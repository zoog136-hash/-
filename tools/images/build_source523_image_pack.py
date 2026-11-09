#!/usr/bin/env python3
"""Build a private exact-original source523 image pack; never transform pixels.

All inputs and outputs are explicit. The source index and decoder summary must
be pinned by the caller. This tool does not activate a pack or write user saves.
"""
import argparse
import collections
import hashlib
import io
import json
import os
import pathlib
import shutil
import tempfile

IMAGE_TYPES = {1, 3, 5, 6, 7, 9, 10, 11, 82, 143, 161}
CONSUMER_FIELDS = {'ItemClass': ['IconID'], 'SpellClass': ['IconID', 'ActivateIconID'],
                   'BuffClass': ['OnIconID', 'OffIconID']}
SOURCE_TABLES = ['AssetView', 'AssetType', 'Icon', *CONSUMER_FIELDS]
DUMMY_IMAGE_TABLE = 'UIBuffCardDummyImagePath'
COMPONENTS = {'retained_noncard_lineage14964', 'changed4_current523',
              'retained_historical_card_lineage1216', 'client523_files_info_verified'}
# Complete-client mode (tools/images/client523_image_inputs.py): every container
# is identified by the 523 files_info SHA-1/size instead of the earlier handoff's
# retained-lineage inventory and four changed DATs.
CLIENT_SOURCE_MODE = 'client523_files_info'
CLIENT_COMPONENT = 'client523_files_info_verified'
CLIENT_ALIGNMENT = 'client523_files_info_sha1_size_verified'


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def strict_json(raw):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'Duplicate JSON object key: ' + key)
            result[key] = value
        return result
    return json.loads(raw.decode('utf-8-sig'), object_pairs_hook=unique)


def safe_relative(value):
    require(isinstance(value, str) and value and ':' not in value and '\\' not in value
            and not value.startswith('/') and not any(ord(c) < 32 for c in value),
            'Unsafe relative path')
    require(all(part not in {'', '.', '..'} for part in value.split('/')),
            'Unsafe relative path component')
    return value


def verify_file(path, expected_bytes, expected_sha256):
    require(path.is_file() and not path.is_symlink(), 'Missing or symlink file: ' + str(path))
    data = path.read_bytes()
    require(len(data) == expected_bytes and sha256(data) == expected_sha256,
            'File bytes/SHA mismatch: ' + str(path))
    return data


def validate_output_destination(output, protected_paths, script_path):
    destination = output.resolve()
    require(not output.exists(), 'Output must not already exist')
    for protected in protected_paths:
        require(not destination.is_relative_to(protected.resolve()), 'Output must be outside inputs')
    for ancestor in script_path.resolve().parents:
        if (ancestor / 'project.godot').is_file() or (ancestor / '.git').exists():
            require(not destination.is_relative_to(ancestor), 'Output must be outside public project')
            break


def validate_table(name, raw_bytes, source_index_rows):
    entries = [r for r in source_index_rows if r.get('path') == 'content/' + name + '.json']
    require(len(entries) == 1, 'Missing or duplicate source index table: ' + name)
    entry = entries[0]
    require(entry.get('version') == 523 and entry.get('status') == 'strict_json_pass'
            and entry.get('member_crc_verified') is True, 'Unverified source index table: ' + name)
    require(entry.get('bytes') == len(raw_bytes) and entry.get('sha256') == sha256(raw_bytes),
            'Source table bytes/SHA mismatch: ' + name)
    table = strict_json(raw_bytes)
    require(isinstance(table, dict) and isinstance(table.get('rows'), list), 'Invalid source rows: ' + name)
    rows = table['rows']
    require(entry.get('row_count') == len(rows), 'Source row count mismatch: ' + name)
    return rows


def unique_members(rows):
    result, folded = {}, set()
    for row in rows:
        path = safe_relative(row['path'])
        require(path not in result and path.casefold() not in folded, 'Duplicate logical member path: ' + path)
        result[path] = row
        folded.add(path.casefold())
    return result


def keyed(rows, key, label):
    values = {}
    for row in rows:
        require(isinstance(row, dict) and type(row.get(key)) is int, 'Invalid key in ' + label)
        require(row[key] not in values, 'Duplicate key in ' + label)
        values[row[key]] = row
    return values


