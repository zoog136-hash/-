"""Package verified monster pixels and523 definitions for explicit game loading.

Only the resource closure, its inventory and launch instructions are included.
This is an extracted-directory bundle, not a ZIP-picker monster installer.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(body):
    return hashlib.sha256(body).hexdigest()


def relative(name):
    require(isinstance(name, str) and name and not PurePosixPath(name).is_absolute()
            and all(p not in ('', '.', '..') for p in name.split('/'))
            and ':' not in name and '\\' not in name, 'Unsafe resource path')
    return name


def encode(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def build(monsters, definitions, monster_sha, definition_sha, commit, output):
    require(not output.exists(), 'Preserve existing output')
    require(re.fullmatch(r'[0-9a-f]{40}', commit), 'Exact code commit required')
    require(not output.resolve().is_relative_to(monsters.resolve())
            and not output.resolve().is_relative_to(definitions.resolve()), 'Keep output outside resource inputs')
    files = {}

    def add(root, prefix, name, digest, size=None):
        path = root / relative(name)
        key = prefix + '/' + name
        if key in files:
            require(files[key]['sha256'] == digest and (size is None or files[key]['bytes'] == size), 'Conflicting resource')
            return path.read_bytes() if name.endswith('.json') else b''
        require(path.is_file() and not path.is_symlink()
                and path.resolve().is_relative_to(root.resolve()), 'Missing or linked resource')
        body = path.read_bytes()
        require(sha(body) == digest and (size is None or len(body) == size), 'Resource hash/size differs: ' + name)
        files[key] = {'path': path, 'sha256': digest, 'bytes': len(body)}
        return body

    m = json.loads(add(monsters, 'monsters', 'manifest.json', monster_sha))
    require(m.get('kind') == 'base508_monster_pack' and m.get('source_snapshot') == 'base508', 'Wrong pixel snapshot')
    for record in m['records'].values():
        model = json.loads(add(monsters, 'monsters', record['tracks_ref'], record['tracks_sha256']))
        require(model['source_sprite_id'] == record['sprite_id'], 'Sprite mismatch')
        for track in model['tracks'].values():
            for frames in track['directions']:
                for frame in frames:
                    for layer in frame['layers']:
                        add(monsters, 'monsters', layer['path'], layer['sha256'])
    d = json.loads(add(definitions, 'world-links', 'manifest.json', definition_sha))
    require(d.get('source_snapshot') == 'patch523', 'Wrong definition snapshot')
    for row in [d['conditions'], *d['lands'].values()]:
        add(definitions, 'world-links', row['file'], row['sha256'], row['bytes'])
    inventory = {name: {k: row[k] for k in ('bytes', 'sha256')} for name, row in sorted(files.items())}
    header = {'schema': 1, 'kind': 'twilight-pr230-resource-bundle', 'version': 1,
              'code_commit': commit, 'art_snapshot': 'base508', 'definition_snapshot': 'patch523',
              'monster_manifest_sha256': monster_sha, 'world_links_manifest_sha256': definition_sha,
              'npc_ids': sorted(map(int, m['records'])), 'new_production_spawns': 0,
              'requires_existing_twilight_code_and_map_pack': True,
              'activation': 'Extract to a separate folder and provide both launch arguments; Drive storage is not installation.',
              'files': inventory}
    readme = f'''PR230 resource bundle v1
Code commit: {commit}
Art: original508 source pixels. Definitions:523. Latest523 art-byte equivalence is not established.
Scope: existing14 host contracts plus the93102 model/API contract; no new production encounter.
Keep existing saves, map packs and larger monster installations.
Extract to a separate folder. This ZIP is not accepted by the monster ZIP picker.
Start the matching TWILIGHT code with its existing map pack and append after --:
--lineagem-monster-pack=/ABSOLUTE/EXTRACTED/monsters/manifest.json
--patch523-world-links=/ABSOLUTE/EXTRACTED/world-links
--patch523-world-links-sha256={definition_sha}
Drive storage does not automatically install or enable this bundle.
Original671 source installer and original523 Content backup remain separate inputs.
'''
    with zipfile.ZipFile(output, 'x', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        def write(name, body):
            entry = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, body)
        for name, row in sorted(files.items()):
            body = row['path'].read_bytes()
            require(sha(body) == row['sha256'], 'Resource changed during packaging')
            write(name, body)
        write('bundle.json', encode(header))
        write('README.txt', readme.encode())
    with zipfile.ZipFile(output) as archive:
        require(archive.testzip() is None, 'Bundle ZIP CRC failed')
    return {'path': str(output), 'bytes': output.stat().st_size,
            'sha256': sha(output.read_bytes()), 'resource_files': len(files),
            'resource_bytes': sum(r['bytes'] for r in files.values()), 'code_commit': commit}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('monsters', 'definitions', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    for name in ('monster-sha256', 'definition-sha256', 'code-commit'):
        parser.add_argument('--' + name, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.monsters, args.definitions, args.monster_sha256,
                           args.definition_sha256, args.code_commit, args.output)))
