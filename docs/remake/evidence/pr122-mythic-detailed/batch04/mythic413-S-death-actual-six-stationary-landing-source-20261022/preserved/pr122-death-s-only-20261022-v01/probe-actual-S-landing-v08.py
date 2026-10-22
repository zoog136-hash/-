from pathlib import Path
import ast,json,numpy as np
from PIL import Image
L=Path('/workspace/scratch/pr122-death-s-only-20261022-v01');B=Path('/workspace/scratch/mythic413-S-death-author-20261020-v01');p=B/'author-own-S-DEATH-six-native-stationary-landing-v08-20261022.py';prefix=p.read_text().split('rows=[]\n',1)[0];prefix=prefix.replace("D=B/'actual-own-S-DEATH-six-native-v08-stationary-landing-20261022';D.mkdir()",'D=OUTPUT')
class NoWrites(ast.NodeTransformer):
 def visit_Expr(self,n):
  if isinstance(n.value,ast.Call) and isinstance(n.value.func,ast.Attribute) and n.value.func.attr in ('save','write_text','write_bytes','mkdir'):return ast.copy_location(ast.Pass(),n)
  return self.generic_visit(n)
ns=dict(__file__=str(p),OUTPUT=L/'probe-only-no-images');t=NoWrites().visit(ast.parse(prefix));ast.fix_missing_locations(t);exec(compile(t,str(p),'exec'),ns)
rows=[]
for ph,st in enumerate(ns['states']):
 ns['st']=st;H=np.array(st['hip'],float);Rp=ns['bodyrot']([st['pelvis']]).as_matrix()[0]
 for i,side in enumerate(['R','L']):
  q=ns['legs'][side];ctrl=ns['controls'][side];m=q['capture'];fu=np.array(m['source_U']);fv=np.array(m['source_V']);heel_src=np.array(m['observed_painted_heel_native']);fr=ns['Slerp']([0,1],ns['Rotation'].from_matrix([np.eye(3),ns['flat_foot'](fu,fv,np.array(ctrl['ankle'])-heel_src)]))([st['foot']]).as_matrix()[0];M=fr@np.column_stack([fu,fv]);heel=np.array(st['heel'][i],float);heel[:2]=H[:2]+ns['axis']([0,0,1],-40*st['body'])[:2,:2]@(heel[:2]-H[:2]);A=heel+M@(np.array(ctrl['ankle'])-heel_src);hip=H+Rp@(ns['U']*(ctrl['hip'][0]-636)+ns['V']*(ctrl['hip'][1]-645));K=ns['knee'](hip,A,side)
  y,x=np.where(np.array(q['foot'])[:,:,3]>0);world=heel+(np.stack([x+.5,y+.5],axis=-1)-heel_src)@M.T;native=ns['ROOT']+world@ns['Pr'].T;canonical=native-ns['ROOT']+np.array([1024,1280]);rows.append(dict(phase=ph,side=side,femur=float(np.linalg.norm(K-hip)),tibia=float(np.linalg.norm(A-K)),canonical_bbox=[float(canonical[:,0].min()-2),float(canonical[:,1].min()-2),float(canonical[:,0].max()+2),float(canonical[:,1].max()+2)],foot_floor_min=float(world[:,2].min())))
old=json.loads((B/'actual-own-S-DEATH-six-native-v07-S-only-20261022/own-S-DEATH-six-actual-native-source-contract-v07.json').read_text());other=[]
for r in old['records']:
 if r['name'][0:2] in ('R-','L-'):continue
 ph=r['phase'];box=np.array(Image.open(r['raster']['path']).getchannel('A').getbbox(),float);box-=np.tile(np.array(old['common_unpadded_root'])+384,2);box+=np.array([1024,1280,1024,1280]);dy=ns['states'][ph]['hip'][1]-old['frames'][ph]['state']['hip'][1];box+=np.array([0,dy,0,dy]);other.append(dict(phase=ph,name=r['name'],predicted_canonical_bbox=box.tolist()))
assert all(abs(r['femur']-289.75)<1e-6 and abs(r['tibia']-289.75)<1e-6 for r in rows)
passed=all(min(r['canonical_bbox'][:2])>=0 and max(r['canonical_bbox'][2:])<=2048 and r['foot_floor_min']>=0 for r in rows) and all(min(r['predicted_canonical_bbox'][:2])>=0 and max(r['predicted_canonical_bbox'][2:])<=2048 for r in other)
pf=dict(status='ANALYTIC_FEET_AND_RIGID_NONLEG_BOUND_PASS_NEEDS_FULL_RENDER' if passed else 'ANALYTIC_HOLD',feet=rows,nonlegs=other,fixed_C=2560,canonical=2048,actual_RGBA_generated=False,approvals_added=0)
(L/'S-death-stationary-landing-v08-analytic-preflight.json').write_text(json.dumps(pf,indent=2)+'\n');print(json.dumps(dict(status=pf['status'],feet_max_bottom=max(r['canonical_bbox'][3] for r in rows),nonleg_max_bottom=max(r['predicted_canonical_bbox'][3] for r in other),fixed_bones=True,images_generated=0)))
assert passed