def validate_member_record(row, container_spec, retained_by_identity, changed_specs):
    safe_relative(row['path'])
    safe_relative(row['container'])
    safe_relative(row['relative_output_path'])
    require(row.get('current523_component') in COMPONENTS, 'Unknown member component')
    require(container_spec.get('container') == row['container']
            and container_spec.get('original_container_identity_verified') is True
            and container_spec.get('index_exactly_consumed') is True
            and container_spec.get('errors') == 0, 'Unverified DAT container')
    require(row.get('original_container_sha256') == container_spec.get('sha256')
            and row.get('original_container_bytes') == container_spec.get('bytes'), 'Container identity mismatch')
    require(row.get('original_bytes_preserved') is True and row.get('pkcs7_padding_verified') is True
            and row.get('pillow_verify_and_load') is True, 'Original member proof missing')
    require(row.get('format') in {'PNG', 'JPEG', 'BMP'}, 'Unsupported original image format')
    if row['current523_component'] == CLIENT_COMPONENT:
        basis = container_spec.get('identity_basis', {})
        require(row.get('current523_alignment') == CLIENT_ALIGNMENT
                and basis.get('current523_alignment') == CLIENT_ALIGNMENT
                and basis.get('sha1') == container_spec.get('sha1')
                and basis.get('sha256') == row['original_container_sha256']
                and basis.get('bytes') == row['original_container_bytes'],
                'Client files_info container identity proof missing')
        require(not retained_by_identity and not changed_specs, 'Client mode cannot mix handoff identities')
    if row['format'] == 'PNG':
        require(row.get('png_all_chunk_crc_verified') is True, 'PNG CRC proof missing')
    for field in ['encrypted_bytes', 'plain_bytes', 'width', 'height']:
        require(type(row.get(field)) is int and row[field] > 0, 'Invalid member numeric field: ' + field)
    for field in ['sha256', 'stored_member_sha256', 'original_container_sha256']:
        require(isinstance(row.get(field), str) and len(row[field]) == 64
                and all(c in '0123456789abcdef' for c in row[field]), 'Invalid member SHA field: ' + field)
    if row['current523_component'] == CLIENT_COMPONENT:
        for field in ['encrypted_bytes', 'plain_bytes', 'width', 'height']:
            require(type(row.get(field)) is int and row[field] > 0, 'Invalid member numeric field: ' + field)
        return row
    changed = changed_specs.get(row['container'])
    if row['current523_component'] == 'changed4_current523':
        require(changed is not None and changed['sha256'] == row['original_container_sha256']
                and changed['bytes'] == row['original_container_bytes'], 'Changed DAT stale identity rejected')
        require(row.get('current523_alignment') == 'exact_current523_changed_original_size_sha1_sha256',
                'Changed DAT current identity proof missing')
    else:
        require(changed is None, 'Changed DAT cannot use retained metadata identity')
        previous = retained_by_identity.get((row['container'], row['path']))
        require(previous is not None and row.get('retained_prior_catalog_all_fields_verified') is True
                and container_spec.get('identity_basis', {}).get('retained_prior_catalog_container_identity') is True,
                'Retained whole-DAT metadata identity proof missing')
        basis = container_spec['identity_basis']
        require(basis.get('sha256') == row['original_container_sha256']
                and basis.get('bytes') == row['original_container_bytes'],
                'Retained whole-DAT metadata SHA/bytes mismatch')
        for field in ['encrypted_bytes', 'plain_bytes', 'sha256', 'format', 'width', 'height']:
            require(row.get(field) == previous.get(field), 'Retained original field mismatch: ' + field)
        expected_component = ('retained_historical_card_lineage1216' if previous.get('historical_card_pack_lineage')
                              else 'retained_noncard_lineage14964')
        require(row['current523_component'] == expected_component, 'Retained lineage component mismatch')
    return row


