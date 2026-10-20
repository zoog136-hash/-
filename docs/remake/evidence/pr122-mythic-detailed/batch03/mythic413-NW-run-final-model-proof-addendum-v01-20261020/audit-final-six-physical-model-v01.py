"""Independent, read-only recomputation of exact six-pose authored model.

No image preview/generation, source edits, game, Git, or approval changes.
The 2.5D shoe surfaces and eight-native thickness are declared constructions.
"""
from pathlib import Path
import hashlib, json, math
import numpy as np
from PIL import Image

S = Path('/workspace/scratch')
BASE = S/'mythic413-NW-run-load-fresh-20261020-v01'
OUT = S/'mythic413-nw-run-cycle-qc-fresh-v02-20261020'
P = BASE/'final-six-actual-causal-rig-and-full-foot-surface-AIR-bounds-v01.json'
RAW = P.read_bytes()
assert hashlib.sha256(RAW).hexdigest() == '153dff6932bd7fef3943bb5bc7ea957775508994b3a928b63602b74d685707e2'
D = json.loads(RAW)
RP = Path(D['roster']['path'])
RB = RP.read_bytes()
assert hashlib.sha256(RB).hexdigest() == D['roster']['sha256'] == '92f75e0bf221fa58aa1e7c73da197d3ad0b005d8881adbb453760568ed449aa7'
ROSTER = json.loads(RB)

def project(v):
    v = np.asarray(v, dtype=float)
    return np.stack((v[..., 0]/.9, v[..., 1]-v[..., 2]), axis=-1)

def lengths(v):
    return np.array([np.linalg.norm(v[a]-v[b]) for a,b in ((0,1),(0,2),(1,2))])

templates = {}
canonical_lengths = None
template_results = []
for name,t in D['foot_surface_templates'].items():
    src = Path(t['actual_source_path'])
    raw = src.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == t['actual_source_sha256']
    image = np.array(Image.open(src).convert('RGBA'))
    marks = np.asarray(t['actual_marker_raw'], dtype=float)
    xyz = np.asarray(t['fixed_marker_XYZ'], dtype=float)
    plane = np.linalg.solve(np.c_[marks, np.ones(3)], xyz)
    assert np.max(np.abs(plane-t['pixel_to_authored_surface_XYZ_affine'])) < 1e-9
    assert np.max(np.abs(project(xyz)-marks)) < 1e-9
    yy,xx = np.where(image[:,:,3] > 0)
    pixels = np.c_[xx,yy,np.ones(len(xx))]
    verts = pixels @ plane
    assert len(xx) == t['opaque_or_AA_texel_vertices']
    assert abs(float(verts[:,2].min())-t['all_texel_centers_minZ']) < 1e-9
    assert abs(float(verts[:,2].max())-t['all_texel_centers_maxZ']) < 1e-9
    tri = lengths(xyz)
    if canonical_lengths is None: canonical_lengths = tri
    assert np.max(np.abs(tri-canonical_lengths)) < 1e-9
    templates[name] = (plane, verts, xyz, marks, image)
    template_results.append(dict(name=name, sha256=t['actual_source_sha256'],
        nonzero_alpha_texels=len(xx), common_boot_triangle_lengths=tri.tolist(),
        max_template_projection_error=float(np.abs(project(xyz)-marks).max())))

