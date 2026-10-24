#!/usr/bin/env python3
"""One minimum load/playback check per new sheet, without whole quality review.

Raw drafts keep generating independently. Unsafe source geometry is recorded
once for the final grouped repair; it never blocks the other actors or retries.
"""
from collections import defaultdict
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
PRODUCTION=HERE.parent
ROOT=PRODUCTION.parents[4]
sys.path.insert(0,str(PRODUCTION))
import checkpoint_worker
STOP=Path('/tmp/twilight-pr122-resume210-minimum-stop')

def read(p):return json.loads(p.read_text())
def write(p,d):
    p.parent.mkdir(parents=True,exist_ok=True)
    tmp=p.with_suffix('.json.tmp');tmp.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');tmp.replace(p)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args,**kwargs):return subprocess.run(args,cwd=ROOT,text=True,capture_output=True,check=True,**kwargs)

def process(jobs,number):
    label=f'bossfix-min{number:03}'
    batch=HERE/'minimum-batches'/label
    batch.mkdir(parents=True,exist_ok=True)
    write(batch/'input.json',dict(jobs=jobs,source_pins=[read(PRODUCTION/j['slug']/(j['clip']+'-receipt.json')) for j in jobs],normal_art_changes=0,whole_quality_review='TARGETED_CORRECTIONS_ONLY'))
    grouped=defaultdict(list)
    for j in jobs:grouped[j['slug']].append(j['clip'])
    cases=[];candidates=[];holds=[];paths={batch/'input.json'}
    for slug,clips in grouped.items():
        selection=batch/(slug+'-clips.json');write(selection,clips);paths.add(selection)
        result=subprocess.run(['python3',str(PRODUCTION/'stage_structural_batch.py'),slug,'--revision',label,'--receipt-list',str(selection)],cwd=ROOT,text=True,capture_output=True,timeout=180)
        candidate=PRODUCTION/slug/label/'candidate.json'
        if result.returncode:
            # All source checks can legitimately HOLD, with no safe track left.
            assert not candidate.exists()
            for clip in clips:
                check=PRODUCTION/slug/'structural-checks'/(clip+'.json')
                assert check.exists() and read(check)['status']=='SOURCE_HOLD',result.stderr[-1200:]
                holds.append(dict(slug=slug,clip=clip,reason=read(check)['reason']))
            continue
        d=read(candidate);actor,staged=next(iter(d['actors'].items()));candidates.append(candidate)
        paths.add(candidate);paths.add(ROOT/staged['frames'].removeprefix('res://'));paths.add(ROOT/staged['native_profile'].removeprefix('res://'))
        roles=defaultdict(list)
        for track in staged['tracks']:
            roles[track['role']].append(track['direction']);paths.add(ROOT/track['texture'])
        holds.extend(dict(slug=slug,**v) for v in d['source_holds'])
        for role,directions in roles.items():cases.append(dict(key=actor,slug=slug+'_'+role,native_profile=staged['native_profile'],roles=[role],directions=directions,run_seconds=1.05,idle_seconds=1.25))
    runtime=None
    if cases:
        casefile=batch/'cases.json';write(casefile,cases);paths.add(casefile)
        runtime=Path('/workspace/runtime')/label
        assert not runtime.exists(),'Use a new minimum batch; no repeated full playback'
        env=os.environ.copy();env['BOSS_FIX_QA_DISPLAY_START']='211'
        run(['python3',str(PRODUCTION.parent/'boss-fix-runtime/run.py'),'--case-file',str(casefile),'--out',str(runtime),'--render','--timeout','420'],env=env,timeout=440)
        assert read(runtime/'process.json')['returncode']==0 and not read(runtime/'process.json')['script_errors']
        report=read(runtime/'report.json')
        assert all(s['status']=='PLAYED_AT_GAME_SCALE' for c in report['cases'] for s in c['segments'])
        evidence=batch/'runtime'
        for name in ('process.json','report.json','capture-manifest.json','godot-run.txt','config.json'):
            dest=evidence/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(runtime/name,dest);paths.add(dest)
        for image in runtime.glob('*/captures/*.png'):
            dest=evidence/image.relative_to(runtime);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(image,dest);paths.add(dest)
    summary=dict(label=label,checked_new_sheets=len(jobs),safe_played_clips=sum(len(c['directions']) for c in cases),held=holds,production_connections_changed=0,new_approvals=0,full_visual_review='TARGETED_CORRECTIONS_ONLY',normal_art_changed=0,candidates=[p.relative_to(ROOT).as_posix() for p in candidates],runtime=str(runtime) if runtime else None,source_pins=[dict(slug=j['slug'],clip=j['clip'],sha256=read(PRODUCTION/j['slug']/(j['clip']+'-receipt.json'))['sha256']) for j in jobs])
    write(batch/'summary.json',summary);paths.add(batch/'summary.json')
    with open(checkpoint_worker.LOCK,'w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        run(['git','add','--sparse','-f','--',*(str(p.relative_to(ROOT)) for p in sorted(paths))])
        run(['git','diff','--cached','--check'])
        run(['git','commit','--quiet','-m','[skip ci] Check new boss draft playback '+label])
    print(json.dumps({k:v for k,v in summary.items() if k not in ('source_pins','candidates','held')},ensure_ascii=False),flush=True)
    return summary

def main():
    jobs=read(HERE/'queue.json')['jobs'];number=1;idle=0
    while not STOP.exists():
        done=set()
        for p in (HERE/'minimum-batches').glob('*/summary.json'):
            for j in read(p)['source_pins']:done.add((j['slug'],j['clip']))
        pending=[j for j in jobs if (j['slug'],j['clip']) not in done and (PRODUCTION/j['slug']/(j['clip']+'-receipt.json')).exists()]
        allsaved=all((PRODUCTION/j['slug']/(j['clip']+'-receipt.json')).exists() or (HERE/'attempts'/(j['slug']+'__'+j['clip']+'.json')).exists() for j in jobs)
        if len(pending)>=6 or (pending and allsaved):
            while (HERE/'minimum-batches'/f'bossfix-min{number:03}').exists():number+=1
            try:process(pending[:6],number)
            except Exception as e:
                write(HERE/'minimum-worker-hold.json',dict(status='BOUNDED_STOP',batch=number,reason=str(e)[-2000:],automatic_retry=False))
                print(json.dumps(dict(status='MINIMUM_WORKER_HOLD',batch=number,reason=str(e)[-1000:])),flush=True);return
            number+=1;idle=0
        else:
            if allsaved and not pending:print(json.dumps(dict(status='ALL_TARGETED_CORRECTIONS_MINIMUM_CHECKED')),flush=True);return
            idle+=1
            if idle>240:print(json.dumps(dict(status='IDLE_EXIT_NO_RETRY')),flush=True);return
            time.sleep(10)
if __name__=='__main__':main()