def compile_assets(asset_rows, type_rows, members):
    assets, types = keyed(asset_rows, 'AssetId', 'AssetView'), keyed(type_rows, 'ID', 'AssetType')
    result = []
    for index, row in enumerate(asset_rows):
        require(type(row.get('AssetTypeId')) is int and isinstance(row.get('FilePath'), str), 'Invalid AssetView fields')
        require(row['AssetTypeId'] in types, 'Missing AssetType key')
        typed = types[row['AssetTypeId']]
        require(isinstance(typed.get('Path'), str), 'Invalid AssetType.Path')
        path = typed['Path'] + row['FilePath']
        status = ('zero_sentinel' if row['AssetId'] == 0 or not row['FilePath'] else
                  'unsupported_csb' if row['AssetTypeId'] == 101 else
                  'unsupported_asset_type' if row['AssetTypeId'] not in IMAGE_TYPES else
                  'verified_original' if path in members else 'missing_current_member')
        if row['AssetId'] != 0 and row['FilePath']:
            safe_relative(path)
        result.append({'asset_id': row['AssetId'], 'asset_type_id': row['AssetTypeId'],
                       'path': path, 'status': status, 'asset_view_row_index_zero': index,
                       'asset_type_row_index_zero': type_rows.index(typed)})
    return result


