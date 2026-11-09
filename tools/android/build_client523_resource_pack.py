#!/usr/bin/env python3
"""Pack the private 523 resource builds into ZIP parts for the Android APK.

Git and the APK carry code only. The user's own client resources are built
outside the repository (tables ZIP, SP2 bank, image pack, map and tile packs,
optionally the original UI pack and the CSB icon selection). This tool puts
those finished private directories, unchanged, into ZIP parts that the APK
installs from the phone's storage (scripts/boot/source523_pack.gd):

* every entry sits under `source523/`; every part starts with
  `source523_part.json` (pack ID, part number, members with their byte sizes);
  part 1 also holds `source523_pack.json`, the descriptor with the relative
  roots and the SHA-256 pins of every pack manifest;
* parts stay below 2 GB (default) and 65,535 entries, so no ZIP64 reader is
  needed;
* text members (mostly the bank's per-action JSON) are deflated, everything
  else is stored; extraction restores the exact bytes, nothing is renamed or
  regenerated, and each runtime reader still checks its own pins.

Output goes to a new private directory outside the repository. Nothing is
uploaded.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import sys
import zipfile
import zlib

SCHEMA = "twilight-client523-resource-pack-v1"
PART_SCHEMA = "twilight-client523-resource-pack-part-v1"
TABLES_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
TABLES_BYTES = 25031173
DESCRIPTOR = "source523_pack.json"
PART_INDEX = "source523_part.json"
# Every entry sits under this folder: the APK mounts a part as a resource pack
# and reads res://source523/<member>. The part index is the first entry and the
# descriptor the second, so a ZIP reader finds them without scanning.
PREFIX = "source523/"
DATE = (2026, 1, 1, 0, 0, 0)
MAX_PART_BYTES = 1_900_000_000
DEFLATE_LEVEL = 6
DESCRIPTOR_RESERVE = 1 << 20
TEXT_SUFFIXES = {".json", ".jsonl", ".txt", ".cfg", ".csv", ".xml", ".plist", ".spr"}
MAX_PART_ENTRIES = 60_000

# Pack directory -> (name inside the pack, manifest file, expected kind check)
SECTIONS = (
    ("bank", "manifest.json"),
    ("images", "manifest.json"),
    ("maps", "source523.json"),
    ("tiles", "tilepack523.json"),
    ("ui", "original_ui.json"),
    ("ui_icons", "icon-selection.json"),
    ("world_links", "manifest.json"),
)
OPTIONAL = {"ui", "ui_icons", "world_links"}
# 523 map travel definitions (tools/map_restore/build_patch523_world_links.py).
WORLD_LINKS_SHA256 = "2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"


class PackError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise PackError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def manifest_checks(section: str, document: dict):
    if section == "bank":
        require(document.get("kind") == "current523_reference_sp2_action_bank", "bank manifest kind differs")
    elif section == "maps":
        require(document.get("kind") == "current523_s32_source_pack" and document.get("cumulative_version") == 523,
                "map manifest is not the current523 S32 source pack")
    elif section == "ui":
        require(document.get("schema") == "twilight-original-ui-v1", "UI manifest schema differs")
        require(document.get("blockers") == [], "UI pack still has unresolved inputs")
    elif section == "ui_icons":
        require(document.get("schema") == "source523-original-ui-icon-selection-v1", "icon selection schema differs")
        packs = document.get("packs")
        require(isinstance(packs, list) and packs and all(
            isinstance(p, dict) and isinstance(p.get("root"), str) and not p["root"].startswith("/") and ".." not in p["root"].split("/")
            for p in packs), "icon selection packs must be relative to the selection folder")


def walk(root: Path):
    """Regular files under root, sorted, as (relative posix name, path, bytes)."""
    found = []
    for directory, dirs, files in os.walk(root):
        dirs.sort()
        for name in sorted(files):
            path = Path(directory) / name
            require(not path.is_symlink(), f"symlink in private pack: {path}")
            relative = path.relative_to(root).as_posix()
            require(not relative.startswith("."), f"hidden file in private pack: {relative}")
            found.append((relative, path, path.stat().st_size))
    return found


def collect(args):
    tables = args.tables.resolve()
    require(tables.stat().st_size == TABLES_BYTES and sha256_file(tables) == TABLES_SHA256,
            "tables ZIP is not the runtime-pinned 523 tables ZIP")
    members = [("tables/source.zip", tables, TABLES_BYTES)]
    descriptor = {"schema": SCHEMA, "cumulative_version": 523,
                  "tables": {"path": "tables/source.zip", "sha256": TABLES_SHA256},
                  "start_land_id": args.start_land}
    for section, manifest_name in SECTIONS:
        root = getattr(args, section)
        if root is None:
            require(section in OPTIONAL, f"--{section.replace('_', '-')} is required")
            continue
        root = root.resolve()
        manifest = root / manifest_name
        require(manifest.is_file(), f"{section}: {manifest_name} missing")
        manifest_checks(section, json.loads(manifest.read_text(encoding="utf-8-sig")))
        if section == "world_links":
            require(sha256_file(manifest) == WORLD_LINKS_SHA256, "world-links manifest is not the pinned 523 definition pack")
        files = walk(root)
        require(any(name == manifest_name for name, _, _ in files), f"{section}: manifest not under root")
        members.extend((f"{section}/{name}", path, size) for name, path, size in files)
        descriptor[section] = {"root": section, "manifest": f"{section}/{manifest_name}",
                               "manifest_sha256": sha256_file(manifest)}
    names = [name for name, _, _ in members]
    require(len(names) == len(set(names)), "duplicate member names")
    return descriptor, members


def deflated(name: str) -> bool:
    """Text members (the bank's per-action JSON is most of them) are deflated;
    SP2, images, maps and ZIPs are already compressed and stay stored."""
    return PurePosixPath(name).suffix.lower() in TEXT_SUFFIXES


def packed_size(name: str, source: Path, size: int) -> int:
    """Bytes the member occupies in a part, as zipfile will write it."""
    if not deflated(name):
        return size
    compressor = zlib.compressobj(DEFLATE_LEVEL, zlib.DEFLATED, -15)
    total = 0
    with source.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            total += len(compressor.compress(block))
    return total + len(compressor.flush())


def plan_parts(members, max_bytes, max_entries):
    """Members are (name, path, bytes, packed bytes); order is kept."""
    parts, current, size = [], [], 0
    for member in members:
        require(member[3] < max_bytes, f"member larger than a part: {member[0]}")
        if current and (size + member[3] + DESCRIPTOR_RESERVE > max_bytes or len(current) + 2 >= max_entries):
            parts.append(current)
            current, size = [], 0
        current.append(member)
        # local and central headers, plus the member's row in the part index
        size += member[3] + 128 + len(member[0].encode()) * 3 + 32
    if current:
        parts.append(current)
    return parts


def entry(name: str, compress: bool = False) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, DATE)
    info.compress_type = zipfile.ZIP_DEFLATED if compress else zipfile.ZIP_STORED
    info.external_attr = 0o600 << 16
    return info


def write_part(path: Path, index: dict, members, descriptor_bytes=None):
    with zipfile.ZipFile(path, "x", zipfile.ZIP_STORED, allowZip64=False, compresslevel=DEFLATE_LEVEL) as archive:
        archive.writestr(entry(PREFIX + PART_INDEX), json.dumps(index, ensure_ascii=False, sort_keys=True,
                                                       separators=(",", ":")).encode())
        if descriptor_bytes is not None:
            archive.writestr(entry(PREFIX + DESCRIPTOR), descriptor_bytes)
        for name, source, size, _ in members:
            require(source.stat().st_size == size, f"changed while packing: {source}")
            info = entry(PREFIX + name, deflated(name))
            with source.open("rb") as handle, archive.open(info, "w") as target:
                for block in iter(lambda: handle.read(1 << 20), b""):
                    target.write(block)


def build(args):
    descriptor, members = collect(args)
    members = [(name, path, size, packed_size(name, path, size)) for name, path, size in members]
    parts = plan_parts(members, args.part_bytes, args.part_entries)
    listing = hashlib.sha256()
    for name, _, size, _ in members:
        listing.update(f"{name}\0{size}\n".encode())
    descriptor["members"] = len(members)
    descriptor["bytes"] = sum(member[2] for member in members)
    descriptor["parts"] = len(parts)
    descriptor["member_listing_sha256"] = listing.hexdigest()
    pin_basis = json.dumps(descriptor, sort_keys=True, separators=(",", ":")).encode()
    descriptor["pack_id"] = hashlib.sha256(pin_basis).hexdigest()
    descriptor_bytes = json.dumps(descriptor, ensure_ascii=False, indent=1, sort_keys=True).encode() + b"\n"
    out = args.output
    out.mkdir(mode=0o700)
    written = []
    selected = set(args.write_parts or range(1, len(parts) + 1))
    require(selected <= set(range(1, len(parts) + 1)), f"--write-parts outside 1..{len(parts)}")
    for number, chunk in enumerate(parts, 1):
        name = f"twilight523-resources-{number}of{len(parts)}.zip"
        if number not in selected:
            written.append({"file": name, "members": len(chunk), "written": False})
            continue
        index = {"schema": PART_SCHEMA, "pack_id": descriptor["pack_id"], "part": number, "parts": len(parts),
                 "members": [[name, size] for name, _, size, _ in chunk]}
        write_part(out / name, index, chunk, descriptor_bytes if number == 1 else None)
        written.append({"file": name, "members": len(chunk), "bytes": (out / name).stat().st_size})
    report = {"pack_id": descriptor["pack_id"], "members": descriptor["members"], "bytes": descriptor["bytes"],
              "parts": written, "descriptor": {k: v for k, v in descriptor.items() if isinstance(v, dict)}}
    (out / "source523_pack_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1))
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--tables", type=Path, required=True, help="runtime-pinned 523 tables ZIP (d5192c3c...)")
    parser.add_argument("--bank", type=Path, required=True, help="SP2 bank directory (manifest.json)")
    parser.add_argument("--images", type=Path, required=True, help="source523 image pack directory (manifest.json)")
    parser.add_argument("--maps", type=Path, required=True, help="current523 S32 source pack (source523.json)")
    parser.add_argument("--tiles", type=Path, required=True, help="current523 tile pack (tilepack523.json)")
    parser.add_argument("--ui", type=Path, help="original UI pack (original_ui.json), optional")
    parser.add_argument("--ui-icons", type=Path,
                        help="folder with icon-selection.json and the CSB icon pack it names, optional")
    parser.add_argument("--world-links", type=Path,
                        help="523 map travel definitions (manifest.json 2de8cebb...), optional")
    parser.add_argument("--start-land", type=int, default=4, help="Land ID entered on a fresh install (4 = Aden)")
    parser.add_argument("--part-bytes", type=int, default=MAX_PART_BYTES)
    parser.add_argument("--part-entries", type=int, default=MAX_PART_ENTRIES)
    parser.add_argument("--write-parts", type=lambda v: [int(x) for x in v.split(",") if x],
                        help="write only these part numbers (e.g. 2,3); the plan and pack ID stay the same, "
                             "so parts written in separate runs belong to one pack")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[2]
    out = args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error("--output must be outside the repository")
    if out.exists():
        parser.error("--output must be a new directory")
    if not 0 < args.part_bytes <= 4_000_000_000 or not 3 <= args.part_entries <= 65_000:
        parser.error("parts must stay below 4 GB and 65,535 entries")
    try:
        print(json.dumps(build(args), ensure_ascii=False, indent=1))
    except PackError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
