#!/usr/bin/env python3
"""Build private generic M523 TI2 subsets from an externally pinned inventory.

The inventory uses schema1/edition LineageM/cumulative_version523 and members
{member:Tile/<id>.ti2,bytes,sha256,availability:present|missing,provenance:{
edition:LineageM,snapshot_version:523,container:Client/Data/Tile<N>.dat,selection_version,
current_selection_verified:true,expected_member_sha256,source_dat_sha256,
current_selected_dat_sha256,evidence_level}}. The complete JSON SHA is a
mandatory caller trust pin. Retained508 bytes require explicit523 selection
proof; a filename or base508 batch alone does not establish current identity.

Every included original is strictly Brotli-decoded and byte-roundtripped using
the existing raw TI2 decoder. Coverage interpretation is the same explicitly
unverified24x24/RGB565 hypothesis: stored black/white/index0 stay opaque. A
caller-pinned existing coverage pack may supply exact selected originals and
PNGs; only selected files are linked/copied, never the entire atlas inventory.
Runtime TI2 storage retains only original bytes and the verified expected RGBA
hash, so the runtime can render the same atlas without a stored PNG.
No private output can be published inside Git or replace an existing pack.
"""
import argparse
import copy
import json
import math
import os
from pathlib import Path
import re
import shutil
import tempfile

from PIL import Image

import current523_tile_review as raw_ti2
from build_current523_aden_pack import _output_path, _publish_directory, _regular_child

MANIFEST_NAME = "tilepack523.json"
KIND = "current523_ti2_subset_pack"
MAX_TILES = 20000
MAX_PNG_BYTES = 2 * 1024 * 1024
MAX_METADATA_BYTES = 64 * 1024 * 1024
ATLAS_STORAGES = ("png", "runtime_ti2")
PNG_FIELDS = ("atlas_path", "atlas_bytes", "atlas_sha256")
SEMANTICS = dict(raw_ti2.SEMANTICS)
STATUS = raw_ti2.STATUS
_CONTAINER = re.compile(r"Client/Data/Tile(?:[1-9][0-9]*)\.dat\Z")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def _json(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= MAX_METADATA_BYTES,
            "Metadata must be a bounded regular file: " + str(path))
    with path.open("rb") as handle:
        encoded = handle.read(MAX_METADATA_BYTES + 1)
    require(len(encoded) <= MAX_METADATA_BYTES, "Metadata grew beyond its bounded size")
    def pairs(values):
        result = {}
        for key, value in values:
            require(key not in result, "Duplicate JSON key")
            result[key] = value
        return result
    def constant(_value):
        raise ValueError("Non-finite JSON constant")
    def finite_number(value):
        result = float(value)
        require(math.isfinite(result), "Non-finite JSON number")
        return result
    try:
        return json.loads(encoded.decode("utf-8-sig"), object_pairs_hook=pairs,
                          parse_constant=constant, parse_float=finite_number), encoded
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("Invalid UTF-8 JSON metadata: " + str(path)) from error


def provenance_for(value, source_sha256):
    require(isinstance(value, dict), "Missing per-TI2 current523 provenance")
    require(value.get("edition") == "LineageM" and value.get("snapshot_version") == 523 and type(value.get("snapshot_version")) is int
            and value.get("current_selection_verified") is True,
            "TI2 provenance must explicitly verify current523 selection")
    raw_ti2._integer(value.get("selection_version"), "selected archive version", 523, 1)
    require(isinstance(value.get("container"), str) and _CONTAINER.fullmatch(value["container"]),
            "Invalid literal TI2 source container")
    require(isinstance(value.get("evidence_level"), str) and 1 <= len(value["evidence_level"]) <= 256,
            "Missing current523 member evidence level")
    require(raw_ti2._digest(value.get("expected_member_sha256")) == source_sha256,
            "TI2 provenance does not pin the exact current member")
    obtained_dat = raw_ti2._digest(value.get("source_dat_sha256"))
    selected_dat = raw_ti2._digest(value.get("current_selected_dat_sha256"))
    if obtained_dat != selected_dat:
        # A retained container may carry an unchanged current member. Its whole
        # DAT must remain identified as old: only the independently pinned
        # member identity qualifies it, never the archive's version label.
        proof = value.get("current_member_identity_proof")
        require(isinstance(proof, dict)
                and proof.get("kind") == "EXACT_CURRENT523_MEMBER_SHA256"
                and proof.get("member_sha256") == source_sha256
                and proof.get("current_index_sha256") != "0" * 64,
                "Retained DAT needs an explicit exact-current-member proof")
        raw_ti2._digest(proof.get("current_index_sha256"))
    # Preserve the caller-pinned original proof, including retained archive and
    # current-selection references, without inventing new source claims.
    return copy.deepcopy(value)


