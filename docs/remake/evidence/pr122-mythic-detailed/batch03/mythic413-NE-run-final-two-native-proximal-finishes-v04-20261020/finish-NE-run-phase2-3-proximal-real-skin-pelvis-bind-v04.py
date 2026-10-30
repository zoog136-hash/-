from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,ast
D=Path(__file__).parent;MAT=D/'common-complete-NE-native-material-parts-v03';BASE=D/'actual-NE-run-six-common-material-finish-v03';OUT=D/'actual-NE-run-two-proximal-pelvis-finish-v04';OUT.mkdir(exist_ok=False)
MP=D/'actual-NE-run-six-fixed-rig-v02/NE-run-six-actual-causal-rig-shoe-surface-and-source-contract-v02.json';model=json.loads(MP.read_text())
SIZE=1536;PAD=np.array([128.,128.]);W=H=1254;SOURCE=np.asarray(model['source_leg_raw']);P=np.asarray(model['projection']);H0=np.asarray(model['source_HFA_raw'][0])
shaft=Image.open(MAT/'original-actual-complete-RIGHT-thigh-and-calf-native.png').convert('RGBA');back=Image.open(MAT/'original-coattails-behind-running-legs-body-native.png').convert('RGBA');front=Image.open(MAT/'original-whitehem-body-RIGHTstaff-foreground-native.png').convert('RGBA')
source=(D/'author-NE-run-contact0-actual-parts-v01.py').read_text();tree=ast.parse(source);needed={'rec','affine','translate','bone_affine','forward_material'};nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in needed]
for fun in nodes:
 if fun.name=='forward_material':
  for sub in fun.body:
   if isinstance(sub,ast.FunctionDef) and sub.name=='posed':
    original=sub.body[-1];assert isinstance(original,ast.Return)
    sub.body[-1:]=[ast.Assign(targets=[ast.Name(id='bone_pose',ctx=ast.Store())],value=original.value)]+ast.parse('h=np.clip((p[1]-716)/48,0,1)\nh=h*h*(3-2*h)\nreturn (1-h)*(p+HIP_OFFSET)+h*bone_pose').body
