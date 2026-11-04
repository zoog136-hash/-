#!/usr/bin/env python3
"""Audit private patch523 optimization definitions without publishing their rows."""
import argparse
import collections
import hashlib
import json
from pathlib import Path

EXPECTED = {
    'EffectSpriteSimplify.json': 'a5d81dc541e08e4b5c0739b0f4fcebae38d900469561071276db496370b644ab',
    'UIFlashEffectHideList.json': 'af7460c9cd4de6d3e894c1fd6c7ca280acbdb1268020d39c489344abeb5cb099',
    'ClientOptimizeTerritoryConditionType.json': '3022f3d5f19dbf280aac360b88b7decac78e728ea1f4dc04d5cf510ae07bfba1',
    'OptimizedTerritoryView.json': '6faeba60ccac99d111f196cbff6afa38358d4a3db7108b6899dfc2696e106f97',
}

def audit(content: Path) -> dict:
    for name, expected in EXPECTED.items():
        if hashlib.sha256((content / name).read_bytes()).hexdigest() != expected:
            raise ValueError('patch523 source SHA mismatch: ' + name)
    rows = json.loads((content / 'OptimizedTerritoryView.json').read_text(encoding='utf-8-sig'))['rows']
    conditions = json.loads((content / 'ClientOptimizeTerritoryConditionType.json').read_text(encoding='utf-8-sig'))['rows']
    names = {row['ID']: row['Name'] for row in conditions}
    flags = ['DefaultLowEffectCount', 'DefaultHideMagicDoll', 'ConditionHideMagicDoll', 'ConditionLowEffectCount']
    for row in rows:
        if any(type(row[key]) is not bool for key in flags):
            raise ValueError('invalid source flag')
        if row['ConditionTypeId'] not in names or row['StartX'] > row['EndX'] or row['StartY'] > row['EndY']:
            raise ValueError('invalid territory definition')
    simplify = json.loads((content / 'EffectSpriteSimplify.json').read_text(encoding='utf-8-sig'))['rows']
    flash = json.loads((content / 'UIFlashEffectHideList.json').read_text(encoding='utf-8-sig'))['rows']
    return {'explicit_simplify_mappings': len(simplify), 'native_flash_hide_paths': len(flash), 'rows': len(rows), 'lands': len({row['LandID'] for row in rows}),
            'condition_counts': dict(collections.Counter(names[row['ConditionTypeId']] for row in rows)),
            'defaults': dict(collections.Counter(f"low={row['DefaultLowEffectCount']},hide={row['DefaultHideMagicDoll']}" for row in rows)),
            'source_sha256': EXPECTED,
            'numeric_effect_budget': 'NOT_PROVIDED',
            'native_rectangle_edge_and_overlap_policy': 'UNVERIFIED',
            'automatic_application': 'DISABLED; explicit user preferences only'}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('content', type=Path)
    print(json.dumps(audit(parser.parse_args().content), ensure_ascii=False, indent=2))
