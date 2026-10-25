#!/usr/bin/env python3
"""Replace only N idle artwork; keep every other pose and timing intact."""
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core

parser_path = ROOT / 'docs/remake/evidence/pr122-monsters-20261023/boss-fix06-queen-n/combined-output/combine_latest.py'
spec = importlib.util.spec_from_file_location('queen_frozen_reader', parser_path)
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def put(path, data):
    if path.exists():
        assert path.read_bytes() == data, 'Choose a new revision: ' + str(path)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def main():
    prior = ROOT / 'docs/remake/evidence/pr122-monsters-20261023/boss-fix06-queen-n/combined-output/candidate.json'
    actor = deepcopy(json.loads(prior.read_text())['actors']['monster:얼음 여왕'])
    old_frames = ROOT / actor['frames'].removeprefix('res://')
    animations = reader.parse_frames(old_frames)
    original = deepcopy(animations)
    geometry, sheets = [], []
    # Helm-crest landmarks reviewed on the original source. Sole positions
    # are measured from both boot components, excluding the cape/staff.
    landmarks = [(192, 1155, 596), (204, 1143, 572)]
    for phase, (crest, sole, center) in enumerate(landmarks):
        raw = HERE / f'raw/N-idle-phase{phase}.png'
        checked = core.analyze(raw, 1, [0], directions_axis='columns', canvas_size=2048,
                               source_anchors=[[center, sole]], directions=['N'])
        core.require_complete_pose_regions(raw, checked)
        canvas = max(64, round((sole - crest) * 256 / 140 / 8) * 8)
        checked = core.analyze(raw, 1, [0], directions_axis='columns', canvas_size=canvas,
                               source_anchors=[[center, sole]], directions=['N'])
        core.require_complete_pose_regions(raw, checked)
        texture = ROOT / f'assets/actors/eight_direction/monster_boss_repair/ice_queen/combat-r003/N-idle-phase{phase}.png'
        put(texture, raw.read_bytes())
        frame = deepcopy(checked['frames'][0])
        frame.update(row=phase, physical_source_row=0, source=raw.relative_to(ROOT).as_posix(), source_sha256=sha(raw),
                     texture=texture.relative_to(ROOT).as_posix(), source_canvas_size=[canvas, canvas],
                     reviewed_helm_crest_y=crest, reviewed_boot_sole_y=sole)
        geometry.append(frame)
        body = '\n'.join(['atlas = ExtResource("new")',
                           'region = Rect2(%s)' % ', '.join(map(str, frame['region'])),
                           'margin = Rect2(%s)' % ', '.join(map(str, frame['margin'])), 'filter_clip = true', ''])
        source_frame = animations['idle_6']['frames'][phase]
        source_frame.update(ext='new', texture='res://' + frame['texture'], region=frame['region'], margin=frame['margin'], body=body)
        sheets.append(dict(source=frame['source'], source_sha256=frame['source_sha256'], texture=frame['texture']))
    assert all(animations[name] == original[name] for name in animations if name != 'idle_6')
    texture_ids, ext, resources, clips = {}, [], [], []
    serial = 0
    for name, animation in animations.items():
        poses = []
        assert animation['speed_token'] == original[name]['speed_token'] and animation['loop_token'] == original[name]['loop_token']
        for frame in animation['frames']:
            texture = frame['texture']
            if texture not in texture_ids:
                texture_ids[texture] = str(len(texture_ids) + 1)
                ext += ['', f'[ext_resource type="Texture2D" path="{texture}" id="{texture_ids[texture]}"]']
            key = f'queen_pose_{serial}'
            serial += 1
            body = frame['body'].replace(f'ExtResource("{frame["ext"]}")', f'ExtResource("{texture_ids[texture]}")')
            resources += ['', f'[sub_resource type="AtlasTexture" id="{key}"]', body.rstrip()]
            poses.append('{"duration": %s, "texture": SubResource("%s")}' % (frame['duration_token'], key))
        clips.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}' %
                     (',\n'.join(poses), animation['loop_token'], name, animation['speed_token']))
    text = '\n'.join([f'[gd_resource type="SpriteFrames" load_steps={serial + len(texture_ids) + 1} format=3]',
                      *ext, *resources, '', '[resource]', 'animations = [\n' + ',\n'.join(clips) + '\n]',
                      'metadata/twilight_canvas_size = Vector2(256, 256)',
                      'metadata/twilight_native_locomotion_staging = true',
                      'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', ''])
    out = ROOT / 'assets/actors/eight_direction/monster_boss_repair/ice_queen/combined-r003'
    frames_path, native_path = out / 'SpriteFrames.tres', out / 'NativeMotionProfile.tres'
    put(frames_path, text.encode())
    profile = (ROOT / actor['native_profile'].removeprefix('res://')).read_text()
    put(native_path, profile.replace(actor['frames'], 'res://' + frames_path.relative_to(ROOT).as_posix()).encode())
    track = next(t for t in actor['tracks'] if t['animation'] == 'idle_6')
    track.update(source=sheets[0]['source'], source_sha256=sheets[0]['source_sha256'], texture=sheets[0]['texture'],
                 multi_source=True, source_sheets=sheets, geometry=dict(frames=geometry),
                 source_visual_first_pass='PASS: both BACK poses keep RIGHT bare thigh viewer-right and LEFT staff/covered leg viewer-left.')
    actor.update(frames='res://' + frames_path.relative_to(ROOT).as_posix(), frames_sha256=sha(frames_path),
                 native_profile='res://' + native_path.relative_to(ROOT).as_posix(), native_profile_sha256=sha(native_path),
                 production_connected=False, detailed_completed=False,
                 quality_review='N IDLE costume-side swap repaired with two new dedicated source poses; exact 32 other clips/106 poses and all timing retained. Full mythic acceptance remains separate.')
    actor['distinct_source_pose_count'] = len({f['rgba_sha256'] for t in actor['tracks'] for f in t['geometry']['frames']})
    assert actor['native_track_count'] == 33 and actor['native_pose_count'] == actor['distinct_source_pose_count'] == 108
    put(HERE / 'candidate.json', (json.dumps(dict(schema='pr122-boss-repair-staging-v1', actors={'monster:얼음 여왕': actor},
        new_approvals=0, default_catalog_switches=0), ensure_ascii=False, indent=2) + '\n').encode())
    put(HERE / 'source-review.json', (json.dumps(dict(scope='N_IDLE two source poses only', visual_first_pass='PASS',
        both_frames_BACK=True, RIGHT_bare_thigh_viewer_RIGHT=True, LEFT_staff_and_covered_leg_viewer_LEFT=True,
        severe_clipping_or_body_break=False, timing_33_preserved=True, other_106_source_poses_preserved=True,
        body_registration_landmarks=landmarks, new_approvals=0), ensure_ascii=False, indent=2) + '\n').encode())
    print(json.dumps(dict(clips=33, poses=108, new_idle_poses=2, other_106_RGBA_preserved=True, animation_timing_preserved=33)))


if __name__ == '__main__':
    main()
