#!/usr/bin/env python3
"""Compare independently built startup bakes from two compiled releases.

Use cache directories from independently verified compiled releases with
--device-caches. To support an installed seed, supply the sealed outputs of
build_startup_bakes.py instead. Provide the source identities recorded by the
runs. Include the resulting JSON in the new release, beside the existing pin.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile

from build_startup_bakes import HEX, INDEX, MAX_FILES, MAX_INDEX, MAX_PAYLOAD, SCHEMA, collect

REUSE_SCHEMA = "twilight.current523.startup-bake-reuse.v1"
IDENTIFIER = re.compile(r"[a-zA-Z_][a-zA-Z_0-9]{0,179}")


def read_pinned_bundle(directory):
    pin = json.loads((directory / "startup_bake_pin.json").read_bytes())
    archive = directory / "twilight523-startup-bakes.zip"
    if (not isinstance(pin, dict) or type(pin.get("archive_bytes")) is not int
            or not 0 < pin["archive_bytes"] <= MAX_PAYLOAD
            or archive.stat().st_size != pin["archive_bytes"]):
        raise ValueError("startup archive size does not match the pin")
    with archive.open("rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != pin.get("archive_sha256"):
            raise ValueError("startup archive SHA-256 does not match the pin")
    with zipfile.ZipFile(archive) as bundle:
        indices = [info for info in bundle.infolist() if info.filename == INDEX]
        if len(indices) != 1 or not 0 < indices[0].file_size <= MAX_INDEX:
            raise ValueError("invalid startup archive index")
        raw_index = bundle.read(indices[0])
    index_sha = hashlib.sha256(raw_index).hexdigest()
    if index_sha != pin.get("index_sha256"):
        raise ValueError("startup index SHA-256 does not match the pin")
    index = json.loads(raw_index)
    files = index.get("files") if isinstance(index, dict) else None
    if not isinstance(files, dict) or not 0 < len(files) <= MAX_FILES or index.get("schema") != SCHEMA:
        raise ValueError("invalid startup archive manifest")
    total = 0
    for name, meta in files.items():
        if not IDENTIFIER.fullmatch(name) or not isinstance(meta, dict):
            raise ValueError("invalid startup archive entry")
        if not all(isinstance(meta.get(field), str) and HEX.fullmatch(meta[field])
                   for field in ("key", "sha256")):
            raise ValueError("invalid startup archive entry digest")
        if type(meta.get("bytes")) is not int or not 0 < meta["bytes"] <= MAX_PAYLOAD:
            raise ValueError("invalid startup archive entry size")
        total += meta["bytes"]
    if total > MAX_PAYLOAD:
        raise ValueError("startup archive payload exceeds the installer limit")
    return index_sha, files


def read_verified_cache(directory):
    entries = collect(directory)
    for name, (meta, payload) in entries.items():
        with payload.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        if digest != meta["sha256"] or payload.stat().st_size != meta["bytes"]:
            raise ValueError(f"device cache bytes do not match the verified metadata: {name}")
    return {name: meta for name, (meta, _) in entries.items()}


def build(previous, current, previous_source, current_source, engine, *, device_caches=False):
    if not HEX.fullmatch(current_source) or current_source != previous_source:
        raise ValueError("verified original inputs differ between the builds")
    if not engine or "|" not in engine:
        raise ValueError("the compiled game's engine identity is required")
    if device_caches:
        old_index = ""
        old_files, new_files = read_verified_cache(previous), read_verified_cache(current)
    else:
        old_index, old_files = read_pinned_bundle(previous)
        _, new_files = read_pinned_bundle(current)
    reuse = {}
    for name, new in sorted(new_files.items()):
        old = old_files.get(name)
        if (old is not None and old["key"] != new["key"]
                and old["sha256"] == new["sha256"] and old["bytes"] == new["bytes"]):
            reuse[name] = {"previous_key": old["key"], "key": new["key"],
                           "sha256": new["sha256"], "bytes": new["bytes"]}
    return {"schema": REUSE_SCHEMA, "index_sha256": old_index, "source": current_source,
            "engine": engine, "files": reuse}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device-caches", action="store_true",
                        help="Read and hash current523_bake directories. Authorize device caches only.")
    parser.add_argument("--previous", type=Path, required=True)
    parser.add_argument("--current", type=Path, required=True)
    parser.add_argument("--previous-source", required=True)
    parser.add_argument("--current-source", required=True)
    parser.add_argument("--engine", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    proof = build(args.previous, args.current, args.previous_source, args.current_source, args.engine,
                  device_caches=args.device_caches)
    encoded = json.dumps(proof, sort_keys=True, separators=(",", ":")).encode()
    if len(encoded) > MAX_INDEX:
        raise ValueError("startup reuse proof exceeds the game limit")
    with args.output.open("xb") as out:
        out.write(encoded)
    print(json.dumps({"reusable_files": len(proof["files"]), "sha256": hashlib.sha256(encoded).hexdigest()}))


if __name__ == "__main__":
    main()
