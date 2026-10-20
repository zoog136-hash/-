from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,math,hashlib
B=Path(__file__).parent;D=B/'actual-E-ATTACK6-native-articulated-rig-v04';P=D/'E-ATTACK6-actual-native-articulated-six-rig-and-local-cape-contract-v04.json';j=json.loads(P.read_text());root=j['common_rig_root_in_unpadded_frame'];storage=np.array(j['storage_translation']);PIV=np.array([root[0],710.]);rows=[]
def bone(a,b,c,d):
 a,b,c,d=map(lambda v:np.array(v,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);M=np.column_stack((v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]))@np.column_stack((u,[-u[1],u[0]])).T;return M,c-M@a
for f in j['frames']:
 if f['phase'] not in [3,4]:continue
 p=f['actual_rig_nodes_unpadded_native'];t=math.radians(p['ang']);M=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);off=PIV+np.array(p['delta'])-M@PIV
 def point(v):return M@np.array(v)+off
 matrices=[bone([795,471],[808,513],point([795,471]),p['le']),bone([808,513],[953,596],p['le'],p['lw']),None,bone([622,354],[550,471],point([622,354]),p['re']),(np.array(f['RIGHT_rigid_staff_matrix']),np.array(f['RIGHT_exact_same_forearm_affine_grip_target'])-np.array(f['RIGHT_rigid_staff_matrix'])@np.array([386,506])),bone([550,471],[428,505],p['re'],p['rw'])]
 a=np.array(Image.open(f['path']));cc,n=label(a[:,:,3]>100);sz=np.bincount(cc.ravel());nodes=[np.array(Image.open(q['path']))for q in f['actual_composition_nodes']]
 for k in range(1,n+1):
  if not 3<=sz[k]<200:continue
  y,x=np.where(cc==k);box=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)];r={'phase':f['phase'],'strong_area':int(sz[k]),'stored_bbox':box,'contributions':[]}
  for ni,ar in enumerate(nodes):
   m=(cc==k)&(ar[:,:,3]>0);count=int(m.sum())
   if not count:continue
   sy,sx=np.where(m);v={'node':Path(f['actual_composition_nodes'][ni]['path']).name,'actual_contributing_pixels':count,'nativeRGBA_sample':ar[sy[0],sx[0]].tolist()}
   if matrices[ni] is not None:
    N,b=matrices[ni];src=(np.column_stack((sx,sy))-storage-b)@np.linalg.inv(N).T;v['original_source_bounds_float']=[src.min(0).tolist(),src.max(0).tolist()];v['original_source_bbox_conservative']=[int(np.floor(src[:,0].min()-2)),int(np.floor(src[:,1].min()-2)),int(np.ceil(src[:,0].max()+3)),int(np.ceil(src[:,1].max()+3))];v['original_to_new_matrix']=N.tolist();v['original_to_new_offset']=b.tolist()
   r['contributions'].append(v)
  rows.append(r)
q={'schema':'E-ATTACK-tiny-hand-component-exact-node-source-ownership-trace-v1','source_contract':{'path':str(P),'sha256':hashlib.sha256(P.read_bytes()).hexdigest()},'SOURCE_status':'PENDING_SEMANTIC_MATERIAL_TRANSFER_ONLY_NO_BULK_DELETION','component_traces':rows};p=B/'E-ATTACK-v04-final-small-foregrip-original-source-trace-v01.json';p.write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'traces':[{'phase':x['phase'],'area':x['strong_area'],'bbox':x['stored_bbox'],'owners':[{'node':r['node'],'source_bbox':r.get('original_source_bbox_conservative')}for r in x['contributions']]}for x in rows]}))
