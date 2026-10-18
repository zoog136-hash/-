#!/usr/bin/env python3
"""Verify the existing private source kit and preview native ticks in real Main.

The source kit and every rendered pixel stay outside the public checkout. This
does not install an actor, identify a transform, or grant an animation approval.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time
import zipfile

from PIL import Image

KIT_SHA = '99dd0cb2f02da039b56923b9f3b947ed7ef4f73843d7f4e0c0dcdd7006b98a98'
ACTION_SHA = '95b1afb8dc04c21075359026a6a42a99e109c96cd745c418e7014476cc35b84e'
ROLES = {'idle': '86', 'walk': '83', 'run': '83-1', 'run_right': '83-2',
         'attack': '84', 'hit': '85', 'death': '8', 'cast': '18', 'special': '87'}
# Prior optional-body builder's mapping, still a candidate awaiting visual review.
DIRECTION_MAP = [6, 5, 4, 3, 2, 1, 0, 7]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--source-kit', type=Path, required=True)
    parser.add_argument('--source-zip', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--display', default=os.environ.get('DISPLAY', ':99'))
    parser.add_argument('--actors', nargs='+', choices=('21624', '21653'), default=['21624', '21653'])
    parser.add_argument('--directions', nargs='+', type=int, choices=range(8), default=list(range(8)))
    parser.add_argument('--roles', nargs='+', choices=tuple(ROLES), default=list(ROLES))
    parser.add_argument('--preflight-only', action='store_true',
                        help='Verify sources without starting Godot; never a Main PASS')
    args = parser.parse_args()
    assert len(args.actors) == len(set(args.actors)) and len(args.directions) == len(set(args.directions))
    assert len(args.roles) == len(set(args.roles))
    root, source, output = args.root.resolve(), args.source_kit.resolve(), args.output.resolve()
    assert not source.is_relative_to(root) and not output.is_relative_to(root), 'Private art must stay outside public checkout'
    assert sha(args.source_zip) == KIT_SHA, 'Wrong or changed source kit'
    with zipfile.ZipFile(args.source_zip) as archive:
        assert archive.testzip() is None, 'Source ZIP CRC failure'
        verified_members = 0
        for member in archive.infolist():
            if member.is_dir():
                continue
            path = (source / member.filename).resolve()
            assert path.is_relative_to(source) and path.is_file(), 'Missing/unsafe extracted source'
            assert path.read_bytes() == archive.read(member), 'Extracted source differs from pinned ZIP: ' + member.filename
            verified_members += 1
    output.mkdir(parents=True, exist_ok=False)
    originals = []
    for item in json.loads((source / 'SHA256_manifest.json').read_text()):
        path = (source / item['path']).resolve()
        assert path.is_relative_to(source) and path.is_file()
        assert path.stat().st_size == item['bytes'] and sha(path) == item['sha256'], item['path']
        originals.append({'path': item['path'], 'bytes': item['bytes'], 'sha256': item['sha256']})
    manifest_path = source / 'motion_proof/manifest.json'
    manifest = json.loads(manifest_path.read_text())
    assert manifest['source_action_sha256'] == ACTION_SHA
    result = {'schema': 1, 'prototype_only': True, 'production_applied': False,
              'target_identity': 'UNMAPPED', 'completed_added': 0,
              'source_kit_sha256': KIT_SHA, 'source_action_sha256': ACTION_SHA,
              'source_manifest_sha256': sha(manifest_path),
              'pinned_ZIP_extracted_members_verified': verified_members,
              'direction_map_candidate': DIRECTION_MAP,
              'direction_mapping_final_approval': False,
              'foot_source_candidate': [72, 30], 'foot_final_approval': False,
              'preview_ticks_per_second': 24, 'native_client_tick_rate_verified': False,
              'playback_ratios': [0.75, 1.0, 1.5], 'directions': args.directions,
              'public_artifacts_allowed': False, 'Android_real_device': 'NOT_RUN',
              'actors': {}, 'sources': originals}
    reconstructed = 0
    for actor_id in args.actors:
        actor = manifest['actors'][actor_id]
        for direction in range(8):
            gait_sets = []
            for action_id in ('83', '83-1', '83-2'):
                gait_sets.append({actor['frames'][str(entry['sequence_base'] + direction) + '/' +
                                  str(entry['frame'])]['rgba_sha256']
                                  for entry in actor['actions'][action_id]['frames']})
            assert all(len(fingerprints) == 8 for fingerprints in gait_sets), 'Eight real gait poses required'
            assert not (gait_sets[0] & gait_sets[1] or gait_sets[0] & gait_sets[2] or gait_sets[1] & gait_sets[2]), 'Walk/run sources must differ'
        folder = source / 'motion_proof/actors' / actor_id
        atlas_images = [Image.open(folder / name).convert('RGBA') for name in actor['atlases']]
        # Full-body RGBA, including restored transparent padding, not crop hashes.
        for frame in actor['frames'].values():
            x, y, w, h = frame['rect']
            crop = atlas_images[frame['page']].crop((x, y, x + w, y + h))
            restored = Image.new('RGBA', tuple(frame['original_size']))
            restored.paste(crop, tuple(frame['alpha_crop'][:2]))
            assert hashlib.sha256(restored.tobytes()).hexdigest() == frame['rgba_sha256']
            reconstructed += 1
        tracks = {}
        for role in args.roles:
            action_id = ROLES[role]
            action = actor['actions'][action_id]
            assert action['directional'] and sum(f['ticks'] for f in action['frames']) == action['total_ticks']
            for direction in args.directions:
                frames = []
                for phase, entry in enumerate(action['frames']):
                    assert type(entry['ticks']) is int and entry['ticks'] > 0
                    sequence = entry['sequence_base'] + DIRECTION_MAP[direction]
                    key = str(sequence) + '/' + str(entry['frame'])
                    frame = actor['frames'][key]
                    frames.append({**frame, 'native_key': key, 'phase': phase,
                                   'ticks': entry['ticks'], 'hit_marker': entry['hit_marker'],
                                   'raw_token': entry['raw_token']})
                tracks[role + '_' + str(direction)] = {
                    'role': role, 'direction': direction, 'source_direction': DIRECTION_MAP[direction],
                    'source_action': action_id, 'source_name': action['source_name'],
                    'total_ticks': action['total_ticks'], 'frames': frames,
                    'distinct_source_RGBA': len({frame['rgba_sha256'] for frame in frames})}
        reference = actor['actions']['86']['frames']
        reference_height = max(actor['frames'][str(f['sequence_base'] + DIRECTION_MAP[2]) + '/' + str(f['frame'])]['rect'][3]
                               for f in reference)
        result['actors'][actor_id] = {'source_header': actor['source_header'],
            'source_bounds': actor['source_bounds'], 'reference_height': reference_height,
            'atlas_paths': [str(folder / name) for name in actor['atlases']],
            'atlas_SHA256': [sha(folder / name) for name in actor['atlases']], 'tracks': tracks}
    result['source_RGBA_reconstructed_and_verified'] = reconstructed
    fixture = output / 'private-preview.json'
    fixture.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    if args.preflight_only:
        preflight = {'source_preflight': 'PASS', 'pinned_ZIP_members': verified_members,
                     'source_RGBA_verified': reconstructed, 'walk_run_disjoint': True,
                     'Main': 'NOT_RUN', 'completed_added': 0, 'production_applied': False}
        (output / 'preflight-result.json').write_text(json.dumps(preflight, indent=2) + '\n')
        print(json.dumps(preflight))
        return
    tested_sources = {str(path.relative_to(root)): sha(path) for path in
                     (Path(__file__).resolve(), root / 'tests/pr122_native_tick_source_preview.gd')}
    env = os.environ.copy()
    env.update({'DISPLAY': args.display, 'LIBGL_ALWAYS_SOFTWARE': '1',
                'TWILIGHT_PR122_NATIVE_FIXTURE': str(fixture),
                'TWILIGHT_PR122_NATIVE_OUTPUT': str(output)})
    for key, name in [('XDG_DATA_HOME', 'user'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
        path = output / name
        path.mkdir()
        env[key] = str(path)
    version = subprocess.check_output([str(args.godot), '--version'], text=True, env=env).strip()
    assert version.startswith('4.7.2.stable.'), version
    command = [str(args.godot), '--path', str(root), '--rendering-driver', 'opengl3',
               '--audio-driver', 'Dummy', '--script', 'res://tests/pr122_native_tick_source_preview.gd']
    start = time.monotonic()
    print('NATIVE_SOURCE_PREFLIGHT_OK RGBA=' + str(reconstructed), flush=True)
    with (output / 'process.log').open('x') as log:
        try:
            status = subprocess.run(command, cwd=root, env=env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=1800).returncode
        except subprocess.TimeoutExpired:
            status = 124
    receipt = {'engine': version, 'returncode': status, 'seconds': time.monotonic() - start,
               'source_kit_sha256': KIT_SHA, 'source_RGBA_verified': reconstructed,
               'art_and_Main_pixels_private': True, 'production_applied': False,
               'target_identity': 'UNMAPPED', 'completed_added': 0, 'Android_real_device': 'NOT_RUN',
               'tested_source_SHA256': tested_sources,
               'tested_sources_unchanged': all(sha(root / path) == digest for path, digest in tested_sources.items())}
    (output / 'process-result.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt), flush=True)
    if status:
        print((output / 'process.log').read_text()[-6000:], flush=True)
        raise SystemExit(status)
    report = json.loads((output / 'report.json').read_text())
    assert receipt['tested_sources_unchanged']
    assert report['checks'] > 0 and not report['failures']
    assert len(report['actors']) == len(args.actors)
    print('NATIVE_MAIN_TECHNICAL_PREVIEW_PASS ' + str(report['checks']), flush=True)


if __name__ == '__main__':
    main()
