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
from test_project_support import classify_result, requires_renderer, run_isolated, timeout_budget, LEGACY_GEOMETRY_TESTS

parser=argparse.ArgumentParser()
parser.add_argument('--godot',default='godot')
parser.add_argument('--logs',default='test-results')
parser.add_argument('--render-visual-tests',action='store_true',help='Compatibility flag: frame-dependent tests always use a real renderer')
parser.add_argument('--timeout',type=int,default=150,help='Per-test seconds; regional map audits run in five independently timed shards')
parser.add_argument('--import-timeout',type=int,default=900,help='One-time complete Godot asset import deadline in seconds')
parser.add_argument('--region-shard-timeout',type=int,default=360,help='Seconds per world family; all five families mandatory')
parser.add_argument('--only',default='',help='Comma-separated exact test names for targeted rechecks; omitted runs the full suite')
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
if args.only:
    selected=set(args.only.split(','))
    unknown=selected-{name for name,_ in tests}
    if unknown: parser.error('Unknown tests: '+', '.join(sorted(unknown)))
    tests=[test for test in tests if test[0] in selected]
failed=[]
skipped=[]
executed=[]
not_run=[]
scopes={}
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
        env['XDG_CONFIG_HOME']=str(Path(user_data)/'config')
        env['XDG_CACHE_HOME']=str(Path(user_data)/'cache')
        # Godot Windows uses APPDATA, not XDG_DATA_HOME. Every process, including
        # the PCK probe child, must inherit its own empty save/config directory.
        env['APPDATA']=user_data
        env['LOCALAPPDATA']=user_data
        if name.startswith('original_based_') or name == 'pr100_direction_gameplay_test':
            # Keep the real directional/lifecycle report after isolated saves
            # are cleaned up, including diagnostics from a failed CI case.
            env['TWILIGHT_PR100_REPORT']=str(logs/(name+'.gameplay.json'))
        if name == 'original_based_transform_temporal_main_test':
            # The inherited batch refuses a non-isolated caller. This runner
            # has just allocated its fresh save directory; keep the unchanged
            # complete fixture and preserve its report outside that directory.
            env['TWILIGHT_PR100_BATCH_ISOLATED']='1'
            env['TWILIGHT_PR100_BATCH_CONFIG']='res://tests/fixtures/pr100_transform_regression.json'
