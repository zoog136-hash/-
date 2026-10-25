from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
B=Path(__file__).parent;O=B/'native-source-parts-v03-complete-RIGHT-jointcaps';O.mkdir(exist_ok=False);old=B/'native-source-parts-v02-full-lower-staff/SW-exact-own-native-semantic-parts-complete-staff-v02.json';j=json.loads(old.read_text());src=np.array(Image.open(j['source']['path']).convert('RGBA'));H,W=src.shape[:2];yy,xx=np.indices((H,W));a=src[:,:,3]>0;parts={};entries=dict(j['parts'])
def pin(p):p=Path(p);v=p.read_bytes();return dict(path=str(p),bytes=len(v),sha256=hashlib.sha256(v).hexdigest())
def poly(points):m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(points,fill=255);return np.array(m)>0
for n,r in entries.items():
 v=np.zeros_like(src);x,y,ex,ey=r['native_crop_box'];v[y:ey,x:ex]=np.array(Image.open(r['path']).convert('RGBA'));parts[n]=v
right=poly([(545,329),(568,333),(580,350),(573,380),(562,400),(561,430),(558,454),(548,479),(534,494),(513,505),(490,511),(462,510),(439,502),(419,496),(400,482),(382,468),(367,459),(341,455),(327,448),(328,403),(340,394),(369,394),(392,409),(414,426),(437,432),(463,430),(484,419),(488,401),(506,378),(527,349)])&a
backing=poly([(480,320),(546,320),(546,336),(541,342),(535,352),(529,362),(522,371),(516,380),(508,386),(496,390),(484,389),(480,369)])
right&=~backing
# All rigidstaff/source LEFT/HEAD/NECK/COAT/fixedboots owners remain immutable.
protected=np.zeros((H,W),bool)
for n in parts:
 if n not in ['RIGHT-full-upper-arm-and-shoulder','RIGHT-white-puff-elbow','RIGHT-complete-forearm-cuff-grip-fingers','BODY-own-chest-waist-ribbons']:protected|=parts[n][:,:,3]>0
right&=~protected
puff=right&poly([(427,420),(477,422),(494,427),(508,434),(521,446),(528,460),(526,477),(516,493),(500,506),(478,513),(452,509),(433,497),(422,476),(420,450)])
forearm=right&(xx<=450)&~puff;upper=right&~puff&~forearm
# Actual shoulder skin cap remains with torso underneath the complete upper arm.
shouldercap=((xx-550)**2+(yy-370)**2<=18**2)&(src[:,:,3]==255)&(src[:,:,0]>src[:,:,2]+20)&(src[:,:,0]>src[:,:,1]+10)&upper
# The visible blue/white elbow junction is x511/y443, not the centre of the puff.
elbowcap=((xx-511)**2+(yy-443)**2<=16**2)&(src[:,:,3]==255)&right
puff|=elbowcap;upper|=elbowcap
core=a&~protected&~right;core|=shouldercap
masks={'RIGHT-full-upper-arm-and-shoulder':upper,'RIGHT-white-puff-elbow':puff,'RIGHT-complete-forearm-cuff-grip-fingers':forearm,'BODY-own-chest-waist-ribbons':core}
for n,m in masks.items():
 v=np.zeros_like(src);v[m]=src[m];parts[n]=v;ys,xs=np.where(m);box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];f=O/f'{n}-true-complete-native-source-RGBA-v03.png';Image.fromarray(v).crop(box).save(f,optimize=True);entries[n]=dict(**pin(f),native_crop_box=box,native_nonzero_alpha_pixels=int(m.sum()),source_RGBA_mismatch=0)
# Native transparent edges have one owner; only real alpha255 native jointcap overlap is permitted.
recon=Image.new('RGBA',(W,H))
for n,v in parts.items():recon.alpha_composite(Image.fromarray(v))
assert np.array_equal(np.array(recon),src),'Whole native source RGBA must recompose exactly'
capfile=O/'RIGHT-actual-native-opaque-jointcap-overlap-mask-v03.png';Image.fromarray((shouldercap.astype('uint8')+elbowcap.astype('uint8')*2)).save(capfile,optimize=True)
j.update(schema='MYTHIC413_SW_COMPLETE_RIGHT_TRUE_PUFF_AND_NATIVE_JOINTCAPS_V03',parts=entries,source_part_reconstruction_RGBA_changed=0,source_partition_disjoint_except_actual_opaque_jointcaps=True,actual_native_jointcap_ownership=dict(mask=pin(capfile),shoulder_native_center=[550,370],shoulder_native_source_skin_RGBA_pixels=int(shouldercap.sum()),elbow_visible_blue_white_junction=[511,443],elbow_native_source_RGBA_pixels=int(elbowcap.sum()),source_alpha_required=255,source_RGBA_mismatch=0,old_full_RIGHT_sleeve_RGBA_remaining_in_BODY_except_exact_skin_jointcap=0),RIGHT_material_correction='Whole source-isolated upper blue sleeve and complete original white puff/outer rim now owned; true blue head backing excluded from arm. Visible elbow control is true blue/white joint instead of puff center.',prior_provisional_contract=pin(old))
j['controls']['RIGHT_elbow']=[511.,443.]
f=O/'SW-exact-own-native-complete-RIGHT-jointcaps-source-contract-v03.json';f.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(contract=pin(f),shouldercap=int(shouldercap.sum()),elbowcap=int(elbowcap.sum()))))
