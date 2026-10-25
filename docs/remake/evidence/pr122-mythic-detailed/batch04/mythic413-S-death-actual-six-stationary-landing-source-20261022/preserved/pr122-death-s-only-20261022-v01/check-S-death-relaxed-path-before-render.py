from pathlib import Path
import ast,json,numpy as np
L=Path('/workspace/scratch/pr122-death-s-only-20261022-v01');p=Path('/workspace/scratch/mythic413-S-death-author-20261020-v01/author-own-S-DEATH-six-native-relaxed-knee-path-v06-20261022.py');prefix=p.read_text().split('rows=[]\n',1)[0];prefix=prefix.replace("D=B/'actual-own-S-DEATH-six-native-v06-S-only-20261022';D.mkdir()",'D=OUTPUT')
class NoWrites(ast.NodeTransformer):
 def visit_Expr(self,n):
  if isinstance(n.value,ast.Call) and isinstance(n.value.func,ast.Attribute) and n.value.func.attr in ('save','write_text','write_bytes','mkdir'):return ast.copy_location(ast.Pass(),n)
  return self.generic_visit(n)
ns=dict(__file__=str(p),OUTPUT=L/'probe-only-no-images');tree=NoWrites().visit(ast.parse(prefix));ast.fix_missing_locations(tree);exec(compile(tree,str(p),'exec'),ns)
rows=[]
for ph,st in enumerate(ns['states']):
 ns['st']=st;H=np.array(st['hip'],float);Rp=ns['bodyrot']([st['pelvis']]).as_matrix()[0]
 for i,side in enumerate(['R','L']):
  q=ns['legs'][side];ctrl=ns['controls'][side];m=q['capture'];fu=np.array(m['source_U']);fv=np.array(m['source_V']);heel_src=np.array(m['observed_painted_heel_native']);fr=ns['Slerp']([0,1],ns['Rotation'].from_matrix([np.eye(3),ns['flat_foot'](fu,fv,np.array(ctrl['ankle'])-heel_src)]))([st['foot']]).as_matrix()[0];M=fr@np.column_stack([fu,fv]);heel=np.array(st['heel'][i],float);heel[:2]=H[:2]+ns['axis']([0,0,1],-40*st['body'])[:2,:2]@(heel[:2]-H[:2]);A=heel+M@(np.array(ctrl['ankle'])-heel_src);hip=H+Rp@(ns['U']*(ctrl['hip'][0]-636)+ns['V']*(ctrl['hip'][1]-645));K=ns['knee'](hip,A,side)
  y,x=np.where(np.array(q['foot'])[:,:,3]>0);world=heel+(np.stack([x+.5,y+.5],axis=-1)-heel_src)@M.T;native=ns['ROOT']+world@ns['Pr'].T;physical=native-ns['ROOT']+np.array([1280,1600]);rows.append(dict(phase=ph,side=side,femur=float(np.linalg.norm(K-hip)),tibia=float(np.linalg.norm(A-K)),foot_physical_bbox=[float(physical[:,0].min()-2),float(physical[:,1].min()-2),float(physical[:,0].max()+2),float(physical[:,1].max()+2)],foot_floor_min=float(world[:,2].min())))
assert all(abs(r['femur']-289.75)<1e-6 and abs(r['tibia']-289.75)<1e-6 for r in rows)
passed=all(min(r['foot_physical_bbox'][:2])>=0 and max(r['foot_physical_bbox'][2:])<=2560 for r in rows)
(L/'S-new-real-leg-path-fixed-bones-and-foot-bounds-probe.json').write_text(json.dumps(dict(status='FOOT_ONLY_PASS_NEEDS_FULL_SOURCE_RENDER' if passed else 'FOOT_BOUNDS_HOLD',rows=rows,new_art_rendered=False),indent=2)+'\n')
print(json.dumps(dict(foot_bounds_pass=passed,max_physical_bottom=max(r['foot_physical_bbox'][3] for r in rows),fixed_bones=True,images_generated=0)))
assert passed
