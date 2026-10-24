from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
B=Path(__file__).parent;O=B/'native-W-source-parts-v01';O.mkdir(exist_ok=False)
HAND=Path('/workspace/scratch/mythic413-W-hit-author-20261020-v01/W-final-once-body-real-cloth-complete-LEFT-original-boots-readonly-future-action-handoff-v01.json');h=json.loads(HAND.read_text());shared=Path(h['shared_actual_material_handoff']['path']);sh=json.loads(shared.read_text());bp=sh['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots']['body'];lp=h['original_complete_LEFT_forearm_and_fingers']['LEFT-far-complete-curved-cuff-forearm-free-hand'];mp=sh['semantic_mattes']['LEFT-far-complete-curved-cuff-forearm-free-hand']
def pin(p):p=Path(p);v=p.read_bytes();return dict(path=str(p),bytes=len(v),sha256=hashlib.sha256(v).hexdigest())
for q in [h['source'],h['once_registration'],h['shared_actual_material_handoff'],bp,lp,mp]:assert pin(q['path'])==q
src=np.array(Image.open(bp['path']).convert('RGBA'));original=np.array(Image.open(h['source']['path']).convert('RGBA'));left=np.array(Image.open(lp['path']).convert('RGBA'));leftmask=np.array(Image.open(mp['path']))>0;H,W=src.shape[:2];yy,xx=np.indices((H,W));a=src[:,:,3]>0
assert np.array_equal(left[left[:,:,3]>0],original[left[:,:,3]>0]),'Complete original forearm/fingers RGBA must remain actual native source'
def poly(points):v=Image.new('L',(W,H));ImageDraw.Draw(v).polygon(points,fill=255);return np.array(v)>0
palm=poly([(374,402),(392,402),(405,409),(415,417),(418,440),(407,450),(391,451),(377,446),(370,438),(369,414)])
staff=((xx<445)&((yy<400)|(yy>461)))|((xx>=380)&(xx<=401)&(yy>=400)&(yy<=461)&~palm)
right=(((xx>=365)&(xx<=522)&(yy>=400)&(yy<=510))|poly([(512,431),(530,430),(541,440),(543,460),(537,479),(522,495),(508,502),(491,499),(485,475),(500,445)]))&~staff
puff=right&poly([(478,435),(500,432),(520,437),(537,447),(543,465),(537,483),(520,501),(498,509),(480,497),(474,475),(475,449)])
fore=right&(xx<484)&~puff;upper=right&~puff&~fore
leftupper=poly([(634,310),(664,313),(689,330),(711,348),(727,372),(741,397),(747,423),(748,448),(740,470),(725,486),(705,496),(689,484),(679,466),(674,448),(658,441),(638,430),(626,413),(622,391),(624,365)])&~leftmask
masks={};used=np.zeros((H,W),bool)
for n,m in [('complete-rigid-RIGHT-staff',staff),('RIGHT-complete-forearm-cuff-grip-fingers',fore),('RIGHT-white-puff-elbow',puff),('RIGHT-full-visible-upper-arm',upper),('LEFT-full-near-upper-arm',leftupper)]:m=m&a&~used;masks[n]=m;used|=m
core=a&~used;fixed=((yy>=1000)|((yy>=640)&(xx>=470)&(xx<=692))|((yy>=720)&(xx>=470)&(xx<=850)))&core
head=poly([(515,65),(785,65),(787,279),(719,341),(619,338),(542,306)])&core&~fixed
neck=poly([(607,279),(699,284),(716,355),(655,372),(602,342)])&core&~head&~fixed
coat=(yy>=545)&core&~head&~neck&~fixed
masks.update({'HEAD-own-profile-face-hair-crown':head,'NECK-own-profile-skin-collar':neck,'COAT-own-real-native-cloth-and-original-tails':coat,'LEGS-original-full-boots-conservative-fixed':fixed,'BODY-own-profile-chest-waist-ribbons':core&~head&~neck&~coat&~fixed})
entries={};owner=np.zeros((H,W),np.uint8);recon=np.zeros_like(src)
for i,(n,m)in enumerate(masks.items(),1):
 assert not np.any(owner[m]);owner[m]=i;recon[m]=src[m];v=np.zeros_like(src);v[m]=src[m];ys,xs=np.where(m);assert len(xs),n;box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];f=O/f'{n}-exact-actual-own-W-native-RGBA-v01.png';Image.fromarray(v).crop(box).save(f,optimize=True);entries[n]=dict(**pin(f),native_crop_box=box,native_nonzero_alpha_pixels=int(m.sum()),actual_input_RGBA_mismatch=0)
