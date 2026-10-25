"""Author six W running poses from retained W-only native materials.

No service, preview, recoloring, mirroring, per-frame resizing, or approval.
The retained hidden upper-leg material remains explicitly unreviewed.
"""
from pathlib import Path
from PIL import Image
from scipy.ndimage import map_coordinates, label
import ast
import hashlib
import json
import math
import sys,copy
import numpy as np

B = Path(__file__).parent
SETTINGS = json.loads((B/'W-own-native-motion-settings-v01.json').read_text())
REUSE = '--reuse-unchanged-parts' in sys.argv
CHECK_ONLY = '--preflight-only' in sys.argv or '--regression-only' in sys.argv
CACHE = B/'actual-W-RUN-six-own-native-v04'
O = B/('actual-W-RUN-six-own-native-v05' if REUSE else 'actual-W-RUN-six-own-native-v04')
if not CHECK_ONLY: O.mkdir(exist_ok=False)
BODY = Path('/workspace/scratch/mythic413-W-attack-author-fresh-20261020-v01/native-W-source-parts-v03-exact-rims-bow/W-exact-native-complete-RIGHT-staff-LEFT-upper-and-true-bow-parts-v03.json')
LEGS = Path('/workspace/scratch/mythic413-S-run-author-fresh-20261020-v01/W-own-native-pure-leg-material-candidates-v04/W-two-original-visible-shin-owners-one-new-hidden-upperleg-candidate-HOLD-contract-v04.json')
HELPER = Path('/workspace/scratch/mythic413-W-attack-author-fresh-20261020-v01/author-own-W-ATTACK6-native-visible-profile-distal-cuff-bind-v04-20261022.py')

def pin(path):
    path = Path(path)
    data = path.read_bytes()
    return dict(path=str(path), bytes=len(data), sha256=hashlib.sha256(data).hexdigest())

def checked(rec):
    p = Path(rec['path'])
    assert pin(p)['sha256'] == rec['sha256'], str(p)
    return p

p = json.loads(BODY.read_text())
leg_contract = json.loads(LEGS.read_text())
reg = json.loads(checked(leg_contract['once_registration']).read_text())
ROOT = np.array(reg['common_rig_root_in_unpadded_frame'])
C, UNIT, SIZE = 2560., 2.5, 1792
PAD = np.array([384,128])
W = H = 1254
PIV = np.array([632.,514.])
NECK = np.array([659.,301.])
yy, xx = np.indices((SIZE,SIZE))
worldx, worldy = xx-PAD[0], yy-PAD[1]
parts = {}
for name, rec in p['parts'].items():
    a = np.zeros((H,W,4), np.uint8)
    x,y,ex,ey = rec['native_crop_box']
    a[y:ey,x:ex] = np.array(Image.open(checked(rec)).convert('RGBA'))
    parts[name] = a

original_upper = parts['LEFT-full-near-upper-arm'].copy()
proximal, distal = original_upper.copy(), original_upper.copy()
proximal[477:] = 0
distal[:477] = 0
assert np.array_equal(proximal.astype(np.uint16)+distal.astype(np.uint16), original_upper)
parts['LEFT-full-near-upper-arm'] = proximal
parts['LEFT-original-distal-upper-cuff-follows-rigid-forearm'] = distal
core = np.zeros((H,W,4),np.uint8)
for name in ['BODY-own-profile-chest-waist-ribbons','HEAD-own-profile-face-hair-crown',
             'NECK-own-profile-skin-collar','COAT-own-real-native-cloth-and-original-tails']:
    core += parts[name]
legs = {name:np.array(Image.open(checked(rec)).convert('RGBA')) for name,rec in leg_contract['parts'].items()}

