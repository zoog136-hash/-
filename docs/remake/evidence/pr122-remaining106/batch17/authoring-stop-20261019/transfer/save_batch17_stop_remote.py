from pathlib import Path
import json
import subprocess
import datetime

repo=Path('/workspace/twilight')
folder=repo/'docs/remake/evidence/pr122-remaining106/batch17/authoring-stop-20261019'
runtime=Path('/workspace/runtime')
log=runtime/'batch17-stop-transfer.log'
receipt=runtime/'batch17-stop-transfer.json'
manifest=json.loads((folder/'preservation-manifest.json').read_text())
parts=[str((folder/x['path']).relative_to(repo)) for x in manifest['parts']]
changes=[x.decode()[3:] for x in subprocess.check_output(['git','status','--porcelain=v1','-z','--untracked-files=all'],cwd=repo).split(b'\0') if x]
small=[p for p in changes if '.tar.zst.part' not in p]
assert all(p.startswith('docs/remake/') for p in changes)
assert len(parts)==162
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=repo).strip()
state={'reason':'User requested stop and save all written work','source_commit':'c3115b7a82bab5e2faf579ad218abe47eee07cf4','CI':'SKIPPED_FOR_SAVE_COMMITS; full CI NOT_VERIFIED','pushes':[]}

def run(args):
    with log.open('ab') as stream:
        stream.write(('\nCOMMAND '+repr(args)+'\n').encode());stream.flush()
        subprocess.run(args,cwd=repo,stdout=stream,stderr=subprocess.STDOUT,check=True)

for index in range(4):
    group=parts[index*41:(index+1)*41]
    run(['git','-c','core.compression=0','add','--sparse','--',*((small if index==0 else [])+group)])
    run(['git','diff','--cached','--check'])
    run(['git','commit','-m',f'[skip ci] Save user-stopped batch17 evidence ({index+1}/4)'])
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
    run(['git','-c','pack.compression=0','push','origin','HEAD:feature/twilight-remaining106-20261016'])
    remote=subprocess.check_output(['git','ls-remote','origin','refs/heads/feature/twilight-remaining106-20261016'],cwd=repo,text=True).split()[0]
    assert remote==head,(remote,head)
    state['pushes'].append({'batch':index+1,'head':head,'archive_parts':len(group),'UTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'remote_HEAD_verified':True})
    receipt.write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(state['pushes'][-1]),flush=True)
print('ALL_STOP_EVIDENCE_PUSHED',flush=True)
