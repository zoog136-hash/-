"""Godot 4.7.2 import, boot, every original smoke test, and the field suite.

Usage: python3 tools/test_project.py --godot /path/to/godot
Each test receives temporary Linux and Windows data directories, never the player's save.
"""
import argparse
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import re
import json
import sys
from test_project_support import classify_result, run_isolated, timeout_budget

parser=argparse.ArgumentParser()
parser.add_argument('--godot',default='godot')
parser.add_argument('--logs',default='test-results')
parser.add_argument('--render-visual-tests',action='store_true',help='Compatibility flag: frame-dependent tests always use a real renderer')
parser.add_argument('--timeout',type=int,default=150,help='Per-test seconds; exhaustive map/save and skill-learning audits have a 540-second minimum')
parser.add_argument('--import-timeout',type=int,default=900,help='One-time complete Godot asset import deadline in seconds')
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
# Navigation files are derived from the *effective* runtime spawn layout.
# Rebuild them after import, before boot/cache equivalence tests, without
# changing the integrity checks or accepting a stale navigation signature.
tests=[('import',['--import']),
       ('bake_navigation',['--script','res://tools/bake_hunting_navigation.gd']),
       ('boot',['--quit-after','60'])]
tests.extend((p.stem,['--script','res://tests/'+p.name]) for p in sorted((root/'tests').glob('*test.gd')))
failed=[]
skipped=[]
executed=[]
not_run=[]
for name,extra in tests:
    executed.append(name)
    source=root/'tests'/(name+'.gd')
    needs_draw=source.is_file() and 'RenderingServer.frame_post_draw' in source.read_text(encoding='utf-8')
    # A headless RenderingServer never emits frame_post_draw. Historically
    # these tests silently ran for 150 seconds each before timing out.
    visual=needs_draw # Never block awaiting draw events under the headless renderer.
    display_args=['--rendering-driver','opengl3','--audio-driver','Dummy'] if visual else ['--headless']
    with tempfile.TemporaryDirectory(prefix='twilight-test-') as user_data:
        env=os.environ.copy()
        env['XDG_DATA_HOME']=user_data
        # Godot Windows uses APPDATA, not XDG_DATA_HOME. Every process, including
        # the PCK probe child, must inherit its own empty save/config directory.
        env['APPDATA']=user_data
        env['LOCALAPPDATA']=user_data
        if visual: env['LIBGL_ALWAYS_SOFTWARE']='1'
        try:
            budget=timeout_budget(name,args.timeout,args.import_timeout)
            command=[args.godot,*display_args,'--path',str(root),*extra]
            if visual and sys.platform.startswith('linux') and not env.get('DISPLAY'):
                if not shutil.which('xvfb-run'):
                    raise RuntimeError('Visual test requires xvfb-run (or DISPLAY); never wait for frame_post_draw in headless mode')
                command=['xvfb-run','-a','-s','-screen 0 1280x720x24',*command]
            p=run_isolated(command,env=env,timeout=budget,cwd=str(root))
            output=p.stdout+p.stderr
            ok,is_skipped=classify_result(name,p.returncode,output)
            if is_skipped:
                skipped.append(name)
            if ok and name=='bake_navigation':
                # Preserve the exact rebuilt files with the CI evidence.
                shutil.copytree(root/'data/maps/navigation',logs/'navigation',dirs_exist_ok=True)
        except OSError as exc:
            output='PROCESS_START_FAILED '+str(exc);ok=False
        except RuntimeError as exc:
            output='VISUAL_SETUP_FAILED '+str(exc);ok=False
        except subprocess.TimeoutExpired as exc:
            output='TIMEOUT '+str(exc)+'\n'+(exc.stdout.decode(errors='replace') if isinstance(exc.stdout,bytes) else (exc.stdout or ''))+'\n'+(exc.stderr.decode(errors='replace') if isinstance(exc.stderr,bytes) else (exc.stderr or ''));ok=False
        (logs/(name+'.log')).write_text(output,encoding='utf-8')
        print(('SKIP ' if name in skipped else ('PASS ' if ok else 'FAIL '))+name,flush=True)
        if not ok:
            failed.append(name)
            if name in ('import','bake_navigation'):
                # Do not manufacture unrelated failures after broken preparation.
                not_run=[remaining for remaining,_ in tests[len(executed):]]
                print('BLOCKED_BY_'+name.upper()+' '+str(len(not_run))+' checks',flush=True)
                break
passed=len(executed)-len(failed)-len(skipped)
print(f'{passed}/{len(tests)} checks passed; {len(skipped)} skipped; {len(not_run)} not run',flush=True)
(logs/'summary.json').write_text(json.dumps({'total':len(tests),'passed':passed,
    'failed':failed,'skipped':skipped,'not_run':not_run,'checks':[name for name,_ in tests]},indent=2)+'\n',encoding='utf-8')
raise SystemExit(bool(failed or not_run))
