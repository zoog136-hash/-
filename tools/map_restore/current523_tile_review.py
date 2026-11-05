#!/usr/bin/env python3
"""Private current523 TI2 coverage atlases, explicitly a display hypothesis.

The raw palette/span model follows the reviewed base508_ti2 helper; 24x24
geometry and RGB565 expansion are candidate interpretations, not confirmed M
runtime behavior. Stored indices receive alpha255, including black/index0.
Viewer alpha flags, world coordinates, projection and movement are not applied.
Compressed originals, all raw u16/flag/index bytes and unknown bits are retained
or hashed separately; decoded serialization must reproduce every original byte.
"""

import argparse
import base64
import ctypes
import ctypes.util
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import struct
import tempfile
import zipfile

import numpy as np
from PIL import Image

from build_current523_aden_pack import _json, _output_path, _publish_directory, _regular_child

SOURCE_COUNT = 2866
SOURCE_BYTES = 97365118
SOURCE_INVENTORY_SHA256 = "b80c592b894b84a265e6f72739af77a78b96b26d6e3ee7ca0a441e0a41c79fab"
SOURCE_RECORDS_SHA256 = "dd503815d713d59cb7b423616957ca6f33866c3b21dab3a48f7d698834d71d31"
REFERENCE_ARCHIVE_SHA256 = "4c0e4d51a42318ae4513f1f1cd60787ed4d467e8d8808e84df049d11df079dae"
REFERENCE_MEMBER = "results/all_Aden_TI2_subimage_pixels.jsonl.gz"
ATLAS_RGBA_INVENTORY_SHA256 = "e84e7a7402c500f100dfe916eea4c7e52af18ba0c24a2e290a8e1dce11be0b2f"
RAW_MODEL_INVENTORY_SHA256 = "cf40acf2c28292eff48cb58cc054f20374f398d03d3286b834beed0c68b77e2c"
RAW_MODEL_FIELDS = ("decoded_bytes", "decoded_sha256", "stored_pixels", "raw_header_u32", "palette_colors",
                    "raw_sections", "palette_u16le_sha256", "raw_decoded_roundtrip")
MAX_BYTES = 8 * 1024 * 1024
MANIFEST_NAME = "tiles523.json"
STATUS = "DISPLAY_HYPOTHESIS_COVERAGE_V1"
SEMANTICS = {"geometry": "CANDIDATE_24X24", "palette": "CANDIDATE_RGB565",
             "coverage_alpha": "STORED_255_UNSTORED_0", "runtime_alpha": "UNKNOWN",
             "coordinates": "UNKNOWN", "projection": "UNKNOWN", "layers": "UNKNOWN",
             "movement": "UNKNOWN", "collision": "UNKNOWN"}
_MEMBER = re.compile(r"Tile/(0|[1-9][0-9]*)\.ti2\Z")
_HASH = re.compile(r"[0-9a-f]{64}\Z")
_BROTLI = None


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def _integer(value, name, maximum=MAX_BYTES, minimum=0):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError("Invalid integer: " + name)
    return value


def _digest(value):
    if not isinstance(value, str) or not _HASH.fullmatch(value):
        raise ValueError("Invalid SHA256")
    return value


def member_id(member):
    if not isinstance(member, str) or len(member) > 40:
        raise ValueError("Invalid literal TI2 member")
    match = _MEMBER.fullmatch(member)
    if match is None:
        raise ValueError("Invalid literal TI2 member")
    return _integer(int(match[1]), "tile ID", 0xffffff)


def _brotli():
    global _BROTLI
    if _BROTLI is None:
        name = ctypes.util.find_library("brotlidec")
        if not name:
            raise RuntimeError("Install the standard libbrotlidec library")
        lib = ctypes.CDLL(name)
        pointer = ctypes.POINTER(ctypes.c_ubyte)
        lib.BrotliDecoderCreateInstance.argtypes = [ctypes.c_void_p] * 3
        lib.BrotliDecoderCreateInstance.restype = ctypes.c_void_p
        lib.BrotliDecoderDestroyInstance.argtypes = [ctypes.c_void_p]
        lib.BrotliDecoderDecompressStream.argtypes = [ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_size_t), ctypes.POINTER(pointer),
            ctypes.POINTER(ctypes.c_size_t), ctypes.POINTER(pointer), ctypes.POINTER(ctypes.c_size_t)]
        lib.BrotliDecoderDecompressStream.restype = ctypes.c_int
        _BROTLI = lib
    return _BROTLI


