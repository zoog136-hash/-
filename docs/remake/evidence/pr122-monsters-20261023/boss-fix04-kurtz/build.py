#!/usr/bin/env python3
"""Import only complete, separated generated Kurtz source sheets."""
import hashlib
import json
from pathlib import Path
import sys
from copy import deepcopy

ROOT = Path(__file__).resolve().parents[5]
BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import frames_bytes

OUT = ROOT / 'assets/actors/eight_direction/monster_boss_repair/kurtz/r001'
REF_HEIGHT = 96
DISPLAY_HEIGHT = 112
SPECS = [
    ('run-front4-v02', 6, 'columns', ['E', 'SE', 'S', 'SW'], [0, 3], {'run': list(range(6))}),
    ('run-back4-v01', 6, 'columns', ['W', 'NW', 'N', 'NE'], [0, 3], {'run': list(range(6))}),
    ('run-S6-v02', 6, 'phase_grid2', ['S'], [0, 3], {'run': list(range(6))}),
    ('combat-front4-v02', 8, 'columns', ['E', 'SE', 'S', 'SW'], [0, 1], {'idle': [0, 1], 'attack': [2, 3, 4, 5], 'hit': [6, 7]}),
    ('combat-back4-v02', 8, 'columns', ['W', 'NW', 'N', 'NE'], [0, 1], {'idle': [0, 1], 'attack': [2, 3, 4, 5], 'hit': [6, 7]}),
    ('death-S4-v01', 4, 'phase_grid2', ['S'], [0], {'death': [0, 1, 2, 3]}),
]