# Recover exact original lower-actor texels omitted by the proposed leg masks.
# Exclude all source pixels already owned by another native actor part.
original_lower = parts['LEGS-original-full-boots-conservative-fixed']
# The two retained calf masks leave a narrow original painted strip between
# their declared edges. Bind those exact source texels to the closest calf,
# rather than leaving them as a detached torso-driven ghost during stance.
from scipy.ndimage import distance_transform_edt
calf_gap = np.zeros((H,W),bool)
for native_y in range(866,1049):
    far_x = np.where(legs['R-far'][native_y,:,3]>0)[0]
    near_x = np.where(legs['L-near'][native_y,:,3]>0)[0]
    if len(far_x) and len(near_x) and far_x.max()<near_x.min():
        calf_gap[native_y,far_x.max()+1:near_x.min()] = True
calf_gap &= original_lower[:,:,3]>0
for name,material in parts.items():
    if name != 'LEGS-original-full-boots-conservative-fixed':
        calf_gap &= material[:,:,3]==0
far_distance = distance_transform_edt(legs['R-far'][:,:,3]==0)
near_distance = distance_transform_edt(legs['L-near'][:,:,3]==0)
source_strip_owners = {}
for name,selection in [('R-far',calf_gap&(far_distance<=near_distance)),
                       ('L-near',calf_gap&(near_distance<far_distance))]:
    assert not np.any(legs[name][selection,3])
    legs[name][selection] = original_lower[selection]
    path = (CACHE if REUSE or CHECK_ONLY else O)/(name+'-exact-original-calf-gap-ownership-native-v04.png')
    if not REUSE and not CHECK_ONLY: Image.fromarray(legs[name]).save(path)
    if REUSE: assert np.array_equal(np.array(Image.open(path).convert('RGBA')),legs[name])
    source_strip_owners[name] = dict(material=pin(path),added_original_native_texels=int(selection.sum()))
source_strip_proof = dict(status='EXACT_ORIGINAL_SOURCE_CALF_STRIP_REBOUND_ANATOMY_REVIEW_HOLD',
                          original_native_texels_rebound=int(calf_gap.sum()),owners=source_strip_owners,
                          colors_changed=False,source_RGBA_resampled=False,new_pixels_created=0,
                          native_source_region=[612,866,639,1000],source_visual_status='HOLD_NOT_REVIEWED')
if not REUSE and not CHECK_ONLY:
    with (O/'exact-original-calf-strip-ownership-v04.json').open('x') as f: json.dump(source_strip_proof,f,indent=2)
owned = np.zeros((H,W),bool)
for name,material in parts.items():
    if name != 'LEGS-original-full-boots-conservative-fixed':
        owned |= material[:,:,3]>0
hidden_coverage_before_fix = owned.copy()
for material in legs.values():
    hidden_coverage_before_fix |= material[:,:,3]>0
    # A generated hidden fill is not proof that an original visible texel survives.
    owned |= (material[:,:,3]>0)&np.all(material==original_lower,axis=2)
restored_original_hidden_overlap = (original_lower[:,:,3]>0)&hidden_coverage_before_fix&~owned
missing_original = (original_lower[:,:,3]>0)&~owned
restored_lower = np.zeros_like(original_lower)
restored_lower[missing_original] = original_lower[missing_original]
assert not np.any((core[:,:,3]>0)&missing_original)
core += restored_lower
restored_path = O/'original-lower-actor-surface-outside-articulated-legs-exact-v03.png'
if not CHECK_ONLY: Image.fromarray(restored_lower).save(restored_path)
coverage = dict(status='EXACT_CURRENT_W_SOURCE_SURFACE_RETAINED_SEMANTIC_QUALITY_HOLD',
                source=pin(checked(p['parts']['LEGS-original-full-boots-conservative-fixed'])),
                recovered_native_texels=int(missing_original.sum()), material=pin(restored_path),
                source_RGBA_resampled=False,colors_changed=False,original_source_coordinates_changed=False)
if not CHECK_ONLY:
    with (O/'original-lower-surface-ownership-restoration-v03.json').open('x') as f: json.dump(coverage,f,indent=2)


# Reuse the exact premultiplied-alpha sampler and arm seam solver, without
# executing the ATTACK producer or reproducing any of its frames.
tree = ast.parse(HELPER.read_text())
functions = [n for n in tree.body if isinstance(n,ast.FunctionDef)
             and n.name in {'smooth','rot','sample','aff','joint','pt'}]
