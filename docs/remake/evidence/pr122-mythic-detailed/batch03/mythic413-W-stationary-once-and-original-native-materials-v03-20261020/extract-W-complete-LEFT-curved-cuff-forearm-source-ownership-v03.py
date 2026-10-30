from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
from scipy.ndimage import label
D=Path(__file__).parent
R=D/'W-new-native-one-time-body-density-C2560-root-registration-v01.json'
r=json.loads(R.read_text());S=Path(r['source']['path']);src=np.asarray(Image.open(S).convert('RGBA'));H,W=src.shape[:2]
O=D/'common-own-W-native-LEFT-materials-v03';O.mkdir(exist_ok=False)
def rec(p):
 b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
# The curved proximal cut follows the original blue/gold elbow cap.
# W actual cuff outer contour follows white-gold sleeve, black bracer and every
# finger. Separate blue coat and hair ribbons remain BODY. Top proximal gold
# flare is owned by the complete sleeve. Tight contour remains pending actual
# native ownership view before articulated production.
poly=[(690, 479), (699, 477), (714, 482), (737, 488), (749, 493), (758, 503), (751, 514), (748, 521), (754, 533), (755, 541), (752, 550), (747, 559), (744, 575), (740, 584), (744, 598), (751, 612), (755, 630), (754, 647), (751, 661), (754, 675), (751, 690), (743, 700), (734, 708), (724, 716), (718, 712), (720, 702), (723, 694), (719, 698), (714, 701), (712, 697), (714, 685), (709, 693), (704, 694), (703, 686), (705, 670), (701, 662), (702, 650), (705, 635), (705, 626), (699, 621), (700, 612), (705, 600), (702, 585), (695, 571), (681, 571), (675, 568), (669, 569), (662, 564), (659, 559), (665, 539), (673, 520), (680, 502), (677, 499), (683, 487)]
m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(poly,fill=255);mask=np.asarray(m)>0
part=np.zeros_like(src);part[mask]=src[mask];body=src.copy();body[mask]=0
support=mask&(src[:,:,3]>0);m=Image.fromarray(support.astype('uint8')*255)
ap=O/'original-actual-W-LEFT-far-complete-curved-cuff-forearm-free-hand-material-v03.png';Image.fromarray(part).save(ap)
bp=O/'actual-W-LEFT-forearm-only-old-erased-BODY-original-RIGHT-staff-arms-and-boots-v03.png';Image.fromarray(body).save(bp)
mp=O/'original-actual-W-LEFT-complete-curved-cuff-forearm-hand-native-ownership-mask-v03.png';m.save(mp)
reconstructed=body.copy();reconstructed[mask]=part[mask];assert np.array_equal(reconstructed,src)
assert np.count_nonzero(np.any(body[support]!=0,axis=1))==0
yy,xx=np.indices((H,W));protect=((xx<=445)|((xx>=345)&(xx<=620)&(yy>=400)&(yy<=550)))&(src[:,:,3]>0)
rp=O/'original-W-RIGHT-near-foregrip-fullstaff-conservative-native-preservation-mask-v03.png';Image.fromarray(protect.astype('uint8')*255).save(rp)
assert np.count_nonzero(support&protect)==0
lab,num=label(part[:,:,3]>=100);counts=np.bincount(lab.ravel())[1:];large=sorted((int(n)for n in counts if n>=200),reverse=True);assert len(large)==1
j=dict(schema='MYTHIC413_W_COMPLETE_LEFT_CURVED_CUFF_NATIVE_OWNERSHIP_READONLY_HANDOFF_V03',status='NATIVE_INPUT_PENDING_ACTUAL_ARTICULATED_JOINT_QC',source=rec(S),once_body_registration=rec(R),C=r['new_W_fixed_C'],bodyunit=r['new_W_fixed_bodyunit'],common_unpadded_root=r['common_rig_root_in_unpadded_frame'],storage_translation=r['production_storage_translation'],native_size=[W,H],parts={'LEFT-far-complete-curved-cuff-forearm-free-hand':rec(ap)},semantic_mattes={'LEFT-far-complete-curved-cuff-forearm-free-hand':rec(mp)},body_inputs={'LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots':dict(body=rec(bp),old_forearm_erasure_support=rec(mp))},fixed_original_RIGHTgear_conservative_native_support=rec(rp),actual_native_controls=dict(LEFT_far_visible_proximal_anchor=[699.,487.],LEFT_far_cuff_elbow=[701.,518.],LEFT_far_wrist=[735.,640.]),controls_scope='Native visible proximal cuff/blue elbow cap and wrist controls, not uniquely measured hidden 3D joints. Wrist control is inside the original black cuff/skin join.',source_ownership_recipe=dict(proximal_and_outer_separator_polygon=poly,native_output_source_RGBA_mismatch=0,source_reconstruction_changed_pixels=0,old_LEFT_material_RGBA_remaining_in_erased_BODY=0,complete_actual_LEFT_strong_alpha100_components_ge200=large),fixed_region_scope='Conservative source-alpha support includes the entire RIGHT weapon/foregrip and some adjacent fixed costume. It is preservation only, not a claimed exact extracted RIGHT animation module. Dedicated RIGHT extraction is owned by the separate ATTACK author.',source_resampling=False,old_original_source_changed=False,body_gate_or_action_approval_added=False,actor_approvals_added=0)
out=O/'W-own-native-complete-LEFT-and-old-erased-BODY-readonly-handoff-v03.json';out.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(handoff=rec(out),actual_LEFT=rec(ap),body=rec(bp),strong=large,source_reconstruction_changed=0)))
# Bounded private source ownership view; excluded from production archives.
bbox=(640,460,780,730);board=Image.new('RGB',(420,270),(132,132,132))
for i,a in enumerate([src,body,part]):
 p=Image.fromarray(a).crop(bbox);bg=Image.new('RGBA',p.size,(132,132,132,255));bg.alpha_composite(p);board.paste(bg.convert('RGB'),(140*i,0))
board.save(O/'private-W-LEFT-native-original-BODY-part-ownership-v03.jpg',quality=87)
