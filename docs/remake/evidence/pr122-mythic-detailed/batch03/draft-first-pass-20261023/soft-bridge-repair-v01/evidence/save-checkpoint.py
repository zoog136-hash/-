import json,pathlib,subprocess
r=pathlib.Path('/workspace/twilight');s=pathlib.Path('/workspace/scratch/pr122-soft-bridge-repair-20261023');stage=json.loads((s/'staging-summary.json').read_text());root='docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/soft-bridge-repair-v01'
paths=['data/pr122_native_locomotion_staging.json','docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json','docs/remake/TWILIGHT_PR122_RESUME_20261019.md',root]+[f"assets/actors/eight_direction/native_locomotion_staging/transform_{key.split(':')[1]}/native007" for key in stage['keys']]
def run(args):return subprocess.run(args,cwd=r,check=True,text=True,capture_output=True).stdout
run(['git','add','-f','--',*paths]);changed=run(['git','diff','--cached','--name-only']).splitlines();assert all(any(p==prefix or p.startswith(prefix+'/') for prefix in paths) for p in changed),'Unexpected staged file'
run(['git','diff','--cached','--check']);run(['git','write-tree','--missing-ok']);run(['git','commit','-m','[skip ci] Separate 27 source contours while preserving ambiguous alpha layers and playback proof'])
print(json.dumps(dict(files=len(changed),commit=run(['git','rev-parse','HEAD']).strip(),status_entries=len(run(['git','status','--porcelain']).splitlines()))))
