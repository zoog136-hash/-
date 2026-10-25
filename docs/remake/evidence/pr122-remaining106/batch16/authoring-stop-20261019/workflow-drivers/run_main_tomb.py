from pathlib import Path
import os,subprocess,time
root=Path('/workspace/runtime/batch16');project=root/'Main-project';out=root/'Tomb-Main-QA-v01';out.mkdir(exist_ok=False)
env=dict(os.environ);env.update(DISPLAY=':107',LIBGL_ALWAYS_SOFTWARE='1')
for name in ['data','config','cache']:(out/name).mkdir()
env.update(XDG_DATA_HOME=str(out/'data'),XDG_CONFIG_HOME=str(out/'config'),XDG_CACHE_HOME=str(out/'cache'))
engine='/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
with (out/'import.log').open('w') as log:r=subprocess.run([engine,'--headless','--path',str(project),'--editor','--import'],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1200)
assert r.returncode==0,(out/'import.log').read_text()[-4000:]
print('TOMB_IMPORT_PASS',flush=True)
cmd=['python3','tools/run_pr122_tomb269_review.py','--project',str(project),'--fixture','res://tests/fixtures/pr122_tomb269_batch16.json','--output',str(out/'actual-Main'),'--godot',engine]
r=subprocess.run(cmd,cwd='/workspace/twilight',env=env);raise SystemExit(r.returncode)
