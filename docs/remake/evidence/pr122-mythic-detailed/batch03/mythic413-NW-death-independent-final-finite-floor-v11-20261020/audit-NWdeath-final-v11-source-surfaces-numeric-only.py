from pathlib import Path
from PIL import Image
import numpy as np
import json,hashlib
B=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020')
A=Path('/workspace/scratch/mythic413-NW-death-author-20261020-v01')
cp=A/'NW-DEATH-final-six-actual-source-constant-root-and-native-registration-v11.json'
mp=A/'NW-DEATH-exact-editable-source-semantic-map-v01/NW-DEATH-v09-plus-phase0v10-exact-editable-material-surface-source-map-v01.json'
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def checked(q):
 assert pin(q['path'])['sha256']==q['sha256'];return Path(q['path'])
c=json.loads(cp.read_text());m=json.loads(mp.read_text());assert pin(cp)['sha256']=='3cfeeeb94a8e8756daa7469209f6bac78d6b9ec452cebb67383cf115bf6dd4f3';assert pin(mp)['sha256']=='a2a9c1e07eb3fbaca81d28ad44fd144e7924c83613a8b121f88365e79e03c992'
assert c['physical_canvas_fixed']==2048 and c['body_unit_fixed']==2 and c['common_unpadded_root']==[641.,1058.3] and c['storage_translation']==[128,128] and c['storage_canvas']==[1536,1536]
assert c['constant_true_leg_length_native_world']==200 and c['runtime_death_duration']==.8 and abs(c['frame_duration']-.8/6)<1e-12 and c['resource_role_seconds']==.65 and abs(c['resource_role_fps']-6/.65)<1e-12 and not c['loop'] and c['terminal_held'] and not c['profile_or_fade_modified']
N=1536;PAD=128;ROOTY=1058.3;P=np.array([[1,0,0],[0,.45,-1]])
alpha={};masks={};files=[]
for f in m['unique_actual_source_files']:
 p=checked(f);im=Image.open(p).convert('RGBA').getchannel('A');alpha[str(p)]=im;masks[str(p)]=np.array(im)>0;files.append(pin(p))
def imdata(q):
 p=str(checked(q));return alpha.get(p) or Image.open(p).convert('RGBA').getchannel('A')
