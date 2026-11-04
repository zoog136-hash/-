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
PACKS = (
    ("TWILIGHT_current523_M_map_integration_989actual_SP2_validated_PNGs_risks_20261104.zip",
     "b6f665d03e84e7cd01b3dd15b60d94091b3ff762cdc58fcfd820c724aa622182", 76907660,
     "1hAunwy9n96sb5yH9Gxfk4arQihp7-GSQ"),
    ("TWILIGHT_current523_M_only_currentSprite_originals18_checkpoint01_20261104.zip",
     "7dfd47a9cb0f1073437933febee72a26a27159c868220b51b476226d4e9632ae", 190728359,
     None),
    ("TWILIGHT_current523_M_only_originalSprite69_checkpoint02_20261104.zip",
     "2280a66e69fca0f4853a6b460a9a2c315f3ebc86d46efaf83582297d6fa1091c", 189340512,
     None),
    ("TWILIGHT_current523_M_only_originalSprite69_checkpoint03_20261104.zip",
     "3e47d38afadc8b8c55d7528acaba5148ec4c101151fa16bc7202f66e1b23da71", 190535985,
     None),
    ("TWILIGHT_current523_M_only_originalSprite69_checkpoint04_20261104.zip",
     "4d6045fc087a8b2e1794776635ac84a6729423e1182a7627fe6bff17ae5a7770", 185164962,
     None),
)


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


def audit(directory):
    received = []
    hits = []
    containers = 0
    nested_members = 0
    selected_sp2 = 0
    png_members = []
    for name, expected_sha, expected_bytes, drive_id in PACKS:
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
                             "sha256": actual_sha, "drive_file_id": drive_id,
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
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = audit(args.directory)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(1, f"HANDOFF_NOT_VERIFIED: {error}\n")
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
