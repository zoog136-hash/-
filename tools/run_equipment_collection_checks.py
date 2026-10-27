#!/usr/bin/env python3
"""Bounded native regression run; delegates fixture handling and isolation to the
existing project runner. Captures are a separate actual OpenGL Main invocation.
No dependency installation, privileged operations, or source rewrites here.
"""
import argparse,os,sys,subprocess,tempfile,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--godot',required=True);p.add_argument('--logs',default='collection-results');args=p.parse_args()
root=Path(__file__).resolve().parents[1];logs=Path(args.logs).resolve();logs.mkdir(parents=True,exist_ok=True)
godot=str(Path(args.godot).resolve())
selected='import,bake_navigation,boot,equipment_collection_runtime_test,equipment_collection_stats_test,equipment_collection_bindings_test,per_instance_enchantments_smoke_test,ui_renewal_integration_test,ui_pointer_transfer_test'
# Preserve all regressions; the full native PNG import outlasts 900s on runners.
result=subprocess.run([sys.executable,str(root/'tools/test_project.py'),'--godot',godot,
                       '--import-timeout','1800','--logs',str(logs/'regression'),'--only',selected],cwd=root)
if result.returncode:sys.exit(result.returncode)
with tempfile.TemporaryDirectory(prefix='twilight-collections-render-') as data:
 env=os.environ.copy();env.update(XDG_DATA_HOME=data,APPDATA=data,LOCALAPPDATA=data,LIBGL_ALWAYS_SOFTWARE='1',TWILIGHT_COLLECTION_CAPTURE_DIR=str(logs/'captures'))
 command=['xvfb-run','-a','-s','-screen 0 1280x720x24',godot,'--rendering-driver','opengl3','--audio-driver','Dummy','--path',str(root),'--script','res://tests/equipment_collection_runtime_test.gd','--','--capture-collections']
 try:
  run=subprocess.run(command,cwd=root,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=240)
  output=run.stdout;ok=run.returncode==0 and 'EQUIPMENT_COLLECTION_RUNTIME_OK' in output and not any(s in output for s in ['SCRIPT ERROR:','ERROR:','COLLECTION_FAIL:'])
 except subprocess.TimeoutExpired as exc:
  output='TIMEOUT '+str(exc);ok=False
 (logs/'capture.log').write_text(output)
 if not ok: print(output[-16000:]);sys.exit(1)
 for name in ['collections_1280x720.png','collections_960x540.png']:
  if not (logs/'captures'/name).exists():raise SystemExit('Missing native render '+name)
print('EQUIPMENT_COLLECTION_NATIVE_CHECKS_OK')
