#!/usr/bin/env python3
"""Assemble newly authored shared demon-family clips without approving species."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import frames_bytes, preserve, json_bytes
from PIL import Image
import numpy as np

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/batch05-demon-family')
FOLDER = Path('assets/actors/eight_direction/monster_staging/demon_family/r001')
REGISTER = Path('data/pr122_monster_demon_family_staging.json')
KEYS = {
    'monster:오만의 탑 공포의 악마': 'fear_demon',
    'monster:마계 악마전사': 'demon_warrior',
    'monster:교만의 제노사이더': 'genocider',
    'monster:탐욕의 코아쿡': 'koakuk',
}


def assemble():
    sources = []
    for path in ('run-production/source-checks.json', 'combat-source-checks.json', 'repair-death-source-checks.json'):
        sources.extend(json.loads((ROOT / BATCH / path).read_text()))
    plan = json.loads((ROOT / 'data/animation_authoring_sources.json').read_text())
    targets = {row['key']: row for row in plan['targets'] if row['key'] in KEYS}
    assert len(targets) == 4
    reference = next(iter(targets.values()))['reference']
    expected_reference = {field: reference[field] for field in ('path', 'region', 'sha256', 'region_rgba_sha256')}
    for target in targets.values():
        assert {field: target['reference'][field] for field in expected_reference} == expected_reference
        presentation = target['presentation_to_preserve']
        assert target['group'] == 'normal_monster' and presentation['visual']['body'] == 'demon'
        assert presentation['attack_type'] == 'melee' and presentation['visual_height'] == 86
        assert presentation['animation_profile'] == {'motion_style': 'slash', 'attack_hit_ratio': 0.44, 'floating': False}
    source_reference = ROOT / reference['path'].removeprefix('res://')
    assert core.sha(source_reference) == reference['sha256']
    with Image.open(source_reference) as image:
        x, y, w, h = reference['region']
        assert hashlib.sha256(image.convert('RGBA').crop((x, y, x + w, y + h)).tobytes()).hexdigest() == reference['region_rgba_sha256']
    tracks, selected_sources, pixel_hashes, visible_hashes = [], [], set(), set()
    for record in sources:
        source = ROOT / record['path']
        assert core.sha(source) == record['sha256']
        if record['status'] != 'GEOMETRY_PASS_ONLY':
            continue
        rows = record['rows']
        directions, axis, refs = record['directions'], record['axis'], record['reference_rows']
        if rows == 4:
            roles = {'run': [0, 1, 2, 3]}
        elif rows == 7:
            roles = {'idle': [0, 1], 'attack': [2, 3, 4], 'hit': [5, 6]}
        elif rows == 3:
            roles = {'death': [0, 1, 2]}
        else:
            raise ValueError('Unexpected source phases')
        initial = core.analyze(source, rows, refs, directions_axis=axis, canvas_size=1024, directions=directions)
        core.require_complete_pose_regions(source, initial)
        # One uniform source canvas, never per-pose pixel rescaling.
        canvas = max(64, round(initial['neutral_height'] * 256 / 64 / 8) * 8)
        geometry = core.analyze(source, rows, refs, directions_axis=axis, canvas_size=canvas, directions=directions)
        core.require_complete_pose_regions(source, geometry)
        texture = FOLDER / source.name
        preserve(ROOT / texture, source.read_bytes())
        with Image.open(source) as image:
            pixels = np.asarray(image.convert('RGBA'))
            for frame in geometry['frames']:
                assert frame['rgba_sha256'] not in pixel_hashes
                pixel_hashes.add(frame['rgba_sha256'])
                x, y, w, h = frame['region']
                visible = core._visible_pose_fingerprint(pixels[y:y + h, x:x + w])
                assert visible not in visible_hashes
                visible_hashes.add(visible)
        selected_sources.append(dict(name=record['name'], source=record['path'], sha256=record['sha256'],
                                     directions=directions, rows=rows, canvas_size=canvas, status='GEOMETRY_PASS_ONLY'))
        for role, phases in roles.items():
            for direction in directions:
                part = deepcopy(geometry)
                part['frames'] = [frame for frame in geometry['frames'] if frame['direction'] == direction and frame['row'] in phases]
                part['distinct_pixel_frames'] = len(phases)
                assert len(part['frames']) == len(phases)
                tracks.append(dict(direction=direction, role=role,
                                   animation=role + '_' + str(core.DIRECTIONS.index(direction)),
                                   source=record['path'], source_sha256=record['sha256'],
                                   texture=texture.as_posix(), geometry=part))
    expected = {(direction, role) for role in ('idle', 'run', 'attack', 'hit') for direction in core.DIRECTIONS} | {('S', 'death')}
    assert len(tracks) == 33 and {(track['direction'], track['role']) for track in tracks} == expected
    assert sum(len(track['geometry']['frames']) for track in tracks) == len(pixel_hashes) == len(visible_hashes) == 91
    frames = FOLDER / 'SpriteFrames.tres'
    preserve(ROOT / frames, frames_bytes(tracks))
    scale = 86 / 64
    actors = {}
    for key, slug in KEYS.items():
        profile = FOLDER / (slug + '-NativeMotionProfile.tres')
        preserve(ROOT / profile, ('\n'.join([
            '[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', '',
            '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', '',
            '[resource]', 'script = ExtResource("1")', f'profile_id = "{key}"',
            f'frames_path = "res://{frames.as_posix()}"', 'layout = "directional8"',
            'movement_fps = 8.333333333', 'reference_speed = 210.0', f'pixel_scale = {scale}',
            f'sprite_offset = Vector2(0, {-32 * scale})', 'authored_motion_weight = 0.0',
            'hit_recoil = 0.0', 'embedded_shadow = false', 'body_kind = "humanoid"',
            'attack_hit_frame = 1', 'action_hit_frames = {"attack": 1}', 'death_duration = 0.65',
            'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false',
            'metadata/twilight_shared_family_candidate = true', ''])).encode())
        actors[key] = dict(kind='normal', quality_tier='hero_transform',
                           frames='res://' + frames.as_posix(), frames_sha256=core.sha(ROOT / frames),
                           native_profile='res://' + profile.as_posix(), native_profile_sha256=core.sha(ROOT / profile),
                           production_connected=False, detailed_completed=False, native_track_count=33,
                           native_pose_count=91, missing_required_tracks=[],
                           sharing_basis='Same existing atlas bytes/region/body/melee/slash/height; newly authored shared normal-family source, not a palette-only proxy',
                           quality_review='HOLD: exact reference identity, hand ownership, direction, support/contact and default Main review pending',
                           original_presentation=targets[key]['presentation_to_preserve'], tracks=tracks)
    base_key = next(iter(KEYS))
    family_adapters = {}
    for key in KEYS:
        if key == base_key:
            continue
        candidate = actors.pop(key)
        family_adapters[key] = {field: candidate[field] for field in (
            'kind', 'quality_tier', 'native_profile', 'native_profile_sha256',
            'production_connected', 'detailed_completed', 'sharing_basis',
            'quality_review', 'original_presentation')}
        family_adapters[key].update(source_actor=base_key, new_source_poses=0,
                                    per_species_Main_visual_review='HOLD', newly_approved=False)
    register = dict(schema='pr122-monster-demon-family-staging-v1', batch=BATCH.as_posix(),
                    shared_unique_clips=33, shared_unique_poses=91, candidate_species=4,
                    actors=actors, family_adapters=family_adapters,
                    reference=reference, selected_sources=selected_sources,
                    newly_approved=0, default_catalog_switches=0,
                    source_approval='HOLD; geometry and playback never grant identity/contact/Main approval')
    destination = ROOT / REGISTER
    if destination.exists() and destination.read_bytes() != json_bytes(register):
        previous = json.loads(destination.read_text())
        assert previous['schema'] == register['schema'] and previous['newly_approved'] == 0
        preserve(ROOT / BATCH / 'register-before-family-adapters.json', destination.read_bytes())
    destination.write_bytes(json_bytes(register))
    summary = ROOT / BATCH / 'candidate-summary.json'
    summary.write_bytes(json_bytes({key: value for key, value in register.items() if key != 'actors'}))
    print('DEMON_FAMILY_STAGED shared_clips=33 unique_poses=91 bindings=4 new_approvals=0')


if __name__ == '__main__':
    assemble()