frame_results = []
staff_lengths = []
max_bone_error = max_control_error = max_rigid_error = 0.
pose_images = []
PXY = np.array([[1/.9,0],[0,1],[0,-1.]])
for f,r in zip(D['frames'], ROSTER['frames']):
    phase = f['phase']
    assert phase == r['phase']
    assert f['native_C'] == r['native_C'] == 2560
    assert f['common_root_unpadded'] == r['common_rig_root_in_unpadded_frame'] == [669,1267.95]
    assert f['storage_translation'] == r['storage_translation']
    assert f['actual_body_bob_raw'] == r['body_node_bob_and_lean']
    path = Path(f['actual_image']['path'])
    raw = path.read_bytes()
    assert hashlib.sha256(raw).hexdigest() == f['actual_image']['sha256'] == r['actual_final_image']['sha256']
    pose = np.array(Image.open(path).convert('RGBA'))
    pose_images.append(pose)
    result = dict(phase=phase, actual_source_sha256=hashlib.sha256(raw).hexdigest(), legs={}, feet={})
    for side in ('L','R'):
        leg = f['leg_controls'][side]
        controls = np.array(r[f'actual_{side}_hip_knee_tarsal_controls_unpadded'], dtype=float)
        assert np.array_equal(np.asarray(leg['actual_control_raw']), controls)
        xyz = np.array(leg['joint_XYZ'], dtype=float)
        err = float(np.abs(project(xyz)-controls).max())
        bone = np.linalg.norm(np.diff(xyz,axis=0),axis=1)
        assert err < 1e-9 and np.abs(bone-250).max() < 1e-9
        max_control_error = max(max_control_error,err)
        max_bone_error = max(max_bone_error,float(np.abs(bone-250).max()))
        result['legs'][side] = dict(bones=bone.tolist(), actual_projection_error=err)
        foot = f['feet'][side]
        plane,verts,marks,rawmarks,template_image = templates[foot['actual_fixed_surface_template']]
        rot = np.array(foot['rigid_rotation'], dtype=float)
        trans = np.array(foot['rigid_translation_XYZ'], dtype=float)
        ortho = float(np.abs(rot.T@rot-np.eye(3)).max())
        assert ortho < 1e-9 and abs(np.linalg.det(rot)-1)<1e-9
        max_rigid_error = max(max_rigid_error,ortho)
        moved_marks = marks@rot.T+trans
        assert np.abs(moved_marks-foot['actual_HFA_XYZ']).max()<1e-9
        assert np.abs(project(moved_marks)-foot['actual_projected_HFA']).max()<1e-9
        assert np.abs(moved_marks[2]-xyz[2]).max()<1e-9
        moved = verts@rot.T+trans
        z_slope = (plane@rot.T)[:,2]
        halfpixel = .5*(abs(z_slope[0])+abs(z_slope[1]))
        min_surface = float(moved[:,2].min()-halfpixel)
        guarded = min_surface-8.
        assert abs(min_surface-foot['all_rendered_texel_quad_surface_minZ'])<1e-8
        assert abs(guarded-foot['conservative_surface_plus8native_thickness_minZ'])<1e-8
        if phase in (2,5): assert guarded>0
        # Exact causal projection of every source texture coordinate, not only H/F/A.
        affine = plane@rot.T@PXY
        affine[2] += trans@PXY
        assert np.abs(np.c_[rawmarks,np.ones(3)]@affine-foot['actual_projected_HFA']).max()<1e-9
        result['feet'][side] = dict(template=foot['actual_fixed_surface_template'],
            all_nonzero_source_texel_quad_minZ=min_surface,
            declared_eight_native_hidden_thickness_lower_bound=guarded,
            critical_HF_Z=moved_marks[:2,2].tolist(),
            causal_source_to_unpadded_raster_affine=affine.tolist())
    staff = {k:np.array(v,dtype=float) for k,v in f['staff'].items()}
    staff_len = float(np.linalg.norm(staff['top']-staff['tip']))
    staff_lengths.append(staff_len)
    guard = float(staff['tip'][2]-5.)
    assert guard>0 and abs(guard-f['staff_tip_uncertainty_guarded_clearance_native'])<1e-9
    result['staff_length_native'] = staff_len
    result['staff_tip_five_native_guarded_clearance'] = guard
    frame_results.append(result)

assert max(staff_lengths)-min(staff_lengths)<1e-9
pairs = []
for phase0,phase1,side in ((0,1,'L'),(3,4,'R')):
    a = np.array(D['frames'][phase0]['feet'][side]['actual_HFA_XYZ'])
    b = np.array(D['frames'][phase1]['feet'][side]['actual_HFA_XYZ'])
    delta = b[0]-a[0]
    world = delta[:2]*.0948275862068
    compensation = float(np.linalg.norm(world-np.array([16.8/math.sqrt(2)]*2)))
    assert compensation<1e-8 and abs(np.linalg.norm(world)-16.8)<1e-8
    assert abs(a[0,2])<1e-9 and abs(b[0,2])<1e-9 and abs(b[1,2])<1e-9
    pairs.append(dict(phases=[phase0,phase1], support_side=side,
        controller_compensated_world_heel_error=compensation,
        heel_forefoot_Z_before_after=[a[:2,2].tolist(),b[:2,2].tolist()]))

