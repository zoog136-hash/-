"""Numeric-only final SW attack: source-owned48 surfaces, projected rig and floor.
Mathematical render functions are extracted without top-level author execution.
No PNG writes/views, source changes or runtime adoption.
"""
from pathlib import Path
from PIL import Image
from scipy.ndimage import map_coordinates,label
import numpy as np,json,hashlib,math,ast
B=Path(__file__).parent;A=Path('/workspace/scratch/mythic413-SW-attack-author-fresh-20261020-v01')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def check(z):
 p=Path(z['path']);assert pin(p)['sha256']==z['sha256'];return p
def load(z):return json.loads(check(z).read_text())
cp=A/'frozen-SW-ATTACK6-independent-SOURCE-PASS-metadata-v01/SW-ATTACK6-final-actual-native-SOURCE-ONE-SHOT-PASS-contract-v01.json';assert pin(cp)['sha256']=='5ef9a306f1af711b2b28f247fffa285cb6ff64be8279bbd691ac59c8b46fd112';c=json.loads(cp.read_text());v=load(c['independent_actual_SOURCE_one_shot_review']);assert c['independent_actual_SOURCE_one_shot_review']['sha256']=='286b58379415fb13c43175c9aba7c1f4d6b95db2b6f3e2e0d5af674ac8e81d4b';prior=load(c['exact_reviewed_native_candidate']);m=load(c['exact_native_parts_contract']);reg=load(c['exact_once_registration']);root=np.array(c['common_rig_root_unpadded']);pad=np.array(c['storage_translation']);assert c['C']==2496 and c['bodyunit']==2.4375 and root.tolist()==reg['common_rig_root_in_unpadded_frame'] and pad.tolist()==[384,128] and c['native_canvas']==[1792,1792] and c['role_seconds']==.42 and not c['loop'] and c['contact_phase']==3
for f,h in zip(c['frames'],prior['frames']):assert {k:z for k,z in f.items()if k!='status'}=={k:z for k,z in h.items()if k!='status'}
source=np.array(Image.open(check(c['source'])).convert('RGBA'));parts={};owners=np.zeros(source.shape[:2],np.uint8);recon=np.zeros_like(source)
for i,(name,z)in enumerate(m['parts'].items(),1):
 a=np.zeros_like(source);x,y,ex,ey=z['native_crop_box'];a[y:ey,x:ex]=np.array(Image.open(check(z)).convert('RGBA'));mask=a[:,:,3]>0;assert not owners[mask].any() and np.array_equal(a[mask],source[mask]);owners[mask]=i;recon[mask]=a[mask];parts[name]=a
assert np.array_equal(recon,source)
core=np.zeros_like(source)
for name in ['BODY-own-chest-waist-ribbons','HEAD-own-hair-face-crown','NECK-own-skin-collar-gems','COAT-own-native-UV-tails']:core+=parts[name]
floorp=Path('/workspace/scratch/mythic413-SW-hit-author-20261020-v01/SW-original-neutral-once-true-sole-and-HIT-six-material-floor-binding-v01.json');assert pin(floorp)['sha256']=='50cff5b869ae33e459f2cb64be28bb116696a414e048c5defd7b2c968482f334';floor=json.loads(floorp.read_text());old=B/'SW-hit-50cff5-independent-once-neutral-source-and-actual-six-floor-companion-v01.json';assert json.loads(old.read_text())['model']==pin(floorp);assert floor['projection_origin']==root.tolist() and floor['projection_matrix']==[[10/9,0,0],[0,1,-1]];rest=floor['remaining_material_capture_plane'];assert rest['world_anchor']==[0.,180.,180.] and rest['native_guard']==8
solemasks=[np.array(Image.open(check(z['exact_source_alpha_support'])))>0 for z in floor['source_material_capture_models']];sole=solemasks[0]|solemasks[1];boots=parts['LEGS-original-full-boots-fixed'];assert np.array_equal(boots[sole],source[sole]);SIZE=1792;yy,xx=np.indices((SIZE,SIZE));wx=xx-pad[0];wy=yy-pad[1];storedsole=np.zeros((SIZE,SIZE),bool);storedsole[128:1382,384:1638]=sole
renderer=A/'author-own-SW-ATTACK6-native-connected-shoulder-fixed-local-sampling-v10.py';ver=load(c['positive_native_material_field_verification']);assert ver['actual_renderer']==pin(renderer)
module=ast.parse(renderer.read_text());wanted=['smooth','rot','field','bodypoint','sampled','affine','bend','upper_join'];definitions=[z for z in module.body if isinstance(z,ast.FunctionDef)and z.name in wanted];assert len(definitions)==8
ns=dict(np=np,math=math,Image=Image,map_coordinates=map_coordinates,PIV=np.array([655.,539.]),NECK=np.array([628.,331.]),worldx=wx,worldy=wy,PAD=pad,SIZE=SIZE);exec(compile(ast.Module(definitions,[]),'exact-author-mathematical-functions-only-no-IO','exec'),ns)
def actualbound(a,skip=None):
 mask=a[:,:,3]>0
 if skip is not None:mask &= ~skip
 y,x=np.where(mask);assert len(y);return dict(alpha_gt0_texel_quads=int(len(y)),native_guard=8,guarded_min_Z=float(root[1]+180-(y-pad[1]).max()-.5-8))
