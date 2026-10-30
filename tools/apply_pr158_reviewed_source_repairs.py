"""Install a reviewed source-repair batch without changing any prior resource.

The explicit plan is an input, not an automatic visual-approval mechanism.
Image authoring happens outside this tool. Pixels are copied byte-for-byte.
"""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path

from import_original_based_motion import analyze, require_complete_pose_regions
from stage_pr122_native_locomotion import build_frames


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def apply(root, plan_path):
    plan = json.loads(plan_path.read_text())
    register_path = root / 'data/pr122_native_locomotion_staging.json'
    before = json.loads(register_path.read_text())
    after = deepcopy(before)
    prepared = []
    for repair in plan['repairs']:
        assert repair['specific_defect_review'] == 'PASS'
        actor = after['actors'][repair['id']]
        assert actor['grade'] == '신화'
        track = next(t for t in actor['tracks'] if t['animation'] == repair['clip'])
        assert track['source_sha256'] == repair['prior_texture_sha256']
        source = root / repair['source']
        assert digest(source) == repair['source_sha256']
        geometry = analyze(source, rows_count=6, directions_axis=repair['directions_axis'],
                           canvas_size=1024, directions=[track['direction']])
        require_complete_pose_regions(source, geometry)
        assert geometry['distinct_pixel_frames'] == 6
        old_track = deepcopy(track)
        track.update(source=repair['source'], texture=repair['source'],
                     source_sha256=repair['source_sha256'], geometry=geometry)
        track['pr158_source_repair'] = dict(prior=old_track,
            specific_defect=repair['defect'], final_quality_approval=False,
            source_pixels_resampled=False)
        prepared.append(dict(id=repair['id'], clip=repair['clip'],
                             source_sha256=repair['source_sha256']))
    preserved = {}
    for key in sorted({r['id'] for r in prepared}):
        old = before['actors'][key]
        actor = after['actors'][key]
        old_frames = root / old['frames'].removeprefix('res://')
        old_profile = root / old['native_profile'].removeprefix('res://')
        assert old_frames.read_bytes() == build_frames(old['tracks'])
        assert digest(old_frames) == old['frames_sha256']
        assert digest(old_profile) == old['native_profile_sha256']
        folder = old_frames.parent.parent / plan['version']
        assert not folder.exists(), 'Never overwrite a prior revision'
        folder.mkdir()
        frames = folder / 'SpriteFrames.tres'
        profile = folder / 'NativeMotionProfile.tres'
        frames.write_bytes(build_frames(actor['tracks']))
        new_ref = 'res://' + frames.relative_to(root).as_posix()
        profile.write_text(old_profile.read_text().replace(old['frames'], new_ref))
        actor.update(frames=new_ref, frames_sha256=digest(frames),
            native_profile='res://' + profile.relative_to(root).as_posix(),
            native_profile_sha256=digest(profile))
        actor['pr158_source_repair_status'] = 'SPECIFIC_DEFECT_FIXED; runtime and final quality gates separate'
        preserved[key] = {str(p.relative_to(root)): digest(p) for p in (old_frames, old_profile)}
    register_path.write_text(json.dumps(after, ensure_ascii=False, indent=2) + '\n')
    return dict(repairs=prepared, prior_resources_preserved=preserved,
                new_final_approvals=0, production_catalog_changes=0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--receipt', type=Path, required=True)
    args = parser.parse_args()
    result = apply(args.root.resolve(), args.plan.resolve())
    args.receipt.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
