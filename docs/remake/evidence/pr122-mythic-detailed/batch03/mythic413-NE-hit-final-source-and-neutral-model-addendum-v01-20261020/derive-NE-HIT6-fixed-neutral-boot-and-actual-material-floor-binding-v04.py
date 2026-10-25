from pathlib import Path
from PIL import Image
import json, hashlib, numpy as np

D = Path(__file__).parent
V = D / 'actual-NE-HIT6-own-native-settled-guard-v04'
RP = V / 'NE-HIT6-exact-final-source-roster-v04.json'
NEUTRAL = Path('/workspace/scratch/mythic413-NE-idle-author-20261020-v01/NE-IDLE-v02-original-neutral-material-sole-staff-and-whole-six-floor-binding-v01.json')

def rec(p):
    p = Path(p); b = p.read_bytes()
    return dict(path=str(p), sha256=hashlib.sha256(b).hexdigest(), bytes=len(b))

assert rec(NEUTRAL)['sha256'] == 'ea0cc150f04fe46e738eacff3d0f75f263f11570992d60ba56b5fe1ed06dd771'
n = json.loads(NEUTRAL.read_text()); r = json.loads(RP.read_text())
original = np.asarray(Image.open(r['source_identity']['path']).convert('RGBA'))
assert r['source_identity'] == n['original_source']
assert r['common_rig_root_unpadded'] == n['common_unpadded_root']
H,W = original.shape[:2]; SIZE=1536; PAD=np.array([128,128]); ROOT=r['common_rig_root_unpadded']
footmasks=[]; models=[]
for f in n['shoe_capture_models']:
    maskrec=f['exact_native_alpha_support_mask']; assert rec(maskrec['path'])==maskrec
    mask=np.asarray(Image.open(maskrec['path']))>0
    y,x=np.where(mask); h=np.asarray(f['visible_heel_native']); u=f['source_U'][2]; v=f['source_V'][2]
    z=f['source_plane_anchor_world'][2]+(x-h[0])*u+(y-h[1])*v
    minimum=float(z.min()-.5*(abs(u)+abs(v))-f['native_guard'])
    assert abs(minimum-1)<1e-10
    big=np.zeros((SIZE,SIZE),bool);big[128:128+H,128:128+W]=mask;footmasks.append(big)
    models.append(dict(side=f['side'],exact_original_foot_model=f,all_source_alpha_texel_quad_count=len(x),guarded_source_min_Z=minimum))
assert not np.any(footmasks[0]&footmasks[1])
capture=n['all_remaining_material_capture_plane']
assert capture['world_anchor'][1]==180
assert capture['U']==[1.,0.,0.] and capture['V']==[0.,0.,-1.]
frames=[]
for f in r['frames']:
    assert rec(f['source']['path'])==f['source']
    a=np.asarray(Image.open(f['source']['path']).convert('RGBA'));alpha=a[:,:,3]>0
    shoes=[]
    for i, model in enumerate(models):
        mask=footmasks[i];native=mask[128:128+H,128:128+W]
        mismatch=int(np.any(a[128:128+H,128:128+W][native]!=original[native],axis=1).sum());assert mismatch==0
        assert int((alpha&mask).sum())==model['all_source_alpha_texel_quad_count']
        shoes.append(dict(side=model['side'],original_native_boot_RGBA_mismatch=mismatch,actual_alpha_texel_quad_count=int((alpha&mask).sum()),guard_native=2.,all_centered_texel_quad_guarded_min_Z=model['guarded_source_min_Z']))
    remaining=alpha&~(footmasks[0]|footmasks[1]);yy,xx=np.where(remaining)
    # One unchanged vertical capture plane. The real HIT material field and
    # articulated arm supply X/Y; this plane supplies the explicit compatible
    # height. No fitted per-frame ground, root, scale, or stance adjustment.
    minimum=float(ROOT[1]+.45*180-(yy-128).max()-.5-8)
    assert minimum>0
    assert int(remaining.sum())+sum(q['actual_alpha_texel_quad_count']for q in shoes)==int(alpha.sum())
    frames.append(dict(phase=f['phase'],actual_source=f['source'],shoes=shoes,remaining_actual_head_torso_guard_legs_cloth_ribbon_fullstaff=dict(alpha_texel_quad_count=int(remaining.sum()),D_native=180.,guard_native=8.,all_centered_texel_quad_guarded_min_Z=minimum),all_actual_alpha_texels_assigned_exactly_once=True,storage_only_translation=[128,128]))
j=dict(schema='MYTHIC413_NE_HIT_EXACT_FIXED_NEUTRAL_BOOTS_ACTUAL_SIX_MATERIAL_SURFACE_BINDING_V04',status='FINITE_ONCE_CHOSEN_MODEL_PENDING_INDEPENDENT_AUDIT',exact_HIT_final_roster=rec(RP),neutral_once_capture_reference=rec(NEUTRAL),unchanged_original_native_identity=r['source_identity'],C=2432,bodyunit=2.375,common_unpadded_root=ROOT,projection=n['projection'],shoe_capture_models=models,remaining_material_plane=capture,frames=frames,stationary_fixed_material_controls_shared_all6=True,perpose_C_root_ground_or_foot_fit=False,scope_and_limits=n['limits']+['The neutral original source99ffa boots and once-chosen capture models are reused only after independently checking every actual HIT boot RGBA and every actual six-frame raster texel. RUN pose0 is not substituted.','This is a bounded compatible material/support construction, not uniquely recovered hidden anatomy or exact 3D body bone evidence. Actual head/torso and guard fields supply the material motion; numerical positive bounds do not replace actual source/cycle quality approval.'],role_seconds=.22,phase_seconds=.22/6,Godot_hit_window_or_profile_modified=False,actor_approvals_added=0)
out=V/'NE-HIT6-exact-original-neutral-boots-and-actual-six-material-floor-binding-v04.json'
with out.open('x')as f:f.write(json.dumps(j,indent=2)+'\n')
print(json.dumps(dict(model=rec(out),all_boot_RGBA_mismatches=0,guarded_boot_minima=[m['guarded_source_min_Z']for m in models],all_remaining_guarded_minimum=min(f['remaining_actual_head_torso_guard_legs_cloth_ribbon_fullstaff']['all_centered_texel_quad_guarded_min_Z']for f in frames)),separators=(',',':')))
