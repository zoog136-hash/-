"""Verify tracked original bytes; optionally restore the byte-split Aden PNG.

This audits source delivery, not terrain collision or Android performance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path('external_map_packs/source_pngs')
PLANS = ('data/maps/native_png_plan.json', 'data/maps/aden_faith_png_plan.json')


def flat_name(value):
    if not isinstance(value, str) or value in ('', '.', '..') or '/' in value or '\\' in value:
        raise ValueError('Unsafe source filename')
    return value


def verify(root, restore_to=None, decode=False, require_tracked=False):
    root = Path(root).resolve()
    source = root / SOURCE
    manifest = json.loads((source / 'manifest.json').read_text())
    if manifest.get('schema') != 1:
        raise ValueError('Unsupported source manifest')
    expected = {}
    for plan in PLANS:
        expected.update(json.loads((root / plan).read_text())['sources'])
    rows = manifest['sources']
    if {r['file'] for r in rows} != set(expected) or len(rows) != len(expected):
        raise ValueError('Missing or duplicate original source')
    tracked = set()
    if require_tracked:
        tracked = set(subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z', '--', str(SOURCE)]).decode().split('\0'))
        if str(SOURCE / 'manifest.json') not in tracked:
            raise ValueError('Source manifest is not tracked by Git')
    if restore_to is not None:
        restore_to = Path(restore_to).resolve()
        if restore_to.exists() or restore_to.is_relative_to(root):
            raise ValueError('Choose a NEW restoration directory outside the checkout')
    if decode:
        from PIL import Image
        Image.MAX_IMAGE_PIXELS = None  # The trusted plans pin large original canvases.
    seen = set()
    total = 0
    with tempfile.TemporaryDirectory(prefix='twilight-original-png-') as temporary:
        stage = Path(temporary) / 'restored'
        stage.mkdir()
        for row in rows:
            name = flat_name(row['file'])
            spec = expected[name]
            for key in ('bytes', 'sha256', 'size', 'mode', 'alpha'):
                if row.get(key) != spec[key]:
                    raise ValueError(f'{name}: source differs from the authenticated map plan')
            parts = row['parts']
            if not parts:
                raise ValueError(f'{name}: no source bytes')
            digest = hashlib.sha256()
            count = 0
            target = stage / name
            with target.open('wb') as output:
                for part in parts:
                    filename = flat_name(part['file'])
                    relative = str(SOURCE / filename)
                    if filename in seen or (require_tracked and relative not in tracked):
                        raise ValueError(f'{filename}: duplicate or untracked source bytes')
                    seen.add(filename)
                    path = source / filename
                    if path.is_symlink() or not 0 < path.stat().st_size <= 100 * 1024 * 1024:
                        raise ValueError(f'{filename}: invalid Git binary')
                    piece_hash = hashlib.sha256()
                    piece_bytes = 0
                    with path.open('rb') as handle:
                        for block in iter(lambda: handle.read(1024 * 1024), b''):
                            output.write(block)
                            digest.update(block)
                            piece_hash.update(block)
                            count += len(block)
                            piece_bytes += len(block)
                    if piece_bytes != part['bytes'] or piece_hash.hexdigest() != part['sha256']:
                        raise ValueError(f'{filename}: byte count or SHA-256 mismatch')
            if count != spec['bytes'] or digest.hexdigest() != spec['sha256']:
                raise ValueError(f'{name}: reconstructed original SHA-256 mismatch')
            if decode:
                with Image.open(target) as picture:
                    picture.load()
                    if picture.format != 'PNG' or list(picture.size) != spec['size'] or picture.mode != spec['mode'] or ('A' in picture.getbands()) != spec['alpha']:
                        raise ValueError(f'{name}: original PNG decode properties differ')
            total += count
        if manifest['original_files'] != len(rows) or manifest['original_bytes'] != total:
            raise ValueError('Incorrect source inventory totals')
        if restore_to is not None:
            restore_to.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(stage, restore_to)
    return {'original_pngs': len(rows), 'git_binary_files': len(seen), 'original_bytes': total,
            'all_sha256_verified': True, 'all_pngs_fully_decoded': decode,
            'git_tracking_verified': require_tracked,
            'restored_to': str(restore_to) if restore_to else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--restore-to', type=Path)
    parser.add_argument('--decode', action='store_true')
    parser.add_argument('--require-tracked', action='store_true')
    args = parser.parse_args()
    try:
        result = verify(args.root, args.restore_to, args.decode, args.require_tracked)
    except (ValueError, OSError, KeyError, TypeError) as exc:
        parser.exit(1, f'MAP_SOURCE_VERIFY_FAILED: {exc}\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
