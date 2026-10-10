"""Restore the reviewed visual bindings with source-byte hashes, never numeric-ID guessing."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import zipfile
from PIL import Image


def restore(bindings: Path, a2: Path, ground_pack: Path, output: Path):
    manifest = json.loads(bindings.read_text(encoding='utf-8'))
    files = {}
    with zipfile.ZipFile(a2) as original, zipfile.ZipFile(ground_pack) as previous:
        for section in ('items', 'monsters'):
            for record in manifest[section]:
                specs = [('inventory_texture', 'inventory_sha256', 'inventory_source_member', original),
                         ('ground_texture', 'ground_sha256', 'ground_source_member', previous)] if section == 'items' else [
                         ('texture', 'sha256', 'source_member', original)]
                for texture_key, sha_key, source_key, archive in specs:
                    member = record[source_key]
                    data = archive.read(member)
                    sha = hashlib.sha256(data).hexdigest()
                    if sha != record[sha_key]:
                        raise ValueError(f'Reviewed bytes differ: {member}')
                    with Image.open(io.BytesIO(data)) as pixels:
                        pixels.load()
                    name = record[texture_key].removeprefix('res://')
                    if not name.startswith('assets/l1j/verified/') or '..' in Path(name).parts:
                        raise ValueError('Unsafe binding path')
                    files[name] = data
                    files[f'data/l1j/verified_bytes/{sha}.l1jpng'] = data
    # Preflight all existing paths before publishing the representative set.
    for name, data in files.items():
        target = output / name
        if target.exists() and target.read_bytes() != data:
            raise ValueError(f'Existing art differs; use a clean staging directory: {name}')
    for name, data in files.items():
        target = output / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    print(json.dumps({'reviewed_images': len(files) // 2, 'source_byte_records': len(files) // 2,
                      'game_database_writes': 0}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bindings', type=Path, required=True)
    parser.add_argument('--a2', type=Path, required=True)
    parser.add_argument('--ground-pack', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    restore(args.bindings, args.a2, args.ground_pack, args.output)
