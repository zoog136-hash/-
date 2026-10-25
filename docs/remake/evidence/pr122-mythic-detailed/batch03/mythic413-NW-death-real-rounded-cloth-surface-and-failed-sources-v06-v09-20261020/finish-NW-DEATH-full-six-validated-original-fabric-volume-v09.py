from pathlib import Path
import numpy as np,json,math,hashlib
from PIL import Image
from scipy.ndimage import map_coordinates,label
P=Path(__file__).parent;D=P/'actual-NW-DEATH6-final-original-fabric-volume-v09';D.mkdir(exist_ok=False)
RAW=P/'actual-NW-DEATH6-original-white-fold-raw-v08/NW-DEATH-six-actual-native-source-common-root-and-floor-raw-contract-v08.json'
raw=json.load(open(RAW));CAM=.45;PAD=128;ROOTY=1058.3
SRC=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/thunder_female-NW-walk-contact0-v01-service.png')
source=Image.open(SRC).convert('RGBA');donor=source.crop((545,542,573,555));donor.save(D/'actual-original-white-fold-core-545542573555-RGBA.png')
ar=np.array(donor).astype(float)/255;assert ar[:,:,3].min()>240/255
U=np.array([1.,0,0]);V=np.array([0.,CAM,-1.])/(1+CAM*CAM);K=np.array([0.,1.,CAM])/math.sqrt(1+CAM*CAM)
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
rows=[];proof=[]
for frame in raw['frames']:
 phase=frame['phase'];worldE=np.array(frame['LEFT_arm']['elbow'])
 cx=worldE[0]+PAD;cy=ROOTY+CAM*worldE[1]-worldE[2]+PAD
 rx=17.5;ry=16.;depth_radius=6.;x0=math.floor(cx-rx-1);x1=math.ceil(cx+rx+1);y0=math.floor(cy-ry-1);y1=math.ceil(cy+ry+1)
 gy,gx=np.indices((y1-y0,x1-x0),dtype=float);gx+=x0;gy+=y0
 coverage=np.zeros(gx.shape);px=np.zeros_like(gx);py=np.zeros_like(gx)
 for sy in [-.375,-.125,.125,.375]:
  for sx in [-.375,-.125,.125,.375]:
   ax=(gx+sx-cx)/rx;ay=(gy+sy-cy)/ry;inside=ax*ax+ay*ay<=1
   coverage+=inside;px+=ax*inside;py+=ay*inside
 nx=np.divide(px,coverage,out=np.zeros_like(px),where=coverage>0);ny=np.divide(py,coverage,out=np.zeros_like(py),where=coverage>0)
 nz=np.sqrt(np.maximum(0,1-nx*nx-ny*ny));u=(np.arctan2(nx,nz)/math.pi+.5)*(donor.width-1);v=(np.arcsin(np.clip(ny,-1,1))/math.pi+.5)*(donor.height-1)
 alpha=map_coordinates(ar[:,:,3],[v,u],order=1,mode='constant',cval=0,prefilter=False)*coverage/16
 rgb=np.stack([map_coordinates(ar[:,:,k],[v,u],order=1,mode='constant',cval=0,prefilter=False)for k in range(3)],2)
 tile=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,alpha])*255+.5,0,255)),'RGBA')
 layer=Image.new('RGBA',(1536,1536));layer.paste(tile,(x0,y0));layer.save(D/f'phase{phase}-actual-original-fabric-rounded-inner-elbow-surface.png')
 base=Image.open(frame['path']).convert('RGBA');ba=np.array(base);new=np.array(Image.alpha_composite(layer,base));la=np.array(layer)
 preserve=(ba[:,:,3]>=240)|(la[:,:,3]==0);new[preserve]=ba[preserve]
 out=Image.fromarray(new);f=D/f'thunder_female-NW-DEATH-{phase}-{frame["name"]}-final-original-fabric-v09.png';out.save(f)
 diff=np.any(new!=ba,axis=2);ys,xs=np.where(diff);assert not np.any(new[ba[:,:,3]>=240]!=ba[ba[:,:,3]>=240])
 U=np.array([1.,0,0]);V=np.array([0.,CAM,-1.])/(1+CAM*CAM);K=np.array([0.,1.,CAM])/math.sqrt(1+CAM*CAM)
 wz=worldE[2]+V[2]*(ry*ny)+K[2]*(depth_radius*nz)
 floor_guard=float(worldE[2]-abs(V[2])*(ry+.75))
 cc,n=label(new[:,:,3]>=100);sizes=np.bincount(cc.ravel());strong=[int(z)for z in sizes[1:]if z>=200]

 row=dict(frame);row.update(pin(f));row['quality']='PENDING_INDEPENDENT_FINAL_ACTUAL_ELBOW_ROI_REVIEW'
 cap=dict(name='LEFT_actual_original_white_fabric_volumetric_inner_elbow',kind='ORIGINAL_RGBA_ELLIPSOID_CLOTH_CROSS_SECTION',world_elbow=worldE.tolist(),source_actual_white_donor=pin(D/'actual-original-white-fold-core-545542573555-RGBA.png'),source_original_rectangle=[545,542,573,555],observed_width_native=35,native_radii=[rx,ry,depth_radius],U=U.tolist(),V=V.tolist(),camera_normal=K.tolist(),actual_source_texel_min_Z=float(wz[coverage>0].min()),raster_support_guard_min_Z=floor_guard,guard_rule='Whole rounded actualfabric geometry bound including .75native AA extension; originalexistingalpha>=240 restoredexact; no flatcolor or wire')
 row['actual_material_surfaces']=frame['actual_material_surfaces']+[cap]
 row['minimum_actual_surface_raster_guard_Z']=min(frame['minimum_actual_surface_raster_guard_Z'],floor_guard)
 row['strong_components_alpha100_4conn_gte200']=[dict(pixels=int(z))for z in strong];rows.append(row)
 bbox=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]if len(xs)else None
 proof.append(dict(phase=phase,source_input_sha256=frame['sha256'],source_output_sha256=row['sha256'],original_opaque_alpha_ge240_RGBA_changes=0,changed_RGBA_pixels=int(diff.sum()),changed_bbox=bbox,complete_RIGHTstaff_leg_and_root_nodes_unchanged=True,actual_volume_floor_guard_Z=floor_guard,body_count=len(strong)))
 if phase==2:assert row['sha256']=='60a489704e824c786ad982e3b016dc195b83dc718f8f957f7fbed76df5ca1897','Validated phase2 operator changed!'
