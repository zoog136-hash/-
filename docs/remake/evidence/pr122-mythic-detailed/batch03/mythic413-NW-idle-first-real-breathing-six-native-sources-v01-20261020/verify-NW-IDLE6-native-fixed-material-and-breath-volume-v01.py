from pathlib import Path
import json,hashlib,ast,numpy as np
from PIL import Image
P=Path(__file__).parent;O=P/'actual-NW-IDLE6-native-thorax-v01';F=O/'NW-IDLE-six-actual-native-source-common-root-and-loop-contract-v01.json';d=json.load(open(F))
def pad(p):
 o=Image.new('RGBA',(1536,1536));o.paste(Image.open(p).convert('RGBA'),(0,0));return np.array(o)
base=pad(d['base_native_source']['path'])
legs=pad('/workspace/scratch/mythic413-NW-hit-author-20261020-v01/actual-braced-stance-v03/NW-HIT-articulated-braced-legs-and-complete-shoes.png');yy,xx=np.indices(base.shape[:2]);lm=(legs[:,:,3]>16)&(yy>=730)
staff=pad('/workspace/scratch/mythic413-NW-attack-author-20261020-v01/actual-NW-ATTACK6-native-rig-v03/actual-original-NW-complete-rigid-RIGHT-staff-material.png');sm=staff[:,:,3]>100
tree=ast.parse((P/'author-NW-IDLE6-native-thorax-relax-and-cloth-v01.py').read_text());fns=[n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name in ('smooth','field')]
import math
ns=dict(np=np,math=math);exec(compile(ast.Module(body=fns,type_ignores=[]),'actual_native_body_nodes','exec'),ns);field=ns['field']
records=[];images=[]
for z in d['frames']:
 a=np.array(Image.open(z['path']).convert('RGBA'));images.append(a);diff=np.any(a!=base,axis=2)
 rib=[]
 for x,y in [(594,510),(690,510),(625,584),(628,422)]:
  dx,dy=field(np.array(float(x)),np.array(float(y)),z['pose_nodes']);rib.append(dict(source_control=[x,y],target=[x+float(dx),y+float(dy)]))
 records.append(dict(phase=z['phase'],source_sha256=z['sha256'],actual_leg_RGBA_changes=int((diff&lm).sum()),actual_complete_RIGHTstaff_RGBA_changes=int((diff&sm).sum()),actual_material_counts=dict(legs=int(lm.sum()),staff=int(sm.sum())),native_body_surface_controls=rib,thorax_rib_span_native=rib[1]['target'][0]-rib[0]['target'][0],actual_thorax_ROI_RGBA_changes=int(diff[430:605,560:725].sum())))
assert len({z['source_sha256']for z in records})==6
assert all(z['actual_leg_RGBA_changes']==z['actual_complete_RIGHTstaff_RGBA_changes']==0 for z in records)
assert max(z['thorax_rib_span_native']for z in records)-min(z['thorax_rib_span_native']for z in records)>4
edges=[dict(pair=[i,(i+1)%6],actual_RGBA_changes=int(np.any(images[i]!=images[(i+1)%6],axis=2).sum()))for i in range(6)]
f=O/'NW-IDLE-six-fixed-actual-legs-staff-and-real-thorax-volume-proof-v01.json';assert not f.exists()
f.write_text(json.dumps(dict(status='SCOPED_NUMERIC_MATERIAL_AND_NODE_CHECK_ONLY_PENDING_ACTUAL_QC',contract_sha256=hashlib.sha256(F.read_bytes()).hexdigest(),physical_canvas_fixed=2048,root_fixed=[641,1058.3],loop_seconds=1.2,records=records,adjacent_pairs_including_loop=edges,actor_approval_added=0),indent=2)+'\n')
print(json.dumps(dict(proof=str(f),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),six_unique_sources=True,fixed_actual_leg_staff_RGBA_changes=0,breath_rib_span_change_native=max(z['thorax_rib_span_native']for z in records)-min(z['thorax_rib_span_native']for z in records))))