assert np.array_equal(recon,src),'All BODY99a9 original+real-hidden-cloth RGBA must reconstruct exactly'
ys,xs=np.where(left[:,:,3]>0);box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];lf=O/'LEFT-complete-original-curved-cuff-forearm-all-free-fingers-native-v01.png';Image.fromarray(left).crop(box).save(lf,optimize=True);entries['LEFT-complete-original-curved-cuff-forearm-free-fingers']=dict(**pin(lf),native_crop_box=box,native_nonzero_alpha_pixels=int((left[:,:,3]>0).sum()),original_source_RGBA_mismatch=0,rendered_over_real_hidden_coat_BODY=True)
om=O/'W-disjoint-BODY-input-native-semantic-owner-indices-v01.png';Image.fromarray(owner).save(om,optimize=True)
ctl=dict(RIGHT_visible_proximal_upper_anchor=[531.,438.],RIGHT_visible_cuff_elbow=[517.,457.],RIGHT_wrist=[427.,439.],RIGHT_grip=[391.,428.],LEFT_projected_shoulder=[660.,345.],LEFT_visible_proximal_cuff=[699.,487.],LEFT_visible_elbow_inside_puff=[701.,518.],LEFT_wrist=[735.,640.])
j=dict(schema='MYTHIC413_W_EXACT_OWN_NATIVE_VISIBLE_RIGHT_STAFF_LEFT_UPPER_REAL_CLOTH_V01',status='ACTUAL_W_NATIVE_INPUTS_PENDING_ATTACK6_SOURCE_REVIEW',source=h['source'],actual_BODY_input_with_single_real_native_hidden_coat=bp,original_complete_LEFT_input=lp,approved_common_handoff=pin(HAND),shared_actual_material_handoff=pin(shared),once_registration=h['once_registration'],C=2560.,bodyunit=2.5,common_rig_root_unpadded=h['root_unpadded'],parts=entries,controls=ctl,BODY_native_owner_indices=pin(om),actual_BODY_RGBA_reconstruction_changed=0,complete_LEFT_original_source_RGBA_mismatch=0,source_resampled_recolored_mirrored=False,RIGHT_upper_scope='Complete original visible far RIGHT proximal sleeve only; anatomical upper arm/shoulder is occluded behind W chest. Declared531438 is a visible projected proximal control, not invented hidden humerus. Attack keeps this source part near original torso occlusion.',LEFT_proximal_cuff_is_not_shoulder=True,full_staff_original_palm_occluded_shaft_requires_same_rigid_hand=True,hidden_cloth_only_existing_approved_shared_single_service=True,new_hidden_material_generated=False,old_failed_donor_BODY_used=False,LEGS_scope='Official conservative stationary W brace lock; includes central cloak/hem and is not a movable leg matte',actor_approvals_added=0)
f=O/'W-exact-native-RIGHT-fullstaff-near-LEFT-upper-real-cloth-source-parts-v01.json';f.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(contract=pin(f),parts=len(entries),native_part_bytes=sum(v['bytes']for v in entries.values()),RIGHT_visible_upper_pixels=entries['RIGHT-full-visible-upper-arm']['native_nonzero_alpha_pixels'],BODY_RGBA_reconstruction_changed=0)))
