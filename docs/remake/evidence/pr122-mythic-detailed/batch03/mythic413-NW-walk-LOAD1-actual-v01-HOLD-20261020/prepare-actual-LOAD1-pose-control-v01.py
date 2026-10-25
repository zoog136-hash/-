"""Native actual-costume LOAD1 control, not a final animation source."""
from pathlib import Path
import hashlib,json,math
import numpy as np
from PIL import Image,ImageDraw,ImageChops,ImageFilter

HERE=Path(__file__).parent
MASTER=HERE/'left-backswing-native-edit-v02/thunder_female-NW-walk-contact0-LEFTbackswing-bounded-v02.png'
assert hashlib.sha256(MASTER.read_bytes()).hexdigest()=='0874d56a0adf0d76b5e91c565ec41d601d8bbb76457c64e703a89dba54cf0645'
OUT=Path('/workspace/scratch/mythic413-NW-walk-LOAD1-author-20261020-v01');OUT.mkdir(exist_ok=False)
source=Image.open(MASTER).convert('RGBA');W,H=source.size
DELTA=(111.35431880224218,100.21888692201796)
LHEEL0=(514.,944.);LHEEL1=tuple(a+b for a,b in zip(LHEEL0,DELTA))
LH=(612.,706.);LK=(563.,808.);LA=(521.,890.)
RH=(670.,716.);RK=(704.,851.);RA=(790.,1046.)
NLK=(592.,852.);NRK=(650.,830.);NRA=(722.,959.)
FX=-.5399492471560389;FY=.841697576624542;E=math.radians(35.264389682754654)
# Sole estimate only for guide roll; actual new painted sole must be reviewed.
SOLE0=(481.,906.);dx=SOLE0[0]-LHEEL0[0];dy=SOLE0[1]-LHEEL0[1]
pitch=math.atan((dy-.9*dx)*(-FX)/(dx*math.cos(E)))
def basis(t):return np.array([[FX*math.cos(t),-FX*math.sin(t)],[-(FY*math.sin(E)*math.cos(t)+math.cos(E)*math.sin(t)),FY*math.sin(E)*math.sin(t)-math.cos(E)*math.cos(t)]])
T=basis(0.)@np.linalg.inv(basis(pitch));NLA=tuple(np.asarray(LHEEL1)+T@(np.asarray(LA)-np.asarray(LHEEL0)))
def polygon(points):
 m=Image.new('L',(W,H),0);ImageDraw.Draw(m).polygon(points,fill=255);return m
def capsule(a,b,r):
 m=Image.new('L',(W,H),0);d=ImageDraw.Draw(m);d.line([a,b],fill=255,width=2*r)
 for x,y in(a,b):d.ellipse((x-r,y-r,x+r,y+r),fill=255)
 return m
parts=[('LEFT_thigh',capsule(LH,LK,33),LH,LK,LH,NLK),('LEFT_shin',capsule(LK,LA,27),LK,LA,NLK,NLA),('RIGHT_thigh',capsule(RH,RK,37),RH,RK,RH,NRK),('RIGHT_shin',capsule(RK,RA,31),RK,RA,NRK,NRA)]
leftfoot=polygon([(467,863),(515,849),(545,877),(554,901),(532,926),(521,956),(503,956),(502,926),(473,916),(452,891)])
rightfoot=polygon([(760,999),(806,1009),(829,1048),(846,1129),(820,1141),(797,1127),(754,1137),(713,1119),(738,1081),(758,1049)])
old=Image.new('L',(W,H),0)
for _,m,*_ in parts:old=ImageChops.lighter(old,m)
old=ImageChops.lighter(old,ImageChops.lighter(leftfoot,rightfoot));ImageDraw.Draw(old).rectangle((0,0,W-1,694),fill=0)
# Staff, silhouette and cape use their original exact body reference; fresh legs are drawn around them.
staff=polygon([(774,650),(790,650),(777,763),(780,787),(774,805),(775,829),(770,854),(769,879),(749,934),(736,931),(737,903),(730,880),(736,856),(736,832),(744,812),(743,794),(754,780),(760,760)])
old=ImageChops.subtract(old,staff)
derived=source.copy();derived.paste((0,0,0,0),(0,0),old)
newmask=Image.new('L',(W,H),0);ops=[]
def affine_part(name,mask,A,t):
 layer=source.copy();layer.putalpha(ImageChops.multiply(source.getchannel('A'),mask))
 inv=np.linalg.inv(A);offset=-inv@t;coeff=(float(inv[0,0]),float(inv[0,1]),float(offset[0]),float(inv[1,0]),float(inv[1,1]),float(offset[1]))
 moved=layer.transform((W,H),Image.Transform.AFFINE,coeff,resample=Image.Resampling.BICUBIC)
 derived.alpha_composite(moved)
 mm=mask.transform((W,H),Image.Transform.AFFINE,coeff,resample=Image.Resampling.NEAREST)
 return mm
