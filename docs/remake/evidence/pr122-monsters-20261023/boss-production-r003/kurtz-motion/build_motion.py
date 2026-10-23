#!/usr/bin/env python3
"""Add complete dedicated idle/run/hit tracks while preserving prior clips."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
COMPASS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def put(path, data):
    if path.exists():
        assert path.read_bytes() == data, 'Use a new revision: ' + str(path)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--directions', required=True)
    p.add_argument('--revision', required=True)
    a = p.parse_args()
    base = HERE.parent / 'kurtz-attack/r010/candidate.json'
    actor = deepcopy(json.loads(base.read_text())['actors']['monster:커츠'])
    original = (ROOT / actor['frames'].removeprefix('res://')).read_text()
    profile = (ROOT / actor['native_profile'].removeprefix('res://')).read_text()
    tracks, ext, resources, animations = [], [], [], []
    for direction in a.directions.split(','):
        for role, count, seconds in [('idle', 2, 1.2), ('run', 6, .48), ('hit', 2, .22)]:
            folder = HERE / direction / role
            geometry, sheets, poses = [], [], []
            for phase in range(count):
                record = json.loads((folder / f'phase{phase}-checks.json').read_text())
                assert record['status'] == 'STRICT_GEOMETRY_PASS'
                source = ROOT / record['source']
                assert sha(source) == record['sha256']
                texture = ROOT / f'assets/actors/eight_direction/monster_boss_repair/kurtz/production-r003/sources/{direction}-{role}-phase{phase}-v{record["version"]:02}.png'
                put(texture, source.read_bytes())
                key = f'motion_{direction}_{role}_{phase}'
                ext += ['', f'[ext_resource type="Texture2D" path="res://{texture.relative_to(ROOT)}" id="{key}"]']
                frame = deepcopy(record['geometry']['frames'][0])
                frame.update(row=phase, texture=texture.relative_to(ROOT).as_posix(), source=record['source'],
                             source_sha256=record['sha256'], physical_source_row=0,
                             source_canvas_size=record['geometry']['canvas_size'])
                geometry.append(frame)
                resources += ['', f'[sub_resource type="AtlasTexture" id="{key}"]', f'atlas = ExtResource("{key}")',
                              'region = Rect2(%s)' % ', '.join(map(str, frame['region'])),
                              'margin = Rect2(%s)' % ', '.join(map(str, frame['margin'])), 'filter_clip = true']
                poses.append('{"duration": 1.0, "texture": SubResource("%s")}' % key)
                sheets.append(dict(source=record['source'], source_sha256=record['sha256'], texture=frame['texture']))
            name = f'{role}_{COMPASS.index(direction)}'
            assert name in actor['missing_required_tracks']
            animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.9f}' %
                              (',\n'.join(poses), str(role in ('idle', 'run')).lower(), name, count / seconds))
            tracks.append(dict(direction=direction, role=role, animation=name, multi_source=True,
                               source=sheets[0]['source'], source_sha256=sheets[0]['source_sha256'],
                               texture=sheets[0]['texture'], source_sheets=sheets, geometry=dict(frames=geometry),
                               quality_review='PENDING_ACCUMULATED_VISUAL_REVIEW', production_connected=False))
    match = re.search(r'animations = \[(.*?)\n\]', original, re.S)
    assert match
    text = original[:match.start(1)] + match.group(1).rstrip() + ',\n' + ',\n'.join(animations) + original[match.end(1):]
    pos = text.index('[sub_resource')
    text = text[:pos] + '\n'.join(ext) + '\n\n' + text[pos:]
    pos = text.index('[resource]')
    text = text[:pos] + '\n'.join(resources) + '\n\n' + text[pos:]
    added_poses = sum(len(t['geometry']['frames']) for t in tracks)
    text = re.sub(r'load_steps=(\d+)', lambda m: 'load_steps=' + str(int(m[1]) + added_poses * 2), text, count=1)
    out = ROOT / 'assets/actors/eight_direction/monster_boss_repair/kurtz' / a.revision
    frames, native = out / 'SpriteFrames.tres', out / 'NativeMotionProfile.tres'
    put(frames, text.encode())
    put(native, profile.replace(actor['frames'], 'res://' + frames.relative_to(ROOT).as_posix()).encode())
    actor['tracks'].extend(tracks)
    actor.update(frames='res://' + frames.relative_to(ROOT).as_posix(), frames_sha256=sha(frames),
                 native_profile='res://' + native.relative_to(ROOT).as_posix(), native_profile_sha256=sha(native),
                 native_track_count=len(actor['tracks']), native_pose_count=sum(len(t['geometry']['frames']) for t in actor['tracks']),
                 new_source_track_count=7 + len(tracks), new_source_poses=28 + added_poses,
                 production_connected=False, detailed_completed=False,
                 quality_review='Dedicated source authoring continues. Entire PNGs and prior animation timing preserved; mythic identity/gait/contact review is pending, no new approval/default switch.')
    actor['missing_required_tracks'] = sorted(set(actor['missing_required_tracks']) - {t['animation'] for t in tracks})
    actor['distinct_source_pose_count'] = len({f['rgba_sha256'] for t in actor['tracks'] for f in t['geometry']['frames']})
    evidence = HERE / a.revision
    evidence.mkdir(exist_ok=True)
    put(evidence / 'candidate.json', (json.dumps(dict(schema='pr122-boss-repair-staging-v1', batch=evidence.relative_to(ROOT).as_posix(),
        actors={'monster:커츠': actor}, new_approvals=0, default_catalog_switches=0), ensure_ascii=False, indent=2) + '\n').encode())
    print(json.dumps(dict(revision=a.revision, clips=actor['native_track_count'], poses=actor['native_pose_count'],
                         missing=len(actor['missing_required_tracks']), new_motion_tracks=len(tracks))))


if __name__ == '__main__':
    main()
