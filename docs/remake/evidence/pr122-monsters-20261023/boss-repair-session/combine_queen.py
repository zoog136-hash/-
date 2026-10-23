#!/usr/bin/env python3
"""Compose two frozen Ice Queen inputs without changing their pixels/geometry."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[5]
BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools'))
from build_pr122_monster_batch import frames_bytes

KEY = 'monster:얼음 여왕'
DIRS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']
RUN_PATH = BASE.parent / 'boss-fix01-queen/candidate.json'
COMBAT_PATH = BASE.parent / 'boss-fix05-queen-combat/candidate.json'
OUT = ROOT / 'assets/actors/eight_direction/monster_boss_repair/ice_queen/combined-r001'
CANDIDATE = BASE / 'queen-combined-candidate.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rel(path):
    return path.resolve().relative_to(ROOT).as_posix()


def local(value):
    value = str(value).removeprefix('res://')
    path = (ROOT / value).resolve()
    path.relative_to(ROOT)
    return path


def pin(path):
    return {'path': rel(path), 'bytes': path.stat().st_size, 'sha256': sha(path)}


def checked_manifest(path, expected_sha):
    path = local(path)
    assert re.fullmatch('[0-9a-f]{64}', expected_sha), 'Expected an exact frozen manifest SHA-256'
    assert sha(path) == expected_sha, f'Input manifest changed after freeze: {path}'
    value = json.loads(path.read_text())
    files = value['files']
    assert isinstance(files, list) and files
    pinned = {}
    for row in files:
        member = local(row['path'])
        assert member.is_file(), f'Frozen input file absent: {member}'
        assert sha(member) == row['sha256'], f'Frozen input SHA mismatch: {member}'
        if 'bytes' in row:
            assert member.stat().st_size == row['bytes'], f'Frozen input size mismatch: {member}'
        pinned[rel(member)] = row
    return {'manifest': pin(path), 'file_count_verified': len(files), 'pinned': pinned}


def normalize_actor(actor, candidate):
    """Lift the frozen combat geometry-table schema; never modify its files."""
    value = deepcopy(actor)
    value.setdefault('kind', 'boss')  # KEY is the known boss Ice Queen.
    value.setdefault('detailed_completed', False)
    if 'quality_review' not in value:
        assert value.get('status') == 'TECHNICALLY_STAGED_QUALITY_HOLD'
        assert value.get('quality_HOLD')
        value['quality_review'] = 'HOLD: ' + '; '.join(value['quality_HOLD'])
    if all('geometry' in track for track in value['tracks']):
        return value
    assert value.get('key') == KEY and value.get('source_pixels_unchanged') is True
    source_text = local(value['frames']).read_text()
    texture_paths = dict(re.findall(
        r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', source_text))
    texture_by_id = {resource_id: path for path, resource_id in texture_paths.items()}
    atlas = {}
    for identifier, body in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[)', source_text, re.S):
        resource_id = re.search(r'atlas = ExtResource\("([^"]+)"\)', body).group(1)
        arrays = {}
        for field in ['region', 'margin']:
            text = re.search(field + r' = Rect2\(([^)]+)\)', body).group(1)
            arrays[field] = [float(part.strip()) for part in text.split(',')]
        atlas[identifier] = {'texture': texture_by_id[resource_id], **arrays}
    geometries = {record['source']: record for record in value['geometries']}
    tracks = []
    for original in value['tracks']:
        record = geometries[original['source']]
        geometry = deepcopy(record['geometry'])
        geometry['frames'] = [deepcopy(record['geometry']['frames'][slot]) for slot in original['source_slots']]
        assert len(geometry['frames']) == len(original['pose_ids']) == original['frame_count']
        textures = set()
        for pose_id, frame in zip(original['pose_ids'], geometry['frames']):
            pose = atlas['pose_' + str(pose_id)]
            assert pose['region'] == frame['region'] and pose['margin'] == frame['margin']
            textures.add(pose['texture'])
        assert len(textures) == 1
        texture = textures.pop()
        assert local(texture).stem == original['source']
        track = deepcopy(original)
        track.update(source=rel(candidate.parent / 'raw' / (original['source'] + '.png')),
                     source_sha256=record['source_sha256'], texture=rel(local(texture)), geometry=geometry,
                     frozen_input_source_identifier=original['source'],
                     source_geometry_table_and_AtlasTexture_mapping_verified=True)
        tracks.append(track)
    value['tracks'] = tracks
    value.setdefault('sizing', {'reference_height': value['reference_height'],
        'source_body_measurements_preserved': [{key: deepcopy(record[key]) for key in record if key != 'geometry'}
                                             for record in value['geometries']]})
    return value


def read_actor(candidate, manifest, expected_pairs, expected_poses):
    assert rel(candidate) in manifest['pinned'], 'Candidate must itself be in its frozen input manifest'
    value = json.loads(candidate.read_text())
    actor = normalize_actor(value['actors'][KEY], candidate)
    assert actor['kind'] == 'boss' and actor['quality_tier'] == 'mythic_transform'
    assert actor['production_connected'] is False and actor['detailed_completed'] is False
    assert value['new_approvals'] == value['default_catalog_switches'] == 0
    tracks = actor['tracks']
    actual = {(t['role'], t['direction']) for t in tracks}
    assert len(tracks) == len(actual) == len(expected_pairs)
    assert actual == expected_pairs, (actual - expected_pairs, expected_pairs - actual)
    poses = []
    for resource_key in ['frames', 'native_profile']:
        resource = local(actor[resource_key])
        assert rel(resource) in manifest['pinned']
        assert sha(resource) == actor[resource_key + '_sha256']
    for track in tracks:
        assert track['animation'] == track['role'] + '_' + str(DIRS.index(track['direction']))
        source, texture = local(track['source']), local(track['texture'])
        assert rel(source) in manifest['pinned'] and rel(texture) in manifest['pinned']
        assert sha(source) == track['source_sha256']
        assert texture.read_bytes() == source.read_bytes(), 'Composition accepts exact preserved source PNGs'
        with Image.open(texture) as image:
            assert image.mode == 'RGBA'
            pixels = np.asarray(image)
            assert list(image.size) == track['geometry']['image_size']
            canvas = track['geometry']['canvas_size']
            assert len(canvas) == 2 and min(canvas) > 0
            for frame in track['geometry']['frames']:
                x, y, width, height = frame['region']
                assert min(x, y) >= 0 and min(width, height) > 0
                assert x + width <= image.width and y + height <= image.height
                assert frame['margin'][2:] == [canvas[0] - width, canvas[1] - height]
                assert min(frame['margin'][:2]) >= 0
                assert frame['margin'][0] + width <= canvas[0]
                assert frame['margin'][1] + height <= canvas[1]
                crop = pixels[y:y + height, x:x + width]
                assert np.any(crop[:, :, 3] > 100), 'Empty source frame'
                assert hashlib.sha256(crop.tobytes()).hexdigest() == frame['rgba_sha256'], 'Source RGBA differs from frozen frame'
                poses.append(frame['rgba_sha256'])
    assert len(poses) == actor['native_pose_count'] == expected_poses
    assert len(set(poses)) == expected_poses
    return actor, poses


def number(text, key):
    match = re.search(r'^' + re.escape(key) + r'\s*=\s*([-+0-9.eE]+)\s*$', text, re.M)
    assert match is not None, f'Missing explicit profile field {key}'
    return float(match.group(1))


def vector(text, key):
    match = re.search(r'^' + re.escape(key) + r'\s*=\s*Vector2\(([^)]+)\)\s*$', text, re.M)
    assert match is not None
    value = [float(v.strip()) for v in match.group(1).split(',')]
    assert len(value) == 2
    return value


ANIMATION_BLOCK = re.compile(
    r'\{"frames"\s*:\s*\[(.*?)\]\s*,\s*"loop"\s*:\s*(true|false)\s*,\s*'
    r'"name"\s*:\s*&"([^"]+)"\s*,\s*"speed"\s*:\s*([-+0-9.eE]+)\s*\}', re.S)


def timing_records(text):
    records = {}
    for match in ANIMATION_BLOCK.finditer(text):
        frame_body, loop, name, speed = match.groups()
        assert name not in records
        durations = re.findall(r'"duration"\s*:\s*([-+0-9.eE]+)', frame_body)
        assert durations and min(map(float, durations)) > 0 and float(speed) > 0
        records[name] = {'speed': float(speed), 'loop': loop == 'true',
                         'durations': list(map(float, durations)),
                         'speed_token': speed, 'loop_token': loop, 'duration_tokens': durations}
    assert records, 'Input animations must have explicit frame timing'
    return records


def preserve_timing(data, timings):
    seen = set()
    def replace(match):
        frame_body, _, name, _ = match.groups()
        assert name not in seen and name in timings
        seen.add(name)
        record = timings[name]
        iterator = iter(record['duration_tokens'])
        assert len(re.findall(r'"duration"\s*:', frame_body)) == len(record['duration_tokens'])
        body = re.sub(r'("duration"\s*:\s*)[-+0-9.eE]+',
                      lambda field: field.group(1) + next(iterator), frame_body)
        return ('{"frames": [' + body + '], "loop": ' + record['loop_token']
                + ', "name": &"' + name + '", "speed": ' + record['speed_token'] + '}')
    text = ANIMATION_BLOCK.sub(replace, data.decode())
    assert seen == set(timings)
    assert timing_records(text) == timings
    return text.encode()


def preserve(path, data):
    if path.exists():
        assert path.read_bytes() == data, f'Preserve existing combined revision; choose a new revision: {path}'
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def combine(args):
    run_manifest = checked_manifest(args.run_manifest, args.run_manifest_sha256)
    combat_manifest = checked_manifest(args.combat_manifest, args.combat_manifest_sha256)
    run_pairs = {('run', d) for d in DIRS if d != 'N'}
    combat_pairs = {(r, d) for r in ['idle', 'attack', 'hit'] for d in DIRS} | {('death', 'S')}
    run, run_poses = read_actor(RUN_PATH, run_manifest, run_pairs, 42)
    combat, combat_poses = read_actor(COMBAT_PATH, combat_manifest, combat_pairs, 60)
    assert len(set(run_poses + combat_poses)) == 102, 'Do not double-count an input source pose'
    run_profile = local(run['native_profile']).read_text()
    combat_profile = local(combat['native_profile']).read_text()
    target_scale = 86.0 / 140.0
    for profile in [run_profile, combat_profile]:
        assert abs(number(profile, 'pixel_scale') - target_scale) < 1e-9
        assert all(abs(a - b) < 1e-9 for a, b in zip(vector(profile, 'sprite_offset'), [0.0, -32.0 * target_scale]))
        assert 'metadata/twilight_production_connected = false' in profile
        assert 'metadata/twilight_detailed_completed = false' in profile
    assert number(combat_profile, 'attack_hit_frame') == 1
    assert number(combat_profile, 'death_duration') > 0
    tracks = deepcopy(run['tracks']) + deepcopy(combat['tracks'])
    tracks.sort(key=lambda t: (['idle', 'run', 'attack', 'hit', 'death'].index(t['role']), DIRS.index(t['direction'])))
    assert len(tracks) == len({t['animation'] for t in tracks}) == 32
    assert not any(t['role'] == 'run' and t['direction'] == 'N' for t in tracks)
    frames_path = OUT / 'SpriteFrames.tres'
    profile_path = OUT / 'NativeMotionProfile.tres'
    timings = timing_records(local(run['frames']).read_text())
    combat_timings = timing_records(local(combat['frames']).read_text())
    assert not set(timings) & set(combat_timings)
    timings.update(combat_timings)
    assert set(timings) == {t['animation'] for t in tracks}
    for track in tracks:
        assert len(timings[track['animation']]['durations']) == len(track['geometry']['frames'])
    frames_data = preserve_timing(frames_bytes(tracks), timings)
    old_line = 'frames_path = "' + combat['frames'] + '"'
    new_line = 'frames_path = "res://' + rel(frames_path) + '"'
    assert combat_profile.count(old_line) == 1
    profile_data = combat_profile.replace(old_line, new_line).encode()
    assert profile_data.decode().replace(new_line, old_line) == combat_profile
    source_quality = {'run': run['quality_review'], 'combat': combat['quality_review']}
    actor = {
        'kind': 'boss', 'quality_tier': 'mythic_transform',
        'frames': 'res://' + rel(frames_path), 'frames_sha256': hashlib.sha256(frames_data).hexdigest(),
        'native_profile': 'res://' + rel(profile_path), 'native_profile_sha256': hashlib.sha256(profile_data).hexdigest(),
        'production_connected': False, 'detailed_completed': False,
        'native_track_count': 32, 'native_pose_count': 102, 'missing_required_tracks': ['run_6'],
        'new_poses_generated_by_composition': 0, 'preserved_input_source_poses': 102,
        'animation_timing_preserved': {name: {key: record[key] for key in ['speed', 'loop', 'durations']}
                                       for name, record in timings.items()},
        'quality_review': 'HOLD: input support/contact/camera/handedness/palette/game-speed reviews remain unapproved; N RUN is deliberately unavailable and never falls through to old reversed-slit source',
        'input_quality_reviews_preserved': source_quality,
        'held_directions': deepcopy(run.get('held_directions', [])),
        'sizing': {'profile_pixel_scale': target_scale, 'sprite_offset': [0.0, -32.0 * target_scale],
                   'common_reference_canvas': [256, 256], 'per_track_virtual_canvas_preserved': True,
                   'source_RGBA_region_margin_and_order_preserved': True, 'source_pixels_resampled': False,
                   'input_sizing_metadata_preserved': {'run': deepcopy(run.get('sizing', {})),
                                                       'combat': deepcopy(combat.get('sizing', {}))}},
        'tracks': tracks,
    }
    result = {'schema': 'pr122-queen-combined-staging-v1', 'batch': rel(BASE),
              'actors': {KEY: actor}, 'new_approvals': 0, 'default_catalog_switches': 0,
              'new_source_PNGs': 0, 'new_poses_generated_by_composition': 0,
              'existing_approved_assets_and_input_candidates_preserved': True,
              'combat_track_adapter': 'Frozen geometries/source_slots/pose_ids lifted to per-track geometry; every source AtlasTexture texture/region/margin verified unchanged',
              'old_N_RUN_reversed_slit_source_connected': False,
              'input_pins': [pin(RUN_PATH), pin(COMBAT_PATH), run_manifest['manifest'], combat_manifest['manifest']],
              'input_manifest_files_verified': run_manifest['file_count_verified'] + combat_manifest['file_count_verified']}
    if args.apply:
        preserve(frames_path, frames_data)
        preserve(profile_path, profile_data)
        preserve(CANDIDATE, (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode())
    print(json.dumps({'mode': 'write' if args.apply else 'verified_read_only', 'clips': 32,
                      'source_poses': 102, 'new_composite_poses': 0, 'missing': ['run_6'],
                      'candidate': rel(CANDIDATE), 'profile': rel(profile_path)}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-manifest', required=True)
    parser.add_argument('--run-manifest-sha256', required=True)
    parser.add_argument('--combat-manifest', required=True)
    parser.add_argument('--combat-manifest-sha256', required=True)
    parser.add_argument('--apply', action='store_true', help='Write only after both pinned frozen manifests verify')
    combine(parser.parse_args())
