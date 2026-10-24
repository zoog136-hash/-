from pathlib import Path
from PIL import Image
from scipy.ndimage import map_coordinates
import numpy as np,json,hashlib
B=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020');A=Path('/workspace/scratch/mythic413-S-hit-author-20261020-v01');cp=A/'actual-S-HIT6-own-native-articulated-v01/S-HIT6-actual-own-native-body-head-LEFTguard-source-contract-v01.json';script=A/'author-S-HIT6-native-frontal-own-recoil-and-complete-front-LEFTguard-v01.py'
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def checked(q):
 assert pin(q['path'])['sha256']==q['sha256'];return Path(q['path'])
c=json.loads(cp.read_text());assert pin(cp)['sha256']=='8d0849843efc996e7ef7c2d9525d0e5c309091d5d01f8ae9957c03ab11486290';source=np.array(Image.open(checked(c['source_identity'])).convert('RGBA'));reg=json.loads(checked(c['once_body_registration']).read_text());hand=json.loads(checked(c['shared_actual_LEFT_material_handoff']).read_text());checked(c['independent_base_source_body_gate']);checked(c['actual_only_LEFT_erased_native_BODY']);checked(c['actual_semantic_rasterizer_definition'])
assert c['C']==2560 and c['bodyunit']==2.5 and c['common_rig_root_unpadded']==reg['common_rig_root_in_unpadded_frame'] and c['storage_translation']==[128.,128.] and c['native_size']==[1536,1536] and c['role_seconds']==.22 and abs(c['phase_seconds']-.22/6)<1e-12
Y,X=np.indices((1254,1254));legs=(Y>=1020)|((Y>=650)&(X>=440)&(X<=850));protect=np.array(Image.open(checked(c['fixed_original_RIGHTgear_conservative_native_support'])))>0
# Exact bilinear interpolation and its within-cell derivatives, independent
# of the producer's finite-difference Newton inverse implementation.
def bilinear(f,x,y):
 xx=np.clip(x,0,f.shape[1]-1);yy=np.clip(y,0,f.shape[0]-1);ix=np.minimum(np.floor(xx).astype(int),f.shape[1]-2);iy=np.minimum(np.floor(yy).astype(int),f.shape[0]-2);u=xx-ix;v=yy-iy;a=f[iy,ix];b=f[iy,ix+1];cc=f[iy+1,ix];d=f[iy+1,ix+1]
 val=(1-u)*(1-v)*a+u*(1-v)*b+(1-u)*v*cc+u*v*d;gx=(1-v)*(b-a)+v*(d-cc);gy=(1-u)*(cc-a)+u*(d-b)
 gx=np.where((x>=0)&(x<=f.shape[1]-1),gx,0);gy=np.where((y>=0)&(y<=f.shape[0]-1),gy,0);return val,gx,gy
