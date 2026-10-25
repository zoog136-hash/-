from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,ast,sys
D=Path(__file__).parent;BASE=D/'contact0-actual-NE-run-v01';MAT=D/'common-complete-NE-native-material-parts-v03';OUT=D/'actual-NE-run-six-common-material-finish-v03';OUT.mkdir(exist_ok=True)
MP=D/'actual-NE-run-six-fixed-rig-v02/NE-run-six-actual-causal-rig-shoe-surface-and-source-contract-v02.json';model=json.loads(MP.read_text())
SIZE=1536;PAD=np.array([128.,128.]);W=H=1254
shaft=Image.open(MAT/'original-actual-complete-RIGHT-thigh-and-calf-native.png').convert('RGBA')
arm=Image.open(MAT/'original-actual-complete-LEFT-cuff-elbow-cap-forearm-hand-native.png').convert('RGBA')
back=Image.open(MAT/'original-coattails-behind-running-legs-body-native.png').convert('RGBA')
front=Image.open(MAT/'original-whitehem-body-RIGHTstaff-foreground-native.png').convert('RGBA')
joint=Image.open(MAT/'actual-blackleather-short-tarsal-surface-native.png').convert('RGBA')

# Keep the proven forward native-material operator, with explicit optional
# actual calf/rigid-shoe affine maps for this genuine soft ankle articulation.
source=(D/'author-NE-run-contact0-actual-parts-v01.py').read_text();tree=ast.parse(source)
nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in {'rec','affine','translate','bone_affine','forward_material'}]
for i,n in enumerate(nodes):
 if n.name=='forward_material':
  text=ast.get_source_segment(source,n).replace('target_knots, name):','target_knots, name, actual_affines=None):')
  needle='m1,o1=bone_affine(sp[1],sp[2],tp[1],tp[2])'
  assert needle in text
  text=text.replace(needle,needle+'\n    if actual_affines is not None:\n        (m0,o0),(m1,o1)=actual_affines')
  nodes[i]=ast.parse(text).body[0]