def relative(path):
    return path.relative_to(ROOT).as_posix()


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def dump(path, value):
    write(path, (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode())


def build():
    records, tracks = [], []
    for name, rows, axis, dirs, refs, roles in SPECS:
        source = BASE / 'raw' / (name + '.png')
        record = {'name': name, 'path': relative(source), 'directions': dirs,
                  'phase_count': rows, 'axis': axis, 'reference_phases': refs}
        if not source.exists():
            record.update(status='NOT_GENERATED')
            records.append(record)
            continue
        record.update(bytes=source.stat().st_size, sha256=core.sha(source))
        try:
            initial = core.analyze(source, rows, refs, directions_axis=axis,
                                   canvas_size=2048, directions=dirs)
            core.require_complete_pose_regions(source, initial)
            canvas = max(64, round(initial['neutral_height'] * 256 / REF_HEIGHT / 8) * 8)
            geometry = core.analyze(source, rows, refs, directions_axis=axis,
                                    canvas_size=canvas, directions=dirs)
            core.require_complete_pose_regions(source, geometry)
            # Use a source ground plane derived from contact phases. Airborne
            # source soles can remain above that plane; do not glue every boot
            # to its instantaneous visible bounding-box bottom.
            if axis == 'columns':
                cell_height = geometry['image_size'][1] / rows
                for direction in dirs:
                    contact = [frame for frame in geometry['frames']
                               if frame['direction'] == direction and frame['row'] in refs]
                    ground = round(sum(frame['source_anchor'][1] - frame['row'] * cell_height
                                       for frame in contact) / len(contact))
                    for frame in geometry['frames']:
                        if frame['direction'] != direction:
                            continue
                        x, y, w, h = frame['region']
                        anchor_x = frame['source_anchor'][0]
                        anchor_y = round(frame['row'] * cell_height + ground)
                        margin_x = canvas // 2 - (anchor_x - x)
                        margin_y = canvas * 5 // 8 - (anchor_y - y)
                        if min(margin_x, margin_y) < 0 or margin_x + w > canvas or margin_y + h > canvas:
                            raise ValueError('Reviewed source-plane anchor cannot fit the full pose canvas')
                        frame['source_anchor'] = [anchor_x, anchor_y]
                        frame['margin'] = [margin_x, margin_y, canvas - w, canvas - h]
                        frame['ground_plane_basis'] = {'contact_phases': refs, 'cell_relative_y': ground}
            elif axis == 'phase_grid2' and 'run' in roles:
                cell_height = geometry['image_size'][1] / ((rows + 1) // 2)
                ground_by_column = {}
                for phase in refs:
                    frame = next(frame for frame in geometry['frames'] if frame['row'] == phase)
                    ground_by_column[phase % 2] = frame['source_anchor'][1] - (phase // 2) * cell_height
                assert set(ground_by_column) == {0, 1}
                for frame in geometry['frames']:
                    x, y, w, h = frame['region']
                    anchor_x = frame['source_anchor'][0]
                    anchor_y = round((frame['row'] // 2) * cell_height + ground_by_column[frame['row'] % 2])
                    margin_x = canvas // 2 - (anchor_x - x)
                    margin_y = canvas * 5 // 8 - (anchor_y - y)
                    if min(margin_x, margin_y) < 0 or margin_x + w > canvas or margin_y + h > canvas:
                        raise ValueError('Single-view source ground plane cannot fit the full pose')
                    frame['source_anchor'] = [anchor_x, anchor_y]
                    frame['margin'] = [margin_x, margin_y, canvas - w, canvas - h]
                    frame['ground_plane_basis'] = {'contact_phases': refs, 'column_relative_y': ground_by_column}
            texture = OUT / (name + '.png')
            write(texture, source.read_bytes())
            assert core.sha(texture) == record['sha256']
            record.update(status='GEOMETRY_PASS_ONLY', geometry=geometry,
                          quality_review='Requires actual identity/direction/support/weight review; geometry is not mythic approval')
            for direction in dirs:
                if name.startswith('run-front4') and direction == 'S':
                    continue  # Dedicated S repair supersedes this sheet's S run.
                for role, phases in roles.items():
                    selected = [deepcopy(frame) for frame in geometry['frames']
                                if frame['direction'] == direction and frame['row'] in phases]
                    assert len(selected) == len(phases)
                    selected_geometry = {key: deepcopy(value) for key, value in geometry.items() if key != 'frames'}
                    selected_geometry['frames'] = selected
                    tracks.append({'direction': direction, 'role': role,
                                   'animation': role + '_' + str(core.DIRECTIONS.index(direction)),
                                   'source': relative(source), 'source_sha256': record['sha256'],
                                   'texture': relative(texture), 'geometry': selected_geometry})
        except ValueError as error:
            record.update(status='SOURCE_HOLD', reason=str(error))
        records.append(record)
    OUT.mkdir(parents=True, exist_ok=True)
    frames = OUT / 'SpriteFrames.tres'
    if tracks:
        write(frames, frames_bytes(tracks))
        profile = OUT / 'NativeMotionProfile.tres'
        scale = DISPLAY_HEIGHT / REF_HEIGHT
        text = '\n'.join([
            '[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', '',
            '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', '',
            '[resource]', 'script = ExtResource("1")', 'profile_id = "monster:커츠"',
            f'frames_path = "res://{relative(frames)}"', 'layout = "directional8"',
            'motion_style = "heavy"', 'body_kind = "armored"', 'movement_fps = 12.5',
            'reference_speed = 210.0', f'pixel_scale = {scale:.12f}',
            f'sprite_offset = Vector2(0, {-32 * scale:.12f})',
            'authored_motion_weight = 0.0', 'hit_recoil = 0.0', 'embedded_shadow = false',
            'attack_hit_frame = 2', 'action_hit_frames = {"attack": 2}', 'death_duration = 0.8',
            'metadata/twilight_production_connected = false',
            'metadata/twilight_detailed_completed = false', ''])
        write(profile, text.encode())
    required = {(role, direction) for role in ['idle', 'run', 'attack', 'hit'] for direction in core.DIRECTIONS} | {('death', 'S')}
    got = {(track['role'], track['direction']) for track in tracks}
    result = {
        'schema': 'pr122-boss-kurtz-repair-candidate-v1', 'id': 'monster:커츠',
        'kind': 'boss', 'quality_tier': 'mythic_transform',
        'new_source_poses': sum(len(t['geometry']['frames']) for t in tracks),
        'native_pose_count': sum(len(t['geometry']['frames']) for t in tracks),
        'native_track_count': len(tracks), 'missing_required_tracks': sorted([f'{r}_{core.DIRECTIONS.index(d)}' for r, d in required - got]),
        'production_connected': False, 'detailed_completed': False, 'new_approvals': 0,
        'prior_approval_and_assets_changed': False,
        'quality_review': 'HOLD: W/NW baked camera turns within RUN; other RUN support/weight and Main contact remain unapproved; 24 idle/attack/hit clips are not authored in this revision',
        'quality_findings': [
            {'criterion': 'reference_identity', 'result': 'IMPROVED_SOURCE_SCREEN',
             'observation': 'Broad spiked plated armor, closed decorated helmet, torn dark-scarlet cape and long broad greatsword restore the project reference silhouette missing from the thin shared runtime knight.'},
            {'criterion': 'S_support_exchange', 'result': 'PARTIAL_OBSERVED',
             'observation': 'Dedicated S6 v02 visibly exchanges screen-left forward boot in phase0 and screen-right forward boot in phase3 while keeping front camera and sword hand fixed. Full swing/flight cadence and physical contact remain HOLD.'},
            {'criterion': 'W_NW_camera', 'result': 'HOLD',
             'observation': 'The generated back RUN sheet turns the W and NW bodies toward the opposite camera in phases3-5. Software flip_h remains false; this is baked source orientation drift and is not hidden by geometry tests.'},
            {'criterion': 'other_RUN_support', 'result': 'HOLD',
             'observation': 'E/SE/SW support exchange is not established; N/NE boots are partly obscured by cape. Do not infer mythic gait from six distinct RGBA phases.'},
            {'criterion': 'ground_plane', 'result': 'METADATA_ONLY',
             'observation': 'Ground anchors are derived from source contact phases0/3, not each airborne boot bottom. This preserves raw PNG pixels and permits airborne clearance, but is not a physical contact approval.'},
            {'criterion': 'death_S', 'result': 'SOURCE_SCREEN_OBSERVED',
             'observation': 'Four complete full-body source stages progress from wounded upright to knee, collapse and prone armor/cape/sword. Actual Main floor/corpse overlap is not signed off.'},
        ],
        'reference': {'path': 'assets/monsters/original/atlas_0.png', 'region': [634, 619, 317, 310],
                      'sha256': core.sha(ROOT / 'assets/monsters/original/atlas_0.png'),
                      'kind': 'existing_project_reference_only'},
        'frames': 'res://' + relative(frames) if tracks else None,
        'native_profile': 'res://' + relative(OUT / 'NativeMotionProfile.tres') if tracks else None,
        'frames_sha256': core.sha(frames) if tracks else None,
        'native_profile_sha256': core.sha(OUT / 'NativeMotionProfile.tres') if tracks else None,
        'tracks': tracks,
    }
    dump(BASE / 'source-checks.json', records)
    dump(BASE / 'candidate.json', {'schema': 'pr122-boss-repair-staging-v1',
                                 'batch': relative(BASE), 'new_approvals': 0,
                                 'default_catalog_switches': 0,
                                 'actors': {'monster:커츠': result}})
    print(json.dumps({'tracks': len(tracks), 'poses': result['new_source_poses'],
                      'missing': result['missing_required_tracks'],
                      'source_statuses': {r['name']: r['status'] for r in records}}, ensure_ascii=False))


if __name__ == '__main__':
    build()
