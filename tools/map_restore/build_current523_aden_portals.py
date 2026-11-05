#!/usr/bin/env python3
"""Join private current523 Aden S32 tails to native M portal declarations.

The output is a private, bounded evidence contract, not a navigation mesh. A
candidate still needs both endpoints accepted by the current source-field
consumer. Raw attributes have no inferred collision semantics. No fee, item
consumption, nearest-point correction, or cross-Land destination is invented.
"""

import argparse
import base64
from collections import Counter
import json
import os
from pathlib import Path
import re
import struct
import tempfile

import current523_s32 as codec
from build_current523_aden_pack import _bounded_source, _is_repository, _regular_child, _unique_object

SCHEMA = 1
MAX_JSON_BYTES = 12 * 1024 * 1024
INPUTS = {
    "Land": "8778d18d8c23a0ccb0a555f495e056987796232c616dec805dfb4c4d633b0ef9",
    "Portal": "af434065337cfd2b8c3fab9887ce5d3569ce6651d122a05288769d487df78a45",
    "Territories": "2ef6e702e46204f8fd233ede612890ec20eadbbd16189bc02b04df3a58f4cc3b",
}
PRIMARY_TARGET_MODE = "signed_halfx_signed_y_base32768"
TARGET_MODES = (PRIMARY_TARGET_MODE, "unsigned_halfx_signed_y_base32768",
                "unsigned_halfx_unsigned_y_base32768")
RUNTIME_REQUIREMENTS = ["source_field_source_endpoint_clear", "source_field_target_endpoint_clear"]


def read_json(path):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > MAX_JSON_BYTES:
        raise ValueError("Expected bounded regular JSON: " + str(path))
    with path.open("rb") as handle:
        raw = handle.read(MAX_JSON_BYTES + 1)
    if len(raw) > MAX_JSON_BYTES:
        raise ValueError("Oversized JSON: " + str(path))
    try:
        value = json.loads(raw.decode("utf-8-sig"), object_pairs_hook=_unique_object)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError("Invalid JSON: " + str(path)) from exc
    return value, raw


def _indexed(rows, name):
    if not isinstance(rows, list) or len(rows) > 100000:
        raise ValueError("Invalid native table: " + name)
    result = {}
    for row in rows:
        if not isinstance(row, dict) or type(row.get("ID")) is not int or row["ID"] in result:
            raise ValueError("Invalid or duplicate native ID: " + name)
        result[row["ID"]] = row
    return result


def source_candidate(member, x, y):
    """Explicit tool hypothesis, admitted only by exact native-row comparison."""
    match = re.fullmatch(r"Map/Aden/([0-9a-fA-F]{4})([0-9a-fA-F]{4})\.s32", member)
    if not match:
        return None
    return [(int(match[1], 16) - 0x7e00) * 64 + x / 2,
            (int(match[2], 16) - 0x7e00) * 64 + y]


def target_candidates(packed):
    value = packed & 0xffffffff
    signed = lambda v: v - 65536 if v & 32768 else v
    return {
        PRIMARY_TARGET_MODE: [32768 + signed(value & 65535) / 2, 32768 + signed(value >> 16)],
        TARGET_MODES[1]: [(value & 65535) / 2, 32768 + signed(value >> 16)],
        TARGET_MODES[2]: [(value & 65535) / 2, 32768 + (value >> 16)],
    }


