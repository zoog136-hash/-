#!/usr/bin/env python3
"""Read-only intake check. Matching names never certify current523 pixels.

The base508 audit records are evidence, not deliverable images. Optional roots
must contain the original decoded tree and actual current523 container bytes.
This produces a review queue, never installs a pack or approves a CSB player.
"""
import argparse
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path, PurePosixPath
import zlib

try:
    from .patch523_item_icons import compile_icon_links
except ImportError:
    from patch523_item_icons import compile_icon_links


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def local_file(root, relative):
    path = PurePosixPath(relative)
    if not relative or path.is_absolute() or '\\' in relative or ':' in relative or any(
            part in ('', '.', '..') for part in relative.split('/')):
        raise ValueError('unsafe source path: ' + relative)
    if root is None:
        return None
    candidate = root.joinpath(*path.parts)
    if not candidate.resolve().is_relative_to(root.resolve()):
        raise ValueError('source path escapes input root: ' + relative)
    return candidate if candidate.is_file() else None


def audit(source, base_audit, pixels=None, current=None):
    index = {r['path']: r for r in json.loads((source/'index.json').read_text('utf-8-sig'))}
    tables = {}
    for name in ('ItemClass', 'Icon', 'AssetView'):
        relative = 'content/' + name + '.json'
        raw = (source/relative).read_bytes()
        spec = index[relative]
        rows = json.loads(raw.decode('utf-8-sig'))['rows']
        if (spec['version'] != 523 or len(raw) != spec['bytes'] or
                hashlib.sha256(raw).hexdigest() != spec['sha256'] or
                f'{zlib.crc32(raw):08x}' != spec['crc32'] or len(rows) != spec['row_count']):
            raise ValueError('source table mismatch: ' + name)
        tables[name] = rows
    links = compile_icon_links(tables)
    containers = {r['container']: r for r in json.loads((base_audit/'containers_verified.json').read_text())}
    images = {}
    with gzip.open(base_audit/'asset_manifest.jsonl.gz', 'rt') as stream:
        for line in stream:
            row = json.loads(line)
            if row['path'] in images:
                raise ValueError('ambiguous audit path: ' + row['path'])
            images[row['path']] = row
    grouped = {}
    for identity in links.values():
        key = str(identity['icon_id'])
        if key not in grouped:
            grouped[key] = dict(identity, item_class_ids=[])
            grouped[key].pop('item_class_id')
        grouped[key]['item_class_ids'].append(identity['item_class_id'])
    container_checks = {}
    for entry in grouped.values():
        entry['pixel_status'] = 'not_supplied'
        entry['version_status'] = 'not_verified'
        if not entry['file_path']:
            entry['pixel_status'] = 'source_empty_path'
            continue
        if entry['asset_type_id'] != 1:
            entry['pixel_status'] = 'source_scene_requires_player' if entry['asset_type_id'] == 101 else 'unsupported_asset_type'
            continue
        path = entry['file_path']
        original = images.get(path if path.startswith('icon/') else 'icon/' + path)
        if original is None:
            entry['pixel_status'] = 'no_base508_path_candidate'
            continue
        entry['base508_candidate'] = {k: original[k] for k in (
            'path', 'container', 'relative_output_path', 'sha256', 'plain_bytes', 'width', 'height', 'mode')}
        container = original['container']
        if container not in container_checks:
            spec = containers[container]
            file = local_file(current, container)
            actual = digest(file) if file else None
            container_checks[container] = {
                'base508_sha256': spec['sha256'], 'current523_sha256': actual,
                'status': 'not_supplied' if actual is None else
                          'identical_bytes' if actual == spec['sha256'] else 'different_bytes'}
        entry['version_status'] = container_checks[container]['status']
        file = local_file(pixels, original['relative_output_path'])
        if file:
            entry['pixel_status'] = ('base508_bytes_match' if
                file.stat().st_size == original['plain_bytes'] and digest(file) == original['sha256']
                else 'base508_bytes_mismatch')
        # Even matching inputs still need consumer-local pixel inspection and
        # Godot rendering. This audit alone never changes installation status.
    return {'schema': 'patch523-item-icon-intake-v1', 'normal_items': len(links),
            'unique_icons': len(grouped), 'installed_pixels': 0,
            'pixel_status_counts': dict(Counter(x['pixel_status'] for x in grouped.values())),
            'container_checks': container_checks, 'icons': grouped}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--base-audit', type=Path, required=True)
    parser.add_argument('--pixels', type=Path)
    parser.add_argument('--current-containers', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = audit(args.source, args.base_audit, args.pixels, args.current_containers)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ('icons', 'container_checks')}))


if __name__ == '__main__':
    main()
