"""Bounded, lossless base508 S32 reader. No terrain-bit semantics are assumed.

This deliberately does not call formats.move_masks: those are A3 PC rules.
Packed references are unsigned 32-bit (24-bit TileID + 8-bit subimage).
"""
import base64
import hashlib
import re
import struct


def origin(member):
    match = re.fullmatch(r"([0-9a-fA-F]{4})([0-9a-fA-F]{4})\.s32", member.rsplit("/", 1)[-1])
    if not match:
        raise ValueError("S32 chunk must have an eight-hex-digit basename")
    return [(int(part, 16) - 0x7e00) * 64 for part in match.groups()]


class Reader:
    def __init__(self, data):
        if not 49158 <= len(data) <= 8 * 1024 * 1024:
            raise ValueError("S32 size outside bounded base508 core")
        self.data, self.pos = data, 0

    def take(self, n):
        if n < 0 or self.pos + n > len(self.data):
            raise ValueError(f"Truncated S32 at {self.pos}, requesting {n}")
        result = self.data[self.pos:self.pos+n]
        self.pos += n
        return result

    def unpack(self, fmt):
        return struct.unpack("<"+fmt, self.take(struct.calcsize("<"+fmt)))

    def count(self, fmt, minimum_size):
        value, = self.unpack(fmt)
        if value > (len(self.data)-self.pos)//minimum_size:
            raise ValueError(f"Unbounded S32 record count at {self.pos}")
        return value


def read_s32(data, member):
    r = Reader(data)
    floor = r.take(32768)
    covers = [list(r.unpack("BBI")) for _ in range(r.count("H", 6))]
    attributes = r.take(16384)
    objects = []
    for _ in range(r.count("I", 4)):
        group, count = r.unpack("HH")
        if count > (len(data)-r.pos)//7:
            raise ValueError("Unbounded object parts")
        objects.append({"group": group, "parts": [list(r.unpack("BBBI")) for _ in range(count)]})
    opacity = r.take(r.count("I", 5)*5)
    declared = list(r.unpack("I")[0] for _ in range(r.count("I", 4)))
    core_end = r.pos
    refs = set(struct.unpack("<8192I", floor))
    refs.update(row[2] for row in covers)
    refs.update(row[3] for group in objects for row in group["parts"])
    encode = lambda b: base64.b64encode(b).decode("ascii")
    return {
        "schema": 1, "edition": "LineageM_base508", "member": member,
        "origin": origin(member), "source_sha256": hashlib.sha256(data).hexdigest(),
        "source_bytes": len(data), "floor_u32le": encode(floor), "covers": covers,
        "attribute_u16le": encode(attributes), "objects": objects,
        "opacity_raw": encode(opacity), "declared_tile_ids": declared,
        "core_end": core_end, "uninterpreted_tail": encode(data[core_end:]),
        "tile_pairs": sorted([ref >> 8, ref & 255] for ref in refs),
        "terrain_collision": "UNKNOWN", "height": "UNKNOWN",
    }


def write_s32(row):
    decode = base64.b64decode
    b = bytearray(decode(row["floor_u32le"]))
    b += struct.pack("<H", len(row["covers"]))
    for part in row["covers"]:
        b += struct.pack("<BBI", *part)
    b += decode(row["attribute_u16le"])
    b += struct.pack("<I", len(row["objects"]))
    for group in row["objects"]:
        b += struct.pack("<HH", group["group"], len(group["parts"]))
        for part in group["parts"]:
            b += struct.pack("<BBBI", *part)
    opacity = decode(row["opacity_raw"])
    b += struct.pack("<I", len(opacity)//5) + opacity
    b += struct.pack("<I", len(row["declared_tile_ids"]))
    for tile in row["declared_tile_ids"]:
        b += struct.pack("<I", tile)
    return bytes(b) + decode(row["uninterpreted_tail"])
