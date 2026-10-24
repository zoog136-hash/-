"""Read-only comparison of the pinned Aden original and its runtime chunks.

First restore existing repository source parts with verify_map_source_pngs.py.
This proves source fidelity, not complete terrain/navigation reconstruction.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image


def audit(source: Path, pack: Path) -> dict:
    manifest = json.loads((pack / 'manifest.json').read_text())
    with source.open('rb') as stream:
        source_hash = hashlib.file_digest(stream, 'sha256').hexdigest()
    if source_hash != manifest['source_sha256']:
        raise ValueError('Wrong original: SHA differs from the active runtime pack')
    Image.MAX_IMAGE_PIXELS = 180_000_000
    with Image.open(source) as original:
        original = original.convert('RGBA')
        for row in manifest['chunks']:
            name = row['file']
            if Path(name).name != name:
                raise ValueError('Unexpected chunk path')
            path = pack / name
            if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
                raise ValueError(f'Chunk SHA mismatch: {name}')
            x, y = row['position']
            width, height = row['size']
            with Image.open(path) as chunk:
                if chunk.size != (width, height) or chunk.convert('RGBA').tobytes() != original.crop((x, y, x + width, y + height)).tobytes():
                    raise ValueError(f'Original RGBA mismatch: {name}')
        return {'source_sha256': source_hash, 'source_size': list(original.size),
                'identical_source_crops': len(manifest['chunks']),
                'navigation_reconstruction_verified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--pack', type=Path, default=Path(__file__).resolve().parents[2] / 'external_map_packs/aden_faith_png_v1/aden_world')
    args = parser.parse_args()
    print(json.dumps(audit(args.source, args.pack), indent=2))
