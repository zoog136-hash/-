#!/usr/bin/env python3
"""Load final merged profiles and play only changed clips in real Godot at1x."""
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,os,subprocess,shutil
from pathlib import Path
HERE=Path(__file__).resolve().parent
B=HERE.parent
ROOT=B.parents[4]
OUT=HERE/'final-integration'
def read(p):return json.loads(p.read_text())
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def process(item):
    n,actor=item;slug=actor['slug'];candidate=read(ROOT/actor['candidate']);profile=candidate['actors'][actor['key']]
    for field in ['frames','native_profile']:
        p=ROOT/profile[field].removeprefix('res://');assert hashlib.sha256(p.read_bytes()).hexdigest()==profile[field+'_sha256']
    changed=[t for t in profile['tracks'] if t['source'].endswith('-v02.png')]
    # A single already-reviewed baseline exercises a merged profile which has
    # no new v02 clip. This is the one final integration, not broad QA replay.
    if not changed:changed=profile['tracks'][:1]
    grouped=defaultdict(list)
    for t in changed:grouped[t['role']].append(t['direction'])
    cases=[dict(key=actor['key'],slug=slug+'_'+role,native_profile=profile['native_profile'],roles=[role],directions=directions,run_seconds=1.05,idle_seconds=1.25) for role,directions in grouped.items()]
    casefile=OUT/(slug+'-cases.json');write(casefile,cases)
    runtime=Path('/workspace/runtime')/('boss-final-integration-'+slug);assert not runtime.exists()
    env=os.environ.copy();env['BOSS_FIX_QA_DISPLAY_START']=str(481+n*3)
    command=['python3',str(B.parent/'boss-fix-runtime/run.py'),'--case-file',str(casefile),'--out',str(runtime),'--render','--timeout','240']
    result=subprocess.run(command,cwd=ROOT,env=env,text=True,capture_output=True,timeout=260)
    status='PASS' if result.returncode==0 and not read(runtime/'process.json')['script_errors'] else 'HOLD'
    if status=='PASS':assert all(s['status']=='PLAYED_AT_GAME_SCALE' for c in read(runtime/'report.json')['cases'] for s in c['segments'])
    dest=OUT/slug/'runtime';dest.mkdir(parents=True,exist_ok=True)
    for name in ['process.json','report.json','capture-manifest.json','config.json','godot-run.txt']:
        if (runtime/name).exists():shutil.copyfile(runtime/name,dest/name)
    for p in runtime.glob('*/captures/*.png'):
        target=dest/p.relative_to(runtime);target.parent.mkdir(exist_ok=True,parents=True);shutil.copyfile(p,target)
    summary=dict(slug=slug,key=actor['key'],status=status,final_tracks_loaded=profile['native_track_count'],played_changed_or_integration_clips=len(changed),runtime=dest.relative_to(ROOT).as_posix(),automatic_retry=False)
    write(OUT/slug/'summary.json',summary);print(json.dumps(summary),flush=True);return summary
def main():
    actors=read(HERE/'final-reviewed-v01/summary.json')['actors']
    with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(process,enumerate(actors)))
    write(OUT/'summary.json',dict(status='PASS' if all(x['status']=='PASS' for x in results) else 'HOLD',actors=results,normal_art_changed=0,Main_default_profiles_changed=False,full_CI_runs=0))
if __name__=='__main__':main()