def load_inventory(path, expected_sha256):
    raw_ti2._digest(expected_sha256)
    inventory, encoded = _json(Path(path))
    require(raw_ti2.sha256(encoded) == expected_sha256, "Input inventory differs from caller SHA256 pin")
    require(isinstance(inventory, dict) and type(inventory.get("schema")) is int
            and inventory["schema"] == 1 and inventory.get("edition") == "LineageM"
            and type(inventory.get("cumulative_version")) is int and inventory["cumulative_version"] == 523,
            "TI2 inventory must select native M cumulative523")
    members = inventory.get("members")
    require(isinstance(members, list) and 0 < len(members) <= MAX_TILES, "Expected bounded explicit TI2 inventory")
    result = {}
    for row in members:
        require(isinstance(row, dict), "Invalid TI2 source inventory row")
        member = row.get("member")
        tile_id = raw_ti2.member_id(member)
        require(tile_id not in result, "Duplicate literal TI2 inventory member")
        size = raw_ti2._integer(row.get("bytes"), "source bytes", minimum=1)
        digest = raw_ti2._digest(row.get("sha256"))
        require(row.get("availability") in ("present", "missing"), "TI2 availability must be explicit")
        result[tile_id] = {"tile_id": tile_id, "member": member, "source_bytes": size,
            "source_sha256": digest, "availability": row["availability"],
            "provenance": provenance_for(row.get("provenance"), digest)}
    return result


def _read_bounded(path, size, digest):
    require(not path.is_symlink() and path.is_file() and path.stat().st_size == size,
            "Missing or wrong-sized original TI2: " + str(path))
    with path.open("rb") as handle:
        encoded = handle.read(raw_ti2.MAX_BYTES + 1)
    require(len(encoded) == size and raw_ti2.sha256(encoded) == digest,
            "Original TI2 differs from pinned bytes: " + str(path))
    return encoded


def render_storage_atlas(row):
    """256 storage slots, only the original physical frames are addressable."""
    count = len(row["blocks"])
    require(1 <= count <= 256, "Physical TI2 count is outside 8-bit source references")
    if count == 256:
        return raw_ti2.render_atlas(row)
    # Empty storage slots are not physical frames. The original header/model
    # stay unchanged and runtime has_subimage() rejects these unused slots.
    view = dict(row)
    view["blocks"] = list(row["blocks"]) + [
        {"flags":0,"offset":(0,0),"raw_runs":(),"pixels":b""}
        for _ in range(256-count)]
    return raw_ti2.render_atlas(view)


def _raw_metadata(decoded, row):
    return {"decoded_bytes": len(decoded), "decoded_sha256": raw_ti2.sha256(decoded),
        "blocks": len(row["blocks"]), "atlas_size": [384, 384],
        "stored_pixels": sum(len(block["pixels"]) for block in row["blocks"]),
        "raw_header_u32": row["header"], "palette_colors": len(row["palette_u16le"]) // 2,
        "raw_sections": copy.deepcopy(row["sections"]),
        "palette_u16le_sha256": raw_ti2.sha256(row["palette_u16le"]), "raw_decoded_roundtrip": True}


def _atlas_storage(manifest):
    storage = manifest.get("atlas_storage", "png")
    require(storage in ATLAS_STORAGES, "Unsupported atlas storage")
    return storage


def _row_paths(row, tile_id, storage):
    require(row.get("original_path") == "originals/" + row["member"], "Unsafe original TI2 path")
    if storage == "png":
        require(row.get("atlas_path") == f"atlases/{tile_id}.png", "Unsafe atlas PNG path")
    else:
        require(not any(key in row for key in PNG_FIELDS), "Runtime TI2 rows cannot contain stored PNG fields")


