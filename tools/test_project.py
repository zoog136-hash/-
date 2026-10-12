"""Godot 4.7.2 import, boot, every original smoke test, and the field suite.

Usage: python3 tools/test_project.py --godot /path/to/godot
Each test receives temporary Linux and Windows data directories, never the player's save.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import re
import json
import sys

parser=argparse.ArgumentParser()
parser.add_argument('--godot',default='godot')
parser.add_argument('--logs',default='test-results')
parser.add_argument('--render-visual-tests',action='store_true',help='Use the existing display only for tests that await frame_post_draw')
parser.add_argument('--timeout',type=int,default=150,help='Per-check seconds; world_regions has a 540-second minimum for 24 scene roundtrips; assertions are unchanged')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
# CI checkouts intentionally omit third-party visuals; install tiny, original
# synthetic fixtures only when none of the fixture paths is present.
# Real or partially installed resources must never be replaced.
if os.environ.get('GITHUB_ACTIONS','').lower() == 'true':
    targets = [
        root/'data/l1j/maps/raw/4.bin',
        root/'data/l1j/registry/a2_visuals_normalized.json',
        root/'assets/l1j/preview/a2/items/34.png',
        root/'assets/l1j/preview/a2/monsters/ms852.png',
        root/'assets/l1j/candidates/spx_converted/99999-0/SpriteFrames.tres',
    ]
    if not any(p.exists() for p in targets):
        subprocess.run([sys.executable,str(root/'tools/l1j_ci_make_fixture.py'),
                        '--root',str(root)],check=True,cwd=root)
        print('CI_SYNTHETIC_L1J_FIXTURES_OK',flush=True)

logs=Path(args.logs).resolve();logs.mkdir(parents=True,exist_ok=True)
tests=[('import',['--editor','--quit']),('boot',['--quit-after','60'])]
tests.extend((p.stem,['--script','res://tests/'+p.name]) for p in sorted((root/'tests').glob('*test.gd')))
failed=[]
skipped=[]
for name,extra in tests:
    source=root/'tests'/(name+'.gd')
    visual=args.render_visual_tests and source.is_file() and 'RenderingServer.frame_post_draw' in source.read_text(encoding='utf-8')
    display_args=['--rendering-driver','opengl3','--audio-driver','Dummy'] if visual else ['--headless']
    with tempfile.TemporaryDirectory(prefix='twilight-test-') as user_data:
        env=os.environ.copy()
        env['XDG_DATA_HOME']=user_data
        # Godot Windows uses APPDATA, not XDG_DATA_HOME. Every process, including
        # the PCK probe child, must inherit its own empty save/config directory.
        env['APPDATA']=user_data
        env['LOCALAPPDATA']=user_data
        try:
            # This integration case visits 24 fields, saves/loads each one and
            # returns to the enlarged Aden continent after every visit.
            # Preserve every assertion while giving these repeated scene loads
            # their own bounded budget; other tests keep the selected limit.
            budget=max(args.timeout,540) if name=='world_regions_test' else args.timeout
            p=subprocess.run([args.godot,*display_args,'--path',str(root),*extra],capture_output=True,text=True,env=env,timeout=budget)
            output=p.stdout+p.stderr
            ok=p.returncode==0 and not re.search(r'SCRIPT ERROR:|ERROR:|FAIL:',output)
            is_skipped=p.returncode==0 and '_SKIP:' in output and not re.search(r'SCRIPT ERROR:|ERROR:|FAIL:',output)
            if is_skipped:
                skipped.append(name)
                ok=True
            elif name not in ('import','boot'):
                reports=[]
                for line in output.splitlines():
                    match=re.search(r'\b[A-Z_]+_RESULT (\{.*\})$',line)
                    if match:
                        try: reports.append(json.loads(match.group(1)))
                        except json.JSONDecodeError: pass
                result_ok=bool(reports) and all(report.get('failures')==[] for report in reports)
                ok=ok and ('_OK' in output or result_ok)
        except subprocess.TimeoutExpired as exc:
            output='TIMEOUT '+str(exc);ok=False
        (logs/(name+'.log')).write_text(output,encoding='utf-8')
        print(('SKIP ' if name in skipped else ('PASS ' if ok else 'FAIL '))+name,flush=True)
        if not ok:failed.append(name)
print(f'{len(tests)-len(failed)-len(skipped)}/{len(tests)} checks passed; {len(skipped)} skipped')
(logs/'summary.json').write_text(json.dumps({'total':len(tests),'passed':len(tests)-len(failed)-len(skipped),
    'failed':failed,'skipped':skipped,'checks':[name for name,_ in tests]},indent=2)+'\n',encoding='utf-8')
raise SystemExit(bool(failed))
