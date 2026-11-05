#!/usr/bin/env python3
"""Verify a private source523 image intake; never install or activate assets.

Only the generated report may contain private local paths and original member
identities. This tool contains no original pixels, source rows, URLs or keys.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import zlib


EXPECTED_INVENTORY = {
    "known_files": 16180,
    "known_encrypted_bytes": 648457488,
    "known_plain_bytes": 648319416,
    "target_files": 14964,
    "target_encrypted_bytes": 609061968,
    "target_plain_bytes": 608934161,
}
INVENTORY_FILE = "audit/current523_retained_images_lineage_diff.jsonl.gz"
BINDINGS_FILE = "source-bindings/all42968_asset_bindings523.jsonl.gz"
CHANGED_PROVENANCE = "provenance/all4_current_opaque_image_originals523.json"
CONTAINER_PROVENANCE = "map-image-contracts/whole_original_current_vs_prior_decoded_identity523.json"
TABLE_PROVENANCE = "map-image-contracts/source_manifest.json"
BASE_INVENTORY_FILE = "audit/base508_image_asset_manifest.jsonl.gz"


class AuditError(Exception):
    def __init__(self, code: str, **details):
        super().__init__(code)
        self.code = code
        self.details = details


def require(condition, code: str, **details):
    if not condition:
        raise AuditError(code, **details)


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def safe_relative(value: str) -> str:
    require(isinstance(value, str) and bool(value), "unsafe_relative_path")
    require(not any(c in value for c in ("\\", ":", "\0")), "unsafe_relative_path", path=value)
    require(not any(ord(c) < 32 or ord(c) == 127 for c in value), "unsafe_relative_path", path=value)
    require(not value.startswith("/") and all(p not in ("", ".", "..") for p in value.split("/")),
            "unsafe_relative_path", path=value)
    return value


def no_symlink_chain(path: Path):
    absolute = Path(os.path.abspath(path))
    for component in (absolute, *absolute.parents):
        require(not component.is_symlink(), "symlink_not_allowed", path=str(component))


def local_file(root: Path, member: str) -> Path:
    candidate = root / safe_relative(member)
    no_symlink_chain(candidate)
    require(candidate.is_file(), "file_missing_or_not_regular", path=str(candidate))
    return candidate


def check_root(root: Path, scan=False) -> Path:
    no_symlink_chain(root)
    require(root.is_dir(), "directory_missing", path=str(root))
    root = root.resolve()
    if scan:
        for directory, dirs, files in os.walk(root, followlinks=False):
            for name in dirs + files:
                entry = Path(directory) / name
                require(not entry.is_symlink(), "symlink_not_allowed", path=str(entry))
                require(entry.is_dir() or entry.is_file(), "special_file_not_allowed", path=str(entry))
    return root


def read_json(path: Path):
    no_symlink_chain(path)
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, ValueError) as exc:
        raise AuditError("invalid_json", path=str(path), error=type(exc).__name__) from exc


def jsonl(path: Path):
    no_symlink_chain(path)
    try:
        with gzip.open(path, "rt", encoding="utf-8") as handle:
            for number, line in enumerate(handle, 1):
                require(bool(line.strip()), "empty_jsonl_row", path=str(path), line=number)
                value = json.loads(line)
                require(isinstance(value, dict), "invalid_jsonl_row", line=number)
                yield value
    except (OSError, EOFError, ValueError) as exc:
        raise AuditError("invalid_jsonl", path=str(path), error=type(exc).__name__) from exc


def fingerprint(path: Path) -> dict:
    no_symlink_chain(path)
    require(path.is_file(), "file_missing_or_not_regular", path=str(path))
    size, crc = 0, 0
    sha256, sha1 = hashlib.sha256(), hashlib.sha1()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            size += len(block)
            sha256.update(block)
            sha1.update(block)
            crc = zlib.crc32(block, crc)
    return {"bytes": size, "sha256": sha256.hexdigest(), "sha1": sha1.hexdigest(),
            "crc32": f"{crc & 0xffffffff:08x}"}


def validate_spec(spec: dict):
    require(isinstance(spec, dict) and integer(spec.get("bytes")), "invalid_file_spec")
    require(isinstance(spec.get("sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", spec["sha256"]),
            "invalid_file_spec")
    if "sha1" in spec:
        require(isinstance(spec["sha1"], str) and re.fullmatch(r"[0-9a-f]{40}", spec["sha1"]),
                "invalid_file_spec")


def matching(actual: dict, expected: dict) -> bool:
    return all(actual.get(field) == expected[field] for field in ("bytes", "sha256", "sha1") if field in expected)


def compatible_specs(left: dict, right: dict) -> bool:
    return (left.get("bytes") == right.get("bytes") and left.get("sha256") == right.get("sha256")
            and ("sha1" not in left or "sha1" not in right or left["sha1"] == right["sha1"]))


def verify_manifest(root: Path, expected_count: int = 27) -> dict:
    root = check_root(root, scan=True)
    manifest = read_json(local_file(root, "MANIFEST.json"))
    entries = manifest.get("files") if isinstance(manifest, dict) else None
    require(isinstance(entries, list) and len(entries) == expected_count, "handoff_manifest_count")
    seen, total = set(), 0
    for entry in entries:
        require(isinstance(entry, dict), "invalid_manifest_entry")
        member = safe_relative(entry.get("path"))
        require(member != "MANIFEST.json" and member not in seen, "duplicate_manifest_path", path=member)
        seen.add(member)
        validate_spec(entry)
        path = local_file(root, member)
        require(matching(fingerprint(path), entry), "handoff_file_integrity", path=member)
        total += entry["bytes"]
    actual = {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()}
    require(actual == seen | {"MANIFEST.json"}, "handoff_unlisted_or_missing_files",
            unlisted=sorted(actual - seen - {"MANIFEST.json"}), missing=sorted(seen - actual))
    return {"payload_files": len(entries), "payload_bytes": total,
            "manifest_sha256": fingerprint(root / "MANIFEST.json")["sha256"]}


def validate_inventory(rows: list, expected: dict | None = None) -> dict:
    expected = EXPECTED_INVENTORY if expected is None else expected
    require(isinstance(rows, list), "inventory_not_list")
    seen, pairs, targets = set(), set(), []
    known_encrypted = known_plain = 0
    for number, row in enumerate(rows, 1):
        require(isinstance(row, dict), "invalid_inventory_row", line=number)
        member = safe_relative(row.get("path"))
        container = safe_relative(row.get("container"))
        require(member.startswith(("Image/", "icon/")) and container.startswith("Client/Data/")
                and container.endswith(".dat"), "inventory_namespace", line=number)
        require(member not in seen and (container, member) not in pairs, "duplicate_inventory_identity", path=member)
        seen.add(member)
        pairs.add((container, member))
        require(type(row.get("historical_card_pack_lineage")) is bool, "inventory_history_not_bool", path=member)
        require(row.get("current523_alignment") == "retained_container_size_sha1_identical",
                "inventory_alignment", path=member)
        require(integer(row.get("encrypted_bytes"), 1) and integer(row.get("plain_bytes"), 1)
                and row["encrypted_bytes"] >= row["plain_bytes"], "inventory_byte_counts", path=member)
        require(isinstance(row.get("sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", row["sha256"]),
                "inventory_digest", path=member)
        require(row.get("format") in ("PNG", "JPEG", "BMP") and integer(row.get("width"), 1)
                and integer(row.get("height"), 1), "inventory_image_metadata", path=member)
        require(row.get("relative_output_path") == "decoded/" + member, "inventory_decoded_path", path=member)
        require(row.get("category") == "/".join(member.split("/")[:2])
                or (row.get("category") == "icon/root" and member.count("/") == 1),
                "inventory_category", path=member)
        known_encrypted += row["encrypted_bytes"]
        known_plain += row["plain_bytes"]
        if row["historical_card_pack_lineage"] is False:
            targets.append(row)
    totals = {"known_files": len(rows), "known_encrypted_bytes": known_encrypted,
              "known_plain_bytes": known_plain, "target_files": len(targets),
              "target_encrypted_bytes": sum(r["encrypted_bytes"] for r in targets),
              "target_plain_bytes": sum(r["plain_bytes"] for r in targets)}
    require(totals == expected, "inventory_fixed_denominator_mismatch", expected=expected, actual=totals)
    return {"totals": totals, "rows": rows, "target_rows": targets,
            "known_container_count": len({r["container"] for r in rows})}


def verify_copies(logical: str, candidates: list[Path], spec: dict) -> dict | None:
    safe_relative(logical)
    validate_spec(spec)
    copies, seen = [], set()
    for path in candidates:
        no_symlink_chain(path)
        if not path.exists():
            continue
        require(path.is_file(), "container_not_regular", path=str(path))
        identity = str(path.resolve())
        if identity in seen:
            continue
        seen.add(identity)
        copies.append({"local_path": identity, **fingerprint(path)})
    if not copies:
        return None
    require(len({(c["bytes"], c["sha256"], c["sha1"]) for c in copies}) == 1,
            "conflicting_container_copies", container=logical,
            copies=[{k: c[k] for k in ("local_path", "bytes", "sha256")} for c in copies])
    require(matching(copies[0], spec), "container_integrity", container=logical,
            local_paths=[c["local_path"] for c in copies])
    return {"container": logical, "bytes": copies[0]["bytes"], "sha256": copies[0]["sha256"],
            "sha1": copies[0]["sha1"], "copy_count": len(copies),
            "local_paths": [c["local_path"] for c in copies]}


def source_container_rows(value: dict, inventory_containers: set, changed: dict) -> dict:
    require(isinstance(value, dict) and isinstance(value.get("current_originals"), list), "container_manifest_schema")
    result = {}
    for row in value["current_originals"]:
        require(isinstance(row, dict) and isinstance(row.get("current_original"), dict), "container_manifest_row")
        spec = row["current_original"]
        member = safe_relative(spec.get("path"))
        validate_spec(spec)
        require(member not in result and member in inventory_containers | set(changed),
                "container_manifest_identity", container=member)
        require(spec.get("matches_current523_manifest") is True and row.get("fresh_rehash_current_manifest_match") is True,
                "container_current_provenance", container=member)
        selection = row.get("current_manifest_selection", {})
        require(selection.get("path") == member and selection.get("manifest_bytes") == spec["bytes"]
                and selection.get("manifest_sha1") == spec.get("sha1"), "container_selection_provenance", container=member)
        retained = member in inventory_containers
        if retained:
            prior = row.get("prior508_container_record", {})
            require(row.get("byte_identical_to_prior_decoded_container") is True
                    and prior.get("container") == member and prior.get("sha256") == spec["sha256"],
                    "container_retained_identity_unqualified", container=member)
        else:
            require(matching(spec, changed[member]), "changed_container_provenance_conflict", container=member)
        result[member] = {key: spec[key] for key in ("bytes", "sha256", "sha1")}
    return result


def verify_catalog(root: Path, inventory: dict, base_rows: list) -> dict:
    """Cross-check supplied container expectations against bound leaf metadata."""
    root = check_root(root)
    verified_path = local_file(root, "containers_verified.json")
    index_path = local_file(root, "index_catalog.json")
    verified, index = read_json(verified_path), read_json(index_path)
    require(isinstance(verified, list) and isinstance(index, dict)
            and isinstance(index.get("containers"), list) and isinstance(index.get("entries"), list)
            and index.get("errors") == [], "catalog_schema")
    original, entries, containers, hashes = {}, {}, {}, {}
    for row in base_rows:
        member = safe_relative(row.get("path"))
        container = safe_relative(row.get("container"))
        require((container, member) not in original, "catalog_base_duplicate")
        original[(container, member)] = row
    fields = ("container", "path", "encrypted_bytes", "plain_bytes", "sha256", "format", "width", "height")
    for row in inventory["rows"]:
        base = original.get((row["container"], row["path"]))
        require(base is not None and all(row.get(k) == base.get(k) for k in fields),
                "retained_base_inventory_conflict", path=row["path"])
    for row in index["containers"]:
        member = safe_relative(row.get("container"))
        require(member not in containers and integer(row.get("bytes"), 1)
                and integer(row.get("directory_offset")) and integer(row.get("directory_bytes"))
                and row.get("outer_crc_verified") is True and row.get("directory_padding_verified") is True
                and row["directory_offset"] + row["directory_bytes"] + 9 == row["bytes"],
                "catalog_container_metadata", container=member)
        containers[member] = row
    for row in verified:
        member = safe_relative(row.get("container"))
        require(member not in hashes and member in containers and row.get("errors") == 0
                and row.get("outer_crc_verified") is True and integer(row.get("entries"))
                and row.get("entries") == row.get("verified_images") == containers[member].get("entries")
                and isinstance(row.get("sha256"), str) and re.fullmatch(r"[0-9a-f]{64}", row["sha256"]),
                "catalog_container_identity", container=member)
        hashes[member] = row
    require(set(hashes) == set(containers), "catalog_container_coverage")
    for row in index["entries"]:
        member, container = safe_relative(row.get("path")), safe_relative(row.get("container"))
        key = (container, member)
        require(key not in entries and key in original and container in containers,
                "catalog_member_identity", path=member)
        require(integer(row.get("offset")) and integer(row.get("size"), 1)
                and row["size"] == original[key].get("encrypted_bytes")
                and row["offset"] + row["size"] <= containers[container]["directory_offset"],
                "catalog_member_extent", path=member)
        entries[key] = row
    require(set(entries) == set(original), "catalog_member_coverage")
    counts = Counter(container for container, member in entries)
    require(all(counts[c] == containers[c]["entries"] for c in containers), "catalog_member_count")
    known = {row["container"] for row in inventory["rows"]}
    require(known.issubset(hashes), "catalog_retained_container_missing")
    specs = {c: {"bytes": containers[c]["bytes"], "sha256": hashes[c]["sha256"]} for c in sorted(known)}
    return {"specs": specs, "root": str(root), "verified_container_rows": len(hashes),
            "verified_index_members": len(entries), "qualified_retained_containers": len(specs),
            "containers_verified_sha256": fingerprint(verified_path)["sha256"],
            "index_catalog_sha256": fingerprint(index_path)["sha256"],
            "source_authenticity": "Supplied historical catalog expectations cross-checked against handoff leaf metadata; actual local DAT hashes are still required. No signed-origin or decoding claim."}


def verify_containers(handoff: Path, roots: list[Path], inventory: dict, catalog: dict | None = None) -> dict:
    changed_rows = read_json(local_file(handoff, CHANGED_PROVENANCE))
    require(isinstance(changed_rows, list) and len(changed_rows) == 4, "changed_container_count")
    changed = {}
    for row in changed_rows:
        require(isinstance(row, dict), "changed_container_schema")
        member = safe_relative(row.get("path"))
        require(member.startswith("Client/Data/") and member.endswith(".dat") and member not in changed,
                "changed_container_identity")
        validate_spec(row)
        require(row.get("current_member_directory_decoded") is False and row.get("current_pixels_decoded") is False,
                "changed_container_not_declared_opaque", container=member)
        changed[member] = {key: row[key] for key in ("bytes", "sha256", "sha1")}
        individual = read_json(local_file(handoff, "provenance/" + Path(member).name + "_provenance.json"))
        require(individual.get("path") == member and individual.get("matches523_manifest") is True
                and matching(individual, row), "changed_container_provenance_conflict", container=member)
    known = {r["container"] for r in inventory["rows"]}
    require(not known.intersection(changed), "changed_container_in_retained_inventory")
    specs = source_container_rows(read_json(local_file(handoff, CONTAINER_PROVENANCE)), known, changed)
    if catalog is not None:
        for member, spec in catalog["specs"].items():
            require(member not in specs or matching(specs[member], spec),
                    "catalog_source_manifest_conflict", container=member)
            if member not in specs:
                specs[member] = spec
    candidates = {member: [] for member in set(specs) | set(changed)}
    sources = []
    for root in roots:
        root = check_root(root, scan=True)
        manifest_root = root.parent if root.name == "originals" and (root.parent / "SOURCE_MANIFEST.json").is_file() else root
        manifest = manifest_root / "SOURCE_MANIFEST.json"
        no_symlink_chain(manifest)
        if manifest.is_file():
            supplied = source_container_rows(read_json(manifest), known, changed)
            source = {"root": str(root), "manifest_sha256": fingerprint(manifest)["sha256"],
                      "declared_containers": len(supplied)}
        else:
            require(catalog is not None, "source_manifest_or_catalog_required", root=str(root))
            supplied = {**catalog["specs"], **changed}
            source = {"root": str(root), "manifest_sha256": None,
                      "metadata_source": "explicit_compact_catalog_and_bound_retained_flags",
                      "declared_containers": len(supplied)}
        for member, spec in supplied.items():
            require(member not in specs or compatible_specs(specs[member], spec),
                    "conflicting_container_declarations", container=member)
            if member not in specs or "sha1" in spec:
                specs[member] = spec
            candidates.setdefault(member, [])
        sources.append(source)
        for path in root.rglob("*.dat"):
            relative = path.relative_to(root).as_posix()
            for prefix in ("originals/", "current523-originals/"):
                if relative.startswith(prefix):
                    relative = relative[len(prefix):]
                    break
            member = safe_relative(relative)
            require(member in supplied, "unmanifested_supplied_container", path=str(path))
            candidates[member].append(path)
    for member in changed:
        candidates.setdefault(member, []).append(handoff / "current523-originals" / member)
        require(member not in specs or matching(specs[member], changed[member]),
                "changed_container_provenance_conflict", container=member)
        specs[member] = changed[member]
    verified = {}
    for member in sorted(specs):
        found = verify_copies(member, candidates.get(member, []), specs[member])
        if found:
            verified[member] = found
    require(set(changed).issubset(verified), "changed_original_missing")
    qualified = set(verified).intersection(known)
    covered = [row for row in inventory["target_rows"] if row["container"] in qualified]
    targets = {row["container"] for row in inventory["target_rows"]}
    return {"original_sources": sources, "verified_unique_containers": len(verified),
            "verified_physical_copies": sum(c["copy_count"] for c in verified.values()),
            "duplicate_matching_copies": sum(c["copy_count"] - 1 for c in verified.values()),
            "verified_containers": list(verified.values()), "verified_retained_containers": sorted(qualified),
            "missing_target_containers": sorted(targets - qualified),
            "container_presence_metadata_coverage_only": {
                "target_files": len(covered), "original_encrypted_member_bytes": sum(r["encrypted_bytes"] for r in covered),
                "plain_file_bytes": sum(r["plain_bytes"] for r in covered),
                "target_file_percent": 100 * len(covered) / EXPECTED_INVENTORY["target_files"],
                "target_original_encrypted_byte_percent": 100 * sum(r["encrypted_bytes"] for r in covered) / EXPECTED_INVENTORY["target_encrypted_bytes"],
                "is_decoded_or_loaded_or_observed_use": False},
            "opaque_current_containers": [{"container": member, "original_verified": True,
                "directory_verified": False, "pixels_verified": False, "member_count": None,
                "old508_members_accepted": False} for member in sorted(changed)],
            "qualified_retained_identity_basis": "Actual local bytes/SHA256 (and SHA1 where declared) match supplied retained provenance and complete-file prior decoded identity. Producer filesystem paths are ignored."}


def verify_tables(root: Path, handoff: Path) -> dict:
    root = check_root(root)
    if root.name == "content" and (root.parent / "index.json").is_file():
        root = check_root(root.parent)
    index_path = local_file(root, "index.json")
    index = read_json(index_path)
    require(isinstance(index, list), "table_index_schema")
    indexed = {}
    for entry in index:
        member = safe_relative(entry.get("path")) if isinstance(entry, dict) else None
        require(member is not None and member not in indexed, "duplicate_table_index_path")
        indexed[member] = entry
    provenance = read_json(local_file(handoff, TABLE_PROVENANCE))
    require(isinstance(provenance, dict) and isinstance(provenance.get("tables"), list), "table_provenance_schema")
    declared = {r["table"]: r for r in provenance["tables"]}
    package = read_json(local_file(root, "package_manifest.json"))
    require(isinstance(package, dict) and isinstance(package.get("files"), list), "table_package_manifest_schema")
    packaged = {}
    for entry in package["files"]:
        member = safe_relative(entry.get("path")) if isinstance(entry, dict) else None
        require(member is not None and member not in packaged, "duplicate_table_package_path")
        packaged[member] = entry
    require("index.json" in packaged and matching(fingerprint(index_path), packaged["index.json"]), "table_index_digest")
    tables, evidence = {}, []
    for name, count in (("AssetType", 23), ("AssetView", 42968)):
        member = "content/" + name + ".json"
        require(member in indexed and member in packaged and name in declared, "table_declaration_missing", table=name)
        path = local_file(root, member)
        actual = fingerprint(path)
        entry, source = indexed[member], declared[name]
        require(matching(actual, entry) and matching(actual, packaged[member])
                and actual["bytes"] == source.get("bytes") and actual["sha256"] == source.get("sha256"),
                "table_digest", table=name)
        require(entry.get("version") == 523 and entry.get("row_count") == count
                and entry.get("member_crc_verified") is True and entry.get("status") == "strict_json_pass"
                and actual["crc32"] == entry.get("crc32"), "table_index_provenance", table=name)
        data = read_json(path)
        rows = data.get("rows") if isinstance(data, dict) else None
        require(isinstance(rows, list) and len(rows) == count and source.get("rows") == count,
                "table_row_count", table=name)
        tables[name] = rows
        evidence.append({"table": name, "rows": count, "bytes": actual["bytes"], "sha256": actual["sha256"]})
    types, assets = {}, {}
    for row in tables["AssetType"]:
        key = row.get("ID")
        require(integer(key) and key not in types and isinstance(row.get("Path"), str), "asset_type_identity")
        types[key] = row
    for row in tables["AssetView"]:
        key = row.get("AssetId")
        require(integer(key) and key not in assets and row.get("AssetTypeId") in types
                and isinstance(row.get("FilePath"), str), "asset_identity")
        assets[key] = row
    seen, statuses, image_statuses = set(), Counter(), Counter()
    for binding in jsonl(local_file(handoff, BINDINGS_FILE)):
        key = binding.get("asset_id")
        require(integer(key) and key not in seen and key in assets, "binding_identity")
        seen.add(key)
        row = assets[key]
        typed = types[row["AssetTypeId"]]["Path"] + row["FilePath"]
        if typed.rstrip("/"):
            safe_relative(typed.rstrip("/"))
        require(binding.get("row") == row and binding.get("path") == typed, "binding_table_mapping", asset_id=key)
        status = binding.get("status")
        require(status in {"exact_catalog_path", "current_replaced_image_member_unverified",
                           "not_in_available_member_catalog", "zero_or_empty", "case_only_candidate"}, "binding_status")
        statuses[status] += 1
        if typed.startswith(("Image/", "icon/")):
            image_statuses[status] += 1
    require(seen == set(assets), "binding_row_coverage")
    return {"root": str(root), "index_sha256": fingerprint(index_path)["sha256"], "tables": evidence,
            "exact_row_and_typed_path_matches": len(seen), "declared_reference_statuses": dict(statuses),
            "image_icon_declared_reference_statuses": dict(image_statuses),
            "references_are_original_files_or_observed_use": False}


def verify_decoded(root: Path | None, inventory: dict) -> dict:
    result = {"requested": root is not None, "new_verified_retained_files": 0,
              "new_verified_target_files": 0, "target_original_encrypted_member_bytes": 0,
              "target_plain_file_bytes": 0, "verified": [], "unqualified_not_accepted": [],
              "successful_full_pixel_decodes": 0, "game_render_or_inspection_evidence": False,
              "changed_container_pixels_accepted": 0, "actual_game_use": "unknown"}
    if root is None:
        return result
    root = check_root(root, scan=True)
    try:
        from PIL import Image
    except ImportError as exc:
        raise AuditError("pillow_required_for_decoded_verification") from exc
    known = {r["path"]: r for r in inventory["rows"]}
    paths = {}
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        member = path.relative_to(root).as_posix()
        if member.startswith("decoded/"):
            member = member[len("decoded/"):]
        safe_relative(member)
        if member not in known:
            result["unqualified_not_accepted"].append(member)
            continue
        paths.setdefault(member, []).append(path)
    for member, copies in sorted(paths.items()):
        row = known[member]
        check = verify_copies(member, copies, {"bytes": row["plain_bytes"], "sha256": row["sha256"]})
        path = copies[0]
        try:
            with Image.open(path) as image:
                require(image.format == row["format"] and image.size == (row["width"], row["height"]),
                        "decoded_format_or_dimensions", path=member)
                image.verify()
            # verify() checks structure/CRC; reopen and load() to force the
            # complete pixel decode without converting or writing the image.
            with Image.open(path) as image:
                image.load()
                require(image.format == row["format"] and image.size == (row["width"], row["height"]),
                        "decoded_format_or_dimensions", path=member)
                if "mode" in row:
                    require(image.mode == row["mode"], "decoded_mode", path=member)
        except AuditError:
            raise
        except Exception as exc:
            raise AuditError("decoded_image_invalid", path=member, error=type(exc).__name__) from exc
        target = row["historical_card_pack_lineage"] is False
        result["verified"].append({"path": member, "container": row["container"], "sha256": row["sha256"],
            "plain_bytes": row["plain_bytes"], "original_encrypted_member_bytes": row["encrypted_bytes"],
            "format": row["format"], "width": row["width"], "height": row["height"],
            "mode": row.get("mode"), "full_pixel_decode_succeeded": True,
            "game_render_or_inspection_evidence": False,
            "target": target, "copy_count": check["copy_count"], "observed_game_use": False})
        result["successful_full_pixel_decodes"] += 1
        result["new_verified_retained_files"] += 1
        if target:
            result["new_verified_target_files"] += 1
            result["target_original_encrypted_member_bytes"] += row["encrypted_bytes"]
            result["target_plain_file_bytes"] += row["plain_bytes"]
    result["unqualified_not_accepted"] = sorted(set(result["unqualified_not_accepted"]))
    return result


def output_directory(path: Path, create: bool = True) -> Path:
    no_symlink_chain(path)
    absolute = Path(os.path.abspath(path))
    for parent in (absolute, *absolute.parents):
        marker = parent / ".git"
        # Managed workspaces may contain an empty .git placeholder. Recognize
        # actual checkouts and worktree gitdir files, not that placeholder.
        checkout = marker.is_file() or (marker.is_dir() and
                    ((marker / "HEAD").exists() or (marker / "config").exists()))
        require(not checkout, "output_inside_repository", path=str(absolute))
    if create:
        absolute.mkdir(parents=True, exist_ok=True)
    return absolute


def run(args) -> dict:
    handoff = check_root(args.handoff)
    manifest = verify_manifest(handoff)
    inventory = validate_inventory(list(jsonl(local_file(handoff, INVENTORY_FILE))))
    catalog = verify_catalog(args.catalog, inventory, list(jsonl(local_file(handoff, BASE_INVENTORY_FILE)))) if args.catalog else None
    containers = verify_containers(handoff, args.originals, inventory, catalog)
    tables = verify_tables(args.tables, handoff)
    decoded = verify_decoded(args.decoded, inventory)
    return {"schema": "source523-image-input-audit-v1", "status": "verified_inputs_with_explicit_gaps",
        "created_utc": datetime.now(timezone.utc).isoformat(), "handoff_root": str(handoff),
        "handoff": manifest, "fixed_denominators": inventory["totals"],
        "known_retained_container_count": inventory["known_container_count"],
        "compact_catalog_verification": {k: v for k, v in catalog.items() if k != "specs"} if catalog else None,
        "full_current523_leaf_inventory": None, "container_verification": containers,
        "source_table_mapping": tables, "decoded_file_verification": decoded,
        "actual_game_use": {"status": "unknown", "new_evidence_files": 0,
                            "new_evidence_original_encrypted_member_bytes": 0, "percentage": None},
        "target": {"actual_use_percent": 95, "file_and_original_encrypted_byte_measures_are_separate": True},
        "boundaries": ["No asset installation, runtime or gameplay activation, state/save writes, image generation or original DAT decryption.",
            "Container coverage is metadata coverage only. Inventory, verified files, loads, test renders and observed game use are different stages.",
            "The retained target is unconfirmed by one historical card lineage, not proven unused globally. Excluded gameplay stays excluded.",
            "Outer DAT, directory and footer bytes never count as original encrypted member payload.",
            "Changed current containers remain opaque; no historical508 member/hash is accepted as their decoded identity.",
            "Sound and actor Sprite/SP2 work are excluded."],
        "remaining_requirements": ["Receive the previously reviewed original image decoder and its approved parameters; never guess keys or substitute old508 pixels.",
            "Receive and verify missing target container originals using explicit current/retained provenance.",
            "Verify decoded leaves separately, then owner-specific source bindings and actual game use. Input verification does not satisfy the95% actual-use goal."]}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--handoff", type=Path, required=True)
    parser.add_argument("--tables", type=Path, required=True, help="Source523 package root containing index.json and content/")
    parser.add_argument("--catalog", type=Path, help="Optional compact historical catalog root; required for originals roots without SOURCE_MANIFEST.json")
    parser.add_argument("--originals", type=Path, action="append", default=[], help="Repeatable local original root containing Client/Data/ or originals/Client/Data/")
    parser.add_argument("--decoded", type=Path)
    parser.add_argument("--output", type=Path, required=True, help="Private generated-report directory outside any Git checkout")
    args = parser.parse_args(argv)
    try:
        output = output_directory(args.output, create=False)
        inputs = [args.handoff, args.tables, *args.originals] + ([args.decoded] if args.decoded else []) + ([args.catalog] if args.catalog else [])
        for source in inputs:
            require(not output.is_relative_to(source.resolve()) and not source.resolve().is_relative_to(output),
                    "output_overlaps_input", path=str(output))
        output.mkdir(parents=True, exist_ok=True)
    except (AuditError, OSError) as exc:
        print(json.dumps({"status": "rejected", "error": getattr(exc, "code", type(exc).__name__)}), file=sys.stderr)
        return 2
    try:
        report, code = run(args), 0
    except (AuditError, OSError, ValueError, TypeError, KeyError, AttributeError) as exc:
        report, code = {"schema": "source523-image-input-audit-v1", "status": "rejected",
            "error": getattr(exc, "code", "invalid_input_schema" if not isinstance(exc, OSError) else type(exc).__name__),
            "details": getattr(exc, "details", {}),
            "actual_game_use": {"status": "unknown", "new_evidence_files": 0,
                                "new_evidence_original_encrypted_member_bytes": 0}}, 2
    target = output / "source523_image_intake_report.json"
    no_symlink_chain(target)
    temporary = output / ".source523_image_intake_report.tmp"
    no_symlink_chain(temporary)
    temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(target)
    print(json.dumps({"status": report["status"], "report": str(target), "report_sha256": fingerprint(target)["sha256"]}))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