exec(compile(ast.fix_missing_locations(ast.Module(body=functions,type_ignores=[])),str(HELPER),'exec'),globals())

def field(x,y,v):
    M = rot(v['body_deg'])
    px,py = x-PIV[0],y-PIV[1]
    dx = M[0,0]*px+M[0,1]*py+PIV[0]+v['torso'][0]-x
    dy = M[1,0]*px+M[1,1]*py+PIV[1]+v['torso'][1]-y
    h = smooth((330-y)/55)
    a = math.radians(v['head_deg'])
    hx,hy = x-NECK[0],y-NECK[1]
    ex = ((math.cos(a)-1)*hx-math.sin(a)*hy)*h
    ey = (math.sin(a)*hx+(math.cos(a)-1)*hy)*h
    dx += M[0,0]*ex+M[0,1]*ey
    dy += M[1,0]*ex+M[1,1]*ey
    cw = smooth((y-620)/200)*smooth((1000-y)/60)*((1-smooth((x-430)/40))+smooth((x-850)/110))
    dx += v['cloth'][0]*cw
    dy += v['cloth'][1]*cw
    rw = np.sin(np.pi*np.clip((x-730)/240,0,1))**2*np.sin(np.pi*np.clip((y-180)/400,0,1))**2
    rw *= ((x>730)&(x<970)&(y>180)&(y<580))
    dx += v['ribbon'][0]*rw
    dy += v['ribbon'][1]*rw
    return dx,dy

ctl = p['controls']
RP = np.array(ctl['RIGHT_visible_proximal_upper_anchor'])
ER = np.array(ctl['RIGHT_visible_cuff_elbow'])
WR = np.array(ctl['RIGHT_wrist'])
G = np.array(ctl['RIGHT_grip'])
SL = np.array(ctl['LEFT_projected_shoulder'])
PL = np.array(ctl['LEFT_visible_proximal_cuff'])
EL = np.array(ctl['LEFT_visible_elbow_inside_puff'])
WL = np.array(ctl['LEFT_wrist'])

# These explicit native rig landmarks are proposed controls, not newly
# observed anatomy. Their anatomical review remains HOLD.
rest = {name:{k:np.array(v,dtype=float) for k,v in values.items()} for name,values in SETTINGS['rest'].items()}
stride = SETTINGS['stride']
phase_names = [phase['role'] for phase in SETTINGS['phases']]

def vector_rotation(a,b):
    a,b = a/np.linalg.norm(a),b/np.linalg.norm(b)
    co = float(np.dot(a,b))
    si = float(a[0]*b[1]-a[1]*b[0])
    return np.array([[co,-si],[si,co]])

def solve_leg(name,v,phase):
    native = rest[name]
    h0,k0,f0 = native['hip'],native['knee'],native['heel']
    h = pt(h0,v)
    l1,l2 = np.linalg.norm(k0-h0),np.linalg.norm(f0-k0)
    stride_x,lift = stride[phase]
    source = legs[name]
    sy,sx = np.where((source[:,:,3]>100)&(np.indices(source.shape[:2])[0]>=1000))
    native_foot = np.stack([sx,sy],axis=1).astype(float)
    floor = float(sy.max())-lift
    f = f0+np.array([stride_x,-lift])
    def ik(endpoint):
        delta = endpoint-h
        d = np.linalg.norm(delta)
        assert abs(l1-l2)+1 < d < l1+l2-0.5, (name,phase,d,l1+l2)
        u = delta/d
        along = (l1*l1-l2*l2+d*d)/(2*d)
        altitude = math.sqrt(max(0.,l1*l1-along*along))
        knee = h+u*along-np.array([u[1],-u[0]])*altitude
        U,L = vector_rotation(k0-h0,knee-h),vector_rotation(f0-k0,endpoint-knee)
        return knee,U,h-U@h0,L,knee-L@k0
    for _ in range(12):
        k,U,uo,L,lo = ik(f)
        err = float((native_foot@L.T+lo)[:,1].max())-floor
        if abs(err)<0.00001:
            break
        f[1] -= err*0.85
    k,U,uo,L,lo = ik(f)
    floor_error = float((native_foot@L.T+lo)[:,1].max())-floor
    assert abs(floor_error)<0.01, (name,phase,floor_error)
    assert abs(np.linalg.norm(k-h)-l1)<1e-8
    assert abs(np.linalg.norm(f-k)-l2)<1e-8
    return dict(hip=h,knee=k,heel=f,upper=U,upper_offset=uo,lower=L,lower_offset=lo,
                femur_length=l1,lower_to_original_heel_length=l2,requested_foot_lift=lift,
                original_visible_sole_plane=float(sy.max()),desired_sole_plane=floor,
                transformed_native_sole_error=floor_error)

