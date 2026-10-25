"""Sixth actual phase: RIGHT terminal toe support, LEFT late swing, back free arm."""
from pathlib import Path
import json,hashlib,math,numpy as np
from PIL import Image,ImageDraw,ImageChops,ImageFilter
from scipy.ndimage import label,binary_closing,binary_fill_holes,binary_dilation
P=Path(__file__).parent;O=Path('/workspace/scratch/mythic413-NW-walk-terminal5-author-20261020-v02');O.mkdir(exist_ok=False)
Bpath=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/left-backswing-native-edit-v02/thunder_female-NW-walk-contact0-LEFTbackswing-bounded-v02.png');B=Image.open(Bpath).convert('RGBA');Tpath=Path('/workspace/scratch/mythic413-NW-walk-terminal2-author-20261020-v02/thunder_female-NW-walk-terminal2-finished-local-rig-v03.png');T=Image.open(Tpath).convert('RGBA');Rpath=P/'thunder_female-NW-walk-Rload4-local-joint-v01-service.png';R=Image.open(Rpath).convert('RGBA');W,H=B.size
def poly(q):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return m
def part(src,q):
 a=src.copy();matte=poly(q);
 if src is R:matte=ImageChops.subtract(matte,Image.open(P/'Rload4-actual-nearLEFT-swing-semantic-matte-v04.png').convert('L'))
 a.putalpha(ImageChops.multiply(a.getchannel('A'),matte.filter(ImageFilter.GaussianBlur(.6))));z=np.array(a);cc,n=label(z[:,:,3]>8);ss=np.bincount(cc.ravel());ss[0]=0;z[:,:,3][cc!=np.argmax(ss)]=0;return Image.fromarray(z)
def move(a,A,t):
 inv=np.linalg.inv(A);b=-inv@t;return a.transform((W,H),Image.Transform.AFFINE,(inv[0,0],inv[0,1],b[0],inv[1,0],inv[1,1],b[1]),Image.Resampling.BICUBIC)
def joint(a,b,c,d):
 a,b,c,d=map(np.asarray,(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);A=np.column_stack([v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]])@np.column_stack([u,[-u[1],u[0]]]).T;return A,c-A@a
y,x=np.indices((H,W));z=np.asarray(B);blue=(z[:,:,2]>z[:,:,0]*1.30)&(z[:,:,2]>50)&(z[:,:,3]>16)&(x>680)&(y>640);cape=binary_dilation(binary_fill_holes(binary_closing(blue,iterations=4)),iterations=6)
full=Image.open('/workspace/scratch/mythic413-NW-walk-terminal2-author-20261020-v02/terminal2-original-rigid-staff-mask-v01.png').convert('L');gold=(z[:,:,0]>80)&(z[:,:,1]>45)&(z[:,:,0]>z[:,:,1]*1.04)&(z[:,:,1]>z[:,:,2]*1.10);cyan=(z[:,:,2]>z[:,:,0]*1.4)&(z[:,:,1]>z[:,:,0]*1.3);weapon=binary_dilation((gold|cyan)&(np.asarray(full)>0)&(z[:,:,3]>16),iterations=2)&(np.asarray(full)>0)&(z[:,:,3]>0);protect=Image.fromarray(np.uint8(cape|weapon|(y<714))*255)
old=Image.open('/workspace/scratch/mythic413-NW-walk-LOAD1-author-20261020-v01/old-legs-erasure-mask.png').convert('L').filter(ImageFilter.MaxFilter(25));old=ImageChops.lighter(old,poly([(520,714),(715,714),(749,835),(788,966),(850,1145),(711,1155),(650,975),(570,954),(440,938),(446,848),(495,786)]));old=ImageChops.subtract(old,protect);body=B.copy();body.paste((0,0,0,0),(0,0),old);bb=Image.new('RGBA',(W,H));bb.paste(body,(0,-6));body=bb
E=math.radians(35.264389682754654);d=np.array([-40.,15/math.sin(E)]);length=np.linalg.norm(d);fx,fy=d/length
def basis(t):return np.array([[fx*math.cos(t),-fx*math.sin(t)],[-(fy*math.sin(E)*math.cos(t)+math.cos(E)*math.sin(t)),fy*math.sin(E)*math.sin(t)-math.cos(E)*math.cos(t)]])
sole4=np.array([665.4843188022421,999.538886922018]);sole5=sole4+np.array([111.35431880224218,100.21888692201796]);rawsole=np.array([672.,1060.]);BT=basis(math.radians(-30))@np.linalg.inv(basis(0));Bt=sole5-BT@rawsole;NRA=BT@np.array([705.,1001.])+Bt
Lshift=np.array([96.,66.]);NLA=np.array([521.,890.])+Lshift
ops=[('RIGHTfar_terminal_thigh',R,[(626,714),(718,714),(732,785),(727,839),(689,862),(642,850),(620,782)],(670,706),(685,821),(670,700),(736,839)),('RIGHTfar_terminal_shin',R,[(655,808),(719,807),(744,900),(748,980),(730,1024),(687,1019),(667,956),(660,888)],(685,821),(705,1001),(736,839),NRA),('LEFTnear_lateswing_thigh',B,[(529,700),(625,700),(611,767),(589,815),(548,846),(509,806)],(612,706),(563,808),(612,700),(578,828)),('LEFTnear_lateswing_shin',B,[(539,790),(590,802),(584,842),(553,891),(530,915),(498,902),(506,858)],(563,808),(521,890),(578,828),NLA)]
layer=Image.new('RGBA',(W,H));meta=[]
for n,src,q,a,b,c,d in ops:
 A,t=joint(a,b,c,d);layer.alpha_composite(move(part(src,q),A,t));meta.append({'part':n,'target':[np.asarray(c).tolist(),np.asarray(d).tolist()]})
