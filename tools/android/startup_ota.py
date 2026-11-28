#!/usr/bin/env python3
"""Package an optional, independently verified startup-cache proof in an OTA."""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
from tempfile import TemporaryDirectory

from update_pack import ROOT, sha256

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "boot"))
from build_startup_bake_reuse import IDENTIFIER, REUSE_SCHEMA, build
from build_startup_bakes import HEX, MAX_FILES, MAX_INDEX, MAX_PAYLOAD

PROOF = "startup_bake_reuse.json"
BUILD_INFO = "build_info.json"
PROJECT = "project.binary"
PIN = "startup_bake_pin.json"
DEFAULT_TICKET = "tools/android/startup_ota_ticket.json"
SCHEMA = "twilight.startup-ota-ticket.v1"
PACK_HEADER = struct.Struct("<4s5I2Q")
PACK_ENTRY = struct.Struct("<2Q16sI")
INT32 = struct.Struct("<I")
BUILD_FIELDS = ("version_code", "version_name", "commit", "compat_key")


@dataclass
class Pack:
    members: dict[str, tuple[int, str]]
    metadata: dict[str, bytes]


def encode(value) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def is_sha(value) -> bool:
    return isinstance(value, str) and HEX.fullmatch(value) is not None


def read_exact(stream, size: int) -> bytes:
    data = stream.read(size)
    if len(data) != size:
        raise ValueError("truncated Godot PCK")
    return data


def read_pack(path: Path) -> Pack:
    """Read unencrypted, standalone Godot 4.7.2 AndroidUpdatePack v4 members."""
    members = {}
    metadata = {}
    with path.open("rb") as stream:
        length = stream.seek(0, os.SEEK_END)
        stream.seek(0)
        header = PACK_HEADER.unpack(read_exact(stream, PACK_HEADER.size))
        magic, version, major, minor, patch, flags, base, directory = header
        if (magic, version, major, minor, patch, flags) != (b"GDPC", 4, 4, 7, 2, 2):
            raise ValueError("unsupported AndroidUpdatePack format")
        if not PACK_HEADER.size <= base <= directory <= length - INT32.size:
            raise ValueError("invalid Godot PCK directory offset")
        stream.seek(directory)
        count, = INT32.unpack(read_exact(stream, INT32.size))
        if not 0 < count <= 100_000 or count > (length - stream.tell()) // (PACK_ENTRY.size + 5):
            raise ValueError("invalid Godot PCK member count")
        for _ in range(count):
            name_size, = INT32.unpack(read_exact(stream, INT32.size))
            if not 0 < name_size <= 4096:
                raise ValueError("invalid Godot PCK member name length")
            name = read_exact(stream, name_size).rstrip(b"\0").decode("utf-8")
            invalid_path = any(part in ("", ".", "..") for part in name.split("/"))
            if invalid_path or "\0" in name or "\\" in name or name in members:
                raise ValueError("invalid or duplicate Godot PCK member name")
            offset, size, expected, file_flags = PACK_ENTRY.unpack(read_exact(stream, PACK_ENTRY.size))
            if file_flags or base + offset + size > directory:
                raise ValueError(f"invalid Godot PCK member extent: {name}")
            cursor = stream.tell()
            stream.seek(base + offset)
            sha = hashlib.sha256()
            md5 = hashlib.md5(usedforsecurity=False)
            save_bytes = name in {BUILD_INFO, PIN, PROOF}
            if save_bytes and size > MAX_INDEX:
                raise ValueError(f"oversized Godot PCK metadata: {name}")
            selected = bytearray() if save_bytes else None
            remaining = size
            while remaining:
                block = read_exact(stream, min(remaining, 1024 * 1024))
                sha.update(block)
                md5.update(block)
                if selected is not None:
                    selected.extend(block)
                remaining -= len(block)
            if md5.digest() != expected:
                raise ValueError(f"corrupt Godot PCK member: {name}")
            members[name] = (size, sha.hexdigest())
            if selected is not None:
                metadata[name] = bytes(selected)
            stream.seek(cursor)
    return Pack(members, metadata)


def build_fields(value: dict) -> dict:
    if not isinstance(value, dict):
        raise ValueError("invalid build metadata")
    if type(value.get("version_code")) is not int or value["version_code"] <= 0:
        raise ValueError("invalid build version")
    if not isinstance(value.get("version_name"), str) or not value["version_name"]:
        raise ValueError("invalid version label")
    if not isinstance(value.get("commit"), str) or not re.fullmatch(r"[a-f0-9]{40}", value["commit"]):
        raise ValueError("invalid build commit")
    if not is_sha(value.get("compat_key")):
        raise ValueError("invalid build compatibility key")
    return {name: value[name] for name in BUILD_FIELDS}


