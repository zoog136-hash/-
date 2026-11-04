"""Restore verified host14 pixels, optionally adding exact source671 contexts.

No location, count, activation, timing or combat rule is introduced. Incremental
mode verifies and shares immutable host14 files instead of restoring them.
"""
import argparse
import hashlib
import json
import os
import pathlib
import shutil
import zipfile


SOURCE_BYTES = 1339066288
SOURCE_SHA256 = '88b3f4470664571f1f6b2894602fa7a6895cc0443a9ac2f5c914f206ba2b876e'
BASE_MANIFEST_SHA256 = '5eff1f07482988ca7a5606a174ac4fba35785496ba176a9e9b6a0212d58b1a82'
BASE_PROVENANCE = {
    'source_zip_sha256': SOURCE_SHA256,
    'source_snapshot': 'base508',
    'definition_policy': 'patch523, separately validated by runtime; no latest-art equality assertion',
    'selection': 'Exact existing14 host contracts only; no new placement/count/respawn rule.',
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')


def safe_relative(name):
    return (isinstance(name, str) and bool(name)
            and not pathlib.PurePosixPath(name).is_absolute()
            and all(part not in ('', '.', '..') for part in name.split('/'))
            and '\\' not in name and ':' not in name)


def parse_context(value):
    parts = value.split(':')
    if len(parts) != 3 or any(not part or any(c not in '0123456789' for c in part) for part in parts):
        raise argparse.ArgumentTypeError('Expected positive NPC:VIEW:LINK integers')
    result = tuple(map(int, parts))
    if any(part <= 0 for part in result):
        raise argparse.ArgumentTypeError('Expected positive NPC:VIEW:LINK integers')
    return result


def verify_context(record, npc_id, view_id, link_id):
    require(record.get('npc_id') == npc_id, 'Source NPC identity does not match')
    contexts = record.get('source_contexts', [record])
    require(isinstance(contexts, list) and all(isinstance(row, dict) for row in contexts),
            'Invalid source context collection')
    require(any(row.get('spawn_view_id') == view_id and row.get('territory_link_id') == link_id
                for row in contexts), f'Source context is unresolved: {npc_id}:{view_id}:{link_id}')


class SourceArchive:
    def __init__(self, archive):
        self.archive = archive
        self.header = json.loads(archive.read('pack.json'))
        require(self.header.get('schema') == 2 and self.header.get('source_snapshot') == 'base508',
                'Unsupported source installer')
        self.index = {}
        for chunk in self.header['chunks']:
            raw = archive.read(chunk['path'])
            require(len(raw) == chunk['bytes'] and sha(raw) == chunk['sha256'], 'Source inventory SHA differs')
            rows = json.loads(raw)
            require(isinstance(rows, list) and len(rows) == chunk['count'], 'Source inventory count differs')
            for row in rows:
                name = row['path']
                require(safe_relative(name) and name not in self.index, 'Unsafe or duplicate source path')
                require(type(row['bytes']) is int and type(row['offset']) is int
                        and row['bytes'] >= 0 and row['offset'] >= 0
                        and row['offset'] + row['bytes'] <= chunk['payload_bytes'], 'Invalid source file bounds')
                self.index[name] = (chunk, row)
        require(len(self.index) == self.header['files'], 'Source inventory total differs')
        self.cache = {}
        self.read_names = set()
        self.read_chunks = set()

    def read(self, name):
        require(name in self.index, 'Source file is missing: ' + name)
        chunk, row = self.index[name]
        key = chunk['payload']
        if key not in self.cache:
            payload = self.archive.read(key)
            require(len(payload) == chunk['payload_bytes'] and sha(payload) == chunk['payload_sha256'],
                    'Source payload SHA differs')
            self.cache.clear()
            self.cache[key] = payload
            self.read_chunks.add(key)
        body = self.cache[key][row['offset']:row['offset'] + row['bytes']]
        require(len(body) == row['bytes'] and sha(body) == row['sha256'], 'Source file SHA differs: ' + name)
        self.read_names.add(name)
        return body


def manifest_for(full, selected, models, paths, provenance=BASE_PROVENANCE):
    source_files = {name: row for name, row in full['source_files'].items() if row['path'] in paths}
    return {**full, 'records': selected, 'models': models, 'source_files': source_files,
            'counts': {'npc_records': len(selected), 'unique_sprite_models': len(models),
                       'original_sp2_files_used': len(source_files), 'native_geographic_spawns': 0},
            'private_subset_provenance': provenance}


def include_record(full, source, selected, models, paths, model_bytes, record, read_model):
    npc_id = str(record['npc_id'])
    sprite_id = str(record['sprite_id'])
    require(full['records'].get(npc_id) == record, 'Source NPC metadata differs')
    model_spec = full['models'][sprite_id]
    require(model_spec.get('tracks_ref') == record.get('tracks_ref')
            and model_spec.get('tracks_sha256') == record.get('tracks_sha256'), 'Source model references differ')
    selected[npc_id] = record
    models[sprite_id] = model_spec
    name = record['tracks_ref']
    require(safe_relative(name) and name in source.index, 'Source model path is invalid')
    if name not in model_bytes:
        raw = read_model(name)
        require(sha(raw) == record['tracks_sha256'], 'Source model SHA differs: ' + name)
        model_bytes[name] = raw
    model = json.loads(model_bytes[name])
    require(model.get('source_sprite_id') == record['sprite_id'], 'Source model Sprite differs')
    paths.add(name)
    for track in model['tracks'].values():
        for frames in track['directions']:
            for frame in frames:
                for layer in frame['layers']:
                    name = layer['path']
                    require(name in source.index and source.index[name][1]['sha256'] == layer['sha256'],
                            'Source layer SHA differs: ' + name)
                    paths.add(name)


def verify_base(base, full, source, bindings):
    require(base.is_dir() and not base.is_symlink(), 'Base subset must be a real directory')
    manifest_path = base / 'manifest.json'
    require(manifest_path.is_file() and not manifest_path.is_symlink(), 'Base manifest is missing or linked')
    raw_manifest = manifest_path.read_bytes()
    require(sha(raw_manifest) == BASE_MANIFEST_SHA256, 'Base subset manifest SHA differs')
    manifest = json.loads(raw_manifest)
    selected, models, paths, model_bytes = {}, {}, set(), {}
    for binding in bindings:
        record = full['records'][str(binding['npc_id'])]
        verify_context(record, binding['npc_id'], binding['spawn_view_id'], binding['territory_link_id'])
        require(record['sprite_id'] == binding['sprite_id'], 'Existing host Sprite differs')
        require(manifest['records'].get(str(binding['npc_id'])) == record, 'Base NPC metadata differs')
        model_name = record['tracks_ref']
        require(safe_relative(model_name), 'Unsafe base model path')
        model_path = base / model_name
        require(model_path.is_file() and not model_path.is_symlink(), 'Base model is missing or linked')
        include_record(full, source, selected, models, paths, model_bytes, record,
                       lambda name: (base / name).read_bytes())
    canonical = manifest_for(full, selected, models, paths)
    require(encoded(canonical) == raw_manifest, 'Base metadata differs from the original default14 output')
    expected_files = paths | {'manifest.json'}
    actual_files = set()
    for path in base.rglob('*'):
        require(not path.is_symlink(), 'Base subset contains a symbolic link')
        if path.is_file():
            actual_files.add(path.relative_to(base).as_posix())
    require(actual_files == expected_files, 'Base subset file list differs')
    for name in paths:
        row = source.index[name][1]
        path = base / name
        require(path.stat().st_size == row['bytes'] and file_sha(path) == row['sha256'],
                'Base file SHA or size differs: ' + name)
    return selected, models, paths, model_bytes


def restore(source_path, output, base=None, extra_contexts=()):
    repo = pathlib.Path(__file__).resolve().parents[2]
    require(not output.exists() and not output.is_symlink(), 'Preserve existing output')
    require(base is not None or not extra_contexts, '--extra-context requires --base-subset')
    if base is not None:
        require(not output.resolve().is_relative_to(base.resolve()), 'Output must be outside the base subset')
    require(source_path.stat().st_size == SOURCE_BYTES and file_sha(source_path) == SOURCE_SHA256,
            'Pinned source ZIP SHA or size differs')
    bindings = (json.loads((repo / 'data/lineagem_base508/monster_bindings.json').read_text())['bindings']
                + json.loads((repo / 'data/lineagem_base508/monster_batch02/runtime_registry.json').read_text())['port_bindings'])
    extra_contexts = list(dict.fromkeys(extra_contexts))
    with zipfile.ZipFile(source_path) as archive:
        source = SourceArchive(archive)
        full = json.loads(source.read('manifest.json'))
        require(full.get('schema') == 1 and full.get('kind') == 'base508_monster_pack'
                and full.get('source_snapshot') == 'base508', 'Unsupported source manifest')
        base_paths = set()
        if base is not None:
            selected, models, paths, model_bytes = verify_base(base, full, source, bindings)
            base_paths = paths.copy()
        else:
            selected, models, paths, model_bytes = {}, {}, set(), {}
            for binding in bindings:
                record = full['records'][str(binding['npc_id'])]
                verify_context(record, binding['npc_id'], binding['spawn_view_id'], binding['territory_link_id'])
                require(record['sprite_id'] == binding['sprite_id'], 'Existing host Sprite differs')
                include_record(full, source, selected, models, paths, model_bytes, record, source.read)
        for npc_id, view_id, link_id in extra_contexts:
            record = full['records'].get(str(npc_id), {})
            verify_context(record, npc_id, view_id, link_id)
            include_record(full, source, selected, models, paths, model_bytes, record, source.read)
        provenance = BASE_PROVENANCE
        if extra_contexts:
            provenance = {**BASE_PROVENANCE,
                          'selection': 'Existing host14 plus explicitly requested original context inventory; no new placement/count/respawn or activation authority.',
                          'base_manifest_sha256': BASE_MANIFEST_SHA256,
                          'extra_contexts': [{'npc_id': npc, 'spawn_view_id': view, 'territory_link_id': link}
                                             for npc, view, link in extra_contexts]}
        subset = manifest_for(full, selected, models, paths, provenance)
        raw_manifest = encoded(subset)
        if not extra_contexts:
            require(sha(raw_manifest) == BASE_MANIFEST_SHA256, 'Default14 manifest byte regression')
        output.mkdir(mode=0o700)
        linked, copied, extracted = 0, 0, 0
        for name in sorted(paths):
            target = output / name
            target.parent.mkdir(parents=True, exist_ok=True)
            if name in base_paths:
                original = base / name
                try:
                    os.link(original, target)
                    linked += 1
                except OSError:
                    shutil.copyfile(original, target)
                    copied += 1
                row = source.index[name][1]
                require(target.stat().st_size == row['bytes'] and file_sha(target) == row['sha256'],
                        'Reused file changed: ' + name)
            else:
                target.write_bytes(model_bytes[name] if name in model_bytes else source.read(name))
                extracted += 1
        # The expanded manifest always gets a new inode; never overwrite a base hardlink.
        (output / 'manifest.json').write_bytes(raw_manifest)
        require(not base_paths.intersection(source.read_names), 'An existing base asset was read from the ZIP')
        pairs = [{key: binding[key] for key in ['npc_id', 'sprite_id', 'spawn_view_id', 'territory_link_id', 'land_id', 'host_map_id']}
                 for binding in bindings]
        receipt = {
            'source_zip_sha256': SOURCE_SHA256, 'whole_zip_sha256_pinned': True,
            'selected_zip_entries_crc_verified_on_read': True, 'whole_zip_crc_checked_by_tool': False,
            'selected_original_files': len(subset['source_files']), 'output_files': len(paths) + 1,
            'output_bytes': sum(path.stat().st_size for path in output.rglob('*') if path.is_file()),
            'manifest_sha256': sha(raw_manifest), 'contracts': pairs,
            'actual_record_keys': {npc: list(row) for npc, row in selected.items()}, 'used_chunks': True,
            'base_subset': str(base.resolve()) if base is not None else None,
            'base_manifest_sha256': BASE_MANIFEST_SHA256 if base is not None else None,
            'base_files_verified': len(base_paths) + 1 if base is not None else 0,
            'base_manifest_matches_default14_bytes': base is not None,
            'reused_files': linked + copied, 'hardlinked_files': linked, 'copied_files': copied,
            'newly_written_files': extracted + 1, 'new_source_asset_files': extracted,
            'extra_contexts': provenance.get('extra_contexts', []),
            'zip_logical_files_read': len(source.read_names), 'zip_payload_chunks_read': len(source.read_chunks),
            'base_assets_read_from_zip': len(base_paths.intersection(source.read_names)),
        }
        receipt_path = output.with_name(output.name + '.receipt.json')
        receipt_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({key: value for key, value in receipt.items()
                          if key not in ['contracts', 'actual_record_keys']}, ensure_ascii=False))
        return receipt


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-zip', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--base-subset', type=pathlib.Path, help='Verified, unchanged host14 subset to reuse')
    parser.add_argument('--extra-context', type=parse_context, action='append', default=[], metavar='NPC:VIEW:LINK')
    args = parser.parse_args()
    restore(args.source_zip, args.output, args.base_subset, args.extra_context)
