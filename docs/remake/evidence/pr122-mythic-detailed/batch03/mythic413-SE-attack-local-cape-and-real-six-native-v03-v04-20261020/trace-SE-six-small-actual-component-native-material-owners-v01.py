from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,math,hashlib
B=Path(__file__).parent;P=B/'actual-SE-ATTACK6-native-articulated-rig-v03/SE-ATTACK6-actual-native-six-continuous-cape-and-correct-real-cape-coverage-contract-v05.json';j=json.loads(P.read_text());root=j['common_rig_root_in_unpadded_frame'];storage=np.array(j['storage_translation']);PIV=np.array([root[0],710.]);rows=[]
def bone(a,b,c,d):
 a,b,c,d=map(lambda v:np.array(v,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);M=np.column_stack((v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]))@np.column_stack((u,[-u[1],u[0]])).T;return M,c-M@a
for f in j['frames']:
 p=f['actual_rig_nodes_unpadded_native'];t=math.radians(p['ang']);M=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);off=PIV+np.array(p['delta'])-M@PIV
 def point(v):return M@np.array(v)+off
 G=np.array([382.,466.]);mat=[bone([801,491],[823,516],point([801,491]),p['le']),bone([823,516],[935,584],p['le'],p['lw']),None,bone([620,343],[552,459],point([620,343]),p['re']),(np.array(f['RIGHT_rigid_staff_matrix']),np.array(f['RIGHT_exact_same_forearm_affine_grip_target'])-np.array(f['RIGHT_rigid_staff_matrix'])@G),bone([552,459],[417,482],p['re'],p['rw'])];a=np.array(Image.open(f['path']));cc,n=label(a[:,:,3]>100);sz=np.bincount(cc.ravel());nodes=[np.array(Image.open(q['path']))for q in f['actual_composition_nodes']]
 for k in range(1,n+1):
  if not 3<=sz[k]<200:continue
  y,x=np.where(cc==k);r={'phase':f['phase'],'area':int(sz[k]),'stored_bbox':[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)],'owners':[]}
  for ni,ar in enumerate(nodes):
   v=(cc==k)&(ar[:,:,3]>0)
   if not v.any():continue
   sy,sx=np.where(v);target=np.column_stack((sx,sy))-storage
   if ni==2:
    ox=target[:,0].astype(float);oy=target[:,1].astype(float);sx0=ox.copy();sy0=oy.copy()
    for _ in range(12):
     w=np.clip((735-sy0)/190,0,1);px=M[0,0]*sx0+M[0,1]*sy0+off[0];py=M[1,0]*sx0+M[1,1]*sy0+off[1];dx=(px-sx0)*w;dy=(py-sy0)*w;cweight=np.clip((sy0-650)/310,0,1)*np.interp(sx0,[0,580,650,975,1254,1792],[1,0,0,0,1,1])*((sy0<1010)&(sy0>600));dx+=p['cloth']*cweight;sy0=oy-dy;sx0=ox-dx
    src=np.column_stack((sx0,sy0))
   else:
    N,b=mat[ni];src=(target-b)@np.linalg.inv(N).T
   r['owners'].append({'node':Path(f['actual_composition_nodes'][ni]['path']).name,'original_source_bbox_conservative':[int(np.floor(src[:,0].min()-2)),int(np.floor(src[:,1].min()-2)),int(np.ceil(src[:,0].max()+3)),int(np.ceil(src[:,1].max()+3))],'mean_actual_RGB':np.rint(ar[sy,sx,:3].mean(0)).astype(int).tolist(),'actual_pixels':len(sx)})
  rows.append(r)
p=B/'SE-actual-six-small-component-exact-native-part-and-body-inverse-source-trace-v01.json';p.write_text(json.dumps({'source_contract':{'path':str(P),'sha256':hashlib.sha256(P.read_bytes()).hexdigest()},'traces':rows},indent=2)+'\n');print(json.dumps({'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'traces':[{'p':r['phase'],'a':r['area'],'o':[[v['node'].split('-actual-')[-1],v['original_source_bbox_conservative'],v['mean_actual_RGB']]for v in r['owners']]}for r in rows]}))