def affinebound(a,M,O,skip=None):
 mask=a[:,:,3]>0
 if skip is not None:mask&=~skip
 y,x=np.where(mask);Y=x*M[1,0]+y*M[1,1]+O[1];maximum=float(Y.max()+.5*np.abs(M[1]).sum());return dict(source_alpha_gt0_texel_quads=len(y),source_max_quad_projected_Y=maximum,guard_native=8,guarded_min_Z=float(root[1]+180-maximum-8))
def bodybound(a,p):
 y,x=np.where(a[:,:,3]>0);xmin,xmax=float(x.min()-.5),float(x.max()+.5);ymin,ymax=float(y.min()-.5),float(y.max()+.5)
 # Every smoothstep is in [0,1]. Left and right outer-cloth supports are
 # disjoint, hence summed clothweight<=1; ribbon product also in [0,1].
 angle=math.radians(p['body_deg']);head=math.radians(p['head_deg']);delta=abs(math.sin(angle))*max(abs(xmin-655),abs(xmax-655))+abs(math.cos(angle)-1)*max(abs(ymin-539),abs(ymax-539))+abs(p['torso'][1])+abs(math.sin(head))*max(abs(xmin-628),abs(xmax-628))+abs(math.cos(head)-1)*max(abs(ymin-331),abs(ymax-331))+abs(p['cloth'][1])+abs(p['ribbon'][1]);maximum=ymax+delta
 return dict(source_alpha_gt0_texel_quads=len(y),conservative_all_source_quad_Y_upper=maximum,conservative_abs_field_Y_bound=delta,guard_native=8,guarded_min_Z=float(root[1]+180-maximum-8))