rows=[]
for i,f in enumerate(c['frames']):
 checked(f['source']);checked(f['source_complete_LEFT_native_material']);mesh=json.loads(checked(f['actual_LEFT_guard_forward_mesh']).read_text());z=np.load(checked(f['actual_body_forward_flow']),allow_pickle=False);assert set(z.files)=={'dX','dY'} and z['dX'].dtype==z['dY'].dtype==np.dtype('float32') and z['dX'].shape==z['dY'].shape==(1254,1254);fx=z['dX'].astype(float);fy=z['dY'].astype(float)
 j=(1+np.gradient(fx,axis=1))*(1+np.gradient(fy,axis=0))-np.gradient(fx,axis=0)*np.gradient(fy,axis=1);minimum=float(j.min());assert abs(minimum-f['body_flow_definition']['minimum_dense_Jacobian_determinant'])<1e-10 and minimum>.01
 # A bilinear cell Jacobian determinant is affine inside the cell. Checking
 # all four corners bounds the whole sampled cell, not only grid centres.
 ux0=1+fx[:-1,1:]-fx[:-1,:-1];uy0=fy[:-1,1:]-fy[:-1,:-1];ux1=1+fx[1:,1:]-fx[1:,:-1];uy1=fy[1:,1:]-fy[1:,:-1];vx0=fx[1:,:-1]-fx[:-1,:-1];vy0=1+fy[1:,:-1]-fy[:-1,:-1];vx1=fx[1:,1:]-fx[:-1,1:];vy1=1+fy[1:,1:]-fy[:-1,1:]
 cellmin=min(float((ux*vy-uy*vx).min())for ux,uy in [(ux0,uy0),(ux1,uy1)]for vx,vy in [(vx0,vy0),(vx1,vy1)]);assert cellmin>.01
 knots=np.array(f['LEFT_actual_source_knots']);target=np.array(f['LEFT_actual_guard_knots_unpadded']);mapped=knots[:2]+np.column_stack((map_coordinates(fx,[knots[:2,1],knots[:2,0]],order=1,mode='nearest',prefilter=False),map_coordinates(fy,[knots[:2,1],knots[:2,0]],order=1,mode='nearest',prefilter=False)));kerr=float(np.max(abs(mapped-target[:2])));assert kerr<1e-10
 assert mesh['source_knots']==f['LEFT_actual_source_knots'] and mesh['target_knots_unpadded']==f['LEFT_actual_guard_knots_unpadded'] and mesh['storage_translation']==[128.,128.]
 theta=np.deg2rad(f['LEFT_guard_target_angle']);assert np.max(abs(target[2]-(target[1]+f['LEFT_guard_projected_length']*np.array([np.cos(theta),np.sin(theta)]))))<1e-10
 # Sample the independent analytic-derivative inverse on a 16pixel target
 # lattice plus actual shared attachment knots; producer all-pixel residual
 # remains separately pinned, not represented as rechecked here.
 sy,sx=np.meshgrid(np.arange(0,1254,16),np.arange(0,1254,16),indexing='ij');tx=np.r_[sx.ravel(),target[:2,0]];ty=np.r_[sy.ravel(),target[:2,1]];ax=tx.copy();ay=ty.copy()
 # At a steep fixed-material boundary a full Newton step can cross several
 # bilinear cells and oscillate. Backtrack each point against actual residual;
 # failure to converge is an audit-solver issue until this check is resolved.
 for step in range(48):
  dx,jx0,jx1=bilinear(fx,ax,ay);dy,jy0,jy1=bilinear(fy,ax,ay);rx=ax+dx-tx;ry=ay+dy-ty;det=(1+jx0)*(1+jy1)-jx1*jy0;assert det.min()>.01
  if max(abs(rx).max(),abs(ry).max())<1e-10:break
  hx=((1+jy1)*rx-jx1*ry)/det;hy=((1+jx0)*ry-jy0*rx)/det;old=rx*rx+ry*ry;scale=np.ones_like(ax)
  for backtrack in range(20):
   nx=ax-scale*hx;ny=ay-scale*hy;vx,_,_=bilinear(fx,nx,ny);vy,_,_=bilinear(fy,nx,ny);err=(nx+vx-tx)**2+(ny+vy-ty)**2;bad=(err>old+1e-26)&(old>1e-20)
   if not np.any(bad):break
   scale[bad]*=.5
  ax-=scale*hx;ay-=scale*hy
 dx,_,_=bilinear(fx,ax,ay);dy,_,_=bilinear(fy,ax,ay);res=float(max(np.max(abs(ax+dx-tx)),np.max(abs(ay+dy-ty))));assert res<1e-9
 png=np.array(Image.open(f['source']['path']).convert('RGBA'));assert png.shape==(1536,1536,4);nat=png[128:1382,128:1382];assert np.array_equal(nat[legs],source[legs]) and np.array_equal(nat[protect],source[protect]);rightflow=max(float(abs(fx[protect]).max()),float(abs(fy[protect]).max()));assert rightflow<1e-9
 assert f['C']==2560 and f['bodyunit']==2.5 and f['common_rig_root_unpadded']==c['common_rig_root_unpadded'] and f['storage_translation']==[128.,128.] and np.max(abs(np.array(f['stored_common_root'])-np.array(c['common_rig_root_unpadded'])-[128,128]))<1e-10
 rows.append(dict(phase=i,role=f['role'],source=f['source'],actual_float32_flow=f['actual_body_forward_flow'],actual_LEFT_guard_mesh=f['actual_LEFT_guard_forward_mesh'],dense_central_difference_Jacobian_min=minimum,all_bilinear_cell_corner_Jacobian_min=cellmin,shared_proximal_elbow_flow_attachment_max_error=kerr,independent_analytic_derivative_inverse_sample_count=len(tx),independent_sample_inverse_residual=res,producer_pinned_all_pixel_inverse_residual=f['body_inverse_maximum_residual'],complete_original_fixed_legs_RGBA_changes=0,full_original_RIGHT_foregrip_staff_RGBA_changes=0,full_RIGHT_material_forward_flow_max=rightflow))
assert len(rows)==6 and len({x['source']['sha256']for x in rows})==6
p=B/'Shit-v01-8d0849-independent-actual-flow-shared-attachments-fixed-material-companion-v01.json';assert not p.exists();p.write_text(json.dumps(dict(status='PASS_FINITE_ACTUAL_DENSE_FLOW_SHARED_ATTACHMENT_AND_FIXED_MATERIAL_BINDING',source_contract=pin(cp),actual_renderer_readonly=pin(script),once_body_numeric_reference=pin(Path('/workspace/scratch/mythic413-S-base-independent-qc-20261020-v01/S-c9a5-once-body-C2560-root-independent-numeric-companion-v01.json')),rows=rows,limits=['All stored flow grid values and every bilinear cell corner Jacobian are checked. Positive local cell Jacobians establish no observed local folded cell, not a general proof of global injectivity of an arbitrary continuous map.','Independent inverse validation uses an analytic-bilinear-derivative Newton solve on a16pixel target lattice and actual shared attachment knots. The producer full-grid inverse bound is retained as pinned separate evidence rather than falsely called independently rerun.','Read-only code confirms the exact stored float32 fields drive actual body inverse sampling and the two shared LEFT proximal/elbow attachment positions. Native six fixed lowerlegs/fullRIGHTgripstaff are directly compared with the original raster.','No images were viewed, no new source pixels generated, and no floor/hidden3D model is approved. Actual source/role/joint/cycle naturalness and game binding remain the fresh primary reviewer/parent scope.'],images_viewed=0,tests_run=0,repo_writes=0,actor_approvals_added=0),ensure_ascii=False,indent=2)+'\n');print(json.dumps(dict(proof=pin(p),minimum_cell_jacobian=min(r['all_bilinear_cell_corner_Jacobian_min']for r in rows),maximum_independent_sample_inverse_residual=max(r['independent_sample_inverse_residual']for r in rows))))
