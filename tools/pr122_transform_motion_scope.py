"""User-authorized role scope; omissions never grant a production approval."""
from __future__ import annotations

import json
from pathlib import Path

POLICY = Path('data/pr122_transform_motion_scope.json')
CATALOG = Path('data/catalog_v19.json')
FULL_ROLES = frozenset(('idle', 'walk', 'run', 'attack', 'hit', 'death'))
EXCLUDED_GRADES = frozenset(('신화', '전설', '영웅', '희귀', '고급', '일반'))
DIRECTIONS = ('E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE')


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
    death = value.get('death_direction_policy')
    if death is not None:
        if not (isinstance(death, dict)
                and set(death) == EXCLUDED_GRADES | {'유일'}
                and value.get('death_existing_native_sources_preserved') is True
                and value.get('death_actor_completion_requires_game_validation') is True
                and all(isinstance(rule, dict) and rule.get('unique_authored_directions') == 1
                        and rule.get('direction_names') == ['S']
                        and rule.get('new_sources_only') is True
                        and rule.get('preserve_existing_directions') is True
                        for rule in death.values())):
            raise ValueError('Invalid new-source-only S death scope')
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


def authoring_directions(root, key, role):
    """Directions for NEW sources; never removes an existing authored clip."""
    if role != 'death' or not isinstance(key, str) or not key.startswith('transform:'):
        return DIRECTIONS
    policy = load_policy(root)
    if policy is None or 'death_direction_policy' not in policy:
        return DIRECTIONS
    rows = json.loads((Path(root) / CATALOG).read_text()).get('변신', [])
    matches = [row for row in rows if str(row.get('sourceId')) == key.removeprefix('transform:')]
    if len(matches) > 1:
        raise ValueError('Duplicate canonical transformation identity')
    if matches and matches[0].get('grade') in policy['death_direction_policy']:
        return ('S',)
    return DIRECTIONS


def required_directions(root, key, role):
    """New S requirement plus all recorded pre-existing directional deaths."""
    directions = authoring_directions(root, key, role)
    if role != 'death' or directions != ('S',):
        return directions
    policy = load_policy(root)
    entry = policy.get('death_source_ledger', {}).get(key, {})
    existing = entry.get('existing_connected_directions', [])
    if not isinstance(existing, list) or any(d not in DIRECTIONS for d in existing):
        raise ValueError('Invalid preserved death directions')
    if key in policy.get('death_preserved_approved_actor_keys', []):
        if not entry.get('existing_approval_preserved') or not existing:
            raise ValueError('Missing preserved approved death source record')
    return tuple(d for d in DIRECTIONS if d == 'S' or d in existing)


def required_tracks(root, key):
    return frozenset((direction, role) for role in required_roles(root, key)
                     for direction in required_directions(root, key, role))