ctl=m['controls'];SR,ER,WR,G,SL,EL,WL=[np.array(ctl[k])for k in ['RIGHT_shoulder','RIGHT_elbow','RIGHT_wrist','RIGHT_grip','LEFT_shoulder','LEFT_elbow','LEFT_wrist']];ty,tx=np.indices(source.shape[:2]);bodymask=core[:,:,3]>0;rows=[]
for i,f in enumerate(c['frames']):
 assert i==f['phase'] and f['C']==2496 and f['common_rig_root_unpadded']==root.tolist() and f['storage_translation']==pad.tolist();actual=np.array(Image.open(check(f['source'])).convert('RGBA'));p=f['actual_phase_parameters'];sx=wx.astype(float);sy=wy.astype(float)
 for _ in range(18):dx,dy=ns['field'](sx,sy,p);sx=wx-dx;sy=wy-dy
 dx,dy=ns['field'](sx,sy,p);support=map_coordinates(core[:,:,3],[sy,sx],order=0,mode='constant',cval=0,prefilter=False)>0;res=float(max(np.max(abs(sx+dx-wx)[support]),np.max(abs(sy+dy-wy)[support])));assert res<1e-4 and abs(res-f['body_inverse_residual'])<1e-10
 body=ns['sampled'](core,sx,sy);ru=ns['rot'](p['body_deg']+p['upper_deg']);ro=ns['bodypoint'](SR,p)-ru@SR;re=ru@ER+ro;rf=ns['rot'](p['fore_deg']);fo=re-rf@ER;lu=ns['rot'](p['body_deg']+p['left_upper']);lo=ns['bodypoint'](SL,p)-lu@SL;le=lu@EL+lo;lf=ns['rot'](p['left_fore']);lfo=le-lf@EL
 for k,a in [('RIGHT_upper_matrix',ru),('RIGHT_upper_offset',ro),('RIGHT_forearm_puff_fullstaff_identical_rigid_matrix',rf),('RIGHT_forearm_puff_fullstaff_identical_offset',fo),('RIGHT_elbow',re),('RIGHT_actual_grip',rf@G+fo),('LEFT_upper_matrix',lu),('LEFT_upper_offset',lo),('LEFT_forearm_matrix',lf),('LEFT_forearm_offset',lfo),('LEFT_elbow',le)]:assert np.allclose(a,f[k],atol=1e-10,rtol=0)
 assert abs(np.linalg.det(rf)-1)<1e-12 and abs(rf.T@rf-np.eye(2)).max()<1e-12
 layerlu,err=ns['upper_join'](parts['LEFT-full-upper-arm'],lu,lo,p);assert abs(err-f['LEFT_upper_actual_source_inverse_residual'])<1e-10
 layers=[('BODY-HEAD-NECK-COAT-native-material',body),('LEGS-original-full-boots-fixed',ns['affine'](boots,np.eye(2),[0,0])),('LEFT-full-upper-arm',layerlu),('LEFT-complete-curved-cuff-forearm-free-fingers',ns['bend'](parts['LEFT-complete-curved-cuff-forearm-free-fingers'],lu,lo,lf,lfo,EL,(WL-EL)/np.linalg.norm(WL-EL))),('RIGHT-full-upper-arm-and-shoulder',ns['affine'](parts['RIGHT-full-upper-arm-and-shoulder'],ru,ro)),('complete-rigid-RIGHT-staff',ns['affine'](parts['complete-rigid-RIGHT-staff'],rf,fo)),('RIGHT-white-puff-elbow',ns['affine'](parts['RIGHT-white-puff-elbow'],rf,fo)),('RIGHT-complete-forearm-cuff-grip-fingers',ns['affine'](parts['RIGHT-complete-forearm-cuff-grip-fingers'],rf,fo))]
 out=Image.new('RGBA',(SIZE,SIZE));surface=[]
 for name,im in layers:
  a=np.array(im)
  if name!='LEFT-full-upper-arm':out.alpha_composite(im)
  else:
   under=np.array(out).astype(float);arm=a.astype(float);out.alpha_composite(im);prox=(sy<=383)&(sx>=680)&(sx<=760)&(under[:,:,3]>0)&(arm[:,:,3]>0);aa=arm[:,:,3];ba=under[:,:,3];den=aa+ba;rgb=np.divide(arm[:,:,:3]*aa[:,:,None]+under[:,:,:3]*ba[:,:,None],den[:,:,None],out=np.zeros_like(arm[:,:,:3]),where=den[:,:,None]>0);union=np.uint8(np.clip(np.dstack((rgb,np.minimum(255,den)))+.5,0,255));oa=np.array(out);oa[prox]=union[prox];out=Image.fromarray(oa)
  if name.startswith('LEGS'):
   sb=affinebound(boots,np.eye(2),np.zeros(2),sole);rb=actualbound(a,storedsole)
  elif name.startswith('BODY'):
   sb=bodybound(core,p);rb=actualbound(a)
  elif name=='LEFT-full-upper-arm':
   b=bodybound(parts[name],p);aff=affinebound(parts[name],lu,lo);sb=dict(conservative_convex_body_upper_bound=True,body_source_bound=b,affine_source_bound=aff,guarded_min_Z=min(b['guarded_min_Z'],aff['guarded_min_Z']));rb=actualbound(a)
  elif name.startswith('LEFT-complete'):
   u=affinebound(parts[name],lu,lo);t=affinebound(parts[name],lf,lfo);sb=dict(convex_blend_all_source_quads=True,upper_bound=u,fore_bound=t,guarded_min_Z=min(u['guarded_min_Z'],t['guarded_min_Z']));rb=actualbound(a)
  else:
   matrix,offset=(ru,ro)if name.startswith('RIGHT-full-upper')else(rf,fo);sb=affinebound(parts[name],matrix,offset);rb=actualbound(a)
  assert min(sb['guarded_min_Z'],rb['guarded_min_Z'])>0;surface.append(dict(node=name,source_surface=sb,actual_raster=rb,actual_RGBA_sha256=hashlib.sha256(a.tobytes()).hexdigest()))
 result=np.array(out);footmask=boots[:,:,3]>0;result[128:1382,384:1638][footmask]=boots[footmask];assert np.array_equal(result,actual)
 for sm in solemasks:assert np.array_equal(actual[128:1382,384:1638][sm],source[sm])
 # Analytic field definition sampled at all actual source material texels;
 # this is a finite grid field witness, not a global continuous Jacobian proof.
 dx,dy=ns['field'](tx.astype(float),ty.astype(float),p);det=(1+np.gradient(dx,axis=1))*(1+np.gradient(dy,axis=0))-np.gradient(dx,axis=0)*np.gradient(dy,axis=1);minimum=float(det[bodymask].min());assert minimum>0
 lab,n=label(actual[:,:,3]>100);counts=np.bincount(lab.ravel())[1:];assert np.count_nonzero(counts>=200)==1 and not np.any(actual[[0,-1],:,3]>16) and not np.any(actual[:,[0,-1],3]>16)
 rows.append(dict(phase=i,role=f['role'],actual_source=pin(f['source']['path']),actual_RGBA_sha256=hashlib.sha256(actual.tobytes()).hexdigest(),eight_node_original_material_rerender_RGBA_mismatch=0,original_boots_and_both_sole_cards_RGBA_mismatch=0,body_inverse_on_actual_source_support_max_residual=res,body_material_sampled_Jacobian_min=minimum,LEFT_upper_actual_support_inverse_max_residual=err,RIGHT_projected_rigid_staff_forearm_grip_Gram_error=float(abs(rf.T@rf-np.eye(2)).max()),native_C=2496,unit=2.4375,root=root.tolist(),storage=pad.tolist(),source_and_actual_eight_surfaces=surface,actual_remaining_raster_bound=actualbound(actual,storedsole),strong_bodies=1))
 print(json.dumps(dict(phase=i,exact_RGBA_rerender=True,all_source_and_raster_floor_bounds_positive=True)),flush=True)
