"""Fail on missing, altered, untracked or incomplete original-map delivery.

Writing the manifest is explicit. CI only verifies the committed manifest.
This checks actual map data bytes, never claims original artwork is present.
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path('data/original_maps/DELIVERY_MANIFEST.json')
FOLDERS = ('data/original_maps', 'data/l1j/recovered_maps')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def verify_payload_ranges(root):
    """Reject truncated shards even when a new manifest hashes their bytes."""
    base = root / 'data/original_maps'
    catalog = json.loads((base / 'catalog.json').read_text())
    checked = set()
    for row in catalog['maps']:
        definition = json.loads((root / row['source_definition'].removeprefix('res://')).read_text())
        refs = [('navigation', r[4], r[5], r[6]) for r in definition['navigation']['chunks']]
        refs += [('terrain', *r['pack'][:3]) for r in definition['terrain_variants']]
        for prefix, shard, offset, size in refs:
            key = (prefix, shard, offset, size)
            if key in checked:
                continue
            path = base / f'{prefix}-{shard:02}.bin'
            if not path.is_file() or offset < 0 or size <= 0 or offset + size > path.stat().st_size:
                raise ValueError(f'Truncated/missing source payload: {row["id"]} {path.name} offset={offset} bytes={size}')
            checked.add(key)
    return len(checked)

def inspect(root):
    result = []
    for folder in FOLDERS:
        for path in sorted((root / folder).rglob('*')):
            relative = path.relative_to(root)
            if path.is_file() and relative != MANIFEST:
                result.append({'path': relative.as_posix(), 'bytes': path.stat().st_size,
                               'sha256': digest(path)})
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--write', action='store_true', help='explicitly update reviewed byte manifest')
    parser.add_argument('--require-tracked', action='store_true')
    args = parser.parse_args()
    root = args.root.resolve()
    verify_payload_ranges(root)
    actual = inspect(root)
    if args.write:
        payload = {'schema': 1, 'original_terrain_art': 'MISSING', 'files': actual,
                   'file_count': len(actual), 'total_bytes': sum(r['bytes'] for r in actual)}
        (root / MANIFEST).write_text(json.dumps(payload, indent=2) + '\n')
    manifest = json.loads((root / MANIFEST).read_text())
    expected = {r['path']: r for r in manifest['files']}
    observed = {r['path']: r for r in actual}
    assert observed == expected, ('Missing, altered or unexpected map data: ' +
        str(sorted(p for p in set(expected) | set(observed) if expected.get(p) != observed.get(p))[:20]))
    assert manifest['file_count'] == len(actual)
    assert manifest['total_bytes'] == sum(r['bytes'] for r in actual)
    catalog = json.loads((root / 'data/original_maps/catalog.json').read_text())
    records = catalog['maps']
    recovered = json.loads((root / 'data/l1j/recovered_maps/source_maps.json').read_text())['maps']
    assert len(records) == len(recovered), 'Selected source grids must not silently disappear'
    assert len({row['id'] for row in records}) == len(records)
    for row in records:
        path = row['source_definition'].removeprefix('res://')
        assert path in expected, 'Definition not delivered: ' + path
        definition = json.loads((root / path).read_text())
        assert definition['map_id'] == row['id']
        for ref in definition['navigation']['chunks']:
            assert f'data/original_maps/navigation-{ref[4]:02}.bin' in expected
        for ref in definition['terrain_variants']:
            assert f"data/original_maps/terrain-{ref['pack'][0]:02}.bin" in expected
    if args.require_tracked:
        tracked = set(subprocess.check_output(['git', 'ls-files', '-z'], cwd=root).decode().split('\0'))
        missing = (set(expected) | {MANIFEST.as_posix()}) - tracked
        assert not missing, 'Map assets are not tracked by Git: ' + str(sorted(missing)[:20])
    print(json.dumps({'result': 'LOCAL_MAP_PACK_VERIFIED', 'files': len(actual),
                      'bytes': manifest['total_bytes'], 'maps': len(records),
                      'original_terrain_art': 'MISSING'}))

if __name__ == '__main__':
    main()
