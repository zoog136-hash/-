#!/usr/bin/env python3
"""Save finished draft art every six sheets while generation continues.

This is a local file/Git worker, not an art reviewer. It never regenerates
sources, starts CI, deletes art, force-pushes or creates a branch/PR.
"""
import json
import os
from pathlib import Path
import subprocess
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
LOCK='/tmp/twilight-pr122-production-git.lock'
STOP=Path('/tmp/twilight-pr122-draft-checkpoints-stop')
BRANCH='feature/twilight-remaining106-20261016'
BACKUP='backup/pr122-boss-corrections-20261023-6b49107e'

def run(args,**kwargs):
    return subprocess.run(args,cwd=ROOT,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=180,**kwargs)

def push(ref):
    env=os.environ.copy();env['GIT_NO_LAZY_FETCH']='1'
    return run(['git','-c','push.useBitmaps=false','-c','pack.window=0','-c','pack.depth=0','-c','pack.useBitmaps=false','-c','push.negotiate=true','push','--no-thin','--quiet','origin','HEAD:'+ref],env=env)

def locked_batch(label,publish):
    import fcntl
    with open(LOCK,'w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        r=run(['python3',str(HERE/'checkpoint.py'),'--label',label])
        if r.returncode:raise RuntimeError('checkpoint failed: '+r.stderr[-600:])
        result=json.loads(r.stdout)
        if not publish:return result,None
        # Pre-upload objects to the existing durable backup; the normal PR
        # update can then complete quickly even with parallel remote commits.
        r=push(BACKUP)
        if r.returncode:return result,'backup push: '+r.stderr[-500:]
        for _ in range(2):
            r=run(['git','fetch','--quiet','--no-tags','origin',BRANCH])
            if r.returncode:return result,'fetch: '+r.stderr[-500:]
            r=run(['git','-c','merge.renames=false','merge','--quiet','--no-edit','-m','[skip ci] Preserve parallel PR122 work with boss draft sources','FETCH_HEAD'])
            if r.returncode:raise RuntimeError('merge requires repair: '+r.stderr[-500:]+r.stdout[-500:])
            r=push(BRANCH)
            if not r.returncode:
                result['remote_PR_commit']=run(['git','rev-parse','HEAD']).stdout.strip()
                return result,None
            if not any(v in r.stderr for v in ('fetch first','non-fast-forward','cannot lock ref')):return result,'PR push: '+r.stderr[-500:]
        return result,'Parallel push race after two normal attempts; preserved backup and local commits'

def count():return len(list(HERE.glob('*/*-receipt.json')))

def main():
    if STOP.exists():raise RuntimeError('Remove the explicit stop file before starting a new worker')
    previous=count();last_change=time.monotonic();number=1;network_failures=0
    print(json.dumps(dict(status='CHECKPOINT_WORKER_STARTED',already_saved_sources=previous)),flush=True)
    while not STOP.exists():
        current=count()
        if current!=previous:last_change=time.monotonic()
        if current-previous>=6:
            while (HERE/'checkpoints'/f'auto{number:03}.json').exists():number+=1
            label=f'auto{number:03}';number+=1
            try:
                result,error=locked_batch(label,network_failures<3)
                previous=current
                if error:network_failures+=1
                else:network_failures=0
                result.update(checkpoint=label,publish_error=error,publishing_paused=network_failures>=3)
                print(json.dumps(result,ensure_ascii=False),flush=True)
                (HERE/'delivery-worker-state.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
            except Exception as error:
                print(json.dumps(dict(status='CHECKPOINT_WORKER_HOLD',reason=str(error)[:1000]),ensure_ascii=False),flush=True)
                return
        if time.monotonic()-last_change>1800:
            print(json.dumps(dict(status='IDLE_EXIT_NO_RETRY')),flush=True);return
        time.sleep(15)
    print(json.dumps(dict(status='EXPLICIT_STOP')),flush=True)

if __name__=='__main__':main()