ns=dict(np=np,Image=Image,json=json,hashlib=hashlib,SIZE=SIZE,PAD=PAD,W=W,H=H)
exec(compile(ast.Module(nodes,[]),'native-material-operator-with-actual-calf-foot-affines','exec'),ns)
rec=ns['rec'];translate=ns['translate'];bone_affine=ns['bone_affine'];forward=ns['forward_material']
SOURCE_R=np.asarray(model['source_leg_raw']);ARMS=[[590,615],[550,645],[475,650],[475,650],[550,645],[590,615]]
phases=[int(x) for x in sys.argv[1:]] or list(range(6))
for phase in phases:
 f=model['frames'][phase];Q=OUT/f'phase{phase}-actual-common-finish-v03';Q.mkdir(exist_ok=False);ns['Q']=Q
 olddir=Path(f['output']['path']).parent;body_raw=np.asarray(f['body_node_raw']);layers={};protect=np.zeros((SIZE,SIZE),bool);joint_union=np.zeros((SIZE,SIZE),bool)
 for side in ['R','L']:
  controls=np.asarray(f['legs'][side]['actual_joint_controls_unpadded'])
  calf=forward(shaft,SOURCE_R,controls,side+'-actual-complete-visible-thigh-and-calf')
  oldcalf=Image.open(olddir/(side+'-actual-complete-thigh-calf-actual-posed-material.png')).convert('RGBA')
  footpath=olddir/(side+'-original-complete-shoe-rigid3D-projection.png');foot=Image.open(footpath).convert('RGBA')
  cm,co=bone_affine(SOURCE_R[1],SOURCE_R[2],controls[1],controls[2])
  fm=np.asarray(f['legs'][side]['shoe_image_affine']);fo=np.asarray(f['legs'][side]['shoe_image_offset'])
  sk=np.array([[811.,917.],[811.,944.],[811.,970.]])
  tk=np.array([cm@sk[0]+co,controls[2],fm@sk[2]+fo-PAD])
  jp=forward(joint,sk,tk,side+'-genuine-short-leather-tarsal-joint',actual_affines=((cm,co+PAD),(fm,fo)))
  pa=np.asarray(jp)[:,:,3]>0;joint_union|=pa
  protect|=pa&((np.asarray(oldcalf)[:,:,3]>=250)|(np.asarray(foot)[:,:,3]>=250))
  layers[side]=(jp,calf,foot)
  jpmeta=Q/(side+'-genuine-short-leather-tarsal-joint-actual-forward-mesh.json');meta=json.loads(jpmeta.read_text());meta.update(actual_proximal_calf_affine=dict(matrix=cm.tolist(),offset_with_storage=(co+PAD).tolist()),actual_distal_rigid_shoe_affine=dict(matrix=fm.tolist(),offset_with_storage=fo.tolist()),method='Continuous actual-material forward mesh, actual calf and rigid3D foot endpoint affine maps, genuine localized blackleather joint surface, no endpoint extrapolation, no wholeboot change',original_complete_shoe_input=rec(footpath));jpmeta.write_text(json.dumps(meta,indent=2)+'\n')
 arm_source=np.array([[559.,520.],[559.,550.],[481.,645.]])
 arm_target=np.array([np.array([559.,520.])+body_raw,np.array([559.,550.])+body_raw,np.array(ARMS[phase])+body_raw])
 moved_arm=forward(arm,arm_source,arm_target,'LEFT-complete-cuff-elbow-cap-forearm-hand-counterphase')
 out=translate(back,body_raw)
 for side in ['L','R']:
  for layer in layers[side]:out.alpha_composite(layer)
 out.alpha_composite(moved_arm);out.alpha_composite(translate(front,body_raw))
 arr=np.array(out);old=np.array(Image.open(f['output']['path']).convert('RGBA'));arr[protect]=old[protect];out=Image.fromarray(arr)
 target=Q/f'thunder_female-NE-run-phase{phase}-actual-common-finish-v03.png';out.save(target)
 diff=np.any(arr!=old,axis=2);yy,xx=np.where(diff);bbox=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)] if len(xx) else None
 Image.fromarray(protect.astype('uint8')*255).save(Q/'actual-good-opaque-calf-and-whole-shoe-protection-mask.png');Image.fromarray(joint_union.astype('uint8')*255).save(Q/'actual-local-short-tarsal-joint-surface-support-mask.png')
 provenance=dict(status='ACTUAL_SHARED_THIGH_ARM_AND_REAL_TARSAL_MATERIAL_FINISH_PENDING_SOURCE_QC',output=rec(target),baseline_source=rec(Path(f['output']['path'])),unchanged_frozen_rig_contract=rec(MP),unchanged_exact_frame_controls=f['legs'],unchanged_body_node=f['body_node_XYZ'],unchanged_C=model['native_C'],unchanged_bodyunit=model['bodyunit'],unchanged_common_root=model['common_rig_root_unpadded'],unchanged_storage=model['storage_translation'],actual_material_contract=rec(MAT/'actual-complete-thigh-arm-and-short-joint-native-source-provenance-v01.json'),actual_complete_shoe_projections_reused_byte_for_byte=True,protected_good_opaque_calf_and_shoe_pixels=int(protect.sum()),protected_RGBA_mismatch=int(np.any(arr[protect]!=old[protect],axis=1).sum()),joint_RGB_is_actual_native_blackleather_donor=True,new_skin_painted=False,native_original_visible_thigh_pixels_transferred_into_correct_moving_part=True,original_complete_cuff_and_elbow_cap_native_material=True,changed_RGBA_pixels=int(diff.sum()),changed_bbox_with_storage=bbox,body_staff_head_cloth_native_inputs_preserved=True,whole_source_resized=False,perpose_C_or_root_fit=False,actor_approvals_added=0)
 (Q/'actual-common-material-finish-and-preservation-provenance-v03.json').write_text(json.dumps(provenance,indent=2)+'\n')
 print(json.dumps(dict(phase=phase,output=rec(target),changed_RGBA=int(diff.sum()),protected_RGBA_mismatch=provenance['protected_RGBA_mismatch'])),flush=True)
