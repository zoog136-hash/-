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
import numpy as np

B = Path(__file__).parent
O = B/'actual-W-RUN-six-own-native-v03'
O.mkdir(exist_ok=False)
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
owned = np.zeros((H,W),bool)
for name,material in parts.items():
    if name != 'LEGS-original-full-boots-conservative-fixed':
        owned |= material[:,:,3]>0
for material in legs.values():
    owned |= material[:,:,3]>0
missing_original = (original_lower[:,:,3]>0)&~owned
restored_lower = np.zeros_like(original_lower)
restored_lower[missing_original] = original_lower[missing_original]
assert not np.any((core[:,:,3]>0)&missing_original)
core += restored_lower
restored_path = O/'original-lower-actor-surface-outside-articulated-legs-exact-v03.png'
Image.fromarray(restored_lower).save(restored_path)
coverage = dict(status='EXACT_CURRENT_W_SOURCE_SURFACE_RETAINED_SEMANTIC_QUALITY_HOLD',
                source=pin(checked(p['parts']['LEGS-original-full-boots-conservative-fixed'])),
                recovered_native_texels=int(missing_original.sum()), material=pin(restored_path),
                source_RGBA_resampled=False,colors_changed=False,original_source_coordinates_changed=False)
with (O/'original-lower-surface-ownership-restoration-v03.json').open('x') as f:
    json.dump(coverage,f,indent=2)


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
rest = {
 'R-far':dict(hip=np.array([570.,646.]),knee=np.array([590.,866.]),heel=np.array([603.,1152.])),
 'L-near':dict(hip=np.array([616.,646.]),knee=np.array([647.,866.]),heel=np.array([682.,1187.]))}
stride = [(-70.,0.), (0.,0.), (80.,24.), (110.,100.), (50.,170.), (-100.,75.)]
phase_names = ['NEAR_CONTACT_FAR_AIR','NEAR_COMPRESSION_FAR_RECOVER','NEAR_TOEOFF_FAR_REACH',
               'FAR_CONTACT_NEAR_AIR','FAR_COMPRESSION_NEAR_RECOVER','FAR_TOEOFF_NEAR_REACH']

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


frames = []
for i,phase_name in enumerate(phase_names):
    v = dict(role=phase_name,body_deg=[-6,-7,-5,-6,-7,-5][i],
             torso=[-8,[10,35,-5,10,35,-5][i]],head_deg=[1,0,-1,1,0,-1][i],
             right_upper=[3,1,-3,-5,-1,2][i],
             right_fore=[-2,-5,-7,-11,-9,-5][i],
             left_upper=[12,6,-3,-12,-6,4][i],
             left_fore=[-14,-7,3,10,0,-8][i],
             cloth=[[8,-3],[12,-1],[16,-5],[10,-3],[14,-1],[18,-5]][i],
             ribbon=[[8,0],[12,1],[15,-1],[9,0],[13,1],[16,-1]][i])
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
    frame = O/f'thunder_female-W-run-{i}-{phase_name}-actual-native-v03.png'
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
with (O/'W-RUN-six-own-native-source-contract-v03.json').open('x') as f:
    json.dump(contract,f,ensure_ascii=False,indent=2)
print('SIX_NATIVE_W_RUN_FRAMES_SAVED_QUALITY_HOLD_NO_ACTOR_APPROVAL',flush=True)