def warp_leg(name,bone):
    # Rotate around the shared knee. This preserves each texel's radius and
    # avoids the inner-knee collapse of linear matrix blending. The fixed
    # 200-native-pixel support belongs to the rig, not each frame's bounds.
    x0,y0,x1,y1 = 300,440,1080,1280
    wy,wx = np.mgrid[y0:y1,x0:x1]
    k0 = rest[name]['knee']
    k = bone['knee']
    U,L = bone['upper'],bone['lower']
    theta0 = math.atan2(U[1,0],U[0,0])
    theta1 = math.atan2(L[1,0],L[0,0])
    delta = (theta1-theta0+math.pi)%(2*math.pi)-math.pi
    span = 200.

    def forward(x,y,jacobian=False):
        t = np.clip((y-(k0[1]-span/2))/span,0.,1.)
        w = t*t*(3-2*t)
        theta = theta0+delta*w
        c,s = np.cos(theta),np.sin(theta)
        dx,dy = x-k0[0],y-k0[1]
        fx,fy = k[0]+c*dx-s*dy,k[1]+s*dx+c*dy
        if not jacobian:
            return fx,fy
        derivative = delta*6*t*(1-t)/span
        j00,j10 = c,s
        j01 = -s+derivative*(-s*dx-c*dy)
        j11 = c+derivative*(c*dx-s*dy)
        return fx,fy,j00,j01,j10,j11

    native_y,native_x = np.where(legs[name][:,:,3]>0)
    _,_,j00,j01,j10,j11 = forward(native_x,native_y,True)
    owned_minimum_jacobian = float((j00*j11-j01*j10).min())
    assert owned_minimum_jacobian>0, ('Native material fold',name,owned_minimum_jacobian)
    for original,target in [(rest[name]['hip'],bone['hip']),
                            (rest[name]['knee'],bone['knee']),
                            (rest[name]['heel'],bone['heel'])]:
        actual = np.array(forward(*original))
        assert np.linalg.norm(actual-target)<1e-8

    # Start at the circular mid-angle; solve the actual skinning map, keeping
    # the original inverse residual guard. No failed pixel is hidden.
    mid = theta0+delta/2
    cs,sn = math.cos(mid),math.sin(mid)
    sx = k0[0]+cs*(wx-k[0])+sn*(wy-k[1])
    sy = k0[1]-sn*(wx-k[0])+cs*(wy-k[1])
    for _ in range(40):
        fx,fy,j00,j01,j10,j11 = forward(sx,sy,True)
        det = j00*j11-j01*j10
        safe = np.where(abs(det)<0.0001,np.where(det<0,-0.0001,0.0001),det)
        dx = (j11*(fx-wx)-j01*(fy-wy))/safe
        dy = (-j10*(fx-wx)+j00*(fy-wy))/safe
        damping = np.minimum(1.,20./np.maximum(np.maximum(abs(dx),abs(dy)),1e-8))
        sx -= dx*damping
        sy -= dy*damping
    selected = map_coordinates(legs[name][:,:,3],[sy,sx],order=0,mode='constant',cval=0,prefilter=False)>0
    fx,fy = forward(sx,sy)
    inverse_error = float(max(np.max(abs(fx-wx)[selected]),np.max(abs(fy-wy)[selected])))
    assert inverse_error<0.0001, (name,inverse_error)
    small = sample(legs[name],sx,sy)
    alpha = np.array(small)[:,:,3]
    assert not np.any(np.r_[alpha[:3].ravel(),alpha[-3:].ravel(),alpha[:,:3].ravel(),alpha[:,-3:].ravel()]), 'Fixed leg support clipped'
    out = Image.new('RGBA',(SIZE,SIZE))
    out.paste(small,(x0+int(PAD[0]),y0+int(PAD[1])))
    bone['minimum_owned_skinning_jacobian'] = owned_minimum_jacobian
    bone['maximum_knee_radius_change'] = 0.
    return out,inverse_error