def extract_named(decoded):
    """Retain every named record at its exact original absolute byte offset."""
    raw = decoded["uninterpreted_tail"]
    if not raw:
        return [], {"named_count": 0, "named_count_present": False, "remaining_bytes": 0,
                    "remaining_sha256": codec.sha256(b"")}
    if len(raw) < 2:
        raise ValueError("Truncated named tail count: " + decoded["member"])
    count, = struct.unpack_from("<H", raw)
    cursor = 2
    if count > (len(raw) - cursor) // 9:
        raise ValueError("Unbounded named tail count: " + decoded["member"])
    records = []
    for index in range(count):
        start = cursor
        if cursor >= len(raw):
            raise ValueError("Truncated named tail label")
        size = raw[cursor]
        cursor += 1
        if size + 8 > len(raw) - cursor:
            raise ValueError("Truncated named tail record")
        label = raw[cursor:cursor + size]
        cursor += size
        x, y, target, packed = struct.unpack_from("<BBHi", raw, cursor)
        cursor += 8
        offset = decoded["core_end"] + start
        record = {"id": decoded["member"] + "@" + str(offset), "member": decoded["member"],
                  "source_sha256": decoded["source_sha256"], "source_bytes": decoded["source_bytes"],
                  "source_byte_offset": offset, "named_record_index": index,
                  "raw_label_base64": base64.b64encode(label).decode("ascii"),
                  "label_ascii_candidate": label.decode("ascii", errors="backslashreplace"),
                  "raw_x_u8": x, "raw_y_u8": y, "raw_target_u16": target,
                  "raw_packed_i32": packed, "raw_packed_u32": packed & 0xffffffff,
                  "raw_hex": raw[start:cursor].hex(),
                  "source_xy_candidate": source_candidate(decoded["member"], x, y),
                  "target_xy_candidates": target_candidates(packed)}
        records.append(record)
    return records, {"named_count": count, "named_count_present": True,
                     "named_count_source_byte_offset": decoded["core_end"],
                     "remaining_source_byte_offset": decoded["core_end"] + cursor,
                     "remaining_bytes": len(raw) - cursor,
                     "remaining_sha256": codec.sha256(raw[cursor:])}


def contains(territory, point):
    return (min(territory["StartX"], territory["EndX"]) <= point[0] <= max(territory["StartX"], territory["EndX"])
            and min(territory["StartY"], territory["EndY"]) <= point[1] <= max(territory["StartY"], territory["EndY"]))


def endpoint_support(position, land_id, members):
    # A verified member is only a source-presence check. Source-field policy is
    # separate and must still accept the actual cell and clear endpoint flags.
    if land_id != 4 or position is None or any(type(v) not in (int, float) or int(v) != v or v < 0 for v in position):
        return {"s32_member_verified": False, "member": None}
    x, y = map(int, position)
    member = f"Map/Aden/{x // 64 + 0x7e00:04x}{y // 64 + 0x7e00:04x}.s32"
    row = members.get(member)
    return {"s32_member_verified": row is not None, "member": member,
            "sha256": row["sha256"] if row else None}


