#!/usr/bin/env python3
"""Select frozen boss revisions without activating or approving them."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
BASE = Path('docs/remake/evidence/pr122-monsters-20261023')
INPUTS = {
    'monster:얼음 여왕': BASE / 'boss-repair-session/queen-combined-candidate.json',
    'monster:죽음의 좀비 로드': BASE / 'boss-fix02-zombie-lord/candidate-r002.json',
    'monster:알비노 데몬': BASE / 'boss-fix03-albino-demon/candidate-r002.json',
    'monster:커츠': BASE / 'boss-fix04-kurtz/r002/candidate.json',
}
LEDGER = 'data/pr122_monster_boss_repair_staging.json'
DIRECTIONS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']


def read(path):
    return json.loads((ROOT / path).read_text())


def pin(path):
    path = Path(str(path).removeprefix('res://'))
    data = (ROOT / path).read_bytes()
    return {'path': path.as_posix(), 'sha256': hashlib.sha256(data).hexdigest()}


def main():
    kinds = {row['id']: row['kind'] for row in read('data/pr122_monster_production_scope.json')['monsters']}
    required = {(direction, role) for direction in DIRECTIONS for role in ('idle', 'run', 'attack', 'hit')} | {('S', 'death')}
    actors, inputs = {}, []
    for key, path in INPUTS.items():
        actor = deepcopy(read(path)['actors'][key])
        assert kinds[key] == actor['kind'] == 'boss'
        assert actor['quality_tier'] == 'mythic_transform'
        assert actor['production_connected'] is False and actor['detailed_completed'] is False
        assert pin(actor['frames'])['sha256'] == actor['frames_sha256']
        assert pin(actor['native_profile'])['sha256'] == actor['native_profile_sha256']
        identities = [(track['direction'], track['role']) for track in actor['tracks']]
        assert len(identities) == len(set(identities)) == actor['native_track_count']
        assert sum(len(track['geometry']['frames']) for track in actor['tracks']) == actor['native_pose_count']
        missing = sorted(f'{role}_{DIRECTIONS.index(direction)}' for direction, role in required - set(identities))
        assert sorted(actor['missing_required_tracks']) == missing
        for track in actor['tracks']:
            assert track['geometry']['frames']
            assert pin(track['source'])['sha256'] == track['source_sha256']
        actor['replaces_previous_staging_selection'] = True
        actor['source_candidate'] = pin(path)
        actors[key] = actor
        inputs.append(pin(path))
    value = {
        'schema': 'pr122-monster-boss-repair-staging-v1', 'date': '2026-10-23',
        'reviewed_source_commit': '88516cfcb303b9c8f288abf72d1cc477aed62ebf',
        'actors': actors, 'new_approvals': 0, 'default_catalog_switches': 0,
        'selection_policy': 'Latest frozen selection only. Prior sources, failed trials and approvals remain preserved. Missing or rejected directions do not inherit old drafts.',
        'source_inputs': inputs,
    }
    (ROOT / LEDGER).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    batches_path = ROOT / 'data/pr122_monster_production_batches.json'
    batches = json.loads(batches_path.read_text())
    if LEDGER not in batches['staging_ledgers']:
        batches['staging_ledgers'].append(LEDGER)
    batches['policy'] = ('Source coverage and technical playback do not grant a new approval. '
                        'Family adapters are not new authored poses. Latest boss repair selections '
                        'supersede prior unapproved source selections without deleting them; '
                        'source identity, gait and contact HOLDs remain explicit.')
    batches_path.write_text(json.dumps(batches, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: {'clips': row['native_track_count'], 'poses': row['native_pose_count'],
                           'missing': row['missing_required_tracks']} for key, row in actors.items()}, ensure_ascii=False))


if __name__ == '__main__':
    main()