RF=[(694,968),(730,966),(750,1018),(746,1078),(725,1091),(680,1094),(645,1073),(636,1045),(653,1010),(679,998)];LF=[(467,863),(515,849),(545,877),(554,901),(532,926),(521,956),(503,956),(502,926),(473,916),(452,891)]
layer.alpha_composite(move(part(R,RF),BT,Bt));layer.alpha_composite(move(part(B,LF),np.eye(2),Lshift));a=layer.getchannel('A');ImageDraw.Draw(a).rectangle((0,0,W-1,707),fill=0);layer.putalpha(a);body.alpha_composite(layer)
f=O/'DERIVED-terminal5-native1254-actual-costume-control.png';body.save(f);layer.save(O/'terminal5-actual-new-leg-control-layer.png');shiftprotect=Image.new('L',(W,H));shiftprotect.paste(protect,(0,-6));shiftprotect.save(O/'terminal5-original-body-equipment-protection-control.png')
d={'status':'ACTUAL_COSTUME_TERMINAL5_CONTROL_NOT_FINAL','input_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'physical_canvas_fixed':2048,'rig_root':[641,1058.3],'storage_translation':[0,0],'source_body':str(Bpath),'source_body_sha256':hashlib.sha256(Bpath.read_bytes()).hexdigest(),'RIGHT_leg_material':'Own actual Rload4 RIGHTthigh/shin/shoe only; removes foregroundLEFTocclusion bysemanticmatte, never swaps LEFTtoRIGHT costume','source_ownRIGHTshoe':str(Rpath),'source_ownRIGHTshoe_sha256':hashlib.sha256(Rpath.read_bytes()).hexdigest(),'RIGHT_actual_forefoot4':sole4.tolist(),'RIGHT_target_forefoot5':sole5.tolist(),'RIGHT_toeoff_angle_deg':30,'RIGHT_ankle5_target':NRA.tolist(),'RIGHT_heel5_target':(BT@np.array([712.,1075.])+Bt).tolist(),'LEFT_heel5_target':[610,1010],'LEFT_ankle5_target':NLA.tolist(),'LEFT_boot_material':'Same actual anatomicalLEFT heelstrike shoe as approvedSOURCE0; shifts96/66 only, lateAIR approach, no mirror','body_bob_and_rigid_staff':[0,-6],'LEFT_arm':'Actual approved backswing opposite nearLEFT advancingleg','limb_targets':meta,'approval_added':0};(O/'terminal5-actual-control-contract-v01.json').write_text(json.dumps(d,indent=2)+'\n')
for n,img in [('terminal5-control-whole-private.jpg',body),('terminal5-control-legs-private.jpg',body.crop((450,630,940,1230)))]:
 bg=Image.new('RGB',img.size,(80,80,80));bg.paste(img,mask=img.getchannel('A'));bg.thumbnail((750,750));bg.save(O/n,quality=85,optimize=True);assert(O/n).stat().st_size<150000
print(json.dumps({'control_sha':d['input_sha256'],'Rsole5':sole5.tolist(),'Rheel5':d['RIGHT_heel5_target'],'Rankle5':NRA.tolist(),'Lheel5':[610,1010]}))
