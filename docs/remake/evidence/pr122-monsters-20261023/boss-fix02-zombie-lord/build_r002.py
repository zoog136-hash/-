#!/usr/bin/env python3
"""Keep r001 intact; replace only its S RUN by the observed support-column source."""
from copy import deepcopy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import frames_bytes, preserve, json_bytes

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/boss-fix02-zombie-lord')
FOLDER = Path('assets/actors/eight_direction/monster_boss_repair/zombie_lord/r002')
KEY = 'monster:죽음의 좀비 로드'
NAME = 'zombie-lord-S-run6-support-columns-v02'


def build():
    r = deepcopy(json.loads((ROOT / BATCH / 'candidate.json').read_text()))
    a = r['actors'][KEY]
    qpath = ROOT / BATCH / 'requests' / (NAME + '.json')
    q = json.loads(qpath.read_text())
    raw = BATCH / 'raw' / (NAME + '.png')
    first = core.analyze(ROOT / raw, 6, [0, 1], directions_axis='phase_grid2', canvas_size=2048, directions=['S'])
    core.require_complete_pose_regions(ROOT / raw, first)
    canvas = max(64, round(first['neutral_height'] * 256 / 64 / 8) * 8)
    g = core.analyze(ROOT / raw, 6, [0, 1], directions_axis='phase_grid2', canvas_size=canvas, directions=['S'])
    core.require_complete_pose_regions(ROOT / raw, g)
    by_row = {f['row']: f for f in g['frames']}
    assert q['playback_source_rows'] == [0, 2, 4, 1, 3, 5]
    g['frames'] = [by_row[i] for i in q['playback_source_rows']]
    texture = FOLDER / (NAME + '.png')
    preserve(ROOT / texture, (ROOT / raw).read_bytes())
    replacement = {'direction': 'S', 'role': 'run', 'animation': 'run_2', 'source': raw.as_posix(),
                   'source_sha256': core.sha(ROOT / raw), 'texture': texture.as_posix(), 'geometry': g,
                   'source_phase_order': q['playback_source_rows'],
                   'observed_support_sequence': ['RIGHT', 'RIGHT', 'RIGHT', 'LEFT', 'LEFT', 'LEFT'],
                   'source_plane_review': 'Observed opposite screen-side full-sole support; anatomicalRIGHT=screenLEFT. Main gait/weight review still HOLD.'}
    a['tracks'] = [replacement if t['direction']=='S' and t['role']=='run' else t for t in a['tracks']]
    fingerprints = [f['rgba_sha256'] for t in a['tracks'] for f in t['geometry']['frames']]
    assert len(fingerprints) == len(set(fingerprints)) == 116
    frames = FOLDER / 'SpriteFrames.tres'
    preserve(ROOT / frames, frames_bytes(a['tracks']))
    oldprofile = ROOT / a['native_profile'].removeprefix('res://')
    profile = FOLDER / 'NativeMotionProfile.tres'
    preserve(ROOT / profile, oldprofile.read_bytes().replace(b'/r001/SpriteFrames.tres', b'/r002/SpriteFrames.tres'))
    a.update(frames='res://' + frames.as_posix(), frames_sha256=core.sha(ROOT / frames),
             native_profile='res://' + profile.as_posix(), native_profile_sha256=core.sha(ROOT / profile),
             quality_review='HOLD: S support exchange source corrected; E/other RUN phase repetition/occlusion and full mythic/Main quality remain unresolved. No runtime switch or approval.')
    r.update(revision='r002', previous_candidate=(BATCH/'candidate.json').as_posix(),
             new_source_poses_this_revision=6, reused_source_poses_from_r001=110,
             comparison='Only S RUN source and its playback index order changed. Old r001 and approved runtime assets remain byte-identical.')
    preserve(ROOT / BATCH / 'candidate-r002.json', json_bytes(r))
    preserve(ROOT / BATCH / 'source-check-r002.json', json_bytes({'source': raw.as_posix(), 'sha256': core.sha(ROOT / raw),
        'request': qpath.relative_to(ROOT).as_posix(), 'request_sha256': core.sha(qpath), 'geometry': g,
        'strict_geometry': 'PASS', 'actual_support_exchange_S': 'OBSERVED_SOURCE_PLANE',
        'semantic_approval': False, 'default_Main': 'NOT_RUN', 'new_approvals': 0}))
    print(json.dumps({'revision':'r002','clips':33,'poses':116,'new_source_poses':6,'reused_r001_poses':110,'new_approvals':0}))


if __name__ == '__main__':
    build()
