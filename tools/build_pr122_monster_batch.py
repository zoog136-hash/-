#!/usr/bin/env python3
"""Stage exact, hash-pinned monster sources; never switch or approve an actor."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path

import import_original_based_motion as core

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/batch01')
REGISTER = Path('data/pr122_monster_animation_staging.json')
SOURCES = [
    ('gnoll_e', 'gnoll-E-all16', 16, 'phase_grid4', [0, 1], 'E', None, None),
    ('gnoll_e_run6', 'gnoll-E-run6', 6, 'phase_grid3', [0, 3], 'E', 'monster:놀', 'run'),
    ('gnoll_e_attack3', 'gnoll-E-attack3', 3, 'phase_grid3', [2], 'E', None, None),
    ('gnoll_e_attack3_v2', 'gnoll-E-attack3-v2', 3, 'columns', [2], 'E', 'monster:놀', 'attack'),
    ('queen_e_run6', 'queen-E-run6', 6, 'phase_grid2', [0, 3], 'E', 'monster:얼음 여왕', 'run'),
    ('queen_s_run6', 'queen-S-run6', 6, 'phase_grid2', [0, 3], 'S', 'monster:얼음 여왕', 'run'),
]
ACTORS = {'monster:놀': ('gnoll', 64, 86), 'monster:얼음 여왕': ('ice_queen', 140, 86)}


def preserve(path, data):
    if path.exists():
        if path.read_bytes() != data:
            raise ValueError('Preserve existing output; choose a new revision: ' + str(path))
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def frames_bytes(tracks):
    count = sum(len(t['geometry']['frames']) for t in tracks)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={count + len(tracks) + 1} format=3]']
    animations = []
    for i, track in enumerate(tracks):
        lines += ['', f'[ext_resource type="Texture2D" path="res://{track["texture"]}" id="{i + 1}"]']
    for i, track in enumerate(tracks):
        for j, frame in enumerate(track['geometry']['frames']):
            lines += ['', f'[sub_resource type="AtlasTexture" id="pose_{i}_{j}"]',
                      f'atlas = ExtResource("{i + 1}")',
                      'region = Rect2(%s)' % ', '.join(map(str, frame['region'])),
                      'margin = Rect2(%s)' % ', '.join(map(str, frame['margin'])), 'filter_clip = true']
        poses = ',\n'.join('{"duration": 1.0, "texture": SubResource("pose_%d_%d")}' % (i, j)
                            for j in range(len(track['geometry']['frames'])))
        loop = str(track['role'] in ('idle', 'run')).lower()
        seconds = {'idle': 1.2, 'run': .48, 'attack': .42, 'hit': .22, 'death': .65}[track['role']]
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.9f}' %
                          (poses, loop, track['animation'], len(track['geometry']['frames']) / seconds))
    lines += ['', '[resource]', 'animations = [\n' + ',\n'.join(animations) + '\n]',
              'metadata/twilight_canvas_size = Vector2(256, 256)',
              'metadata/twilight_native_locomotion_staging = true',
              'metadata/twilight_production_connected = false',
              'metadata/twilight_detailed_completed = false', '']
    return '\n'.join(lines).encode()


def build(root, request_dir):
    records, selected = [], {key: [] for key in ACTORS}
    for request_name, name, rows, axis, refs, direction, key, role in SOURCES:
        request = json.loads((request_dir / (request_name + '-request.json')).read_text())
        source = Path(request['image_path'])
        raw = BATCH / 'raw' / (name + '.png')
        preserve(root / raw, source.read_bytes())
        record = {'name': name, 'path': raw.as_posix(), 'sha256': core.sha(source),
                  'rows': rows, 'axis': axis, 'reference_rows': refs, 'direction': direction}
        request.update(preserved_path=raw.as_posix(), sha256=record['sha256'])
        preserve(root / BATCH / 'requests' / (name + '.json'), json_bytes(request))
        try:
            initial = core.analyze(source, rows, refs, directions_axis=axis,
                                   canvas_size=2048, directions=[direction])
            core.require_complete_pose_regions(source, initial)
            if key is None:
                raise ValueError('Rejected trial is preserved and cannot enter selected tracks')
            # One uniform virtual canvas for this whole source. This retains
            # all original pixels and the previous source-height convention.
            canvas = max(64, round(initial['neutral_height'] * 256 / ACTORS[key][1] / 8) * 8)
            geometry = core.analyze(source, rows, refs, directions_axis=axis,
                                    canvas_size=canvas, directions=[direction])
            core.require_complete_pose_regions(source, geometry)
            record.update(status='GEOMETRY_PASS_ONLY', geometry=geometry,
                          quality_review='HOLD: anatomical support, contact, directional identity and source-plane anchors need review')
            folder = Path('assets/actors/eight_direction/monster_staging') / ACTORS[key][0] / 'r002'
            texture = folder / f'{direction}-{role}.png'
            preserve(root / texture, source.read_bytes())
            selected[key].append({'direction': direction, 'role': role,
                                  'animation': role + '_' + str(core.DIRECTIONS.index(direction)),
                                  'source': raw.as_posix(), 'texture': texture.as_posix(),
                                  'source_sha256': record['sha256'], 'geometry': geometry})
        except ValueError as error:
            record.update(status='SOURCE_HOLD', reason=str(error))
        records.append(record)

    scope = json.loads((root / 'data/pr122_monster_production_scope.json').read_text())
    classification = {row['id']: row for row in scope['monsters']}
    actors = {}
    for key, tracks in selected.items():
        if not tracks:
            continue
        slug, reference_height, display_height = ACTORS[key]
        folder = Path('assets/actors/eight_direction/monster_staging') / slug / 'r002'
        frames = folder / 'SpriteFrames.tres'
        preserve(root / frames, frames_bytes(tracks))
        scale = display_height / reference_height
        profile = folder / 'NativeMotionProfile.tres'
        body = '\n'.join([
            '[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', '',
            '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', '',
            '[resource]', 'script = ExtResource("1")', f'profile_id = "{key}"',
            f'frames_path = "res://{frames.as_posix()}"', 'layout = "directional8"',
            'movement_fps = 12.5', 'reference_speed = 210.0', f'pixel_scale = {scale:.12f}',
            f'sprite_offset = Vector2(0, {-32 * scale:.12f})', 'authored_motion_weight = 0.0',
            'hit_recoil = 0.0', 'embedded_shadow = false', 'attack_hit_frame = 1',
            'action_hit_frames = {"attack": 1}', 'death_duration = 0.65',
            'metadata/twilight_production_connected = false',
            'metadata/twilight_detailed_completed = false', ''])
        preserve(root / profile, body.encode())
        required = {(d, role) for role in ('idle', 'run', 'attack', 'hit') for d in core.DIRECTIONS} | {('S', 'death')}
        available = {(t['direction'], t['role']) for t in tracks}
        actors[key] = {'kind': classification[key]['kind'], 'quality_tier': classification[key]['quality_tier'],
                       'frames': 'res://' + frames.as_posix(), 'frames_sha256': core.sha(root / frames),
                       'native_profile': 'res://' + profile.as_posix(),
                       'native_profile_sha256': core.sha(root / profile),
                       'production_connected': False, 'detailed_completed': False,
                       'native_track_count': len(tracks),
                       'native_pose_count': sum(len(t['geometry']['frames']) for t in tracks),
                       'missing_required_tracks': [f'{role}_{core.DIRECTIONS.index(d)}' for d, role in sorted(required - available)],
                       'quality_review': 'HOLD: new textual-brief art has not had identity/support/contact or Main visual approval',
                       'tracks': tracks}
    register = {'schema': 'pr122-monster-staging-v1', 'batch': BATCH.as_posix(), 'actors': actors,
                'new_approvals': 0, 'default_catalog_switches': 0,
                'preservation': 'Previous approved art, shared proxies, WALK and multiview DEATH remain byte-identical.'}
    destination = root / REGISTER
    if destination.exists():
        previous = json.loads(destination.read_text())
        for key, actor in actors.items():
            old = previous.get('actors', {}).get(key)
            if old and (old['production_connected'] or old['detailed_completed']) and old != actor:
                raise ValueError('Cannot replace an approved/connected actor: ' + key)
        # Other batches own other actor entries. Rerunning this batch must
        # retain their work instead of replacing the whole shared registry.
        merged = previous.get('actors', {}).copy()
        merged.update(actors)
        register['actors'] = merged
    if destination.exists() and destination.read_bytes() != json_bytes(register):
        previous = json.loads(destination.read_text())
        assert previous['new_approvals'] == previous['default_catalog_switches'] == 0
        assert all(not a['production_connected'] and not a['detailed_completed'] for a in previous['actors'].values())
        preserve(root / BATCH / 'rejected-r001-register.json', destination.read_bytes())
    destination.write_bytes(json_bytes(register))
    preserve(root / BATCH / 'source-checks.json', json_bytes(records))
    print(json.dumps({'staged_actors': len(actors), 'clips': sum(a['native_track_count'] for a in actors.values()),
                      'poses': sum(a['native_pose_count'] for a in actors.values()),
                      'source_holds': sum(r['status'] == 'SOURCE_HOLD' for r in records), 'new_approvals': 0}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--request-dir', type=Path, default=Path('/tmp'))
    args = parser.parse_args()
    build(Path(__file__).resolve().parents[1], args.request_dir)
