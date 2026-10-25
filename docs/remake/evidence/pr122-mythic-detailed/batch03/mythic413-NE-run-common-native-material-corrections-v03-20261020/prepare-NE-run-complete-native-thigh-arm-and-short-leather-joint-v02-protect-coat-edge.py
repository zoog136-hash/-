from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
D=Path(__file__).parent;Q=D/'common-complete-NE-native-material-parts-v02';Q.mkdir(exist_ok=False)
B=Path('/workspace/scratch/mythic413-NE-walk-author-20261020-v01')
S=B/'NE-contact0-actual-native-background-AA-clean-r002.png';BP=B/'actual-NE-LOAD1-semantic-and-RIGHTstaff-finish-v04/original-native-body-coat-complete-RIGHTstaff-oldboots-removed-INPUT-v04.png';RP=B/'actual-NE-LOAD1-semantic-speck-finish-v03/original-native-RIGHT-complete-shoe-and-leg-material-staff-speck-excluded.png'
src=Image.open(S).convert('RGBA');a=np.array(src);body=np.array(Image.open(BP).convert('RGBA'));oldR=np.array(Image.open(RP).convert('RGBA'));W,H=src.size
def mask(poly):
 m=Image.new('L',src.size);ImageDraw.Draw(m).polygon(poly,fill=255);return np.array(m)>0
def save(arr,name):
 p=Q/name;Image.fromarray(arr).save(p);return p
def rec(p):
 b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
# Trace the native visible thigh below the original white/gold hem and to
# the RIGHT of the original blue/gold tail edge. Transfer its actual pixels
# out of fixed BODY; never fabricate flesh or threshold-paint garment colors.
thigh_poly=[(750,714),(756,711),(763,708),(770,704),(775,700),(780,696),(787,700),(794,720),(804,750),(813,790),(825,840),(832,880),(815,899),(730,899),(720,870),(711,840),(713,830),(715,820),(717,810),(719,800),(722,790),(725,780),(727,770),(729,760),(731,750),(734,740),(737,730),(741,720)]
tm=mask(thigh_poly);tm[900:]=False
fullR=oldR.copy();fullR[tm]=a[tm]
shaft=fullR.copy();shaft[940:]=0
save(fullR,'original-actual-complete-RIGHT-thigh-calf-and-shoe-staff-clean-native.png');save(shaft,'original-actual-complete-RIGHT-thigh-and-calf-native.png');save(tm.astype('uint8')*255,'actual-old-RIGHT-thigh-pixel-transfer-semantic-matte.png')
# Complete actual cuff, forearm and hand, including the western gold rim
# omitted by the prior partial material. Proximal blue elbow cap is retained
# in this actual material so it can remain fixed while distal cloth bends.
arm_poly=[(551,508),(568,519),(584,528),(600,526),(602,540),(593,555),(582,571),(570,589),(550,605),(534,622),(516,641),(495,668),(479,689),(463,698),(448,692),(438,681),(437,662),(446,642),(460,622),(478,599),(492,578),(501,560),(511,545),(526,530),(540,518)]
am=mask(arm_poly);arm=a.copy();arm[~am]=0
save(arm,'original-actual-complete-LEFT-cuff-elbow-cap-forearm-hand-native.png');save(am.astype('uint8')*255,'actual-old-complete-LEFT-cuff-forearm-removal-semantic-matte.png')
clean=body.copy();clean[tm|am]=0
hem=[(600,704),(620,714),(650,718),(675,714),(700,710),(725,706),(750,699),(775,689),(798,680)]
hy=np.interp(np.arange(W),[p[0] for p in hem],[p[1] for p in hem]);tail=(np.arange(H)[:,None]>hy[None,:])&(np.arange(W)[None,:]<820)
back=clean.copy();back[~tail]=0;front=clean.copy();front[tail]=0
save(back,'original-coattails-behind-running-legs-body-native.png');save(front,'original-whitehem-body-RIGHTstaff-foreground-native.png');save(clean,'original-actual-BODY-only-complete-old-thigh-and-arm-removed-native.png')
# One real black-leather material patch for genuinely exposed tarsal joint
# surface. Only this small actual texture patch is locally projected, not the
# source body or the shoe. A semantic surface bounds its contour.
donor=np.zeros_like(a);donor[899:930,788:812]=a[899:930,788:812]
donor_im=Image.fromarray(donor);save(donor,'actual-native-blackleather-tarsal-surface-donor-only.png')
M=np.diag([1.8,1.45]);o=np.array([810.5,938.])-M@np.array([799.5,914.5]);inv=np.linalg.inv(M);io=-inv@o
texture=donor_im.transform(src.size,Image.Transform.AFFINE,(inv[0,0],inv[0,1],io[0],inv[1,0],inv[1,1],io[1]),resample=Image.Resampling.BICUBIC)
jpoly=[(797,917),(819,917),(829,935),(824,951),(811,959),(796,950),(789,933)]
jm=mask(jpoly);joint=np.array(texture);joint[~jm]=0
save(joint,'actual-blackleather-short-tarsal-surface-native.png');save(jm.astype('uint8')*255,'actual-short-tarsal-surface-semantic-matte.png')
transferred=(body[:,:,3]>0)&tm
unchanged=~(tm|am)
proof=dict(status='ACTUAL_NATIVE_PART_TRANSFER_PREPARED_PENDING_INDEPENDENT_SEMANTIC_QC',source_inputs=[rec(p) for p in (S,BP,RP)],native_C=2432,bodyunit=2.375,source_density_or_commonroot_changed=False,RIGHT_thigh_contour=thigh_poly,LEFT_complete_forearm_contour=arm_poly,short_blackleather_joint_contour=jpoly,donor_texture_source_bbox=[788,899,812,930],local_joint_texture_projection=M.tolist(),local_joint_texture_offset=o.tolist(),native_complete_thigh_source_RGBA_mismatch=int(np.any(fullR[tm]!=a[tm],axis=1).sum()),BODY_outside_two_transfer_semantics_RGBA_mismatch=int(np.any(clean[unchanged]!=body[unchanged],axis=1).sum()),actual_old_thigh_pixels_transferred_from_BODY=int(transferred.sum()),transferred_strong_blue_diagnostic=int((transferred&(a[:,:,2]>a[:,:,0]*1.35)&(a[:,:,2]>a[:,:,1]*1.14)).sum()),transferred_white_diagnostic=int((transferred&(a[:,:,:3].min(2)>180)).sum()),RIGHT_full_staff_below900_RGBA_changed=int(np.any(clean[900:,850:]!=body[900:,850:],axis=2).sum()),source_staff_speck_not_reimported=True,whole_source_resized=False,actor_approvals_added=0)
(Q/'actual-complete-thigh-arm-and-short-joint-native-source-provenance-v01.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps({k:proof[k] for k in ['native_complete_thigh_source_RGBA_mismatch','BODY_outside_two_transfer_semantics_RGBA_mismatch','actual_old_thigh_pixels_transferred_from_BODY','transferred_strong_blue_diagnostic','transferred_white_diagnostic','RIGHT_full_staff_below900_RGBA_changed']}))
