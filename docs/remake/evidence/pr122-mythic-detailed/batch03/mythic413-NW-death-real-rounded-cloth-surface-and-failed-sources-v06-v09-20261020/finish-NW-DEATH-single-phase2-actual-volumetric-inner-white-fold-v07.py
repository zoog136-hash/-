"""A real original-fabric sleeve cross-section, not a line or flat paint.

The planar cloth fold collapses in transverse projection at this bend. A
rounded cloth surface retains the observed 35 native-pixel fabric width.
Original opaque art stays exact; only the missing inner surface is revealed.
"""
from pathlib import Path
import numpy as np,json,math,hashlib
from PIL import Image
from scipy.ndimage import map_coordinates,label
P=Path(__file__).parent;D=P/'actual-NW-DEATH-single-phase2-volume-v07';D.mkdir(exist_ok=False)
OLD=P/'actual-NW-DEATH6-single-phase2-native-v06/NW-DEATH-six-actual-native-source-common-root-and-floor-single-phase2-contract-v06.json'
previous=json.load(open(OLD));frame=previous['frames'][0];worldE=np.array(frame['LEFT_arm']['elbow']);CAM=.45;PAD=128;ROOTY=1058.3
SRC=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/thunder_female-NW-walk-contact0-v01-service.png')
source=Image.open(SRC).convert('RGBA');donor=source.crop((545,542,573,555));donor.save(D/'actual-original-white-fold-core-545542573555-RGBA.png')
ar=np.array(donor).astype(float)/255;assert ar[:,:,3].min()>240/255
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
layer=Image.new('RGBA',(1536,1536));layer.paste(tile,(x0,y0));layer.save(D/'actual-native-original-fabric-rounded-inner-elbow-surface.png')
base=Image.open(frame['path']).convert('RGBA');ba=np.array(base);new=np.array(Image.alpha_composite(layer,base));la=np.array(layer)
preserve=(ba[:,:,3]>=240)|(la[:,:,3]==0);new[preserve]=ba[preserve]
out=Image.fromarray(new);f=D/'thunder_female-NW-DEATH-2-KNEES2-original-fabric-volume-v07.png';out.save(f)
diff=np.any(new!=ba,axis=2);ys,xs=np.where(diff);assert not np.any(new[ba[:,:,3]>=240]!=ba[ba[:,:,3]>=240])
U=np.array([1.,0,0]);V=np.array([0.,CAM,-1.])/(1+CAM*CAM);K=np.array([0.,1.,CAM])/math.sqrt(1+CAM*CAM)
wz=worldE[2]+V[2]*(ry*ny)+K[2]*(depth_radius*nz)
floor_guard=float(worldE[2]-abs(V[2])*(ry+.75))
cc,n=label(new[:,:,3]>=100);sizes=np.bincount(cc.ravel());strong=[int(z)for z in sizes[1:]if z>=200]
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
contract=dict(status='ACTUAL_SINGLE_PHASE2_ORIGINAL_WHITE_FABRIC_VOLUME_PENDING_LOCAL_QC_NOT_FULL_SIX',phase=2,output=pin(f),previous_source=pin(Path(frame['path'])),previous_contract=pin(OLD),source_original=pin(SRC),actual_white_fabric_donor=pin(D/'actual-original-white-fold-core-545542573555-RGBA.png'),donor_source_rectangle=[545,542,573,555],source_RGBA_min=np.array(donor).min(axis=(0,1)).tolist(),geometry=dict(type='Rounded native cloth cross-section with original fabric UV on front ellipsoid',world_elbow_unchanged=worldE.tolist(),screen_center=[float(cx),float(cy)],native_radii=[rx,ry,depth_radius],observed_broad_whitefold_width_native=35,U=U.tolist(),V=V.tolist(),camera_normal=K.tolist(),source_UV='Original opaque whitefold only, sphere longitude/latitude within original28x13core; transparent outside surface, no endpoint repetition',antialias='4x4 actual ellipse coverage; material UV at covered geometry centroid'),minimum_actual_surface_Z=float(wz[coverage>0].min()),raster_floor_guard_Z=floor_guard,existing_opaque_RGBA_changes=0,changed_RGBA_pixels=int(diff.sum()),changed_bbox=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],outside_actual_surface_RGBA_changes=0,strong_components_alpha100_4conn_gte200=strong,physical_canvas_fixed=2048,body_unit=2,root_fixed=[641,1058.3],storage_translation=[128,128],original_legs_RIGHTcap_fullstaff_unchanged=True,new_services=0,new_images_received=0,actor_approval_added=0)
c=D/'NW-DEATH-phase2-real-white-fabric-volume-and-original-opaque-preservation-v07.json';c.write_text(json.dumps(contract,indent=2)+'\n')
print(json.dumps(dict(contract=pin(c),output=pin(f),changes=int(diff.sum()),bbox=contract['changed_bbox'],opaque_changes=0,floor_guard=floor_guard,strong_bodies=len(strong))))