for name,m,a,b,c,d in parts:
 v=np.asarray(b)-np.asarray(a);z=np.asarray(d)-np.asarray(c);s=np.linalg.norm(z)/np.linalg.norm(v);angle=math.atan2(z[1],z[0])-math.atan2(v[1],v[0]);A=s*np.array([[math.cos(angle),-math.sin(angle)],[math.sin(angle),math.cos(angle)]]);t=np.asarray(c)-A@np.asarray(a)
 mm=affine_part(name,m,A,t);newmask=ImageChops.lighter(newmask,mm);ops.append({'part':name,'old_joint_pair':[a,b],'target_joint_pair':[c,d],'CONTROL_ONLY_projected_scale':float(s),'CONTROL_ONLY_rotation_degrees':math.degrees(angle)})
mm=affine_part('LEFT_boot_roll_to_flat_CONTROL',leftfoot,T,np.asarray(LHEEL1)-T@np.asarray(LHEEL0));newmask=ImageChops.lighter(newmask,mm)
right_shift=np.asarray(NRA)-np.asarray(RA);mm=affine_part('RIGHT_AIR_boot_CONTROL',rightfoot,np.eye(2),right_shift);newmask=ImageChops.lighter(newmask,mm)
# Protect upperbody and actual carried staff. Relaxed edit padding admits natural joint/shoe repaint.
allowed=ImageChops.lighter(old,newmask).filter(ImageFilter.MaxFilter(31));ImageDraw.Draw(allowed).rectangle((0,0,W-1,689),fill=0);allowed=ImageChops.subtract(allowed,staff)
allowed.save(OUT/'allowed-LOAD1-legs-and-local-hip-mask.png');staff.save(OUT/'original-RIGHTstaff-protection-mask.png');old.save(OUT/'old-legs-erasure-mask.png')
derived.save(OUT/'DERIVED-actual-costume-LOAD1-LEFTstance-RIGHTswing-control.png')
derived.crop((450,690,870,1190)).save(OUT/'DERIVED-LOAD1-leg-foot-close-control.png')
meta={'status':'ACTUAL_COSTUME_LOAD1_POSE_CONTROL_ONLY_NOT_FINAL_SOURCE','source_master':str(MASTER),'source_master_sha256':'0874d56a0adf0d76b5e91c565ec41d601d8bbb76457c64e703a89dba54cf0645','virtual_C_fixed':2048,'body_unit_factor_fixed':2,'raw_size':[W,H],'native_plant_delta':DELTA,'LEFT_heel0_stiletto':LHEEL0,'LEFT_heel1_target':LHEEL1,'LEFT_forefoot_sole0_estimate':{'xy':SOLE0,'uncertainty_px':[8,8],'not_ornamental_toe':'Used for CONTROL footroll only, not final ground approval'},'LEFT_footroll_control_degrees':math.degrees(pitch),'LEFT_ankle1_target':NLA,'LEFT_knee1_target':NLK,'RIGHT_knee1_target':NRK,'RIGHT_ankle1_target':NRA,'RIGHT_air_boot_control_shift':right_shift.tolist(),'RIGHT_toe_extremity1_control':[748.+right_shift[0],1117.+right_shift[1]],'body_root_or_frame_shift':'NONE; same native body placement and same C; actual new hip/knee/ankle articulation required','raw_source_anchor':'Common source0/1 anchor must be pinned by root; pairwise plantdelta independent of common translation, not perpose retuning','original_RGBA_resampled':False,'control_only_parts_affine':True,'final_source_rule':'New service RGBA inside explicit legs/localhipmask only, original master elsewhere; no finalresource resample','ops':ops,'actor_approval_added':0}
(OUT/'actual-LOAD1-control-contract-v01.json').write_text(json.dumps(meta,indent=2)+'\n')
for name in['DERIVED-actual-costume-LOAD1-LEFTstance-RIGHTswing-control.png','DERIVED-LOAD1-leg-foot-close-control.png']:
 im=Image.open(OUT/name).convert('RGBA');bg=Image.new('RGB',im.size,(84,84,84));bg.paste(im,mask=im.getchannel('A'));bg.thumbnail((750,750));q=OUT/(Path(name).stem+'-private.jpg');bg.save(q,'JPEG',quality=88,optimize=True);assert q.stat().st_size<150000
print('ACTUAL_LOAD1_CONTROL_READY',OUT,'LEFT_heel_target',LHEEL1,'LEFT_ankle',NLA,'C2048fixed','approval0')
