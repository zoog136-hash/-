#!/usr/bin/env python3
"""TWILIGHT fail-closed resource audit: source upload != Git commit != delivery.

Usage:
  python3 tools/check_resource_integrity.py
  python3 tools/check_resource_integrity.py --source-dir /path/to/uploaded/zips
  python3 tools/check_resource_integrity.py --release-dir /path/to/downloadable/pack
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import zipfile

EXPECTED = {"transform": 413, "doll": 166, "relic": 144}
EXPECTED_FRAMES = 41442
SHA256_PATTERN = re.compile(r"[0-9a-f]{64}\Z")
SOURCE_PACK_NAME = "TWILIGHT-original-resources.zip"


class AuditError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise AuditError(message)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path):
    require(path.is_file(), f"MISSING JSON: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise AuditError(f"INVALID JSON: {path}: {exc}") from exc


def safe_relative(path):
    require(isinstance(path, str) and path and "\\" not in path, f"INVALID PATH: {path!r}")
    parsed = PurePosixPath(path)
    require(not parsed.is_absolute() and not any(p in (".", "..") for p in path.split("/")),
            f"UNSAFE PATH: {path!r}")
    return parsed


def tracked_files(root):
    cmd = subprocess.run(["git", "-C", str(root), "ls-files", "-z", "--",
                          "assets/", "data/visuals/runtime_manifest.json", "data/resource_delivery_ledger.json"],
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    require(cmd.returncode == 0, f"GIT INDEX UNAVAILABLE: {cmd.stderr.decode(errors='replace')}")
    return set(x.decode("utf-8") for x in cmd.stdout.split(b"\0") if x)


def check_catalog(root, expected=None, expected_frames=EXPECTED_FRAMES):
    expected = EXPECTED if expected is None else expected
    manifest_path = "data/visuals/runtime_manifest.json"
    manifest = load_json(root / manifest_path)
    require(manifest.get("schema") == 1, "RUNTIME MANIFEST SCHEMA MISMATCH")
    catalog = manifest.get("catalog")
    require(isinstance(catalog, dict), "CATALOG IS NOT AN OBJECT")
    require(len(catalog) == sum(expected.values()), f"CATALOG COUNT WRONG: {len(catalog)}")
    tracked = tracked_files(root)
    require(manifest_path in tracked, "RUNTIME MANIFEST NOT COMMITTED")
    require("data/resource_delivery_ledger.json" in tracked, "DELIVERY LEDGER NOT COMMITTED")
    counts = dict.fromkeys(expected, 0)
    frames = 0
    catalog_paths = set()
    total_bytes = 0
    for key, entry in catalog.items():
        require(isinstance(entry, dict) and ":" in key, f"INVALID ENTRY: {key}")
        kind = key.split(":", 1)[0]
        require(kind in counts, f"UNKNOWN CATEGORY: {key}")
        counts[kind] += 1
        atlas = entry.get("atlas")
        require(isinstance(atlas, str) and atlas.startswith("res://assets/catalog_motion/")
                and atlas.endswith(".webp"), f"ATLAS PATH INVALID: {key}: {atlas}")
        relative = str(safe_relative(atlas.removeprefix("res://")))
        require(relative not in catalog_paths, f"DUPLICATE ATLAS: {relative}")
        catalog_paths.add(relative)
        source = entry.get("source")
        if isinstance(source, str) and source.startswith("res://assets/"):
            source_relative = str(safe_relative(source.removeprefix("res://")))
            require(source_relative in tracked, f"SOURCE IMAGE NOT IN GIT: {source_relative} ({key})")
            require((root / source_relative).is_file(), f"SOURCE IMAGE MISSING: {source_relative}")
        require(relative in tracked, f"ASSET NOT IN GIT (PUSH WOULD OMIT IT): {relative}")
        actual = root / relative
        require(actual.is_file(), f"MISSING ATLAS: {relative}")
        size = actual.stat().st_size
        require(size > 100, f"EMPTY OR PLACEHOLDER ATLAS: {relative}")
        with actual.open("rb") as handle:
            signature = handle.read(12)
            require(signature[:4] == b"RIFF" and signature[8:12] == b"WEBP",
                    f"BAD WEBP HEADER: {relative}")
        sha = entry.get("atlas_sha256")
        require(isinstance(sha, str) and SHA256_PATTERN.fullmatch(sha), f"MISSING HASH: {key}")
        require(sha256_file(actual) == sha, f"ATLAS HASH MISMATCH: {relative}")
        tracks = entry.get("tracks")
        require(isinstance(tracks, list) and len(tracks) > 0, f"MISSING TRACKS: {key}")
        for track in tracks:
            require(isinstance(track, dict) and isinstance(track.get("count"), int) and track["count"] > 0,
                    f"BAD FRAME COUNT: {key}")
            frames += track["count"]
        total_bytes += size
    require(counts == expected, f"CATEGORY COUNTS WRONG: {counts} != {expected}")
    require(frames == expected_frames, f"FRAME TOTAL WRONG: {frames} != {expected_frames}")
    committed_atlases = {p for p in tracked if p.startswith("assets/catalog_motion/") and p.endswith(".webp")}
    require(committed_atlases == catalog_paths,
            f"UNDECLARED/MISSING GIT ATLASES: extra={len(committed_atlases-catalog_paths)} "
            f"missing={len(catalog_paths-committed_atlases)}")
    return {"atlases": len(catalog), "frames": frames, "bytes": total_bytes, "categories": counts}


def check_ledger(root):
    ledger = load_json(root / "data/resource_delivery_ledger.json")
    require(ledger.get("schema") == 1, "DELIVERY LEDGER SCHEMA MISMATCH")
    require(ledger.get("generated_atlases", {}).get("state") == "committed_and_hashed",
            "ATLAS DELIVERY STATE INVALID")
    for category in ("original_monsters_items", "original_map_tiles", "source_archives"):
        entry = ledger.get(category)
        require(isinstance(entry, dict), f"LEDGER MISSING CATEGORY: {category}")
        state = entry.get("state")
        require(state in {"not_delivered", "session_only", "private_package_pending"},
                f"INVALID/UNPROVEN PUBLIC DELIVERY CLAIM: {category}={state!r}; "
                "bundle verification is separate")
    archives = ledger["source_archives"].get("files")
    require(isinstance(archives, list) and archives, "SOURCE INVENTORY EMPTY")
    unique = set()
    for entry in archives:
        name = entry.get("filename")
        require(isinstance(name, str) and name.endswith(".zip") and len(safe_relative(name).parts) == 1,
                f"INVALID ARCHIVE NAME: {name!r}")
        require(name not in unique, f"DUPLICATE SOURCE: {name}")
        unique.add(name)
        require(isinstance(entry.get("bytes"), int) and entry["bytes"] > 0, f"INVALID SIZE: {name}")
        require(isinstance(entry.get("sha256"), str) and SHA256_PATTERN.fullmatch(entry["sha256"]),
                f"INVALID ARCHIVE SHA: {name}")
        require(entry.get("availability") == "conversation_session_only",
                f"FALSE PERSISTENCE CLAIM: {name}")
    return ledger


def verify_source_archives(ledger, source_dir):
    total = 0
    for entry in ledger["source_archives"]["files"]:
        path = source_dir / entry["filename"]
        require(path.is_file(), f"SOURCE ZIP NOT ACCESSIBLE IN THIS ENVIRONMENT: {path}")
        require(path.stat().st_size == entry["bytes"], f"SOURCE ZIP SIZE CHANGED: {path}")
        require(sha256_file(path) == entry["sha256"], f"SOURCE ZIP HASH MISMATCH: {path}")
        try:
            with zipfile.ZipFile(path) as archive:
                require(archive.testzip() is None, f"SOURCE ZIP BAD CRC: {path}")
        except zipfile.BadZipFile as exc:
            raise AuditError(f"SOURCE ZIP INVALID: {path}: {exc}") from exc
        total += 1
    return total


def verify_release(root, release_dir):
    """Check actual offline release ZIP, SHA and CRC, not just a receipt claiming success."""
    receipt = load_json(release_dir / "resource_delivery_receipt.json")
    require(receipt.get("schema") == 1, "RELEASE RECEIPT SCHEMA INVALID")
    require(receipt.get("archive") == SOURCE_PACK_NAME, "RELEASE RECEIPT ARCHIVE NAME INVALID")
    path = release_dir / SOURCE_PACK_NAME
    require(path.is_file(), f"RELEASE PACK NOT DELIVERED: {path}")
    require(path.stat().st_size == receipt.get("bytes"), "RELEASE PACK SIZE MISMATCH")
    require(sha256_file(path) == receipt.get("sha256"), "RELEASE PACK HASH MISMATCH")
    try:
        with zipfile.ZipFile(path) as archive:
            require(archive.testzip() is None, "RELEASE PACK ZIP CRC FAILED")
            resources = [i for i in archive.infolist() if not i.is_dir() and
                         (i.filename.startswith("assets/external_l1j/") or
                          i.filename.startswith("assets/external_spx/") or
                          i.filename.startswith("assets/l1j/verified/") or
                          i.filename.startswith("data/l1j/maps/"))]
            for item in resources:
                safe_relative(item.filename)
                require(item.file_size > 0, f"EMPTY ORIGINAL FILE: {item.filename}")
            require(resources and len(resources) == receipt.get("original_file_count"),
                    "RELEASE PACK ORIGINAL RESOURCE COUNT MISMATCH/EMPTY")
    except zipfile.BadZipFile as exc:
        raise AuditError(f"RELEASE ZIP INVALID: {exc}") from exc
    return len(resources)


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    p.add_argument("--source-dir", type=Path)
    p.add_argument("--release-dir", type=Path)
    args = p.parse_args(argv)
    try:
        root = args.root.resolve()
        summary = check_catalog(root)
        ledger = check_ledger(root)
        print("RESOURCE_SOURCE_CHECKOUT_OK", json.dumps(summary, ensure_ascii=False), flush=True)
        print("RESOURCE_ORIGINALS_NOT_IN_PUBLIC_REPO: session upload != distributed assets", flush=True)
        if args.source_dir:
            count = verify_source_archives(ledger, args.source_dir.resolve())
            print(f"SOURCE_ARCHIVES_VERIFIED {count} ZIP files; NOT proof of repo inclusion/delivery", flush=True)
        if args.release_dir:
            count = verify_release(root, args.release_dir.resolve())
            print(f"RESOURCE_PRIVATE_RELEASE_VERIFIED {count} original files in distributable ZIP", flush=True)
        return 0
    except AuditError as exc:
        print("RESOURCE_INTEGRITY_FAILED:", exc, file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