def proj(w):return np.array([w[0],ROOTY+.45*w[1]-w[2]])
errors=[];affine=[];mesh=[];volume=[];bones=[];staff=[];frames=[]
for i,(f,mf) in enumerate(zip(c['frames'],m['frames'])):
 assert f['phase']==mf['phase']==i and f['sha256']==mf['actual_rendered_frame']['sha256']==pin(f['path'])['sha256']
 a=Image.open(f['path']);assert a.size==(N,N)
 frames.append(dict(phase=i,source=pin(f['path'])))
 for side,j in f['leg_world_joints'].items():
  H,K,V=[np.array(j[k]) for k in ['hip','knee','ankle']];err=max(abs(np.linalg.norm(H-K)-200),abs(np.linalg.norm(K-V)-200));assert err<1e-9;bones.append(dict(phase=i,side=side,femur_tibia_error=err))
 ru=np.array(f['RIGHT_arm']['rigid_U']);rv=np.array(f['RIGHT_arm']['rigid_V']);gram=np.column_stack((ru,rv)).T@np.column_stack((ru,rv));assert np.max(abs(gram-np.eye(2)))<1e-10
 staff.append(dict(phase=i,whole_staff_capture_axes_Gram_error=float(np.max(abs(gram-np.eye(2))))))
 assert len(f['actual_material_surfaces'])==len(mf['surfaces'])
 for declared,entry in zip(f['actual_material_surfaces'],mf['surfaces']):
  q=entry['geometry'];assert q==declared and q['name']==entry['name'];kind=entry['kind'];name=q['name'];im=imdata(entry['actual_source']);mask=np.array(im)>0;ys,xs=np.where(mask)
  if kind=='ACTUAL_RGBA_AFFINE_PLANE':
   sa=np.array(q['source_anchor']);wa=np.array(q['world_anchor']);U=np.array(q['U']);V=np.array(q['V']);M=P@np.column_stack((U,V));assert np.max(abs(M-q['projected_matrix']))<1e-10
   assert len(xs)==q['source_alpha_nonzero_pixels']==entry['source_alpha_nonzero_pixels']
   z=wa[2]+U[2]*(xs-sa[0])+V[2]*(ys-sa[1]);smin=float(z.min());decl_guard=smin-1.5*(abs(U[2])+abs(V[2]));assert abs(smin-q['actual_source_texel_min_Z'])<1e-8 and abs(decl_guard-q['raster_support_guard_min_Z'])<1e-8
   inv=np.linalg.inv(M);off=sa-inv@(proj(wa)+PAD);out=im.transform((N,N),Image.Transform.AFFINE,(inv[0,0],inv[0,1],off[0],inv[1,0],inv[1,1],off[1]),Image.Resampling.BICUBIC);oy,ox=np.where(np.array(out)>0);grad=np.array([U[2],V[2]])@inv
   oz=wa[2]+grad@np.stack((ox-PAD-proj(wa)[0],oy-PAD-proj(wa)[1]));actual_quad=float(oz.min()-.5*np.abs(grad).sum())
   source_quad=smin-.5*(abs(U[2])+abs(V[2]));row=dict(phase=i,name=name,actual_source=entry['actual_source'],source_alpha_positive_pixels=len(xs),source_center_minZ=smin,source_centered_texel_quad_minZ=source_quad,author_source_AA_guard_minZ=decl_guard,independent_actual_affine_raster_alpha_pixels=len(ox),independent_actual_raster_centered_texel_quad_minZ=actual_quad)
   if min(source_quad,decl_guard,actual_quad)<-1e-8:errors.append(row)
   if 'whole_coat'in entry or 'original_whole_coat'in entry:
    orig=np.array(Image.open(checked(entry['original_whole_coat'])).convert('RGBA'));part=np.array(Image.open(checked(entry['actual_source'])).convert('RGBA'));keep=(np.indices(part.shape[:2])[0]<=entry['source_split_y'])if entry['split_rule']=='y <= cut' else(np.indices(part.shape[:2])[0]>entry['source_split_y']);assert np.array_equal(part[keep],orig[keep]) and not part[~keep,3].any()
   affine.append(row)
  elif kind=='CONTINUOUS_ORIGINAL_RGBA_3D_UV_MESH':
   E=np.array(q['world_elbow']);se=np.array(q['source_elbow_approx']);U=np.array(q['upper_U']);V=np.array(q['upper_V']);fu=np.array(q['fore_U']);fv=np.array(q['fore_V'])
   def world(x,y):
    x,y=np.broadcast_arrays(np.asarray(x,float),np.asarray(y,float));w=np.clip((y-540)/30,0,1);w=w*w*(3-2*w);upper=E+(x-se[0])[...,None]*U+(y-se[1])[...,None]*V;fore=E+(x-se[0])[...,None]*fu+(y-se[1])[...,None]*fv;return upper*(1-w[...,None])+fore*w[...,None]
   actual=world(xs,ys);smin=float(actual[:,2].min());assert len(xs)==q['source_alpha_nonzero_pixels'] and abs(smin-q['actual_source_texel_min_Z'])<1e-8
   x0,y0,x1,y1=q['source_uv_bounds_padded'];gx=np.unique(np.r_[np.arange(x0,x1+1,5),x1]);gy=np.unique(np.r_[np.arange(y0,y1+1,5),y1,535,540,550,558,570]);gy=gy[(gy>=y0)&(gy<=y1)];sx,sy=np.meshgrid(gx,gy);wp=world(sx,sy);vmin=float(wp[:,:,2].min());assert abs(vmin-q['raster_support_guard_min_Z'])<1e-8
   row=dict(phase=i,name=name,actual_source=entry['actual_source'],actual_source_alpha_pixels=len(xs),source_center_minZ=smin,padded_actual_UV_triangle_vertex_minZ=vmin,all_actual_triangle_barycentric_raster_Z_bounded_by_vertex_min=True,source_UV_bounds=q['source_uv_bounds_padded'])
   if min(smin,vmin)<-1e-8:errors.append(row)
   mesh.append(row)
  elif kind=='ORIGINAL_RGBA_ELLIPSOID_CLOTH_CROSS_SECTION':
   checked(entry['actual_rendered_RGBA_layer']);U=np.array(q['U']);V=np.array(q['V']);K=np.array(q['camera_normal']);E=np.array(q['world_elbow']);assert np.max(abs(P@K))<1e-10
   M=P@np.column_stack((U,V));inv=np.linalg.inv(M);layer=np.array(Image.open(entry['actual_rendered_RGBA_layer']['path']).convert('RGBA'));yy,xx=np.where(layer[:,:,3]>0);uv=inv@np.stack((xx-PAD-proj(E)[0],yy-PAD-proj(E)[1]));extent=np.max(abs(uv),axis=1)+.5*np.abs(inv).sum(axis=1);depth=q['native_radii'][2];minimum=float(E[2]-extent[0]*abs(U[2])-extent[1]*abs(V[2])-depth*abs(K[2]));row=dict(phase=i,name=name,actual_donor=entry['actual_source'],actual_rendered_original_fabric=entry['actual_rendered_RGBA_layer'],actual_raster_alpha_pixels=len(xx),entire_actual_pixel_quad_parameter_extents=extent.tolist(),declared_volume_depth=depth,conservative_entire_actual_raster_box_plus_full_depth_minZ=minimum,camera_null_normal_projection=(P@K).tolist())
   if minimum<-1e-8:errors.append(row)
   volume.append(row)
  else:raise AssertionError(kind)