def _reuse_rows(root, expected_sha256, manifest_name="tiles523.json"):
    require(manifest_name in ("tiles523.json", MANIFEST_NAME), "Unsupported literal reuse manifest name")
    if root is None:
        require(expected_sha256 is None, "Reuse digest requires a reuse pack")
        return {}, None
    root = Path(root)
    require(not root.is_symlink() and root.is_dir(), "Expected regular reuse pack directory")
    raw_ti2._digest(expected_sha256)
    path = _regular_child(root, manifest_name)
    manifest, encoded = _json(path)
    require(raw_ti2.sha256(encoded) == expected_sha256, "Reuse manifest differs from caller SHA256 pin")
    require(isinstance(manifest, dict) and manifest.get("edition") == "LineageM"
            and type(manifest.get("cumulative_version")) is int and manifest["cumulative_version"] == 523
            and manifest.get("status") == STATUS and manifest.get("semantics") == SEMANTICS,
            "Reuse pack has a different source edition/version or coverage interpretation")
    storage = _atlas_storage(manifest)
    rows = manifest.get("tiles")
    require(isinstance(rows, list) and 0 < len(rows) <= MAX_TILES, "Invalid bounded reuse rows")
    result = {}
    for row in rows:
        require(isinstance(row, dict), "Invalid reuse row")
        tile_id = raw_ti2.member_id(row.get("member"))
        require(type(row.get("tile_id")) is int and row["tile_id"] == tile_id and tile_id not in result,
                "Duplicate or invalid reuse tile ID")
        _row_paths(row, tile_id, storage)
        result[tile_id] = row
    return result, root.resolve()


def _copy_verified(source, target, *, hardlink):
    # Never chmod a hardlink: doing so would alter the preserved source inode.
    if hardlink:
        os.link(source, target)
    else:
        shutil.copyfile(source, target)
        target.chmod(0o600)


def validate_manifest(manifest):
    require(isinstance(manifest, dict), "Invalid generic TI2 manifest")
    for key, expected in (("schema", 1), ("kind", KIND), ("edition", "LineageM"),
            ("cumulative_version", 523), ("source_root", "Tile/"), ("status", STATUS),
            ("delivery_status", "PRIVATE_LOCAL_ONLY"), ("raw_decoded_roundtrip", True)):
        require(manifest.get(key) == expected and type(manifest.get(key)) is type(expected),
                "Generic TI2 manifest identity mismatch: " + key)
    require(manifest.get("semantics") == SEMANTICS, "Unsupported coverage interpretation")
    storage = _atlas_storage(manifest)
    raw_ti2._digest(manifest.get("input_inventory_sha256"))
    raw_ti2._digest(manifest.get("input_source_inventory_sha256"))
    raw_ti2._integer(manifest.get("input_source_count"), "input count", MAX_TILES, 1)
    count = raw_ti2._integer(manifest.get("source_count"), "tile count", MAX_TILES, 1)
    require(count <= manifest["input_source_count"], "Subset exceeds input inventory")
    tiles = manifest.get("tiles")
    require(isinstance(tiles, list) and len(tiles) == count, "Invalid generic TI2 subset count")
    seen = set()
    for tile in tiles:
        require(isinstance(tile, dict), "Invalid generic TI2 row")
        tile_id = raw_ti2.member_id(tile.get("member"))
        require(type(tile.get("tile_id")) is int and tile["tile_id"] == tile_id and tile_id not in seen,
                "Duplicate or invalid generic TI2 ID")
        seen.add(tile_id)
        _row_paths(tile, tile_id, storage)
        for key in ("source_sha256", "decoded_sha256", "atlas_rgba_sha256", "palette_u16le_sha256"):
            raw_ti2._digest(tile.get(key))
        raw_ti2._integer(tile.get("source_bytes"), "source bytes", minimum=1)
        decoded = raw_ti2._integer(tile.get("decoded_bytes"), "decoded bytes", minimum=4)
        if storage == "png":
            raw_ti2._digest(tile.get("atlas_sha256"))
            raw_ti2._integer(tile.get("atlas_bytes"), "atlas bytes", MAX_PNG_BYTES, 33)
        require(type(tile.get("blocks")) is int and 1 <= tile["blocks"] <= 256 and tile.get("atlas_size") == [384, 384]
                and all(type(value) is int for value in tile["atlas_size"]), "Unsupported generic atlas layout")
        raw_ti2._integer(tile.get("stored_pixels"), "stored pixels", 256 * 576)
        raw_ti2._integer(tile.get("palette_colors"), "palette colors", 256, 1)
        header = raw_ti2._integer(tile.get("raw_header_u32"), "raw header", 0xffffffff)
        require(header & 4095 == tile["blocks"] and header & 4096 and tile.get("raw_decoded_roundtrip") is True,
                "Invalid raw header or byte roundtrip evidence")
        sections = tile.get("raw_sections")
        require(isinstance(sections, dict) and set(sections) == {"header", "palette", "flags", "descriptors", "indices"},
                "Invalid raw TI2 sections")
        end = 0
        for name in ("header", "palette", "flags", "descriptors", "indices"):
            section = sections[name]
            require(isinstance(section, dict) and raw_ti2._integer(section.get("offset"), "section offset") == end,
                    "Raw TI2 sections must be contiguous")
            end += raw_ti2._integer(section.get("bytes"), "section bytes")
            raw_ti2._digest(section.get("sha256"))
        require(end == decoded and sections["header"]["bytes"] == 4
                and sections["palette"]["bytes"] == 1 + tile["palette_colors"] * 2
                and sections["flags"]["bytes"] == tile["blocks"] and sections["indices"]["bytes"] == tile["stored_pixels"],
                "Raw TI2 section sizes disagree")
        provenance_for(tile.get("provenance"), tile["source_sha256"])
    for field, calculated in (("source_inventory_sha256", raw_ti2.source_inventory(tiles)),
            ("atlas_rgba_inventory_sha256", raw_ti2.rgba_inventory(tiles)),
            ("raw_model_inventory_sha256", raw_ti2.raw_model_inventory(tiles))):
        require(raw_ti2._digest(manifest.get(field)) == calculated, "Generic TI2 inventory mismatch: " + field)
    if count == manifest["input_source_count"]:
        require(manifest["input_source_inventory_sha256"] == manifest["source_inventory_sha256"],
                "Whole input and included source inventory identities disagree")
    return manifest