sys.path.insert(0,'/workspace/twilight/tools')
from pr122_reviewed_source_regions import require_native_source_part_ownership

def require_exact_source_ownership(original, materials):
    return require_native_source_part_ownership(original,materials)

def require_positive_jacobian(values):
    minimum = float(np.min(values))
    if not np.isfinite(minimum) or minimum<=0:
        raise ValueError('Native material folding before rendering')
    return minimum

def require_character_settings(settings):
    if settings['direction']!='W' or settings['role']!='run':
        raise ValueError('Own W run sources require W run configuration')
    if settings['C']!=C or settings['bodyunit']!=UNIT or not np.array_equal(settings['root_unpadded'],ROOT):
        raise ValueError('Preserve this character registration; no copied ratio/root')
    contacts = []
    for phase in range(6):
        support = [side for side,shift in settings['phase_shift'].items()
                   if settings['stride'][(phase+shift)%6][1]==0]
        if len(support)>1:
            raise ValueError('Unexpected simultaneous/repeated-foot contact')
        if support and (not contacts or contacts[-1]!=support[0]):
            contacts.append(support[0])
    if contacts!=['L-near','R-far']:
        raise ValueError('Run support must alternate original leg identities')
    return contacts

body_names = {'BODY-own-profile-chest-waist-ribbons','HEAD-own-profile-face-hair-crown',
              'NECK-own-profile-skin-collar','COAT-own-real-native-cloth-and-original-tails',
              'LEGS-original-full-boots-conservative-fixed'}
logical_materials = {name:material for name,material in parts.items() if name not in body_names}
logical_materials.update({'core':core,**legs})
ownership_check = require_exact_source_ownership(original_lower,logical_materials)
contacts = require_character_settings(SETTINGS)
minimums = []
for phase,v in enumerate(SETTINGS['phases']):
    for name,shift in SETTINGS['phase_shift'].items():
        bone = solve_leg(name,v,(phase+shift)%6)
        ny,nx = np.where(legs[name][:,:,3]>0)
        U,L = bone['upper'],bone['lower']
        a0,a1 = math.atan2(U[1,0],U[0,0]),math.atan2(L[1,0],L[0,0])
        delta = (a1-a0+math.pi)%(2*math.pi)-math.pi
        t = np.clip((ny-(rest[name]['knee'][1]-100))/200.,0.,1.)
        determinant = 1+delta*6*t*(1-t)/200*(nx-rest[name]['knee'][0])
        minimums.append(require_positive_jacobian(determinant))
preflight = dict(status='SOURCE_INPUT_GUARDS_PASS_BEFORE_POSE_RENDER',ownership=ownership_check,
                 minimum_owned_Jacobian=min(minimums),support_order=contacts,
                 source_original_pixels_recovered_from_hidden_overlap=int(restored_original_hidden_overlap.sum()),
                 source_visual_status='HOLD_NOT_REVIEWED',actor_approvals_added=0)
