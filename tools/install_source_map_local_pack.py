#!/usr/bin/env python3
"""Verify and install the tracked correction layer into an existing source84 pack.

Usage: python3 tools/install_source_map_local_pack.py --pack-root /path/to/source84
The original artwork and collision packs must already be installed there.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def install(source, root):
    manifest_path = source / 'file_manifest.json'
    if not manifest_path.is_file():
        manifest_path = Path(__file__).resolve().parents[1] / 'data/maps/source84_local_files.json'
    manifest = json.loads(manifest_path.read_text())
    receipt = json.loads((Path(__file__).resolve().parents[1] /
                          'data/maps/source_map_local_pack.json').read_text())
    if sha(root / 'index.json') != manifest['base_index_sha256']:
        raise ValueError('Original artwork index does not match; nothing installed')
    expected = {}
    for row in manifest['files']:
        relative = Path(row['path'])
        if relative.is_absolute() or '..' in relative.parts or relative.parts[0] != 'local-interpretation-v1':
            raise ValueError('Unsafe manifest path')
        if str(relative) in expected:
            raise ValueError('Duplicate manifest path')
        expected[str(relative)] = row
    actual = {str(p.relative_to(source)) for p in (source / 'local-interpretation-v1').rglob('*') if p.is_file()}
    if actual != set(expected):
        raise ValueError('Tracked correction file inventory differs')
    for relative, row in expected.items():
        path = source / relative
        if path.is_symlink() or path.stat().st_size != row['bytes'] or sha(path) != row['sha256']:
            raise ValueError('Correction file changed: ' + relative)
    if sha(source / 'local-interpretation-v1/index.json') != receipt['index_sha256']:
        raise ValueError('Runtime index differs from pinned game receipt')
    target = root / 'local-interpretation-v1'
    if target.exists():
        existing = {str(p.relative_to(root)) for p in target.rglob('*') if p.is_file()}
        if existing != set(expected) or any((root / p).is_symlink() or sha(root / p) != row['sha256'] for p, row in expected.items()):
            raise ValueError('Existing correction layer differs; preserve it and choose another root')
        return 'verified existing'
    with tempfile.TemporaryDirectory(prefix='.source84-install-', dir=root) as staging:
        staged = Path(staging) / target.name
        shutil.copytree(source / target.name, staged)
        for relative, row in expected.items():
            if sha(Path(staging) / relative) != row['sha256']:
                raise ValueError('Staged copy verification failed')
        staged.rename(target)
    return 'installed'


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pack-root', type=Path, required=True)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1] / 'external_map_packs/source84_v3')
    args = parser.parse_args()
    print(install(args.source.resolve(), args.pack_root.resolve()))
