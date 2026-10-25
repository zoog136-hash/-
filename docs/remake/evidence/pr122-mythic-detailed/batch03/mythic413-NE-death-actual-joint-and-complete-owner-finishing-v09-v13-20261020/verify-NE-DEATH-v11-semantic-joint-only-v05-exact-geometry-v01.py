from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
B=Path(__file__).parent
oldp=B/'actual-NE-DEATH-six-native-v05/actual-NE-DEATH-six-source-contract-v05.json';newp=B/'actual-NE-DEATH-six-native-v11/actual-NE-DEATH-six-source-contract-v11.json';old=json.loads(oldp.read_text());new=json.loads(newp.read_text());ROOT=np.array(new['common_unpadded_root']);P=np.array([[10/9,0,0],[0,1,-1.]])
leg=np.array(Image.open('/workspace/scratch/mythic413-NE-run-author-20261020-v01/common-complete-NE-native-material-parts-v03/original-actual-complete-RIGHT-thigh-and-calf-native.png'));yy,xx=np.where(leg[:,:,3]>0);take=(yy>=798)&(yy<=836);x0,x1=xx[take].min()-.5,xx[take].max()+.5;y0,y1=797.5,836.5;uv=np.array([[x,y]for x in [x0,x1]for y in [y0,y1]])
def projected(q):return ROOT+q@P.T+256
rows=[]
for fo,fn in zip(old['frames'],new['frames']):
 ph=fn['phase'];allowed=np.zeros((2304,2304),bool);regions=[]
 def box(name,points,margin=3):
  pp=projected(np.array(points));lo=np.maximum(0,np.floor(pp.min(axis=0)-margin).astype(int));hi=np.minimum(2303,np.ceil(pp.max(axis=0)+margin).astype(int));allowed[lo[1]:hi[1]+1,lo[0]:hi[0]+1]=True;regions.append(dict(name=name,stored_bbox=[int(lo[0]),int(lo[1]),int(hi[0]),int(hi[1])]))
 for side in ['R','L']:
  bo,bn=fo['bones'][side],fn['bones'][side]
  for k in ['hip','knee','ankle','heel','source_foot_U','source_foot_V','foot_SO3']:assert np.array_equal(np.array(bo[k]),np.array(bn[k]))
  m=bn['actual_native_rounded_knee'];K=np.array(bn['knee']);MT=np.array(m['source_femur_world_UV']);MC=np.array(m['source_calf_world_UV']);points=np.r_[K+(uv-[790,815])@MT.T,K+(uv-[790,815])@MC.T];box(side+' original native knee material y798..836, both unchanged parent planes',points)
  a=bn['actual_native_rounded_ankle'];E=np.array(a['orthonormal_surface_basis']);r=np.array(a['all_edge_texel_quad_expanded_radii']);C=np.array(a['center_world']);extent=np.sqrt(np.diag(P@E@np.diag(r*r)@E.T@P.T));pc=projected(C);lo=np.floor(pc-extent-3).astype(int);hi=np.ceil(pc+extent+3).astype(int);allowed[lo[1]:hi[1]+1,lo[0]:hi[0]+1]=True;regions.append(dict(name=side+' actual narrow ankle leather interface',stored_bbox=[int(lo[0]),int(lo[1]),int(hi[0]),int(hi[1])]))
 for k in ['state','pelvis_world','pelvis_SO3','torso_waist_world','torso_SO3','head_neck_world','head_SO3','cloth_native_model']:assert fo[k]==fn[k]
 for side in ['R','L']:
  for k in ['shoulder','elbow','upperbone_length','upperarm_source_U','upperarm_source_V','source_shoulder','forearm_source_U','forearm_source_V','source_elbow','whole_grip_fullstaff_rigid','dedicated_weapon_catch_progress']:assert fo['arms'][side][k]==fn['arms'][side][k]
 # The native curved sleeve ownership transfer is declared independently of
 # observed frame differences: fixed original-source rectangle and three
 # pre-existing receiving nodes. The new skin is a convex blend of the two
 # unchanged arm planes and is inside these projected bounds.
 su=np.array([[x,y]for x in [774.5,875.5]for y in [509.5,636.5]])
 r=fn['arms']['R'];CU=np.column_stack([r['upperarm_source_U'],r['upperarm_source_V']]);CF=np.column_stack([r['forearm_source_U'],r['forearm_source_V']]);CT=np.array(fn['torso_SO3'])@np.column_stack([new['source_capture_body_U'],new['source_capture_body_V']]);E=np.array(r['elbow']);W=np.array(fn['torso_waist_world']);points=np.r_[E+(su-r['source_elbow'])@CU.T,E+(su-r['source_elbow'])@CF.T,W+(su-[727,630])@CT.T];box('RIGHT actual complete curved white/gold sleeve ownership native rect775..875/510..636',points)
 a=np.array(Image.open(fo['path']).convert('RGBA'));b=np.array(Image.open(fn['path']).convert('RGBA'));diff=np.any(a!=b,axis=2);outside=int(np.sum(diff&~allowed));assert outside==0,(ph,outside)
 rows.append(dict(phase=ph,changed_RGBA_pixels=int(diff.sum()),changed_RGBA_outside_declared_semantic_joint_bounds=outside,allowed_bound_pixels=int(allowed.sum()),allowed_regions=regions,all_original_body_states_bones_and_rigid_nodes_exact=True))
# Fixed native staff and distal grip material remains byte exact. Proximal
# sleeve source changes are outside this independently declared pole node.
a=np.array(Image.open(B/'actual-NE-DEATH-six-native-v05/native-RIGHT-complete-forearm-grip-staff-both-ends-native.png'));b=np.array(Image.open(B/'actual-NE-DEATH-six-native-v11/native-RIGHT-complete-forearm-grip-staff-both-ends-native.png'));assert np.array_equal(a[:,865:],b[:,865:])
for name in ['native-head-face-bun-and-original-hair.png','native-LEFT-upperarm-native.png','native-LEFT-complete-cuff-forearm-hand-native.png','native-ALL-original-bluegold-coattails-complete-bluegold-coattail.png']:
 ap=B/'actual-NE-DEATH-six-native-v05'/name;bp=B/'actual-NE-DEATH-six-native-v11'/name
 if ap.exists() and bp.exists():assert ap.read_bytes()==bp.read_bytes()
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
out=B/'NE-DEATH-v11-v05-unchanged-bones-source-gear-and-joint-only-RGBA-binding-v01.json';assert not out.exists();out.write_text(json.dumps(dict(status='PASS_EXACT_V05_TO_V11_ONLY_DECLARED_ACTUAL_NATIVE_JOINT_MATERIAL_FINISH',old_contract=pin(oldp),new_contract=pin(newp),source_fixed_C_root_bodyunit_profile_storage_unchanged=True,all12_original_leg_bones_and_every_parent_SO3_rigid_node_exact=True,complete_original_RIGHTgrip_staff_native_x865plus_RGBA_exact=True,changed_RGBA_outside_declared_semantic_joints_all6=0,regions_defined_before_frame_differences=True,rows=rows,limits=['Native source ownership rectangles and exact pre-existing material planes define bounds before reading bitmap differences.','Both original knees and narrow ankle leather interfaces plus complete RIGHT curved white/gold sleeve are the only allowed changes.','No whole pose fitting, body scale, source regeneration, staff motion or profile change.'],actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(proof=pin(out),outside_RGBA_all6=0,changed=[r['changed_RGBA_pixels']for r in rows])))
