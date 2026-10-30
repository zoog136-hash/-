"""Preserve prior boss resources while restoring six genuinely authored poses."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import re

from import_original_based_motion import analyze, require_complete_pose_regions


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def apply(root, plan):
    path = root / 'data/pr122_monster_boss_repair_staging.json'
    before = json.loads(path.read_text())
    after = deepcopy(before)
    resources = {}
    receipt = {'changed_clips': [], 'prior_resources': {}, 'new_final_approvals': 0}
    for repair in plan['repairs']:
        key = repair['id']
        actor = after['actors'][key]
        assert actor['kind'] == 'boss' and not actor['production_connected']
        index = next(i for i, t in enumerate(actor['tracks']) if t['animation'] == repair['clip'])
        old = deepcopy(actor['tracks'][index])
        assert len(old['geometry']['frames']) == 5
        source = root / repair['source']
        assert sha(source) == repair['source_sha256']
        assert repair['specific_defect_review'] == 'PASS'
        assert old['source_sha256'] == repair['prior_source_sha256']
        kwargs = dict(rows_count=6, directions_axis='phase_grid3', directions=[old['direction']])
        geometry = analyze(source, canvas_size=1024, **kwargs)
        # Preserve the existing reference body's rendered height without resampling pixels.
        canvas = round(old['geometry']['canvas_size'][0] * geometry['neutral_height'] / old['geometry']['neutral_height'] / 8) * 8
        geometry = analyze(source, canvas_size=canvas, **kwargs)
        require_complete_pose_regions(source, geometry)
        assert geometry['distinct_pixel_frames'] == 6
        track = {k: deepcopy(old[k]) for k in ['role', 'direction', 'animation']}
        track.update(source=repair['source'], texture=repair['source'],
                     source_sha256=repair['source_sha256'], geometry=geometry,
                     quality_review='SPECIFIC_WEAPON_DEFECT_FIXED; final quality remains HOLD',
                     production_connected=False, pr158_source_repair={'prior': old, 'final_quality_approval': False})
        actor['tracks'][index] = track
        for field in ['native_pose_count', 'distinct_source_pose_count']:
            actor[field] += 1
        if key not in resources:
            old_file = root / actor['frames'].removeprefix('res://')
            assert sha(old_file) == actor['frames_sha256']
            resources[key] = old_file.read_text()
        text = resources[key]
        old_ref = f'path="res://{old["texture"]}" id="{index+1}"'
        assert text.count(old_ref) == 1
        text = text.replace(old_ref, f'path="res://{repair["source"]}" id="{index+1}"')
        pattern = r'\[sub_resource type="AtlasTexture" id="draft_' + str(index) + r'_\d+"\]\n.*?(?=\n\[)'
        blocks = list(re.finditer(pattern, text, re.S))
        assert len(blocks) == 5
        new_blocks = []
        for phase, frame in enumerate(geometry['frames']):
            new_blocks.append(f'[sub_resource type="AtlasTexture" id="draft_{index}_{phase}"]\n'
                f'atlas = ExtResource("{index+1}")\n'
                + 'region = Rect2(%s)\n' % ', '.join(map(str, frame['region']))
                + 'margin = Rect2(%s)\n' % ', '.join(map(str, frame['margin']))
                + 'filter_clip = true\n')
        for pos in reversed(range(len(blocks))):
            match = blocks[pos]
            text = text[:match.start()] + ('\n'.join(new_blocks) if pos == 0 else '') + text[match.end():]
        pattern = r'\{"frames": \[\{"duration": 1\.0, "texture": SubResource\("draft_' + str(index) + r'_0"\)\}.*?"name": &"' + repair['clip'] + r'", "speed": ([0-9.]+)\}'
        match = re.search(pattern, text, re.S)
        assert match
        seconds = 5 / float(match[1])
        poses = ',\n'.join('{"duration": 1.0, "texture": SubResource("draft_%d_%d")}' % (index, phase) for phase in range(6))
        animation = '{"frames": [%s], "loop": false, "name": &"%s", "speed": %.9f}' % (poses, repair['clip'], 6 / seconds)
        text = text[:match.start()] + animation + text[match.end():]
        text = re.sub(r'load_steps=(\d+)', lambda m: 'load_steps=' + str(int(m[1])+1), text, count=1)
        resources[key] = text
        receipt['changed_clips'].append(dict(id=key, clip=repair['clip'], before_poses=5, after_poses=6,
            duration_seconds_preserved=seconds, canvas=canvas, pixels_resampled=False))
    for key, text in resources.items():
        actor = after['actors'][key]
        old = before['actors'][key]
        old_frames = root / old['frames'].removeprefix('res://')
        old_profile = root / old['native_profile'].removeprefix('res://')
        assert sha(old_profile) == old['native_profile_sha256']
        folder = old_frames.parent.parent / plan['version']
        assert not folder.exists()
        folder.mkdir()
        frames = folder / 'SpriteFrames.tres'
        profile = folder / 'NativeMotionProfile.tres'
        frames.write_text(text)
        ref = 'res://' + frames.relative_to(root).as_posix()
        profile.write_text(old_profile.read_text().replace(old['frames'], ref))
        actor.update(frames=ref, frames_sha256=sha(frames), native_profile='res://' + profile.relative_to(root).as_posix(), native_profile_sha256=sha(profile))
        receipt['prior_resources'][key] = {str(p.relative_to(root)): sha(p) for p in [old_frames, old_profile]}
    path.write_text(json.dumps(after, ensure_ascii=False, indent=2) + '\n')
    return receipt


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    p.add_argument('--plan', type=Path, required=True)
    p.add_argument('--receipt', type=Path, required=True)
    a = p.parse_args()
    a.receipt.write_text(json.dumps(apply(a.root.resolve(), json.loads(a.plan.read_text())), ensure_ascii=False, indent=2) + '\n')
