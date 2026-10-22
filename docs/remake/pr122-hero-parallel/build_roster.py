#!/usr/bin/env python3
"""Exact intersection with the 498 ledger; never promote runtime proxies."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'data/pr122_hero_parallel_staging.json'
LEDGER = 'docs/remake/evidence/pr122-remaining106/batch17/all498-production-status.json'
GROUPS = {
    '407': ('tree', 'branches', 'melee', 4),
    '406': ('female_caster', 'staff', 'magic', 4),
    '405': ('winged_fairy', 'fairy', 'magic', 4),
    '386': ('female_humanoid', 'cherry_costume', 'melee', 4),
    '376': ('male_humanoid', 'fishing_rod', 'rod', 4),
    '360': ('male_humanoid', 'cards', 'ranged', 4),
    '359': ('puppet', 'trombone', 'instrument', 4),
    '358': ('humanoid', 'drums', 'instrument', 4),
    '357': ('male_humanoid', 'ringmaster', 'whip', 4),
    '352': ('frog', 'horns', 'melee', 4),
    '276': ('female_humanoid', 'maid', 'melee', 4),
    '268': ('armored_humanoid', 'celestial_sword', 'slash', 4),
    '260': ('armored_humanoid', 'kenrauhel', 'slash', 2),
    '231': ('armored_humanoid', 'unique_lance', 'thrust', 4),
    '198': ('female_humanoid', 'rabbit_costume', 'melee', 4),
    '197': ('armored_humanoid', 'harper', 'slash', 4),
    '182': ('armored_humanoid', 'lance_blue', 'thrust', 1),
    '179': ('armored_humanoid', 'lance_red', 'thrust', 1),
    '155': ('reaper', 'scythe', 'slash', 4),
    '123': ('female_humanoid', 'gun', 'ranged', 4),
    '16': ('demon', 'balrog', 'melee', 4),
    '11': ('demon', 'beres', 'magic', 1),
    '9': ('dark_elf', 'bow', 'ranged', 4),
    '7': ('demon', 'baphomet', 'melee', 1),
    '4': ('armored_humanoid', 'celestial_sword', 'slash', 4),
}


def digest(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def build():
    catalog = json.loads((ROOT / 'data/catalog_v19.json').read_text())['변신']
    ledger = json.loads((ROOT / LEDGER).read_text())
    by_id = {row['id']: row for row in ledger['species']}
    assert len(by_id) == 498
    heroes = [r for r in catalog if r.get('grade') == '영웅'
              and 'transform:' + str(r['sourceId']) in by_id]
    approved = [r for r in heroes if by_id['transform:' + str(r['sourceId'])]
                ['production_status'] in ('VERIFIED_COMPLETED', 'FRAME_INSUFFICIENT')]
    pending = [r for r in heroes if r not in approved]
    assert {str(r['sourceId']) for r in pending} == set(GROUPS)
    previous = json.loads(OUT.read_text()) if OUT.exists() else {}
    actors = {}
    for row in sorted(pending, key=lambda r: (GROUPS[str(r['sourceId'])][3], int(r['sourceId']))):
        sid = str(row['sourceId'])
        key = 'transform:' + sid
        body, equipment, attack, priority = GROUPS[sid]
        actors[key] = {
            'name': row['name'], 'grade': '영웅',
            'historical_status': by_id[key]['production_status'],
            'reference': row['image_path'],
            'reference_sha256': digest(row['image_path'].removeprefix('res://')),
            'body': body, 'equipment': equipment, 'attack_family': attack,
            'priority': priority, 'classification_is_art_approval': False,
            'status': 'NOT_STARTED', 'production_connected': False,
            'independent_validation': 'NOT_RUN', 'final_approved': False,
        }
        # Only explicitly authored hero-only state may survive a roster refresh.
        old = previous.get('actors', {}).get(key, {})
        for field in ['status', 'frames', 'native_profile', 'rig', 'tracks',
                      'independent_validation', 'quality_holds', 'source_donor',
                      'source_frames_sha256', 'new_run_poses', 'production_connected',
                      'final_approved', 'raster_review', 'main_validation_report', 'shared_run_poses',
                      'unique_art_candidates', 'prior_candidates', 'death_policy_scope',
                      'death_reuse_assessment', 'new_unique_authored_poses',
                      'new_death_authored_directions', 'new_death_unique_poses', 'death_hold_review_source',
                      'death_validation_report']:
            if field in old:
                actors[key][field] = old[field]
    result = {
        'schema': 'pr122-hero-parallel-v1', 'branch': 'feature/pr122-hero-parallel',
        'basis_pr_head': '5bf5d3195f97fda565f195f19344a4929597267e',
        'latest_main_read_only': previous.get('latest_main_read_only', '470836b5e79985522541206f9e3d51edfb9cc277'),
        'source_498_ledger': LEDGER,
        'source_498_ledger_sha256': digest(LEDGER),
        'required_roles': ['idle', 'run', 'attack', 'hit', 'death'],
        'directions': ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE'],
        'walk_policy': 'USER_EXCLUDED_20261020_EXISTING_ASSETS_PRESERVED',
        'hero_total_in_498': len(heroes), 'historical_approved_excluded': len(approved),
        'historical_short_frame_excluded': sum(by_id['transform:' + str(r['sourceId'])]
             ['production_status'] == 'FRAME_INSUFFICIENT' for r in approved),
        'pending_total': len(pending), 'new_final_approvals': 0,
        'default_game_connections': 0, 'actors': actors,
        'historical_approved_ids_read_only': ['transform:' + str(r['sourceId']) for r in approved],
    }
    if previous.get('animation_policy'):
        result['animation_policy'] = previous['animation_policy']
    assert len(heroes) == 109 and len(approved) == 84 and len(pending) == 25
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('HERO_ROSTER_OK total=109 excluded_approved=84 pending=25 walk=excluded new_approvals=0')


if __name__ == '__main__':
    build()
