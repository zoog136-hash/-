#!/usr/bin/env python3
"""Make independent whole-map physical probes from pinned private source bytes.

Requires NumPy. Output contains original evidence and belongs outside public Git.
QA positioning is explicit own behavior, never a recovered native admission rule.
Both input SHA pins are mandatory; existing output is never overwritten.
"""
from pathlib import Path
import json, hashlib, zlib, functools, struct, collections
import numpy as np
import argparse
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source-root', type=Path, required=True)
parser.add_argument('--source-sha256', required=True)
parser.add_argument('--portal-rows', type=Path, required=True)
parser.add_argument('--portal-sha256', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = args.source_root
pin = args.source_sha256
if args.output.exists():
    raise FileExistsError('Preserve existing evidence: choose a new output')
for path, digest in [(root / 'source523.json', pin), (args.portal_rows, args.portal_sha256)]:
    if len(digest) != 64 or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        raise ValueError('Private input SHA256 mismatch: ' + str(path))
m = json.load(open(root / 'source523.json'))
members = {r['member']: r for r in m['members']}
logical = {int(r['declaration']['ID']): r for r in m['logical_lands']}
roots = collections.defaultdict(dict)
byasset = collections.defaultdict(list)
for r in m['logical_lands']:
    if not r['excluded_content'] and r['policy_status'] == 'classified':
        byasset[r['declaration']['AssetPath']].append(r['declaration'])

@functools.lru_cache(maxsize=24)
def raw(name):
    r = members[name]
    b = (root / r['path']).read_bytes()
    assert hashlib.sha256(b).hexdigest() == r.get('stored_sha256', r['sha256'])
    b = zlib.decompress(b, 31) if r.get('storage_format') == 'gzip' else b
    assert len(b) == r['bytes'] and hashlib.sha256(b).hexdigest() == r['sha256']
    return b
for r in m['members']:
    if r['status'] != 'ready' or r['format'] != 's32' or len(Path(r['member']).stem) != 8:
        continue
    b = raw(r['member'])
    stem = Path(r['member']).stem
    origin = ((int(stem[:4], 16) - 32256) * 64, (int(stem[4:], 16) - 32256) * 64)
    a = np.frombuffer(b, dtype='<u2', count=8192, offset=r['attribute_offset']).reshape(64, 64, 2)
    f = np.frombuffer(b, dtype='<u4', count=8192).reshape(64, 64, 2)
    allowed = np.isin(a, [0, 4, 8, 12, 32]).all(axis=2) & (f != 4294967295).all(axis=2)
    roots[r['asset_path']][origin] = {'member': r['member'], 'mask': allowed}
    assert len(roots[r['asset_path']]) <= 6558
portals = json.loads(args.portal_rows.read_text(encoding='utf-8'))
native = collections.defaultdict(list)
for row in portals:
    p = row['Portal']
    land = logical.get(int(p['SourceLandID']))
    if land and (not land['excluded_content']):
        native[land['declaration']['AssetPath']].append({'cell': [p['SourceX'], p['SourceY']], 'land_id': int(p['SourceLandID']), 'role': 'EXACT_CURRENT523_PORTAL_SOURCE_COORDINATE; QA_ENTRY_NOT_NATIVE_ADMISSION', 'portal_id': p['ID'], 'native_row': p})

def info(asset, x, y):
    chunk = roots[asset].get((x // 64 * 64, y // 64 * 64))
    r = {'source_cell': [int(x), int(y)], 'walkable': False, 'status': 'missing_or_unplaced_source'}
    if chunk is None:
        return r
    name = chunk['member']
    spec = members[name]
    b = raw(name)
    i = y % 64 * 128 + x % 64 * 2
    r.update(member=name, source_sha256=spec['sha256'], raw_pair=list(struct.unpack_from('<HH', b, spec['attribute_offset'] + i * 2)), floor_pair=list(struct.unpack_from('<II', b, i * 4)), walkable=bool(chunk['mask'][y % 64, x % 64]), status='original_cell')
    return r
D = [(0, -1), (1, 0), (0, 1), (-1, 0)]
cases = []
for asset, chunks in sorted(roots.items()):
    candidates = sorted(native[asset], key=lambda x: (x['land_id'], x['portal_id']))
    selected = None
    clear = None
    for candidate in candidates:
        x, y = candidate['cell']
        f = info(asset, x, y)
        if not f['walkable']:
            continue
        for dx, dy in D:
            n = info(asset, x + dx, y + dy)
            if n['walkable']:
                selected = {**candidate, 'entry_cell_info': f}
                clear = n
                break
        if selected:
            break
    if selected is None:
        for (ox, oy), chunk in sorted(chunks.items()):
            mask = chunk['mask']
            pair = mask[:, :-1] & mask[:, 1:]
            points = np.argwhere(pair)
            if len(points):
                y, x = points[0]
                selected = {'cell': [ox + int(x), oy + int(y)], 'land_id': min((x['ID'] for x in byasset[asset])), 'role': 'OWN_QA_FIRST_CLEAR_CARDINAL_EDGE; NOT_NATIVE_ENTRY_OR_TRAVEL_RULE', 'entry_cell_info': info(asset, ox + int(x), oy + int(y))}
                clear = info(asset, ox + int(x) + 1, oy + int(y))
                break
            pair = mask[:-1] & mask[1:]
            points = np.argwhere(pair)
            if len(points):
                y, x = points[0]
                selected = {'cell': [ox + int(x), oy + int(y)], 'land_id': min((x['ID'] for x in byasset[asset])), 'role': 'OWN_QA_FIRST_CLEAR_CARDINAL_EDGE; NOT_NATIVE_ENTRY_OR_TRAVEL_RULE', 'entry_cell_info': info(asset, ox + int(x), oy + int(y))}
                clear = info(asset, ox + int(x), oy + int(y) + 1)
                break
    assert selected and clear and selected['entry_cell_info']['walkable'] and clear['walkable'], asset
    wall = None
    for (ox, oy), chunk in sorted(chunks.items()):
        mask = chunk['mask']
        for dx, dy in D:
            neighbor = np.roll(mask, shift=(-dy, -dx), axis=(0, 1))
            edge = mask & ~neighbor
            edge[0, :] = False
            edge[-1, :] = False
            edge[:, 0] = False
            edge[:, -1] = False
            points = np.argwhere(edge)
            if len(points):
                y, x = points[0]
                stand = info(asset, ox + int(x), oy + int(y))
                blocked = info(asset, ox + int(x) + dx, oy + int(y) + dy)
                assert stand['walkable'] and (not blocked['walkable'])
                wall = {'stand': stand, 'blocked': blocked, 'role': 'OWN_QA_WALL_PROBE_POSITION; NOT_NATIVE_TRAVEL'}
                break
        if wall:
            break
    if wall is None:
        for (ox, oy), chunk in sorted(chunks.items()):
            points = np.argwhere(chunk['mask'])
            for y, x in points:
                if int(x) not in (0, 63) and int(y) not in (0, 63):
                    continue
                for dx, dy in D:
                    n = info(asset, ox + int(x) + dx, oy + int(y) + dy)
                    if not n['walkable']:
                        wall = {'stand': info(asset, ox + int(x), oy + int(y)), 'blocked': n, 'role': 'OWN_QA_OUTER_BOUNDARY_WALL_PROBE'}
                        break
                if wall:
                    break
            if wall:
                break
    assert wall, asset
    seam = None
    refused = None
    closed = None
    pairs = 0
    for (ox, oy), chunk in sorted(chunks.items()):
        for dx, dy in [(64, 0), (0, 64)]:
            other = chunks.get((ox + dx, oy + dy))
            if other is None:
                continue
            pairs += 1
            left = chunk['mask'][:, -1] if dx else chunk['mask'][-1, :]
            right = other['mask'][:, 0] if dx else other['mask'][0, :]
            indices = np.flatnonzero(left & right)
            if len(indices) and seam is None:
                t = int(indices[0])
                a = (ox + 63, oy + t) if dx else (ox + t, oy + 63)
                b = (a[0] + 1, a[1]) if dx else (a[0], a[1] + 1)
                seam = {'first': info(asset, *a), 'second': info(asset, *b)}
            indices = np.flatnonzero(left ^ right)
            if len(indices) and refused is None:
                t = int(indices[0])
                a = (ox + 63, oy + t) if dx else (ox + t, oy + 63)
                b = (a[0] + 1, a[1]) if dx else (a[0], a[1] + 1)
                fa = info(asset, *a)
                fb = info(asset, *b)
                refused = {'first': fa if fa['walkable'] else fb, 'second': fb if fa['walkable'] else fa}
            if closed is None:
                a = (ox + 63, oy) if dx else (ox, oy + 63)
                b = (a[0] + 1, a[1]) if dx else (a[0], a[1] + 1)
                closed = {'first': info(asset, *a), 'second': info(asset, *b)}
    minx = min((x for x, y in chunks))
    miny = min((y for x, y in chunks))
    land = logical[selected['land_id']]['declaration']
    cases.append({'land_id': land['ID'], 'name': land['Name'], 'asset_path': asset, 'placed_S32': len(chunks), 'entry': selected, 'clear_neighbor': clear, 'wall_probe': wall, 'open_seam': seam, 'refused_seam': refused, 'closed_seam_sample': closed, 'adjacent_chunk_pairs': pairs, 'outside_cell': [minx - 1, miny - 1], 'source_rule': 'OWN_ALLOWLIST_0_4_8_12_32; both floor refs present; native M semantics unknown', 'native_coordinate_candidates': len(candidates), 'native_admission_verified': False})
    if len(cases) % 100 == 0:
        print('ROOT_CASES', len(cases), flush=True)
assert len(cases) == 577
out = {'schema': 1, 'source_manifest_sha256': pin, 'native_rules_verified': False, 'cases': cases, 'summary': {'roots': len(cases), 'native_source_coordinate_entries': sum((c['entry']['role'].startswith('EXACT_CURRENT') for c in cases)), 'own_QA_entries': sum((c['entry']['role'].startswith('OWN_QA') for c in cases)), 'open_seam_roots': sum((c['open_seam'] is not None for c in cases)), 'refused_seam_roots': sum((c['open_seam'] is None and c['refused_seam'] is not None for c in cases)), 'closed_seam_roots': sum((c['open_seam'] is None and c['refused_seam'] is None and (c['adjacent_chunk_pairs'] > 0) for c in cases)), 'no_adjacent_chunks_roots': sum((c['adjacent_chunk_pairs'] == 0 for c in cases))}}
p = args.output
p.write_text(json.dumps(out, indent=2, ensure_ascii=False) + '\n')
print(json.dumps({'path': str(p), 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'summary': out['summary']}, ensure_ascii=False))
