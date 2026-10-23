#!/usr/bin/env python3
"""Run bounded, normal-speed boss arena QA without changing game catalogs."""
import argparse
from copy import deepcopy
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
GODOT = Path('/workspace/runtime/bin/Godot_v4.7.2-stable_linux.x86_64')
COMPASS = ('E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE')


def monsters():
    db = json.loads((ROOT / 'data/monsters/monster_world_catalog.json').read_text())
    result = {}
    for raw in json.loads((ROOT / 'data/game_db_v17.json').read_text())['몬스터']:
        row = deepcopy(raw)
        row.update(db['overlays'].get(row['name'], {}))
        result[row['name']] = row
    for patch in db['additions']:
        if patch['name'] in result:
            continue
        row = deepcopy(result.get(patch.get('template', '해골 근위병'), {}))
        row.update(patch)
        result[row['name']] = row
    return result


def config_case(raw, records, args):
    key = raw.get('key', args.key)
    path = raw.get('native_profile', args.profile)
    if not key or not path:
        raise ValueError('Each case needs key and native_profile')
    path = str(path)
    if path.startswith(str(ROOT) + '/'):
        path = 'res://' + Path(path).relative_to(ROOT).as_posix()
    elif not path.startswith('res://'):
        path = 'res://' + path
    if not (ROOT / path.removeprefix('res://')).is_file():
        raise ValueError('Candidate native profile is not present: ' + path)
    directions = raw.get('directions', args.directions.split(','))
    roles = raw.get('roles', args.roles.split(','))
    if any(d not in COMPASS for d in directions) or any(r not in ('idle', 'run', 'attack', 'hit', 'death') for r in roles):
        raise ValueError('Invalid direction or role')
    source = records[key.removeprefix('monster:')]
    return dict(key=key, native_profile=path, slug=raw.get('slug', re.sub(r'[^a-zA-Z0-9_-]', '_', key)),
        directions=directions, roles=roles,
        move_speed=float(raw.get('move_speed', source.get('speed', 124.0))),
        attack_seconds=float(raw.get('attack_seconds', source.get('attack_interval', 1.2))),
        attack_range=float(raw.get('attack_range', source.get('attack_range', 58.0))),
        run_seconds=float(raw.get('run_seconds', args.run_seconds)),
        idle_seconds=float(raw.get('idle_seconds', args.idle_seconds)))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--key')
    parser.add_argument('--profile')
    parser.add_argument('--case-file', type=Path, help='JSON list, or {cases:[...]}, of case overrides')
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--render', action='store_true', help='Real X11/OpenGL viewport PNGs; otherwise headless diagnostics only')
    parser.add_argument('--directions', default='E,S', help='Comma separated; use E,SE,S,SW,W,NW,N,NE for all eight')
    parser.add_argument('--roles', default='idle,run,attack,hit,death')
    parser.add_argument('--run-seconds', type=float, default=1.8)
    parser.add_argument('--idle-seconds', type=float, default=1.4)
    parser.add_argument('--timeout', type=int, default=420)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    records = monsters()
    raw = json.loads(args.case_file.read_text()) if args.case_file else [{}]
    if isinstance(raw, dict):
        raw = raw['cases']
    cases = [config_case(item, records, args) for item in raw]
    if len({case['slug'] for case in cases}) != len(cases):
        raise ValueError('Every case needs a unique ASCII slug')
    config = dict(cases=cases, output=str(out), capture=args.render)
    config_path = out / 'config.json'
    config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + '\n')
    project = out / 'project'
    project.mkdir()
    (project / 'project.godot').write_text('[application]\nconfig/name="TWILIGHT boss real-speed diagnostic arena"\n[display]\nwindow/size/viewport_width=960\nwindow/size/viewport_height=640\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    for name in ('data', 'scripts', 'assets', 'docs'):
        (project / name).symlink_to(ROOT / name, target_is_directory=True)
    env = os.environ.copy()
    for name in ('DATA', 'CONFIG', 'CACHE'):
        path = out / 'user' / name.lower()
        path.mkdir(parents=True)
        env['XDG_' + name + '_HOME'] = str(path)
    env['BOSS_FIX_QA_CONFIG'] = str(config_path)
    command = [str(GODOT), '--path', str(project), '--audio-driver', 'Dummy', '--script',
               'res://' + (HERE / 'arena.gd').relative_to(ROOT).as_posix()]
    server = None
    display_log = None
    try:
        if args.render:
            executable = shutil.which('Xvfb') or '/workspace/runtime/boss-qa-xvfb/unpacked/usr/bin/Xvfb'
            if not Path(executable).is_file():
                raise RuntimeError('Xvfb unavailable. Supply an Xvfb binary or use headless diagnostics without --render.')
            Path('/tmp/.X11-unix').mkdir(exist_ok=True)
            display = next(i for i in range(117, 130) if not Path('/tmp/.X11-unix/X' + str(i)).exists())
            display_log = (out / 'xvfb-run.txt').open('w')
            server = subprocess.Popen([executable, ':' + str(display), '-screen', '0', '960x640x24',
                '-nolisten', 'tcp', '-ac', '-noreset'], stdout=display_log, stderr=subprocess.STDOUT)
            for _ in range(50):
                if Path('/tmp/.X11-unix/X' + str(display)).exists():
                    break
                if server.poll() is not None:
                    raise RuntimeError('Xvfb stopped before display startup; see xvfb-run.txt')
                time.sleep(.1)
            else:
                raise RuntimeError('Xvfb display readiness timed out')
            env.update(DISPLAY=':' + str(display), LIBGL_ALWAYS_SOFTWARE='1')
            command += ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3']
        else:
            command += ['--headless']
        (out / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
        started = time.monotonic()
        with (out / 'godot-run.txt').open('w') as log:
            process = subprocess.run(command, env=env, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=args.timeout)
        text = (out / 'godot-run.txt').read_text(errors='replace')
        status = dict(returncode=process.returncode, elapsed_seconds=time.monotonic() - started,
            render_requested=args.render, speed_scale=1.0, simulation_dt=1 / 60,
            script_errors=any(marker in text for marker in ('SCRIPT ERROR:', 'Parse Error:', 'ERROR:')),
            Main_scene_validation=False, quality_approval_changes=0)
        (out / 'process.json').write_text(json.dumps(status, indent=2) + '\n')
        if process.returncode or status['script_errors'] or not (out / 'report.json').is_file():
            raise RuntimeError('QA run did not complete cleanly; see process.json/godot-run.txt')
        report = json.loads((out / 'report.json').read_text())
        files = []
        for case in report['cases']:
            for path in sorted((out / Path(case['samples_file']).parent.name).glob('captures/*.png')):
                files.append(dict(path=str(path), bytes=path.stat().st_size, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        (out / 'capture-manifest.json').write_text(json.dumps({'files': files}, indent=2) + '\n')
        print(json.dumps(dict(cases=len(report['cases']), captures=len(files), renderer=report['video_adapter'],
            speed_scale=1, Main=False, report=str(out / 'report.json')), ensure_ascii=False))
    finally:
        if server is not None:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
        if display_log is not None:
            display_log.close()


if __name__ == '__main__':
    main()