def build_pack(source_dir, inventory_path, output, *, expected_inventory_sha256,
               tile_ids=None, reuse_pack=None, expected_reuse_manifest_sha256=None,
               reuse_manifest_name="tiles523.json", hardlink_reuse=True, atlas_storage="png"):
    require(atlas_storage in ATLAS_STORAGES, "Unsupported atlas storage")
    source_dir = Path(source_dir)
    require(source_dir.is_dir() and not source_dir.is_symlink(), "Expected regular TI2 source directory")
    source_dir = source_dir.resolve()
    output = _output_path(output, source_dir)
    inventory = load_inventory(inventory_path, expected_inventory_sha256)
    selected = sorted(inventory if tile_ids is None else tile_ids)
    require(0 < len(selected) <= MAX_TILES and len(set(selected)) == len(selected), "Invalid or duplicate subset IDs")
    for tile_id in selected:
        raw_ti2._integer(tile_id, "tile ID", 0xffffff)
        require(tile_id in inventory and inventory[tile_id]["availability"] == "present", "Selected original TI2 is missing")
    reuse, reuse_root = _reuse_rows(reuse_pack, expected_reuse_manifest_sha256, reuse_manifest_name)
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix="." + output.name + ".staging-", dir=output.parent))
    stage.chmod(0o700)
    try:
        (stage / "originals/Tile").mkdir(parents=True, mode=0o700)
        if atlas_storage == "png":
            (stage / "atlases").mkdir(mode=0o700)
        tiles = []
        for tile_id in selected:
            expected = inventory[tile_id]
            member = expected["member"]
            prior = reuse.get(tile_id)
            if prior is not None:
                require(prior.get("source_bytes") == expected["source_bytes"]
                        and prior.get("source_sha256") == expected["source_sha256"], "Reuse TI2 source differs from current inventory")
            source = source_dir / member
            if source.exists() or source.is_symlink():
                source = _regular_child(source_dir, member)
            else:
                require(prior is not None, "Missing selected original TI2: " + member)
                source = _regular_child(reuse_root, prior["original_path"])
            encoded = _read_bounded(source, expected["source_bytes"], expected["source_sha256"])
            decoded = raw_ti2.strict_decompress(encoded)
            raw = raw_ti2.parse_ti2(decoded)
            require(raw_ti2.write_ti2(raw) == decoded, "Raw TI2 byte roundtrip failed")
            atlas = render_storage_atlas(raw)
            rgba_sha = raw_ti2.sha256(atlas.tobytes())
            row = {key: copy.deepcopy(expected[key]) for key in ("tile_id", "member", "source_bytes", "source_sha256", "provenance")}
            raw_metadata = _raw_metadata(decoded, raw)
            row.update(raw_metadata)
            row.update(original_path="originals/" + member)
            if atlas_storage == "png":
                row.update(atlas_path=f"atlases/{tile_id}.png")
            png_source = None
            if prior is not None:
                require(all(prior.get(key) == value for key, value in raw_metadata.items()),
                        "Reuse raw TI2 evidence differs from fresh strict decode")
                require(prior.get("atlas_rgba_sha256") == rgba_sha,
                        "Reuse atlas does not match fresh coverage interpretation")
                if "atlas_path" in prior:
                    png_source = _regular_child(reuse_root, prior["atlas_path"])
                    require(type(prior.get("atlas_bytes")) is int and 33 <= prior["atlas_bytes"] <= MAX_PNG_BYTES
                            and png_source.stat().st_size == prior["atlas_bytes"],
                            "Reuse PNG does not match fresh coverage interpretation")
                    raw_ti2.verify_atlas_png(png_source, raw_ti2._digest(prior.get("atlas_sha256")), rgba_sha)
            if atlas_storage == "png":
                if png_source is not None:
                    _copy_verified(png_source, stage / row["atlas_path"], hardlink=hardlink_reuse)
                else:
                    Image.fromarray(atlas).save(stage / row["atlas_path"], format="PNG", compress_level=4)
                    (stage / row["atlas_path"]).chmod(0o600)
            _copy_verified(source, stage / row["original_path"], hardlink=hardlink_reuse)
            _read_bounded(stage / row["original_path"], expected["source_bytes"], expected["source_sha256"])
            if atlas_storage == "png":
                png_path = stage / row["atlas_path"]
                png_sha, _ = raw_ti2.verify_atlas_png(png_path, rgba_sha256=rgba_sha)
                row.update(atlas_bytes=png_path.stat().st_size, atlas_sha256=png_sha)
            row.update(atlas_rgba_sha256=rgba_sha)
            tiles.append(row)
            if len(tiles) % 250 == 0:
                print(f"CURRENT523_TI2_PROGRESS {len(tiles)}/{len(selected)}", flush=True)
        manifest = {"schema": 1, "kind": KIND, "edition": "LineageM", "cumulative_version": 523,
            "source_root": "Tile/", "source_count": len(tiles), "input_source_count": len(inventory),
            "input_inventory_sha256": expected_inventory_sha256,
            "input_source_inventory_sha256": raw_ti2.source_inventory(list(inventory.values())),
            "source_inventory_sha256": raw_ti2.source_inventory(tiles),
            "atlas_rgba_inventory_sha256": raw_ti2.rgba_inventory(tiles), "raw_model_inventory_sha256": raw_ti2.raw_model_inventory(tiles),
            "status": STATUS, "semantics": dict(SEMANTICS), "raw_decoded_roundtrip": True,
            "tiles": tiles, "delivery_status": "PRIVATE_LOCAL_ONLY"}
        if atlas_storage == "runtime_ti2":
            manifest["atlas_storage"] = atlas_storage
        validate_manifest(manifest)
        manifest_path = stage / MANIFEST_NAME
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        manifest_path.chmod(0o600)
        _publish_directory(stage, output)
        stage = None
        return manifest
    finally:
        if stage is not None:
            shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", required=True, type=Path)
    parser.add_argument("--inventory", required=True, type=Path)
    parser.add_argument("--expected-inventory-sha256", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--tile-ids", help="Comma-separated literal tile IDs; default is the entire inventory")
    parser.add_argument("--reuse-pack", type=Path)
    parser.add_argument("--expected-reuse-manifest-sha256")
    parser.add_argument("--reuse-manifest-name", choices=("tiles523.json", MANIFEST_NAME), default="tiles523.json")
    parser.add_argument("--atlas-storage", choices=ATLAS_STORAGES, default="png",
                        help="Store PNG atlases (default), or only original TI2 bytes for runtime rendering")
    parser.add_argument("--copy-reuse", action="store_true", help="Copy instead of selectively hardlinking verified source/reused PNG files")
    args = parser.parse_args()
    try:
        ids = None if args.tile_ids is None else [int(value) for value in args.tile_ids.split(",")]
        manifest = build_pack(args.source_dir, args.inventory, args.output,
            expected_inventory_sha256=args.expected_inventory_sha256, tile_ids=ids,
            reuse_pack=args.reuse_pack, expected_reuse_manifest_sha256=args.expected_reuse_manifest_sha256,
            reuse_manifest_name=args.reuse_manifest_name,
            hardlink_reuse=not args.copy_reuse, atlas_storage=args.atlas_storage)
    except (OSError, ValueError, RuntimeError) as error:
        parser.exit(1, f"Generic current523 TI2 pack failed: {error}\n")
    print(json.dumps({"output": str(args.output.resolve()), "manifest": MANIFEST_NAME,
        "manifest_sha256": raw_ti2.sha256((args.output / MANIFEST_NAME).read_bytes()),
        "source_count": manifest["source_count"], "input_source_count": manifest["input_source_count"],
        "source_inventory_sha256": manifest["source_inventory_sha256"], "status": STATUS,
        "delivery_status": manifest["delivery_status"]}))


if __name__ == "__main__":
    main()
