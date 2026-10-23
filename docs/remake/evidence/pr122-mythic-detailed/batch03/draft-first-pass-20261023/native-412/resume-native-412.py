import sys,json,re,subprocess
from pathlib import Path
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import stage_pr122_native_locomotion as s
import pr122_native_production_approvals as approvals
m=json.loads((r/s.SOURCE_MANIFEST).read_text());reg=json.loads((r/s.REGISTER).read_text())
restored=[]
for i in range(120):
 try:approvals.load_state(r,manifest=m,register=reg);break
 except approvals.ApprovalError as e:
  match=re.fullmatch('Missing or escaped proof/artifact: (.+)',str(e))
  if not match:raise
  p=match[1];assert not (r/p).exists() and not Path(p).is_absolute() and '..' not in Path(p).parts
  subprocess.run(['git','restore','--source=HEAD','--worktree','--ignore-skip-worktree-bits','--',p],cwd=r,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);restored.append(p)
else:raise RuntimeError('Dependency restore bound reached')
fresh={}
for rec in m['raw_images']:
 if rec['key']=='transform:412' and '/native-412/' in rec['source']:
  g=json.loads((r/rec['source']).with_suffix('.geometry.json').read_text());fresh[rec['source']]=s.preserved_source_analysis(r,rec,g)
s.stage(r,'transform:412','native001',analyzed_sources=fresh)
print('restored_dependencies',len(restored))
