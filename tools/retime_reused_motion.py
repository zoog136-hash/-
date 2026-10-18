#!/usr/bin/env python3
"""Retime only the five existing unapproved, exact-body project candidates.

Derived from current DB speed and explicit displayed height/width. This keeps
the approved source cadence per travelled stride, not a newly measured gait.
No gameplay record, texture, source SpriteFrames or approval is written.
"""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path

from retarget_original_motion import canonical, register_profiles, required


def records(root):
    read = lambda p: json.loads((root / p).read_text())
    catalog = read('data/monsters/monster_world_catalog.json')
    result = {}
    for raw in read('data/game_db_v17.json')['몬스터']:
        row = deepcopy(raw)
        row.update(catalog['overlays'].get(row['name'], {}))
        result[row['name']] = row
    for patch in catalog['additions']:
        if patch['name'] in result:
            continue
        row = deepcopy(result.get(patch.get('template', '해골 근위병'), {}))
        row.update(patch)
        result[row['name']] = row
    return result


def prepare(root):
    read = lambda p: json.loads((root / p).read_text())
    catalog = read('data/combat_animation_profiles.json')
    profiles = catalog['profiles']
    monsters = records(root)
    plan = read('docs/remake/evidence/pr122-remaining106/batch13/family-reuse-plan.json')
    result = []
    for case in plan['cases']:
        key, source_key = case['target'], case['source']
        profile, source = profiles[key], profiles[source_key]
        required(profile['frames_path'].endswith('/'+case['folder']+'/SpriteFrames.tres'), 'Candidate binding changed')
        source_path = root / case['source_frames_path']
        required(hashlib.sha256(source_path.read_bytes()).hexdigest() == case['source_frames_SHA256'], 'Approved source changed')
        target_record, source_record = monsters[key.split(':', 1)[1]], monsters[source_key.split(':', 1)[1]]
        speed = lambda r: float(r.get('speed', 70.0 + min(70, int(float(r['hp']) / 10.0))))
        target_speed, source_speed = speed(target_record), speed(source_record)
        height_ratio = profile['pixel_scale'] / source['pixel_scale']
        width_ratio = profile.get('native_width_ratio', 1.0) / source.get('native_width_ratio', 1.0)
        required(.5 < height_ratio < 2 and .8 < width_ratio < 1.25, 'Unreviewed scale outside existing adapter')
        fps = source['movement_fps'] * target_speed / source_speed / height_ratio
        before = deepcopy(profile)
        profile['movement_fps'] = fps
        profile['movement_cadence_width_ratio'] = width_ratio
        required({k:v for k,v in before.items() if k not in ('movement_fps','movement_cadence_width_ratio')} ==
                 {k:v for k,v in profile.items() if k not in ('movement_fps','movement_cadence_width_ratio')}, 'Unrelated profile change')
        result.append({'id':key, 'source':source_key, 'source_speed':source_speed, 'target_speed':target_speed,
                       'source_fps':source['movement_fps'], 'height_ratio':height_ratio, 'width_ratio':width_ratio,
                       'prior_fps':before['movement_fps'], 'new_fps':fps,
                       'east_west_fps':fps/width_ratio, 'north_south_fps':fps,
                       'baseline':'approved source cadence; independent no-slip visual review pending',
                       'gameplay_changed':False, 'approval':'PENDING', 'new_frames':0})
    return catalog, result


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[1])
    p.add_argument('--report',type=Path,required=True)
    p.add_argument('--apply',action='store_true')
    a = p.parse_args()
    root = a.root.resolve()
    path = root/'data/combat_animation_profiles.json'
    original = path.read_text()
    catalog, result = prepare(root)
    updated = register_profiles(original,catalog,[r['id'] for r in result])
    if a.apply:
        path.write_text(updated)
    a.report.parent.mkdir(parents=True,exist_ok=True)
    a.report.write_text(json.dumps({'applied':a.apply,'candidates':result},ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False))
