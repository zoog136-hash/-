"""Godot 4.7.2 import, boot, every original smoke test, and the field suite.

Usage: python3 tools/test_project.py --godot /path/to/godot
Each test receives a temporary XDG data directory, never the player's save.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import re
import json

parser=argparse.ArgumentParser()
parser.add_argument('--godot',default='godot')
parser.add_argument('--logs',default='test-results')
parser.add_argument('--timeout',type=int,default=150,help='Per-check limit in seconds; assertions are unchanged')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
logs=Path(args.logs).resolve();logs.mkdir(parents=True,exist_ok=True)
tests=[('import',['--editor','--quit']),('boot',['--quit-after','60'])]
tests.extend((p.stem,['--script','res://tests/'+p.name]) for p in sorted((root/'tests').glob('*test.gd')))
failed=[]
for name,extra in tests:
    with tempfile.TemporaryDirectory(prefix='twilight-test-') as user_data:
        env=os.environ.copy();env['XDG_DATA_HOME']=user_data
        try:
            p=subprocess.run([args.godot,'--headless','--path',str(root),*extra],capture_output=True,text=True,env=env,timeout=args.timeout)
            output=p.stdout+p.stderr
            ok=p.returncode==0 and not re.search(r'SCRIPT ERROR:|ERROR:|FAIL:',output)
            if name not in ('import','boot'):
                ok=ok and ('_OK' in output)
        except subprocess.TimeoutExpired as exc:
            output='TIMEOUT '+str(exc);ok=False
        (logs/(name+'.log')).write_text(output,encoding='utf-8')
        print(('PASS ' if ok else 'FAIL ')+name,flush=True)
        if not ok:failed.append(name)
print(f'{len(tests)-len(failed)}/{len(tests)} checks passed')
(logs/'summary.json').write_text(json.dumps({'total':len(tests),'passed':len(tests)-len(failed),
    'failed':failed,'checks':[name for name,_ in tests]},indent=2)+'\n',encoding='utf-8')
raise SystemExit(bool(failed))
