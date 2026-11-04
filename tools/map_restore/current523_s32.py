"""Bounded, lossless LineageM cumulative523 Aden S32 byte model.

This module imports no viewer or spatial helper. Storage indices and unsigned
packed references are raw observations; coordinates, projection, movement,
collision, height, zones and drawing order remain UNKNOWN. S32 has no edition
header: a parsed byte stream alone cannot establish source identity. The pinned
677-member manifest establishes the current523 selection separately.

Sections form a contiguous partition of the source. Count headers belong to
their section; records_offset skips that header. Object group offsets point to
their HH header and parts_offset to the following 7-byte raw records.
"""

import hashlib
import re
import struct

SCHEMA = 1
EDITION = "LineageM"
CUMULATIVE_VERSION = 523
LAND_ID = 4
ASSET_PATH = "Aden/"
SOURCE_ROOT = "Map/Aden/"
SOURCE_COUNT = 677
MANIFEST_NAME = "aden523.json"
SOURCE_INVENTORY_SHA256 = "e236f89849bcc6fc618feb13046c077adff59f909ad376b408c9b24fafc3288c"
CURRENT_ANCHOR = "Map/Aden/800a8000.s32"
CURRENT_ANCHOR_BYTES = 210523
CURRENT_ANCHOR_SHA256 = "ab3b89eb4a9be8b2b5448c60bcf4c7ac6d4164ada21d85f88ffc7f566e9b2b96"
FLOOR_BYTES = 32768
ATTRIBUTE_BYTES = 16384
MIN_BYTES = FLOOR_BYTES + 2 + ATTRIBUTE_BYTES + 12
MAX_BYTES = 8 * 1024 * 1024
MAX_COVERS = 65535
MAX_OBJECT_GROUPS = 65535
MAX_OBJECT_PARTS = 262144
MAX_GROUP_PARTS = 65535
MAX_OPACITY_RECORDS = 262144
MAX_DECLARED = 65535
MAX_TAIL_BYTES = 1024 * 1024
SECTION_NAMES = ("floor", "covers", "attributes", "objects", "opacity", "declared", "tail")
SEMANTICS = dict.fromkeys(("coordinates", "projection", "movement", "collision",
                          "height", "regions", "zones", "safety_combat", "drawing_order"), "UNKNOWN")
_SHA256 = re.compile(r"[0-9a-f]{64}\Z")
_MEMBER = re.compile(r"Map/Aden/[A-Za-z0-9_-]+\.s32\Z")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def _integer(value, name, minimum=0, maximum=MAX_BYTES):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f"Invalid {name}: expected integer {minimum}..{maximum}")
    return value


def _hash(value, name):
    if not isinstance(value, str) or not _SHA256.fullmatch(value):
        raise ValueError(f"Invalid SHA256: {name}")
    return value


def validate_member_path(member):
    """Accept one literal Aden filename, including the nonstandard source name."""
    if not isinstance(member, str) or len(member) > 128 or not _MEMBER.fullmatch(member):
        raise ValueError("Invalid Aden source member path")
    return member


def _identity(edition, cumulative_version):
    if edition != EDITION or type(cumulative_version) is not int or cumulative_version != CUMULATIVE_VERSION:
        raise ValueError("Only LineageM cumulative523 is accepted")


class _Reader:
    def __init__(self, data):
        size = data.nbytes if isinstance(data, memoryview) else len(data) if isinstance(data, (bytes, bytearray)) else -1
        if not MIN_BYTES <= size <= MAX_BYTES:
            raise ValueError("S32 source size outside bounded raw model")
        self.data = bytes(data)
        self.pos = 0

    def take(self, size):
        if size < 0 or size > len(self.data) - self.pos:
            raise ValueError(f"Truncated S32 at raw offset {self.pos}, requesting {size} bytes")
        start = self.pos
        self.pos += size
        return self.data[start:self.pos]

    def unpack(self, fmt):
        return struct.unpack("<" + fmt, self.take(struct.calcsize("<" + fmt)))

    def count(self, fmt, width, limit, reserve=0):
        offset = self.pos
        value, = self.unpack(fmt)
        remaining = len(self.data) - self.pos - reserve
        if value > limit or remaining < 0 or value > remaining // width:
            raise ValueError(f"Invalid S32 record count at raw offset {offset}")
        return value