def strict_decompress(raw, limit=MAX_BYTES):
    """Reject truncated, trailing and concatenated streams; cap all output."""
    _integer(limit, "decoded size limit", MAX_BYTES, 1)
    if not isinstance(raw, bytes) or not 1 <= len(raw) <= MAX_BYTES:
        raise ValueError("Compressed TI2 outside bounded size")
    lib = _brotli()
    pointer = ctypes.POINTER(ctypes.c_ubyte)
    source = (ctypes.c_ubyte * len(raw)).from_buffer_copy(raw)
    available_in = ctypes.c_size_t(len(raw))
    next_in = ctypes.cast(source, pointer)
    total_out = ctypes.c_size_t()
    state = lib.BrotliDecoderCreateInstance(None, None, None)
    if not state:
        raise RuntimeError("Brotli decoder allocation failed")
    chunks, total = [], 0
    try:
        while True:
            capacity = min(65536, limit - total)
            if capacity <= 0:
                raise ValueError("Decoded TI2 exceeds bounded output size")
            buffer = ctypes.create_string_buffer(capacity)
            available_out = ctypes.c_size_t(capacity)
            next_out = ctypes.cast(buffer, pointer)
            result = lib.BrotliDecoderDecompressStream(state, ctypes.byref(available_in),
                ctypes.byref(next_in), ctypes.byref(available_out), ctypes.byref(next_out), ctypes.byref(total_out))
            used = capacity - available_out.value
            chunks.append(buffer.raw[:used])
            total += used
            if result == 1:
                if available_in.value != 0:
                    raise ValueError("Trailing or concatenated Brotli input")
                return b"".join(chunks)
            if result != 3:
                raise ValueError("Invalid or truncated Brotli stream")
    finally:
        lib.BrotliDecoderDestroyInstance(state)


class _Reader:
    def __init__(self, raw):
        if not isinstance(raw, bytes) or not 4 <= len(raw) <= MAX_BYTES:
            raise ValueError("Decoded TI2 outside bounded size")
        self.raw, self.pos = raw, 0

    def take(self, count):
        if count < 0 or count > len(self.raw) - self.pos:
            raise ValueError("Truncated TI2 at raw offset " + str(self.pos))
        start = self.pos
        self.pos += count
        return self.raw[start:self.pos]

    def u8(self):
        return self.take(1)[0]


def parse_ti2(raw):
    """Bounded raw two-pass scan; geometry is interpreted only by render_atlas."""
    r = _Reader(raw)
    sections = {}
    def section(name, start):
        sections[name] = {"offset": start, "bytes": r.pos - start, "sha256": sha256(raw[start:r.pos])}
    header, = struct.unpack("<I", r.take(4))
    section("header", 0)
    count = header & 4095
    start = r.pos
    palette = b""
    if header & 4096:
        palette = r.take((r.u8() or 256) * 2)
    section("palette", start)
    start = r.pos
    flags = r.take(count)
    section("flags", start)
    start = r.pos
    blocks = []
    for flag in flags:
        offset = r.pos
        if flag & 64:
            origin, raw_runs = (0, 0), ()
        else:
            origin = (r.u8(), r.u8())
            size = r.u8()
            raw_runs = struct.unpack("<" + "H" * size, r.take(size * 2))
        pixel_count = 288 if flag & 64 else sum((word >> 5) & 31 for word in raw_runs)
        blocks.append({"flags": flag, "offset": origin, "raw_runs": raw_runs,
                       "descriptor_offset": offset, "descriptor_bytes": r.pos - offset,
                       "pixel_count": pixel_count})
    section("descriptors", start)
    start = r.pos
    palette_count = len(palette) // 2
    for block in blocks:
        block["pixels_offset"] = r.pos
        block["pixels"] = r.take(block["pixel_count"])
        if block["pixels"] and (not palette_count or max(block["pixels"]) >= palette_count):
            raise ValueError("TI2 index outside raw palette")
    section("indices", start)
    if r.pos != len(raw):
        raise ValueError("Unconsumed decoded TI2 bytes")
    return {"header": header, "palette_u16le": palette, "blocks": blocks,
            "sections": sections, "decoded_bytes": len(raw), "decoded_sha256": sha256(raw)}


