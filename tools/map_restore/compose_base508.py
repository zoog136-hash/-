"""Compose original S32 layers using original TI2 pixels, without fallback art.

Display projection follows reviewed L1MapViewer ViewportRenderer.cs at
364fcff15ea019e5a9329170aaf7e245404ebba6. It never defines terrain collision.
Source origins, half-cell positions, layers, groups and TileIDs remain unchanged
in the separately retained lossless geometry.
"""
import base64
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil
import struct
import zlib
from PIL import Image
from base508_original_store import retain_original

from base508_ti2 import read_ti2, render


def project(origin, half_x, local_y, source_origin):
    dx, dy = origin[0]-source_origin[0], origin[1]-source_origin[1]
    return 24*(dx+dy+(half_x+1)//2+local_y), 12*(dy-dx+local_y-half_x//2)


def placements(chunks):
    origin = [min(c['origin'][i] for c in chunks) for i in range(2)]
    rows = []
    for chunk in chunks:
        for i, ref in enumerate(struct.unpack('<8192I', base64.b64decode(chunk['floor_u32le']))):
            x, y = project(chunk['origin'], i % 128, i//128, origin)
            rows.append((-2, x, y, ref))
        for half_x, local_y, ref in chunk['covers']:
            x, y = project(chunk['origin'], half_x, local_y, origin)
            rows.append((-1, x, y, ref))
        for group in chunk['objects']:
            for half_x, local_y, layer, ref in group['parts']:
                x, y = project(chunk['origin'], half_x, local_y, origin)
                rows.append((layer, x, y, ref))
    rows.sort(key=lambda r: r[0])  # Stable original order within a layer.
    return origin, rows


def compose(chunks, source, tile_inventory, out, tile_cache=None):
    if not chunks:
        raise ValueError('No original geometry to compose')
    origin, rows = placements(chunks)
    used = Counter(row[3] for row in rows)
    tiles, provenance, cache_keys = {}, [], {}
    for tile_id in sorted({ref >> 8 for ref in used}):
        spec = next(r for r in tile_inventory[str(tile_id)] if r['member'].endswith('.ti2'))
        file = source / spec['member']
        payload = file.read_bytes()
        if len(payload) != spec['bytes'] or f'{zlib.crc32(payload):08x}' != spec['crc32']:
            raise ValueError('TI2 inventory CRC mismatch: '+str(file))
        if tile_cache is None:
            tile = read_ti2(payload)
        else:
            cache_keys[tile_id], tile = tile_cache.read(payload)
        tiles[tile_id] = tile
        target = out / 'source' / spec['member']
        target.parent.mkdir(parents=True, exist_ok=True)
        retain_original(file, target)
        provenance.append({'tile_id': tile_id, 'source': 'source/'+spec['member'], 'bytes': len(payload), 'sha256': hashlib.sha256(payload).hexdigest(), 'crc32': spec['crc32'], 'header': tile['header'], 'block_count': len(tile['blocks']), 'flags': dict(Counter(b['flags'] for b in tile['blocks']))})
    frames = {}
    for ref in used:
        tile_id, index = ref >> 8, ref & 255
        tile = tiles[tile_id]
        if index >= len(tile['blocks']):
            raise ValueError(f'Unresolved original TileID/subimage: {tile_id}:{index}')
        frames[ref] = render(tile['blocks'][index], tile['palette'], display_alpha=True) if tile_cache is None else tile_cache.frame(cache_keys[tile_id],tile,index)
    left, top = min(r[1] for r in rows), min(r[2] for r in rows)
    right, bottom = max(r[1] for r in rows)+24, max(r[2] for r in rows)+24
    size = (right-left, bottom-top)
    if size[0]*size[1] > 160_000_000:
        raise ValueError('Composition exceeds bounded canvas allocation')
    image = Image.new('RGBA', size)
    for layer, x, y, ref in rows:
        image.alpha_composite(frames[ref], (x-left, y-top))
    empty = sum(used[ref] for ref, frame in frames.items() if frame.getchannel('A').getbbox() is None)
    statistics = {'s32_composed_chunks':sum(c.get('source_format','S32')=='S32' for c in chunks),'seg_composed_chunks':sum(c.get('source_format')=='SEG' for c in chunks), 'ti2_decoded_files': len(tiles), 'decoded_used_tile_pairs': len(frames), 'floor_half_tiles_composed': sum(r[0] == -2 for r in rows), 'cover_tiles_composed': sum(r[0] == -1 for r in rows), 'object_parts_composed': sum(r[0] >= 0 for r in rows), 'decoded_source_tile_placements': len(rows), 'visual_s32_tiles_restored': len(rows)-empty, 'empty_source_tile_placements': empty, 'missing_tile_pairs': 0, 'fallback_tiles': 0}
    statistics['visual_source_tiles_restored'] = len(rows)-empty
    if any(c.get('source_format')=='SEG' for c in chunks):
        by_format = {'S32':Counter(), 'SEG':Counter()}
        for chunk in chunks:
            refs = list(struct.unpack('<8192I',base64.b64decode(chunk['floor_u32le'])))
            refs.extend(c[2] for c in chunk['covers'])
            refs.extend(p[3] for g in chunk['objects'] for p in g['parts'])
            by_format[chunk.get('source_format','S32')].update(refs)
        for kind, counts in by_format.items():
            statistics['visual_'+kind.lower()+'_tiles_restored'] = sum(n for ref,n in counts.items() if frames[ref].getchannel('A').getbbox() is not None)
    metadata = {'schema': 1, 'source_origin': origin, 'pixel_translation': [-left, -top], 'half_tile_pixels': [24, 24], 'source_cell_basis_x': [24, -12], 'source_cell_basis_y': [24, 12], 'statistics': statistics, 'tile_provenance': provenance, 'display_alpha': 'Reviewed TI2 type bit2 half alpha and bit4/5 brightness alpha; original RGB565 colors retained; M engine equivalence unverified', 'depth_status': 'Original layer bytes applied; engine opacity/effect tail semantics unverified', 'terrain_collision': 'UNKNOWN'}
    (out/'composition.json').write_text(json.dumps(metadata, separators=(',', ':'))+'\n')
    return image, metadata
