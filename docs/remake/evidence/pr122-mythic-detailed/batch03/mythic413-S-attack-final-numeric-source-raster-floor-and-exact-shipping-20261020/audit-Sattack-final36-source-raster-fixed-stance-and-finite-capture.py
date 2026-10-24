"""S ATTACK image0 exact node/rig and finite painted-material capture audit.
This does not claim unique anatomical3D or a full actor/game approval.
"""
from pathlib import Path
import json,hashlib,math
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates,label
B=Path(__file__).parent;A=Path('/workspace/scratch/mythic413-S-attack-author-20261020-v01')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def check(s):
 p=Path(s['path']);assert pin(p)['sha256']==s['sha256'];return p
def load(s):return json.loads(check(s).read_text())
def rgba(s):return np.array(Image.open(check(s)).convert('RGBA'))
CP=A/'actual-S-ATTACK6-own-native-articulated-rig-v07/S-ATTACK6-final-actual-native-SOURCE-ONE-SHOT-PASS-contract-v08.json';assert pin(CP)['sha256']=='6994157cc90d78d61e3ef8044f0ad6c4bbacc2247f314ae42fa628b735f1341d';c=json.loads(CP.read_text());m=load(c['shared_materials']);reg=load(c['shared_once_registration_exact_JSON']);source=rgba(c['source']);root=np.array(c['common_rig_root_in_unpadded_frame']);pad=np.array(c['storage_translation']);W=1792
assert c['C']==2560 and c['bodyunit']==2.5 and c['common_rig_root_in_unpadded_frame']==reg['common_rig_root_in_unpadded_frame'] and c['storage_translation']==[128,128] and c['native_canvas']==[W,W] and c['one_shot'] and c['role_seconds_preserved']==.42 and c['fps']==6/.42 and c['intended_contact_frame']==3 and not c['source_body_root_unit_OR_perposefootfit_changed'] and not c['whole_actor_mirrored']
visual=check(c['independent_final_SOURCE_and_one_shot_PASS']);assert pin(visual)['sha256']=='4a453eb39fe306f92e4a73b22334dab5cdd52efb3027e0bd0590fe1cc992bac8';v=json.loads(visual.read_text());historical=load(c['prior_actual_candidate_exact_same_six_artwork']);assert v['contract']['sha256']==c['prior_actual_candidate_exact_same_six_artwork']['sha256'];assert [{k:z for k,z in f.items() if k!='SOURCE_status'} for f in c['frames']]==[{k:z for k,z in f.items() if k!='SOURCE_status'} for f in historical['frames']]
floorpath=Path('/workspace/scratch/mythic413-S-hit-author-20261020-v01/S-original-neutral-once-true-sole-and-HIT-six-material-floor-binding-v01.json');floor=json.loads(floorpath.read_text());assert pin(floorpath)['sha256']=='b937fcb0e1fea65fae7227ebefbe508b5f352c521055006522ab10b16f02a3c2';oldnum=B/'Shit-b937fc-independent-once-neutral-source-and-actual-six-floor-companion-v01.json';prior=json.loads(oldnum.read_text());assert prior['model']==pin(floorpath);P=np.array(floor['projection_matrix']);assert np.array_equal(P,[[10/9,0,0],[0,1,-1]]) and np.array_equal(floor['projection_origin'],root);rest=floor['remaining_material_capture_plane'];assert rest['world_anchor']==[0.,180.,180.] and rest['U']==[.8999999999999999,0.,0.] and rest['V']==[0.,0.,-1.]
footmasks=[np.array(Image.open(check(z['exact_source_alpha_support'])))>0 for z in floor['source_material_capture_models']];footunion=footmasks[0]|footmasks[1];storedfeet=np.zeros((W,W),bool);storedfeet[128:1382,128:1382]=footunion
def pad0(a):
 im=Image.new('RGBA',(W,W));im.paste(Image.fromarray(a),(0,0));return im