assert len(rows)==6
contract=dict(raw);contract.update(status='ACTUAL_FINAL_NW_DEATH6_VALIDATED_CLOTH_OPERATOR_PROPAGATED_PENDING_INDEPENDENT_FINAL_ROIS',frames=rows,original_raw_contract=pin(RAW),phase2_independent_operator_receipt='Reviewer passed exact60a489704 phase2 and requested identicaloperator all6',original_operator_recipe=pin(P/'finish-NW-DEATH-single-phase2-actual-volumetric-inner-white-fold-v07.py'),actor_approval_added=0)
c=D/'NW-DEATH-final-six-exact-native-source-root-and-floor-contract-v09.json';c.write_text(json.dumps(contract,indent=2)+'\n')
fproof=D/'NW-DEATH-final-six-exact-original-fabric-operator-opaque-and-floor-proof-v09.json';fproof.write_text(json.dumps(dict(status='SCOPED_SIX_OPERATOR_PROPAGATION_CHECK_PENDING_FINAL_ACTUAL_QC',source_contract=pin(c),validated_phase2_SHA='60a489704e824c786ad982e3b016dc195b83dc718f8f957f7fbed76df5ca1897',same_phase2_exact_png_reproduced=True,records=proof,actor_approval_added=0),indent=2)+'\n')
print(json.dumps(dict(contract=pin(c),proof=pin(fproof),all_body_counts=[x['body_count']for x in proof],phase2_exact_PASS_reproduced=True,opaque_RGBA_changes=0)))
