from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib,io
B=Path(__file__).parent;D=B/'native-source-parts-v01';D.mkdir(exist_ok=False)
SOURCE=Path('/workspace/scratch/mythic413-SW-hit-author-20261020-v01/SW-new-high-quality-native-background-AA-clean-v01.png')
HAND=Path('/workspace/scratch/mythic413-SW-hit-author-20261020-v01/common-own-SW-native-LEFT-materials-v02/SW-own-native-complete-LEFT-and-old-erased-BODY-readonly-handoff-v02.json')
h=json.loads(HAND.read_text());src=np.array(Image.open(SOURCE).convert('RGBA'));H,W=src.shape[:2];yy,xx=np.indices((H,W));available=src[:,:,3]>0
ledger=B/'private-image-byte-ledger-v01.jsonl'
def pin(p):
 p=Path(p);b=p.read_bytes();return dict(path=str(p),bytes=len(b),sha256=hashlib.sha256(b).hexdigest())
def intake(p,role):
 p=Path(p);rows=[json.loads(s)for s in ledger.read_text().splitlines()];q=pin(p)
 if any(r['path']==str(p)for r in rows):return q
 total=rows[-1]['cumulative_bytes']+q['bytes'];assert total<=6000000,(role,total)
 with ledger.open('a')as f:f.write(json.dumps(dict(sequence=len(rows)+1,role=role,**q,cumulative_bytes=total))+'\n')
 return q
def poly(points):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(points,fill=255);return np.array(m)>0
# Exact staff silhouette lies isolated left of the costume. Palm occlusion remains an
# original hole and follows the identical forearm/staff rigid transform in every pose.
staff=((xx<430)&(yy<397))|((xx>=349)&(xx<=370)&(yy>=397)&(yy<=456))|((xx<381)&(yy>456))
# The original shaft is occluded by skin at these rows. No hidden shaft is painted.
skinpoly=poly([(340,399),(353,401),(364,407),(374,401),(383,404),(390,416),(390,445),(382,454),(369,459),(353,455),(341,450),(333,446),(332,438),(335,429),(330,421),(332,412)])
staff&=~skinpoly
rightall=poly([(545,329),(568,333),(578,350),(567,376),(554,400),(543,428),(533,454),(519,477),(503,491),(483,499),(461,500),(439,492),(420,481),(399,475),(382,463),(367,459),(341,455),(327,448),(328,403),(340,394),(369,394),(392,409),(414,426),(437,432),(463,430),(484,419),(488,401),(506,378),(527,349)])
rightall&=~staff
puff=rightall&poly([(457,426),(479,431),(498,443),(504,465),(495,489),(481,499),(460,500),(441,490),(432,474),(435,451),(445,435)])
forearm=rightall&poly([(327,390),(400,395),(420,420),(447,432),(459,438),(454,456),(445,476),(439,491),(415,485),(387,469),(325,460)])&~puff
upper=rightall&~puff&~forearm
leftmaskpath=Path(h['semantic_mattes']['LEFT-far-complete-curved-cuff-forearm-free-hand']['path']);intake(leftmaskpath,'shared-complete-LEFT-mask-intake')
left=np.array(Image.open(leftmaskpath))>0;left&=available
leftupper=poly([(696,348),(720,351),(737,368),(744,390),(751,410),(767,427),(777,451),(784,474),(773,491),(751,499),(734,490),(722,468),(715,445),(710,420),(703,393)])&~left
parts={};used=np.zeros((H,W),bool)
for name,m in [('complete-rigid-RIGHT-staff',staff),('RIGHT-complete-forearm-cuff-grip-fingers',forearm),('RIGHT-white-puff-elbow',puff),('RIGHT-full-upper-arm-and-shoulder',upper),('LEFT-complete-curved-cuff-forearm-free-fingers',left),('LEFT-full-upper-arm',leftupper)]:
 m=m&available&~used;parts[name]=m;used|=m
core=available&~used
fixedlegs=((yy>=1020)|((yy>=690)&(xx>=440)&(xx<=850))|((yy>=640)&(yy<690)&(xx>=470)&(xx<=800)))&core
head=poly([(475,65),(739,65),(791,225),(735,312),(666,346),(570,344),(499,308)])&core&~fixedlegs
neck=poly([(568,307),(668,309),(685,360),(661,389),(580,373),(553,348)])&core&~head&~fixedlegs
coat=(yy>=610)&~fixedlegs&core
parts.update({'HEAD-own-hair-face-crown':head,'NECK-own-skin-collar-gems':neck,'COAT-own-native-UV-tails':coat,'LEGS-original-full-boots-fixed':fixedlegs,'BODY-own-chest-waist-ribbons':core&~head&~neck&~coat&~fixedlegs})
owner=np.zeros((H,W),np.uint8);out=np.zeros_like(src);entries={}
for i,(name,m)in enumerate(parts.items(),1):
 assert not np.any(owner[m]);owner[m]=i;out[m]=src[m];ys,xs=np.where(m);box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];a=np.zeros_like(src);a[m]=src[m];im=Image.fromarray(a).crop(box);f=D/f'{name}-exact-original-native-RGBA.webp';im.save(f,lossless=True,exact=True,method=6);q=intake(f,'derived-exact-native-semantic-material');assert np.array_equal(np.array(Image.open(f).convert('RGBA')),np.array(im));entries[name]=dict(**q,native_crop_box=box,native_nonzero_alpha_pixels=int(m.sum()),source_RGBA_mismatch=0)
assert np.array_equal(out,src),'Original source complete exact disjoint reconstruction required'
mask=D/'exact-disjoint-original-native-semantic-owner-indices.png';Image.fromarray(owner).save(mask,optimize=True);mp=intake(mask,'derived-semantic-index-mask')
j=dict(schema='MYTHIC413_SW_OWN_EXACT_NATIVE_SEMANTIC_PARTS_V01',status='ACTUAL_MATERIALS_PENDING_ARTICULATED_SOURCE_QC',source=pin(SOURCE),common_LEFT_handoff=pin(HAND),parts=entries,source_owner_index_mask=mp,source_part_reconstruction_RGBA_changed=0,RIGHT_original_grip=[360.,427.],controls=dict(RIGHT_shoulder=[550.,370.],RIGHT_elbow=[487.,452.],RIGHT_wrist=[390.,439.],RIGHT_grip=[360.,427.],LEFT_shoulder=[723.,383.],LEFT_proximal_visible_cuff=[734.,480.],LEFT_elbow=[756.,513.],LEFT_wrist=[853.,619.]),staff_palm_occlusion='Exact source palm hole remains behind same rigid transformed native hand; no hidden shaft invented',native_hidden_material_generated=False,source_resampled_mirrored_recolored=False,actor_approvals_added=0)
f=D/'SW-exact-own-native-semantic-parts-and-rig-controls-v01.json';f.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(contract=pin(f),parts=len(entries),material_bytes=sum(v['bytes']for v in entries.values()),ledger_bytes=json.loads(ledger.read_text().splitlines()[-1])['cumulative_bytes'])))
