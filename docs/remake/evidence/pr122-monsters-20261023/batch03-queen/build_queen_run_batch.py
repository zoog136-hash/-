"""Preserve and stage six dedicated queen RUN sources without approving art."""
import hashlib
import json
from pathlib import Path
import statistics
import sys

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/batch03-queen')
FOLDER = Path('assets/actors/eight_direction/monster_staging/ice_queen/batch03/r001')
REGISTER = Path('data/pr122_monster_queen_run_staging.json')
DIRECTIONS = ['SE', 'SW', 'W', 'NW', 'N', 'NE']


def put(path, data):
    if path.exists():
        assert path.read_bytes() == data, 'Preserve previous output; use a new revision: ' + str(path)
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def jb(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def build():
    tracks, checks = [], []
    manifest_path = ROOT / BATCH / 'file-manifest.json'
    pins = {row['path']: row['sha256'] for row in json.loads(manifest_path.read_text())['files']} if manifest_path.exists() else {}
    for direction in DIRECTIONS:
        name = f'queen-{direction}-run6-v01'
        request = json.loads((ROOT / BATCH / 'requests' / (name + '.json')).read_text())
        raw = BATCH / 'raw' / (name + '.png')
        original = Path(request['image_path'])
        if original.is_file():
            put(ROOT / raw, original.read_bytes())
        else:
            assert (ROOT / raw).is_file(), 'Missing durable generated PNG: ' + str(raw)
        if raw.as_posix() in pins:
            assert core.sha(ROOT / raw) == pins[raw.as_posix()], 'Preserved raw source changed'
        check = dict(name=name, direction=direction, source=raw.as_posix(), sha256=core.sha(ROOT / raw),
                     rows=6, directions_axis='phase_grid2', reference_rows=[0, 3])
        try:
            geometry = core.analyze(ROOT / raw, 6, [0, 3], directions_axis='phase_grid2',
                                    canvas_size=2048, directions=[direction])
            core.require_complete_pose_regions(ROOT / raw, geometry)
            check.update(status='GEOMETRY_PASS_ONLY', geometry=geometry)
            # Retain the small-canvas failure as a separate calibration result.
            small_canvas = max(64, round(geometry['neutral_height'] * 256 / 140 / 8) * 8)
            try:
                small = core.analyze(ROOT / raw, 6, [0, 3], directions_axis='phase_grid2',
                                     canvas_size=small_canvas, directions=[direction])
                core.require_complete_pose_regions(ROOT / raw, small)
                check['prior_140px_calibration'] = {'status': 'GEOMETRY_PASS_ONLY', 'canvas_size': small_canvas}
            except ValueError as error:
                check['prior_140px_calibration'] = {'status': 'HOLD', 'canvas_size': small_canvas, 'reason': str(error)}
            check['source_quality'] = 'HOLD: canonical identity, absolute camera, support exchange, flight source-plane anchors and inter-source anatomy/scale need independent review'
            texture = FOLDER / f'{direction}-run.png'
            put(ROOT / texture, (ROOT / raw).read_bytes())
            tracks.append(dict(direction=direction, role='run', animation='run_' + str(core.DIRECTIONS.index(direction)),
                               source=raw.as_posix(), texture=texture.as_posix(),
                               source_sha256=check['sha256'], geometry=geometry))
        except ValueError as error:
            check.update(status='SOURCE_HOLD', reason=str(error))
        checks.append(check)
    assert tracks, 'No source may be replaced by a fallback'
    count = sum(len(t['geometry']['frames']) for t in tracks)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={count + len(tracks) + 1} format=3]']
    for i, track in enumerate(tracks):
        lines += ['', f'[ext_resource type="Texture2D" path="res://{track["texture"]}" id="{i + 1}"]']
    animations = []
    for i, track in enumerate(tracks):
        for j, frame in enumerate(track['geometry']['frames']):
            lines += ['', f'[sub_resource type="AtlasTexture" id="pose_{i}_{j}"]',
                      f'atlas = ExtResource("{i + 1}")',
                      'region = Rect2(%s)' % ', '.join(map(str, frame['region'])),
                      'margin = Rect2(%s)' % ', '.join(map(str, frame['margin'])), 'filter_clip = true']
        poses = ',\n'.join('{"duration": 1.0, "texture": SubResource("pose_%d_%d")}' % (i, j) for j in range(6))
        animations.append('{"frames": [%s], "loop": true, "name": &"%s", "speed": 12.5}' % (poses, track['animation']))
    lines += ['', '[resource]', 'animations = [\n' + ',\n'.join(animations) + '\n]',
              'metadata/twilight_canvas_size = Vector2(256, 256)',
              'metadata/twilight_native_locomotion_staging = true',
              'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', '']
    frames = FOLDER / 'SpriteFrames.tres'
    put(ROOT / frames, '\n'.join(lines).encode())
    # ONE shared physical scale for all six views. This calibration is a staging
    # measurement, not per-direction deformation or a boss quality approval.
    normalized_heights = [track['geometry']['neutral_height'] * 256 / 2048 for track in tracks]
    reference_height = statistics.median(normalized_heights)
    scale = 86 / reference_height
    profile = FOLDER / 'NativeMotionProfile.tres'
    lines = ['[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', '',
             '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', '',
             '[resource]', 'script = ExtResource("1")', 'profile_id = "monster:얼음 여왕"',
             f'frames_path = "res://{frames.as_posix()}"', 'layout = "directional8"',
             'movement_fps = 12.5', 'reference_speed = 210.0', f'pixel_scale = {scale:.12f}',
             f'sprite_offset = Vector2(0, {-32 * scale:.12f})', 'authored_motion_weight = 0.0',
             'hit_recoil = 0.0', 'embedded_shadow = false',
             'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', '']
    put(ROOT / profile, '\n'.join(lines).encode())
    actor = dict(kind='boss', quality_tier='mythic_transform', frames='res://' + frames.as_posix(),
                 frames_sha256=core.sha(ROOT / frames), native_profile='res://' + profile.as_posix(),
                 native_profile_sha256=core.sha(ROOT / profile), production_connected=False, detailed_completed=False,
                 native_track_count=len(tracks), native_pose_count=count, tracks=tracks,
                 canvas_size=[2048, 2048], foot=[1024, 1280],
                 sizing=dict(method='ONE_common_uniform_scale_from_median_native_height',
                             normalized_neutral_heights=normalized_heights, shared_reference_height=reference_height,
                             pixel_scale=scale, visual_approval='HOLD',
                             note='Existing E/S r002 body sizing is not automatically merged or approved.'),
                 quality_review='HOLD: dedicated new text-brief art; source geometry or playback never grants identity/contact/appearance approval')
    register = {'schema': 'pr122-queen-directional-run-staging-v1', 'batch': BATCH.as_posix(),
                'actors': {'monster:얼음 여왕': actor}, 'new_approvals': 0, 'default_catalog_switches': 0,
                'previous_E_S_batch01_preserved': True, 'total_boss_completion': False}
    put(ROOT / REGISTER, jb(register))
    put(ROOT / BATCH / 'source-checks.json', jb(checks))
    files = []
    for directory in [ROOT / BATCH / 'raw', ROOT / BATCH / 'requests', ROOT / FOLDER]:
        for path in sorted(directory.rglob('*')):
            if path.is_file():
                files.append({'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size,
                              'sha256': core.sha(path)})
    put(ROOT / BATCH / 'file-manifest.json', jb({'schema': 1, 'files': files,
        'new_sources': len(checks), 'new_selected_clips': len(tracks), 'new_selected_poses': count,
        'newly_approved': 0, 'pixels': 'Exact generated PNG bytes; no pixel edits, palette swaps, mirrors, crops or re-sampling'}))
    print(json.dumps({'queen_RUN_clips': len(tracks), 'poses': count, 'strict2048_geometry_pass': len(tracks),
                      'source_holds': len(checks) - len(tracks), 'small_140px_calibration_holds': sum(c.get('prior_140px_calibration', {}).get('status') == 'HOLD' for c in checks),
                      'new_approvals': 0}))


if __name__ == '__main__':
    build()
