"""Reproduce the albino fishman candidate without approving or switching it."""
from pathlib import Path
from copy import deepcopy
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/batch04-normal-hold')
FOLDER = Path('assets/actors/eight_direction/monster_staging/batch04/albino_fishman/r001')
KEY = 'monster:알비노 피쉬맨'


def put(path, content):
    path = ROOT / path
    if path.exists() and path.read_bytes() != content:
        raise ValueError('Preserve prior bytes: ' + str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def jbytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def emit(tracks):
    count = sum(len(t['geometry']['frames']) for t in tracks)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={count + len(tracks) + 1} format=3]']
    for i, t in enumerate(tracks):
        lines += ['', f'[ext_resource type="Texture2D" path="res://{t["texture"]}" id="{i + 1}"]']
    animations = []
    seconds = dict(idle=1.2, run=.48, walk=.7, attack=.42, hit=.22, death=.65)
    for i, t in enumerate(tracks):
        for j, frame in enumerate(t['geometry']['frames']):
            lines += ['', f'[sub_resource type="AtlasTexture" id="p_{i}_{j}"]',
                      f'atlas = ExtResource("{i + 1}")',
                      'region = Rect2(%s)' % ', '.join(map(str, frame['region'])),
                      'margin = Rect2(%s)' % ', '.join(map(str, frame['margin'])), 'filter_clip = true']
        poses = ',\n'.join('{"duration": 1.0, "texture": SubResource("p_%d_%d")}' % (i, j)
                          for j in range(len(t['geometry']['frames'])))
        loop = str(t['role'] in ('idle', 'run', 'walk')).lower()
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.9f}' %
                          (poses, loop, t['animation'], len(t['geometry']['frames']) / seconds[t['role']]))
    lines += ['', '[resource]', 'animations = [\n' + ',\n'.join(animations) + '\n]',
              'metadata/twilight_canvas_size = Vector2(256, 256)',
              'metadata/twilight_native_locomotion_staging = true',
              'metadata/twilight_production_connected = false',
              'metadata/twilight_detailed_completed = false', '']
    return '\n'.join(lines).encode()


