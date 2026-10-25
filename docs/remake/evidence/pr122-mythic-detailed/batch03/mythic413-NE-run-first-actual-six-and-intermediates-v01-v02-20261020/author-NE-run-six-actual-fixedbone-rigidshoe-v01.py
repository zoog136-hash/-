from pathlib import Path
from PIL import Image
import numpy as np, math, json, hashlib, ast

D=Path(__file__).parent
BASE=D/'contact0-actual-NE-run-v01'
OUT=D/'actual-NE-run-six-fixed-rig-v01'
OUT.mkdir(exist_ok=False)
SIZE=1536;PAD=np.array([128.,128.]);ROOT=np.array([716.2291666666666,1054.2766007046484])
shaft=Image.open(BASE/'original-complete-RIGHT-upperthigh-calf-source-native.png').convert('RGBA')
shoe=Image.open(BASE/'RIGHT-complete-shoe-native-RGBA.png').convert('RGBA')
back=Image.open(BASE/'original-native-blue-coattails-behind-running-legs.png').convert('RGBA')
front=Image.open(BASE/'original-native-body-skirt-RIGHTstaff-foreground-old-free-arm-removed.png').convert('RGBA')
ARMP=Path('/workspace/scratch/mythic413-NE-walk-author-20261020-v01/actual-NE-LOAD1-rig-v02/original-native-LEFT-free-forearm-and-hand-material.png')
arm=Image.open(ARMP).convert('RGBA');W,H=shaft.size

# Reuse only the already preserved general native material rasterizer.
# No imported producer module is executed and no old output is overwritten.
tree=ast.parse((D/'author-NE-run-contact0-actual-parts-v01.py').read_text())
needed={'rec','affine','translate','bone_affine','forward_material'}
ns=dict(np=np,Image=Image,json=json,hashlib=hashlib,SIZE=SIZE,PAD=PAD,W=W,H=H)
exec(compile(ast.Module([n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in needed],[]),'preserved-native-material-rasterizer','exec'),ns)
rec=ns['rec'];affine=ns['affine'];translate=ns['translate'];forward_material=ns['forward_material'];bone_affine=ns['bone_affine']

# One fixed native authored coordinate model. It matches the game-source
# NW/NE ground metric: raw=(X/.9,Y-Z). Equal physical X/Y displacement is
# the exact NE screen heel clock; this is a declared model, not recovered 3D.
P=np.array([[1/.9,0,0],[0,1,-1.]])
N=np.array([0,1,1.])/math.sqrt(2)
H0=np.array([799.5,1028.]);F0=np.array([855.,1005.]);A0=np.array([811.,944.])
k=(F0[1]-H0[1])/(F0[0]-H0[0])
by=100/(-k*(A0[0]-H0[0])+(A0[1]-H0[1]));bx=-k*by
B=np.array([[.9,0],[bx,1+by],[bx,by]])
assert np.max(abs(P@B-np.eye(2)))<1e-12
Af=B@(A0-H0);Ff=B@(F0-H0)
assert abs(Af[2]-100)<1e-10 and abs(Ff[2])<1e-10
LENGTH=61*4.5125
SOURCE_R=np.array([[774.,724.],[790.,815.],[811.,944.]])
def minlift(raw):
    x,y=np.asarray(raw)-H0
    return np.array([.9*x,y/2,-y/2])
th=math.sqrt(LENGTH**2-np.linalg.norm(minlift(SOURCE_R[1])-minlift(SOURCE_R[0]))**2)
ca=math.sqrt(LENGTH**2-np.linalg.norm(minlift(SOURCE_R[2])-minlift(SOURCE_R[1]))**2)
an=float(Af@N)
Rhip=minlift(SOURCE_R[0])+N*(an+ca+th)
Rknee=minlift(SOURCE_R[1])+N*(an+ca)
assert abs(np.linalg.norm(Rknee-Rhip)-LENGTH)<1e-10
assert abs(np.linalg.norm(Af-Rknee)-LENGTH)<1e-10
Lhip=np.array([.9*(680-H0[0]),704-H0[1]+Rhip[2],Rhip[2]])
GROUND_RAW=np.array([-132.23325357766257,119.00992821989632])
GROUND=np.array([.9*GROUND_RAW[0],GROUND_RAW[1],0.])
SOURCE_WORLD_UNIT=16.8/np.linalg.norm(GROUND)
assert abs(abs(GROUND[0])-GROUND[1])<1e-9

