import ast,copy,hashlib,json
from pathlib import Path
B=Path('/workspace/scratch/mythic413-S-death-author-20261020-v01');L=Path('/workspace/scratch/pr122-death-s-only-20261022-v01')
src=B/'author-own-S-DEATH-six-native-relaxed-knee-path-v07-20261022.py';s=src.read_text();tree=ast.parse(s);n=next(x for x in tree.body if isinstance(x,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='states' for t in x.targets));new=copy.deepcopy(n)
for ph,hip,heels in [(3,[0,260,200],[[-145,660,75],[135,740,80]]),(4,[0,270,65],[[-155,650,45],[145,750,45]]),(5,[0,270,60],[[-165,630,25],[155,750,25]])]:
 d=new.value.elts[ph]
 for i,k in enumerate(d.keys):
  if k.value=='hip':d.values[i]=ast.parse(repr(hip),mode='eval').body
  if k.value=='heel':d.values[i]=ast.parse(repr(heels),mode='eval').body
ls=s.splitlines(keepends=True);ls[n.lineno-1:n.end_lineno]=[ast.unparse(new)+'\n'];s=''.join(ls)
s=s.replace('actual-own-S-DEATH-six-native-v07-S-only-20261022','actual-own-S-DEATH-six-native-v08-stationary-landing-20261022').replace('own-S-DEATH-six-actual-native-source-contract-v05.json','own-S-DEATH-six-actual-native-source-contract-v08.json')
rp=B/'author-own-S-DEATH-six-native-stationary-landing-v08-20261022.py'
with rp.open('x') as f:f.write(s)
driver=B/'author-own-S-DEATH-real-six-relaxed-knee-path-v07-20261022.py';ds=driver.read_text().replace('actual-own-S-DEATH-six-native-v07-S-only-20261022','actual-own-S-DEATH-six-native-v08-stationary-landing-20261022').replace(src.name,rp.name).replace('own-S-DEATH-six-actual-native-source-contract-v07.json','own-S-DEATH-six-actual-native-source-contract-v08.json')
dp=B/'author-own-S-DEATH-real-six-stationary-landing-v08-20261022.py'
with dp.open('x') as f:f.write(ds)
proof=dict(status='NEW_REAL_ARTICULATED_LANDING_CONTROLS_PENDING_PREFLIGHT',unchanged_first_three_states=ast.dump(n.value.elts[0])==ast.dump(new.value.elts[0]) and ast.dump(n.value.elts[1])==ast.dump(new.value.elts[1]) and ast.dump(n.value.elts[2])==ast.dump(new.value.elts[2]),changes='Phases 3-5 hip follows a stationary collapse landing near the start; fixed-length legs settle around the actual landing. No image or frame fitting.',fixed_C=2560,fixed_root=True,fixed_bones=289.75,no_source_RGBA_scaling=True,no_per_frame_storage_fit=True,source_visual_status='HOLD',approvals_added=0,paths=[str(rp),str(dp)])
(L/'S-death-stationary-landing-v08-control-change-proof.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'new_rig':rp.name,'new_driver':dp.name,'originals_changed':False,'approvals_added':0}))
