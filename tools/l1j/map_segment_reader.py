"""Reuse the validated PR80 S32 decoder; original art is not reconstructed.

Source: 7167daa5:tools/l1j/convert_s32.py, parse().
Kept separately so recovering map Work does not overwrite the active PR80 tool.
"""
import struct

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