parts={k:rgba(z)for k,z in m['parts'].items()};core=rgba(m['fullCORE']);assert np.array_equal(core[footunion],source[footunion]);corepad=np.array(pad0(core)).astype(float)/255;alpha=corepad[:,:,3]
ctl=m['actual_native_controls'];SR=np.array(ctl['RIGHT_near_shoulder'],float);ER=np.array(ctl['RIGHT_near_cuff_elbow'],float);WR=np.array(ctl['RIGHT_near_wrist'],float);G=np.array(ctl['RIGHT_original_grip'],float);SL=np.array(ctl['LEFT_anatomical_shoulder'],float);EL=np.array(ctl['LEFT_far_cuff_elbow'],float);WL=np.array(ctl['LEFT_far_wrist'],float)
def bone(a,b,d,e):
 a,b,d,e=map(lambda p:np.asarray(p,float),(a,b,d,e));u=(b-a)/np.linalg.norm(b-a);v=(e-d)/np.linalg.norm(e-d);M=np.column_stack([v*np.linalg.norm(e-d)/np.linalg.norm(b-a),[-v[1],v[0]]])@np.column_stack([u,[-u[1],u[0]]]).T;return M,d-M@a
def raster(a,M,O):
 inv=np.linalg.inv(M);q=-inv@(O+pad);return np.array(pad0(a).transform((W,W),Image.Transform.AFFINE,(*inv[0],q[0],*inv[1],q[1]),Image.Resampling.BICUBIC))
def raster_bound(a,skip=None):
 mm=a[:,:,3]>0
 if skip is not None:mm&=~skip
 yy,xx=np.where(mm);assert len(yy)>0
 return dict(actual_alpha_gt0_texel_quads=len(yy),guard_native=8,guarded_min_Z=float(root[1]+180-(yy-pad[1]).max()-.5-8))
def source_affine_bound(a,M,O):
 yy,xx=np.where(a[:,:,3]>0);grad=-M[1];z=root[1]+180-(xx*M[1,0]+yy*M[1,1]+O[1]);return dict(actual_original_source_alpha_gt0_texel_quads=len(xx),source_quad_guard_native=8,guarded_min_Z=float(z.min()-.5*abs(grad).sum()-8))
def core_y(x,y,TM,off):return y+(TM[1,0]*x+(TM[1,1]-1)*y+off[1])*np.clip((690-y)/170,0,1)
def core_source_bound(TM,off):
 yy,xx=np.where((core[:,:,3]>0)&~footunion);largest=-np.inf
 for dx in [-.5,.5]:
  x=xx+dx
  for dy in [-.5,.5]:largest=max(largest,float(core_y(x,yy+dy,TM,off).max()))
  # Piecewise quadratic extrema over each actual source texel quad.
  if abs(TM[1,1]-1)>1e-14:
   cy=(170+(TM[1,1]-1)*690-TM[1,0]*x-off[1])/(2*(TM[1,1]-1));ok=(cy>=yy-.5)&(cy<=yy+.5)&(cy>=520)&(cy<=690)
   if np.any(ok):largest=max(largest,float(core_y(x[ok],cy[ok],TM,off).max()))
  for cut in [520.,690.]:
   ok=(yy-.5<=cut)&(yy+.5>=cut)
   if np.any(ok):largest=max(largest,float(core_y(x[ok],np.full(np.count_nonzero(ok),cut),TM,off).max()))
 return dict(actual_original_source_alpha_gt0_texel_quads=len(xx),source_quad_guard_native=8,exact_piecewise_quadratic_max_native_Y=largest,guarded_min_Z=float(root[1]+180-largest-8))
