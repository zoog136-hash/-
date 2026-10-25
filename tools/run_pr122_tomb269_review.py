#!/usr/bin/env python3
"""Run restored, unapproved Tomb269 in actual Main/OpenGL with fresh saves."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import time

from test_project_support import classify_result


def run(project, fixture, output, engine, timeout):
    if (project / '.git').exists() or project == Path(__file__).resolve().parents[1]:
        raise ValueError('Use a separate non-Git Main copy with a staged unapproved trial')
    if not os.environ.get('DISPLAY'):
        raise ValueError('A real OpenGL display is required, e.g. xvfb-run')
    output.mkdir(parents=True, exist_ok=False)
    platform = output / 'platform'
    for name in ['data', 'config', 'cache']:
        (platform / name).mkdir(parents=True)
    selected = {'DISPLAY': os.environ['DISPLAY'], 'LIBGL_ALWAYS_SOFTWARE': '1',
                'XDG_DATA_HOME': str(platform / 'data'), 'APPDATA': str(platform / 'data'),
                'LOCALAPPDATA': str(platform / 'data'), 'XDG_CONFIG_HOME': str(platform / 'config'),
                'XDG_CACHE_HOME': str(platform / 'cache'), 'TWILIGHT_PR100_BATCH_ISOLATED': '1',
                'TWILIGHT_PR100_BATCH_CONFIG': fixture,
                'TWILIGHT_PR100_BATCH_REPORT': str(output / 'report.json'),
                'TWILIGHT_PR100_BATCH_CAPTURE_DIR': str(output / 'captures')}
    command = [str(engine), '--path', str(project), '--rendering-method', 'gl_compatibility',
               '--audio-driver', 'Dummy', '--script', 'res://tests/pr122_tomb269_baseline_visual_review.gd']
    (output / 'invocation.json').write_text(json.dumps({'args': command, 'env': selected}, indent=2) + '\n')
    env = os.environ.copy()
    env.update(selected)
    start = time.monotonic()
    with (output / 'run.log').open('w') as log:
        process = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
    (output / 'process-result.json').write_text(json.dumps({
        'returncode': process.returncode, 'wall_seconds': time.monotonic() - start,
        'child_max_RSS_KiB': resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
        'VRAM': 'NOT_MEASURED', 'Android_real_device': 'NOT_RUN'}, indent=2) + '\n')
    verify(output)


def verify(output):
    process = json.loads((output / 'process-result.json').read_text())
    log = (output / 'run.log').read_text()
    if classify_result('pr122_tomb269', process['returncode'], log) != (True, False):
        raise RuntimeError('Actual Main failed; original log/report/captures retained in ' + str(output))
    summary = json.loads((output / 'report.json').read_text())
    assert summary['failures'] == [] and summary['checks'] > 0 and len(summary['cases']) == 1
    case = summary['cases'][0]
    assert case['transform_id'] == '269' and case['pose_samples'] == 112 and case['failures'] == []
    detail_path = Path(case['report']).resolve()
    assert detail_path.is_relative_to(output)
    detail = json.loads(detail_path.read_text())
    assert detail['failures'] == [] and len(detail['player']) == len(detail['monster']) == 8
    assert detail['transform_temporal']['native_phases'] == detail['transform_temporal']['rendered_native_phases'] == 112
    assert detail['lifecycle']['manual_pickup'] and detail['lifecycle']['death_callbacks'] == 1
    events = {e['name']: e for e in detail['remaining106_player_visual']['events']}
    for direction in ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']:
        assert events['actual-player-' + direction + '-contact']['state']['frame'] == 1
    probe = detail['pr122_tomb269_smaller_target']
    assert probe['real_hit_count'] == 1 and probe['actual_hp_delta'] > 0
    assert probe['attack_phase1_captured'] and probe['real_damage_contact_captured']
    assert probe['unchanged_original_8_direction_cases'] and not probe['source_approved']
    samples = detail['pr122_tomb269_completed_baseline']['samples']
    assert len(samples) == 40 and all(s['player_base_scale'][0] > 0 for s in samples)
    files = []
    capture_root = output / 'captures' / case['slug']
    for name in detail['screenshots']:
        path = (capture_root / name).resolve()
        assert path.is_relative_to(capture_root) and path.is_file()
        files.append({'path': str(path.relative_to(output)), 'bytes': path.stat().st_size,
                      'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    for entry in [*events.values(), *samples]:
        path = Path(entry['path']).resolve()
        assert path.is_relative_to(capture_root) and hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256']
    result = {'status': 'AUTOMATIC_MAIN_PASS_VISUAL_REVIEW_REQUIRED', 'checks': summary['checks'],
              'native_phases': 112, 'original_contacts': 8, 'extra_SW_real_hits': 1,
              'baseline_samples': 40, 'PNG_files': files, 'completed_added': 0,
              'production_applied': False, 'Android_real_device': 'NOT_RUN'}
    manifest = output / 'delivery-manifest.json'
    if manifest.exists():
        assert json.loads(manifest.read_text()) == result
    else:
        manifest.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'PNG_files'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path)
    parser.add_argument('--fixture')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--godot', type=Path)
    parser.add_argument('--verify-existing', type=Path, help='Verify a completed immutable run without launching it again')
    parser.add_argument('--timeout', type=int, default=1200)
    args = parser.parse_args()
    if args.verify_existing:
        verify(args.verify_existing.resolve())
    else:
        if not all([args.project, args.fixture, args.output, args.godot]):
            parser.error('New runs require --project, --fixture, --output and --godot')
        run(args.project.resolve(), args.fixture, args.output.resolve(), args.godot.resolve(), args.timeout)
