#!/usr/bin/env python3
"""Make private remaining-Land QA inputs from existing passed physical proofs.

This reuses exact shared geometry; it grants no admission and creates no runtime
catalog/pack. Output includes original definitions and belongs outside public Git.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path

from build_current523_aden_pack import _output_path

OWNER_PIN = '2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90'
TABLES = ['LandAttribute', 'LandTimeLimit', 'LandWeeklyOpenTime', 'CompetitionDungeonLand']


def require(ok, message):
    if not ok:
        raise ValueError(message)


def checked(path, sha, size=None):
    raw = path.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == sha and (size is None or len(raw) == size),
            'Private input identity differs: ' + str(path))
    return raw


def make(args):
    args.output = _output_path(args.output, args.source_root.resolve())
    require(not args.output.exists(), 'Preserve previous evidence; select a new output')
    source = json.loads(checked(args.source_root / 'source523.json', args.source_sha256))
    physical = json.loads(checked(args.physical_cases, args.physical_cases_sha256))['cases']
    passed = [json.loads(line) for line in checked(args.passed_physical_rows,
              args.passed_rows_sha256).decode('utf-8').splitlines()]
    require(all(row['status'] == 'PASS' for row in passed), 'Incomplete physical evidence')
    ordinary = {int(row['declaration']['ID']): row['declaration']
                for row in source['logical_lands']
                if not row['excluded_content'] and row['policy_status'] == 'classified'}
    byasset = {row['asset_path']: row for row in physical}
    completed = {int(row['land_id']) for row in passed}
    require(len(completed) == len(passed) and completed <= ordinary.keys(),
            'Duplicate/foreign prior logical identities')
    require(len({row['asset_path'] for row in passed}) == len(passed) and
            {row['asset_path'] for row in passed} == {row['AssetPath'] for row in ordinary.values()},
            'Prior evidence does not cover distinct ordinary physical roots')
    for row in passed:
        require(row['asset_path'] == ordinary[int(row['land_id'])]['AssetPath'] and
                int(byasset[row['asset_path']]['land_id']) == int(row['land_id']),
                'Prior physical proof/QA identity differs')
    require(args.definition_manifest_sha256 == OWNER_PIN, 'Wrong owner manifest pin')
    manifest = json.loads(checked(args.definitions_root / 'manifest.json', OWNER_PIN))
    condition_spec = manifest['conditions']
    condition_raw = checked(args.definitions_root / 'conditions.json',
                            condition_spec['sha256'], condition_spec['bytes'])
    conditions = json.loads(condition_raw)['tables']
    result = []
    for ident, land in sorted(ordinary.items(), key=lambda pair: (pair[1]['AssetPath'], pair[0])):
        if ident in completed:
            continue
        geo = byasset[land['AssetPath']]
        spec = manifest['lands'][str(ident)]
        require(spec['file'] == f'lands/{ident}.json' and spec['asset_path'] == land['AssetPath'],
                'Definition shard namespace differs')
        raw = checked(args.definitions_root / spec['file'], spec['sha256'], spec['bytes'])
        shard = json.loads(raw)
        require(shard['land'] == land, 'Original Land declarations differ')
        result.append({'land': land, 'asset_path': land['AssetPath'],
            'representative_land_id': geo['land_id'], 'placed_S32': geo['placed_S32'],
            'entry': geo['entry']['entry_cell_info'], 'clear_neighbor': geo['clear_neighbor'],
            'wall_probe': geo['wall_probe'], 'outside_cell': geo['outside_cell'],
            'QA_entry_role': 'EXPLICIT_OWN_QA_REUSE_OF_ALREADY_VERIFIED_SHARED_GEOMETRY; NOT_NATIVE_ADMISSION',
            'expected_portals': [link['portal'] for link in shard['portals']],
            'expected_territories': shard['territories'],
            'conditions': {name: [row for row in conditions[name]
                if row.get('LandID', row.get('LandId', -1)) == ident] for name in TABLES},
            'owner_shard_sha256': spec['sha256'],
            'physical_proof_rows_sha256': args.passed_rows_sha256})
    require({row['land']['ID'] for row in result} == ordinary.keys() - completed,
            'Remaining identity set differs')
    payload = {'schema': 'CURRENT523_REMAINING_LOGICAL_MAIN_QA_V1',
        'source_manifest_sha256': args.source_sha256, 'prior_577_play_IDs': sorted(completed),
        'cases': result, 'new_geometry_discovery': False, 'native_admission_verified': False,
        'source_conditions_SHA256': hashlib.sha256(condition_raw).hexdigest()}
    encoded = (json.dumps(payload, ensure_ascii=False, separators=(',', ':')) + '\n').encode()
    fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(encoded)
    print(json.dumps({'remaining_logical_IDs': [row['land']['ID'] for row in result],
                      'bytes': len(encoded), 'SHA256': hashlib.sha256(encoded).hexdigest()}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['source-root', 'physical-cases', 'passed-physical-rows', 'definitions-root', 'output']:
        parser.add_argument('--' + name, type=Path, required=True)
    for name in ['source-sha256', 'physical-cases-sha256', 'passed-rows-sha256',
                 'definition-manifest-sha256']:
        parser.add_argument('--' + name, required=True)
    make(parser.parse_args())