fy,fx=np.where(parts['complete-rigid-RIGHT-near-staff'][:,:,3]>100);top=np.array([np.where(parts['complete-rigid-RIGHT-near-staff'][fy.min(),:,3]>100)[0].mean(),fy.min()]);bottom=np.array([np.where(parts['complete-rigid-RIGHT-near-staff'][fy.max(),:,3]>100)[0].mean(),fy.max()]);ys,xs=np.indices((W,W));tx=xs-pad[0];ty=ys-pad[1];rows=[]
for i,f in enumerate(c['frames']):
 assert f['phase']==i and f['sha256']==v['frames'][i]['sha256'] and f['common_rig_root_in_unpadded_frame']==root.tolist() and f['storage_translation']==pad.tolist() and f['physical_C']==2560
 a=rgba(dict(path=f['path'],sha256=f['sha256']));nodes=[rgba(z)for z in f['actual_composition_nodes']];assert len(nodes)==6;out=Image.new('RGBA',(W,W))
 for z in nodes:out.alpha_composite(Image.fromarray(z))
 assert np.array_equal(a,np.array(out));p=f['actual_rig_nodes_unpadded_native'];ang=math.radians(p['ang']);TM=np.array([[math.cos(ang),-math.sin(ang)],[math.sin(ang),math.cos(ang)]]);pivot=np.array([root[0],670.]);off=pivot+np.array(p['delta'])-TM@pivot
 FM,FO=bone(ER,WR,p['re'],p['rw']);grip=FM@G+FO;theta=math.radians(p['staff']);SM=np.array([[math.cos(theta),-math.sin(theta)],[math.sin(theta),math.cos(theta)]]);SO=grip-SM@G;assert np.allclose(grip,f['RIGHT_exact_foregrip_affine_grip_target'],atol=1e-10,rtol=0) and np.array_equal(SM,np.array(f['RIGHT_rigid_staff_matrix']));assert np.allclose(SM@top+SO,f['actual_original_staff_top_tip_target_unpadded'],atol=1e-10,rtol=0) and np.allclose(SM@bottom+SO,f['actual_original_staff_bottom_tip_target_unpadded'],atol=1e-10,rtol=0);assert abs(np.linalg.det(SM)-1)<1e-12 and abs(SM.T@SM-np.eye(2)).max()<1e-12
 maps={0:(*bone(SL,EL,TM@SL+off,p['le']),'LEFT-far-upper-arm'),1:(*bone(EL,WL,p['le'],p['lw']),'LEFT-far-complete-curved-cuff-forearm-free-hand'),3:(*bone(SR,ER,TM@SR+off,p['re']),'RIGHT-near-upper-arm'),4:(SM,SO,'complete-rigid-RIGHT-near-staff'),5:(FM,FO,'RIGHT-near-complete-forearm-grip-hand')};surface=[]
 for j,(M,O,k)in maps.items():
  assert np.array_equal(raster(parts[k],M,O),nodes[j]);sb=source_affine_bound(parts[k],M,O);rb=raster_bound(nodes[j]);assert min(sb['guarded_min_Z'],rb['guarded_min_Z'])>0;surface.append(dict(node=j,source=m['parts'][k],sourcecard=sb,actual_raster=rb,independent_affine_RGBA_mismatch=0))
 sx=tx.astype(float);sy=ty.astype(float)
 for _ in range(12):
  w=np.clip((690-sy)/170,0,1);dx=(TM[0,0]*sx+TM[0,1]*sy+off[0]-sx)*w;dy=(TM[1,0]*sx+TM[1,1]*sy+off[1]-sy)*w;cw=np.clip((sy-600)/300,0,1)*np.interp(sx,[0,430,450,900,925,1792],[1,1,0,0,1,1])*((sy<985)&(sy>600));dx+=p['cloth']*cw;sx=tx-dx;sy=ty-dy
 aa=map_coordinates(alpha,[sy,sx],order=1,mode='constant',cval=0);rgb=np.stack([map_coordinates(corepad[:,:,j]*alpha,[sy,sx],order=1,mode='constant',cval=0)for j in range(3)],2);rgb=np.divide(rgb,aa[:,:,None],out=np.zeros_like(rgb),where=aa[:,:,None]>1e-8);basebody=np.uint8(np.clip(np.dstack([rgb,aa])*255+.5,0,255));capmeta=c['actual_broad_proximal_skin_joint_material_and_pose_records'][i];cap=rgba(capmeta['actual_exposed_joint_surface']);mask=cap[:,:,3]>0;assert np.array_equal(basebody[~mask],nodes[2][~mask]) and np.array_equal(cap[mask],nodes[2][mask]);skin=load(capmeta['actual_source_material']);check(skin['source']);check(skin['source_semantic_mask']);inv=TM.T;cx=inv[0,0]*(tx-off[0])+inv[0,1]*(ty-off[1]);cy=inv[1,0]*(tx-off[0])+inv[1,1]*(ty-off[1]);assert np.all(((cx[mask]-712)/20)**2+((cy[mask]-360)/26)**2<=1+1e-12)
 ss=core_source_bound(TM,off);rr=raster_bound(nodes[2],storedfeet);assert min(ss['guarded_min_Z'],rr['guarded_min_Z'])>0;surface.append(dict(node=2,source=m['fullCORE'],sourcecard_without_original_sole_cards=ss,actual_raster_without_original_sole_cards=rr,body_RGBA_outside_authored_skin_surface_mismatch=0,actual_authored_skin_surface=capmeta['actual_exposed_joint_surface'],skin_surface_texels=int(mask.sum()),fixed_parent_ellipse=[712,360,20,26]))
 for fm in footmasks:assert np.array_equal(nodes[2][128:1382,128:1382][fm],source[fm])
 lab,n=label(a[:,:,3]>100);cnt=np.bincount(lab.ravel())[1:];assert np.count_nonzero(cnt>=200)==1;assert not np.any(a[[0,-1],:,3]>16) and not np.any(a[:,[0,-1],3]>16)
 rows.append(dict(phase=i,name=f['name'],actual_source=pin(f['path']),RGBA_sha256=hashlib.sha256(a.tobytes()).hexdigest(),all6node_RGBA_recomposition_mismatch=0,five_original_part_affine_reraster_RGBA_mismatch=0,original_CORE_boot_sole_capture_RGBA_mismatch=[0,0],common_C=2560,bodyunit=2.5,common_root=root.tolist(),storage_translation=pad.tolist(),RIGHT_same_foregrip_grip=grip.tolist(),RIGHT_projected_rigid_staff_orthogonality_error=float(abs(SM.T@SM-np.eye(2)).max()),RIGHT_projected_staff_determinant=float(np.linalg.det(SM)),source_and_raster_material_surfaces=surface,strong_bodies=1,storage_boundary_alpha16=0))
