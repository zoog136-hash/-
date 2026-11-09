#!/usr/bin/env python3
"""Build identity and update feed for the playtest APK's over-the-air packs.

    update_pack.py build-info --version-code N --version-name NAME --commit SHA --godot-version V
        writes res://build_info.json (shipped in the APK and in the update pack)
    update_pack.py feed --pack build/x.pck --base-url URL [--apk-url URL] --output build/update.json
        writes the feed record for scripts/boot/updater.gd and renames nothing

A pack applies only to an APK with the same compat key: the engine version,
the project settings (without the version line), the global script class
list and the updater itself. Those load before a pack can be mounted, so a
change to any of them needs a new APK.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMPAT_INPUTS = ("project.godot", ".godot/global_script_class_cache.cfg", "scripts/boot/updater.gd")


def compat_key(root: Path, godot_version: str) -> str:
    digest = hashlib.sha256()
    digest.update(b"godot\0" + godot_version.strip().encode() + b"\0")
    for name in COMPAT_INPUTS:
        path = root / name
        if not path.is_file():
            raise SystemExit(f"compat input missing: {name}")
        data = path.read_bytes()
        if name == "project.godot":
            data = re.sub(rb"(?m)^config/version=.*\n", b"", data)
        digest.update(name.encode() + b"\0" + hashlib.sha256(data).digest())
    return digest.hexdigest()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def build_info(args: argparse.Namespace) -> dict:
    if args.version_code <= 0:
        raise SystemExit("version code must be positive")
    info = {
        "schema": "twilight-build-info-v1",
        "version_code": args.version_code,
        "version_name": args.version_name,
        "commit": args.commit,
        "compat_key": compat_key(Path(args.root), args.godot_version),
    }
    (Path(args.root) / "build_info.json").write_text(json.dumps(info, indent=1) + "\n", encoding="utf-8")
    return info


def feed(args: argparse.Namespace) -> dict:
    root = Path(args.root)
    info = json.loads((root / "build_info.json").read_text(encoding="utf-8"))
    pack = Path(args.pack)
    file = f"twilight-update-{info['version_code']}.pck"
    record = {
        "schema": "twilight-update-feed-v1",
        "version_code": info["version_code"],
        "version_name": info["version_name"],
        "commit": info["commit"],
        "compat_key": info["compat_key"],
        "file": file,
        "size": pack.stat().st_size,
        "sha256": sha256(pack),
        "url": args.base_url.rstrip("/") + "/" + file,
    }
    if args.apk_url:
        record["apk_url"] = args.apk_url
    Path(args.output).write_text(json.dumps(record, indent=1) + "\n", encoding="utf-8")
    return record


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=str(ROOT))
    sub = parser.add_subparsers(dest="command", required=True)
    one = sub.add_parser("build-info")
    one.add_argument("--version-code", type=int, required=True)
    one.add_argument("--version-name", required=True)
    one.add_argument("--commit", required=True)
    one.add_argument("--godot-version", required=True)
    two = sub.add_parser("feed")
    two.add_argument("--pack", required=True)
    two.add_argument("--base-url", required=True)
    two.add_argument("--apk-url", default="")
    two.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    result = build_info(args) if args.command == "build-info" else feed(args)
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
