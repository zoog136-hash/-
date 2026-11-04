#!/usr/bin/env python3
"""Verify the existing private Drive handoff and locate exact effect members.

Reads local files only. ZIP/DAT identities and CRC are evidence of received
bytes, never approval of SP2 pixels, direction semantics, or native rendering.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import zipfile


TARGET_IDS = (24941, 24942, 24943, 29044, 29045)
TARGET = re.compile(r"^Sprite/(24941|24942|24943|29044|29045)-\d+\.sp2$")

def expected_archives(directory, manifest):
    """Load owner-supplied fingerprints without publishing private receipts."""
    rows = json.loads((manifest or directory / "presentation-audit-input.json").read_text())["archives"]
    if not isinstance(rows, list) or len(rows) != 5:
        raise ValueError("private manifest must identify the five handoff archives")
    names = set()
    for row in rows:
        name, size, digest = row["filename"], row["bytes"], row["sha256"]
        if (not isinstance(name, str) or Path(name).name != name or name in (".", "..")
                or "\\" in name or name in names or type(size) is not int or size <= 0
                or not isinstance(digest, str) or re.fullmatch(r"[0-9a-f]{64}", digest) is None):
            raise ValueError("invalid private archive identity")
        names.add(name)
        yield name, digest, size


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def check_zip(archive):
    names = archive.namelist()
    if len(names) != len(set(names)):
        raise ValueError("duplicate ZIP member")
    damaged = archive.testzip()
    if damaged is not None:
        raise ValueError("ZIP CRC mismatch: " + damaged)


def check_manifest(archive):
    rows = json.loads(archive.read("package_manifest.json"))
    for row in rows:
        data = archive.read(row["file"])
        if len(data) != row["bytes"] or sha256(data) != row["sha256"]:
            raise ValueError("package manifest mismatch: " + row["file"])
    return len(rows)


def matching_member(name):
    # Canonical raw-package path has one extra directory; DAT members do not.
    return TARGET.fullmatch(name.removeprefix("selected_originals/"))


def audit(directory, manifest=None):
    received = []
    hits = []
    containers = 0
    nested_members = 0
    selected_sp2 = 0
    png_members = []
    for name, expected_sha, expected_bytes in expected_archives(directory, manifest):
        path = directory / name
        with path.open("rb") as stream:
            actual_sha = hashlib.file_digest(stream, "sha256").hexdigest()
        if path.stat().st_size != expected_bytes or actual_sha != expected_sha:
            raise ValueError("received archive size/SHA mismatch: " + name)
        with zipfile.ZipFile(path) as archive:
            check_zip(archive)
            manifest_members = check_manifest(archive)
            dats = 0
            for member in archive.infolist():
                if member.filename.endswith(".sp2"):
                    selected_sp2 += 1
                if member.filename.endswith(".png"):
                    png_members.append(member.filename)
                if matching_member(member.filename):
                    data = archive.read(member)
                    hits.append({"archive": name, "member": member.filename,
                                 "bytes": len(data), "sha256": sha256(data)})
                if not member.filename.endswith(".dat"):
                    continue
                if member.file_size > 64 * 1024 * 1024:
                    raise ValueError("unexpected DAT size: " + member.filename)
                data = archive.read(member)
                proof_path = "source_proofs/" + Path(member.filename).name + "_proof.json"
                proof = json.loads(archive.read(proof_path))
                if len(data) != proof["bytes"] or sha256(data) != proof["sha256"]:
                    raise ValueError("DAT source proof mismatch: " + member.filename)
                with zipfile.ZipFile(io.BytesIO(data)) as inner:
                    check_zip(inner)
                    nested_members += len(inner.infolist())
                    for item in inner.infolist():
                        if not matching_member(item.filename):
                            continue
                        payload = inner.read(item)
                        hits.append({"archive": name, "container": member.filename,
                                     "member": item.filename, "bytes": len(payload),
                                     "crc32": f"{item.CRC:08x}", "sha256": sha256(payload)})
                dats += 1
            containers += dats
            received.append({"filename": name, "bytes": expected_bytes,
                             "sha256": actual_sha,
                             "crc_passed": True, "manifest_members_verified": manifest_members,
                             "nested_dat_count": dats})
    found_ids = {int(matching_member(hit["member"])[1]) for hit in hits}
    return {
        "scope": "Existing user-owned Drive handoff; local bytes, exact names, SHA and CRC only",
        "archives": received,
        "received_archive_bytes": sum(row["bytes"] for row in received),
        "selected_sp2_members": selected_sp2,
        "nested_dat_containers": containers,
        "nested_dat_members_including_directory_entries": nested_members,
        "requested_sprite_ids": list(TARGET_IDS),
        "matching_target_members": hits,
        "ids_without_received_members": sorted(set(TARGET_IDS) - found_ids),
        "upstream_standard_png_members": png_members,
        "sp2_pixel_or_native_render_validation": "NOT_PERFORMED; byte checks do not establish pixels",
        "global_source_absence_proven": False,
        "full_inventory_library_transfer": "NOT_RETRIED; previous tools/list HTTP401",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--manifest", type=Path, help="Private owner manifest with five filename/bytes/sha256 records")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = audit(args.directory, args.manifest)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(1, f"HANDOFF_NOT_VERIFIED: {error}\n")
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
