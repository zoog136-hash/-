"""User-authorized role scope; omissions never grant a production approval."""
from __future__ import annotations

import json
from pathlib import Path

POLICY = Path('data/pr122_transform_motion_scope.json')
CATALOG = Path('data/catalog_v19.json')
FULL_ROLES = frozenset(('idle', 'walk', 'run', 'attack', 'hit', 'death'))
EXCLUDED_GRADES = frozenset(('신화', '전설', '영웅', '희귀', '고급', '일반'))


def load_policy(root):
    path = Path(root) / POLICY
    if not path.exists():
        return None  # Legacy fixtures keep the stricter complete six-role scope.
    value = json.loads(path.read_text())
    if not (value.get('schema') == 'pr122-transform-motion-scope-v1'
            and value.get('actor_kind') == 'transform'
            and set(value.get('walk_excluded_grades', [])) == EXCLUDED_GRADES
            and value.get('unique_transform_walk_required') is True
            and value.get('boss_walk_required') is True
            and value.get('existing_assets_preserved') is True
            and value.get('omission_grants_approval') is False
            and set(value.get('required_roles_without_walk', [])) == FULL_ROLES - {'walk'}):
        raise ValueError('Invalid transformation-only user motion scope')
    return value


def required_roles(root, key):
    root = Path(root)
    if not isinstance(key, str) or not key.startswith('transform:'):
        return FULL_ROLES
    policy = load_policy(root)
    if policy is None:
        return FULL_ROLES
    source_id = key.removeprefix('transform:')
    rows = json.loads((root / CATALOG).read_text()).get('변신', [])
    matches = [row for row in rows if str(row.get('sourceId')) == source_id]
    if len(matches) > 1:
        raise ValueError('Duplicate canonical transformation identity')
    if len(matches) == 1 and matches[0].get('grade') in EXCLUDED_GRADES:
        return FULL_ROLES - {'walk'}
    return FULL_ROLES


def requires_walk(root, key):
    return 'walk' in required_roles(root, key)