# Both full weapon ends remain actual SOURCE0 pixels at the literal integer body bob.
source0 = pose_images[0]
tip_regions = [(870,0,940,100),(915,1075,940,1118)]
staff_pixels = []
for f,r,pose in zip(D['frames'],ROSTER['frames'],pose_images):
    shift = np.array(f['storage_translation'])+np.array(f['actual_body_bob_raw'])
    assert np.array_equal(shift,shift.astype(int))
    dx,dy=map(int,shift)
    checks=[]
    for x0,y0,x1,y1 in tip_regions:
        ref=source0[y0:y1,x0:x1]
        target=pose[y0+dy:y1+dy,x0+dx:x1+dx]
        assert ref.shape==target.shape
        opaque=ref[:,:,3]>=250
        changed=int(np.count_nonzero(np.any(ref!=target,axis=2)&opaque))
        checks.append(dict(native_source0_region=[x0,y0,x1,y1],
            source0_opaque_pixels=int(opaque.sum()),changed_pixels=changed))
    staff_pixels.append(dict(phase=f['phase'],checks=checks))

report=dict(schema='PR122-independent-all6-authored-rig-and-actual-foot-surface-QC-v1',
    status='PASS_EXACT_ACTUAL_CONTROL_AND_DECLARED_COMPATIBLE_FULL_TEXTURE_AIR_BOUNDS',
    author_model=dict(path=str(P),sha256=hashlib.sha256(RAW).hexdigest()),
    roster=dict(path=str(RP),sha256=hashlib.sha256(RB).hexdigest()),
    template_results=template_results,frames=frame_results,plant_clock_pairs=pairs,
    maximum_bone_error=max_bone_error,maximum_actual_control_projection_error=max_control_error,
    maximum_rigid_rotation_error=max_rigid_error,
    staff_length_change=max(staff_lengths)-min(staff_lengths),actual_staff_end_pixel_checks=staff_pixels,
    claim_limits=[
        'This independently verifies one explicitly authored compatible 2.5D rig; hidden depths, shoe-card surfaces and eight-native thickness are declared construction choices, not uniquely recovered physical anatomy.',
        'Every nonzero actual shoe texture texel and its pixel quad was included in the source-card AIR bound; no lowest-alpha-Y floor rule or selected-marker-only AIR substitution.',
        'Grounded support is observed heel clock/real footroll plus critical H/F controls in this model. Full hidden 3D sole contact/penetration is not uniquely observed; support-card AA extrema can lie below critical H/F plane.',
        'Skeletal/control/AIR construction does not alone approve artwork, full actor actions or game connection; separate actual source/cycle and exact request/atlas review are required.',
        'Frozen roster clock field actor_run_speed_world=210 names the retained reference speed. Actual game RUN262.5 uses effective15.625Hz/dt.064; both produce16.8world perphase.'
    ],actual_source_pixels_changed=False,physical_declared_model_compatible=True,
    uniquely_recovered_physical_anatomy=False,whole_actor_approved=False,actor_approvals_added=0)
target=OUT/'RUN-final-six-independent-rig-surface-AIR-model-PASS-v01.json'
data=(json.dumps(report,indent=2,allow_nan=False)+'\n').encode()
with target.open('xb') as stream: stream.write(data)
print(json.dumps(dict(proof=str(target),sha256=hashlib.sha256(data).hexdigest(),
    bone_error=max_bone_error,control_error=max_control_error,
    AIR_bounds={str(i):{side:frame_results[i]['feet'][side]['declared_eight_native_hidden_thickness_lower_bound']for side in ('L','R')}for i in (2,5)},
    actual_staff_end_pixel_changes=[sum(x['changed_pixels']for x in r['checks'])for r in staff_pixels])))