def rodrigues(axis,angle):
    axis=np.asarray(axis,float);axis/=np.linalg.norm(axis);x,y,z=axis
    K=np.array([[0,-z,y],[z,0,-x],[-y,x,0.]])
    return np.eye(3)*math.cos(angle)+(1-math.cos(angle))*np.outer(axis,axis)+math.sin(angle)*K

direction=Ff.copy();direction[2]=0;direction/=np.linalg.norm(direction)
pitch_axis=np.array([-direction[1],direction[0],0.])
def rotation(yaw,pitch):
    # Negative Rodrigues angle about this perpendicular axis raises toes.
    return rodrigues([0,0,1],math.radians(yaw))@rodrigues(pitch_axis,-math.radians(pitch))

def proj(xyz):return P@np.asarray(xyz)+H0
def target_air_foot(raw_A,z_A,yaw,pitch):
    R=rotation(yaw,pitch);x,y=np.asarray(raw_A)-H0
    A=np.array([.9*x,y+z_A,z_A]);return R,A-R@Af
def contact_foot(raw_H,yaw,pitch,delta=None):
    R=rotation(yaw,pitch);x,y=np.asarray(raw_H)-H0
    heel=np.array([.9*x,y,0.])
    if delta is not None:heel+=delta
    return R,heel

def knee_ik(hip,ankle,target):
    d=ankle-hip;length=np.linalg.norm(d)
    assert length<2*LENGTH-1e-8, ('outside fixed bone reach',length,proj(hip).tolist(),proj(ankle).tolist())
    axis=d/length;center=(hip+ankle)/2;radius=math.sqrt(LENGTH**2-length**2/4)
    basis=np.cross(axis,[1,0,0])
    if np.linalg.norm(basis)<.1:basis=np.cross(axis,[0,1,0])
    basis/=np.linalg.norm(basis);other=np.cross(axis,basis)
    angles=np.arange(8192)*2*math.pi/8192
    candidates=center+radius*(np.cos(angles)[:,None]*basis+np.sin(angles)[:,None]*other)
    images=candidates@P.T+H0
    dist=((images-np.asarray(target))**2).sum(1)
    dist[(candidates[:,2]<80)|(candidates[:,2]>hip[2]+15)]+=1e9
    j=int(dist.argmin());out=candidates[j]
    assert abs(np.linalg.norm(out-hip)-LENGTH)<1e-9
    assert abs(np.linalg.norm(out-ankle)-LENGTH)<1e-9
    return out

raw_shoe=np.array(shoe);ys,xs=np.where(raw_shoe[:,:,3]>0)
points=[]
for dx,dy in ((-.5,-.5),(-.5,.5),(.5,-.5),(.5,.5)):
    points.append(np.stack((xs+dx-H0[0],ys+dy-H0[1]),axis=1)@B.T)
