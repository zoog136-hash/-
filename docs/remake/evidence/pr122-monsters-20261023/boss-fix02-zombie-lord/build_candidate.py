#!/usr/bin/env python3
"""Assemble dedicated, unapproved Zombie Lord source-plane poses without replacing old art."""
from copy import deepcopy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import frames_bytes, preserve, json_bytes

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/boss-fix02-zombie-lord')
FOLDER = Path('assets/actors/eight_direction/monster_boss_repair/zombie_lord/r001')
KEY = 'monster:죽음의 좀비 로드'
REPAIRS = {('E', 'run'): 'v02', ('SW', 'run'): 'v02', ('N', 'run'): 'v02', ('SW', 'core'): 'v02'}
REASONS = {
    ('E', 'run'): 'Private visual review: nominal E RUN is pulled toward frontal SE; dedicated true-side revision required.',
    ('SW', 'run'): 'Private visual review: nominal SW RUN is pulled toward frontal S; dedicated quarter-left revision required.',
    ('N', 'run'): 'Strict complete-pose crop rejected intersecting pose rectangles; wider-gutter source required.',
    ('SW', 'core'): 'Private visual review: nominal SW idle/contact is pulled toward frontal S; quarter-left revision required.',
}


def build():
    records, tracks, fingerprints = [], [], set()
    for request_path in sorted((ROOT / BATCH / 'requests').glob('*.json')):
        if 'support-columns' in request_path.name:
            continue  # Immutable r001 source selection excludes later r002 trials.
        q = json.loads(request_path.read_text())
        raw = BATCH / 'raw' / (q['name'] + '.png')
        if not (ROOT / raw).exists():
            raise ValueError('Request source not yet saved: ' + str(raw))
        d, role = q['direction'], q['role']
        selected_revision = REPAIRS.get((d, role), 'v01')
        selected = q['name'].endswith(selected_revision)
        rec = {k: q[k] for k in ('name', 'direction', 'role', 'rows', 'directions_axis', 'reference_rows')}
        rec.update(source=raw.as_posix(), sha256=core.sha(ROOT / raw), request=request_path.relative_to(ROOT).as_posix(),
                   request_sha256=core.sha(request_path), selected=selected)
        try:
            first = core.analyze(ROOT / raw, q['rows'], q['reference_rows'], directions_axis=q['directions_axis'],
                                 canvas_size=2048, directions=[d])
            core.require_complete_pose_regions(ROOT / raw, first)
            # A single uniform scale per whole source; no pixel edit, mirroring,
            # duplication, per-pose fitting or changed crop-completeness threshold.
            canvas = max(64, round(first['neutral_height'] * 256 / 64 / 8) * 8)
            g = core.analyze(ROOT / raw, q['rows'], q['reference_rows'], directions_axis=q['directions_axis'],
                             canvas_size=canvas, directions=[d])
            core.require_complete_pose_regions(ROOT / raw, g)
            rec.update(status='GEOMETRY_PASS_ONLY', geometry=g, canvas_size=canvas)
            if not selected:
                rec.update(status='PRESERVED_SUPERSEDED_HOLD', reason=REASONS.get((d, role), 'Superseded immutable trial'))
            else:
                texture = FOLDER / (q['name'] + '.png')
                preserve(ROOT / texture, (ROOT / raw).read_bytes())
                for f in g['frames']:
                    assert f['rgba_sha256'] not in fingerprints, 'Repeated visible frame: ' + q['name']
                    fingerprints.add(f['rgba_sha256'])
                roles = q.get('roles', {role: list(range(q['rows']))})
                for action, phases in roles.items():
                    part = deepcopy(g)
                    part['frames'] = [f for f in g['frames'] if f['row'] in phases]
                    assert len(part['frames']) == len(phases)
                    part['distinct_pixel_frames'] = len(phases)
                    tracks.append({'direction': d, 'role': action,
                                   'animation': action + '_' + str(core.DIRECTIONS.index(d)),
                                   'source': raw.as_posix(), 'source_sha256': rec['sha256'],
                                   'texture': texture.as_posix(), 'geometry': part})
        except ValueError as error:
            rec.update(status='SOURCE_HOLD', reason=str(error))
        records.append(rec)
    expected = {(d, r) for r in ('idle', 'run', 'attack', 'hit') for d in core.DIRECTIONS} | {('S', 'death')}
    available = {(t['direction'], t['role']) for t in tracks}
    assert len(available) == len(tracks), 'Duplicate track selection'
    frames = FOLDER / 'SpriteFrames.tres'
    preserve(ROOT / frames, frames_bytes(tracks))
    profile = FOLDER / 'NativeMotionProfile.tres'
    body = '\n'.join([
        '[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', '',
        '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', '',
        '[resource]', 'script = ExtResource("1")', f'profile_id = "{KEY}"',
        f'frames_path = "res://{frames.as_posix()}"', 'layout = "directional8"',
        'movement_fps = 12.5', 'reference_speed = 210.0', 'pixel_scale = 2.0',
        'sprite_offset = Vector2(0, -64)', 'authored_motion_weight = 0.0',
        'hit_recoil = 0.0', 'embedded_shadow = false', 'body_kind = "humanoid"',
        'attack_hit_frame = 1', 'action_hit_frames = {"attack": 1}', 'death_duration = 0.65',
        'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', ''])
    preserve(ROOT / profile, body.encode())
    actor = {
        'kind': 'boss', 'quality_tier': 'mythic_transform',
        'frames': 'res://' + frames.as_posix(), 'frames_sha256': core.sha(ROOT / frames),
        'native_profile': 'res://' + profile.as_posix(), 'native_profile_sha256': core.sha(ROOT / profile),
        'production_connected': False, 'detailed_completed': False,
        'native_track_count': len(tracks), 'native_pose_count': sum(len(t['geometry']['frames']) for t in tracks),
        'missing_required_tracks': [f'{r}_{core.DIRECTIONS.index(d)}' for d, r in sorted(expected-available)],
        'quality_review': 'HOLD: dedicated repair candidate; source geometry/playback cannot grant mythic/Main approval. See visual-review.json for actual observations and remaining holds.',
        'reference_pin': json.loads((ROOT / BATCH / 'reference-pin.json').read_text()),
        'distinct_source_pose_count': len(fingerprints), 'tracks': tracks,
    }
    register = {'schema': 'pr122-monster-staging-v1', 'batch': BATCH.as_posix(), 'actors': {KEY: actor},
                'family_adapters': {}, 'new_approvals': 0, 'default_catalog_switches': 0,
                'source_pixel_edits': 0, 'mirrored_source_poses': 0, 'duplicated_source_poses': 0,
                'new_walk_sources': 0, 'old_approved_assets_preserved': True,
                'reference_scope': 'Existing project atlas art; external original-game authenticity not established',
                'appearance_choice': 'Reference crop shows empty fists and attached chains. DB fallback weapon=axe is not visible in the project reference; no new axe invented.'}
    preserve(ROOT / BATCH / 'candidate.json', json_bytes(register))
    preserve(ROOT / BATCH / 'source-checks.json', json_bytes(records))
    print(json.dumps({'clips': len(tracks), 'poses': actor['native_pose_count'], 'unique_poses': len(fingerprints),
                      'missing_tracks': len(expected-available), 'source_holds': sum(x['status']=='SOURCE_HOLD' for x in records),
                      'superseded_sources': sum(x['status']=='PRESERVED_SUPERSEDED_HOLD' for x in records), 'new_approvals': 0}))


if __name__ == '__main__':
    build()
