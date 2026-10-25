from pathlib import Path
from PIL import Image, ImageDraw
from scipy.ndimage import map_coordinates, label
import numpy as np
import json, hashlib, ast, math

D = Path(__file__).parent
O = D / 'actual-NE-HIT6-own-native-articulated-v01'
O.mkdir(exist_ok=False)
RUN = Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01')
B = Path('/workspace/scratch/mythic413-NE-walk-author-20261020-v01')
S = B / 'NE-contact0-actual-native-background-AA-clean-r002.png'
A = RUN / 'common-complete-NE-native-material-parts-v03/original-actual-complete-LEFT-cuff-elbow-cap-forearm-hand-native.png'
R = B / 'actual-NE-LOAD1-semantic-speck-finish-v03/original-native-RIGHT-complete-shoe-and-leg-material-staff-speck-excluded.png'
L = B / 'actual-NE-LOAD1-rig-v02/original-native-complete-LEFT-visible-boot-material.png'
N_METHOD = Path('/workspace/scratch/mythic413-N-hit-author-20261020-v01/author-N-HIT6-native-articulated-recoil-v08-actual-curved-cuff-semantic.py')
source = Image.open(S).convert('RGBA')
arm = Image.open(A).convert('RGBA')
src, aa = np.array(source), np.array(arm)
H, W = src.shape[:2]
SIZE = 1536
PAD = np.array([128., 128.])
ROOT = [716.2291666666666, 1054.2766007046484]
yy, xx = np.indices((H, W))

def rec(p):
    p = Path(p)
    b = p.read_bytes()
    return dict(path=str(p), sha256=hashlib.sha256(b).hexdigest(), bytes=len(b))

def smooth(t):
    t = np.clip(t, 0, 1)
    return t*t*(3-2*t)

# One actual stationary native stance registration. Original complete leg
# shafts, cuffs, outsole, counter and gold stilettos remain native RGBA, not
# foot-fit controls derived independently for the six output poses.
fixedlegs = (np.array(Image.open(R))[:, :, 3] > 0) | (np.array(Image.open(L))[:, :, 3] > 0)
fixedstaff = xx >= 850
Image.fromarray(fixedlegs.astype('uint8')*255).save(O / 'one-time-original-complete-legs-and-shoes-fixed-native-matte.png')
Image.fromarray(fixedstaff.astype('uint8')*255).save(O / 'original-full-RIGHT-staff-grip-fixed-native-region.png')

# Trace the actual curved upper cuff rather than cutting a horizontal elbow.
# It stays with its original upper arm; the complete real white cuff, bracer
# and hand articulate from the same native elbow beneath this curved overlap.
cx = [510, 520, 530, 540, 550, 560, 570, 580, 590, 600, 610, 620]
cy = [514, 523, 535, 543, 548, 551, 551, 549, 544, 535, 522, 510]
boundary = np.interp(xx, cx, cy)
armsemantic = aa[:, :, 3] > 0
fixedcap = armsemantic & (yy <= boundary)
base = src.copy()
base[armsemantic & ~fixedcap] = 0
Image.fromarray(fixedcap.astype('uint8')*255).save(O / 'actual-NE-curved-upper-blue-gold-cuff-fixed-native-matte.png')
Image.fromarray((armsemantic & ~fixedcap).astype('uint8')*255).save(O / 'actual-NE-old-distal-forearm-hand-erasure-native-matte.png')
Image.fromarray(base).save(O / 'actual-original-NE-body-full-staff-fixedlegs-only-distal-free-arm-erased-native.png')

# Same bounded native semantic material mesh used in the independently
# approved NE RUN actual cuff. Import definitions only, no producer side effects.
code = (RUN / 'author-NE-run-contact0-actual-parts-v01.py').read_text()
tree = ast.parse(code)
nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in {'bone_affine', 'forward_material'}]
ns = dict(np=np, Image=Image, json=json, hashlib=hashlib, SIZE=SIZE, PAD=PAD, W=W, H=H)
exec(compile(ast.Module(nodes, []), 'bounded-actual-NE-material-mesh-definitions-only', 'exec'), ns)
forward = ns['forward_material']

phases = [
    dict(role='stable_guard', head=[-1., 2.], cranial_deg=0., wrist=[493., 650.], cloth=[0., 0.], ribbon=[0., 0.]),
    dict(role='impact_response', head=[-12., 19.], cranial_deg=-1.5, wrist=[465., 485.], cloth=[3., 5.], ribbon=[2., 1.]),
    dict(role='maximum_recoil', head=[-32., 39.], cranial_deg=-4.5, wrist=[490., 463.], cloth=[10., 8.], ribbon=[7., 2.]),
    dict(role='counterbalance', head=[-20., 17.], cranial_deg=-1.8, wrist=[458., 490.], cloth=[13., 4.], ribbon=[10., 1.]),
    dict(role='regaining_control', head=[-5., 3.], cranial_deg=.5, wrist=[475., 633.], cloth=[5., 1.], ribbon=[4., -1.]),
    dict(role='regained_guard', head=[-1., 2.], cranial_deg=0., wrist=[493., 650.], cloth=[0., 0.], ribbon=[0., 0.]),
]