assert len(rows)==6 and len({z['actual_RGBA_sha256']for z in rows})==6
out=B/'SWattack-final5ef9-independent48-source-raster-fixed-rig-finite-capture-v01.json';assert not out.exists();out.write_text(json.dumps(dict(status='PASS_EXACT_SW_ATTACK48_SOURCE_SURFACES_FIXED_BOOTS_PROJECTED_RIG_AND_FINITE_PAINT_CAPTURE',source_contract=pin(cp),peer_actual_source_review=c['independent_actual_SOURCE_one_shot_review'],original_exact_source=c['source'],once_registration=c['exact_once_registration'],material_contract=c['exact_native_parts_contract'],math_defining_renderer=pin(renderer),same_once_neutral_model=pin(floorp),prior_independent_once_model=pin(old),fixed_sole_source_guarded_min_Z=1.,common_rest_capture_plane=rest,rows=rows,limits=['The actual visual/source/one-shot judgement is inherited from the exact peer SOURCE286b receipt; no images were viewed here.','The author uses eight composition groups and eleven native semantic owners per phase:48 source/raster groups, not36. Mathematical function definitions were extracted without executing any author top-level render/write code; their exact six output RGBA is independently recomposed and matched.','All original source owners are disjoint, original RGBA and reconstruct the complete source. The original stationary full boots/sole cards are bitexact at fixed common root; no alpha/footfit or perposebodyunit exists.','Projected RIGHT forearm/puff/grip/staff share one orthogonal2D rotation and fixed projected length. This is not proof of unique hidden3D anatomy, physical fixed bones or proper3D weapon rotation.','The original once-neutral sole planes and unchanged rest capture D180 are a finite stationary painted-material compatibility witness. All source texel quads and actual raster quads are guarded positive; nonlinear field source bounds use explicit conservative allquad intervals and convex-combination maxima.','Sampled positive source-grid Jacobians and actual-support inverse residuals do not assert a unique continuous physical3D recovery or global injectivity theorem. Source nodes, unit, C, root, .42s contact3 and shallow stationary SW scope remain fixed.','No source PNG, repository, helper, Git, game/runtime or actor approval changes are made.'],new_image_views=0,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(proof=pin(out),nodes=48,poses=6)))