def pack_build(pack: Pack) -> dict:
    value = json.loads(pack.metadata.get(BUILD_INFO, b"null"))
    if not isinstance(value, dict) or value.get("schema") != "twilight-build-info-v1":
        raise ValueError("PCK missing a valid build_info.json")
    return build_fields(value)


def runtime_identity(pack: Pack) -> dict:
    if pack.members.keys() & {PROOF, DEFAULT_TICKET} or not {PROJECT, PIN} <= pack.members.keys():
        raise ValueError("plain PCK must have its project and seed pin and no startup proof")
    # build-info is stamped per release. The existing compat key binds the
    # unstamped project configuration, engine, updater and classes.
    runtime = {name: pack.members[name] for name in pack.members if name not in {BUILD_INFO, PROJECT}}
    return {"compat_key": pack_build(pack)["compat_key"], "content_sha256": digest(encode(runtime))}


def official_identity(feed_path: Path, pck_path: Path) -> dict:
    feed = json.loads(feed_path.read_bytes())
    if not isinstance(feed, dict) or feed.get("schema") != "twilight-update-feed-v1":
        raise ValueError("invalid previous release feed")
    info = build_fields(feed)
    if (info["version_name"] != f"523.{info['version_code']}" or type(feed.get("size")) is not int
            or feed["size"] != pck_path.stat().st_size or not is_sha(feed.get("sha256"))
            or feed["sha256"] != sha256(pck_path)):
        raise ValueError("previous PCK does not match the official feed")
    if pack_build(read_pack(pck_path)) != info:
        raise ValueError("previous PCK build identity does not match the feed")
    return {**info, "pck_sha256": feed["sha256"]}


def proof_bytes(proof) -> bytes:
    if (not isinstance(proof, dict) or set(proof) != {"schema", "source", "engine", "index_sha256", "files"}
            or proof["schema"] != REUSE_SCHEMA or proof["index_sha256"] != "" or not is_sha(proof["source"])):
        raise ValueError("invalid device-cache proof schema or source")
    if not isinstance(proof["engine"], str) or not re.fullmatch(r"4\.7\.2[^|]+\|[a-f0-9]{40}", proof["engine"]):
        raise ValueError("invalid proof engine identity")
    rows = proof["files"]
    if not isinstance(rows, dict) or not 0 < len(rows) <= MAX_FILES:
        raise ValueError("invalid startup proof row count")
    total = 0
    for name, row in rows.items():
        if (not IDENTIFIER.fullmatch(name) or not isinstance(row, dict)
                or set(row) != {"previous_key", "key", "sha256", "bytes"}
                or not all(is_sha(row[field]) for field in ("previous_key", "key", "sha256"))
                or row["previous_key"] == row["key"]
                or type(row["bytes"]) is not int or not 0 < row["bytes"] <= MAX_PAYLOAD):
            raise ValueError(f"invalid startup proof row: {name}")
        total += row["bytes"]
    data = encode(proof)
    if total > MAX_PAYLOAD or len(data) > MAX_INDEX:
        raise ValueError("startup proof exceeds game bounds")
    return data


def validate_ticket(ticket, plain: Pack) -> bytes:
    if not isinstance(ticket, dict) or ticket.get("schema") != SCHEMA:
        raise ValueError("invalid startup OTA ticket")
    previous = build_fields(ticket.get("previous"))
    if not is_sha(ticket["previous"].get("pck_sha256")) or previous["version_name"] != f"523.{previous['version_code']}":
        raise ValueError("invalid ticket previous release identity")
    candidate = pack_build(plain)
    if candidate["version_code"] <= previous["version_code"] or candidate["compat_key"] != previous["compat_key"]:
        raise ValueError("ticket does not target a compatible newer OTA")
    if runtime_identity(plain) != ticket.get("candidate"):
        raise ValueError("candidate PCK contents differ from the verified ticket")
    raw = proof_bytes(ticket.get("proof"))
    if digest(raw) != ticket.get("proof_sha256"):
        raise ValueError("ticket proof SHA-256 does not match")
    return raw


def ticket_from_file(path: Path):
    with path.open("rb") as stream:
        raw = stream.read(MAX_INDEX + 8193)
    if len(raw) > MAX_INDEX + 8192:
        raise ValueError("startup OTA ticket is too large")
    return json.loads(raw)


