#!/usr/bin/env python3
"""Extend frozen r001 with complete new role-separated source sheets."""
import json
from pathlib import Path
from copy import deepcopy
import sys

BASE = Path(__file__).resolve().parent
ROOT = Path(__file__).resolve().parents[6]
PRIOR = BASE.parent
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import frames_bytes

OUT = ROOT / 'assets/actors/eight_direction/monster_boss_repair/kurtz/r002'
SPECS = [
    ('idle-hit-front4-v03', 4, 'columns', ['E', 'SE', 'S', 'SW'], [0, 1], {'idle': [0, 1], 'hit': [2, 3]}),
    ('idle-hit-back4-v03', 4, 'columns', ['W', 'NW', 'N', 'NE'], [0, 1], {'idle': [0, 1], 'hit': [2, 3]}),
] + [(f'attack-{d}4-v03', 4, 'phase_grid2', [d], [3], {'attack': [0, 1, 2, 3]}) for d in ['E', 'SE', 'S', 'SW']]


def rel(p):
    return p.relative_to(ROOT).as_posix()


def dump(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def build():
    prior = json.loads((PRIOR / 'candidate.json').read_text())['actors']['monster:커츠']
    tracks = deepcopy(prior['tracks'])
    records = []
    added_poses = 0
    for name, rows, axis, dirs, refs, roles in SPECS:
        src = BASE / 'raw' / (name + '.png')
        r = {'name': name, 'path': rel(src), 'directions': dirs, 'roles': list(roles)}
        if not src.exists():
            r.update(status='NOT_GENERATED')
            records.append(r)
            continue
        r.update(sha256=core.sha(src), bytes=src.stat().st_size)
        try:
            initial = core.analyze(src, rows, refs, directions_axis=axis, canvas_size=2048, directions=dirs)
            core.require_complete_pose_regions(src, initial)
            canvas = max(64, round(initial['neutral_height'] * 256 / 96 / 8) * 8)
            geometry = core.analyze(src, rows, refs, directions_axis=axis, canvas_size=canvas, directions=dirs)
            core.require_complete_pose_regions(src, geometry)
            texture = OUT / (name + '.png')
            texture.parent.mkdir(parents=True, exist_ok=True)
            texture.write_bytes(src.read_bytes())
            assert core.sha(texture) == r['sha256']
            r.update(status='GEOMETRY_PASS_ONLY', geometry=geometry)
            for d in dirs:
                for role, phases in roles.items():
                    selected = [deepcopy(f) for f in geometry['frames'] if f['direction'] == d and f['row'] in phases]
                    assert len(selected) == len(phases)
                    g = deepcopy(geometry)
                    g['frames'] = selected
                    tracks.append({'direction': d, 'role': role, 'animation': f'{role}_{core.DIRECTIONS.index(d)}',
                                   'source': rel(src), 'source_sha256': r['sha256'], 'texture': rel(texture), 'geometry': g})
                    added_poses += len(selected)
        except ValueError as error:
            r.update(status='SOURCE_HOLD', reason=str(error))
        records.append(r)
    assert len(tracks) == len({t['animation'] for t in tracks})
    OUT.mkdir(parents=True, exist_ok=True)
    frames = OUT / 'SpriteFrames.tres'
    frames.write_bytes(frames_bytes(tracks))
    profile = OUT / 'NativeMotionProfile.tres'
    profile.write_text((ROOT / prior['native_profile'].removeprefix('res://')).read_text().replace(prior['frames'], 'res://' + rel(frames)))
    required = {(r, d) for r in ['idle', 'run', 'attack', 'hit'] for d in core.DIRECTIONS} | {('death', 'S')}
    available = {(t['role'], t['direction']) for t in tracks}
    actor = deepcopy(prior)
    actor.update(frames='res://' + rel(frames), frames_sha256=core.sha(frames),
                 native_profile='res://' + rel(profile), native_profile_sha256=core.sha(profile),
                 tracks=tracks, native_track_count=len(tracks), native_pose_count=sum(len(t['geometry']['frames']) for t in tracks),
                 new_source_poses=added_poses, prior_revision_source_poses_reused=prior['native_pose_count'],
                 missing_required_tracks=sorted(f'{r}_{core.DIRECTIONS.index(d)}' for r, d in required - available),
                 quality_review='HOLD: inherited RUN W/NW camera/support issues and all new source identity/contact/scale review need explicit results; resource loading is not mythic approval')
    actor['quality_findings'].extend([
        {'criterion': 'new_back_idle_hit_camera', 'result': 'HOLD',
         'observation': 'Private source view shows W column actually turns screen-right and NW resembles rear-right NE rather than distinct rear-left. N and NE rear silhouettes are present. No eight-view identity approval is granted.'},
        {'criterion': 'new_S_attack', 'result': 'HOLD',
         'observation': 'Four large articulated sword poses are separate and complete, but overhead hand assignment is inconsistent with the original right-hand guard and the contact source extends mostly laterally rather than proving forward S target contact.'},
        {'criterion': 'new_SW_attack', 'result': 'IMPROVED_SOURCE_SCREEN_ONLY',
         'observation': 'Large complete greatsword, broad armored torso and scarlet cape retain the boss source identity through windup/downswing/contact/recovery. Source contact extends toward lower-left. Real target contact/timing, common scale and sword-hand continuity remain unsigned.'},
        {'criterion': 'failed_large_sources', 'result': 'SOURCE_HOLD_PRESERVED',
         'observation': 'Front idle/hit and E attack include another body inside a full-pose bounding rectangle; SE attack has only three separate connected bodies because neighboring poses touch. These sources are preserved raw and no frames are invented or cropped around the failure.'},
    ])
    dump(BASE / 'candidate.json', {'schema': 'pr122-boss-repair-staging-v1', 'batch': rel(BASE), 'new_approvals': 0,
                                  'default_catalog_switches': 0, 'actors': {'monster:커츠': actor}})
    dump(BASE / 'source-checks.json', records)
    print(json.dumps({'clips': len(tracks), 'total_native_poses': actor['native_pose_count'], 'new_r002_poses': added_poses,
                      'missing': actor['missing_required_tracks'], 'source_statuses': {r['name']: r['status'] for r in records}}, ensure_ascii=False))


if __name__ == '__main__':
    build()
