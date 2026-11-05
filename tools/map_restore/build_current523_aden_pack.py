#!/usr/bin/env python3
"""Build a private current523 Aden raw-source tree outside the repository.

Example:
  python3 tools/map_restore/build_current523_aden_pack.py \
    --source-dir /private/selected_originals \
    --summary /private/all_Aden_map_structure_summary.json \
    --land-declaration /private/M_only_Land4_assetpath_and_explicit_zone_declarations.json \
    --output /private/current523-aden-pack

The input source directory contains Map/Aden/*.s32. Original source bytes are
copied unchanged; no image, spatial transform, navigation or zone is produced.
The final directory is published with one sibling-directory rename after every
staged member has been independently read and verified. Existing output is never
replaced. Local private output does not establish durable resource delivery.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import tempfile
import zlib

import current523_s32 as codec

MAX_METADATA_BYTES = 8 * 1024 * 1024


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key: " + key)
        result[key] = value
    return result


def _json(path):
    if not path.is_file() or path.is_symlink() or path.stat().st_size > MAX_METADATA_BYTES:
        raise ValueError("Metadata must be a bounded regular file: " + str(path))
    with path.open("rb") as handle:
        raw = handle.read(MAX_METADATA_BYTES + 1)
    if len(raw) > MAX_METADATA_BYTES:
        raise ValueError("Metadata grew beyond its bounded size: " + str(path))
    try:
        return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=_unique_object), raw
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError("Invalid UTF-8 JSON metadata: " + str(path)) from exc


def _regular_child(root, relative):
    """No symlink or traversal is permitted inside the private source tree."""
    parts = relative.split("/")
    if any(part in ("", ".", "..") or "\\" in part for part in parts):
        raise ValueError("Unsafe private source path")
    current = root
    for part in parts:
        current = current / part
        if current.is_symlink():
            raise ValueError("Symlink in private source tree: " + relative)
    if not current.is_file():
        raise ValueError("Missing regular private source file: " + relative)
    return current


def _bounded_source(path):
    size = path.stat().st_size
    if not codec.MIN_BYTES <= size <= codec.MAX_BYTES:
        raise ValueError("S32 source size outside bounded raw model: " + str(path))
    # Read at most one byte beyond the limit even if a source changes mid-read.
    with path.open("rb") as handle:
        data = handle.read(codec.MAX_BYTES + 1)
    if len(data) != size:
        raise ValueError("S32 source changed size while reading: " + str(path))
    return data


def _summary_rows(summary):
    if not isinstance(summary, list) or len(summary) != codec.SOURCE_COUNT:
        raise ValueError("Evidence summary must contain exactly 677 current Aden members")
    normalized = []
    for row in summary:
        if not isinstance(row, dict):
            raise ValueError("Invalid evidence summary row")
        normalized.append({"member": row.get("member"), "bytes": row.get("source_bytes"),
                           "sha256": row.get("source_sha256")})
    if codec.inventory_sha256(normalized) != codec.SOURCE_INVENTORY_SHA256:
        raise ValueError("Evidence summary is not the pinned current523 Aden inventory")
    return {row["member"]: row for row in summary}


def _land(land):
    if not isinstance(land, dict):
        raise ValueError("Missing direct LineageM Land4 declaration")
    row = land.get("Land4_raw", land)
    if not isinstance(row, dict) or type(row.get("ID")) is not int or row["ID"] != codec.LAND_ID or row.get("AssetPath") != codec.ASSET_PATH:
        raise ValueError("Direct LineageM Land4 must declare AssetPath=Aden/")
    if "source_asset_root" in land and land["source_asset_root"] != codec.SOURCE_ROOT:
        raise ValueError("Land4 source root does not match Map/Aden/")
    return {"ID": codec.LAND_ID, "AssetPath": codec.ASSET_PATH}


def _inventory(source_dir, expected):
    aden = source_dir / "Map" / "Aden"
    if any(path.is_symlink() for path in (source_dir / "Map", aden)) or not aden.is_dir():
        raise ValueError("Missing regular Map/Aden/ source directory")
    actual = set()
    for path in aden.rglob("*"):
        if path.is_symlink() or not path.is_file():
            raise ValueError("Only original regular S32 members are permitted in Map/Aden/")
        member = path.relative_to(source_dir).as_posix()
        codec.validate_member_path(member)
        actual.add(member)
    if actual != set(expected):
        missing = sorted(set(expected) - actual)
        extra = sorted(actual - set(expected))
        raise ValueError(f"Aden inventory mismatch: missing={missing[:3]}, extra={extra[:3]}")


def _output_path(output, source_dir):
    output = Path(output).expanduser()
    if output.is_symlink() or output.exists():
        raise ValueError("Output already exists; choose a new private pack directory")
    output = output.resolve()
    if output == source_dir or source_dir in output.parents:
        raise ValueError("Private output must be outside the original source tree")
    # Both a normal repository and a linked-worktree .git file are recognized.
    if any(_is_repository(parent) for parent in (output, *output.parents)):
        raise ValueError("Originals must be built outside any Git repository")
    repository = next((parent for parent in Path(__file__).resolve().parents if _is_repository(parent)), None)
    if repository and (output == repository or repository in output.parents):
        raise ValueError("Private original output must be outside the repository")
    return output


def _is_repository(directory):
    marker = directory / ".git"
    # Managed workspaces can contain an empty policy mount named .git. A real
    # directory repository has HEAD; a linked worktree uses a .git regular file.
    return marker.is_file() or (marker.is_dir() and (marker / "HEAD").is_file())


def _publish_directory(stage, output):
    """Publish atomically without replacing even a concurrently created directory."""
    if os.name == "nt":
        # Windows rename fails when its target already exists.
        os.rename(stage, output)
        return
    import ctypes
    import errno
    libc = ctypes.CDLL(None, use_errno=True)
    rename = getattr(libc, "renameat2", None)
    if rename is None:
        raise ValueError("Atomic no-replace directory publishing is unavailable on this platform")
    rename.argtypes = (ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint)
    rename.restype = ctypes.c_int
    # Linux AT_FDCWD=-100 and RENAME_NOREPLACE=1. Stage/output share a parent.
    if rename(-100, os.fsencode(stage), -100, os.fsencode(output), 1) != 0:
        error = ctypes.get_errno()
        if error in (errno.ENOSYS, errno.EINVAL, errno.ENOTSUP):
            raise ValueError("Atomic no-replace directory publishing is unavailable on this filesystem")
        raise OSError(error, os.strerror(error), str(output))


def member_metadata(decoded, summary):
    sections = decoded["sections"]
    row = {"member": decoded["member"], "path": "originals/" + decoded["member"],
           "source_path": decoded["member"], "bytes": decoded["source_bytes"],
           "sha256": decoded["source_sha256"], "attribute_offset": sections["attributes"]["offset"],
           "attribute_sha256": sections["attributes"]["sha256"], "core_end": decoded["core_end"],
           "object_part_count": sections["objects"]["part_count"], "sections": sections}
    for key in ("source_container", "manifest_container_last_version", "source_crc32"):
        if key in summary:
            row[key] = summary[key]
    return row


def validate_pack(pack_root):
    """Verify identity and every member on disk, including raw section digests."""
    root = Path(pack_root)
    if root.is_symlink() or not root.is_dir():
        raise ValueError("Private pack must be a regular directory")
    manifest, _ = _json(_regular_child(root, codec.MANIFEST_NAME))
    codec.validate_manifest(manifest)
    expected_paths = {codec.MANIFEST_NAME}
    for member in manifest["members"]:
        path = _regular_child(root, member["path"])
        data = _bounded_source(path)
        if len(data) != member["bytes"] or codec.sha256(data) != member["sha256"]:
            raise ValueError("Private source SHA256/size mismatch: " + member["member"])
        decoded = codec.read_s32(data, member["member"])
        if decoded["sections"] != member["sections"] or codec.write_s32(decoded) != data:
            raise ValueError("Private raw section mismatch: " + member["member"])
        expected_paths.add(member["path"])
    actual_paths = set()
    for path in root.rglob("*"):
        if path.is_symlink():
            raise ValueError("Symlink in private pack")
        if path.is_file():
            actual_paths.add(path.relative_to(root).as_posix())
        elif not path.is_dir():
            raise ValueError("Nonregular entry in private pack")
    if actual_paths != expected_paths:
        raise ValueError("Unexpected or missing files in private pack")
    return manifest


def build_pack(source_dir, summary_path, land_declaration_path, output, *, cumulative_version=523, edition="LineageM"):
    codec._identity(edition, cumulative_version)
    source_dir = Path(source_dir).expanduser()
    if source_dir.is_symlink() or not source_dir.is_dir():
        raise ValueError("Source directory must be a regular directory containing Map/Aden/")
    source_dir = source_dir.resolve()
    output = _output_path(output, source_dir)
    summary, summary_raw = _json(Path(summary_path))
    evidence = _summary_rows(summary)
    land, land_raw = _json(Path(land_declaration_path))
    declaration = _land(land)
    _inventory(source_dir, evidence)
    output.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix="." + output.name + ".staging-", dir=output.parent))
    try:
        # A private tree must not acquire group/world access through the caller's umask.
        stage.chmod(0o700)
        members = []
        for name in sorted(evidence):
            expected = evidence[name]
            data = _bounded_source(_regular_child(source_dir, name))
            if len(data) != expected["source_bytes"] or codec.sha256(data) != expected["source_sha256"]:
                raise ValueError("Current523 source SHA256/size mismatch: " + name)
            if "source_crc32" in expected and f"{zlib.crc32(data) & 0xffffffff:08x}" != expected["source_crc32"]:
                raise ValueError("Current523 source CRC32 mismatch: " + name)
            decoded = codec.read_s32(data, name)
            if (codec.write_s32(decoded) != data or decoded["sections"]["attributes"]["offset"] != expected.get("attribute_byte_offset")
                    or decoded["sections"]["attributes"]["sha256"] != expected.get("attribute_sha256")):
                raise ValueError("Raw source roundtrip/attribute evidence mismatch: " + name)
            destination = stage / "originals" / name
            destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            with destination.open("xb") as handle:
                handle.write(data)
            destination.chmod(0o600)
            members.append(member_metadata(decoded, expected))
        manifest = {"schema": codec.SCHEMA, "edition": codec.EDITION,
                    "cumulative_version": codec.CUMULATIVE_VERSION, "land_id": codec.LAND_ID,
                    "asset_path": codec.ASSET_PATH, "source_root": codec.SOURCE_ROOT,
                    "source_count": codec.SOURCE_COUNT,
                    "source_inventory_sha256": codec.SOURCE_INVENTORY_SHA256,
                    "members": members, "semantics": dict(codec.SEMANTICS),
                    "land_declaration": declaration,
                    "provenance": {
                        "source_summary": {"name": Path(summary_path).name, "bytes": len(summary_raw), "sha256": codec.sha256(summary_raw)},
                        "land_declaration": {"name": Path(land_declaration_path).name, "bytes": len(land_raw), "sha256": codec.sha256(land_raw)}},
                    "delivery_status": "PRIVATE_LOCAL_ONLY"}
        codec.validate_manifest(manifest)
        manifest_path = stage / codec.MANIFEST_NAME
        manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        manifest_path.chmod(0o600)
        validate_pack(stage)
        if output.exists() or output.is_symlink():
            raise ValueError("Output appeared during staging; refusing to replace it")
        _publish_directory(stage, output)
        stage = None
        return manifest
    finally:
        if stage is not None:
            shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--land-declaration", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--cumulative-version", type=int, default=523)
    parser.add_argument("--edition", default="LineageM")
    args = parser.parse_args()
    try:
        manifest = build_pack(args.source_dir, args.summary, args.land_declaration, args.output,
                              cumulative_version=args.cumulative_version, edition=args.edition)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Private Aden pack failed: {exc}\n")
    print(json.dumps({"output": str(args.output.resolve()), "manifest": codec.MANIFEST_NAME,
                      "members": len(manifest["members"]), "source_bytes": sum(row["bytes"] for row in manifest["members"]),
                      "source_inventory_sha256": manifest["source_inventory_sha256"],
                      "delivery_status": manifest["delivery_status"]}, sort_keys=True))


if __name__ == "__main__":
    main()
