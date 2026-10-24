#!/usr/bin/env python3
"""Install authorized private Oman/111 art into an ordinary Godot project.

The project pins the index, which pins manifests, which pin every texture.
This installer accepts only these two data directories, never executable code.
"""
import argparse
import hashlib
import json
import shutil
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]
PACKS = {'oman_png_v1': 'oman_png_pack.json',
         'domination_png_v1': 'domination_png_pack.json'}


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read(path):
    return json.loads(path.read_text())


def texture(folder, row):
    name = row['file']
    if not isinstance(name, str) or PurePosixPath(name).name != name or '\\' in name:
        raise ValueError('Unsafe texture path')
    if not name.endswith('.png') or sha(folder/name) != row['sha256']:
        raise ValueError('Texture SHA mismatch: '+name)


def verify(folder, receipt):
    if sha(folder/'index.json') != receipt['index_sha256']:
        raise ValueError('Index SHA mismatch: '+folder.name)
    index = read(folder/'index.json')
    count = 0
    for mid, entry in index['maps'].items():
        if mid not in receipt['maps'] or entry['manifest'] != mid+'/manifest.json':
            raise ValueError('Unexpected map')
        manifest = folder/entry['manifest']
        if sha(manifest) != entry['sha256']:
            raise ValueError('Manifest SHA mismatch: '+mid)
        value = read(manifest)
        for row in value.get('chunks', [])+value.get('foreground', []):
            texture(folder/mid, row); count += 1
        for row in value.get('regions', []):
            texture(folder/mid, row); count += 1
            for cut in row.get('cuts', []):
                texture(folder/mid, cut); count += 1
    if set(index['maps']) != set(receipt['maps']):
        raise ValueError('Incomplete map set')
    return count


def install(archive, project):
    receipts = {name: read(project/'data/maps'/file) for name, file in PACKS.items()}
    destination = project/'external_map_packs'
    if destination.is_symlink():
        raise ValueError('Refusing symbolic-link pack parent')
    destination.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.tower-png-', dir=destination) as temporary:
        stage = Path(temporary)
        with zipfile.ZipFile(archive) as bundle:
            entries = bundle.infolist()
            if len(entries) > 2048 or sum(info.file_size for info in entries) > 2*1024**3:
                raise ValueError('Archive exceeds the bounded tower pack size')
            names = set()
            for info in entries:
                p = PurePosixPath(info.filename)
                if (p.is_absolute() or '..' in p.parts or '\\' in info.filename
                        or not p.parts or p.parts[0] not in PACKS
                        or info.filename in names or (info.external_attr >> 16) & 0o170000 == 0o120000):
                    raise ValueError('Unsafe archive entry: '+info.filename)
                names.add(info.filename)
                if info.is_dir():
                    continue
                if p.suffix not in {'.png', '.json'} or info.file_size > 64*1024*1024:
                    raise ValueError('Only bounded PNG/JSON data allowed')
                output = stage.joinpath(*p.parts)
                output.parent.mkdir(parents=True, exist_ok=True)
                with bundle.open(info) as source, output.open('wb') as target:
                    shutil.copyfileobj(source, target)
        # Validate both before changing either installed pack.
        counts = {name: verify(stage/name, receipts[name]) for name in PACKS}
        changed = []
        try:
            for name in PACKS:
                existing = destination/name
                backup = stage/(name+'.previous')
                if existing.is_symlink():
                    raise ValueError('Refusing symbolic-link destination')
                if existing.exists(): existing.rename(backup)
                changed.append(name)
                (stage/name).rename(existing)
        except Exception:
            for name in reversed(changed):
                existing = destination/name
                if existing.exists(): shutil.rmtree(existing)
                backup = stage/(name+'.previous')
                if backup.exists(): backup.rename(existing)
            raise
    print(json.dumps({'status': 'PASS', 'textures': counts,
                      'ordinary_launch': True, 'project': str(project)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    parser.add_argument('--project', type=Path, default=ROOT)
    args = parser.parse_args()
    install(args.archive, args.project.resolve())
