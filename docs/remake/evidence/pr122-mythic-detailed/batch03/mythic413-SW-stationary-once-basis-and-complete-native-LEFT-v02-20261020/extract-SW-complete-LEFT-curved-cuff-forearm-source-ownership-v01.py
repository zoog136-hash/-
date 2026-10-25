from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
from scipy.ndimage import label
D=Path(__file__).parent
R=D/'SW-new-native-one-time-body-density-C2496-root-registration-v02.json'
r=json.loads(R.read_text());S=Path(r['source']['path']);src=np.asarray(Image.open(S).convert('RGBA'));H,W=src.shape[:2]
O=D/'common-own-SW-native-LEFT-materials-v01';O.mkdir(exist_ok=False)
def rec(p):
 b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
# The curved proximal cut follows the original blue/gold elbow cap.
# The outer top contour excludes the separate genuine blue hair ribbon
# at x789..825/y470..502; that material remains entirely on BODY. The
# exposed lower contour passes through the actual transparent corridor
# between the white sleeve and the separate gold/blue waist/coat. Distal
# silhouette is the original native RGBA, including every finger and AA.
poly=[(762,461),(767,477),(774,486),(783,495),(790,502),(792,508),(930,510),(930,700),(877,690),(853,677),(836,653),(831,629),(810,613),(784,593),(761,574),(744,560),(737,552),(727,543),(724,536),(718,528),(715,520),(711,512),(705,503),(696,496),(698,493),(705,486),(715,480),(729,473),(744,468),(758,466)]
m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(poly,fill=255);mask=np.asarray(m)>0
part=np.zeros_like(src);part[mask]=src[mask];body=src.copy();body[mask]=0
support=mask&(src[:,:,3]>0);m=Image.fromarray(support.astype('uint8')*255)
ap=O/'original-actual-SW-LEFT-far-complete-curved-cuff-forearm-free-hand-material-v01.png';Image.fromarray(part).save(ap)
bp=O/'actual-SW-LEFT-forearm-only-old-erased-BODY-original-RIGHT-staff-arms-and-boots-v01.png';Image.fromarray(body).save(bp)
mp=O/'original-actual-SW-LEFT-complete-curved-cuff-forearm-hand-native-ownership-mask-v01.png';m.save(mp)
reconstructed=body.copy();reconstructed[mask]=part[mask];assert np.array_equal(reconstructed,src)
assert np.count_nonzero(np.any(body[support]!=0,axis=1))==0
yy,xx=np.indices((H,W));protect=((xx<=465)|((xx>=345)&(xx<=565)&(yy>=390)&(yy<=545)))&(src[:,:,3]>0)
rp=O/'original-SW-RIGHT-near-foregrip-fullstaff-conservative-native-preservation-mask-v01.png';Image.fromarray(protect.astype('uint8')*255).save(rp)
assert np.count_nonzero(support&protect)==0
lab,num=label(part[:,:,3]>=100);counts=np.bincount(lab.ravel())[1:];large=sorted((int(n)for n in counts if n>=200),reverse=True);assert len(large)==1
j=dict(schema='MYTHIC413_SW_COMPLETE_LEFT_CURVED_CUFF_NATIVE_OWNERSHIP_READONLY_HANDOFF_V01',status='NATIVE_INPUT_PENDING_ACTUAL_ARTICULATED_JOINT_QC',source=rec(S),once_body_registration=rec(R),C=r['new_SW_fixed_C'],bodyunit=r['new_SW_fixed_bodyunit'],common_unpadded_root=r['common_rig_root_in_unpadded_frame'],storage_translation=r['production_storage_translation'],native_size=[W,H],parts={'LEFT-far-complete-curved-cuff-forearm-free-hand':rec(ap)},semantic_mattes={'LEFT-far-complete-curved-cuff-forearm-free-hand':rec(mp)},body_inputs={'LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots':dict(body=rec(bp),old_forearm_erasure_support=rec(mp))},fixed_original_RIGHTgear_conservative_native_support=rec(rp),actual_native_controls=dict(LEFT_far_visible_proximal_anchor=[734.,480.],LEFT_far_cuff_elbow=[756.,513.],LEFT_far_wrist=[853.,619.]),controls_scope='Native visible proximal cuff/blue elbow cap and wrist controls, not uniquely measured hidden 3D joints. Wrist control is inside the original black cuff/skin join.',source_ownership_recipe=dict(proximal_and_outer_separator_polygon=poly,native_output_source_RGBA_mismatch=0,source_reconstruction_changed_pixels=0,old_LEFT_material_RGBA_remaining_in_erased_BODY=0,complete_actual_LEFT_strong_alpha100_components_ge200=large),fixed_region_scope='Conservative source-alpha support includes the entire RIGHT weapon/foregrip and some adjacent fixed costume. It is preservation only, not a claimed exact extracted RIGHT animation module. Dedicated RIGHT extraction is owned by the separate ATTACK author.',source_resampling=False,old_original_source_changed=False,body_gate_or_action_approval_added=False,actor_approvals_added=0)
out=O/'SW-own-native-complete-LEFT-and-old-erased-BODY-readonly-handoff-v01.json';out.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(handoff=rec(out),actual_LEFT=rec(ap),body=rec(bp),strong=large,source_reconstruction_changed=0)))
# Bounded private source ownership view; excluded from production archives.
bbox=(690,440,930,700);board=Image.new('RGB',(720,260),(132,132,132))
for i,a in enumerate([src,body,part]):
 p=Image.fromarray(a).crop(bbox);bg=Image.new('RGBA',p.size,(132,132,132,255));bg.alpha_composite(p);board.paste(bg.convert('RGB'),(240*i,0))
board.save(O/'private-SW-LEFT-native-original-BODY-part-ownership-v01.jpg',quality=87)