ast.fix_missing_locations(ast.Module(nodes,[]));ns=dict(np=np,Image=Image,json=json,hashlib=hashlib,SIZE=SIZE,PAD=PAD,W=W,H=H)
exec(compile(ast.fix_missing_locations(ast.Module(nodes,[])),'actual-soft-proximal-skin-surface-pelvis-to-fixed-femur','exec'),ns)
rec=ns['rec'];translate=ns['translate'];forward=ns['forward_material'];bone_affine=ns['bone_affine']
for phase in [2,3]:
 f=model['frames'][phase];old=BASE/f'phase{phase}-actual-common-finish-v03';Q=OUT/f'phase{phase}-actual-pelvis-finish-v04';Q.mkdir();ns['Q']=Q
 controls=np.asarray(f['legs']['R']['actual_joint_controls_unpadded']);offset=controls[0]-SOURCE[0]+PAD;ns['HIP_OFFSET']=offset
 newR=forward(shaft,SOURCE,controls,'RIGHT-actual-proximal-skin-pelvis-bound-thigh-calf')
 oldR=Image.open(old/'R-actual-complete-visible-thigh-and-calf-actual-posed-material.png').convert('RGBA')
 support=np.any(np.asarray(newR)!=np.asarray(oldR),axis=2)
 body_raw=np.asarray(f['body_node_raw']);out=translate(back,body_raw)
 oldfeet=Path(f['output']['path']).parent
 for side in ['L','R']:
  out.alpha_composite(Image.open(old/(side+'-genuine-short-leather-tarsal-joint-actual-posed-material.png')).convert('RGBA'))
  out.alpha_composite(newR if side=='R' else Image.open(old/'L-actual-complete-visible-thigh-and-calf-actual-posed-material.png').convert('RGBA'))
  out.alpha_composite(Image.open(oldfeet/(side+'-original-complete-shoe-rigid3D-projection.png')).convert('RGBA'))
 out.alpha_composite(Image.open(old/'LEFT-complete-cuff-elbow-cap-forearm-hand-counterphase-actual-posed-material.png').convert('RGBA'))
 fixed_foreground=translate(front,body_raw);out.alpha_composite(fixed_foreground)
 oldP=old/f'thunder_female-NE-run-phase{phase}-actual-common-finish-v03.png';oldarr=np.asarray(Image.open(oldP).convert('RGBA'));arr=np.array(out)
 protected=np.asarray(fixed_foreground)[:,:,3]>=250
 # Preserve all existing foreground white/gold hem/torso/staff and every
 # pixel outside this actual proximal skin-surface support, exactly.
 arr[(~support)|protected]=oldarr[(~support)|protected]
 output=Q/f'thunder_female-NE-run-phase{phase}-actual-pelvis-finish-v04.png';Image.fromarray(arr).save(output)
 Image.fromarray(support.astype('uint8')*255).save(Q/'actual-proximal-RIGHT-surface-change-support-mask.png');Image.fromarray(protected.astype('uint8')*255).save(Q/'unchanged-original-whitehem-body-full-RIGHTstaff-foreground-protection-mask.png')
 changed=np.any(arr!=oldarr,axis=2);yy,xx=np.where(changed);bbox=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)] if len(xx) else None
 # Actual flexible skin chart: source pelvis cap follows the body, then
 # blends to the exact fixed femur chart. This projects the real mesh and
 # leaves physical hip/knee/ankle bones unchanged.
 meshfile=Q/'RIGHT-actual-proximal-skin-pelvis-bound-thigh-calf-actual-forward-mesh.json';mesh=json.loads(meshfile.read_text());mesh.update(proximal_skin_binding='source_y<=716 actual source pelvis cap; smoothstep to same frozen femur by source_y764',pelvis_image_translation_with_storage=offset.tolist(),whole_fixed_leg_controls_unchanged=True);meshfile.write_text(json.dumps(mesh,indent=2)+'\n')
 note=dict(status='ACTUAL_TWO_PROXIMAL_SOFT_SKIN_BIND_FINISH_PENDING_INDEPENDENT_SOURCE_GATE',phase=phase,output=rec(output),baseline=rec(oldP),unchanged_frozen_physical_rig=rec(MP),unchanged_actual_joint_controls=f['legs'],unchanged_body_node=f['body_node_XYZ'],original_actual_skin_and_garter_native_source=rec(MAT/'original-actual-complete-RIGHT-thigh-and-calf-native.png'),actual_material_operator='Native source surface pinned to pelvis up to y716, smoothly blended to same frozen femur by y764. No new flesh painted; no change to source garment or source calf/shoe.',changed_RGBA_pixels=int(changed.sum()),changed_bbox_with_storage=bbox,outside_actual_R_proximal_support_RGBA_mismatch=int(np.any(arr[~support]!=oldarr[~support],axis=1).sum()),original_foreground_whitehem_body_staff_RGBA_mismatch=int(np.any(arr[protected]!=oldarr[protected],axis=1).sum()),fixed_original_LEFT_proximal_skin_and_garter_body_input_deleted=False,LEFT_leg_shoe_and_arm_component_inputs_changed=False,original_coattail_body_layer_changed=False,heel_and_all_bone_controls_changed=False,C=2432,bodyunit=2.375,common_root=model['common_rig_root_unpadded'],storage_translation=PAD.tolist(),actor_approvals_added=0)
 (Q/'actual-two-proximal-pelvis-skin-bind-preservation-proof-v04.json').write_text(json.dumps(note,indent=2)+'\n');print(json.dumps(dict(phase=phase,output=rec(output),changed_RGBA=note['changed_RGBA_pixels'],bbox=bbox,protected_foreground_RGBA_mismatch=note['original_foreground_whitehem_body_staff_RGBA_mismatch'],outside_support_RGBA_mismatch=note['outside_actual_R_proximal_support_RGBA_mismatch'])),flush=True)
