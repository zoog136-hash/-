"""Dedicated NW braced stance from unchanged approved actor materials.

This is new HIT input art, not a modification or re-approval of old walk.
Complete actual flat shoes are translated once by integer native pixels.
Only actual thigh/calf material is articulated to meet them.
"""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageChops
from scipy.ndimage import label

P=Path(__file__).parent
O=P/'actual-braced-stance-v02';O.mkdir(exist_ok=False)
S=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/left-backswing-native-edit-v02/thunder_female-NW-walk-contact0-LEFTbackswing-bounded-v02.png')
L=Path('/workspace/scratch/mythic413-NW-walk-LOAD1-author-20261020-v01/thunder_female-NW-walk-LOAD1-rigged-retouched-v04.png')
R=Path('/workspace/scratch/mythic413-NW-walk-Rload4-author-20261020-v03/thunder_female-NW-walk-Rload4-finished-native-body-v04.png')
im=Image.open(S).convert('RGBA');W,H=im.size
assert (W,H)==(1254,1254)
assert hashlib.sha256(S.read_bytes()).hexdigest()=='0874d56a0adf0d76b5e91c565ec41d601d8bbb76457c64e703a89dba54cf0645'
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def poly(q):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return m
def part(source,q,name):
 m=poly(q);a=source.copy();a.putalpha(ImageChops.multiply(a.getchannel('A'),m))
 a.save(O/(name+'-material.png'));m.save(O/(name+'-semantic-matte.png'));return a
def bone(a,b,c,d):
 a,b,c,d=map(lambda z:np.asarray(z,float),(a,b,c,d));v=b-a;u=v/np.linalg.norm(v);n=np.array([-u[1],u[0]])
 z=d-c;w=z/np.linalg.norm(z);nn=np.array([-w[1],w[0]])
 A=np.column_stack([w*np.linalg.norm(z)/np.linalg.norm(v),nn])@np.column_stack([u,n]).T
 return A,c-A@a
def affine(a,A,t):
 inv=np.linalg.inv(A);k=-inv@t
 return a.transform((W,H),Image.Transform.AFFINE,(inv[0,0],inv[0,1],k[0],inv[1,0],inv[1,1],k[1]),Image.Resampling.BICUBIC)
lf=part(Image.open(L).convert('RGBA'),[(588,947),(651,944),(677,977),(687,1010),(675,1045),(641,1057),(600,1061),(571,1042),(564,1016),(575,979)],'LEFT-complete-actual-flat-shoe')
rf=part(Image.open(R.parent/'Rload4-actual-stance-leg-layer-v04.png').convert('RGBA'),[(677,944),(730,944),(748,980),(744,1020),(723,1030),(688,1025),(659,1013),(633,1000),(637,980),(664,964)],'RIGHT-complete-actual-flat-shoe')
feet=Image.new('RGBA',(W,H));feet.paste(lf,(-111,-100));feet.alpha_composite(rf,dest=(-1,101));feet.save(O/'NW-HIT-fixed-complete-flat-shoes.png')
legs=Image.new('RGBA',(W,H));ops=[]
items=[
 ('RIGHT-thigh',[(636,696),(701,704),(736,782),(736,872),(691,892),(659,838),(640,768)],(670,716),(704,851),(670,716),(700,861)),
 ('RIGHT-calf',[(683,824),(734,828),(793,957),(823,1048),(802,1080),(762,1068),(730,996),(702,918)],(704,851),(790,1046),(700,861),(704,1070)),
 ('LEFT-thigh',[(567,692),(642,700),(621,781),(592,838),(550,841),(528,803),(546,737)],(612,706),(563,808),(612,706),(554,780)),
]
for name,q,a,b,c,d in items:
 src=part(im,q,name);A,t=bone(a,b,c,d);lay=affine(src,A,t);legs.alpha_composite(lay)
 ops.append(dict(name=name,source_control=[a,b],target_control=[c,d],matrix=A.tolist(),offset=t.tolist(),anatomical_joints='author projected control; hidden anatomy uncertain'))
