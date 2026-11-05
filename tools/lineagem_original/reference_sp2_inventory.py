"""Verify the complete current523 reference set and keep delivery stages separate.

Only exact original member identities join. This module never guesses an actor
from a filename, treats a registry entry as installed pixels, or fetches inputs.
The full per-file ledger and source text stay in the caller's private output.
"""
from __future__ import annotations

import argparse
from collections import Counter
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import zlib

INVENTORY = 'current523_sp2_all54384_action_inventory.jsonl.gz'
CANDIDATES = 'main_parent_child_consumption_audit_final2982_candidates.jsonl.gz'
EXPECTED_FILES = 45990
EXPECTED_BYTES = 4824334813
EXPECTED_INVENTORY_FILES = 54384
EXPECTED_INVENTORY_BYTES = 5670117382
EXPECTED_OUTSIDE_FILES = 8394
OUTPUT_FILES = ('reference45990-ledger.jsonl.gz', 'source-action-links.jsonl.gz',
                'source-actions.jsonl.gz', 'source-declarations.jsonl.gz',
                'source-category-roots.jsonl.gz', 'compiler-requests.jsonl.gz',
                'outside-selected-families8394.jsonl.gz')


def digest(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            value.update(block)
    return value.hexdigest()


def rows(path):
    opener = gzip.open if str(path).endswith('.gz') else open
    with opener(path, 'rt', encoding='utf-8') as stream:
        for line in stream:
            yield json.loads(line)


def safe_member(member):
    if not isinstance(member, str):
        raise ValueError(f'unsafe original member: {member!r}')
    path = PurePosixPath(member)
    if (path.is_absolute() or '\\' in member or '\x00' in member
            or '..' in path.parts or str(path) != member or len(path.parts) != 2
            or path.parts[0] != 'Sprite' or path.suffix != '.sp2'):
        raise ValueError(f'unsafe original member: {member!r}')
    return path


def verify_manifest(directory, manifest_name):
    manifest_path = directory / manifest_name
    manifest = json.loads(manifest_path.read_text())
    seen = set()
    total_bytes = 0
    for item in manifest['members']:
        name = item['name']
        if name in seen or Path(name).name != name:
            raise ValueError(f'invalid manifest member: {name}')
        seen.add(name)
        path = directory / name
        if path.stat().st_size != item['bytes'] or digest(path) != item['sha256']:
            raise ValueError(f'handoff identity mismatch: {name}')
        total_bytes += item['bytes']
    expected_bytes = manifest.get('total_file_bytes', manifest.get('total_bytes'))
    if total_bytes != expected_bytes or len(seen) != manifest.get('total_files', len(seen)):
        raise ValueError(f'manifest totals mismatch: {manifest_name}')
    return {'manifest': manifest_name, 'sha256': digest(manifest_path),
            'files': len(seen), 'bytes': total_bytes}


def unique_index(path, key):
    result = {}
    for row in rows(path):
        identity = row[key]
        if identity in result:
            raise ValueError(f'duplicate {key} in {path.name}: {identity}')
        result[identity] = row
    return result


def totals(values):
    values = list(values)
    return {'files': len(values), 'original_bytes': sum(row['bytes'] for row in values)}


def category_totals(values):
    counts, sizes = Counter(), Counter()
    for row in values:
        categories = row['source_family_categories']
        if len(categories) != len(set(categories)):
            raise ValueError(f'duplicate source category: {row["member"]}')
        for category in categories:
            counts[category] += 1
            sizes[category] += row['bytes']
    return {category: {'files': counts[category], 'original_bytes': sizes[category]}
            for category in sorted(counts)}


def load_inventory(directory):
    inventory = {}
    for row in rows(directory / INVENTORY):
        member = row['member']
        safe_member(member)
        if member in inventory:
            raise ValueError(f'duplicate original member: {member}')
        inventory[member] = row
    selected = {name: row for name, row in inventory.items() if row['source_family_categories']}
    classification = json.loads((directory / 'current523_sp2_difference_classification.json').read_text())
    expected = classification['any_selected_source_family_in_difference']
    actual = {'files': len(selected), 'original_bytes': sum(x['bytes'] for x in selected.values())}
    if actual != expected or actual != {'files': EXPECTED_FILES, 'original_bytes': EXPECTED_BYTES}:
        raise ValueError(f'target denominator mismatch: {actual}')
    if (totals(inventory.values()) != {'files': EXPECTED_INVENTORY_FILES,
                                     'original_bytes': EXPECTED_INVENTORY_BYTES}
            or len(inventory) - len(selected) != EXPECTED_OUTSIDE_FILES):
        raise ValueError('difference inventory denominator mismatch')
    counts = category_totals(selected.values())
    expected_categories = {key: value['unconfirmed_in_this_lineage']
                           for key, value in classification['source_family_categories_nonadditive'].items()}
    if counts != expected_categories:
        raise ValueError('source-family file/byte cross-check failed')
    combinations = {}
    for row in inventory.values():
        key = tuple(sorted(row['source_family_categories']))
        group = combinations.setdefault(key, {'files': 0, 'original_bytes': 0})
        group['files'] += 1
        group['original_bytes'] += row['bytes']
    expected_combinations = {tuple(sorted(row['categories'])): {key: row[key] for key in ('files', 'original_bytes')}
                             for row in classification['exclusive_category_combinations']}
    if combinations != expected_combinations:
        raise ValueError('exclusive source-category combination cross-check failed')
    return inventory, selected


def inspect_original(row, roots):
    """An exact relative path, bytes and CRC are mandatory; SHA is never invented."""
    matches = []
    rejected = []
    for root in roots:
        path = root / row['member']
        if not path.is_file():
            continue
        if not path.resolve().is_relative_to(root.resolve()):
            rejected.append({'root': str(root), 'reason': 'source_symlink_outside_root'})
            continue
        raw = path.read_bytes()
        identity = {'bytes': len(raw), 'crc32': f'{zlib.crc32(raw) & 0xffffffff:08x}',
                    'sha256': hashlib.sha256(raw).hexdigest()}
        if identity['bytes'] != row['bytes'] or identity['crc32'] != row['crc32'].lower():
            rejected.append({'root': str(root), 'reason': 'original_size_or_crc_mismatch', 'observed': identity})
            continue
        # Historical SHA evidence can be structured. Only an explicit SHA field
        # is a digest; a source-text hash must never be used for original pixels.
        evidence = row.get('original_member_sha256_evidence')
        expected = evidence if isinstance(evidence, str) else (evidence or {}).get('sha256')
        if expected is not None and identity['sha256'] != expected:
            rejected.append({'root': str(root), 'reason': 'original_sha256_mismatch', 'observed': identity})
            continue
        matches.append({'path': str(path), **identity})
    hashes = {item['sha256'] for item in matches}
    if len(hashes) > 1:
        return {'status': 'conflicting_original_copies', 'matches': matches, 'rejected': rejected}
    return {'status': 'verified_local_original' if matches else 'original_bytes_unavailable',
            'matches': matches, 'rejected': rejected}


def candidate_evidence(row):
    # Preserve exact frame addresses, alias chains, dependency source lines,
    # historical error caveats and all original action IDs. No role is inferred.
    return row.get('candidates', [])


def private_output_path(output):
    """Reject repository paths and symlinks before creating any private data."""
    output = Path(output).absolute()
    if any(path.is_symlink() for path in (output, *output.parents)):
        raise ValueError('private ledger output must not traverse a symlink')
    output = output.resolve()
    module_root = Path(__file__).resolve().parents[2]
    # A private copy can sit below /workspace/.git, which is not this game's
    # repository. Identify the game repository by its actual project marker.
    repositories = {path for path in (output, *output.parents)
                    if (path / 'project.godot').is_file()}
    if (module_root / 'project.godot').is_file():
        repositories.add(module_root)
    if any(output.is_relative_to(repository) for repository in repositories):
        raise ValueError('private ledger output must be outside the repository')
    return output


def prepare_private_output(output):
    output = private_output_path(output)
    if any((output / name).exists() or (output / name).is_symlink()
           for name in (*OUTPUT_FILES, 'summary.json', 'validation.json')):
        raise ValueError('output contains an existing ledger; choose an empty destination')
    output.mkdir(parents=True, exist_ok=True, mode=0o700)
    output.chmod(0o700)
    return output


def private_binary(path):
    """Create one owner-only artifact without following or replacing links."""
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0)
    directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | getattr(os, 'O_NOFOLLOW', 0))
    try:
        descriptor = os.open(path.name, flags, 0o600, dir_fd=directory)
    finally:
        os.close(directory)
    os.fchmod(descriptor, 0o600)
    return os.fdopen(descriptor, 'wb')


