"""Dedicated N thunder-staff attack: original own materials, six actual bone poses."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import numpy as np, json, hashlib, math

P=Path(__file__).parent/'controls-v02';P.mkdir(exist_ok=False)
H=Path('/workspace/scratch/mythic413-N-walk-load-author-fresh-20261020-v01/N-native-rig-and-material-handoff-for-RUN-v01')
M=json.loads((H/'N-RUN-actual-native-rig-source-material-handoff-v01.json').read_text())
S=Path(M['source0']['path']);src=Image.open(S).convert('RGBA');W,Hh=src.size
assert hashlib.sha256(S.read_bytes()).hexdigest()==M['source0']['sha256']
body0=Image.open(H/'source0-native-body-coat-RIGHTstaff-with-complete-old-legs-removed-INPUT.png').convert('RGBA')
legs={s:Image.open(H/f'complete-original-native-{s}-leg-and-stiletto-material.png').convert('RGBA')for s in ['LEFT','RIGHT']}
left_forearm=Image.open(H/'complete-original-native-LEFT-forearm-hand-bracer-ornament-material.png').convert('RGBA')
def poly(points):
    m=Image.new('L',(W,Hh));ImageDraw.Draw(m).polygon(points,fill=255);return m
def isolated(im,mask):
    a=im.copy();a.putalpha(ImageChops.multiply(a.getchannel('A'),mask));return a
def transform(im,A,t):
    inv=np.linalg.inv(A);b=-inv@t
    return im.transform((W,Hh),Image.Transform.AFFINE,(inv[0,0],inv[0,1],b[0],inv[1,0],inv[1,1],b[1]),Image.Resampling.BICUBIC)
def segment(im,a,b,c,d):
    a,b,c,d=map(lambda x:np.asarray(x,dtype=float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c)
    A=np.column_stack((v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]))@np.column_stack((u,[-u[1],u[0]])).T
    return transform(im,A,c-A@a)
def shift(im,delta):
    q=Image.new('RGBA',(W,Hh));q.paste(im,tuple(map(int,delta)));return q
weapon_mask=poly([(797,140),(817,140),(846,278),(834,323),(835,393),(813,440),(813,784),(835,844),(823,918),(807,975),(786,920),(778,844),(796,783),(796,440),(774,393),(774,323),(766,278)])
# Source shaft is hidden by the actual right-hand grip, which must stay arm material.
ImageDraw.Draw(weapon_mask).rectangle((778,465,818,511),fill=0)
visible=Image.new('L',(W,Hh));visible.paste(weapon_mask.crop((0,0,W,665)),(0,0));visible=ImageChops.lighter(visible,poly([(801,798),(816,799),(813,811),(824,830),(811,848),(824,877),(812,906),(807,975),(785,908),(790,880),(779,848),(791,825),(791,808)]));weapon_mask=visible
RU=poly([(694,410),(739,410),(766,456),(775,509),(753,540),(720,518),(695,468)])
RF=poly([(733,493),(771,491),(792,459),(815,461),(826,500),(783,540),(749,545)])
LU=poly([(554,411),(594,417),(587,455),(564,494),(563,529),(533,543),(515,514),(531,471)])
LF=poly([(529,499),(563,515),(540,564),(508,603),(496,642),(470,644),(464,613),(484,571),(509,528)])
right_upper=isolated(src,RU);right_fore=isolated(src,RF);left_upper=isolated(src,LU)
weapon=Image.new('RGBA',(W,Hh));shaft=src.crop((797,520,811,660)).resize((14,333),Image.Resampling.BICUBIC);weapon.paste(shaft,(797,482));weapon.alpha_composite(isolated(src,weapon_mask))
erase=ImageChops.lighter(weapon_mask,ImageChops.lighter(ImageChops.lighter(RU,RF),ImageChops.lighter(LU,LF)))
torso=body0.copy();torso.paste((0,0,0,0),(0,0),erase)
# Store actual native isolated materials and semantic mattes once, immutable inputs.
for n,im in [('actual-N-torso-head-skirt-coat-base-INPUT.png',torso),('actual-N-RIGHT-upperarm-material.png',right_upper),('actual-N-RIGHT-forearm-hand-material.png',right_fore),('actual-N-LEFT-upperarm-material.png',left_upper),('actual-N-complete-double-ended-staff-material.png',weapon)]:
    f=P/n;assert not f.exists();im.save(f)
weapon_mask.save(P/'actual-N-full-staff-semantic-matte-v01.png');erase.save(P/'actual-N-attack-arm-weapon-removal-matte-v01.png')
phase_data=[
 ('READY0',[0,0],[715,431],[749,514],[793,483],0,[574,433],[542,517],[487,602],[598,776],[717,773]),
 ('WINDUP1',[8,5],[724,440],[778,534],[837,502],18,[582,439],[544,485],[504,514],[602,784],[731,785]),
 ('COIL2',[10,9],[726,442],[775,477],[819,408],29,[584,442],[551,477],[523,495],[603,791],[734,791]),
 ('STRIKE3',[-7,-16],[706,413],[742,376],[780,352],-10,[565,418],[527,476],[493,548],[585,782],[715,781]),
 ('FOLLOW4',[-10,-8],[703,420],[733,393],[770,385],-18,[564,424],[523,492],[482,571],[580,790],[713,788]),
 ('RECOVER5',[-2,-2],[713,429],[746,507],[796,470],-3,[572,431],[538,511],[486,595],[592,779],[719,778]),
]
records=[]
for i,(name,bob,rs,re,rw,angle,ls,le,lw,lk,rk) in enumerate(phase_data):
    # Two fixed shoe anchors for a braced attack; no body/root or canvas fit.
    left_delta=np.array([-16.5,80.]);right_delta=np.array([40.,-72.])
    layer=Image.new('RGBA',(W,Hh))
    for side,hip,knee,oldhip,oldknee,oldankle,delta,cut,footcut in [
      ('RIGHT',[687+bob[0],646+bob[1]],rk,[687,646],[679,787],[678,923],right_delta,787,880),
      ('LEFT',[620+bob[0],646+bob[1]],lk,[620,646],[623,737],[615,801],left_delta,737,730)]:
        original=legs[side];thighmask=poly([(0,631),(W,631),(W,cut+9),(0,cut+9)]);calfmask=poly([(0,cut-8),(W,cut-8),(W,footcut+30),(0,footcut+30)])
        thigh=isolated(original,thighmask);calf=isolated(original,calfmask);ankle=np.array(oldankle)+delta
        layer.alpha_composite(segment(thigh,oldhip,oldknee,hip,knee));layer.alpha_composite(segment(calf,oldknee,oldankle,knee,ankle))
        foot=original.copy();fa=np.asarray(foot).copy();fa[:footcut]=0;foot=Image.fromarray(fa)
        layer.alpha_composite(transform(foot,np.eye(2),delta))
    current=layer.copy();lean=[0,2,3.5,-3,-4,-.5][i];theta=math.radians(lean);TA=np.array([[math.cos(theta),-math.sin(theta)],[math.sin(theta),math.cos(theta)]]);pivot=np.array([662.,646.]);current.alpha_composite(transform(torso,TA,pivot+np.asarray(bob)-TA@pivot))
    current.alpha_composite(segment(left_upper,[574,433],[543,517],ls,le))
    current.alpha_composite(segment(left_forearm,[543,517],[487,602],le,lw))
    current.alpha_composite(segment(right_upper,[715,431],[747,515],rs,re))
    # The whole rigid gold/cyan staff rotates around its grip, never bends or mirrors.
    a=math.radians(angle);A=np.array([[math.cos(a),-math.sin(a)],[math.sin(a),math.cos(a)]])
    grip=np.array([804.,482.]);dest=np.asarray(rw)+np.array([11.,-1.]);t=dest-A@grip
    current.alpha_composite(transform(weapon,A,t))
    current.alpha_composite(segment(right_fore,[747,515],[793,483],re,rw))
    f=P/f'DERIVED-N-attack-{i}-{name}-actual-costume-control-v01.png';assert not f.exists();current.save(f)
    layer.save(P/f'actual-N-attack-{i}-new-leg-assembly-INPUT-v01.png')
    small=current.copy();small.thumbnail((650,650));bg=Image.new('RGB',small.size,(70,70,70));bg.paste(small,mask=small.getchannel('A'));j=P/f'N-attack-{i}-{name}-control-private.jpg';bg.save(j,quality=84,optimize=True);assert j.stat().st_size<150000
    records.append({'phase':i,'name':name,'input':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'status':'ACTUAL_COSTUME_POSE_CONTROL_NOT_FINISHED_SOURCE','body_bob':bob,'RIGHT_shoulder_elbow_wrist':[rs,re,rw],'LEFT_shoulder_elbow_wrist':[ls,le,lw],'staff_rigid_angle_deg':angle,'actual_torso_lean_deg':lean,'LEFT_fixed_goldheel':[600,930],'RIGHT_fixed_goldheel':[720,960]})
d={'status':'ACTUAL_DEDICATED_N_ATTACK_CONTROLS_JOINT_RETOUCH_REQUIRED','source':str(S),'source_sha256':hashlib.sha256(S.read_bytes()).hexdigest(),'C_fixed':1920,'common_root':[662.8125,917.6920531878804],'storage_translation':[0,0],'impact_frame':3,'one_shot':True,'phases':records,'no_whole_frame_motion_as_attack_completion':True,'approval_added':0}
(P/'N-attack-six-dedicated-native-control-contract-v01.json').write_text(json.dumps(d,indent=2)+'\n')
print(json.dumps({'actual_control_phases':len(records),'STRIKE3':records[3]['input'],'STRIKE3_sha256':records[3]['sha256'],'status':d['status']}))
