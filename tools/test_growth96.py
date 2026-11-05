#!/usr/bin/env python3
"""Run growth rewards against the complete private input and actual Main.

Use a current ci_core.py --prepare-only stage. Every save is isolated, retained
under the requested log directory, and never points at a player's profile.
"""
import argparse
import os
from pathlib import Path
import shutil
import tempfile

from ci_core import run
from audit_growth96_source import audit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--project', required=True, type=Path)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--logs', required=True, type=Path)
    parser.add_argument('--render', action='store_true', help='Use the configured display instead of headless rendering.')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    project, logs = args.project.resolve(), args.logs.resolve()
    if logs.is_relative_to(root) or project == root:
        raise ValueError('Use a disposable project and private logs outside the Git worktree.')
    logs.mkdir(parents=True, exist_ok=True)
    coverage = audit(args.source)['coverage']
    for folder in ['scripts/progression', 'scripts/growth', 'scripts/ui']:
        for source in (root / folder).glob('*.gd'):
            target = project / source.relative_to(root)
            if not target.is_file() or source.read_bytes() != target.read_bytes():
                raise ValueError('The Main stage is stale: ' + str(source.relative_to(root)))
    if (root / 'scripts/world.gd').read_bytes() != (project / 'scripts/world.gd').read_bytes():
        raise ValueError('The Main stage has a different world.gd.')
    for name in ['growth96_runtime_test', 'growth96_main_ui_test', 'qa_class_selection']:
        shutil.copy2(root / ('tests/' + name + '.gd'), project / ('tests/' + name + '.gd'))
    profile = Path(tempfile.mkdtemp(prefix='isolated-growth96-', dir=logs))
    env = os.environ.copy()
    env.pop('TWILIGHT_PATCH523_CONTENT', None)
    env.update(XDG_DATA_HOME=str(profile / 'data'), XDG_CONFIG_HOME=str(profile / 'config'),
               XDG_CACHE_HOME=str(profile / 'cache'), TWILIGHT_GROWTH96_TEST_ROOT=str(profile / 'data'),
               TWILIGHT_GROWTH96_INPUT=str(args.source.resolve()), TWILIGHT_GROWTH96_EVIDENCE=str(profile / 'screenshots'))
    if not env.get('TWILIGHT_SOURCE_MAP_PACK'):
        raise ValueError('The actual current source-map pack is required.')
    base = [args.godot, '--audio-driver', 'Dummy', '--path', str(project)]
    run(base + ['--headless', '--editor', '--import', '--quit'], project, logs / 'import.log', env, 1800)
    unit = profile / 'unit'
    for path in ['scripts/progression/growth96_source.gd', 'scripts/progression/growth96_runtime.gd',
                 'scripts/skills/save_writer.gd', 'tests/growth96_runtime_test.gd']:
        target = unit / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / path, target)
    (unit / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Growth96 isolated rules"\n')
    unit_env = {**env, 'TWILIGHT_PATCH523_CONTENT': str(args.source.resolve())}
    run([args.godot, '--headless', '--audio-driver', 'Dummy', '--path', str(unit), '--script',
         'res://tests/growth96_runtime_test.gd'], unit, logs / 'runtime.log', unit_env, 240, 'GROWTH96_RUNTIME_RESULT')
    command = base + ([] if args.render else ['--headless']) + ['--script', 'res://tests/growth96_main_ui_test.gd']
    run(command, project, logs / 'main-ui.log', env, 300, 'GROWTH96_MAIN_RESULT')
    run(command + ['--', '--cold-reload'], project, logs / 'cold-reload.log', env, 180, 'GROWTH96_MAIN_RESULT')
    print('GROWTH96_CHECKS_OK', coverage, 'isolated evidence:', profile)


if __name__ == '__main__':
    main()
