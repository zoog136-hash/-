#!/usr/bin/env python3
"""Run the additive QA-clocked Main validator with fresh isolated XDG roots.

Creates a new output directory, captures the exact validator bytes/SHA and
explicit command, and refuses a changed validator or a failed engine result.
No production file or existing guard is modified.
"""
from pathlib import Path
import argparse,hashlib,json,os,subprocess,time
p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('--config',action='append',default=[]);p.add_argument('--render',action='store_true');p.add_argument('--godot',default='/workspace/scratch/bin/godot-pr100');p.add_argument('--root',default='/workspace/twilight');p.add_argument('--timeout',type=int,default=1800);a=p.parse_args()
out=Path(a.output).resolve();assert not out.exists(),f'Fresh output directory required: {out}';out.mkdir(parents=True)
root=Path(a.root).resolve();validator=root/'tests/original_based_temporal_main_test.gd';source=validator.read_bytes();sha=hashlib.sha256(source).hexdigest();(out/'validator.gd').write_bytes(source)
env=os.environ.copy();settings={}
for key,leaf in [('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('XDG_RUNTIME_DIR','runtime')]:
 d=out/leaf;d.mkdir();env[key]=str(d);settings[key]=str(d)
settings['TWILIGHT_PR100_TEMPORAL_ISOLATED']='1';settings['TWILIGHT_PR100_TEMPORAL_REPORT']=str(out/'summary.json')
if a.config:settings['TWILIGHT_PR100_TEMPORAL_CONFIGS']=';'.join(str(Path(x).resolve())for x in a.config)
if a.render:
 settings['TWILIGHT_PR100_TEMPORAL_CAPTURE_DIR']=str(out/'captures');settings['LIBGL_ALWAYS_SOFTWARE']='1';settings['DISPLAY']=env.get('DISPLAY',':99')
else:
 env.pop('TWILIGHT_PR100_TEMPORAL_CAPTURE_DIR',None)
for k,v in settings.items():env[k]=v
cmd=[a.godot,'--path',str(root),'--script','res://tests/original_based_temporal_main_test.gd','--audio-driver','Dummy']
cmd+=['--display-driver','x11','--rendering-method','gl_compatibility']if a.render else['--headless']
metadata={'command':cmd,'explicit_environment':settings,'validator_sha256':sha,'clock':'120Hz QA simulation; every step checked/logged; native texture changes captured at actual frame_post_draw. No real-time performance/AI/combat/weapon-death claim.','started_wall_ns':time.time_ns(),'rendered':a.render}
(out/'invocation.json').write_text(json.dumps(metadata,indent=2)+'\n')
with (out/'engine.log').open('w')as log:
 result=subprocess.run(cmd,env=env,cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=a.timeout)
metadata['finished_wall_ns']=time.time_ns();metadata['returncode']=result.returncode;metadata['validator_unchanged_during_run']=validator.read_bytes()==source
if (out/'summary.json').exists():
 summary=json.loads((out/'summary.json').read_text());metadata['failures']=summary.get('failures');metadata['cases']=summary.get('cases');metadata['summary_sha256']=hashlib.sha256((out/'summary.json').read_bytes()).hexdigest()
(out/'invocation.json').write_text(json.dumps(metadata,indent=2)+'\n');print(json.dumps(metadata,ensure_ascii=False))
assert result.returncode==0 and metadata.get('failures')==[] and metadata['validator_unchanged_during_run'],f'Validation failed; preserved at {out}'