proof=dict(status='PASS_FINITE_DECLARED_SURFACE_MODEL_SOURCE_AND_ACTUAL_RASTER_BOUNDS'if not errors else'HOLD_DECLARED_SURFACE_MODEL_ACTUAL_RASTER_BOUND',source_contract=pin(cp),exact_editable_source_map=pin(mp),source_files=files,source_frames=frames,unchanged_runtime_death_seconds=.8,unchanged_resource_role_seconds=.65,phase_seconds=.8/6,held_terminal=True,projection=P.tolist(),physical_C=2048,root=[641,1058.3],storage_translation=[128,128],twelve_fixed_200_native_bone_checks=bones,complete_original_RIGHT_staff_rigid_axes_checks=staff,affine_source_and_actual_raster_surface_checks=affine,continuous_original_actual_UV_mesh_checks=mesh,actual_original_fabric_rounded_volume_checks=volume,findings=errors,limits=['This reconstructs and independently bounds one declared compatible source-capture/UV material model. It does not uniquely recover hidden anatomical depths or turn a numeric witness into wholeactor approval.','Affine sourcePNG alpha and actual interpolated raster centered pixel-quads are checked independently. Curved native mesh raster heights are bounded by the exact padded source-UV triangle vertices; original fabric volume uses the full actual raster footprint and conservative full declared depth envelope.','Visible fall/held/source/joint naturalness and exact final game binding belong to the fresh primary source reviewer and parent. No new image views or assets/Git/game modifications were performed.'],images_viewed=0,tests_run=0,repo_writes=0,actor_approvals_added=0)
p=B/'NWdeath-v11-3cfeee-independent-finite-source-actual-raster-floor-companion-v01.json';assert not p.exists();p.write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(dict(proof=pin(p),status=proof['status'],affine_checks=len(affine),curved_mesh_checks=len(mesh),actual_volume_checks=len(volume),findings=errors[:6],minimum_independent_affine_raster_quad_Z=min(x['independent_actual_raster_centered_texel_quad_minZ']for x in affine),minimum_volume_box_depth_Z=min(x['conservative_entire_actual_raster_box_plus_full_depth_minZ']for x in volume))))
