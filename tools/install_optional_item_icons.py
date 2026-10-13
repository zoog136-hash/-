#!/usr/bin/env python3
"""Install the 15 optional item PNGs from a user-owned ZIP, without changing DB."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import zipfile

MANIFEST = Path("data/optional_item_icons_15.json")
DEST = Path("assets/original_items/inventory")
PNG_HEADER = b"\x89PNG\r\n\x1a\n"

def sha256(data):
    return hashlib.sha256(data).hexdigest()

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", type=Path, default=Path("."), help="TWILIGHT project root")
    ap.add_argument("--source", type=Path, help="local immma2004.zip; required unless --verify")
    ap.add_argument("--verify", action="store_true", help="read-only check of all installed PNGs")
    args = ap.parse_args(argv)
    root = args.root.resolve()
    if not (root / "project.godot").is_file():
        ap.error("--root must contain TWILIGHT project.godot")
    manifest = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
    rows = manifest["items"]
    if len(rows) != 15 or len({x["name"] for x in rows}) != 15:
        raise ValueError("Expected 15 unique manifest rows")
    if not args.verify and args.source is None:
        ap.error("--source is required for installation")
    changed = 0
    unchanged = 0
    source = None
    try:
        if not args.verify:
            source = zipfile.ZipFile(args.source)
            bad = source.testzip()
            if bad:
                raise ValueError("Corrupt ZIP member: " + bad)
        for row in rows:
            icon_id = int(row["icon_id"])
            if icon_id <= 0 or row["slot"] != "consumable":
                raise ValueError("Invalid manifest entry")
            expected = row["sha256"].lower()
            if len(expected) != 64 or any(c not in "0123456789abcdef" for c in expected):
                raise ValueError("Invalid SHA-256 for " + row["name"])
            path = root / DEST / f"{icon_id}.png"
            if path.exists():
                if sha256(path.read_bytes()) != expected:
                    raise ValueError(f"Refusing to overwrite different existing art: {path}")
                unchanged += 1
                continue
            if args.verify:
                raise FileNotFoundError(f"Private icon not installed: {path}")
            data = source.read(f"img/item/{icon_id}.png")
            if not data.startswith(PNG_HEADER) or len(data) < 24:
                raise ValueError(f"Invalid PNG data for {icon_id}")
            if (int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")) != (128, 128):
                raise ValueError(f"Unexpected PNG dimensions: {icon_id}")
            if sha256(data) != expected:
                raise ValueError(f"SHA-256 mismatch: {icon_id}")
            path.parent.mkdir(parents=True, exist_ok=True)
            temp = path.with_suffix(".png.part")
            try:
                with temp.open("xb") as stream:
                    stream.write(data)
                os.replace(temp, path)
            finally:
                temp.unlink(missing_ok=True)
            changed += 1
    finally:
        if source is not None:
            source.close()
    print(json.dumps({"installed": changed, "already_present": unchanged,
        "validated": len(rows), "source": "local private ZIP" if not args.verify else "installed files",
        "public_repository_png_commits": 0}, ensure_ascii=False))
    return 0

if __name__ == "__main__":
    sys.exit(main())
