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
from test_project_support import classify_result, requires_renderer, run_isolated, timeout_budget, LEGACY_GEOMETRY_TESTS, select_checks

parser=argparse.ArgumentParser()
parser.add_argument('--godot',default='godot')
parser.add_argument('--logs',default='test-results')
parser.add_argument('--render-visual-tests',action='store_true',help='Compatibility flag: frame-dependent tests always use a real renderer')
parser.add_argument('--timeout',type=int,default=150,help='Per-test seconds; regional map audits run in five independently timed shards')
parser.add_argument('--import-timeout',type=int,default=900,help='One-time complete Godot asset import deadline in seconds')
parser.add_argument('--region-shard-timeout',type=int,default=360,help='Seconds per world family; all five families mandatory')
parser.add_argument('--only',default='',help='Comma-separated exact test names for targeted rechecks; omitted runs the full suite')
parser.add_argument('--shard-index',type=int,default=0)
parser.add_argument('--shard-count',type=int,default=1)
parser.add_argument('--no-ci-synthetic-fixtures',action='store_true',help='Audit committed resources without installing synthetic L1J fixtures')
args=parser.parse_args()
if args.shard_count < 1 or not 0 <= args.shard_index < args.shard_count:
    parser.error('Invalid shard index/count')
if args.only and (args.shard_count != 1 or args.shard_index != 0):
    parser.error('--only and sharding cannot be combined')
root=Path(__file__).resolve().parents[1]
# CI checkouts intentionally omit third-party visuals; install tiny, original
# synthetic fixtures only when none of the fixture paths is present.
# Real or partially installed resources must never be replaced.
if os.environ.get('GITHUB_ACTIONS','').lower() == 'true' and not args.no_ci_synthetic_fixtures:
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
try:
    tests,plan=select_checks(tests,args.only,args.shard_index,args.shard_count)
except ValueError as exc:
    parser.error(str(exc))
failed=[]
skipped=[]
executed=[]
not_run=[]
scopes={}
def write_summary() -> None:
    # Save after each completed check so cancellation cannot conceal omissions.
    report={'total':len(tests),'passed':len(executed)-len(failed)-len(skipped),
        'failed':failed,'skipped':skipped,'not_run':[n for n,_ in tests[len(executed):]],
        'checks':[name for name,_ in tests], 'validation_scopes':scopes,
        'selection':args.only or ('SHARDED_FULL_SUITE' if args.shard_count>1 else 'FULL_SUITE'),
        'plan':plan, 'synthetic_fixture_policy':'DISABLED' if args.no_ci_synthetic_fixtures else 'EXISTING_CI_AUTO'}
    (logs/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
write_summary()
for name,extra in tests:
    executed.append(name)
    source=root/'tests'/(name+'.gd')
    needs_draw=source.is_file() and requires_renderer(source.read_text(encoding='utf-8'),os.environ)
    # A headless RenderingServer never emits frame_post_draw. Historically
    # these tests silently ran for 150 seconds each before timing out.
    visual=needs_draw # Never block awaiting draw events under the headless renderer.
    # These historical tests assert literal pre-remake polygons, room IDs,
    # renderer node paths and authored blocker counts. Keep every assertion on
    # its actual fixture. A3 is independently exercised by the registered real
    # Main runtime, hunting/physics and population tests, never counted here.
    legacy_geometry=name in LEGACY_GEOMETRY_TESTS
    scopes[name]='EXISTING_TWILIGHT_GEOMETRY' if legacy_geometry else 'ACTIVE_INSTALLED_MAPS_OR_TEST_SPECIFIC_FIXTURE'
    display_args=['--rendering-driver','opengl3','--audio-driver','Dummy'] if visual else ['--headless']
    with tempfile.TemporaryDirectory(prefix='twilight-test-') as user_data:
        env=os.environ.copy()
        env['XDG_DATA_HOME']=user_data
        # Godot Windows uses APPDATA, not XDG_DATA_HOME. Every process, including
        # the PCK probe child, must inherit its own empty save/config directory.
        env['APPDATA']=user_data
        env['LOCALAPPDATA']=user_data
        if name.startswith('original_based_') or name == 'pr100_direction_gameplay_test':
            # Keep the real directional/lifecycle report after isolated saves
            # are cleaned up, including diagnostics from a failed CI case.
            env['TWILIGHT_PR100_REPORT']=str(logs/(name+'.gameplay.json'))
        if name == 'original_based_transform_temporal_main_test':
            # The runner already owns a fresh temporary Godot user directory.
            # Explicitly authorize this inherited full 10-case batch and keep
            # its separate case/report evidence outside the temporary home.
            env['TWILIGHT_PR100_BATCH_ISOLATED']='1'
            env['TWILIGHT_PR100_BATCH_REPORT']=str(logs/(name+'.batch.json'))
        if visual: env['LIBGL_ALWAYS_SOFTWARE']='1'
        try:
            budget=timeout_budget(name,args.timeout,args.import_timeout)
            command=[args.godot,*display_args,'--path',str(root),*extra]
            if legacy_geometry:
                command.extend(['--','--legacy-map-layouts'])
            if name=='world_regions_test':
                command=[sys.executable,str(root/'tools/world_region_shards.py'),'--godot',args.godot,
                         '--path',str(root),'--logs',str(logs/'world-region-shards'),
                         '--timeout',str(args.region_shard_timeout),'--legacy-map-layouts']
            if visual and sys.platform.startswith('linux') and not env.get('DISPLAY'):
                if not shutil.which('xvfb-run'):
                    raise RuntimeError('Visual test requires xvfb-run (or DISPLAY); never wait for frame_post_draw in headless mode')
                command=['xvfb-run','-a','-s','-screen 0 1280x720x24',*command]
            p=run_isolated(command,env=env,timeout=budget,cwd=str(root))
            output='VALIDATION_SCOPE '+scopes[name]+'\n'+p.stdout+p.stderr
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
            # Artifact delivery may fail independently of the test. Retain the
            # bounded failure detail in ordinary job logs as well as the file.
            print('FAILED_OUTPUT_BEGIN '+name+'\n'+output[-16000:]+'\nFAILED_OUTPUT_END '+name,flush=True)
            if name in ('import','bake_navigation'):
                # Do not manufacture unrelated failures after broken preparation.
                not_run=[remaining for remaining,_ in tests[len(executed):]]
                print('BLOCKED_BY_'+name.upper()+' '+str(len(not_run))+' checks',flush=True)
                write_summary()
                break
        write_summary()
passed=len(executed)-len(failed)-len(skipped)
print(f'{passed}/{len(tests)} checks passed; {len(skipped)} skipped; {len(not_run)} not run',flush=True)
write_summary()
raise SystemExit(bool(failed or not_run))
