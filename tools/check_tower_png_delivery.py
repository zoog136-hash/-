#!/usr/bin/env python3
"""Verify the authorized, Git-tracked ordinary Oman/111 runtime PNG delivery."""
import argparse
import json
import subprocess
import sys
from pathlib import Path, PurePosixPath

sys.path.insert(0, str(Path(__file__).resolve().parent / 'map_restore'))
from install_tower_png_pack import PACKS, read, sha, verify


def check(root):
    authorization = read(root / 'data/maps/tower_png_authorization.json')
    if (authorization['statement'] != '재배포 권한 확보 — 공개 추가 허용'
            or authorization['scope'] != 'PUBLIC_GITHUB_RUNTIME_PNG_CHUNKS_AND_THEIR_MINIMAPS_FROM_101_TO_111_ONLY'
            or authorization['raw_source_files_added_to_git'] is not False):
        raise ValueError('Missing scoped redistribution authorization')
    manifest = read(root / 'data/maps/tower_png_delivery_manifest.json')
    tracked = set(subprocess.check_output(
        ['git', '-C', str(root), 'ls-files', '-z']).decode().split('\0'))
    expected = set()
    total_bytes = 0
    for row in manifest['files']:
        name = row['path']
        parts = PurePosixPath(name).parts
        if (len(parts) < 3 or parts[0] != 'external_map_packs'
                or parts[1] not in PACKS or '..' in parts or name in expected):
            raise ValueError('Invalid delivery path: ' + name)
        expected.add(name)
        path = root / name
        if name not in tracked or path.is_symlink() or not path.is_file():
            raise ValueError('Runtime asset absent from Git or disk: ' + name)
        if path.stat().st_size != row['bytes'] or sha(path) != row['sha256']:
            raise ValueError('Runtime asset bytes/SHA mismatch: ' + name)
        total_bytes += row['bytes']
    actual = {p.relative_to(root).as_posix()
              for name in PACKS
              for p in (root / 'external_map_packs' / name).rglob('*')
              if p.is_file()}
    if actual != expected or len(expected) != 428:
        raise ValueError('Runtime inventory incomplete or contains unrecorded files')
    counts = {}
    for name, receipt_name in PACKS.items():
        receipt = read(root / 'data/maps' / receipt_name)
        if receipt.get('bundled_required') is not True:
            raise ValueError('Ordinary GitHub launch must require the runtime bundle')
        counts[name] = verify(root / 'external_map_packs' / name, receipt)
    if sum(counts.values()) != 414:
        raise ValueError('Expected 414 actual runtime textures')
    result = {'status': 'PASS', 'tracked_files': len(expected),
              'bytes': total_bytes, 'textures': counts,
              'authorization': manifest['authorization'],
              'all_original_art_integrated': False}
    print(json.dumps(result, ensure_ascii=False))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    check(args.root.resolve())