def field(x, y, p):
    # Fixed pelvis; actual upper thorax yields away from the NE impact. Keep
    # the RIGHT braced grip/weapon at its original native transform.
    spine = smooth((700-y)/300) * smooth((850-x)/60)
    dx, dy = p['head'][0]*spine, p['head'][1]*spine
    # The head rotates relative to the thorax; this is not whole-PNG rotation.
    cranial = smooth((465-y)/90) * smooth((850-x)/60)
    ang = math.radians(p['cranial_deg'])
    px, py = x-704, y-390
    dx = dx + (px*(math.cos(ang)-1)-py*math.sin(ang))*cranial
    dy = dy + (px*math.sin(ang)+py*(math.cos(ang)-1))*cranial
    # Only the far-left cloth surface responds here; actual legs are separately
    # protected. Roots taper continuously to zero, preserving costume joins.
    wx = np.sin(np.pi*np.clip((x-275)/260, 0, 1))**2
    wy = np.sin(np.pi*np.clip((y-660)/335, 0, 1))**2
    lag = wx*wy*((x>275)&(x<535)&(y>660)&(y<995))
    dx, dy = dx+p['cloth'][0]*lag, dy+p['cloth'][1]*lag
    ribbon = np.sin(np.pi*np.clip((x-430)/185, 0, 1))**2 * np.sin(np.pi*np.clip((y-315)/190, 0, 1))**2
    ribbon = ribbon*((x>430)&(x<615)&(y>315)&(y<505))
    return dx+p['ribbon'][0]*ribbon, dy+p['ribbon'][1]*ribbon

def invert(p):
    # Finite Newton inversion of the causal forward surface, with a measured
    # residual. No alpha-height normalization or body/root fitting.
    tx, ty = xx.astype(float), yy.astype(float)
    sx, sy = tx.copy(), ty.copy()
    for _ in range(10):
        dx, dy = field(sx, sy, p)
        rx, ry = sx+dx-tx, sy+dy-ty
        ex, ey = field(sx+.01, sy, p)
        fx, fy = field(sx, sy+.01, p)
        j00, j10 = 1+(ex-dx)/.01, (ey-dy)/.01
        j01, j11 = (fx-dx)/.01, 1+(fy-dy)/.01
        det = j00*j11-j01*j10
        sx -= (j11*rx-j01*ry)/det
        sy -= (-j10*rx+j00*ry)/det
    dx, dy = field(sx, sy, p)
    return sx, sy, float(max(np.max(abs(sx+dx-tx)), np.max(abs(sy+dy-ty))))

def actual_sample(data, sx, sy):
    pm = data.astype(float)/255
    pm[:, :, :3] *= pm[:, :, 3, None]
    v = np.stack([map_coordinates(pm[:, :, c], [sy, sx], order=1, mode='constant', cval=0, prefilter=False) for c in range(4)], axis=2)
    a = v[:, :, 3]
    rgb = np.divide(v[:, :, :3], a[:, :, None], out=np.zeros_like(v[:, :, :3]), where=a[:, :, None]>1e-8)
    out = np.rint(np.dstack((rgb, a)).clip(0, 1)*255).astype('uint8')
    unchanged = (abs(sx-xx)<1e-9)&(abs(sy-yy)<1e-9)
    out[unchanged] = data[unchanged]
    return out