def build():
    anchors = json.loads((ROOT / BATCH / 'preserved-living/foot-anchor-drafts.json').read_text())
    draft = {row['role']: row for row in anchors['roles']}
    tracks, checks = [], []
    living = [('idle', 'idle-v2', 2, 'e3e139c73125dd8ea25fdec58cfb6be70cc9f67065f32119a70aa833bf51e411'),
              ('walk', 'walk-v2', 3, '24a8c236222ed8095dedaae3f7961714c78299dc0e021d8aca05e122a386d40f'),
              ('attack', 'attack-v2', 3, 'f99d86d3330a17e5c3bfd5feef968540a87a08ed5f6613ad3822c430868841d4'),
              ('hit', 'hit-v1', 2, '95a37da2b5467eea7f36c1bb3a99bd30b90393d1c3e721b2a4add38b5c7b2fb0')]
    new = json.loads((ROOT / BATCH / 'source-checks-v01.json').read_text())

    def install(name, source, rows, ds, axis, refs, role, anchors=None):
        initial = core.analyze(source, rows, refs, directions_axis=axis, canvas_size=2048,
                               directions=ds, source_anchors=anchors)
        core.require_complete_pose_regions(source, initial)
        # One source-wide proportional virtual canvas, no source resampling.
        canvas = max(64, round(initial['neutral_height'] * 256 / 95.75 / 8) * 8)
        geometry = core.analyze(source, rows, refs, directions_axis=axis, canvas_size=canvas,
                                directions=ds, source_anchors=anchors)
        core.require_complete_pose_regions(source, geometry)
        texture = FOLDER / (name + '.png')
        put(texture, source.read_bytes())
        check = dict(name=name, source=source.relative_to(ROOT).as_posix(), sha256=core.sha(source),
                     status='GEOMETRY_PASS_ONLY', canvas=canvas, geometry=geometry,
                     anchor_review='HOLD: preserved draft foot proposals for living; bbox anchors for new run/death are not reviewed anatomical support')
        checks.append(check)
        for d in ds:
            g = deepcopy(geometry)
            g['frames'] = [frame for frame in g['frames'] if frame['direction'] == d]
            g['distinct_pixel_frames'] = len(g['frames'])
            tracks.append(dict(role=role, direction=d, animation=role + '_' + str(core.DIRECTIONS.index(d)),
                               texture=texture.as_posix(), source=check['source'], source_sha256=check['sha256'],
                               geometry=g, source_kind='preserved_existing' if anchors else 'new_text_brief_source'))

    for role, name, rows, expected in living:
        source = ROOT / BATCH / 'preserved-living' / (name + '.png')
        assert core.sha(source) == expected
        proposed = draft[role]
        assert proposed['source_sha256'] == expected
        actual_anchors = [row['draft_source_anchor'] for row in proposed['anchors']]
        install(name, source, rows, core.DIRECTIONS, 'blocks4x2', [0, 1] if role != 'attack' else [2], role, actual_anchors)
    for record in new:
        assert record['status'] == 'GEOMETRY_PASS_ONLY'
        source = ROOT / record['path']
        assert core.sha(source) == record['sha256']
        install(record['name'], source, record['rows'], record['directions'], record['axis'],
                record['reference_rows'], 'death' if 'death' in record['name'] else 'run')
    required = {(d, role) for role in ('idle', 'run', 'attack', 'hit') for d in core.DIRECTIONS} | {('S', 'death')}
    assert required <= {(t['direction'], t['role']) for t in tracks}
    assert len(tracks) == 41
    assert sum(len(t['geometry']['frames']) for t in tracks if t['role'] != 'walk') == 91
    all_fingerprints = [f['rgba_sha256'] for t in tracks for f in t['geometry']['frames']]
    assert len(all_fingerprints) == len(set(all_fingerprints)) == 115
    frames = FOLDER / 'SpriteFrames.tres'
    put(frames, emit(tracks))
    scale = 86 / 95.75
    profile = FOLDER / 'NativeMotionProfile.tres'
    put(profile, ('\n'.join([
        '[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', '',
        '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', '',
        '[resource]', 'script = ExtResource("1")', f'profile_id = "{KEY}"',
        f'frames_path = "res://{frames.as_posix()}"', 'layout = "directional8"',
        'movement_fps = 8.333333333', 'reference_speed = 210.0', f'pixel_scale = {scale:.12f}',
        f'sprite_offset = Vector2(0, {-32 * scale:.12f})', 'authored_motion_weight = 0.0',
        'hit_recoil = 0.0', 'embedded_shadow = false', 'attack_hit_frame = 1',
        'action_hit_frames = {"attack": 1}', 'death_duration = 0.65',
        'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', ''])).encode())
    actor = dict(kind='normal', quality_tier='hero_transform', frames='res://' + frames.as_posix(),
                 frames_sha256=core.sha(ROOT / frames), native_profile='res://' + profile.as_posix(),
                 native_profile_sha256=core.sha(ROOT / profile), native_track_count=41, native_pose_count=115,
                 required_track_count=33, required_pose_count=91, preserved_walk_tracks=8,
                 production_connected=False, detailed_completed=False, tracks=tracks,
                 quality_review='HOLD: identity, foot support/contact, source-plane anchors and default Main quality remain unapproved')
    register = dict(schema='pr122-monster-staging-v1', batch=BATCH.as_posix(),
                    actors={KEY: actor}, new_approvals=0, default_catalog_switches=0)
    destination = ROOT / 'data/pr122_monster_hold_staging.json'
    if destination.exists():
        previous = json.loads(destination.read_text())
        if previous.get('family_adapters'):
            register['family_adapters'] = previous['family_adapters']
    put(Path('data/pr122_monster_hold_staging.json'), jbytes(register))
    put(BATCH / 'selected-source-checks.json', jbytes(checks))
    print('FISHMAN_STAGED required_clips=33 required_poses=91 preserved_walk_clips=8 total_clips=41 total_poses=115 approvals=0')


if __name__ == '__main__':
    build()
