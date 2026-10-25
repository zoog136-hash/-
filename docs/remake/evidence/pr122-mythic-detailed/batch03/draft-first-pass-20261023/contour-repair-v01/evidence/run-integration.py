import json,os,subprocess,re
from pathlib import Path
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-contour-repair-20261023');stage=json.loads((s/'staging-summary.json').read_text());reg=json.loads((r/'data/pr122_native_locomotion_staging.json').read_text());keys=stage['keys'];groups=[keys[i:i+2] for i in range(0,len(keys),2)];results=[]
for index,group in enumerate(groups):
 env=os.environ.copy();env.update(TWILIGHT_NATIVE_TEST_KEYS=','.join(group),XDG_DATA_HOME='/workspace/scratch/twilight-test-pr122-contour',XDG_CACHE_HOME='/workspace/scratch/pr122-runtime-cache',XDG_CONFIG_HOME='/workspace/scratch/pr122-runtime-config');path=s/f'main-player-{index:02d}.log'
 with path.open('w') as stream:
  try:rc=subprocess.run(['/workspace/scratch/godot472/Godot_v4.7.2-stable_linux.x86_64','--headless','--fixed-fps','120','--disable-render-loop','--path',str(r),'--script','res://tests/pr122_native_batch_candidate_test.gd'],env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=100).returncode
  except subprocess.TimeoutExpired:rc=124
 log=path.read_text();match=re.search(r'PR122_BATCH_CANDIDATE_INTEGRATION_PASS actors=(\d+) clips=(\d+) death_directions=(\d+) unsized_frame_fixtures=(\d+)',log);expected=sum(reg['actors'][k]['native_track_count'] for k in group)
 ok=bool(rc==0 and match and int(match[1])==len(group) and int(match[2])==expected and 'ERROR:' not in log)
 result=dict(keys=group,status='PASS' if ok else 'HOLD',exit_code=rc,clips=expected,death_directions=int(match[3]) if match else 0,unsized_frame_fixtures=int(match[4]) if match else None,log=path.name);results.append(result)
 (s/'integration-results.json').write_text(json.dumps(results,indent=2)+'\n')
 if not ok:break
summary=dict(status='PASS' if len(results)==len(groups) and all(x['status']=='PASS' for x in results) else 'HOLD',actors=sum(len(x['keys']) for x in results),clips=sum(x['clips'] for x in results),death_directions=sum(x['death_directions'] for x in results),groups=results,production_switches=0,final_approvals_added=0)
(s/'integration-summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:summary[k] for k in ('status','actors','clips','death_directions')}))
