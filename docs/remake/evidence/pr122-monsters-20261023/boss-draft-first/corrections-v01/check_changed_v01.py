#!/usr/bin/env python3
"""Replay only newly packed, pose-selected, calibrated clips and adjacent idle."""
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
import json,os,subprocess,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent
B=HERE.parent
ROOT=B.parents[4]
R=HERE/'combined-reviewed-v01'
OUT=HERE/'changed-v01-playback'
def read(p):return json.loads(p.read_text())
def write(p,d):p.parent.mkdir(exist_ok=True,parents=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def run(args,**kw):return subprocess.run(args,cwd=ROOT,capture_output=True,text=True,check=True,**kw)
def process(item):
    number,(slug,clips)=item
    saved=OUT/slug/'summary.json'
    if saved.exists():return read(saved)  # Clean previous cases are never replayed.
    selection=OUT/(slug+'-clips.json');write(selection,clips)
    revision='reviewed-fixes-v01'
    run(['python3',str(B/'stage_structural_batch.py'),slug,'--revision',revision,'--reviewed-inventory','--inventory-root',str(R),'--frame-adjustments',str(R/'frame-adjustments-v01.json'),'--receipt-list',str(selection)])
    candidate=B/slug/revision/'candidate.json';actor,profile=next(iter(read(candidate)['actors'].items()))
    assert not read(candidate)['source_holds']
    roles=defaultdict(list)
    for t in profile['tracks']:roles[t['role']].append(t['direction'])
    cases=[dict(key=actor,slug=slug+'_'+role,native_profile=profile['native_profile'],roles=[role],directions=directions,run_seconds=1.05,idle_seconds=1.25) for role,directions in roles.items()]
    casefile=OUT/(slug+'-cases.json');write(casefile,cases)
    runtime=Path('/workspace/runtime')/('reviewed-fixes-v01-'+slug)
    if runtime.exists():
        # The sole retry follows the identified sparse-checkout repair. Keep
        # all initial evidence and never loop when the same error persists.
        initial=runtime/'process.json'
        assert not initial.exists() or read(initial)['script_errors'] or read(initial)['returncode']!=0
        runtime=Path(str(runtime)+'-environment-v02');assert not runtime.exists(),'Repeated failure: HOLD, no automatic retry'
    env=os.environ.copy();env['BOSS_FIX_QA_DISPLAY_START']=str(351+number*3)
    try:run(['python3',str(B.parent/'boss-fix-runtime/run.py'),'--case-file',str(casefile),'--out',str(runtime),'--render','--timeout','420'],env=env,timeout=450)
    except (subprocess.CalledProcessError,subprocess.TimeoutExpired) as error:
        result=dict(slug=slug,status='HOLD',changed_and_affected_clips=len(clips),runtime=str(runtime),reason=str(error),automatic_retry=False)
        write(saved,result);return result
    proc=read(runtime/'process.json');assert proc['returncode']==0 and not proc['script_errors']
    report=read(runtime/'report.json');assert all(s['status']=='PLAYED_AT_GAME_SCALE' for c in report['cases'] for s in c['segments'])
    dest=OUT/slug/'runtime';dest.mkdir(exist_ok=True,parents=True)
    for n in ['process.json','report.json','capture-manifest.json','godot-run.txt','config.json']:shutil.copyfile(runtime/n,dest/n)
    for p in runtime.glob('*/captures/*.png'):
        target=dest/p.relative_to(runtime);target.parent.mkdir(exist_ok=True,parents=True);shutil.copyfile(p,target)
    result=dict(slug=slug,changed_and_affected_clips=len(clips),candidate=candidate.relative_to(ROOT).as_posix(),runtime=dest.relative_to(ROOT).as_posix(),played_segments=sum(len(c['segments']) for c in report['cases']),status='PASS')
    write(OUT/slug/'summary.json',result);print(json.dumps(result),flush=True);return result
def main():
    rows=read(R/'structural-inventory.json')['clips'];bad={(j['slug'],j['corrects']) for j in read(HERE/'queue.json')['jobs']};adjust=read(R/'frame-adjustments-v01.json');groups=defaultdict(set)
    for x in rows:
        if (x['slug'],x['clip']) in bad:continue
        newly_packed=x.get('ownership_proof','').startswith('docs/remake/evidence/pr122-monsters-20261023/boss-draft-first/resume210-v01/')
        if newly_packed or x['clip'] in adjust.get(x['slug'],{}):groups[x['slug']].add(x['clip'])
    # Only south idle is affected by the death scale transition; no broad replay.
    for slug,clips in groups.items():
        if 'S-death-v01' in clips and (slug,'S-idle-v01') not in bad:clips.add('S-idle-v01')
    items=list(enumerate((slug,sorted(clips)) for slug,clips in sorted(groups.items())))
    with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(process,items))
    write(OUT/'summary.json',dict(status='PASS' if all(x['status']=='PASS' for x in results) else 'HOLD',actors=results,changed_or_affected_clips=sum(x['changed_and_affected_clips'] for x in results),unchanged_good_clips_replayed=0,normal_art_changed=0))
if __name__=='__main__':main()