registration = dict(schema='NE_HIT_STATIONARY_NATIVE_STANCE_ONE_TIME_V01', source=rec(S), C=2432, bodyunit=2.375, common_rig_root_unpadded=ROOT, storage_translation=PAD.tolist(), source_native_size=[W,H], output_native_size=[SIZE,SIZE], fixed_legs_source=[rec(R),rec(L)], original_RIGHT_observed_HFA=[[799.5,1028],[855,1005],[811,944]], one_time_stance_registration_only=True, each_pose_foot_or_root_fitting=False, scope='Original actual native complete two-boot/leg stationary brace, source topology preserved; no invented unique hidden floor or new per-pose foot fitting.', actor_approvals_added=0)
reg = O / 'NE-HIT-original-native-two-boot-stationary-brace-once-registration-v01.json'
reg.write_text(json.dumps(registration, indent=2)+'\n')
frames = []
for i, p in enumerate(phases):
    Q = O / f'phase{i}-actual-NE-hit-{p["role"]}-v01'
    Q.mkdir(exist_ok=False)
    ns['Q'] = Q
    sx, sy, residual = invert(p)
    assert residual < .0001, residual
    bodyrgba = actual_sample(base, sx, sy)
    body = Image.new('RGBA', (SIZE,SIZE))
    body.alpha_composite(Image.fromarray(bodyrgba), tuple(PAD.astype(int)))
    proximal = np.array([559.,520.]); elbow = np.array([559.,550.])
    dx,dy=field(proximal[0],proximal[1],p); pc=proximal+[float(dx),float(dy)]
    dx,dy=field(elbow[0],elbow[1],p); ec=elbow+[float(dx),float(dy)]
    movedarm = forward(arm, [proximal,elbow,[481.,645.]], [pc,ec,p['wrist']], 'LEFT-actual-complete-curved-cuff-white-sleeve-bracer-hand-guard')
    # Anatomical LEFT is far-side: torso, hair/ribbon and its retained curved
    # upper-cuff surface occlude it naturally rather than painting it on back.
    out = movedarm.copy()
    out.alpha_composite(body)
    arr = np.array(out)
    native = arr[128:128+H,128:128+W].copy()
    native[fixedlegs|fixedstaff] = src[fixedlegs|fixedstaff]
    arr[128:128+H,128:128+W] = native
    out = Image.fromarray(arr)
    target=Q/f'thunder_female-NE-hit-phase{i}-{p["role"]}-actual-native-v01.png'
    out.save(target)
    body.save(Q/'actual-head-thorax-clothing-node-native-v01.png')
    cc,n=label(arr[:,:,3]>100);counts=np.bincount(cc.ravel());big=sorted([int(v)for v in counts[1:]if v>=200],reverse=True)
    footdiff=int(np.any(native[fixedlegs]!=src[fixedlegs],axis=1).sum())
    staffdiff=int(np.any(native[fixedstaff]!=src[fixedstaff],axis=1).sum())
    f=dict(phase=i,role=p['role'],source=rec(target),native_size=[SIZE,SIZE],C=2432,bodyunit=2.375,common_rig_root_unpadded=ROOT,storage_translation=PAD.tolist(),stored_common_rig_root=(np.asarray(ROOT)+PAD).tolist(),head_upper_thorax_recoil=p['head'],cranial_rotation_degrees=p['cranial_deg'],native_clothing_lag=p['cloth'],native_ribbon_lag=p['ribbon'],LEFT_actual_guard_knots_unpadded=[pc.tolist(),ec.tolist(),p['wrist']],actual_LEFT_guard_material=rec(A),actual_LEFT_guard_mesh=rec(Q/'LEFT-actual-complete-curved-cuff-white-sleeve-bracer-hand-guard-actual-forward-mesh.json'),body_forward_inverse_maximum_residual_native=residual,original_complete_two_legs_shoes_RGBA_changes=footdiff,original_full_RIGHT_staff_grip_fixed_region_RGBA_changes=staffdiff,strong_alpha100_components_ge200=big,actor_approvals_added=0)
    (Q/'actual-native-NE-hit-phase-source-preservation-provenance-v01.json').write_text(json.dumps(f,indent=2)+'\n')
    frames.append(f)
    print(json.dumps(dict(phase=i,source=rec(target),footdiff=footdiff,staffdiff=staffdiff,strong=big,inverse_residual=residual)),flush=True)

contract=dict(schema='MYTHIC413_NE_HIT_SIX_ACTUAL_NATIVE_ARTICULATED_SOURCE_V01',status='ACTUAL_OWN_NE_SOURCE_RENDERED_PENDING_INDEPENDENT_QC',action='hit',direction='NE',source_identity=rec(S),stationary_brace_once_registration=rec(reg),actual_LEFT_complete_material=rec(A),method_read_only_reference=rec(N_METHOD),method_pixels_reused_from_N=False,C=2432,bodyunit=2.375,common_rig_root_unpadded=ROOT,storage_translation=PAD.tolist(),native_size=[SIZE,SIZE],role_seconds=.22,phase_seconds=.22/6,frames=frames,whole_PNG_translation_rotation_shared_recolor_or_mirror=False,perpose_C_root_or_foot_fit=False,RIGHT_anatomical_near_full_staff_and_complete_both_boots_preserved=True,existing_Godot_hit_window_or_profile_modified=False,source_cycle_and_game_approved=False,actor_approvals_added=0,completed_detailed_actors_unchanged=2)
cp=O/'NE-HIT6-actual-own-native-brace-spine-head-guard-source-contract-v01.json';cp.write_text(json.dumps(contract,indent=2)+'\n')
print(json.dumps(dict(contract=rec(cp),frames=len(frames))),flush=True)

# One finite private production preview; output remains a local file only.
board=Image.new('RGB',(1200,800),(125,125,125));dr=ImageDraw.Draw(board)
for f in frames:
    im=Image.open(f['source']['path']).convert('RGBA');im.thumbnail((400,380));cell=Image.new('RGBA',(400,380),(125,125,125,255));cell.alpha_composite(im,((400-im.width)//2,0));x=(f['phase']%3)*400;y=(f['phase']//3)*400;board.paste(cell.convert('RGB'),(x,y+20));dr.text((x+5,y+4),str(f['phase'])+' '+f['role'],fill='white')
pp=O/'private-NE-HIT6-actual-body-arm-clothing-board-v01.jpg';board.save(pp,quality=76,optimize=True);assert pp.stat().st_size<150000
