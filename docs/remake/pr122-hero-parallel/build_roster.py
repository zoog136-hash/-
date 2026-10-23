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
    '406': ('insectoid_multilimbed', 'claws_and_antennae', 'melee', 4),
    '405': ('winged_insect_fairy', 'fairy', 'magic', 4),
    '386': ('female_humanoid', 'cherry_costume', 'melee', 4),
    '376': ('male_humanoid', 'fishing_rod', 'rod', 4),
    '360': ('male_humanoid', 'cards', 'ranged', 4),
    '359': ('puppet', 'trombone', 'instrument', 4),
    '358': ('humanoid', 'drums', 'instrument', 4),
    '357': ('male_humanoid', 'ringmaster', 'whip', 4),
    '352': ('frog', 'horns', 'melee', 4),
    '276': ('female_humanoid', 'maid', 'melee', 4),
    '268': ('winged_armored_humanoid', 'celestial_sword', 'slash', 4),
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
    '4': ('winged_armored_humanoid', 'celestial_sword', 'slash', 4),
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
        # Preserve hero-owned review/provenance fields, including newer schemas.
        # Identity/classification still comes from the exact 498/catalog join.
        old = previous.get('actors', {}).get(key, {})
        identity_fields = {'name', 'grade', 'historical_status', 'reference',
                           'reference_sha256', 'body', 'equipment', 'attack_family',
                           'priority', 'classification_is_art_approval'}
        for field, value in old.items():
            if field not in identity_fields:
                actors[key][field] = value
    for key, actor in actors.items():
        if actor['final_approved']:
            receipt_path = ROOT / actor['approval_receipt'].removeprefix('res://')
            receipt = json.loads(receipt_path.read_text())
            assert receipt['status'] == 'APPROVED_HERO_ASSET_READY_FOR_INTEGRATION' and receipt['id'] == key
            assert receipt['frames_sha256'] == digest(actor['frames'].removeprefix('res://'))
            assert receipt['native_profile_sha256'] == digest(actor['native_profile'].removeprefix('res://'))
            assert receipt['rig_sha256'] == digest(actor['rig'].removeprefix('res://'))
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
        'target_scope_total': len(pending),
        'pending_total': sum(not a['final_approved'] for a in actors.values()),
        'new_final_approvals': sum(a['final_approved'] for a in actors.values()),
        'default_game_connections': 0, 'actors': actors,
        'historical_approved_ids_read_only': ['transform:' + str(r['sourceId']) for r in approved],
    }
    # Supplemental repairs are not new species and must never disappear here.
    result = {**previous, **result}
    assert len(heroes) == 109 and len(approved) == 84 and len(pending) == 25
    if result != previous:
        OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f"HERO_ROSTER_OK total=109 excluded_approved=84 scope=25 pending={result['pending_total']} new_approvals={result['new_final_approvals']} walk=excluded")


if __name__ == '__main__':
    build()
