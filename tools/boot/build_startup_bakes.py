#!/usr/bin/env python3
"""Package verified outputs of an isolated TWILIGHT startup. No source ZIPs or saves."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

SCHEMA = "twilight.current523.startup-bakes.v1"
BAKE_SCHEMA = "twilight.current523.bake.v1"
INDEX = "startup_bakes.json"
CHUNK = 1024 * 1024
MAX_INDEX = 256 * 1024
MAX_PAYLOAD = 1536 * 1024 * 1024
MAX_FILES = 700
HEX = re.compile(r"[a-f0-9]{64}")
NAME = re.compile(r"(?:definitions_|disk_|current523_source_pack_|current523_tile_pack_|original_ui_pack_)[a-zA-Z_0-9]+")
MODELS = {
    "card_slot_relic523_records", "content523_models", "equipment_rules",
    "equipment_rules_catalog_records", "equipment_rules_cold", "equipment_rules_runtime",
    "expedition523_records", "monsterbook523_payload", "monsterbook523_stored_rows",
    "native_item_templates", "option_combat523_records", "player_original_profiles523", "protection523_original",
    "quest523_payload", "quest523_records", "quest_startup_rewards523", "relic_spell_levels", "shop_skill_book_contracts523",
    "source523_image_pack", "source523_shop_input", "source523_ticket_model", "source_dungeon_candidate",
    "sp2_manifest_actors", "sp2_manifest_members", "sp2_manifest_top", "world_initial_item_weights",
}
REQUIRED = {
    "native_item_templates", "equipment_rules", "equipment_rules_catalog_records",
    "equipment_rules_runtime", "source523_image_pack", "card_slot_relic523_records",
    "world_initial_item_weights", "player_original_profiles523", "quest_startup_rewards523",
}


def collect(cache):
    entries = {}
    for path in sorted(cache.glob("*.json")):
        name = path.stem
        if name not in MODELS and not NAME.fullmatch(name):
            continue
        if path.is_symlink() or path.stat().st_size > 4096:
            raise ValueError(f"invalid bake pointer: {name}")
        meta = json.loads(path.read_bytes())
        key, digest, length = (meta.get(field) for field in ("key", "sha256", "bytes"))
        generation = meta.get("file", name + ".bin")
        if (meta.get("schema") != BAKE_SCHEMA or not isinstance(key, str) or not HEX.fullmatch(key)
                or not isinstance(digest, str) or not HEX.fullmatch(digest) or type(length) is not int or length <= 0
                or not isinstance(generation, str)
                or not re.fullmatch(re.escape(name) + r"(?:\.g[a-f0-9]{16})?\.bin", generation)):
            raise ValueError(f"invalid bake metadata: {name}")
        data = cache / generation
        if data.is_symlink() or not data.is_file() or data.stat().st_size != length:
            raise ValueError(f"incomplete bake: {name}")
        entries[name] = ({"key": key, "bytes": length, "sha256": digest}, data)
    if not REQUIRED.issubset(entries):
        raise ValueError(f"incomplete original startup: {', '.join(sorted(REQUIRED - entries.keys()))}")
    if len(entries) > MAX_FILES or sum(meta["bytes"] for meta, _ in entries.values()) > MAX_PAYLOAD:
        raise ValueError("startup bakes exceed the installer limits")
    return entries


def build(cache, output):
    entries = collect(cache)
    output.mkdir(mode=0o700, parents=True)
    manifest = json.dumps({"schema": SCHEMA, "files": {name: row[0] for name, row in entries.items()}},
                          sort_keys=True, separators=(",", ":")).encode()
    if len(manifest) > MAX_INDEX:
        raise ValueError("startup index exceeds the installer limit")
    path = output / "twilight523-startup-bakes.zip"
    with zipfile.ZipFile(path, "x", zipfile.ZIP_DEFLATED, compresslevel=3, allowZip64=False) as zip_file:
        index = zipfile.ZipInfo(INDEX)
        index.compress_type = zipfile.ZIP_DEFLATED
        zip_file.writestr(index, manifest)
        for name, (meta, source) in entries.items():
            sha = hashlib.sha256()
            length = 0
            with source.open("rb") as stream:
                for i, chunk in enumerate(iter(lambda: stream.read(CHUNK), b"")):
                    member = zipfile.ZipInfo(f"data/{name}/{i}")
                    member.compress_type = zipfile.ZIP_DEFLATED
                    zip_file.writestr(member, chunk, compresslevel=3)
                    sha.update(chunk)
                    length += len(chunk)
            if length != meta["bytes"] or sha.hexdigest() != meta["sha256"]:
                raise ValueError(f"bake changed or damaged while packaging: {name}")
    with zipfile.ZipFile(path) as zip_file:
        if zip_file.testzip() is not None:
            raise ValueError("packed startup archive failed CRC")
    with path.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    pin = {"archive_sha256": digest, "index_sha256": hashlib.sha256(manifest).hexdigest(),
           "archive_bytes": path.stat().st_size}
    (output / "startup_bake_pin.json").write_text(json.dumps(pin, indent=2) + "\n")
    return {"files": len(entries), "uncompressed_bytes": sum(meta["bytes"] for meta, _ in entries.values()), **pin}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
        parser.error("write the private package outside the game repository")
    print(json.dumps(build(args.cache.resolve(), args.output.resolve()), indent=2))


if __name__ == "__main__":
    main()
