"""The 2026-10-23 monster contract supersedes older monster WALK requirements."""
import json
from pathlib import Path

POLICY = Path('data/pr122_monster_production_scope.json')
DIRECTIONS = ('E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE')


def lookup(root, key):
    if not isinstance(key, str) or not key.startswith('monster:'):
        return None
    path = Path(root) / POLICY
    if not path.is_file():
        return None
    policy = json.loads(path.read_text())
    if not (policy.get('schema') == 'pr122-monster-motion-scope-v1'
            and policy.get('new_walk_required') is False
            and policy.get('new_death_directions') == ['S']
            and policy.get('preserve_existing_walk') is True
            and policy.get('preserve_existing_directional_death') is True
            and policy.get('omission_grants_approval') is False):
        raise ValueError('Invalid monster production scope')
    matches = [row for row in policy['monsters'] if row['id'] == key]
    if len(matches) > 1:
        raise ValueError('Duplicate monster identity')
    return matches[0] if matches else None


def required_roles(root, key):
    return frozenset(('idle', 'run', 'attack', 'hit', 'death')) if lookup(root, key) else None


def authoring_directions(root, key, role):
    if lookup(root, key) is None:
        return None
    return ('S',) if role == 'death' else DIRECTIONS


def required_directions(root, key, role):
    row = lookup(root, key)
    if row is None:
        return None
    if role != 'death':
        return DIRECTIONS
    # Existing approved motions stay required. An unapproved proxy is preserved
    # in the old catalog, but does not force eight NEW death sources.
    existing = row['existing_death_directions'] if row['preserved_status'] == 'VERIFIED_COMPLETED' else []
    return tuple(direction for direction in DIRECTIONS if direction == 'S' or direction in existing)