def write_ti2(row):
    """Reconstruct descriptors and original unsigned palette/flags/index bytes."""
    try:
        out = bytearray(struct.pack("<I", row["header"]))
        palette = row["palette_u16le"]
        if row["header"] & 4096:
            if not isinstance(palette, bytes) or len(palette) % 2 or not 1 <= len(palette) // 2 <= 256:
                raise ValueError("Invalid raw TI2 palette")
            out += bytes([len(palette) // 2 % 256]) + palette
        elif palette:
            raise ValueError("Palette bytes without palette flag")
        blocks = row["blocks"]
        if len(blocks) != row["header"] & 4095:
            raise ValueError("TI2 block count does not match header")
        out += bytes(block["flags"] for block in blocks)
        for block in blocks:
            if not block["flags"] & 64:
                runs = block["raw_runs"]
                out += struct.pack("<BBB", *block["offset"], len(runs))
                out += struct.pack("<" + "H" * len(runs), *runs)
        for block in blocks:
            out += block["pixels"]
    except (KeyError, TypeError, struct.error, OverflowError) as exc:
        raise ValueError("Invalid raw TI2 record") from exc
    result = bytes(out)
    if len(result) > MAX_BYTES or len(result) != row.get("decoded_bytes") or sha256(result) != row.get("decoded_sha256"):
        raise ValueError("TI2 decoded byte-exact reserialization mismatch")
    return result


def _implicit_positions(left):
    widths = list(range(2, 25, 2)) + list(range(22, 0, -2))
    return np.concatenate([np.arange(0 if left else 24-width, width if left else 24, dtype=np.int32) + row * 24
                           for row, width in enumerate(widths)])


_IMPLICIT = (_implicit_positions(False), _implicit_positions(True))


def block_positions(block):
    if block["flags"] & 64:
        return _IMPLICIT[block["flags"] & 1]
    x_origin, y = block["offset"]
    x_base = x_origin
    positions = []
    for word in block["raw_runs"]:
        skip, count, row_step = word & 31, (word >> 5) & 31, (word >> 10) & 31
        x = x_base + skip
        if count:
            if x < 0 or x + count > 24 or not 0 <= y < 24:
                raise ValueError("Candidate TI2 write outside 24x24 canvas")
            positions.append(np.arange(x, x + count, dtype=np.int32) + y * 24)
        if row_step:
            y += row_step
            x_base = x_origin
        else:
            x_base = x + count
    result = np.concatenate(positions) if positions else np.empty(0, dtype=np.int32)
    if len(result) != len(block["pixels"]):
        raise ValueError("TI2 span/index consumption mismatch")
    _validate_positions(result)
    return result


def _validate_positions(positions):
    if len(positions) and (int(positions.min()) < 0 or int(positions.max()) >= 576):
        raise ValueError("Candidate TI2 write outside 24x24 canvas")
    if len(np.unique(positions)) != len(positions):
        raise ValueError("Duplicate candidate TI2 canvas write")


def render_atlas(row):
    """Vectorized stored-pixel coverage; viewer alpha flags are never applied."""
    if len(row["blocks"]) != 256:
        raise ValueError("Review atlas requires all256 physical TI2 blocks")
    words = np.frombuffer(row["palette_u16le"], dtype="<u2")
    red, green, blue = words >> 11, (words >> 5) & 63, words & 31
    rgba = np.empty((len(words), 4), dtype=np.uint8)
    rgba[:, 0], rgba[:, 1], rgba[:, 2], rgba[:, 3] = ((red << 3) | (red >> 2)), ((green << 2) | (green >> 4)), ((blue << 3) | (blue >> 2)), 255
    frames = np.zeros((256, 576, 4), dtype=np.uint8)
    for index, block in enumerate(row["blocks"]):
        positions = block_positions(block)
        indices = np.frombuffer(block["pixels"], dtype=np.uint8)
        if len(positions) != len(indices) or (len(indices) and int(indices.max()) >= len(words)):
            raise ValueError("Candidate TI2 palette/index mismatch")
        frames[index, positions] = rgba[indices]
    return frames.reshape(16, 16, 24, 24, 4).transpose(0, 2, 1, 3, 4).reshape(384, 384, 4)


def load_source_records(path):
    records, raw = _json(Path(path))
    if sha256(raw) != SOURCE_RECORDS_SHA256 or not isinstance(records, list) or len(records) != SOURCE_COUNT:
        raise ValueError("Trusted current523 TI2 source records do not match pinned evidence")
    seen = set()
    for row in records:
        if not isinstance(row, dict) or member_id(row.get("member")) != row.get("tile_id") or type(row.get("tile_id")) is not int:
            raise ValueError("Invalid TI2 source record identity")
        if row["member"] in seen:
            raise ValueError("Duplicate TI2 source record")
        seen.add(row["member"])
        _integer(row.get("source_bytes"), "source bytes", minimum=1)
        _integer(row.get("decoded_bytes"), "decoded bytes", minimum=4)
        _digest(row.get("source_sha256")); _digest(row.get("decoded_sha256"))
        if row.get("blocks") != 256 or row.get("header") != 4352:
            raise ValueError("Unexpected current523 raw TI2 header/block count")
    if source_inventory(records) != SOURCE_INVENTORY_SHA256:
        raise ValueError("Wrong current523 TI2 source inventory")
    # The independent per-frame ledger follows this evidence order.
    return records


def source_inventory(records):
    return sha256("".join(f"{row['member']}\t{row['source_bytes']}\t{row['source_sha256']}\n"
                          for row in sorted(records, key=lambda row: row["member"])).encode())


def rgba_inventory(tiles):
    return sha256("".join(f"{row['member']}\t{row['atlas_rgba_sha256']}\n"
                          for row in sorted(tiles, key=lambda row: row["member"])).encode())


def raw_model_inventory(tiles):
    try:
        lines = [row["member"] + "\t" + json.dumps({key: row[key] for key in RAW_MODEL_FIELDS},
                  sort_keys=True, separators=(",", ":")) + "\n" for row in sorted(tiles, key=lambda row: row["member"])]
    except (KeyError, TypeError) as error:
        raise ValueError("Invalid raw TI2 evidence inventory") from error
    return sha256("".join(lines).encode())


def verify_atlas_png(path, png_sha256=None, rgba_sha256=None):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or not 1 <= path.stat().st_size <= MAX_BYTES:
        raise ValueError("Invalid bounded atlas PNG")
    with path.open("rb") as handle:
        raw = handle.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError("Atlas PNG grew beyond bounded size")
    digest = sha256(raw)
    if png_sha256 is not None and digest != _digest(png_sha256):
        raise ValueError("Atlas PNG byte hash mismatch")
    if (len(raw) < 33 or raw[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
            or struct.unpack(">II", raw[16:24]) != (384, 384) or raw[24:29] != b"\x08\x06\x00\x00\x00"):
        raise ValueError("Atlas PNG must be RGBA384x384 before decoding")
    with Image.open(io.BytesIO(raw)) as image:
        if image.mode != "RGBA" or image.size != (384, 384):
            raise ValueError("Atlas PNG must be RGBA384x384")
        pixels_digest = sha256(image.tobytes())
    if rgba_sha256 is not None and pixels_digest != _digest(rgba_sha256):
        raise ValueError("Atlas PNG decoded RGBA hash mismatch")
    return digest, pixels_digest


def validate_manifest(manifest):
    if not isinstance(manifest, dict):
        raise ValueError("Invalid tile review manifest")
    for key, expected in (("schema", 1), ("edition", "LineageM"), ("cumulative_version", 523),
                           ("land_id", 4), ("asset_path", "Aden/"), ("source_root", "Tile/"),
                           ("source_count", SOURCE_COUNT), ("status", STATUS),
                           ("delivery_status", "PRIVATE_LOCAL_ONLY")):
        if manifest.get(key) != expected or (type(expected) is int and type(manifest.get(key)) is not int):
            raise ValueError("Tile review manifest identity mismatch: " + key)
    if manifest.get("semantics") != SEMANTICS or manifest.get("source_records_sha256") != SOURCE_RECORDS_SHA256:
        raise ValueError("Tile review evidence/interpretation boundary mismatch")
    tiles = manifest.get("tiles")
    if not isinstance(tiles, list) or len(tiles) != SOURCE_COUNT:
        raise ValueError("Tile review requires exactly2866 source members")
    seen = set()
    for tile in tiles:
        if not isinstance(tile, dict) or member_id(tile.get("member")) != tile.get("tile_id") or type(tile.get("tile_id")) is not int:
            raise ValueError("Invalid tile review member")
        if tile["member"] in seen:
            raise ValueError("Duplicate tile review member")
        seen.add(tile["member"])
        if tile.get("original_path") != "originals/" + tile["member"] or tile.get("atlas_path") != f"atlases/{tile['tile_id']}.png":
            raise ValueError("Invalid tile review relative path")
        for key in ("source_sha256", "decoded_sha256", "atlas_sha256", "atlas_rgba_sha256"):
            _digest(tile.get(key))
        for key in ("source_bytes", "atlas_bytes"):
            _integer(tile.get(key), key, minimum=1)
        _integer(tile.get("decoded_bytes"), "decoded bytes", minimum=4)
        if tile.get("blocks") != 256 or type(tile.get("blocks")) is not int or tile.get("atlas_size") != [384, 384]:
            raise ValueError("Invalid review atlas dimensions/block count")
        _integer(tile.get("stored_pixels"), "stored pixels", 256 * 576)
        colors = _integer(tile.get("palette_colors"), "palette colors", 256, 1)
        _digest(tile.get("palette_u16le_sha256"))
        if type(tile.get("raw_header_u32")) is not int or tile["raw_header_u32"] != 4352 or tile.get("raw_decoded_roundtrip") is not True:
            raise ValueError("Invalid raw TI2 header/roundtrip evidence")
        sections = tile.get("raw_sections")
        names = ("header", "palette", "flags", "descriptors", "indices")
        if not isinstance(sections, dict) or set(sections) != set(names):
            raise ValueError("Invalid raw TI2 evidence sections")
        end = 0
        for name in names:
            section = sections[name]
            if not isinstance(section, dict) or _integer(section.get("offset"), "raw section offset") != end:
                raise ValueError("Raw TI2 evidence sections must be contiguous")
            size = _integer(section.get("bytes"), "raw section bytes")
            _digest(section.get("sha256"))
            if "count" in section:
                raise ValueError("Unexpected raw TI2 evidence section count")
            expected = {"header": 4, "palette": 1 + colors * 2, "flags": 256, "indices": tile["stored_pixels"]}.get(name)
            if (expected is not None and size != expected) or (name == "descriptors" and size > 256 * 513):
                raise ValueError("Raw TI2 evidence section size mismatch")
            end += size
        if end != tile["decoded_bytes"]:
            raise ValueError("Raw TI2 evidence partition does not match decoded size")
    if source_inventory(tiles) != SOURCE_INVENTORY_SHA256 or manifest.get("source_inventory_sha256") != SOURCE_INVENTORY_SHA256:
        raise ValueError("Wrong current523 review source inventory")
    digest = rgba_inventory(tiles)
    if manifest.get("atlas_rgba_inventory_sha256") != digest or digest != ATLAS_RGBA_INVENTORY_SHA256:
        raise ValueError("Wrong verified candidate atlas RGBA inventory")
    if manifest.get("raw_model_inventory_sha256") != RAW_MODEL_INVENTORY_SHA256 or raw_model_inventory(tiles) != RAW_MODEL_INVENTORY_SHA256:
        raise ValueError("Wrong verified raw TI2 evidence inventory")
    if manifest.get("raw_decoded_roundtrip") is not True or manifest.get("stored_pixels") != sum(tile["stored_pixels"] for tile in tiles):
        raise ValueError("Raw TI2 aggregate evidence mismatch")
    return manifest


class _Reference:
    """Stream the independent733696-row ledger without extracting it."""
    def __init__(self, archive):
        self.zip = self.member = self.stream = None
        self.count = 0
        if archive is not None:
            h = hashlib.sha256()
            with Path(archive).open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    h.update(chunk)
            if h.hexdigest() != REFERENCE_ARCHIVE_SHA256:
                raise ValueError("Independent reference archive hash mismatch")
            self.zip = zipfile.ZipFile(archive)
            self.member = self.zip.open(REFERENCE_MEMBER)
            self.stream = gzip.GzipFile(fileobj=self.member)

    def compare(self, tile_id, row, atlas):
        if self.stream is None:
            return
        for index, block in enumerate(row["blocks"]):
            line = self.stream.readline(65537)
            if not line or len(line) > 65536:
                raise ValueError("Independent tile ledger is truncated or oversized")
            expected = json.loads(line)
            frame = atlas[(index // 16)*24:(index // 16+1)*24, (index % 16)*24:(index % 16+1)*24]
            if (expected.get("tile_id") != tile_id or expected.get("subimage") != index
                    or expected.get("flags_u8") != block["flags"] or expected.get("offset") != list(block["offset"])
                    or expected.get("raw_runs_u16") != list(block["raw_runs"])
                    or expected.get("stored_pixels") != len(block["pixels"])
                    or base64.b64decode(expected.get("pixel_indices_base64", ""), validate=True) != block["pixels"]
                    or expected.get("coverage_rgba_sha256") != sha256(frame.tobytes())):
                raise ValueError(f"Independent coverage/raw record mismatch: Tile/{tile_id}.ti2 block{index}")
            self.count += 1

    def finish(self):
        if self.stream is not None and (self.stream.read(1) or self.count != SOURCE_COUNT * 256):
            raise ValueError("Independent tile ledger inventory mismatch")

    def close(self):
        for resource in (self.stream, self.member, self.zip):
            if resource is not None:
                resource.close()


def build_pack(source_dir, source_records, output, *, reference_archive=None):
    source_dir = Path(source_dir)
    if source_dir.is_symlink() or not source_dir.is_dir():
        raise ValueError("Regular source directory containing Tile/ is required")
    source_dir = source_dir.resolve()
    output = _output_path(output, source_dir)
    records = load_source_records(source_records)
    tile_root = source_dir / "Tile"
    if tile_root.is_symlink() or not tile_root.is_dir():
        raise ValueError("Missing regular Tile/ source root")
    actual = set()
    for path in tile_root.rglob("*"):
        if path.is_symlink() or not path.is_file():
            raise ValueError("Only regular literal TI2 source members are permitted")
        relative = path.relative_to(source_dir).as_posix()
        member_id(relative)
        actual.add(relative)
    if actual != {row["member"] for row in records}:
        raise ValueError("Expected exact2866 current523 TI2 source inventory")
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix="." + output.name + ".staging-", dir=output.parent))
    stage.chmod(0o700)
    reference = None
    try:
        reference = _Reference(reference_archive)
        (stage / "originals/Tile").mkdir(parents=True, mode=0o700)
        (stage / "atlases").mkdir(mode=0o700)
        tiles = []
        total_pixels = 0
        for expected in records:
            member, tile_id = expected["member"], expected["tile_id"]
            path = _regular_child(source_dir, member)
            if path.stat().st_size != expected["source_bytes"]:
                raise ValueError("Original TI2 source size mismatch: " + member)
            with path.open("rb") as handle:
                raw = handle.read(MAX_BYTES + 1)
            if len(raw) != expected["source_bytes"] or sha256(raw) != expected["source_sha256"]:
                raise ValueError("Original TI2 source hash mismatch: " + member)
            decoded = strict_decompress(raw)
            if len(decoded) != expected["decoded_bytes"] or sha256(decoded) != expected["decoded_sha256"]:
                raise ValueError("Decoded TI2 evidence mismatch: " + member)
            row = parse_ti2(decoded)
            if write_ti2(row) != decoded or row["header"] != 4352 or len(row["blocks"]) != 256:
                raise ValueError("Raw TI2 byte roundtrip/header mismatch: " + member)
            stored = sum(len(block["pixels"]) for block in row["blocks"])
            if stored != expected["stored_pixels"] or len(row["palette_u16le"]) // 2 != expected["palette_colors"]:
                raise ValueError("Raw TI2 palette/index evidence mismatch: " + member)
            atlas = render_atlas(row)
            reference.compare(tile_id, row, atlas)
            original_path, atlas_path = "originals/" + member, f"atlases/{tile_id}.png"
            (stage / original_path).write_bytes(raw)
            (stage / original_path).chmod(0o600)
            Image.fromarray(atlas).save(stage / atlas_path, format="PNG", compress_level=4)
            (stage / atlas_path).chmod(0o600)
            png = (stage / atlas_path).read_bytes()
            with Image.open(stage / atlas_path) as image:
                if image.mode != "RGBA" or image.size != (384, 384) or image.tobytes() != atlas.tobytes():
                    raise ValueError("PNG bytes do not preserve candidate atlas RGBA")
            tiles.append({"tile_id": tile_id, "member": member, "original_path": original_path,
                "source_bytes": len(raw), "source_sha256": sha256(raw), "decoded_bytes": len(decoded),
                "decoded_sha256": sha256(decoded), "atlas_path": atlas_path, "atlas_bytes": len(png),
                "atlas_sha256": sha256(png), "atlas_rgba_sha256": sha256(atlas.tobytes()),
                "blocks": 256, "atlas_size": [384, 384], "stored_pixels": stored,
                "raw_header_u32": row["header"], "palette_colors": len(row["palette_u16le"]) // 2,
                "raw_sections": row["sections"], "palette_u16le_sha256": sha256(row["palette_u16le"]),
                "raw_decoded_roundtrip": True})
            total_pixels += stored
            if len(tiles) % 250 == 0:
                print(f"TILE_REVIEW_PROGRESS {len(tiles)}/{SOURCE_COUNT}", flush=True)
        reference.finish()
        digest = rgba_inventory(tiles)
        if digest != ATLAS_RGBA_INVENTORY_SHA256:
            raise ValueError("Candidate atlas RGBA inventory differs from verified review")
        manifest = {"schema": 1, "edition": "LineageM", "cumulative_version": 523, "land_id": 4,
            "asset_path": "Aden/", "source_root": "Tile/", "source_count": SOURCE_COUNT,
            "source_inventory_sha256": SOURCE_INVENTORY_SHA256, "source_records_sha256": SOURCE_RECORDS_SHA256,
            "atlas_rgba_inventory_sha256": digest, "status": STATUS, "semantics": dict(SEMANTICS),
            "raw_model_inventory_sha256": raw_model_inventory(tiles),
            "tiles": tiles, "stored_pixels": total_pixels, "raw_decoded_roundtrip": True,
            "delivery_status": "PRIVATE_LOCAL_ONLY", "independent_reference_frames": reference.count,
            "reference_archive_sha256": REFERENCE_ARCHIVE_SHA256 if reference.count else None}
        validate_manifest(manifest)
        manifest_path = stage / MANIFEST_NAME
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        manifest_path.chmod(0o600)
        _publish_directory(stage, output)
        stage = None
        return manifest
    finally:
        if reference is not None:
            reference.close()
        if stage is not None:
            shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--source-records", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--reference-archive", type=Path)
    args = parser.parse_args()
    try:
        manifest = build_pack(args.source_dir, args.source_records, args.output, reference_archive=args.reference_archive)
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, f"TI2 review pack failed: {error}\n")
    print(json.dumps({"output": str(args.output.resolve()), "manifest": MANIFEST_NAME,
        "tiles": len(manifest["tiles"]), "atlas_rgba_inventory_sha256": manifest["atlas_rgba_inventory_sha256"],
        "independent_reference_frames": manifest["independent_reference_frames"], "status": STATUS}))


if __name__ == "__main__":
    main()