def write_json(path, document):
    with private_binary(path) as stream:
        stream.write((json.dumps(document, ensure_ascii=False, indent=2) + '\n').encode('utf-8'))


def declaration_keys(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == 'declaration_key':
                yield child
            else:
                yield from declaration_keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from declaration_keys(child)


def verify_supplemental(inventory, candidates, consumption, supplemental):
    if totals(consumption.values()) != {'files': 34417, 'original_bytes': 2898034588}:
        raise ValueError('supplemental declaration-family denominator mismatch')
    for group in (consumption, candidates):
        for member, row in group.items():
            safe_member(member)
            expected = inventory.get(member)
            if expected is None:
                raise ValueError(f'supplemental member absent from inventory: {member}')
            for key in ('archive', 'container', 'bytes', 'crc32', 'version_basis', 'original_member_sha256_evidence'):
                if row.get(key) != expected.get(key):
                    raise ValueError(f'supplemental original identity mismatch: {member}:{key}')
    if set(consumption) != {member for member, row in inventory.items()
                           if row['action_classification'] == 'only_declared_prefix_family'}:
        raise ValueError('supplemental members do not exactly cover declaration-family inventory')
    candidate_summary = json.loads((supplemental / 'main_parent_child_consumption_audit_final2982_summary.json').read_text())
    observed = totals(candidates.values())
    if observed != {'files': candidate_summary['files'], 'original_bytes': candidate_summary['bytes']}:
        raise ValueError('parent candidate denominator mismatch')
    subcandidates = [item for row in candidates.values() for item in row['candidates']]
    if len(subcandidates) != candidate_summary['candidate_rows']:
        raise ValueError('parent candidate action count mismatch')
    statuses = {}
    for row in candidates.values():
        group = statuses.setdefault(row['status'], {'files': 0, 'bytes': 0})
        group['files'] += 1
        group['bytes'] += row['bytes']
        if row['candidate_count'] != len(row['candidates']):
            raise ValueError('parent candidate row count mismatch')
        if consumption[row['member']]['pack_consumption_classification'] != 'registered_parent_action_address_candidate_not_compiled':
            raise ValueError('parent candidate historical classification mismatch')
        for item in row['candidates']:
            if (item['current_resolution_status'] != 'exact_effective_raw_match'
                    or item['current_effective_dependency_contains_child'] is not True):
                raise ValueError('parent candidate is not an exact effective dependency')
    if statuses != candidate_summary['exclusive_file_status']:
        raise ValueError('parent candidate status conservation failed')
    return candidate_summary


def write_jsonl(path, iterable):
    # Stable compressed artifacts are hashable and resumable across executors.
    with private_binary(path) as raw:
        with gzip.GzipFile(filename='', mode='wb', fileobj=raw, mtime=0) as stream:
            for item in iterable:
                stream.write((json.dumps(item, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n').encode())


def validate_output(output, summary, inventory, selected, candidates, links,
                    actions, declarations, category_roots, requests):
    """Read every emitted record back; fail closed before reporting success."""
    counts = {}
    seen = set()
    seen_bytes = 0
    classifications, blockers = Counter(), Counter()
    parent_file_count = parent_action_count = 0
    previous = None
    for row in rows(output / 'reference45990-ledger.jsonl.gz'):
        member = row['member']
        if member in seen or member not in selected or (previous is not None and member <= previous):
            raise ValueError('ledger exact member conservation failed')
        previous = member
        seen.add(member)
        source = selected[member]
        if row['source_inventory'] != source:
            raise ValueError('source inventory evidence changed on readback: ' + member)
        if (row['source_classification'] != source['action_classification']
                or row['source_family_categories'] != source['source_family_categories']
                or row['action_link_keys'] != source['actual_source_action_link_keys']
                or row['saved_frame_evidence'] != source['saved_SP2_frame_evidence']):
            raise ValueError('ledger source evidence mismatch: ' + member)
        expected_parent = candidates.get(member, {})
        if row['parent_action_candidates'] != expected_parent.get('candidates', []):
            raise ValueError('parent candidate evidence changed on readback: ' + member)
        parent_header = {key: value for key, value in expected_parent.items() if key != 'candidates'} or None
        if row['parent_candidate_file_evidence'] != parent_header:
            raise ValueError('parent file evidence changed on readback: ' + member)
        parent_file_count += member in candidates
        parent_action_count += len(row['parent_action_candidates'])
        if any(row[key] is not None for key in ('packed_output', 'registry', 'consumer_event_selection',
                                               'active_installation', 'playback_evidence')):
            raise ValueError('unobserved runtime delivery stage was populated')
        if row['map_lane_dependency'] != any(key.startswith('map_') for key in source['source_family_categories']):
            raise ValueError('map dependency conservation failed')
        if row['blockers'] != sorted(set(row['blockers'])):
            raise ValueError('duplicate or unstable blocker list')
        required = {'current_pack_compilation_unverified', 'consumer_event_selection_unverified',
                    'active_installation_unobserved', 'main_playback_unobserved'}
        if not required.issubset(row['blockers']):
            raise ValueError('unobserved delivery stage blocker missing')
        seen_bytes += source['bytes']
        classifications[row['source_classification']] += 1
        blockers.update(row['blockers'])
    if seen != selected.keys() or len(seen) != EXPECTED_FILES or seen_bytes != EXPECTED_BYTES:
        raise ValueError('ledger full denominator conservation failed')
    if (dict(classifications) != summary['source_classifications']
            or dict(blockers) != summary['blocker_counts_nonadditive']
            or parent_file_count != summary['parent_candidate_files']
            or parent_action_count != summary['parent_candidate_actions']):
        raise ValueError('ledger summary conservation failed')
    counts['reference45990-ledger.jsonl.gz'] = len(seen)
    index_specs = [('source-action-links.jsonl.gz', links, lambda row: row['link_key']),
                   ('source-actions.jsonl.gz', actions, lambda row: row['action_key']),
                   ('source-declarations.jsonl.gz', declarations, lambda row: row['declaration_key']),
                   ('source-category-roots.jsonl.gz', category_roots,
                    lambda row: f'{row["category"]}:{row["sprite_id"]}'),
                   ('outside-selected-families8394.jsonl.gz',
                    {key: row for key, row in inventory.items() if key not in selected}, lambda row: row['member'])]
    for name, expected, identity in index_specs:
        index_seen = set()
        for row in rows(output / name):
            key = identity(row)
            if key in index_seen or expected.get(key) != row:
                raise ValueError(f'index evidence readback mismatch: {name}:{key}')
            index_seen.add(key)
        if index_seen != expected.keys():
            raise ValueError('index readback denominator mismatch: ' + name)
        counts[name] = len(index_seen)
    request_seen = set()
    for row in rows(output / 'compiler-requests.jsonl.gz'):
        key = row['actor_id'], row['action_id'], row['action_key']
        if (key in request_seen or key not in requests
                or row['target_members'] != sorted(requests[key])
                or any(selected[member]['action_classification'] == 'ambiguous'
                       or selected[member]['source_resolution_ambiguities'] for member in row['target_members'])
                or actions[row['action_key']]['action_id'] != row['action_id']
                or row['status'] != 'metadata_request_only_not_compile_or_event_approval'
                or row['selection_semantics'] != 'exact_source_action_id_only_no_gameplay_role_inferred'):
            raise ValueError('compiler request readback mismatch')
        request_seen.add(key)
    if request_seen != requests.keys():
        raise ValueError('compiler request denominator mismatch')
    counts['compiler-requests.jsonl.gz'] = len(request_seen)
    for artifact in summary['artifacts']:
        path = output / artifact['name']
        if path.stat().st_size != artifact['bytes'] or digest(path) != artifact['sha256']:
            raise ValueError('output artifact hash mismatch: ' + path.name)
    validation = {
        'status': 'PASS', 'scope': 'complete_local_metadata_ledger_readback_only',
        'record_counts': dict(sorted(counts.items())),
        'target_files': len(seen), 'target_original_bytes': seen_bytes,
        'exact_member_deduplication': True, 'original_inventory_preserved_exactly': True,
        'full_parent_candidates_preserved_exactly': True,
        'source_indices_preserved_exactly': True, 'source_family_file_and_byte_crosscheck': True,
        'exclusive_source_category_combinations_crosscheck': True,
        'installed_and_played_states_remain_null': True,
        'originals_downloaded': 0, 'new_sp2_decodes': 0,
        'compiled_this_run_files': 0, 'game_runs': 0, 'published_artifacts': 0,
        'summary_sha256': digest(output / 'summary.json'),
        'implementation_sha256': digest(__file__),
        'artifacts': summary['artifacts'],
    }
    write_json(output / 'validation.json', validation)


def build(metadata, supplemental, output, original_roots=(), transfer_blocker=None):
    output = private_output_path(output)
    proofs = [verify_manifest(metadata, 'current523_sp2_metadata_handoff_manifest.json'),
              verify_manifest(supplemental, 'main_parent_child_consumption_audit_metadata_manifest.json')]
    inventory, selected = load_inventory(metadata)
    candidates = unique_index(supplemental / CANDIDATES, 'member')
    consumption = unique_index(supplemental / 'main_parent_child_consumption_audit_all34417_file_inventory.jsonl.gz', 'member')
    parent_summary = verify_supplemental(inventory, candidates, consumption, supplemental)
    if set(candidates) - selected.keys():
        raise ValueError('parent candidate unexpectedly outside selected families')
    contexts = unique_index(metadata / 'current523_sp2_actor_dependency_context.jsonl.gz', 'source_owner_key')
    wanted_links = {key for row in selected.values() for key in row['actual_source_action_link_keys']}
    links = {}
    for row in rows(metadata / 'current523_sp2_action_file_links.jsonl.gz'):
        if row['link_key'] in wanted_links:
            if row['link_key'] in links:
                raise ValueError('duplicate action link ' + row['link_key'])
            links[row['link_key']] = row
    if links.keys() != wanted_links:
        raise ValueError('missing declared action links')
    wanted_actions = {row['action_key'] for row in links.values()}
    for row in candidates.values():
        if row['member'] in selected:
            wanted_actions.update(x['current_effective_action']['action_key'] for x in row['candidates'])
    wanted_declarations = {key for row in selected.values()
                           for key in declaration_keys(contexts.get(row['source_owner_context_key']))}
    wanted_declarations.update(key for row in candidates.values() for key in declaration_keys(row))
    wanted_declarations.update(key for row in links.values() for key in declaration_keys(row))
    all_declarations = unique_index(metadata / 'current523_sp2_declaration_raw_index.jsonl.gz', 'declaration_key')
    wanted_declarations.update(key for key, row in all_declarations.items()
                               if wanted_actions.intersection(row['animation_action_keys']))
    if wanted_declarations - all_declarations.keys():
        raise ValueError('missing source declaration evidence')
    declarations = {key: all_declarations[key] for key in wanted_declarations}
    del all_declarations
    addressed_actions = set(wanted_actions)
    # Keep unaddressed sibling source actions as source evidence only. They are
    # deliberately not added to compiler requests or inferred gameplay roles.
    wanted_actions.update(key for row in declarations.values() for key in row['animation_action_keys'])
    actions = {}
    for row in rows(metadata / 'current523_sp2_action_source_index.jsonl.gz'):
        if row['action_key'] in wanted_actions:
            if row['action_key'] in actions:
                raise ValueError('duplicate source action key ' + row['action_key'])
            actions[row['action_key']] = row
    if actions.keys() != wanted_actions:
        raise ValueError('missing source action evidence')
    for row in selected.values():
        for key in row['actual_source_action_link_keys']:
            link = links[key]
            action = actions[link['action_key']]
            if (link['member'] != row['member'] or link['source_action_id'] != action['action_id']
                    or link['source_file'] != action['source_file']
                    or link['source_line'] != action['source_line']):
                raise ValueError('source action link identity mismatch: ' + key)
    for row in candidates.values():
        for item in row['candidates']:
            action = actions[item['current_effective_action']['action_key']]
            if item['action_id'] != action['action_id']:
                raise ValueError('parent candidate source action ID mismatch')
            for key, value in item['current_effective_action'].items():
                if action[key] != value:
                    raise ValueError('parent candidate source action evidence mismatch: ' + key)
    wanted_roots = {key for row in selected.values()
                    for item in (contexts.get(row['source_owner_context_key']) or {}).get('explicit_table_contexts', [])
                    for key in item['table_reference_record_keys']}
    category_roots = {}
    for row in rows(metadata / 'current523_sp2_category_root_evidence.jsonl.gz'):
        key = f'{row["category"]}:{row["sprite_id"]}'
        if key in wanted_roots:
            if key in category_roots:
                raise ValueError('duplicate category root ' + key)
            category_roots[key] = row
    if category_roots.keys() != wanted_roots:
        raise ValueError('missing declared source table root evidence')
    output = prepare_private_output(output)
    blockers = Counter()
    states = Counter()
    requests = {}
    original_states = Counter()
    ledger_count = 0

    def ledger_rows():
        nonlocal ledger_count
        for member, row in sorted(selected.items()):
            original = inspect_original(row, original_roots)
            pending = []
            if original['status'] != 'verified_local_original':
                pending.append(original['status'])
            if row['source_resolution_ambiguities'] or row['action_classification'] == 'ambiguous':
                pending.append('source_resolution_ambiguous')
            parent = candidate_evidence(candidates.get(member, {}))
            direct = [links[key] for key in row['actual_source_action_link_keys']]
            if not direct and not parent:
                pending.append('no_effective_action_address_in_supplied_metadata')
                pending.append('source_action_timing_unresolved')
            saved_frames = row['saved_SP2_frame_evidence']
            if saved_frames is None or saved_frames.get('stored_frame_counts') is None:
                pending.append('saved_directional_frame_evidence_unavailable')
            for issue in ('stored_direction_absent', 'frame_out_of_stored_range', 'no_matching_saved_structural_frame_evidence'):
                if row['action_reference_and_frame_check_counts'].get(issue):
                    pending.append(issue)
            for link in direct:
                action = actions[link['action_key']]
                if action['explicit_fps'] is None or action['explicit_fps'] <= 0:
                    pending.append('explicit_source_fps_unavailable')
                if action['parse_issues']:
                    pending.append('source_action_parse_issues')
                if row['action_classification'] != 'ambiguous' and not row['source_resolution_ambiguities']:
                    for actor in link['consuming_SPR_ids']:
                        request = requests.setdefault((actor, action['action_id'], action['action_key']), set())
                        request.add(member)
            for item in parent:
                key = item['current_effective_action']['action_key']
                requests.setdefault((item['actor_id'], item['action_id'], key), set()).add(member)
            if any(not item['timing_metadata_ready'] for item in parent):
                pending.append('parent_action_source_or_timing_review')
            if any(item['frame_check_status'] != 'valid-only' for item in parent):
                pending.append('parent_action_frame_review')
            map_owned = any(x.startswith('map_') for x in row['source_family_categories'])
            if map_owned:
                pending.append('map_lane_placement_and_event_dependency')
            pending.extend(['current_pack_compilation_unverified', 'consumer_event_selection_unverified',
                            'active_installation_unobserved', 'main_playback_unobserved'])
            historical = consumption.get(member, {})
            context = contexts.get(row['source_owner_context_key'])
            if context is None:
                pending.append('source_owner_context_absent')
            pending = sorted(set(pending))
            blockers.update(pending)
            states[row['action_classification']] += 1
            original_states[original['status']] += 1
            ledger_count += 1
            yield {
                'member': member,
                'source_inventory': row,
                'original_identity': {key: row.get(key) for key in ('archive', 'container', 'bytes', 'crc32', 'version_basis', 'original_member_sha256_evidence')},
                'source_family_categories': row['source_family_categories'],
                'source_classification': row['action_classification'],
                'source_owner_context': context,
                'action_link_keys': row['actual_source_action_link_keys'],
                'parent_action_candidates': parent,
                'parent_candidate_file_evidence': {key: value for key, value in candidates.get(member, {}).items()
                                                   if key != 'candidates'} or None,
                'saved_frame_evidence': row['saved_SP2_frame_evidence'],
                'source_ambiguities': row['source_resolution_ambiguities'],
                'existing_connection': {'basis': 'supplemental_pinned_main_audit_not_live_observation',
                                        'pinned_main': '00b84cfe19c05e01d30208384bf7fbcc4ae6bbf2',
                                        'audit_record': historical or None,
                                        'classification': historical.get('pack_consumption_classification'),
                                        'registered_matches': historical.get('registered_matches'),
                                        'compiled_frame_path_matches': historical.get('compiled_frame_path_matches'),
                                        'independent_map_registry': historical.get('independent_map989_registry')},
                'original_input': original,
                'packed_output': None, 'registry': None, 'consumer_event_selection': None,
                'active_installation': None, 'playback_evidence': None,
                'map_lane_dependency': map_owned,
                'blockers': pending,
                'transfer_blocker': transfer_blocker if original['status'] != 'verified_local_original' else None,
            }
    write_jsonl(output / 'reference45990-ledger.jsonl.gz', ledger_rows())
    write_jsonl(output / 'source-action-links.jsonl.gz', (links[x] for x in sorted(links)))
    write_jsonl(output / 'source-actions.jsonl.gz', (actions[x] for x in sorted(actions)))
    write_jsonl(output / 'source-declarations.jsonl.gz', (declarations[x] for x in sorted(declarations)))
    write_jsonl(output / 'source-category-roots.jsonl.gz', (category_roots[x] for x in sorted(category_roots)))
    write_jsonl(output / 'compiler-requests.jsonl.gz', ({'actor_id': key[0], 'action_id': key[1], 'action_key': key[2],
                                                     'target_members': sorted(members),
                                                     'status': 'metadata_request_only_not_compile_or_event_approval',
                                                     'selection_semantics': 'exact_source_action_id_only_no_gameplay_role_inferred'}
                                                    for key, members in sorted(requests.items())))
    write_jsonl(output / 'outside-selected-families8394.jsonl.gz', (row for name, row in sorted(inventory.items()) if name not in selected))
    summary = {'schema': 2, 'source_snapshot': 'current523', 'target_files': ledger_count,
               'target_bytes': sum(x['bytes'] for x in selected.values()), 'outside_target_files': EXPECTED_OUTSIDE_FILES,
               'outside_target_bytes': EXPECTED_INVENTORY_BYTES - EXPECTED_BYTES,
               'source_classifications': dict(states), 'blocker_counts_nonadditive': dict(sorted(blockers.items())),
               'source_family_counts_nonadditive': category_totals(selected.values()),
               'original_inputs_verified': original_states['verified_local_original'],
               'original_input_states': dict(original_states),
               'source_action_links': len(links), 'source_actions': len(actions),
               'addressed_source_actions': len(addressed_actions), 'source_declarations': len(declarations),
               'source_category_roots': len(category_roots), 'parent_candidate_files': len(candidates),
               'parent_candidate_actions': parent_summary['candidate_rows'],
               'parent_candidate_statuses': parent_summary['exclusive_file_status'],
               'ambiguous_files_not_promoted': states['ambiguous'],
               'compiler_requests': len(requests), 'compiled_this_run_files': 0,
               'compiled_files': None, 'installed_files': None, 'main_played_files': None,
               'transfer_blocker': transfer_blocker,
               'metadata_proofs': proofs,
               'implementation': {'path': str(Path(__file__).resolve()), 'sha256': digest(__file__)},
               'artifacts': [{'name': name, 'bytes': (output / name).stat().st_size, 'sha256': digest(output / name)}
                             for name in sorted(OUTPUT_FILES)],
               'limitations': ['Metadata evidence is not compilation, installation or playback.',
                               'Categories overlap. Source table references do not authorize excluded gameplay.',
                               'A per-file review blocker can coexist with a ready parent candidate when another action needs review.',
                               'Map placement belongs to the map lane. UI, sound, arena, Ziggurat, clan, siege, pets and engine/APK work stay excluded.',
                               'Existing registrations and compiled paths are historical audit evidence, not local installed pixels.']}
    write_json(output / 'summary.json', summary)
    validate_output(output, summary, inventory, selected, candidates, links, actions, declarations, category_roots, requests)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--metadata', type=Path, required=True)
    parser.add_argument('--supplemental', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--original-root', type=Path, action='append', default=[])
    parser.add_argument('--transfer-blocker', help='Exact observed transfer failure, without credentials or URLs')
    args = parser.parse_args()
    summary = build(args.metadata, args.supplemental, args.output, args.original_root, args.transfer_blocker)
    print(json.dumps({key: summary[key] for key in ('target_files', 'target_bytes', 'outside_target_files', 'original_inputs_verified', 'compiler_requests', 'source_classifications')}, ensure_ascii=False))


if __name__ == '__main__':
    main()
