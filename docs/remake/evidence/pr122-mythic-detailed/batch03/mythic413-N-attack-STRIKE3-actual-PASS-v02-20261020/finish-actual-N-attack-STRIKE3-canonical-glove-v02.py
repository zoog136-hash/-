"""Fixed-bodyunit actual attack, one waist registration, canonical LEFT glove."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
import numpy as np, json,hashlib
P=Path(__file__).parent
R=P/'thunder_female-N-attack-STRIKE3-new-joints-v01-service.png'
D=Path('/workspace/scratch/mythic413-N-walk-load-author-fresh-20261020-v01/N-native-rig-and-material-handoff-for-RUN-v01/complete-original-native-LEFT-forearm-hand-bracer-ornament-material.png')
r=Image.open(R).convert('RGBA');donor=Image.open(D).convert('RGBA');W,H=r.size
def polygon(points):
    m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(points,fill=255);return m
def segment(im,a,b,c,d):
    a,b,c,d=map(lambda z:np.asarray(z,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c)
    A=np.column_stack([v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]])@np.column_stack([u,[-u[1],u[0]]]).T
    t=c-A@a;iv=np.linalg.inv(A);q=-iv@t
    return im.transform((W,H),Image.Transform.AFFINE,(iv[0,0],iv[0,1],q[0],iv[1,0],iv[1,1],q[1]),Image.Resampling.BICUBIC)
mask=polygon([(511,587),(552,603),(523,640),(498,666),(477,702),(451,724),(437,703),(453,672),(464,635),(485,609)])
ImageDraw.Draw(mask).rectangle((542,619,586,671),fill=255)
ImageDraw.Draw(mask).rectangle((476,689,492,718),fill=255)
new=segment(donor,[543,517],[487,602],[534,599],[480,651])
local=r.copy();local.paste((0,0,0,0),(0,0),mask);local.alpha_composite(new)
changed=np.any(np.asarray(local)!=np.asarray(r),axis=2)
# Exact bounded original protection. New donor can extend the original glove silhouette.
union=np.maximum(np.asarray(mask),np.asarray(new.getchannel('A')))>0
assert not (changed&~union).any()
out=Image.new('RGBA',(1254,1414));out.paste(local,(-46,45))
F=P/'thunder_female-N-attack-3-STRIKE3-registered-canonical-glove-v02.png';assert not F.exists();out.save(F)
mask.save(P/'STRIKE3-original-LEFT-forearm-hand-correction-matte-v02.png');new.save(P/'STRIKE3-canonical-new-LEFT-forearm-hand-layer-v02.png')
proof={'status':'ACTUAL_STRIKE3_SOURCE_READY_PENDING_INDEPENDENT_QC','source':str(R),'source_sha256':hashlib.sha256(R.read_bytes()).hexdigest(),'output':str(F),'output_sha256':hashlib.sha256(F.read_bytes()).hexdigest(),'canonical_LEFT_forearm_hand':str(D),'canonical_LEFT_forearm_hand_sha256':hashlib.sha256(D.read_bytes()).hexdigest(),'removed_old_arm_remnants_raw_rects':[[542,619,586,671],[476,689,492,718]],'LEFT_raw_elbow_wrist':[[534,599],[480,651]],'canonical_LEFT_material_source_elbow_wrist':[[543,517],[487,602]],'original_RGBA_changes_outside_explicit_LEFT_correction':int((changed&~union).sum()),'RIGHT_arm_fullstaff_head_torso_boots':'Originalraw3001 exactRGBA, only single integer waist registration and transparentstoragepadding','physical_C_fixed':1920,'bodyunit_fixed':1.875,'common_rig_root_in_unpadded_frame':[662.8125,917.6920531878804],'native_body_registration_translation':[-46,-115],'body_registration_basis':'One actualwaistdiamond[683,650] -> preauthoredattackwaist[637,535] (oldNwaist aroundhip−3degrees +[-7,-16], globallyquantized0.2px). Neverheel/alpha/Cfit.','body_measurement':'Actual nape[650,487]±10 ->waist[683,650]±3,166.3native vsoldN160.05;+3.9% withinobservationaltorso twist','storage_translation':[0,160],'storage_size':[1254,1414],'fixed_attack_stance_native_registered_goldheels':{'LEFT':[528.5,967],'RIGHT':[720,1051]},'stance_basis':'Single bodywaist registration of naturallypaintedactualSTRIKE3; theseheelsbecomeALL6fixedstance, no perposefoot/root adjustment.','impact_frame':3,'one_shot':True,'approval_added':0}
(P/'STRIKE3-actual-body-registration-and-canonical-glove-proof-v02.json').write_text(json.dumps(proof,indent=2)+'\n')
reg={'status':'FROZEN_N_ATTACK_SHARED_RIG_REGISTRATION_NOT_ACTOR_APPROVAL','physical_canvas':1920,'bodyunit':1.875,'common_rig_root_in_unpadded_frame':[662.8125,917.6920531878804],'all6_storage_translation':[0,160],'all6_storage_size':[1254,1414],'canonical_body_authority':'ApprovedNbody1bc3 andactualattack3001 torso unit+3.9% independentlynarrowaccepted','actual_attack3_body_registration':{'raw_waist':[683,650],'fixed_target_waist':[637,535],'integer_translation':[-46,-115],'never_derived_from_foot_or_alpha':True},'fixed_all6_goldheel_stance':{'LEFT':[528.5,967],'RIGHT':[720,1051]},'impact_frame':3,'phase_order':['READY0','WINDUP1','COIL2','STRIKE3','FOLLOW4','RECOVER5'],'loop':False,'actor_approval_added':0}
assert (P/'N-attack-fixed-body-root-and-twofoot-stance-registration-v01.json').exists()
bg=Image.new('RGB',out.size,(70,70,70));bg.paste(out,mask=out.getchannel('A'));bg.thumbnail((720,810));j=P/'N-attack-STRIKE3-final-v02-whole-private.jpg';bg.save(j,quality=84,optimize=True);assert j.stat().st_size<150000
print(json.dumps({'output_sha256':proof['output_sha256'],'storage':[1254,1414],'storage_translation':[0,160],'outside_LEFT_correction_RGBA_changes':proof['original_RGBA_changes_outside_explicit_LEFT_correction'],'preview_bytes':j.stat().st_size}))
