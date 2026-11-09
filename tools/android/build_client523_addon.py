#!/usr/bin/env python3
"""Builds a small add-on for an installed TWILIGHT 523 resource pack.

An add-on adds sections to the pack already on the phone without
reinstalling its parts. It is one ZIP picked in the same installer
("리소스 팩(.zip) 선택"). The first add-on carries the 523 map travel
definitions (world-links: Land, Portal and Territory rows per Land), which
523 play mode needs to enter and travel between Lands.

    python3 tools/map_restore/build_patch523_world_links.py \\
        --source-zip <523 tables ZIP> --output /private/world-links
    python3 tools/android/build_client523_addon.py \\
        --world-links /private/world-links --output /private/addon

The add-on holds derived original rows: keep it private like the pack.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_client523_resource_pack as pack  # noqa: E402

ADDON_SCHEMA = "twilight-client523-resource-addon-v1"
ADDON_DESCRIPTOR = "source523_addon.json"
WORLD_LINKS_SHA256 = "2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
# section -> (manifest file, required manifest SHA-256)
ADDON_SECTIONS = {"world_links": ("manifest.json", WORLD_LINKS_SHA256)}


def build(args) -> dict:
    members = []
    sections = {}
    for section, (manifest_name, pin) in ADDON_SECTIONS.items():
        root = getattr(args, section)
        if root is None:
            continue
        root = root.resolve()
        manifest = root / manifest_name
        pack.require(manifest.is_file(), f"{section}: {manifest_name} missing")
        digest = pack.sha256_file(manifest)
        pack.require(digest == pin, f"{section}: manifest SHA-256 {digest} is not the pinned {pin}")
        files = pack.walk(root)
        members.extend((f"{section}/{name}", path, size) for name, path, size in files)
        sections[section] = {"root": section, "manifest": f"{section}/{manifest_name}", "manifest_sha256": digest}
    pack.require(sections, "no add-on section given")
    listing = hashlib.sha256()
    for name, _, size in members:
        listing.update(f"{name}\0{size}\n".encode())
    descriptor = {"schema": ADDON_SCHEMA, "cumulative_version": 523, "sections": sections,
                  "members": len(members), "bytes": sum(m[2] for m in members),
                  "member_listing_sha256": listing.hexdigest()}
    descriptor["addon_id"] = hashlib.sha256(json.dumps(descriptor, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    descriptor_bytes = json.dumps(descriptor, ensure_ascii=False, indent=1, sort_keys=True).encode() + b"\n"
    out = args.output
    out.mkdir(mode=0o700)
    name = "twilight523-addon-" + "-".join(sorted(s.replace("_", "-") for s in sections)) + ".zip"
    index = {"schema": pack.PART_SCHEMA, "pack_id": descriptor["addon_id"], "part": 1, "parts": 1, "addon": True,
             "members": [[member, size] for member, _, size in members]}
    import zipfile
    with zipfile.ZipFile(out / name, "x", zipfile.ZIP_STORED, allowZip64=False, compresslevel=pack.DEFLATE_LEVEL) as archive:
        archive.writestr(pack.entry(pack.PREFIX + pack.PART_INDEX), json.dumps(index, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode())
        archive.writestr(pack.entry(pack.PREFIX + ADDON_DESCRIPTOR), descriptor_bytes)
        for member, source, size in members:
            info = pack.entry(pack.PREFIX + member, True)
            with source.open("rb") as handle, archive.open(info, "w") as target:
                for block in iter(lambda: handle.read(1 << 20), b""):
                    target.write(block)
    report = {"file": name, "bytes": (out / name).stat().st_size, "addon_id": descriptor["addon_id"],
              "members": len(members), "sections": sections}
    (out / "source523_addon_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1))
    return report


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--world-links", type=Path, help="world-links folder (manifest.json 2de8cebb...)")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    repo = Path(__file__).resolve().parents[2]
    out = args.output.resolve()
    if out == repo or repo in out.parents:
        parser.error("--output must be outside the repository")
    if out.exists():
        parser.error("--output must be a new directory")
    try:
        print(json.dumps(build(args), ensure_ascii=False, indent=1))
    except pack.PackError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
