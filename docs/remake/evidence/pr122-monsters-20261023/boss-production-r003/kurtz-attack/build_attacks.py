#!/usr/bin/env python3
"""Append real attack art without changing any existing animation token."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
COMPASS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def preserve(path, data):
    if path.exists():
        assert path.read_bytes() == data, 'Choose a new revision: ' + str(path)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--directions', required=True)
    parser.add_argument('--revision', required=True)
    args = parser.parse_args()
    directions = args.directions.split(',')
    prior = ROOT / 'docs/remake/evidence/pr122-monsters-20261023/boss-fix09-kurtz/candidate.json'
    actor = deepcopy(json.loads(prior.read_text())['actors']['monster:커츠'])
    original_frames = (ROOT / actor['frames'].removeprefix('res://')).read_text()
    original_profile = (ROOT / actor['native_profile'].removeprefix('res://')).read_text()
    existing_names = {track['animation'] for track in actor['tracks']}
    ext, resources, animations, tracks = [], [], [], []
    for direction in directions:
        animation = 'attack_' + str(COMPASS.index(direction))
        assert animation not in existing_names
        folder = HERE / ('single' if direction == 'E' else 'single-' + direction)
        frames, sheets, poses = [], [], []
        for phase in range(4):
            record = json.loads((folder / f'phase{phase}-checks.json').read_text())
            assert record['status'] == 'STRICT_GEOMETRY_PASS', record
            source = ROOT / record['source']
            assert sha(source) == record['sha256']
            texture = ROOT / f'assets/actors/eight_direction/monster_boss_repair/kurtz/production-r003/sources/{direction}-attack-phase{phase}.png'
            preserve(texture, source.read_bytes())
            key = f'new_{direction}_{phase}'
            ext += ['', f'[ext_resource type="Texture2D" path="res://{texture.relative_to(ROOT)}" id="{key}"]']
            frame = deepcopy(record['geometry']['frames'][0])
            frame.update(row=phase, texture=texture.relative_to(ROOT).as_posix(), source=record['source'],
                         source_sha256=record['sha256'], physical_source_row=0,
                         source_canvas_size=record['geometry']['canvas_size'])
            frames.append(frame)
            resources += ['', f'[sub_resource type="AtlasTexture" id="{key}"]', f'atlas = ExtResource("{key}")',
                          'region = Rect2(%s)' % ', '.join(map(str, frame['region'])),
                          'margin = Rect2(%s)' % ', '.join(map(str, frame['margin'])), 'filter_clip = true']
            poses.append('{"duration": 1.0, "texture": SubResource("%s")}' % key)
            sheets.append(dict(source=record['source'], sha256=record['sha256'], texture=frame['texture']))
        animations.append('{"frames": [%s], "loop": false, "name": &"%s", "speed": 9.523809524}' % (',\n'.join(poses), animation))
        tracks.append(dict(direction=direction, role='attack', animation=animation, multi_source=True,
                           source=sheets[0]['source'], source_sha256=sheets[0]['sha256'], texture=sheets[0]['texture'],
                           source_sheets=sheets, geometry=dict(frames=frames),
                           source_review='PENDING_ACCUMULATED_VISUAL_REVIEW', production_connected=False))
    match = re.search(r'animations = \[(.*?)\n\]', original_frames, re.S)
    assert match
    text = original_frames[:match.start(1)] + match.group(1).rstrip() + ',\n' + ',\n'.join(animations) + original_frames[match.end(1):]
    pos = text.index('[sub_resource')
    text = text[:pos] + '\n'.join(ext) + '\n\n' + text[pos:]
    pos = text.index('[resource]')
    text = text[:pos] + '\n'.join(resources) + '\n\n' + text[pos:]
    text = re.sub(r'load_steps=(\d+)', lambda m: 'load_steps=' + str(int(m[1]) + len(directions) * 8), text, count=1)
    out = ROOT / 'assets/actors/eight_direction/monster_boss_repair/kurtz' / args.revision
    frames_path = out / 'SpriteFrames.tres'
    profile_path = out / 'NativeMotionProfile.tres'
    preserve(frames_path, text.encode())
    preserve(profile_path, original_profile.replace(actor['frames'], 'res://' + frames_path.relative_to(ROOT).as_posix()).encode())
    actor['tracks'].extend(tracks)
    actor.update(frames='res://' + frames_path.relative_to(ROOT).as_posix(), frames_sha256=sha(frames_path),
                 native_profile='res://' + profile_path.relative_to(ROOT).as_posix(), native_profile_sha256=sha(profile_path),
                 native_track_count=len(actor['tracks']), native_pose_count=sum(len(t['geometry']['frames']) for t in actor['tracks']),
                 production_connected=False, detailed_completed=False,
                 quality_review='AUTHORING_IN_PROGRESS: real new attack poses appended; original tracks and timing preserved. Dedicated-source visual review remains pending; no approval or default switch.')
    actor['missing_required_tracks'] = sorted(set(actor['missing_required_tracks']) - {t['animation'] for t in tracks})
    actor['new_source_track_count'] = len(tracks)
    actor['new_source_poses'] = len(tracks) * 4
    actor['prior_revision_source_poses_reused'] = 58
    actor['prior_revision_tracks_reused'] = 17
    actor['excluded_prior_tracks_are_source_specific'] = True
    actor['previous_revision_quality_findings'] = actor.pop('quality_findings', [])
    actor['quality_findings'] = [
        dict(criterion='authored_attack_coverage', result='TECHNICAL_SOURCE_FRAMES_CREATED',
             observation='Four dedicated RGBA poses per new attack; old source-specific exclusions remain preserved.'),
        dict(criterion='accumulated_visual_review', result='PENDING',
             observation='Technical region/canvas/PNG checks do not grant mythic identity, gait, weapon-contact or final production approval.')]
    actor['distinct_source_pose_count'] = len({f['rgba_sha256'] for t in actor['tracks'] for f in t['geometry']['frames']})
    evidence = HERE / args.revision
    evidence.mkdir(exist_ok=True)
    candidate = dict(schema='pr122-boss-repair-staging-v1', batch=evidence.relative_to(ROOT).as_posix(),
                     new_approvals=0, default_catalog_switches=0, actors={'monster:커츠': actor})
    preserve(evidence / 'candidate.json', (json.dumps(candidate, ensure_ascii=False, indent=2) + '\n').encode())
    print(json.dumps(dict(revision=args.revision, clips=actor['native_track_count'], poses=actor['native_pose_count'],
                          new_attacks=len(tracks), missing=len(actor['missing_required_tracks'])), ensure_ascii=False))


if __name__ == '__main__':
    main()