def verify_image(data, record):
    # Inspect exact existing original bytes only. No encoder, pixel edits or save.
    from PIL import Image
    with Image.open(io.BytesIO(data)) as image:
        require(image.format == record['format'] and image.size == (record['width'], record['height']),
                'Original image format/dimensions mismatch')
        image.verify()
    with Image.open(io.BytesIO(data)) as image:
        image.load()


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')) + '\n').encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['tables', 'source-index', 'decoder-summary', 'output']:
        parser.add_argument('--' + name, type=pathlib.Path, required=True)
    parser.add_argument('--inventory', type=pathlib.Path,
                        help='Earlier handoff inventory; not used for a client523_files_info decoder summary')
    parser.add_argument('--decoded-root', type=pathlib.Path,
                        help='Original decoded files root when catalog/summary are a pinned snapshot')
    for name in ['source-index', 'decoder-summary']:
        parser.add_argument('--expected-' + name + '-sha256', required=True)
    parser.add_argument('--expected-inventory-manifest-sha256')
    parser.add_argument('--hardlink-originals', action='store_true',
                        help='Hard-link verified decoded originals into the pack instead of copying (same filesystem)')
    args = parser.parse_args()
    protected = [args.tables, args.source_index.parent, args.decoder_summary.parent]
    if args.inventory is not None:
        protected.append(args.inventory)
    validate_output_destination(args.output, protected, pathlib.Path(__file__))
    source_raw = args.source_index.read_bytes()
    summary_raw = args.decoder_summary.read_bytes()
    require(sha256(source_raw) == args.expected_source_index_sha256, 'Pinned source index SHA mismatch')
    require(sha256(summary_raw) == args.expected_decoder_summary_sha256, 'Pinned decoder summary SHA mismatch')
    source_index, summary = strict_json(source_raw), strict_json(summary_raw)
    require(isinstance(source_index, list), 'Invalid source index')
    require(summary.get('strict_failure_count') == 0, 'Decoder has strict failures')
    decoder_root = args.decoder_summary.parent
    decoded_root = args.decoded_root or decoder_root
    require(not args.output.resolve().is_relative_to(decoded_root.resolve()), 'Output must be outside decoded inputs')
    catalog_path = decoder_root / 'current523-verified-member-catalog.jsonl'
    catalog_raw = verify_file(catalog_path, summary['catalog_bytes'], summary['catalog_sha256'])
    catalog = [strict_json(line) for line in catalog_raw.splitlines() if line]
    require(len(catalog) == summary['verified_original_members'], 'Decoder member count mismatch')
    all_members = unique_members(catalog)
    client_mode = summary.get('source_mode') == CLIENT_SOURCE_MODE
    inventory_raw = None
    if client_mode:
        require(args.inventory is None and args.expected_inventory_manifest_sha256 is None,
                'Client-source decoder summary takes no earlier handoff inventory')
        require(summary.get('files_info_version') == 523, 'Client-source summary is not 523')
        retained_rows, retained, changed = [], {}, {}
    else:
        require(args.inventory is not None and args.expected_inventory_manifest_sha256 is not None,
                'Handoff decoder summary requires --inventory and its manifest pin')
        inventory_raw = (args.inventory / 'MANIFEST.json').read_bytes()
        require(sha256(inventory_raw) == args.expected_inventory_manifest_sha256, 'Pinned inventory manifest SHA mismatch')
        inventory = strict_json(inventory_raw)
        retained_name = 'audit/current523_retained_images_lineage_diff.jsonl.gz'
        retained_specs = [r for r in inventory['files'] if r['path'] == retained_name]
        require(len(retained_specs) == 1, 'Missing/duplicate retained inventory contract')
        retained_spec = retained_specs[0]
        retained_raw = verify_file(args.inventory / retained_name, retained_spec['bytes'], retained_spec['sha256'])
        import gzip
        retained_rows = [strict_json(line) for line in gzip.decompress(retained_raw).splitlines() if line]
        retained = {(r['container'], r['path']): r for r in retained_rows}
        require(len(retained) == len(retained_rows), 'Duplicate retained identity')
        changed = {r['path'].removeprefix('current523-originals/'): r for r in inventory['files']
                   if r['path'].startswith('current523-originals/') and r['path'].endswith('.dat')}
        require(len(changed) == 4, 'Exactly four current changed DAT identities required')
    tables, table_raw, source_files = {}, {}, {}
    source_tables = list(SOURCE_TABLES)
    # Preserve the original declaration and all image members. Runtime excludes
    # these exact source-declared dummy assets without rewriting the inventory.
    if any(row.get('path') == 'content/' + DUMMY_IMAGE_TABLE + '.json' for row in source_index):
        source_tables.append(DUMMY_IMAGE_TABLE)
    for name in source_tables:
        data = (args.tables / (name + '.json')).read_bytes()
        tables[name] = validate_table(name, data, source_index)
        table_raw[name] = data
        source_files[name] = {'path': 'source/' + name + '.json', 'sha256': sha256(data), 'bytes': len(data),
                              'version': 523, 'row_count': len(tables[name])}
    members, container_specs = [], {}
    component_counts = collections.defaultdict(lambda: {'files': 0, 'stored_encrypted_member_bytes': 0,
                                                        'decoded_file_bytes': 0})
    for record in all_members.values():
        name = pathlib.PurePosixPath(record['container']).name
        if name not in container_specs:
            spec = strict_json((decoder_root / 'containers' / (name + '.json')).read_bytes())
            verify_file(pathlib.Path(spec['input_path']), spec['bytes'], spec['sha256'])
            container_specs[name] = spec
        validate_member_record(record, container_specs[name], retained, changed)
        component = component_counts[record['current523_component']]
        component['files'] += 1
        component['stored_encrypted_member_bytes'] += record['encrypted_bytes']
        component['decoded_file_bytes'] += record['plain_bytes']
        if record['current523_component'] == 'retained_historical_card_lineage1216':
            continue
        members.append(record)
    for component, counts in component_counts.items():
        observed = summary['components'][component]
        require(counts == {'files': observed['files'], 'stored_encrypted_member_bytes': observed['stored_member_bytes'],
                           'decoded_file_bytes': observed['plain_file_bytes']}, 'Decoder component totals mismatch')
    member_lookup = unique_members(members)
    assets = compile_assets(tables['AssetView'], tables['AssetType'], member_lookup)
    icons = keyed(tables['Icon'], 'ID', 'Icon')
    consumers = {}
    for table, fields in CONSUMER_FIELDS.items():
        keyed(tables[table], 'ID', table)
        require(all(type(r.get(field)) is int for r in tables[table] for field in fields),
                'Invalid exact consumer icon role: ' + table)
        consumers[table] = [{'id': r['ID'], 'row_index_zero': i,
                             'source_row_canonical_sha256': sha256(json.dumps(r, ensure_ascii=False, sort_keys=True,
                                                                            separators=(',', ':')).encode()),
                             'roles': {f: r[f] for f in fields}}
                            for i, r in enumerate(tables[table])]
    for row in icons.values():
        require(type(row.get('AssetID')) is int, 'Invalid Icon.AssetID')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    stage = pathlib.Path(tempfile.mkdtemp(prefix='source523-image-pack-', dir=args.output.parent))
    try:
        (stage / 'source').mkdir()
        (stage / 'source/index.json').write_bytes(source_raw)
        (stage / 'source/decoder-summary.json').write_bytes(summary_raw)
        (stage / 'source/decoder-catalog.jsonl').write_bytes(catalog_raw)
        if inventory_raw is not None:
            (stage / 'source/inventory-manifest.json').write_bytes(inventory_raw)
        for name, data in table_raw.items():
            (stage / source_files[name]['path']).write_bytes(data)
        packed_members = []
        for record in members:
            original = decoded_root / safe_relative(record['relative_output_path'])
            data = verify_file(original, record['plain_bytes'], record['sha256'])
            verify_image(data, record)
            target = 'originals/' + safe_relative(record['path'])
            (stage / target).parent.mkdir(parents=True, exist_ok=True)
            if args.hardlink_originals:
                os.link(original, stage / target)
            else:
                (stage / target).write_bytes(data)
            packed = {k: v for k, v in record.items() if k != 'relative_output_path'}
            packed['file'] = target
            packed_members.append(packed)
        fixed = [r for r in retained_rows if not r.get('historical_card_pack_lineage')]
        if not client_mode:
            require(summary.get('fixed_retained_noncard_file_denominator') == len(fixed)
                    and summary.get('fixed_retained_noncard_stored_byte_denominator') == sum(r['encrypted_bytes'] for r in fixed),
                    'Fixed retained scope denominator differs from inherited inventory')
        full_current = None
        if summary.get('source_current_catalog_complete') is True:
            checks = summary.get('source_current_catalog_completion_checks', {})
            require(checks and all(value is True for value in checks.values())
                    and summary.get('whole_current_source_member_denominator') == len(catalog),
                    'Full current catalog completion proof is inconsistent')
            full_current = {'files': len(catalog),
                            'stored_encrypted_member_bytes': sum(r['encrypted_bytes'] for r in catalog),
                            'decoded_file_bytes': sum(r['plain_bytes'] for r in catalog),
                            'outer_dat_bytes': sum(r['bytes'] for r in container_specs.values())}
        manifest = {'schema': 1, 'kind': 'source523-exact-original-image-pack', 'source_version': 523,
                    'source_snapshot': 'patch523', 'image_pixels': 'unchanged_original_file_bytes',
                    'source_index': {'path': 'source/index.json', 'sha256': sha256(source_raw), 'bytes': len(source_raw)},
                    'source_tables': source_files,
                    'decoder_summary': {'path': 'source/decoder-summary.json', 'sha256': sha256(summary_raw), 'bytes': len(summary_raw)},
                    'decoder_catalog': {'path': 'source/decoder-catalog.jsonl', 'sha256': sha256(catalog_raw), 'bytes': len(catalog_raw)},
                    'members': packed_members, 'assets': assets, 'consumers': consumers,
                    'icons': [{'id': r['ID'], 'asset_id': r['AssetID'], 'row_index_zero': i}
                              for i, r in enumerate(tables['Icon'])],
                    'metrics': {'validated_catalog_components': dict(component_counts), 'pack_members': len(packed_members),
                                'source_mode': CLIENT_SOURCE_MODE if client_mode else 'earlier_handoff',
                                'fixed_retained_noncard': {'files': len(fixed),
                                    'stored_encrypted_member_bytes': sum(r['encrypted_bytes'] for r in fixed),
                                    'decoded_file_bytes_inherited_metadata': sum(r['plain_bytes'] for r in fixed)},
                                'source_current_catalog_complete': full_current is not None,
                                'whole_current_source_denominator': full_current, 'actual_game_consumption_observed': 0},
                    'qualifications': ['Retained identities are whole-DAT metadata qualified.',
                        'Received verified catalog may be partial; missing members stay unresolved.',
                        'Loading is not evidence of display or gameplay use.',
                        'CSB101 belongs to the existing UI owner; Sound and SP2 actors are excluded.']}
        encoded = json_bytes(manifest)
        (stage / 'manifest.json').write_bytes(encoded)
        stage.rename(args.output)
        print(json.dumps({'ok': True, 'output': str(args.output), 'manifest_sha256': sha256(encoded),
                          'pack_members': len(packed_members), 'metrics': manifest['metrics']}, indent=2))
    except BaseException:
        shutil.rmtree(stage)
        raise


if __name__ == '__main__':
    main()
