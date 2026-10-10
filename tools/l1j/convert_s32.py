#!/usr/bin/env python3
"""Index every supplied S32 placement, retaining original bytes and unknown data.

Binary record formats follow the supplied L1MapViewer CLI/S32Parser.cs and
PakViewer Lin.Helper.Core/Map/S32Reader.cs. This exports source geometry, not
terrain artwork, and never replaces playable TWILIGHT maps without the tiles.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile


def parse(blob):
    offset = 0
    spans = {}
    tiles = set()

    def read(fmt):
        nonlocal offset
        length = struct.calcsize('<' + fmt)
        if offset + length > len(blob):
            raise ValueError('truncated record at byte ' + str(offset))
        result = struct.unpack_from('<' + fmt, blob, offset)
        offset += length
        return result

    def span(name, start, count, record_bytes):
        spans[name] = dict(offset=start, bytes=offset-start, count=count,
                           record_bytes=record_bytes)

    start = offset
    for _ in range(128 * 64):
        index, tile, unknown = read('BHB')
        tiles.add(tile)
    span('floor_half_tiles', start, 128*64, 4)
    cover_count, = read('H')
    start = offset
    for _ in range(cover_count):
        x, y, index, tile, unknown = read('BBBHB')
        tiles.add(tile)
    span('floor_covers', start, cover_count, 6)
    start = offset
    for _ in range(64 * 64):
        read('hh')
    span('source_attributes', start, 64*64, 4)
    groups, = read('i')
    if groups < 0 or groups > (len(blob)-offset)//4:
        raise ValueError('invalid object group count')
    start = offset
    objects = 0
    for _ in range(groups):
        group, count = read('hH')
        for _ in range(count):
            x, y, layer, index, tile, unknown = read('BBBBhB')
            tiles.add(tile)
        objects += count
    span('object_groups', start, objects, None)
    spans['object_groups']['groups'] = groups
    for name, record_format in [('opacity_events', 'BBHB'), ('declared_tile_ids', 'i')]:
        if offset == len(blob):
            break
        count, = read('i')
        record_size = struct.calcsize('<'+record_format)
        if count < 0 or count > (len(blob)-offset)//record_size:
            raise ValueError('invalid ' + name + ' count')
        start = offset
        for _ in range(count):
            result = read(record_format)
            if name == 'declared_tile_ids':
                tiles.add(result[0])
        span(name, start, count, record_size)
    portals = []
    if offset < len(blob):
        count, = read('H')
        start = offset
        for _ in range(count):
            length, = read('B')
            name_bytes = bytes(read(str(length)+'s')[0])
            x, y, target_map, portal_id = read('BBHi')
            portals.append(dict(name_hex=name_bytes.hex(), local_position=[x,y],
                                target_map_id=target_map, source_portal_id=portal_id))
        span('source_portals', start, count, None)
    if offset < len(blob):
        count, = read('H')
        extended = bool(count & 0x8000)
        count &= 0x7fff
        start = offset
        for _ in range(count):
            read('HHHi' if extended else 'HHH')
        span('sprite_effects', start, count, 10 if extended else 6)
    # Preserve trailing/version-specific bytes. Unknown fields are not silently
    # interpreted as portals, collision, missing textures, or sprite identities.
    return dict(spans=spans, tile_ids=sorted(tiles), portals=portals,
                parsed_bytes=offset, unknown_tail_bytes=len(blob)-offset)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--a3', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    records = []
    failures = []
    used_tiles = set()
    counts = Counter()
    with zipfile.ZipFile(args.a3) as archive:
        for member in sorted(archive.namelist()):
            match = re.fullmatch(r'data/client_maps/([A-Za-z0-9_-]+)/(\d+)/([A-Za-z0-9_-]+)\.s32', member)
            if not match:
                continue
            theme, map_id, stem = match[1], int(match[2]), match[3]
            blob = archive.read(member)
            target = args.out / 'client_s32' / theme / str(map_id) / (stem+'.s32')
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(blob)
            try:
                data = parse(blob)
            except (ValueError, struct.error) as error:
                failures.append(dict(source_member=member, reason=str(error),
                                     source_sha256=hashlib.sha256(blob).hexdigest(),
                                     source_file='res://data/l1j/maps/'+target.relative_to(args.out).as_posix()))
                continue
            coordinate_name = re.fullmatch(r'([0-9a-fA-F]{8})(?:_\d+)?', stem)
            origin = None
            if coordinate_name:
                code = coordinate_name[1]
                bx, by = int(code[:4],16), int(code[4:],16)
                origin = [(bx-0x7fff)*64+32704, (by-0x7fff)*64+32704]
            data.update(map_id=map_id, theme=theme, source_member=member, source_origin=origin,
                        coordinate_status='filename block coordinates' if origin else 'unresolved nonstandard filename',
                        dimensions=[64,64], source_sha256=hashlib.sha256(blob).hexdigest(),
                        source_file='res://data/l1j/maps/'+target.relative_to(args.out).as_posix(),
                        terrain_graphics='MISSING', gameplay_applied=False)
            records.append(data)
            used_tiles.update(data['tile_ids'])
            for name, info in data['spans'].items():
                counts[name] += info['count']
            if len(records)%300 == 0:
                print('S32_PROGRESS',len(records),flush=True)
    supplied = sum(name.lower().endswith('.s32') for name in archive.namelist())
    if supplied != len(records)+len(failures):
        failures.append(dict(reason='source S32 inventory and parsed selection differ', supplied=supplied))
    manifest = dict(schema=1, format_basis='supplied L1MapViewer and PakViewer S32 parsers',
                    parsed_segments=len(records), failures=failures, placement_counts=dict(counts),
                    missing_tile_ids=sorted(used_tiles), segments=records,
                    gameplay_applied=False, artwork_restored=False)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out/'s32_placements.json').write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n')
    print('S32_SOURCE_GEOMETRY',len(records),'failures',len(failures),
          'required_tiles',len(used_tiles),'placements',dict(counts),flush=True)
    raise SystemExit(bool(failures))


if __name__ == '__main__':
    main()
