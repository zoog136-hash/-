from pathlib import Path
import hashlib,json,math
import numpy as np
from PIL import Image
from scipy.ndimage import label

B=Path(__file__).parent
A=Path('/workspace/scratch/mythic413-SE-attack-author-20261020-v01')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def checked(s):
 p=Path(s['path']);assert pin(p)['sha256']==s['sha256'];return p
def load(s):return json.loads(checked(s).read_text())
def rgba(s):return np.array(Image.open(checked(s)).convert('RGBA'))
def mask(s):return np.array(Image.open(checked(s)))>0
cp=A/'actual-SE-ATTACK6-native-articulated-rig-v04/SE-ATTACK6-actual-native-final-specific-owner-and-PASS-cape-candidate-contract-v06.json'
assert pin(cp)['sha256']=='f5867eaecd6cfadd0b8319c2b0693509620b3bb8d1f0a992655d097ee479b624'
c=json.loads(cp.read_text());m=load(c['shared_materials']);reg=load(c['shared_once_registration_exact_JSON']);src=rgba(c['source'])
priorp=A/'actual-SE-ATTACK6-native-articulated-rig-v03/SE-ATTACK6-actual-native-six-continuous-cape-and-correct-real-cape-coverage-contract-v05.json'
assert pin(priorp)['sha256']=='df4209ad2c181ac0ddc203adf744f8955e35506c7846a28254b9dbdb95b52a89'
prior=json.loads(priorp.read_text());old=load(prior['shared_materials'])
assert c['C']==2816 and c['bodyunit']==2.75 and c['common_rig_root_in_unpadded_frame']==reg['common_rig_root_in_unpadded_frame']
assert c['storage_translation']==[128,128] and c['native_canvas']==[1792,1792] and not c['whole_actor_mirrored'] and not c['source_or_fixed_boot_resampling_or_perpose_fit']
assert c['one_shot'] and c['role_seconds_preserved']==.42 and c['fps']==6/.42 and c['intended_contact_frame']==3 and c['actor_approvals_added']==0
fix=m['final_specific_original_material_owner_fixes'];items=fix['items'];yy,xx=np.indices(src.shape[:2]);hair=mask(items['original-behind-arm-hair-ribbon-moved-to-CORE']['mask']);finger=mask(items['top-finger-skin-restored-to-foregrip']['mask']);rim=mask(items['original-cuff-rim-moved-to-foregrip']['mask'])
for name,mm in [('original-behind-arm-hair-ribbon-moved-to-CORE',hair),('top-finger-skin-restored-to-foregrip',finger),('original-cuff-rim-moved-to-foregrip',rim)]:assert int(mm.sum())==items[name]['native_nonzero_RGBA_pixels']
parts={k:rgba(v) for k,v in m['parts'].items()};oldparts={k:rgba(v) for k,v in old['parts'].items()};core=rgba(m['fullCORE']);oldcore=rgba(old['fullCORE'])
RF='RIGHT-near-complete-forearm-grip-hand';RU='RIGHT-near-upper-arm';POLE='complete-rigid-RIGHT-near-staff'
assert np.array_equal(parts[RF][finger|rim],src[finger|rim]);assert np.array_equal(core[hair],src[hair]);assert not np.any(parts[RU][hair]) and not np.any(parts[RF][hair])
assert np.array_equal(core[740:],oldcore[740:])
fist=(xx>=348)&(xx<417)&(yy>=433)&(yy<497);axis=np.polyval(m['staff_axis_once_from_original_visible_metal'],yy);hidden=(yy>=425)&(yy<522)&(abs(xx-axis)<18)
allowed={RU:hair,RF:fist|rim|hair,POLE:hidden|hair}
nativechanges={}
for k,a in parts.items():
 d=np.any(a!=oldparts[k],2);assert not np.any(d&~allowed.get(k,np.zeros(d.shape,bool)));nativechanges[k]=int(d.sum())
cd=np.any(core!=oldcore,2);assert not np.any(cd&~(fist|rim|hair));nativechanges['CORE']=int(cd.sum())
# Recompute the finite hidden shaft profile from actual original shaft samples.
profile=[]
for u in range(-17,18):
 samples=np.array([src[y,int(round(np.polyval(m['staff_axis_once_from_original_visible_metal'],y)))+u] for y in range(560,741)])
 good=samples[samples[:,3]>16,:3]
 profile.append([*np.rint(np.median(good,axis=0)).astype(int).tolist(),int(round(float(np.median(samples[:,3]))))] if len(good) else [0,0,0,int(round(float(np.median(samples[:,3]))))])