assert len(rows)==6 and len({z['RGBA_sha256']for z in rows})==6
q=B/'Sattack-final699415-independent36-source-raster-fixed-rig-finite-capture-v01.json';assert not q.exists();q.write_text(json.dumps(dict(status='PASS_EXACT_S_ATTACK36_NODES_FIXED_STANCE_PROJECTED_RIG_AND_FINITE_PAINTED_MATERIAL_CAPTURE',source_contract=pin(CP),actual_source_visual_PASS=pin(visual),same_six_artwork_prior= c['prior_actual_candidate_exact_same_six_artwork'],original_source=c['source'],material=c['shared_materials'],same_once_neutral_floor_model=pin(floorpath),prior_independent_fixed_sole_floor=pin(oldnum),fixed_sole_source_guarded_min_Z=1.0,common_rest_capture_plane=rest,rows=rows,limits=['Actual SOURCE/one-shot judgement is inherited from the exact peer visual receipt. This independent work does not view original art or repeat once-body registration.','All actual36 source node rasters compose exact sixRGBA; thirty original affine parts and six BODY/actual-skin retouch envelopes are independently matched. The actual feet remain in the original BODY; foreground equipment may legitimately occlude them and does not become a foot deformation.','The common original-neutral painted-material planes supply finite guarded sourcecard and actual raster bounds. They are one stationary compatibility witness, not recovered hidden anatomical3D, a calibrated physical skeleton, or a3D weapon-rotation proof. Staff rotation/length/grip are verified in the authored projected metric.','All source CORE texel-quad bounds include the exact piecewise quadratic spine-Y extrema; outer cape motion is transverse and does not alter the floor-Z bound. Genuine authored skin joint and local cape remain the separately approved native material derivatives.','FixedC/root/storage, original bodyunit, one-shot .42/contact3 and source ownership are retained. No per-pose alpha-height/root fit, source resizing, quality threshold change, game adoption or actor approval is added.'],images_viewed=0,source_PNG_modified=False,repository_changes=0,game_tests_run=0,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(proof=pin(q),actual_poses=6,nodes=36,source_and_raster_bounds_positive=True,actor_approvals_added=0)))