if '--regression-only' in sys.argv:
    rejected = []
    def must_reject(name,action):
        try:
            action()
        except ValueError:
            rejected.append(name)
            return
        raise AssertionError('Known defect not rejected: '+name)
    bad_core = core.copy()
    bad_core[restored_original_hidden_overlap] = 0
    must_reject('real_641_original_pixels_hidden_by_generated_fill',
                lambda:require_exact_source_ownership(original_lower,{**logical_materials,'core':bad_core}))
    bad_core = core.copy()
    bad_core[calf_gap] = original_lower[calf_gap]
    must_reject('real_922_original_pixels_owned_by_body_and_calf',
                lambda:require_exact_source_ownership(original_lower,{**logical_materials,'core':bad_core}))
    # Reproduce the former linear-blend skinning map at its actual failing pose.
    bone = solve_leg('R-far',SETTINGS['phases'][0],3)
    original_leg = np.array(Image.open(checked(leg_contract['parts']['R-far'])).convert('RGBA'))
    ny,nx = np.where(original_leg[:,:,3]>30)
    U,L,u,l = bone['upper'],bone['lower'],bone['upper_offset'],bone['lower_offset']
    t = np.clip((ny-(rest['R-far']['knee'][1]-35))/70,0,1)
    w,dw = t*t*(3-2*t),6*t*(1-t)/70
    difference = np.stack([nx,ny],axis=1)@(L-U).T+(l-u)
    j00,j10 = (1-w)*U[0,0]+w*L[0,0],(1-w)*U[1,0]+w*L[1,0]
    j01,j11 = (1-w)*U[0,1]+w*L[0,1]+dw*difference[:,0],(1-w)*U[1,1]+w*L[1,1]+dw*difference[:,1]
    must_reject('actual_previous_linear_knee_fold',lambda:require_positive_jacobian(j00*j11-j01*j10))
    bad = copy.deepcopy(SETTINGS)
    bad['phase_shift']['R-far'] = 0
    must_reject('same_leg_support_halfcycle',lambda:require_character_settings(bad))
    bad = copy.deepcopy(SETTINGS)
    bad['direction'] = 'E'
    must_reject('wrong_direction_configuration',lambda:require_character_settings(bad))
    preflight['known_defect_cases_rejected'] = rejected
if CHECK_ONLY:
    print(json.dumps(preflight),flush=True)
    raise SystemExit(0)