def make_ticket(args) -> dict:
    previous = official_identity(args.previous_feed, args.previous_pack)
    candidate = read_pack(args.candidate_pack)
    proof = build(args.previous_cache, args.candidate_cache, args.previous_source,
                  args.candidate_source, args.engine, device_caches=True)
    raw = proof_bytes(proof)
    ticket = {
        "schema": SCHEMA, "previous": previous, "candidate": runtime_identity(candidate),
        "proof_sha256": digest(raw), "proof": proof,
    }
    validate_ticket(ticket, candidate)
    with args.output.open("xb") as handle:
        handle.write(encode(ticket) + b"\n")
    return summary(ticket, raw)


def verify_included(plain: Pack, final: Pack, proof: bytes) -> None:
    actual_members = dict(final.members)
    actual_members.pop(PROOF, None)
    if actual_members != plain.members or final.metadata.get(PROOF) != proof:
        raise ValueError("final PCK does not contain exactly the verified proof and plain OTA contents")


def summary(ticket: dict, raw: bytes) -> dict:
    return {
        "previous_version": ticket["previous"]["version_name"],
        "previous_pck_sha256": ticket["previous"]["pck_sha256"],
        "source_sha256": ticket["proof"]["source"], "engine": ticket["proof"]["engine"],
        "entries": len(ticket["proof"]["files"]), "proof_bytes": len(raw),
        "proof_sha256": ticket["proof_sha256"],
    }


def export_godot(root: Path, godot: str, target: Path) -> None:
    subprocess.run([godot, "--headless", "--path", str(root), "--export-pack", "AndroidUpdatePack", str(target)],
                   cwd=root, stdout=sys.stderr, check=True)


def export_ota(root: Path, godot: str, output: Path, ticket_path: Path) -> dict:
    source = root / PROOF
    if os.path.lexists(source):
        raise ValueError(f"staging root already contains {PROOF}; use a clean release checkout")
    with TemporaryDirectory(prefix=".startup-ota-", dir=output.parent) as temp:
        plain_path = Path(temp) / "plain.pck"
        export_godot(root, godot, plain_path)
        plain = read_pack(plain_path)
        runtime_identity(plain)
        status = {"status": "omitted", "reason": "ticket_missing"}
        selected = plain_path
        if os.path.lexists(ticket_path):
            try:
                ticket = ticket_from_file(ticket_path)
                raw = validate_ticket(ticket, plain)
                variant = Path(temp) / "with-proof.pck"
                handle = source.open("xb")
                try:
                    with handle:
                        handle.write(raw)
                    export_godot(root, godot, variant)
                finally:
                    source.unlink(missing_ok=True)
                verify_included(plain, read_pack(variant), raw)
                status = {"status": "included", **summary(ticket, raw)}
                selected = variant
            except (ValueError, OSError, subprocess.CalledProcessError) as error:
                status = {"status": "rejected", "reason": str(error)}
        status["pck_bytes"] = selected.stat().st_size
        status["pck_sha256"] = sha256(selected)
        os.replace(selected, output)
    return status


def verify_ota(args) -> dict:
    ticket = ticket_from_file(args.ticket)
    plain = read_pack(args.plain)
    raw = validate_ticket(ticket, plain)
    if ticket["previous"] != official_identity(args.previous_feed, args.previous_pack):
        raise ValueError("ticket previous release does not match the supplied official PCK")
    verify_included(plain, read_pack(args.pack), raw)
    return {"status": "verified", **summary(ticket, raw), "pck_bytes": args.pack.stat().st_size,
            "pck_sha256": sha256(args.pack)}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    prepare = sub.add_parser("prepare")
    for name in ("previous-feed", "previous-pack", "candidate-pack", "previous-cache", "candidate-cache", "output"):
        prepare.add_argument("--" + name, type=Path, required=True)
    for name in ("previous-source", "candidate-source", "engine"):
        prepare.add_argument("--" + name, required=True)
    verify = sub.add_parser("verify")
    for name in ("ticket", "plain", "pack", "previous-feed", "previous-pack"):
        verify.add_argument("--" + name, type=Path, required=True)
    export = sub.add_parser("export")
    export.add_argument("--root", type=Path, default=ROOT)
    export.add_argument("--godot", default="godot")
    export.add_argument("--output", type=Path, required=True)
    export.add_argument("--ticket", type=Path)
    export.add_argument("--status", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "prepare":
            result = make_ticket(args)
        elif args.command == "verify":
            result = verify_ota(args)
        else:
            root = args.root.resolve()
            ticket = (args.ticket or root / DEFAULT_TICKET).resolve()
            if ticket.is_relative_to(root) and ticket != root / DEFAULT_TICKET:
                raise ValueError("keep an explicit ticket outside the project or use the excluded default path")
            result = export_ota(root, args.godot, args.output.resolve(), ticket)
            if args.status:
                args.status.write_bytes(encode(result) + b"\n")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"startup OTA: {error}\n")
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
