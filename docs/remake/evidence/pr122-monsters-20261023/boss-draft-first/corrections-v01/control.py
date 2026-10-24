#!/usr/bin/env python3
"""One bounded generation attempt for each previously absent boss sheet."""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
from pathlib import Path
import subprocess
import time

HERE=Path(__file__).resolve().parent
PRODUCTION=HERE.parent
ROOT=PRODUCTION.parents[4]

def read(p):return json.loads(p.read_text())
def write(p,data):
    p.parent.mkdir(parents=True,exist_ok=True)
    tmp=p.with_suffix(p.suffix+'.tmp')
    tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    tmp.replace(p)
def key(j):return j['slug']+'__'+j['clip']
def receipt(j):return PRODUCTION/j['slug']/(j['clip']+'-receipt.json')
@contextmanager
def locked():
    with open('/tmp/twilight-pr122-corrections-v01.lock','w') as f:
        fcntl.flock(f,fcntl.LOCK_EX)
        yield
def status():
    jobs=read(HERE/'queue.json')['jobs']
    saved=[j for j in jobs if receipt(j).exists()]
    holds=list((HERE/'attempts').glob('*.json'))
    held=sum(read(p)['status']=='HOLD' for p in holds)
    running=sum(1 for j in jobs if (HERE/'attempts'/(key(j)+'.work')).exists() and not receipt(j).exists() and not (HERE/'attempts'/(key(j)+'.json')).exists())
    return dict(planned=len(jobs),saved=len(saved),remaining=len(jobs)-len(saved),held=held,running=running,global_pause=(HERE/'generation-pause.json').exists(),new_approvals=0)
def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['claim','save','error','status']);p.add_argument('--slug');p.add_argument('--clip');p.add_argument('--image');p.add_argument('--reason');p.add_argument('--global-pause',action='store_true');a=p.parse_args()
    with locked():
        jobs=read(HERE/'queue.json')['jobs']
        if a.action=='status':print(json.dumps(status()));return
        if a.action=='claim':
            if (HERE/'generation-pause.json').exists():print(json.dumps(dict(done=True,reason='GLOBAL_PROVIDER_PAUSE',summary=status())));return
            for j in jobs:
                attempt=HERE/'attempts'/(key(j)+'.json');work=attempt.with_suffix('.work')
                if receipt(j).exists() or attempt.exists() or work.exists():continue
                request=read(ROOT/j['request'])
                for path in request['request'].get('referenced_image_paths',[]):
                    assert Path(path).is_file()
                write(work,dict(slug=j['slug'],clip=j['clip'],status='RUNNING',started_unix=time.time(),request=j['request'],attempt=1))
                print(json.dumps(dict(done=False,job=j,request=request['request']),ensure_ascii=False));return
            print(json.dumps(dict(done=True,summary=status())));return
        j=next(j for j in jobs if j['slug']==a.slug and j['clip']==a.clip)
        attempt=HERE/'attempts'/(key(j)+'.json')
        assert not attempt.exists(),'Do not retry a finished attempt'
        record=dict(slug=j['slug'],clip=j['clip'],attempt=1,finished_unix=time.time(),request=j['request'])
        if a.action=='save':
            r=subprocess.run(['python3',str(PRODUCTION/'record_source.py'),j['slug'],j['clip'],a.image],cwd=ROOT,text=True,capture_output=True,check=True)
            d=read(receipt(j));record.update(status='SAVED',sha256=d['sha256'],source=d['source'],source_imagegen_path=d['source_imagegen_path'])
        else:
            record.update(status='HOLD',reason=a.reason[:2400],automatic_retry=False)
            if a.global_pause:write(HERE/'generation-pause.json',dict(status='PROVIDER_PAUSE',reason=a.reason[:2400],at_unix=time.time(),automatic_retry=False))
        write(attempt,record)
        print(json.dumps(dict(slug=j['slug'],clip=j['clip'],status=record['status'],summary=status()),ensure_ascii=False))
if __name__=='__main__':main()