frames = []
for i,v in enumerate(SETTINGS['phases']):
    phase_name = v['role']
    sx,sy = worldx.astype(float),worldy.astype(float)
    for _ in range(40):
        dx,dy = field(sx,sy,v)
        sx,sy = worldx-dx,worldy-dy
    # Finish with Newton inversion of the actual body field. Keep the exact
    # residual bound; fixed-point iteration alone was too slow near the hem.
    for _ in range(6):
        dx,dy = field(sx,sy,v)
        ex,ey = field(sx+0.001,sy,v)
        hx,hy = field(sx,sy+0.001,v)
        j00,j10 = 1+(ex-dx)/0.001,(ey-dy)/0.001
        j01,j11 = (hx-dx)/0.001,1+(hy-dy)/0.001
        determinant = j00*j11-j01*j10
        safe = np.where(abs(determinant)<0.0001,np.where(determinant<0,-0.0001,0.0001),determinant)
        rx,ry = sx+dx-worldx,sy+dy-worldy
        sx,sy = sx-(j11*rx-j01*ry)/safe,sy-(-j10*rx+j00*ry)/safe
    dx,dy = field(sx,sy,v)
    mask = map_coordinates(core[:,:,3],[sy,sx],order=0,mode='constant',cval=0,prefilter=False)>0
    body_inverse_error = float(max(np.max(abs(sx+dx-worldx)[mask]),np.max(abs(sy+dy-worldy)[mask])))
    assert body_inverse_error<0.0001
    body = sample(core,sx,sy)
    if REUSE:
        cached_contract_path = CACHE/'W-RUN-six-own-native-source-contract-v04.json'
        cached_contract = json.loads(cached_contract_path.read_text())
        cached_frame = cached_contract['frames'][i]
        assert cached_frame['parameters']==v, 'Changed controls require an explicit affected-part review'
        assert cached_frame['C']==C and cached_frame['common_rig_root_unpadded']==ROOT.tolist()
        out = Image.new('RGBA',(SIZE,SIZE))
        node_pins = []
        changed = 0
        for rec in cached_frame['nodes']:
            if rec['name']=='BODY-HEAD-NECK-real-COAT-native-material':
                im = body
                node = O/f'phase-{i}-BODY-HEAD-NECK-real-COAT-native-material.png'
                im.save(node,optimize=True)
                node_pins.append(dict(name=rec['name'],**pin(node)))
                changed += 1
            else:
                im = Image.open(checked(rec)).convert('RGBA')
                node_pins.append(copy.deepcopy(rec))
            out.alpha_composite(im)
        assert changed==1 and len(node_pins)==10
        rgba = np.array(out)
        border = int((rgba[:3,:,3]>16).sum()+(rgba[-3:,:,3]>16).sum()+(rgba[:,:3,3]>16).sum()+(rgba[:,-3:,3]>16).sum())
        assert border==0
        components,count = label(rgba[:,:,3]>100)
        sizes = np.bincount(components.ravel())
        major = sorted([int(size) for size in sizes[1:] if size>=100],reverse=True)
        assert len(major)==1, 'Detached body part: stop without weakening assembly checks'
        frame = O/f'thunder_female-W-run-{i}-{phase_name}-actual-native-v05.png'
        out.save(frame,optimize=True)
        assert np.array_equal(np.array(Image.open(frame).convert('RGBA')),rgba)
        updated = copy.deepcopy(cached_frame)
        updated.update(source=pin(frame),nodes=node_pins,body_inverse_error=body_inverse_error,
                       border_alpha_texels=border,major_alpha_components=major,
                       reused_unchanged_node_count=9,changed_node_count=1)
        frames.append(updated)
        print(json.dumps(dict(phase=i,changed_nodes=1,unchanged_nodes_reused=9,major_components=1)),flush=True)
        continue
    RU = rot(v['body_deg']+v['right_upper'])
    ruo = pt(RP,v)-RU@RP
    elbow = RU@ER+ruo
    RF = rot(v['right_fore'])
    rfo = elbow-RF@ER
    LU = rot(v['body_deg']+v['left_upper'])
    luo = pt(SL,v)-LU@SL
    lprox = LU@PL+luo
    LF = rot(v['left_fore'])
    lfo = lprox-LF@PL
    ru,ruerr = joint(parts['RIGHT-full-visible-upper-arm'],RU,ruo,v,435,455,(380,300,700,660))
    lu,luerr = joint(parts['LEFT-full-near-upper-arm'],LU,luo,v,360,470,(450,200,980,800))
    bones = {'L-near':solve_leg('L-near',v,i),'R-far':solve_leg('R-far',v,(i+3)%6)}
    far,far_error = warp_leg('R-far',bones['R-far'])
    near,near_error = warp_leg('L-near',bones['L-near'])
    layers = [('R-far-own-native-articulated-leg',far),
              ('L-near-own-native-articulated-leg',near),
              ('RIGHT-full-visible-upper-arm',ru),
              ('BODY-HEAD-NECK-real-COAT-native-material',body),
              ('complete-rigid-RIGHT-staff',aff(parts['complete-rigid-RIGHT-staff'],RF,rfo)),
              ('RIGHT-white-puff-elbow',aff(parts['RIGHT-white-puff-elbow'],RF,rfo)),
              ('RIGHT-complete-forearm-cuff-grip-fingers',aff(parts['RIGHT-complete-forearm-cuff-grip-fingers'],RF,rfo)),
              ('LEFT-full-near-upper-arm',lu),
              ('LEFT-original-distal-upper-cuff-follows-rigid-forearm',aff(parts['LEFT-original-distal-upper-cuff-follows-rigid-forearm'],LF,lfo)),
              ('LEFT-complete-original-curved-cuff-forearm-free-fingers',aff(parts['LEFT-complete-original-curved-cuff-forearm-free-fingers'],LF,lfo))]
    out = Image.new('RGBA',(SIZE,SIZE))
    node_pins = []
    for name,im in layers:
        out.alpha_composite(im)
        node = O/f'phase-{i}-{name}.png'
        im.save(node,optimize=True)
        node_pins.append(dict(name=name,**pin(node)))
    rgba = np.array(out)
    border = int((rgba[:3,:,3]>16).sum()+(rgba[-3:,:,3]>16).sum()+(rgba[:,:3,3]>16).sum()+(rgba[:,-3:,3]>16).sum())
    assert border==0
    components,count = label(rgba[:,:,3]>100)
    sizes = np.bincount(components.ravel())
    major = sorted([int(s) for s in sizes[1:] if s>=100],reverse=True)
    frame = O/f'thunder_female-W-run-{i}-{phase_name}-actual-native-v04.png'
    out.save(frame,optimize=True)
    assert np.array_equal(np.array(Image.open(frame).convert('RGBA')),rgba)
    encoded_bones = {name:{k:value.tolist() if isinstance(value,np.ndarray) else float(value) for k,value in rec.items()} for name,rec in bones.items()}
    frames.append(dict(phase=i,role=phase_name,source=pin(frame),C=C,bodyunit=UNIT,
                       common_rig_root_unpadded=ROOT.tolist(),storage_translation=PAD.tolist(),
                       native_canvas=[SIZE,SIZE],parameters=v,bones=encoded_bones,
                       nodes=node_pins,body_inverse_error=body_inverse_error,
                       arm_inverse_errors=[ruerr,luerr],leg_inverse_errors=[far_error,near_error],
                       rigid_staff_Gram_error=float(np.max(abs(RF.T@RF-np.eye(2)))),
                       border_alpha_texels=border,major_alpha_components=major,
                       LEFT_full_forearm_rigid_matrix=LF.tolist(),RIGHT_staff_rigid_matrix=RF.tolist()))
    print(json.dumps(dict(phase=i,major_components=len(major),frames_written=i+1)),flush=True)

