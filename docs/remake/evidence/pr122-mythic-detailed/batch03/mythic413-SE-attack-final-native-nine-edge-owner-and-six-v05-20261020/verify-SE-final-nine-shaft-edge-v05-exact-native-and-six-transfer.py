from pathlib import Path
from PIL import Image
from scipy.ndimage import binary_dilation,map_coordinates,label
import numpy as np,json,hashlib,math
B=Path(__file__).parent;D=B/'actual-SE-ATTACK6-native-articulated-rig-v05';P=D/'SE-ATTACK6-actual-native-final-specific-owner-and-PASS-cape-candidate-contract-v07.json';O=B/'actual-SE-ATTACK6-native-articulated-rig-v04/SE-ATTACK6-actual-native-final-specific-owner-and-PASS-cape-candidate-contract-v06.json';j=json.loads(P.read_text());old=json.loads(O.read_text());m=json.loads(Path(j['shared_materials']['path']).read_text());mo=json.loads(Path(m['prior_material']['path']).read_text());fix=json.loads(Path(m['final_nine_original_shaft_edge_AA_owner']['path']).read_text());mask=np.array(Image.open(fix['source_owner_mask']['path']).convert('L'))>0;nativeAllowed={4:mask,5:mask};nativeSourceDiff={}
for i,key in [(3,'RIGHT-near-upper-arm'),(4,'complete-rigid-RIGHT-near-staff'),(5,'RIGHT-near-complete-forearm-grip-hand')]:
 a=np.array(Image.open(m['parts'][key]['path']));o=np.array(Image.open(mo['parts'][key]['path']));diff=np.any(a!=o,2);assert not np.any(diff&~nativeAllowed.get(i,np.zeros(mask.shape,bool)));nativeSourceDiff[key]=int(diff.sum())
a=np.array(Image.open(m['fullCORE']['path']));o=np.array(Image.open(mo['fullCORE']['path']));assert np.array_equal(a,o);nativeSourceDiff['CORE']=0
root=j['common_rig_root_in_unpadded_frame'];storage=j['storage_translation'];W=H=1792;yy,xx=np.indices((H,W));PIV=np.array([root[0],710.]);rows=[]
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
def bone(a,b,c,d):
 a,b,c,d=map(lambda v:np.array(v,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);M=np.column_stack((v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]))@np.column_stack((u,[-u[1],u[0]])).T;return M,c-M@a
for f,of in zip(j['frames'],old['frames']):
 p=f['actual_rig_nodes_unpadded_native'];assert p==of['actual_rig_nodes_unpadded_native'];t=math.radians(p['ang']);M=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);off=PIV+np.array(p['delta'])-M@PIV
 def point(v):return M@np.array(v)+off
 FM,FO=bone([552,459],[417,482],p['re'],p['rw']);UM,UO=bone([620,343],[552,459],point([620,343]),p['re']);SM=np.array(f['RIGHT_rigid_staff_matrix']);SO=np.array(f['RIGHT_exact_same_forearm_affine_grip_target'])-SM@np.array([382,466]);mat={3:(UM,UO),4:(SM,SO),5:(FM,FO)};out=Image.new('RGBA',(W,H));union=np.zeros((H,W),bool);nd=[]
 for i,(n,on)in enumerate(zip(f['actual_composition_nodes'],of['actual_composition_nodes'])):
  ar=np.array(Image.open(n['path']));ao=np.array(Image.open(on['path']));dif=np.any(ar!=ao,2);allow=np.zeros((H,W),bool)
  if i in nativeAllowed:
   mask=binary_dilation(nativeAllowed[i],iterations=3)
   if i==2:
    sx=xx.astype(float);sy=yy.astype(float)
    for _ in range(12):
     w=np.clip((735-sy)/190,0,1);px=M[0,0]*sx+M[0,1]*sy+off[0];py=M[1,0]*sx+M[1,1]*sy+off[1];dx=(px-sx)*w;dy=(py-sy)*w;cweight=np.clip((sy-650)/310,0,1)*np.interp(sx,[0,580,650,975,1254,1792],[1,0,0,0,1,1])*((sy<1010)&(sy>600));dx+=p['cloth']*cweight;sy=yy-dy;sx=xx-dx
    local=map_coordinates(mask.astype(float),[sy,sx],order=1,mode='constant',cval=0)>0;stored=np.zeros((H,W),bool);stored[storage[1]:,storage[0]:]=local[:H-storage[1],:W-storage[0]];allow=stored
   else:
    N,b=mat[i];V=np.linalg.inv(N);v=-V@b;im=Image.fromarray(mask.astype('uint8')*255).transform((W,H),Image.Transform.AFFINE,tuple(V[0])+(v[0],)+tuple(V[1])+(v[1],),Image.Resampling.BICUBIC);s=Image.new('L',(W,H));s.paste(im,tuple(storage));allow=np.array(s)>0
  assert not np.any(dif&~allow);union|=allow;out.alpha_composite(Image.fromarray(ar));nd.append({'node':Path(n['path']).name,'RGBA_changed_pixels':int(dif.sum()),'outside_native_specific_owner_kernel_changes':0})
 a=np.array(Image.open(f['path']));ao=np.array(Image.open(of['path']));assert np.array_equal(a,np.array(out));assert not np.any(np.any(a!=ao,2)&~union);boot={}
 for k,(x0,y0,x1,y1)in {'LEFT_actual_original_boot':[485,1070,680,1240],'RIGHT_actual_original_boot':[800,1070,1030,1240]}.items():
  boot[k]=int(np.any(a[y0+storage[1]:y1+storage[1],x0+storage[0]:x1+storage[0]]!=ao[y0+storage[1]:y1+storage[1],x0+storage[0]:x1+storage[0]],2).sum())
 assert sum(boot.values())==0;cc,n=label(a[:,:,3]>100);sz=np.bincount(cc.ravel());sz[0]=0;assert int((sz>=200).sum())==1;small=[]
 for k in range(1,n+1):
  if 3<=sz[k]<200:
   y,x=np.where(cc==k);small.append({'area':int(sz[k]),'stored_bbox':[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]})
 rows.append({'phase':f['phase'],'actual_frame':pin(f['path']),'nodes':nd,'outside_all_specific_original_owner_kernel_RGBA_changes':0,'all_nodes_RGBA_recomposition_difference':0,'actual_original_boot_RGBA_changes':boot,'C_root_unit_storage_grip_all_phase_controls_changes':0,'strong_body_count':1,'small_alpha100_components_ge3':small})
q={'schema':'SE-final-specific-original-owner-six-exact-native-transfer-v1','prior_contract':pin(O),'actual_contract':pin(P),'native_specific_material_proof':pin(Path(m['final_nine_original_shaft_edge_AA_owner']['path'])),'native_material_changes_only_inside_named_owner_regions':nativeSourceDiff,'native_PASS_cape_y740plus_CORE_RGBA_changes':0,'original_actual_source_modified':False,'checks':rows,'SOURCE_actor_or_game_approval_added':0};p=D/'SE-ATTACK6-final-nine-shaft-edge-owner-v05-exact-36node-sole-cape-transfer-proof-v01.json';p.write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({'proof':pin(p),'contract':pin(P),'native_source_changes':nativeSourceDiff,'all_nonspecific_changes':0,'remaining_small_alpha100_ge3':[r['small_alpha100_components_ge3']for r in rows]}))