SHOE_SURFACE=np.concatenate(points)
BODY=[np.array([0.,0.,0.]),np.array([-.9*4,0.,-70.]),np.array([.9*2,0.,38.])]*2
ARMS=[[590,615],[550,645],[475,650],[475,650],[550,645],[590,615]]
plans=[
    dict(R=('contact',H0,0,12),L=('air',[585,865],250,20,-12),K_R=[790,815],K_L=[525,810]),
    dict(R=('contact',H0,0,0,GROUND),L=('air',[665,900],270,20,0),K_R=[744,920],K_L=[690,800]),
    dict(R=('air',[680,990],220,0,-15),L=('air',[760,850],280,20,5),K_R=[720,870],K_L=[770,720]),
    dict(R=('air',[695,870],250,0,-12),L=('contact',[750,1028],20,12),K_R=[610,825],K_L=[720,850]),
    dict(R=('air',[755,905],270,0,0),L=('contact',[750,1028],20,0,GROUND),K_R=[780,805],K_L=[650,930]),
    dict(R=('air',[850,860],280,0,5),L=('air',[590,990],220,20,-15),K_R=[845,750],K_L=[640,870]),
]
frames=[]
for phase,plan in enumerate(plans):
    Q=OUT/f'phase{phase}-actual';Q.mkdir();ns['Q']=Q
    node=BODY[phase];body_raw=P@node
    results={};layers={}
    for side,hip0 in [('R',Rhip),('L',Lhip)]:
        params=plan[side]
        R,heel=(contact_foot(*params[1:]) if params[0]=='contact' else target_air_foot(*params[1:]))
        ankle=R@Af+heel;hip=hip0+node;knee=knee_ik(hip,ankle,plan['K_'+side])
        controls=np.array([proj(hip),proj(knee),proj(ankle)])
        leg=forward_material(shaft,SOURCE_R,controls,side+'-actual-complete-thigh-calf')
        matrix=P@R@B;offset=proj(heel)-matrix@H0+PAD
        foot=affine(shoe,matrix,offset);footpath=Q/(side+'-original-complete-shoe-rigid3D-projection.png');foot.save(footpath)
        layers[side]=(leg,foot)
        transformed=SHOE_SURFACE@R.T+heel
        bounds=dict(full_nonzero_RGBA_texel_quad_count=len(SHOE_SURFACE),minimum_Z=float(transformed[:,2].min()),minimum_Z_with_8native_hidden_thickness=float(transformed[:,2].min()-8),method='All native semantic source nonzero-alpha texel corners lifted by one fixed shoeplane and transformed by actual rigid3D matrix; not lowest-alphaY inference.')
        results[side]=dict(hip=hip.tolist(),knee=knee.tolist(),ankle=ankle.tolist(),heel=heel.tolist(),front_structural_sole=(R@Ff+heel).tolist(),actual_joint_controls_unpadded=controls.tolist(),rotation3D=R.tolist(),shoe_image_affine=matrix.tolist(),shoe_image_offset=offset.tolist(),shoe_surface_bounds=bounds,femur=float(np.linalg.norm(knee-hip)),tibia=float(np.linalg.norm(ankle-knee)))
    M,o=bone_affine([559,550],[481,645],np.array([559,550])+body_raw,np.array(ARMS[phase])+body_raw)
    moved_arm=affine(arm,M,o+PAD);moved_arm.save(Q/'actual-complete-LEFT-forearm-hand-counterphase.png')
    out=translate(back,body_raw)
    for side in ('L','R'):
        out.alpha_composite(layers[side][0]);out.alpha_composite(layers[side][1])
    out.alpha_composite(moved_arm);out.alpha_composite(translate(front,body_raw))
    output=Q/f'thunder_female-NE-run-phase{phase}-actual-fixed-rig-v01.png';out.save(output)
    entry=dict(phase=phase,role=['RIGHT_CONTACT','RIGHT_LOAD','LEFT_DRIVE_RIGHT_TRAIL_AIR','LEFT_CONTACT','LEFT_LOAD','RIGHT_DRIVE_LEFT_TRAIL_AIR'][phase],output=rec(output),C=2432,bodyunit=2.375,common_rig_root_unpadded=ROOT.tolist(),storage_translation=PAD.tolist(),body_node_XYZ=node.tolist(),body_node_raw=body_raw.tolist(),LEFT_free_arm_target_controls_unpadded=[(np.array([559,550])+body_raw).tolist(),(np.array(ARMS[phase])+body_raw).tolist()],legs=results,status='ACTUAL_NEW_NE_RUN_SOURCE_PENDING_FINITE_AUTHOR_AND_INDEPENDENT_QC',actor_approvals_added=0)
    (Q/'actual-fixed-body-bones-shoes-arm-controls-and-source-provenance-v01.json').write_text(json.dumps(entry,indent=2)+'\n');frames.append(entry)
    print(json.dumps(dict(phase=phase,output=rec(output),bone_error=max(abs(results[s][b]-LENGTH) for s in ('R','L') for b in ('femur','tibia')),AIR_bounds={s:results[s]['shoe_surface_bounds']['minimum_Z_with_8native_hidden_thickness'] for s in ('R','L')})),flush=True)