def read_s32(data, member, *, cumulative_version=CUMULATIVE_VERSION, edition=EDITION):
    """Decode raw storage only. Source identity requires validate_manifest too."""
    _identity(edition, cumulative_version)
    validate_member_path(member)
    r = _Reader(data)
    sections = {}

    def section(name, start, **metadata):
        sections[name] = {"offset": start, "bytes": r.pos - start,
                          "sha256": sha256(r.data[start:r.pos]), **metadata}

    floor = r.take(FLOOR_BYTES)
    section("floor", 0)
    start = r.pos
    count = r.count("H", 6, MAX_COVERS, ATTRIBUTE_BYTES + 12)
    covers = [r.unpack("BBI") for _ in range(count)]
    section("covers", start, count=count, records_offset=start + 2)
    start = r.pos
    attributes = r.take(ATTRIBUTE_BYTES)
    section("attributes", start)
    start = r.pos
    count = r.count("I", 4, MAX_OBJECT_GROUPS, 8)
    objects = []
    total_parts = 0
    for index in range(count):
        offset = r.pos
        group, parts_count = r.unpack("HH")
        reserve = 4 * (count - index - 1) + 8
        total_parts += parts_count
        if (parts_count > MAX_GROUP_PARTS or total_parts > MAX_OBJECT_PARTS
                or parts_count > (len(r.data) - r.pos - reserve) // 7):
            raise ValueError(f"Invalid S32 object part count at raw offset {offset + 2}")
        objects.append({"group": group, "offset": offset, "parts_offset": r.pos,
                        "parts": [r.unpack("BBBI") for _ in range(parts_count)]})
    section("objects", start, count=count, records_offset=start + 4, part_count=total_parts)
    start = r.pos
    count = r.count("I", 5, MAX_OPACITY_RECORDS, 4)
    opacity = r.take(count * 5)
    section("opacity", start, count=count, records_offset=start + 4)
    start = r.pos
    count = r.count("I", 4, MAX_DECLARED)
    declared = [r.unpack("I")[0] for _ in range(count)]
    section("declared", start, count=count, records_offset=start + 4)
    core_end = r.pos
    if len(r.data) - core_end > MAX_TAIL_BYTES:
        raise ValueError("S32 opaque tail exceeds limit")
    tail = r.take(len(r.data) - core_end)
    section("tail", core_end)
    return {"schema": SCHEMA, "edition": EDITION, "cumulative_version": CUMULATIVE_VERSION,
            "member": member, "source_bytes": len(r.data), "source_sha256": sha256(r.data),
            "floor_u32le": floor, "covers": covers, "attribute_u16le": attributes,
            "objects": objects, "opacity_raw": opacity, "declared_tile_ids": declared,
            "core_end": core_end, "uninterpreted_tail": tail, "sections": sections,
            "semantics": dict(SEMANTICS)}


def _raw(value, name, size=None):
    if not isinstance(value, bytes) or (size is not None and len(value) != size):
        raise ValueError(f"Invalid raw byte field: {name}")
    return value


def _pack(fmt, values):
    try:
        if any(type(value) is not int for value in values):
            raise ValueError("Raw fields must be integers")
        return struct.pack("<" + fmt, *values)
    except (struct.error, TypeError, OverflowError) as exc:
        raise ValueError("Raw record has an invalid unsigned field or width") from exc


def write_s32(row):
    """Rebuild a decoded original and verify its byte/hash/section invariants."""
    if not isinstance(row, dict) or type(row.get("schema")) is not int or row["schema"] != SCHEMA:
        raise ValueError("Invalid raw S32 schema")
    _identity(row.get("edition"), row.get("cumulative_version"))
    validate_member_path(row.get("member"))
    try:
        floor = _raw(row["floor_u32le"], "floor", FLOOR_BYTES)
        attributes = _raw(row["attribute_u16le"], "attributes", ATTRIBUTE_BYTES)
        covers, objects, declared = row["covers"], row["objects"], row["declared_tile_ids"]
        _integer(len(covers), "cover count", maximum=MAX_COVERS)
        _integer(len(objects), "object count", maximum=MAX_OBJECT_GROUPS)
        _integer(len(declared), "declared count", maximum=MAX_DECLARED)
        opacity = _raw(row["opacity_raw"], "opacity")
        if len(opacity) % 5:
            raise ValueError("Opacity raw byte count must be divisible by five")
        _integer(len(opacity) // 5, "opacity count", maximum=MAX_OPACITY_RECORDS)
        tail = _raw(row["uninterpreted_tail"], "tail")
        _integer(len(tail), "tail bytes", maximum=MAX_TAIL_BYTES)
        out = bytearray(floor) + _pack("H", [len(covers)])
        for record in covers:
            out += _pack("BBI", record)
        out += attributes + _pack("I", [len(objects)])
        total_parts = 0
        for group in objects:
            parts = group["parts"]
            total_parts += len(parts)
            _integer(len(parts), "group part count", maximum=MAX_GROUP_PARTS)
            _integer(total_parts, "total object parts", maximum=MAX_OBJECT_PARTS)
            out += _pack("HH", [group["group"], len(parts)])
            for record in parts:
                out += _pack("BBBI", record)
        out += _pack("I", [len(opacity) // 5]) + opacity + _pack("I", [len(declared)])
        for value in declared:
            out += _pack("I", [value])
        out += tail
    except (KeyError, TypeError) as exc:
        raise ValueError("Incomplete raw S32 record") from exc
    result = bytes(out)
    decoded = read_s32(result, row["member"])
    for name in ("source_bytes", "source_sha256", "core_end", "sections", "semantics"):
        if row.get(name) != decoded[name]:
            raise ValueError(f"Raw S32 {name} does not match reserialization")
    if row["objects"] != decoded["objects"]:
        raise ValueError("Object raw offsets do not match reserialization")
    return result


def inventory_sha256(members):
    """Canonical current-selection identity, independent of JSON formatting."""
    if not isinstance(members, (list, tuple)) or len(members) > SOURCE_COUNT:
        raise ValueError("Aden inventory must be a bounded member list")
    lines = []
    seen = set()
    for row in members:
        if not isinstance(row, dict):
            raise ValueError("Invalid Aden inventory row")
        member = validate_member_path(row.get("member"))
        if member in seen:
            raise ValueError("Duplicate Aden member")
        seen.add(member)
        size = _integer(row.get("bytes"), "source bytes", MIN_BYTES, MAX_BYTES)
        digest = _hash(row.get("sha256"), member)
        lines.append((member, f"{member}\t{size}\t{digest}\n"))
    return sha256("".join(line for _, line in sorted(lines)).encode("utf-8"))


def _validate_sections(row):
    sections = row.get("sections")
    if not isinstance(sections, dict) or set(sections) != set(SECTION_NAMES):
        raise ValueError("Missing or unexpected raw S32 sections")
    end = 0
    for name in SECTION_NAMES:
        section = sections[name]
        if not isinstance(section, dict):
            raise ValueError("Invalid raw S32 section")
        if _integer(section.get("offset"), "section offset") != end:
            raise ValueError("S32 sections must form a contiguous partition")
        size = _integer(section.get("bytes"), "section bytes")
        _hash(section.get("sha256"), "section " + name)
        if name in ("floor", "attributes", "tail") and "count" in section:
            raise ValueError("Unexpected count in uncounted raw S32 section: " + name)
        if name in ("floor", "attributes"):
            if size != (FLOOR_BYTES if name == "floor" else ATTRIBUTE_BYTES):
                raise ValueError("Invalid fixed raw S32 section size")
        elif name == "tail":
            if size > MAX_TAIL_BYTES:
                raise ValueError("Opaque tail exceeds limit")
        else:
            header, width, limit = {"covers": (2, 6, MAX_COVERS), "objects": (4, 4, MAX_OBJECT_GROUPS),
                                    "opacity": (4, 5, MAX_OPACITY_RECORDS),
                                    "declared": (4, 4, MAX_DECLARED)}[name]
            count = _integer(section.get("count"), name + " count", maximum=limit)
            if _integer(section.get("records_offset"), "records offset") != end + header:
                raise ValueError("Invalid raw records offset")
            expected_size = header + width * count
            if name == "objects":
                parts = _integer(section.get("part_count"), "object parts", maximum=MAX_OBJECT_PARTS)
                if parts > count * MAX_GROUP_PARTS:
                    raise ValueError("Impossible raw object part count")
                expected_size += 7 * parts
                if _integer(row.get("object_part_count"), "object part metadata", maximum=MAX_OBJECT_PARTS) != parts:
                    raise ValueError("Object part metadata does not match section")
            if size != expected_size:
                raise ValueError("Raw count does not match section size")
        end += size
        if end > row["bytes"]:
            raise ValueError("Raw S32 section exceeds source size")
    if (end != row["bytes"] or row.get("core_end") != sections["tail"]["offset"]
            or row.get("attribute_offset") != sections["attributes"]["offset"]
            or row.get("attribute_sha256") != sections["attributes"]["sha256"]):
        raise ValueError("Raw S32 metadata does not match section partition")


def validate_manifest(manifest):
    """Reject other editions, stale selections, unsafe paths and malformed offsets."""
    if not isinstance(manifest, dict) or type(manifest.get("schema")) is not int or manifest["schema"] != SCHEMA:
        raise ValueError("Invalid Aden manifest schema")
    _identity(manifest.get("edition"), manifest.get("cumulative_version"))
    for name, expected in (("land_id", LAND_ID), ("asset_path", ASSET_PATH),
                           ("source_root", SOURCE_ROOT), ("source_count", SOURCE_COUNT)):
        if manifest.get(name) != expected or (isinstance(expected, int) and type(manifest.get(name)) is not int):
            raise ValueError(f"Invalid Aden manifest {name}")
    declaration = manifest.get("land_declaration")
    if (not isinstance(declaration, dict) or type(declaration.get("ID")) is not int
            or declaration["ID"] != LAND_ID or declaration.get("AssetPath") != ASSET_PATH):
        raise ValueError("Invalid direct Land4 declaration in Aden manifest")
    if manifest.get("delivery_status") != "PRIVATE_LOCAL_ONLY":
        raise ValueError("Raw Aden pack must retain its private local delivery status")
    semantics = manifest.get("semantics")
    if not isinstance(semantics, dict) or any(semantics.get(key) != value for key, value in SEMANTICS.items()) or any(value != "UNKNOWN" for value in semantics.values()):
        raise ValueError("Raw S32 semantics must remain UNKNOWN")
    members = manifest.get("members")
    if not isinstance(members, list) or len(members) != SOURCE_COUNT:
        raise ValueError("Current523 Aden requires exactly 677 members")
    digest = inventory_sha256(members)
    if digest != SOURCE_INVENTORY_SHA256 or manifest.get("source_inventory_sha256") != digest:
        raise ValueError("Aden source inventory is not the pinned current523 selection")
    for row in members:
        if row.get("path") != "originals/" + row["member"] or row.get("source_path") != row["member"]:
            raise ValueError("Invalid private Aden source relative path")
        if row["member"] == CURRENT_ANCHOR and (row["bytes"] != CURRENT_ANCHOR_BYTES or row["sha256"] != CURRENT_ANCHOR_SHA256):
            raise ValueError("Stale Aden 800a8000.s32 is not current523")
        _validate_sections(row)
    return manifest