def join_portals(lands, territories, portals, records, members):
    """Join namespaces first, then exact source and destination tests; no repair."""
    if lands.get(4, {}).get("AssetPath") != "Aden/":
        raise ValueError("Native Land4 does not declare Aden/")
    aden = [row for row in portals.values() if row.get("SourceLandID") == 4]
    by_target = {}
    for portal in aden:
        if portal.get("TargetTerritoryID") not in territories:
            raise ValueError("Missing native target territory")
        territory = territories[portal["TargetTerritoryID"]]
        if territory.get("LandID") not in lands:
            raise ValueError("Missing native target Land")
        for value in [portal.get("SourceX"), portal.get("SourceY"), *(territory.get(key) for key in ("StartX", "StartY", "EndX", "EndY"))]:
            if type(value) is not int:
                raise ValueError("Invalid native portal coordinate")
        by_target.setdefault(territory["LandID"], []).append(portal)
    raw_for_portal = {row["ID"]: [] for row in aden}
    for record in records:
        # Raw target 4 resolves through Land[4] -> Aden/, never the literal 4/.
        target_id = record["raw_target_u16"]
        candidates = by_target.get(target_id, []) if target_id in lands else []
        record["target_land_declaration"] = lands.get(target_id)
        record["namespace_pair_portal_ids"] = [row["ID"] for row in candidates]
        exact = [row for row in candidates if [row["SourceX"], row["SourceY"]] == record["source_xy_candidate"]]
        record["exact_source_portal_ids"] = [row["ID"] for row in exact]
        record["destination_containing_portal_ids"] = {
            mode: [row["ID"] for row in exact if contains(territories[row["TargetTerritoryID"]], point)]
            for mode, point in record["target_xy_candidates"].items()}
        for portal in exact:
            raw_for_portal[portal["ID"]].append(record)
    result = []
    for portal in sorted(aden, key=lambda row: row["ID"]):
        territory = territories[portal["TargetTerritoryID"]]
        target_land = lands[territory["LandID"]]
        matched = raw_for_portal[portal["ID"]]
        valid = [record for record in matched if portal["ID"] in record["destination_containing_portal_ids"][PRIMARY_TARGET_MODE]]
        point = [territory["StartX"], territory["StartY"]] if territory["StartX"] == territory["EndX"] and territory["StartY"] == territory["EndY"] else None
        source = [portal["SourceX"], portal["SourceY"]]
        source_support = endpoint_support(source, 4, members)
        target_support = endpoint_support(point, territory["LandID"], members)
        blockers = []
        if not matched: blockers.append("no_exact_source_and_namespace_raw_record")
        elif not valid: blockers.append("raw_destination_outside_declared_territory")
        if len(valid) > 1: blockers.append("ambiguous_raw_endpoint_records")
        if point is None: blockers.append("target_rectangle_has_no_verified_exact_landing")
        if territory["LandID"] != 4: blockers.append("target_land_source_not_supplied")
        if not source_support["s32_member_verified"]: blockers.append("source_s32_not_verified")
        if not target_support["s32_member_verified"]: blockers.append("target_s32_not_verified")
        result.append({"id": portal["ID"], "portal": portal, "source_land": lands[4],
                       "target_territory": territory, "target_land": target_land,
                       "source_position": source, "landing_position": point,
                       "landing_basis": "native_singleton_territory" if point is not None else "UNKNOWN",
                       "source_support": source_support, "target_support": target_support,
                       "exact_source_raw_record_ids": [r["id"] for r in matched],
                       "matched_raw_record_ids": [r["id"] for r in valid],
                       "raw_endpoint_match": len(valid) == 1,
                       "activation_candidate": not blockers, "activation_eligible": False,
                       "blockers": blockers, "runtime_requirements": list(RUNTIME_REQUIREMENTS)})
    return result