assert len({f['source']['sha256'] for f in frames})==6
contract = dict(schema='pr122-own-native-six-pose-source-v01',
                status='SIX_ACTUAL_NATIVE_W_RUN_POSES_SOURCE_VISUAL_AND_ANATOMY_HOLD_NOT_APPROVED',
                key='transform:413',direction='W',action='run',frames=frames,
                source_materials=dict(body=pin(BODY),legs=pin(LEGS),registration=pin(checked(leg_contract['once_registration']))),
                recovered_original_lower_actor_surface=coverage,
                exact_original_calf_strip_ownership=source_strip_proof,
                reused_sampler_and_arm_seam_solver=pin(HELPER),C=C,bodyunit=UNIT,
                common_rig_root_unpadded=ROOT.tolist(),storage_translation=PAD.tolist(),
                source_canvas=[SIZE,SIZE],native_rig_landmarks_are_proposed_not_visually_reviewed=True,
                original_W_only_materials=True,mirrored_other_direction=False,
                shared_motion_or_recolored_substitute=False,per_pose_C_or_root_fit=False,
                bone_lengths_constant=True,original_fullboot_materials_retained=True,
                knee_skinning='FIXED_200_NATIVE_PIXEL_CIRCULAR_ROTATION_NO_RADIAL_COLLAPSE',
                new_source_images_generated_by_service=0,preview_images_created=0,
                source_visual_status='HOLD_NOT_REVIEWED',
                retained_hidden_far_upperleg_source_status='HOLD_NOT_INDEPENDENTLY_REVIEWED',
                gameplay_world_foot_contact='NOT_RUN_HOLD',production_connected=False,
                actor_approvals_added=0,game_clips_adopted=0)
contract['source_input_preflight'] = preflight
contract['character_settings'] = pin(B/'W-own-native-motion-settings-v01.json')
if REUSE:
    contract['parent_source_contract'] = pin(CACHE/'W-RUN-six-own-native-source-contract-v04.json')
    contract['changed_nodes_rendered'] = 6
    contract['unchanged_nodes_reused'] = 54
contract_name = 'W-RUN-six-own-native-source-contract-v05.json' if REUSE else 'W-RUN-six-own-native-source-contract-v04.json'
with (O/contract_name).open('x') as f:
    json.dump(contract,f,ensure_ascii=False,indent=2)
print('SIX_NATIVE_W_RUN_FRAMES_SAVED_QUALITY_HOLD_NO_ACTOR_APPROVAL',flush=True)