assert profile==fix['native_shaft_original_measured_RGBA_profile']
fpm=Path('/workspace/scratch/mythic413-SE-hit-author-20261020-v01/SE-original-neutral-once-true-sole-and-HIT-six-material-floor-binding-v01.json');floor=json.loads(fpm.read_text());footmasks=[mask(z['exact_source_alpha_support']) for z in floor['source_material_capture_models']]
for z,mm in zip(floor['source_material_capture_models'],footmasks):assert np.array_equal(rgba(z['exact_original_native_material'])[mm],src[mm])
W=1792
def pad(a):
 im=Image.new('RGBA',(W,W));im.paste(Image.fromarray(a),(0,0));return im
def affine(im,M,t):
 inv=np.linalg.inv(M);q=-inv@t
 return np.array(im.transform((W,W),Image.Transform.AFFINE,tuple(inv[0])+(q[0],)+tuple(inv[1])+(q[1],),Image.Resampling.BICUBIC))
def bone(a,b,c,d):
 a,b,c,d=map(lambda x:np.asarray(x,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c)
 M=np.column_stack([v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]])@np.column_stack([u,[-u[1],u[0]]]).T
 return M,c-M@a
def stored(a):
 v=np.zeros_like(a);v[128:,128:]=a[:-128,:-128];return v
ctrl=m['actual_native_controls'];G=np.array(ctrl['RIGHT_original_grip'],float);SR=np.array(ctrl['RIGHT_near_shoulder'],float);ER=np.array(ctrl['RIGHT_near_cuff_elbow'],float);WR=np.array(ctrl['RIGHT_near_wrist'],float);SL=np.array(ctrl['LEFT_far_visible_proximal_anchor'],float);EL=np.array(ctrl['LEFT_far_cuff_elbow'],float);WL=np.array(ctrl['LEFT_far_wrist'],float)
polealpha=parts[POLE][:,:,3];py,px=np.where(polealpha>100);top=np.array([np.where(polealpha[py.min()]>100)[0].mean(),py.min()]);bottom=np.array([np.where(polealpha[py.max()]>100)[0].mean(),py.max()])
rows=[];rgbs=[]
for i,(f,pf) in enumerate(zip(c['frames'],prior['frames'])):
 assert f['phase']==i and f['actual_rig_nodes_unpadded_native']==pf['actual_rig_nodes_unpadded_native'];assert f['common_rig_root_in_unpadded_frame']==c['common_rig_root_in_unpadded_frame'] and f['storage_translation']==[128,128] and f['physical_C']==2816
 a=rgba(dict(path=f['path'],sha256=f['sha256']));nodes=[rgba(z) for z in f['actual_composition_nodes']];out=Image.new('RGBA',(W,W))
 for v in nodes:out.alpha_composite(Image.fromarray(v))
 assert np.array_equal(a,np.array(out));rgbs.append(hashlib.sha256(a.tobytes()).hexdigest());native=a[128:1382,128:1382]
 for mm in footmasks:assert np.array_equal(native[mm],src[mm])
 p=f['actual_rig_nodes_unpadded_native'];ang=math.radians(p['ang']);TM=np.array([[math.cos(ang),-math.sin(ang)],[math.sin(ang),math.cos(ang)]]);piv=np.array([c['common_rig_root_in_unpadded_frame'][0],710.]);toff=piv+np.array(p['delta'])-TM@piv
 FM,FO=bone(ER,WR,p['re'],p['rw']);grip=FM@G+FO;st=math.radians(p['staff']);SM=np.array([[math.cos(st),-math.sin(st)],[math.sin(st),math.cos(st)]]);SO=grip-SM@G
 assert np.allclose(grip,f['RIGHT_exact_same_forearm_affine_grip_target'],atol=1e-11,rtol=0);assert np.array_equal(SM,np.array(f['RIGHT_rigid_staff_matrix']))
 assert np.allclose(SM@top+SO,f['native_original_full_staff_top_tip_target'],atol=1e-10,rtol=0);assert np.allclose(SM@bottom+SO,f['native_original_full_staff_bottom_tip_target'],atol=1e-10,rtol=0)
 maps={0:(*bone(SL,EL,TM@SL+toff,p['le']),'LEFT-far-upper-arm'),1:(*bone(EL,WL,p['le'],p['lw']),'LEFT-far-complete-curved-cuff-forearm-free-hand'),3:(*bone(SR,ER,TM@SR+toff,p['re']),RU),4:(SM,SO,POLE),5:(FM,FO,RF)}
 residuals={}
 for k,(M,O,n) in maps.items():
  expected=stored(affine(pad(parts[n]),M,O));assert np.array_equal(expected,nodes[k]);residuals[str(k)]=0
 for k in [0,1]:assert f['actual_composition_nodes'][k]['sha256']==pf['actual_composition_nodes'][k]['sha256']
 labs,n=label(a[:,:,3]>100);sizes=np.bincount(labs.ravel());assert np.count_nonzero(sizes[1:]>=200)==1;small=[]
 for k in range(1,n+1):
  if 3<=sizes[k]<200:
   ys,xs=np.where(labs==k);contributions=[]
   for nk,(M,O,name) in maps.items():
    nz=nodes[nk][ys,xs,3]>0
    if np.any(nz):
     uv=(np.stack([xs[nz]-128,ys[nz]-128],1)-O)@np.linalg.inv(M).T
     contributions.append(dict(node=nk,native_material=name,continuous_inverse_source_UV=uv.tolist(),node_alpha=nodes[nk][ys[nz],xs[nz],3].tolist()))
   assert len(contributions)==1
   small.append(dict(area=int(sizes[k]),stored_bbox=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],actual_native_contributions=contributions))
 assert not np.any(a[[0,-1],:,3]>16) and not np.any(a[:,[0,-1],3]>16)
 rows.append(dict(phase=i,name=f['name'],actual_source=pin(f['path']),RGBA_sha256=rgbs[-1],six_node_RGBA_recomposition_mismatch=0,five_articulated_node_independent_affine_reraster_mismatch=residuals,fixed_original_lowerboot_sole_RGBA_mismatch=[0,0],fixed_painted_lowerboot_sole_texels=[int(q.sum()) for q in footmasks],same_forearm_matrix_grip=grip.tolist(),staff_orthogonality_residual=float(abs(SM.T@SM-np.eye(2)).max()),staff_determinant=float(np.linalg.det(SM)),complete_native_staff_tips=[(SM@top+SO).tolist(),(SM@bottom+SO).tolist()],strong_bodies=1,small_alpha100_components_ge3=small,canvas_edges_alpha16=0))
