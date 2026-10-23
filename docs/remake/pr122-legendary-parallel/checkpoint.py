#!/usr/bin/env python3
"""Refresh the isolated legendary ledger from real PNGs and Godot reports."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DIR = ROOT / 'docs/remake/pr122-legendary-parallel'
BASE = '16bb178426134dbc5ffcc32306de0a2509352c8f'
DIRECTIONS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    catalog = json.loads((ROOT/'data/catalog_v19.json').read_text())
    actors = [x for x in catalog['변신'] if x['grade'] == '전설']
    assert len(actors) == 40
    old_path = ROOT/'docs/remake/evidence/pr122-remaining106/batch17/all498-production-status.json'
    legacy = {x['id']: x for x in json.loads(old_path.read_text())['species']}
    reports = {}
    for p in sorted(DIR.glob('batch*-minimal-validation.json')):
        report = json.loads(p.read_text())
        assert report['failures'] == 0
        for row in report['records']:
            assert row['status'] == 'PASS' and row['frames_reached'] == 6
            reports[(row['key'], row['direction'], row['role'])] = p.relative_to(ROOT).as_posix()
    authored = []
    for p in sorted((ROOT/'assets/actors/eight_direction/legendary_parallel').glob('*/draft001/*-record-v01.json')):
        d = json.loads(p.read_text())
        assert d['key'] in legacy and d['poses'] == 6
        png = ROOT/d['source']
        tres = ROOT/d['output_spriteframes'].removeprefix('res://')
        assert sha(png) == d['source_sha256'] and sha(tres) == d['output_spriteframes_sha256']
        report = reports.get((d['key'], d['direction'], d['role']))
        assert report is not None, 'Do not commit an untested SpriteFrames track'
        reused_poses=d.get('reused_poses',0)
        prior_draft_poses=d.get('reused_prior_draft_poses',0)
        legacy_poses=d.get('reused_legacy_poses',reused_poses-prior_draft_poses)
        assert legacy_poses >= 0 and prior_draft_poses >= 0
        assert legacy_poses+prior_draft_poses == reused_poses
        assert d.get('newly_authored_poses',6)+reused_poses == 6
        authored.append({'key':d['key'], 'direction':d['direction'], 'role':d['role'],
                         'source':d['source'], 'source_sha256':d['source_sha256'],
                         'source_bytes':png.stat().st_size, 'SpriteFrames':d['output_spriteframes'],
                         'SpriteFrames_sha256':d['output_spriteframes_sha256'],
                         'record':p.relative_to(ROOT).as_posix(), 'poses':6,
                         'newly_authored_poses':d.get('newly_authored_poses',6),
                         'reused_poses':reused_poses,
                         'reused_legacy_poses':legacy_poses,
                         'reused_prior_draft_poses':prior_draft_poses,
                         'minimal_Godot_report':report, 'draft_status':'MINIMAL_CHECK_PASS',
                         'quality_status':'HOLD_NOT_REVIEWED', 'actor_final_approval':False,
                         'hold_reasons':d['hold_reasons']})
    rows = []
    for a in actors:
        key = 'transform:'+str(a['sourceId']); old = legacy[key]
        motions = [x for x in authored if x['key'] == key]
        rows.append({'key':key,'name':a['name'],'grade':a['grade'],
                     'reference':a['image_path'],'reference_sha256':sha(ROOT/a['image_path'].removeprefix('res://')),
                     'legacy_approval_preserved':old['approval_preserved'],
                     'legacy_production_status':old['production_status'],'legacy_frames_path':old['frames_path'],
                     'existing_WALK_and_directional_DEATH_preserved':True,
                     'required_motion_configurations':33,'drafts':motions,
                     'remaining_draft_configurations':33-len(motions),
                     'precision_final_approved':False})
    counts = {'required_actors':40,'required_motion_configurations':1320,'minimum_pose_target':7920,
              'new_draft_configurations':len(authored),'minimally_validated_configurations':len(authored),
              'newly_authored_poses':sum(x['newly_authored_poses'] for x in authored),
              'reused_existing_poses':sum(x['reused_poses'] for x in authored),
              'reused_legacy_poses':sum(x['reused_legacy_poses'] for x in authored),
              'reused_prior_draft_poses':sum(x['reused_prior_draft_poses'] for x in authored),
              'quality_held_configurations':len(authored),'new_final_approved_actors':0,
              'new_final_approved_configurations':0,'verified_complete_existing_reuse_configurations':0,
              'remaining_draft_configurations':1320-len(authored)}
    data = {'schema':'pr122-legendary-parallel-staging-v1','base_PR':122,'base_sha':BASE,
            'branch':'feature/pr122-legendary-parallel-20261023','directions':DIRECTIONS,
            'production_order':[['S',x] for x in ['attack','run','death','hit','idle']]+[[d,x] for d in ['E','SE','SW','W','NW','N','NE'] for x in ['idle','run','attack','hit']],
            'minimum_frames_per_configuration':6,'new_death_directions':['S'],'new_WALK_excluded':True,
            'production_connected':False,'mythic_files_changed':False,'catalog_or_saves_changed':False,
            'whole_game_and_Godot_4_7_2_QA':'NOT_RUN_DEFERRED_UNTIL_DRAFTS_COMPLETE',
            'legacy_ledger_sha256':sha(old_path),'counts':counts,'actors':rows}
    target = ROOT/'data/pr122_legendary_parallel_staging.json'
    target.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(counts,ensure_ascii=False))

if __name__ == '__main__':
    main()
