#!/usr/bin/env python3
"""Verify the existing private523 Content archive in place; never extract originals."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
import zlib

ARCHIVE_SHA256 = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'


def strict_pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError('Duplicate JSON key: ' + key)
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError('Nonstandard JSON constant: ' + value)


def decode(raw):
    return json.loads(raw.decode('utf-8-sig'), object_pairs_hook=strict_pairs,
                      parse_constant=reject_constant)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(archive, conditions=None):
    with archive.open('rb') as stream:
        require(hashlib.file_digest(stream, 'sha256').hexdigest() == ARCHIVE_SHA256,
                'Archive SHA differs from the pinned original')
    compiled = decode(conditions.read_bytes())['tables'] if conditions else {}
    result = {'archive_bytes': archive.stat().st_size, 'archive_sha256': ARCHIVE_SHA256,
              'tables': 0, 'rows': 0, 'original_json_bytes': 0,
              'typed_exact_production_context_tables': [], 'schema': []}
    with zipfile.ZipFile(archive) as package:
        names = package.namelist()
        require(len(names) == len(set(names)), 'Duplicate ZIP member')
        require(package.testzip() is None, 'ZIP CRC failure')
        index = decode(package.read('index.json'))
        manifest = decode(package.read('package_manifest.json'))
        specs = {row['path']: row for row in manifest['files']}
        require(len(index) == len({row['path'] for row in index}), 'Duplicate index path')
        actual = {name for name in names if name.startswith('content/') and name.endswith('.json')}
        require(actual == {row['path'] for row in index}, 'Actual/index table set differs')
        for spec in index:
            name = spec['path']
            raw = package.read(name)
            sha = hashlib.sha256(raw).hexdigest()
            require(len(raw) == spec['bytes'] == specs[name]['bytes'] and
                    sha == spec['sha256'] == specs[name]['sha256'], 'SHA/size differs: ' + name)
            require(f'{zlib.crc32(raw) & 0xffffffff:08x}' == spec['crc32'], 'Index CRC differs: ' + name)
            obj = decode(raw)
            require(isinstance(obj, dict) and set(obj) == {'rows'} and isinstance(obj['rows'], list),
                    'Unexpected table root: ' + name)
            rows = obj['rows']
            require(all(isinstance(row, dict) for row in rows), 'Unexpected row type: ' + name)
            fields = sorted({key for row in rows for key in row})
            require(len(rows) == spec['row_count'] and fields == spec['fields'],
                    'Actual row count/schema differs: ' + name)
            table = Path(name).stem
            if table in compiled:
                previous = compiled[table]
                previous = previous if isinstance(previous, list) else previous['rows']
                # Preserve bool-vs-number and numeric types; Python equality alone does not.
                canonical = lambda value: json.dumps(value, sort_keys=True, separators=(',', ':'))
                require(canonical(previous) == canonical(rows), 'Production context differs: ' + table)
                result['typed_exact_production_context_tables'].append(table)
            result['tables'] += 1
            result['rows'] += len(rows)
            result['original_json_bytes'] += len(raw)
            result['schema'].append({'table': table, 'rows': len(rows), 'fields': fields, 'sha256': sha})
        require(set(result['typed_exact_production_context_tables']) == set(compiled),
                'Production context table absent from original index')
    result['all_SHA_size_CRC_schema_checks_passed'] = True
    result['native_collision_or_portal_activation_verified'] = False
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--production-conditions', type=Path)
    parser.add_argument('--output', type=Path, required=True, help='New local receipt; refuses overwrite')
    args = parser.parse_args()
    # Fail before reading457MB of original JSON if the destination already exists.
    require(not args.output.exists(), 'Preserve previous receipt; select a new output')
    receipt = verify(args.archive, args.production_conditions)
    with args.output.open('x') as stream:
        json.dump(receipt, stream, ensure_ascii=False, indent=2)
        stream.write('\n')
    print(json.dumps({key: value for key, value in receipt.items() if key != 'schema'}))
