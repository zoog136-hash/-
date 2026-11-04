"""Restore exact existing host14 pixels from the pinned private source671 installer.

No new source identity, location, count, timing or combat rule is introduced.
"""
import argparse, hashlib, json, pathlib, zipfile
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-zip', type=pathlib.Path, required=True)
parser.add_argument('--output', type=pathlib.Path, required=True)
args = parser.parse_args()
repo = pathlib.Path(__file__).resolve().parents[2]
source = args.source_zip
out = args.output
root = out.parent
expected = '88b3f4470664571f1f6b2894602fa7a6895cc0443a9ac2f5c914f206ba2b876e'

def sha(b):
    return hashlib.sha256(b).hexdigest()
digest = hashlib.sha256()
with source.open('rb') as stream:
    for block in iter(lambda: stream.read(1024 * 1024), b''):
        digest.update(block)
if not (source.stat().st_size == 1339066288 and digest.hexdigest() == expected):
    raise ValueError('Source contract check failed: source.stat().st_size==1339066288 and digest.hexdigest()==expected')
bindings = json.loads((repo / 'data/lineagem_base508/monster_bindings.json').read_text())['bindings'] + json.loads((repo / 'data/lineagem_base508/monster_batch02/runtime_registry.json').read_text())['port_bindings']
if out.exists():
    raise ValueError('Preserve existing output')
with zipfile.ZipFile(source) as z:
    header = json.loads(z.read('pack.json'))
    if not (header['schema'] == 2 and header['source_snapshot'] == 'base508'):
        raise ValueError("Source contract check failed: header['schema']==2 and header['source_snapshot']=='base508'")
    index = {}
    for chunk in header['chunks']:
        raw = z.read(chunk['path'])
        if not (len(raw) == chunk['bytes'] and sha(raw) == chunk['sha256']):
            raise ValueError("Source contract check failed: len(raw)==chunk['bytes'] and sha(raw)==chunk['sha256']")
        rows = json.loads(raw)
        if not len(rows) == chunk['count']:
            raise ValueError("Source contract check failed: len(rows)==chunk['count']")
        for row in rows:
            name = row['path']
            if not (name not in index and (not pathlib.PurePosixPath(name).is_absolute()) and ('..' not in name.split('/')) and ('\\' not in name) and (':' not in name)):
                raise ValueError("Source contract check failed: name not in index and not pathlib.PurePosixPath(name).is_absolute() and '..'not in name.split('/')and '\\\\'not in name and ':'not in name")
            if not (row['bytes'] >= 0 and row['offset'] >= 0 and (row['offset'] + row['bytes'] <= chunk['payload_bytes'])):
                raise ValueError("Source contract check failed: row['bytes']>=0 and row['offset']>=0 and row['offset']+row['bytes']<=chunk['payload_bytes']")
            index[name] = (chunk, row)
    if not len(index) == header['files']:
        raise ValueError("Source contract check failed: len(index)==header['files']")
    cache = {}

    def read(name):
        chunk, row = index[name]
        key = chunk['payload']
        if key not in cache:
            payload = z.read(key)
            if not (len(payload) == chunk['payload_bytes'] and sha(payload) == chunk['payload_sha256']):
                raise ValueError("Source contract check failed: len(payload)==chunk['payload_bytes']and sha(payload)==chunk['payload_sha256']")
            cache.clear()
            cache[key] = payload
        body = cache[key][row['offset']:row['offset'] + row['bytes']]
        if not (len(body) == row['bytes'] and sha(body) == row['sha256']):
            raise ValueError("Source contract check failed: len(body)==row['bytes']and sha(body)==row['sha256']")
        return body
    full = json.loads(read('manifest.json'))
    selected = {}
    models = {}
    paths = set()
    pairs = []
    for binding in bindings:
        nid = str(binding['npc_id'])
        record = full['records'][nid]
        if not (record['npc_id'] == binding['npc_id'] and record['sprite_id'] == binding['sprite_id']):
            raise ValueError("Source contract check failed: record['npc_id']==binding['npc_id']and record['sprite_id']==binding['sprite_id']")
        if not any((c.get('spawn_view_id') == binding['spawn_view_id'] and c.get('territory_link_id') == binding['territory_link_id'] for c in record.get('source_contexts', [record]))):
            raise ValueError("Source contract check failed: any(c.get('spawn_view_id')==binding['spawn_view_id']and c.get('territory_link_id')==binding['territory_link_id']for c in record.get('source_contexts',[record]))")
        selected[nid] = record
        models[str(record['sprite_id'])] = full['models'][str(record['sprite_id'])]
        model_bytes = read(record['tracks_ref'])
        if not sha(model_bytes) == record['tracks_sha256']:
            raise ValueError("Source contract check failed: sha(model_bytes)==record['tracks_sha256']")
        model = json.loads(model_bytes)
        if not model['source_sprite_id'] == binding['sprite_id']:
            raise ValueError("Source contract check failed: model['source_sprite_id']==binding['sprite_id']")
        paths.add(record['tracks_ref'])
        for track in model['tracks'].values():
            for frames in track['directions']:
                for frame in frames:
                    for layer in frame['layers']:
                        if not index[layer['path']][1]['sha256'] == layer['sha256']:
                            raise ValueError("Source contract check failed: index[layer['path']][1]['sha256']==layer['sha256']")
                        paths.add(layer['path'])
        pairs.append({k: binding[k] for k in ['npc_id', 'sprite_id', 'spawn_view_id', 'territory_link_id', 'land_id', 'host_map_id']})
    out.mkdir(mode=448)
    for name in sorted(paths):
        path = out / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(read(name))
    source_files = {name: row for name, row in full['source_files'].items() if row['path'] in paths}
    subset = {**full, 'records': selected, 'models': models, 'source_files': source_files, 'counts': {'npc_records': len(selected), 'unique_sprite_models': len(models), 'original_sp2_files_used': len(source_files), 'native_geographic_spawns': 0}, 'private_subset_provenance': {'source_zip_sha256': expected, 'source_snapshot': 'base508', 'definition_policy': 'patch523, separately validated by runtime; no latest-art equality assertion', 'selection': 'Exact existing14 host contracts only; no new placement/count/respawn rule.'}}
    (out / 'manifest.json').write_text(json.dumps(subset, ensure_ascii=False, separators=(',', ':')) + '\n')
    receipt = {'source_zip_sha256': expected, 'whole_zip_sha256_pinned': True, 'selected_zip_entries_crc_verified_on_read': True, 'whole_zip_crc_checked_by_tool': False, 'selected_original_files': len(source_files), 'output_files': len(paths) + 1, 'output_bytes': sum((p.stat().st_size for p in out.rglob('*') if p.is_file())), 'manifest_sha256': sha((out / 'manifest.json').read_bytes()), 'contracts': pairs, 'actual_record_keys': {nid: list(row) for nid, row in selected.items()}, 'used_chunks': True}
    (root / (out.name + '.receipt.json')).write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in receipt.items() if k not in ['contracts', 'actual_record_keys']}, ensure_ascii=False))