body_source=np.array(Image.open('/workspace/scratch/mythic413-NE-walk-author-20261020-v01/actual-NE-LOAD1-semantic-and-RIGHTstaff-finish-v04/original-native-body-coat-complete-RIGHTstaff-oldboots-removed-INPUT-v04.png').convert('RGBA'))
yy,xx=np.where((body_source[:,:,3]>=128)&(np.indices(body_source.shape[:2])[1]>850)&(np.indices(body_source.shape[:2])[0]>1000))
tip_y=int(yy.max());tip_x=float(np.median(xx[yy==tip_y]));staff_Y=tip_y-H0[1]+120
staff_tip=[.9*(tip_x-H0[0]),staff_Y,120]
contract=dict(schema='MYTHIC413_NE_RUN_ACTUAL_FIXED_RIG_SIX_SOURCE_V01',status='ACTUAL_SOURCE_RENDERED_NOT_YET_INDEPENDENTLY_APPROVED',source_files=[rec(p) for p in (BASE/'original-complete-RIGHT-upperthigh-calf-source-native.png',BASE/'RIGHT-complete-shoe-native-RGBA.png',BASE/'original-native-blue-coattails-behind-running-legs.png',BASE/'original-native-body-skirt-RIGHTstaff-foreground-old-free-arm-removed.png',ARMP)],source_rasterizer=rec(D/'author-NE-run-contact0-actual-parts-v01.py'),projection=P.tolist(),source_shoe_plane_lift=B.tolist(),source_HFA_raw=[H0.tolist(),F0.tolist(),A0.tolist()],source_HFA_XYZ_relative_heel=[np.zeros(3).tolist(),Ff.tolist(),Af.tolist()],source_leg_raw=SOURCE_R.tolist(),source_leg_XYZ=[Rhip.tolist(),Rknee.tolist(),Af.tolist()],source_LEFT_hip=Lhip.tolist(),fixed_femur_tibia_native=LENGTH,source_3D_interpretation='Declared constructive native authoring rig, not unique hidden anatomy. One original complete actual RIGHT boot is articulated on both symmetrical legs; no whole actor mirror or arbitrary perpose boot size. Original LEFT source remains preserved and is not substituted into this fixed canonical boot.',source_ankle_control_uncertainty_native=8,frames=frames,native_C=2432,bodyunit=2.375,common_rig_root_unpadded=ROOT.tolist(),storage_translation=PAD.tolist(),source_NE_exact_sameheel_delta_raw=GROUND_RAW.tolist(),source_NE_exact_sameheel_delta_XYZ=GROUND.tolist(),world_per_native_ground_unit=SOURCE_WORLD_UNIT,world_step=float(np.linalg.norm(GROUND)*SOURCE_WORLD_UNIT),clock=dict(reference_speed=210,reference_phase_hz=12.5,actual_speed=262.5,effective_phase_hz=15.625,actual_phase_dt=.064,world_per_phase=16.8),staff=dict(actual_native_bottom_tip_observed=[tip_x,tip_y],source_tip_XYZ=staff_tip,source_declared_Y_plane=staff_Y,body_XYZ_nodes=[x.tolist() for x in BODY],guarded_minimum_tip_clearance_native=min(120+x[2]-5 for x in BODY),full_original_RIGHT_staff_pixels_move_with_body_only=True,unique_hidden_staff_depth_recovery=False),whole_source_resized=False,perpose_C_or_root_fit=False,source_and_cycle_approved=False,actor_approvals_added=0,old_sources_overwritten=False)
contractpath=OUT/'NE-run-six-actual-causal-rig-shoe-surface-and-source-contract-v01.json';contractpath.write_text(json.dumps(contract,indent=2)+'\n');print(json.dumps(dict(contract=rec(contractpath),actual_frames=6,approved_frames=0)),flush=True)