# Real LOAD1 calf and whole flat shoe are a continuous native surface. The
# one fixed foot translation remains exact below source y944; the actual calf
# curves to the new knee with no artificial horizontal foot/cuff cut.
calfshoe=part(Image.open(L).convert('RGBA'),[(544,823),(616,823),(649,913),(661,963),(680,983),(687,1010),(675,1045),(641,1057),(600,1061),(571,1042),(564,1016),(575,979),(568,926),(548,877)],'LEFT-continuous-calf-and-complete-flat-shoe')
y,x=np.indices((H,W),dtype=float)
sx=x.copy();sy=y.copy()
def displacement(y):
 t=np.clip((y-850.)/94.,0.,1.);t=t*t*(3-2*t)
 return -25.-86.*t,-70.-30.*t
for _ in range(18):
 dx,dy=displacement(sy);sx=x-dx;sy=y-dy
from scipy.ndimage import map_coordinates
ar=np.asarray(calfshoe).astype(float)/255;al=ar[:,:,3];pm=ar[:,:,:3]*al[:,:,None]
wa=map_coordinates(al,[sy,sx],order=1,mode='constant',cval=0)
rgb=np.stack([map_coordinates(pm[:,:,i],[sy,sx],order=1,mode='constant',cval=0)for i in range(3)],2)
rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-8)
continuous=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255+.5,0,255)),'RGBA')
# Below the physical cuff, restore exact integer-translated full actual shoe.
legs.alpha_composite(continuous)
legs.alpha_composite(feet);legs.save(O/'NW-HIT-articulated-braced-legs-and-complete-shoes.png')
erase=poly([(421,713),(719,713),(754,807),(856,1046),(867,1154),(710,1167),(673,1015),(580,960),(437,961)])
staffpath=Path('/workspace/scratch/mythic413-NW-walk-LOAD1-author-20261020-v01/original-RIGHTstaff-protection-mask.png')
staff=Image.open(staffpath).convert('L');erase=ImageChops.subtract(erase,staff)
cape=poly([(744,652),(805,619),(938,665),(1039,822),(1033,925),(981,969),(898,946),(818,858),(769,780)])
erase=ImageChops.subtract(erase,cape)
cleanpath=Path('/workspace/scratch/mythic413-NW-attack-author-20261020-v01/actual-NW-ATTACK6-native-rig-v03/actual-NW-clean-original-garment-LEFT-oldarm-erased-body-staff-legs-INPUT.png')
base=Image.open(cleanpath).convert('RGBA').crop((0,0,W,H));base.paste((0,0,0,0),(0,0),erase);base.alpha_composite(legs)
# Whole original rigid weapon stays in front of newly articulated legs.
weapon=im.copy();weapon.putalpha(ImageChops.multiply(im.getchannel('A'),staff));base.alpha_composite(weapon)
base.save(O/'thunder_female-NW-HIT-braced-fixed-stance-candidate-v02.png');erase.save(O/'old-walk-leg-erasure-mask.png')
data=dict(status='ACTUAL_NEW_BRACED_HIT_INPUT_PENDING_INDEPENDENT_SOURCE_QC',source0=pin(S),LEFT_flat_shoe_source=pin(L),RIGHT_flat_shoe_source=pin(R),physical_canvas=2048,body_unit=2,common_rig_root=[641,1058.3],storage_translation=[0,0],source_size=[1254,1254],fixed_shoe_integer_translations=dict(LEFT=[-111,-100],RIGHT=[-1,101]),fixed_heel_controls=dict(LEFT=[514.3543188022422,944.2188869220179],RIGHT=[704.4843188022421,1115.538886922018]),sole_yaw='Preserve each actual approved flatshoe native yaw; no forced perimeter slope',leg_operations=ops,output=pin(O/'thunder_female-NW-HIT-braced-fixed-stance-candidate-v02.png'),approval_added=0,new_service_calls=0)
(O/'NW-HIT-actual-braced-stance-source-and-fixed-contract-v02.json').write_text(json.dumps(data,indent=2)+'\n')
print(json.dumps(dict(output=data['output'],C=2048,root=[641,1058.3],new_service_calls=0,approval_added=0)))
