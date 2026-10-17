import os,json,time,subprocess
from pathlib import Path
base=Path('/workspace/scratch/pr100-continuation/main-batch29')
commands=[]
for mode in ['headless','render']:
 out=base/mode;out.mkdir(exist_ok=True)
 env=os.environ.copy();env.update({'DISPLAY':':99','LIBGL_ALWAYS_SOFTWARE':'1','XDG_DATA_HOME':str(out/'data'),'XDG_CACHE_HOME':str(out/'cache'),'XDG_CONFIG_HOME':str(out/'config'),'TWILIGHT_PR100_BATCH_ISOLATED':'1','TWILIGHT_PR100_BATCH_CONFIG':'res://tests/fixtures/pr100_batch29.json','TWILIGHT_PR100_BATCH_REPORT':str(out/'report.json'),'TWILIGHT_PR100_BATCH_CAPTURE_DIR':str(out/'captures') if mode=='render' else '', 'TWILIGHT_ORIGINAL_POSE_CAPTURE':'1' if mode=='render' else '0'})
 args=['/workspace/scratch/bin/godot-pr100']+(['--headless'] if mode=='headless' else ['--rendering-driver','opengl3'])+['--audio-driver','Dummy','--path','/workspace/twilight','--script','res://tests/run_original_based_boss_batch.gd']
 log=(out/'engine.log').open('wb'); p=subprocess.Popen(args,env=env,stdout=log,stderr=subprocess.STDOUT);commands.append((mode,p,log,time.monotonic())); print(json.dumps({'started':mode,'pid':p.pid}),flush=True)
for mode,p,log,start in commands:
 try: result=p.wait(timeout=1800)
 except subprocess.TimeoutExpired:p.terminate();result=p.wait()
 log.close();print(json.dumps({'mode':mode,'exit_code':result,'elapsed':round(time.monotonic()-start,3)}),flush=True)
