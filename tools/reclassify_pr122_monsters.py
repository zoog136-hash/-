#!/usr/bin/env python3
"""Build the 318-monster production queues without granting art approvals."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

STATUS = 'docs/remake/evidence/pr122-remaining106/batch17/all498-production-status.json'
COVERAGE = 'docs/remake/evidence/pr100-direction-fix/original-based/coverage/coverage.json'
OUTPUT = 'data/pr122_monster_production_scope.json'
DIRECTIONS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']


def build(root):
    def read(path):
        return json.loads((root / path).read_text())

    status = read(STATUS)
    monsters = [row for row in status['species'] if row['id'].startswith('monster:')]
    assert len(monsters) == len({row['id'] for row in monsters}) == 318
    coverage = {row['key']: row for row in read(COVERAGE)['identities']}
    db = read('data/monsters/monster_world_catalog.json')
    catalog = read('data/catalog_v19.json')
    boss_evidence = {}

    def boss(name, evidence):
        boss_evidence.setdefault(name, []).append(evidence)

    for name, row in db['overlays'].items():
        if row.get('is_boss') or row.get('grade') == '보스':
            boss(name, 'monster_world_catalog.overlays.is_boss/grade')
    for row in db['additions']:
        if row.get('is_boss') or row.get('grade') == '보스':
            boss(row['name'], 'monster_world_catalog.additions.is_boss/grade')
    for row in catalog.get('몬스터', []):
        if row.get('is_boss') or row.get('grade') == '보스' or row.get('type') == '보스':
            boss(row['name'], 'catalog_v19.monsters.is_boss/grade/type')
    spawn_evidence = {}
    for map_id, map_row in read('data/monsters/world_spawn_profiles.json')['maps'].items():
        for row in map_row.get('monster_spawn', []):
            for name in row.get('monster_types', []):
                spawn_evidence.setdefault(name, []).append({'map': map_id, 'mode': row.get('mode', 'normal')})
                if row.get('mode') == 'boss' or row.get('boss_id') == name:
                    boss(name, 'world_spawn_profiles:' + map_id + ':' + row.get('id', ''))
    profiles = read('data/combat_animation_profiles.json')['profiles']
    binding_counts = Counter(profile.get('frames_path') for profile in profiles.values())
    staging_path = root / 'data/pr122_monster_animation_staging.json'
    staged = json.loads(staging_path.read_text()).get('actors', {}) if staging_path.is_file() else {}
    staged_parts = {key: [actor] for key, actor in staged.items()}
    index_path = root / 'data/pr122_monster_production_batches.json'
    if index_path.is_file():
        for ledger in json.loads(index_path.read_text())['staging_ledgers']:
            if ledger == 'data/pr122_monster_animation_staging.json':
                continue
            table = read(ledger)
            actors = table.get('actors', {})
            for key, actor in actors.items():
                if actor.get('replaces_previous_staging_selection') is True:
                    # Old sources remain in their immutable ledgers. A reviewed
                    # boss selection must not silently inherit a rejected view.
                    staged_parts[key] = [actor]
                else:
                    staged_parts.setdefault(key, []).append(actor)
            for key, adapter in table.get('family_adapters', {}).items():
                source = actors[adapter['source_actor']]
                staged_parts.setdefault(key, []).append(dict(source, **{
                    'native_profile': adapter['native_profile'],
                    'quality_review': adapter['quality_review'], 'new_source_poses': 0}))
    staged = {}
    for key, parts in staged_parts.items():
        tracks = {(track['direction'], track['role']): track for part in parts for track in part['tracks']}
        required = {(direction, role) for role in ('idle', 'run', 'attack', 'hit') for direction in DIRECTIONS} | {('S', 'death')}
        staged[key] = {
            'native_track_count': len(tracks),
            'native_pose_count': sum(len(track['geometry']['frames']) for track in tracks.values()),
            'missing_required_tracks': [f'{role}_{DIRECTIONS.index(direction)}' for direction, role in sorted(required - tracks.keys())],
            'quality_review': 'HOLD: source identity, actual support/contact, scale integration and default Main remain separate from technical playback',
            'profiles': [part['native_profile'] for part in parts],
            'source_coverage_only': len(parts) > 1,
        }
    result = []
    for old in monsters:
        key, name = old['id'], old['name']
        original_group = coverage[key]['group']
        evidence = list(boss_evidence.get(name, []))
        if original_group == 'boss':
            evidence.append('coverage:boss (named/regional/top encounter)')
        is_boss = bool(evidence)
        profile = profiles[key]
        completed = old['production_status'] == 'VERIFIED_COMPLETED'
        production_status = old['production_status']
        if not completed and key in staged and production_status == 'NOT_AUTHORED':
            production_status = 'IN_PROGRESS'
        shared = (any(profile.get(field) for field in ('shared_visual_source', 'shared_visual_policy'))
                  or binding_counts[profile.get('frames_path')] > 1)
        frames_path = root / profile.get('frames_path', '').removeprefix('res://')
        text = frames_path.read_text() if frames_path.is_file() else ''
        tracks = {name: len(re.findall(r'"duration"\s*:', body)) for body, name in re.findall(
            r'\{"frames"\s*:\s*\[(.*?)\],\s*"loop"\s*:\s*(?:true|false),\s*"name"\s*:\s*&"([^"]+)"', text, re.S)}
        existing_deaths = [direction for i, direction in enumerate(DIRECTIONS) if 'death_' + str(i) in tracks]
        if not completed:
            queue = {'IN_PROGRESS': 'finish_current', 'SOURCE_HOLD': 'repair_source',
                     'NOT_AUTHORED': 'author_source'}[old['production_status']]
        else:
            queue = 'preserve_completed'
        result.append({
            'id': key, 'name': name, 'kind': 'boss' if is_boss else 'normal',
            'quality_tier': 'mythic_transform' if is_boss else 'hero_transform',
            'classification_evidence': evidence or ['coverage:normal_monster; no boss DB/spawn flag'],
            'spawn_evidence': spawn_evidence.get(name, []),
            'preserved_status': old['production_status'], 'production_status': production_status,
            'queue': queue, 'priority': 0 if old['production_status'] == 'IN_PROGRESS' else (1 if old['production_status'] == 'SOURCE_HOLD' else 2),
            'reason': staged[key]['quality_review'] if key in staged else old['reason'],
            'historical_reason_preserved': old['reason'], 'frames_path': profile.get('frames_path', ''),
            'runtime_proxy': bool(profile.get('shared_visual_source')),
            'shared_visual_source': profile.get('shared_visual_source'),
            'shared_frames_binding_count': binding_counts[profile.get('frames_path')],
            'existing_death_directions': existing_deaths,
            'metadata_screen': {'SpriteFrames_present': frames_path.is_file(), 'track_counts': tracks,
                                'PNG_and_visual_quality': 'NOT_REVIEWED_BY_METADATA_SCREEN'},
            'quality_screen': ('REVIEW_SHARED_BOSS' if is_boss and shared else 'PRESERVE_APPROVAL_DETAILED_REVIEW_PENDING') if completed else 'SOURCE_PRODUCTION_PENDING',
            'new_staging': staged.get(key),
            'new_approval': False,
        })
    summary = {}
    for kind in ('normal', 'boss'):
        rows = [row for row in result if row['kind'] == kind]
        done = sum(row['production_status'] == 'VERIFIED_COMPLETED' for row in rows)
        summary[kind] = {'total': len(rows), 'completed_preserved': done, 'remaining': len(rows) - done,
                         'statuses': dict(Counter(row['production_status'] for row in rows))}
    pins = [STATUS, COVERAGE, 'data/monsters/monster_world_catalog.json',
            'data/monsters/world_spawn_profiles.json', 'data/catalog_v19.json']
    review_scope_path = root / 'data/pr122_monster_review_scope.json'
    review_scope = json.loads(review_scope_path.read_text()) if review_scope_path.is_file() else None
    if review_scope is not None:
        assert review_scope['include_previously_approved'] is True
        assert review_scope['normal']['review'] == 'frame_integrity_only'
        assert review_scope['boss']['review'] == 'mythic_quality'
        pins.append(review_scope_path.relative_to(root).as_posix())
        for row in result:
            row['current_review_requirement'] = 'frame_integrity_only' if row['kind'] == 'normal' else 'mythic_quality'
            row['historical_visual_holds_block_current_review'] = row['kind'] == 'boss'
    if index_path.is_file():
        pins.append(index_path.relative_to(root).as_posix())
        pins.extend(json.loads(index_path.read_text())['staging_ledgers'])
    return {
        'schema': 'pr122-monster-motion-scope-v1', 'user_instruction_date': '2026-10-23',
        'actor_kind': 'monster', 'required_roles': ['idle', 'run', 'attack', 'hit', 'death'],
        'new_walk_required': False, 'new_death_directions': ['S'],
        'directional_roles': {role: DIRECTIONS for role in ('idle', 'run', 'attack', 'hit')},
        'preserve_existing_walk': True, 'preserve_existing_directional_death': True,
        'preserve_existing_approvals': True, 'omission_grants_approval': False,
        'normal_reuse': 'Compatible family art/rig permitted; silhouette, species, contact and distinct actions required. Palette-only proxies confer no completion.',
        'boss_reuse': 'Dedicated identity-first source. Shared resources require explicit identity/quality review.',
        'summary': summary, 'monsters': result,
        'evidence_pins': [{'path': path, 'sha256': hashlib.sha256((root / path).read_bytes()).hexdigest()} for path in pins],
        'quality_audit_limit': 'DB/spawn and runtime binding screen only. Existing approvals are preserved; no new visual approval is inferred.',
        'current_review_scope': review_scope,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    value = build(root)
    data = (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()
    path = root / OUTPUT
    if args.check:
        assert path.read_bytes() == data, 'Monster classification is stale'
    else:
        path.write_bytes(data)
    print(json.dumps(value['summary'], ensure_ascii=False))


if __name__ == '__main__':
    main()
