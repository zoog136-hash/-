#!/usr/bin/env python3
"""Strict read-only source preflight and isolated actual Main E-gait preview."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import subprocess
import time

import numpy as np
from PIL import Image
import import_original_based_motion as motion


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--fixture', type=Path, default=Path('docs/remake/evidence/pr122-remaining106/batch07/reaper-male-E-preview.json'))
    parser.add_argument('--display', default=os.environ.get('DISPLAY', ''))
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    fixture_path = (root / args.fixture).resolve()
    assert fixture_path.is_relative_to(root)
    fixture = json.loads(fixture_path.read_text())
    assert fixture['prototype_only'] and not fixture['production_applied'] and not fixture['final_model_approval']
    assert fixture['selected_distinct_sources'] == 6 and len(fixture['frames']) == 6
    fingerprints = set()
    verified = []
    sheets = {}
    ownership = {}
    for spec in fixture.get('whole_source_sheets', []):
        assert spec['rows'] == 6 and spec['directions'] == ['E']
        source = root / spec['file'].removeprefix('res://')
        assert spec['file'] not in sheets and motion.sha(source) == spec['source_sha256']
        geometry = spec['geometry']
        actual = motion.analyze(source, rows_count=6, reference_rows=spec['reference_rows'],
            directions=['E'], canvas_size=geometry['canvas_size'][0],
            source_anchors=[frame['source_anchor'] for frame in geometry['frames']])
        motion.require_complete_pose_regions(source, actual)
        assert actual == geometry and len(actual['frames']) == 6
        sheets[spec['file']] = spec
        ownership[spec['file']] = set()
    for entry in fixture['frames']:
        source = root / entry['file'].removeprefix('res://')
        assert motion.sha(source) == entry['source_sha256']
        geometry = entry['geometry']
        frame = geometry['frames'][0]
        if entry['file'] in sheets:
            # The complete whole sheet was checked above. Every analyzed body
            # must occur exactly once; no omitted/excluded pieces or slots.
            sheet = sheets[entry['file']]
            row = entry['source_frame_row']
            assert row in range(6) and row not in ownership[entry['file']]
            ownership[entry['file']].add(row)
            assert entry['source_sha256'] == sheet['source_sha256']
            actual = {**sheet['geometry'], 'frames': [sheet['geometry']['frames'][row]],
                      'distinct_pixel_frames': 1}
        else:
            actual = motion.analyze(source, rows_count=1, reference_rows=[0], directions=['E'],
                canvas_size=geometry['canvas_size'][0], source_anchors=[frame['source_anchor']])
            motion.require_complete_pose_regions(source, actual)
        assert actual == geometry
        x, y, width, height = frame['region']
        with Image.open(source) as image:
            fingerprint = motion._visible_pose_fingerprint(np.asarray(image)[y:y+height, x:x+width])
        assert fingerprint == entry['visible_pixel_fingerprint'] and fingerprint not in fingerprints
        fingerprints.add(fingerprint)
        verified.append({'file': entry['file'], 'sha256': motion.sha(source),
                         'bytes': source.stat().st_size, 'strict_geometry': 'PASS'})
    assert all(rows == set(range(6)) for rows in ownership.values())
    (output / 'source-preflight.json').write_text(json.dumps({'sources': verified, 'distinct_visible_sources': 6,
        'source_pixels_changed': False, 'final_semantic_gait_approval': False}, indent=2) + '\n')
    version = subprocess.check_output([str(args.godot), '--version'], text=True).strip()
    assert version.startswith('4.7.2.stable.'), version
    env = os.environ.copy()
    env.update({'DISPLAY': args.display, 'LIBGL_ALWAYS_SOFTWARE': '1',
        'XDG_DATA_HOME': str(output / 'user'), 'XDG_CONFIG_HOME': str(output / 'config'),
        'XDG_CACHE_HOME': str(output / 'cache'), 'TWILIGHT_PR122_GAIT_ISOLATED': '1',
        'TWILIGHT_PR122_GAIT_REPORT': str(output / 'report.json'),
        'TWILIGHT_PR122_GAIT_FIXTURE': 'res://' + str(fixture_path.relative_to(root)),
        'TWILIGHT_PR122_GAIT_CAPTURE_DIR': str(output / 'captures')})
    for name in ('user', 'config', 'cache'):
        (output / name).mkdir()
    command = [str(args.godot), '--path', str(root), '--rendering-driver', 'opengl3',
               '--audio-driver', 'Dummy', '--script', 'res://tests/pr122_reaper_locomotion_source_preview.gd']
    start = time.monotonic()
    print('START_PR122_GAIT_SOURCE_PREVIEW', flush=True)
    with (output / 'run.log').open('x') as log:
        try:
            returncode = subprocess.run(command, cwd=root, env=env, stdout=log,
                stderr=subprocess.STDOUT, timeout=600).returncode
        except subprocess.TimeoutExpired:
            returncode = 124
    receipt = {'returncode': returncode, 'engine': version, 'seconds': time.monotonic() - start,
        'command': command, 'child_max_RSS_KiB': resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
        'VRAM': 'NOT_MEASURED', 'Android_real_device': 'NOT_RUN', 'completed_added': 0}
    (output / 'process-result.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt), flush=True)
    if returncode:
        print((output / 'run.log').read_text()[-10000:], flush=True)
        raise SystemExit(returncode)
    report = json.loads((output / 'report.json').read_text())
    assert not report['failures']
    preview = report['source_preview']
    assert preview['prototype_only'] and not preview['production_applied'] and preview['completed_added'] == 0
    assert len(preview['modes']) == 6
    for item in preview['modes']:
        expected = preview['baseline_frames'] if item['mode'].startswith('original') else 6
        assert item['frames'] == expected and len(item['captures']) == expected
        assert set(item['native_sequence']) == set(range(expected))
    assert preview['actual_input']['observed_native_frames'] == 6
    assert len(preview['actual_input']['captures']) == 6
    captures = []
    for path in sorted((output / 'captures').glob('*.png')):
        captures.append({'path': str(path), 'bytes': path.stat().st_size,
                         'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    validation = {'technical_preview': 'PASS', 'checks': report['checks'], 'failures': [],
        'source_candidates': 6, 'speeds': [0.75, 1.0, 1.5], 'actual_keyboard_native_frames': 6,
        'actual_keyboard_displacement': preview['actual_input']['displacement'],
        'captures': captures, 'final_visual_quality': preview['visual_quality'],
        'production_applied': False, 'completed_added': 0, 'Android_real_device': 'NOT_RUN'}
    (output / 'validation.json').write_text(json.dumps(validation, indent=2) + '\n')
    print('PR122_GAIT_SOURCE_PREVIEW_TECHNICAL_PASS ' + json.dumps({
        key: value for key, value in validation.items() if key != 'captures'}), flush=True)


if __name__ == '__main__':
    main()
