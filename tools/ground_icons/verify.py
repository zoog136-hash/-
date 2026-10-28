#!/usr/bin/env python3
"""Read-only Godot validation of committed ground-category art and real drops.

Initial before/after inventory-pixel evidence is preserved in
 docs/verification/ground_categories_20261015.json. This runner never installs
patches, changes source images, writes gameplay files, or pushes Git commits.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from test_project_support import run_isolated, timeout_budget

ROOT = Path(__file__).resolve().parents[2]

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--import-timeout', type=int, default=1800,
                        help='Bound the one-time full Godot import in seconds')
    args = parser.parse_args()
    engine = str(Path(args.godot).resolve())
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    os.chdir(ROOT)
    from build import build
    build(write=False)
    protected = ['scripts/world.gd', 'scripts/player.gd',
        'scripts/ui/inven_inventory_icons.gd', 'scripts/ui/item_visual.gd',
        'data/game_db_v17.json', 'data/catalog_v19.json',
        'data/inven_inventory_icons.json', 'data/l1j/live_visual_bindings.json',
        'data/visuals/runtime_manifest.json']
    protected += [str(path) for path in Path('scripts/loot').glob('*.gd')]
    def source_hashes() -> dict[str,str]:
        return {path: hashlib.sha256(Path(path).read_bytes()).hexdigest() for path in protected}
    original_hashes = source_hashes()
    summary = []
    def run(label: str, script: str | None = None, render: bool = False, importing: bool = False) -> bool:
        env = dict(os.environ, GODOT_SILENCE_ROOT_WARNING='1',
            XDG_DATA_HOME=str(output/'user-data'/label), GROUND_STAGE='after',
            GROUND_REPORT=str(output/'after-probe.json'),
            GROUND_CAPTURES=str(output/'after-captures'))
        command = [engine, '--audio-driver', 'Dummy', '--path', '.']
        if importing:
            command += ['--headless', '--editor', '--import']
        elif render:
            command = ['xvfb-run', '-a'] + command + ['--rendering-method', 'gl_compatibility', '--script', 'res://tests/'+str(script)+'.gd']
        else:
            command += ['--headless', '--script', 'res://tests/'+str(script)+'.gd']
        try:
            budget = timeout_budget('import' if importing else (script or ''), 240, args.import_timeout)
            result = run_isolated(command, env=env, timeout=budget, cwd=str(ROOT))
            text, code = result.stdout + result.stderr, result.returncode
        except subprocess.TimeoutExpired as exc:
            text = exc.stdout.decode('utf-8', 'replace') if isinstance(exc.stdout, bytes) else exc.stdout or ''
            text += exc.stderr.decode('utf-8', 'replace') if isinstance(exc.stderr, bytes) else exc.stderr or ''
            text += '\nTIMEOUT\n'
            code = 124
        (output/(label+'.log')).write_text(text, encoding='utf-8')
        ok = code == 0 and not re.search(r'SCRIPT ERROR|Parse Error|Failed to load script|ERROR:', text)
        summary.append({'test': label, 'ok': ok, 'exit_code': code})
        (output/'test-summary.json').write_text(json.dumps(summary, indent=2)+'\n', encoding='utf-8')
        print(label, 'PASS' if ok else 'FAIL', flush=True)
        print('\n'.join(text.splitlines()[-12:]), flush=True)
        return ok
    if not run('import', importing=True):
        return 1
    run('ground-category-probe', 'ground_category_probe')
    for test in ['inven_inventory_icons_test', 'item_visual_test', 'ground_drop_smoke_test',
        'ground_loot_system_test', 'remake_ui_local_item_icons_test',
        'ui_stage4_item_instance_test', 'original_skill_warehouse_migration_test']:
        run(test, test)
    for test in ['aden_ground_continuity_test', 'eight_interactions_test']:
        run(test, test, render=True)
    run('capture-ground-categories', 'capture_ground_categories', render=True)
    if source_hashes() != original_hashes:
        raise RuntimeError('Protected name/effect/loot/inventory/gameplay files changed')
    (output/'protected-files.json').write_text(json.dumps(original_hashes, indent=2)+'\n', encoding='utf-8')
    return 0 if all(entry['ok'] for entry in summary) else 1

if __name__ == '__main__':
    raise SystemExit(main())