assert len(rows)==6 and len(set(rgbs))==6
target=B/'SEattack-v04-independent-exact36-current-owner-native-node-sole-and-grip-binding-v01.json';assert not target.exists()
result=dict(status='PASS_EXACT_CURRENT_SE_SOURCE_OWNER_36NODE_FIXED_BOOT_AND_GRIP_BINDING',source_contract=pin(cp),prior_source=pin(priorp),source_original=c['source'],materials=c['shared_materials'],once_body=c['shared_once_registration_exact_JSON'],source_material_owner_native_changes=nativechanges,original_finger_and_cuff_native_RGBA_mismatch=0,original_hair_ribbon_native_RGBA_mismatch=0,PASS_cape_CORE_y740plus_RGBA_mismatch=0,actual_hidden_shaft_profile_recomputed_from_original_source=True,hidden_shaft_profile=profile,original_stationary_support_model=pin(fpm),six=rows,C=c['C'],bodyunit=c['bodyunit'],root=c['common_rig_root_in_unpadded_frame'],storage_translation=c['storage_translation'],seconds=.42,contact_frame=3,limits=['This binds exact original source ownership, actual composited pixels, fixed native sole/lowerboot patches and 2D affine/rigid staff-grip continuity; it does not recover a unique hidden3D attack skeleton, movement floor or full actor approval.','The bounded local actual cape repaint remains the separately reviewed native material derivative; outside its approved mask source protection and native y740plus final owner protection remain exact.','The residual 3-pixel edge is recorded with its exact native inverse source contribution; connectivity thresholds are unchanged.'],images_viewed=0,repository_changes=0,game_tests_run=0,actor_approvals_added=0)
target.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(proof=pin(target),small=[z['small_alpha100_components_ge3'] for z in rows],nativechanges=nativechanges)))
