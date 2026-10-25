#!/usr/bin/env python3
"""Preserve new orc-family art and assemble unapproved native candidates."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import frames_bytes, preserve, json_bytes

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/batch06-orc-family')
FOLDER = Path('assets/actors/eight_direction/monster_staging/orc_family/r001')
KEYS = ['monster:로머', 'monster:에스카로스 치프']
NAMES = ['orc-run-front4', 'orc-run-back4', 'orc-combat-front4', 'orc-combat-back4', 'orc-death-S3']


def build():
    targets = {x['key']: x for x in json.loads((ROOT / 'data/animation_authoring_sources.json').read_text())['targets']}
    evidence = {key: targets[key] for key in KEYS}
    first = targets[KEYS[0]]
    second = targets[KEYS[1]]
    assert first['reference'] == second['reference']
    for key in KEYS:
        target = targets[key]
        assert target['group'] == 'normal_monster'
        p = target['presentation_to_preserve']
        assert p['visual']['body'] == 'orc_captain' and p['visual_height'] == 86
        assert p['attack_type'] == 'melee' and p['animation_profile']['motion_style'] == 'slash'
        assert p['visual']['weapon'] == 'sword' and p['visual']['width'] == 1.05
    shared_proof = {
        'keys': KEYS, 'same_reference': first['reference'], 'target_evidence': evidence,
        'basis': 'Identical original atlas region/RGBA, body, weapon, width, height, combat and motion presentation. Only fallback crest/accent differ.',
        'new_source': 'New shared native orc-captain rig from textual brief; no palette-only substitution or claim of individual unique art.',
        'review': 'HOLD: original reference identity, source-plane anatomy/support/contact and default Main visual review pending',
        'new_approvals': 0, 'default_catalog_switches': 0,
    }
    preserve(ROOT / BATCH / 'family-sharing-evidence.json', json_bytes(shared_proof))
    records, tracks, fingerprints = [], [], set()
    for name in NAMES:
        request = json.loads((Path('/tmp') / (name + '-request.json')).read_text())
        source = Path(request['image_path'])
        raw = BATCH / 'raw' / (name + '.png')
        preserve(ROOT / raw, source.read_bytes())
        request.update(preserved_path=raw.as_posix(), sha256=core.sha(source))
        preserve(ROOT / BATCH / 'requests' / (name + '.json'), json_bytes(request))
        directions, rows = request['directions'], request['rows']
        axis, refs, roles = request['axis'], request['reference_rows'], request['roles']
        record = {k: request[k] for k in ('name', 'directions', 'rows', 'axis', 'reference_rows', 'roles')}
        record.update(source=raw.as_posix(), sha256=core.sha(source))
        try:
            initial = core.analyze(source, rows, refs, directions_axis=axis, canvas_size=2048, directions=directions)
            core.require_complete_pose_regions(source, initial)
            canvas = max(64, round(initial['neutral_height'] * 256 / 64 / 8) * 8)
            geometry = core.analyze(source, rows, refs, directions_axis=axis, canvas_size=canvas, directions=directions)
            core.require_complete_pose_regions(source, geometry)
            texture = FOLDER / (name + '.png')
            preserve(ROOT / texture, source.read_bytes())
            for frame in geometry['frames']:
                assert frame['rgba_sha256'] not in fingerprints, 'Repeated visible frame across sources'
                fingerprints.add(frame['rgba_sha256'])
            record.update(status='GEOMETRY_PASS_ONLY', geometry=geometry, canvas_size=canvas)
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
    preserve(ROOT / BATCH / 'source-checks.json', json_bytes(records))
    available = {(t['direction'], t['role']) for t in tracks}
    expected = {(d, r) for r in ('idle', 'run', 'attack', 'hit') for d in core.DIRECTIONS} | {('S', 'death')}
    frames = FOLDER / 'SpriteFrames.tres'
    preserve(ROOT / frames, frames_bytes(tracks))
    actors = {}
    for key in KEYS:
        slug = 'romer' if key == KEYS[0] else 'escaros_chief'
        profile = FOLDER / (slug + '-NativeMotionProfile.tres')
        scale = 86 / 64
        body = '\n'.join([
            '[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', '',
            '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', '',
            '[resource]', 'script = ExtResource("1")', f'profile_id = "{key}"',
            f'frames_path = "res://{frames.as_posix()}"', 'layout = "directional8"',
            'movement_fps = 8.333333333', 'reference_speed = 210.0', f'pixel_scale = {scale}',
            f'sprite_offset = Vector2(0, {-32 * scale})', 'authored_motion_weight = 0.0',
            'hit_recoil = 0.0', 'embedded_shadow = false', 'body_kind = "humanoid"',
            'attack_hit_frame = 1', 'action_hit_frames = {"attack": 1}', 'death_duration = 0.65',
            'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', ''])
        preserve(ROOT / profile, body.encode())
        actors[key] = {
            'kind': 'normal', 'quality_tier': 'hero_transform', 'frames': 'res://' + frames.as_posix(),
            'frames_sha256': core.sha(ROOT / frames), 'native_profile': 'res://' + profile.as_posix(),
            'native_profile_sha256': core.sha(ROOT / profile), 'production_connected': False,
            'detailed_completed': False, 'native_track_count': len(tracks),
            'native_pose_count': sum(len(t['geometry']['frames']) for t in tracks),
            'missing_required_tracks': [f'{r}_{core.DIRECTIONS.index(d)}' for d, r in sorted(expected-available)],
            'quality_review': shared_proof['review'], 'shared_source_family': 'orc_captain_same_reference',
            'distinct_source_pose_count': len(fingerprints), 'tracks': tracks}
    adapter_actor = actors.pop(KEYS[1])
    adapters = {KEYS[1]: {
        'source_actor': KEYS[0], 'kind': 'normal', 'quality_tier': 'hero_transform',
        'native_profile': adapter_actor['native_profile'],
        'native_profile_sha256': adapter_actor['native_profile_sha256'],
        'frames': adapter_actor['frames'], 'frames_sha256': adapter_actor['frames_sha256'],
        'shared_source_family': 'orc_captain_same_reference', 'new_source_poses': 0,
        'quality_review': shared_proof['review'], 'production_connected': False, 'detailed_completed': False}}
    register = {'schema': 'pr122-monster-staging-v1', 'batch': BATCH.as_posix(), 'actors': actors, 'family_adapters': adapters,
                'shared_native_source_families': 1, 'new_approvals': 0, 'default_catalog_switches': 0}
    preserve(ROOT / 'data/pr122_monster_orc_family_staging.json', json_bytes(register))
    preserve(ROOT / BATCH / 'candidate.json', json_bytes(register))
    print(json.dumps({'actors': len(actors), 'family_adapters': len(adapters), 'shared_families': 1, 'clips_per_actor': len(tracks),
                      'unique_source_poses': len(fingerprints), 'holds': sum(r['status']=='SOURCE_HOLD' for r in records),
                      'full_33_clip_candidate': available==expected, 'new_approvals': 0}))


if __name__ == '__main__':
    build()
