import sys,re,subprocess,json
from pathlib import Path
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import pr122_native_production_approvals as a
restored=[]
for _ in range(150):
 try:a.load_state(r);break
 except a.ApprovalError as e:
  m=re.fullmatch('Missing or escaped proof/artifact: (.+)',str(e))
  if not m:raise
  p=m[1];assert not (r/p).exists() and '..' not in Path(p).parts and not Path(p).is_absolute()
  subprocess.run(['git','restore','--source=HEAD','--worktree','--ignore-skip-worktree-bits','--',p],cwd=r,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);restored.append(p)
else:raise RuntimeError('Dependency recovery limit')
Path('/workspace/scratch/pr122-contour-repair-20261023/restored-proof-dependencies.json').write_text(json.dumps(restored,indent=2)+'\n');print('approval_proof_dependencies_restored',len(restored))
