from pathlib import Path
import json
import os
import subprocess
import time

root=Path('/workspace/runtime/batch16')
out=root/'Spider-Family-Temporal-QA-v01'
out.mkdir(exist_ok=False)
env=dict(os.environ)
for name in ['data','config','cache']:(out/name).mkdir()
env.update(DISPLAY=':107',LIBGL_ALWAYS_SOFTWARE='1',
    XDG_DATA_HOME=str(out/'data'),XDG_CONFIG_HOME=str(out/'config'),XDG_CACHE_HOME=str(out/'cache'),
    TWILIGHT_PR100_TEMPORAL_ISOLATED='1',
    TWILIGHT_PR100_TEMPORAL_CONFIG='res://tests/fixtures/pr122_batch16_spider_family.json',
    TWILIGHT_PR100_TEMPORAL_REPORT=str(out/'report.json'),
    TWILIGHT_PR100_TEMPORAL_CAPTURE_DIR=str(out/'captures'))
cmd=['/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64',
    '--path',str(root/'Main-project'),'--rendering-driver','opengl3','--audio-driver','Dummy',
    '--script','res://tests/original_based_temporal_main_test.gd']
start=time.monotonic()
with (out/'run.log').open('w') as log:r=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1500)
print('TEMPORAL_PROCESS',r.returncode,round(time.monotonic()-start,2),flush=True)
if r.returncode:
    print((out/'run.log').read_text(errors='replace')[-6000:],flush=True)
    raise SystemExit(r.returncode)
d=json.loads((out/'report.json').read_text());print('BATCH16_TEMPORAL_RESULT',json.dumps({k:v for k,v in d.items() if k not in ['cases','samples']},ensure_ascii=False),flush=True);assert not d['failures']
