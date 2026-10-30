#!/usr/bin/env python3
"""Assemble the first full 33-track normal-monster candidate from exact PNGs."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path

import import_original_based_motion as core
from build_pr122_monster_batch import frames_bytes, preserve, json_bytes

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/batch02-salamander')
FOLDER = Path('assets/actors/eight_direction/monster_staging/salamander/r001')
KEY = 'monster:사라만다'
SOURCES = [
    ('salamander_run_front4', 4, ['E', 'SE', 'S', 'SW'], 'rows', [0, 2], {'run': [0, 1, 2, 3]}),
    ('salamander_run_back4', 4, ['W', 'NW', 'N', 'NE'], 'rows', [0, 2], {'run': [0, 1, 2, 3]}),
    ('salamander_combat_front4', 7, ['E', 'SE', 'S', 'SW'], 'rows', [0, 1], None),
    ('salamander_combat_front4_v2', 7, ['E', 'SE', 'S', 'SW'], 'columns', [0, 1], {'idle': [0, 1], 'attack': [2, 3, 4], 'hit': [5, 6]}),
    ('salamander_combat_back4', 7, ['W', 'NW', 'N', 'NE'], 'rows', [0, 1], {'idle': [0, 1], 'attack': [2, 3, 4], 'hit': [5, 6]}),
    ('salamander_death_s3', 3, ['S'], 'columns', [0], {'death': [0, 1, 2]}),
]


def build(root, request_dir):
    records, tracks, fingerprints = [], [], set()
    for name, rows, directions, axis, refs, roles in SOURCES:
        request = json.loads((request_dir / (name + '-request.json')).read_text())
        source = Path(request['image_path'])
        raw = BATCH / 'raw' / (name + '.png')
        preserve(root / raw, source.read_bytes())
        request.update(preserved_path=raw.as_posix(), sha256=core.sha(source))
        preserve(root / BATCH / 'requests' / (name + '.json'), json_bytes(request))
        record = {'name': name, 'source': raw.as_posix(), 'sha256': core.sha(source),
                  'directions': directions, 'rows': rows, 'axis': axis, 'reference_rows': refs}
        try:
            initial = core.analyze(source, rows, refs, directions_axis=axis, canvas_size=1024, directions=directions)
            core.require_complete_pose_regions(source, initial)
            if roles is None:
                raise ValueError('Rejected front trial cannot enter selected tracks')
            canvas = max(64, round(initial['neutral_height'] * 256 / 64 / 8) * 8)
            geometry = core.analyze(source, rows, refs, directions_axis=axis, canvas_size=canvas, directions=directions)
            core.require_complete_pose_regions(source, geometry)
            texture = FOLDER / (name + '.png')
            preserve(root / texture, source.read_bytes())
            for frame in geometry['frames']:
                assert frame['rgba_sha256'] not in fingerprints, 'Duplicate pixel pose across sources'
                fingerprints.add(frame['rgba_sha256'])
            record.update(status='GEOMETRY_PASS_ONLY', canvas_size=canvas, geometry=geometry)
            for role, phases in roles.items():
                for direction in directions:
                    part = deepcopy(geometry)
                    part['frames'] = [f for f in geometry['frames'] if f['direction'] == direction and f['row'] in phases]
                    assert len(part['frames']) == len(phases)
                    part['distinct_pixel_frames'] = len(phases)
                    tracks.append({'direction': direction, 'role': role,
                                   'animation': role + '_' + str(core.DIRECTIONS.index(direction)),
                                   'source': raw.as_posix(), 'source_sha256': record['sha256'],
                                   'texture': texture.as_posix(), 'geometry': part})
        except ValueError as error:
            record.update(status='SOURCE_HOLD', reason=str(error))
        records.append(record)
    available = {(track['direction'], track['role']) for track in tracks}
    expected = {(d, role) for role in ('idle', 'run', 'attack', 'hit') for d in core.DIRECTIONS} | {('S', 'death')}
    assert available == expected and len(tracks) == 33
    assert sum(len(t['geometry']['frames']) for t in tracks) == len(fingerprints) == 91
    frames = FOLDER / 'SpriteFrames.tres'
    preserve(root / frames, frames_bytes(tracks))
    profile = FOLDER / 'NativeMotionProfile.tres'
    scale = 78 / 64
    preserve(root / profile, ('\n'.join([
        '[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', '',
        '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', '',
        '[resource]', 'script = ExtResource("1")', f'profile_id = "{KEY}"',
        f'frames_path = "res://{frames.as_posix()}"', 'layout = "directional8"',
        'movement_fps = 8.333333333', 'reference_speed = 210.0', f'pixel_scale = {scale}',
        f'sprite_offset = Vector2(0, {-32 * scale})', 'authored_motion_weight = 0.0',
        'hit_recoil = 0.0', 'embedded_shadow = false', 'body_kind = "quadruped"',
        'attack_hit_frame = 1', 'action_hit_frames = {"attack": 1}', 'death_duration = 0.65',
        'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', ''])).encode())
    register_path = root / 'data/pr122_monster_animation_staging.json'
    register = json.loads(register_path.read_text())
    old = register['actors'].get(KEY)
    if old and (old['production_connected'] or old['detailed_completed']):
        raise ValueError('Preserve the approved/connected salamander; use a new revision')
    register['actors'][KEY] = {
        'kind': 'normal', 'quality_tier': 'hero_transform', 'frames': 'res://' + frames.as_posix(),
        'frames_sha256': core.sha(root / frames), 'native_profile': 'res://' + profile.as_posix(),
        'native_profile_sha256': core.sha(root / profile), 'production_connected': False,
        'detailed_completed': False, 'native_track_count': 33, 'native_pose_count': 91,
        'missing_required_tracks': [], 'quality_review': 'HOLD: text-brief identity against existing reference, support/contact/source-plane anchors and default Main review pending',
        'tracks': tracks}
    register_path.write_bytes(json_bytes(register))
    preserve(root / BATCH / 'source-checks.json', json_bytes(records))
    preserve(root / BATCH / 'candidate.json', json_bytes(register['actors'][KEY]))
    print('SALAMANDER_STAGED tracks=33 poses=91 selected_PNGs=5 rejected_PNGs=1 approvals_added=0')


if __name__ == '__main__':
    build(Path(__file__).resolve().parents[1], Path('/tmp'))