def build_contract(pack_root, evidence_root):
    pack_root, evidence_root = Path(pack_root), Path(evidence_root)
    if pack_root.is_symlink() or evidence_root.is_symlink():
        raise ValueError("Input roots must not be symlinks")
    manifest, manifest_raw = read_json(_regular_child(pack_root, codec.MANIFEST_NAME))
    codec.validate_manifest(manifest)
    artifact_manifest, artifact_raw = read_json(_regular_child(evidence_root, "artifact_manifest.json"))
    if not isinstance(artifact_manifest, list):
        raise ValueError("Invalid supplied artifact manifest")
    artifacts = {row["path"]: row for row in artifact_manifest}
    tables, provenance = {}, {}
    for name, expected in INPUTS.items():
        relative = "inputs/" + name + ".json"
        value, raw = read_json(_regular_child(evidence_root, relative))
        proof = artifacts.get(relative, {})
        digest = codec.sha256(raw)
        if digest != expected or proof.get("sha256") != digest or proof.get("bytes") != len(raw):
            raise ValueError("Native input SHA256/manifest mismatch: " + name)
        if not isinstance(value, dict):
            raise ValueError("Invalid native rows object: " + name)
        tables[name] = _indexed(value.get("rows"), name)
        provenance[name] = {"path": relative, "bytes": len(raw), "sha256": digest, "rows": len(tables[name])}
    records, tails, members = [], [], {}
    for metadata in manifest["members"]:
        data = _bounded_source(_regular_child(pack_root, metadata["path"]))
        if len(data) != metadata["bytes"] or codec.sha256(data) != metadata["sha256"]:
            raise ValueError("Original source size/SHA256 mismatch: " + metadata["member"])
        decoded = codec.read_s32(data, metadata["member"])
        if decoded["sections"] != metadata["sections"] or codec.write_s32(decoded) != data:
            raise ValueError("Lossless source partition mismatch: " + metadata["member"])
        members[metadata["member"]] = metadata
        named, tail = extract_named(decoded)
        records.extend(named)
        if named:
            tails.append({"member": metadata["member"], "source_sha256": metadata["sha256"],
                          "tail": metadata["sections"]["tail"], **tail})
    portals = join_portals(tables["Land"], tables["Territories"], tables["Portal"], records, members)
    stats = {"verified_source_members": len(members), "native_land4_portals": len(portals),
             "named_raw_records": len(records),
             "namespace_pair_eligible_records": sum(bool(r["namespace_pair_portal_ids"]) for r in records),
             "exact_source_records": sum(bool(r["exact_source_portal_ids"]) for r in records),
             "target_containment_records": {mode: sum(bool(r["destination_containing_portal_ids"][mode]) for r in records) for mode in TARGET_MODES},
             "aden_internal_exact_source_records": sum(r["raw_target_u16"] == 4 and bool(r["exact_source_portal_ids"]) for r in records),
             "aden_internal_endpoint_matched_records": sum(r["raw_target_u16"] == 4 and bool(r["destination_containing_portal_ids"][PRIMARY_TARGET_MODE]) for r in records),
             "activation_candidates": sum(p["activation_candidate"] for p in portals), "activated_portals": 0,
             "blockers": dict(Counter(reason for p in portals for reason in p["blockers"]))}
    return {"schema": SCHEMA, "edition": "LineageM", "cumulative_version": 523,
            "land_id": 4, "asset_path": "Aden/", "source_inventory_sha256": codec.SOURCE_INVENTORY_SHA256,
            "delivery_status": "PRIVATE_LOCAL_ONLY", "primary_target_mode": PRIMARY_TARGET_MODE,
            "qualification": "Exact native declaration comparisons qualify individual raw records only. Coordinate hypotheses, member presence and raw attributes do not prove native movement or collision. Runtime must verify both source-field endpoints and clear flags before activation.",
            "native_inputs": provenance,
            "source_manifest": {"sha256": codec.sha256(manifest_raw), "bytes": len(manifest_raw)},
            "supplied_artifact_manifest": {"sha256": codec.sha256(artifact_raw), "bytes": len(artifact_raw)},
            "counts": stats, "portals": portals, "raw_records": records, "named_tail_members": tails,
            "runtime_requirements": list(RUNTIME_REQUIREMENTS), "cost_policy": "No fee or consumption declared by these Portal rows; no cost is inferred from other tables."}


def write_private(contract, output):
    output = Path(output).expanduser()
    if output.is_symlink() or output.exists():
        raise ValueError("Output already exists")
    output = output.resolve()
    if any(_is_repository(parent) for parent in (output.parent, *output.parent.parents)):
        raise ValueError("Private native portal output must be outside Git repositories")
    encoded = (json.dumps(contract, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    if len(encoded) > MAX_JSON_BYTES:
        raise ValueError("Oversized portal contract")
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=output.parent, prefix=".aden-portals-", delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(encoded)
        os.link(temporary, output)  # Atomic publication without replacing another writer.
    finally:
        if temporary is not None: temporary.unlink(missing_ok=True)
    return {"path": str(output), "bytes": len(encoded), "sha256": codec.sha256(encoded), "counts": contract["counts"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pack-root", required=True)
    parser.add_argument("--evidence-root", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    print(json.dumps(write_private(build_contract(args.pack_root, args.evidence_root), args.output), indent=2))


if __name__ == "__main__":
    main()
