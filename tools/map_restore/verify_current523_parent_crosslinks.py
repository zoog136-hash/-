#!/usr/bin/env python3
"""Read-only verification of the parent map-crosslink handoff against Aden523.

Prints a receipt to stdout; changes no resource, source, loader, or original.
Only the 31 supplied Aden originals are independently reread here. The other
19 records retain their external-source/retained508 metadata provenance.
"""
import argparse
import base64
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile

import current523_s32 as codec

ARCHIVE_BYTES = 389919
ARCHIVE_SHA256 = "7fa773dfa1e040ba6afc9eed917b90f1a6bbca4cd64fbef44b0b85fe3697c71f"
CONTRACT_SHA256 = "350176c5a55d349ec1b4e0b861b29b48499c9b5c32471c89b3ef86d03ea19767"
INPUT_SHA256 = {
    "Land": "8778d18d8c23a0ccb0a555f495e056987796232c616dec805dfb4c4d633b0ef9",
    "Portal": "af434065337cfd2b8c3fab9887ce5d3569ce6651d122a05288769d487df78a45",
    "Territories": "2ef6e702e46204f8fd233ede612890ec20eadbbd16189bc02b04df3a58f4cc3b",
}
MAX_JSON_BYTES = 12 * 1024 * 1024
RAW_KEYS = ("raw_label_base64", "raw_x_u8", "raw_y_u8", "raw_target_u16", "raw_packed_i32", "raw_hex")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def read_bytes(path, maximum=MAX_JSON_BYTES):
    path = Path(path)
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= maximum,
            "Expected bounded regular input: " + str(path))
    data = path.read_bytes()
    require(len(data) <= maximum, "Input grew beyond limit: " + str(path))
    return data


def read_json(path):
    return json.loads(read_bytes(path).decode("utf-8-sig"))


def index(rows, key, label):
    result = {}
    for row in rows:
        value = key(row)
        require(value not in result, "Duplicate " + label + ": " + str(value))
        result[value] = row
    return result


def record_key(row):
    return row["member"], row["source_byte_offset"]


def decode_record(record):
    """Independently decode the supplied full raw named record, including label."""
    raw = bytes.fromhex(record["raw_hex"])
    require(bool(raw) and len(raw) == 1 + raw[0] + 8, "Invalid raw named-record length")
    label = raw[1:1 + raw[0]]
    x, y, target, packed = struct.unpack_from("<BBHi", raw, 1 + raw[0])
    fields = {"raw_label_base64": base64.b64encode(label).decode("ascii"),
              "raw_x_u8": x, "raw_y_u8": y, "raw_target_u16": target,
              "raw_packed_i32": packed, "raw_hex": raw.hex()}
    require(all(record.get(key) == value for key, value in fields.items()), "Raw named-record fields disagree")
    match = re.fullmatch(r"Map/([^/]+)/([0-9a-fA-F]{4})([0-9a-fA-F]{4})\.s32", record["member"])
    require(match is not None, "Nonstandard member cannot supply a coordinate candidate")
    source = [(int(match[2], 16) - 0x7e00) * 64 + x / 2,
              (int(match[3], 16) - 0x7e00) * 64 + y]
    low, high = struct.unpack("<hh", struct.pack("<i", packed))
    return raw, match[1] + "/", source, [32768 + low / 2, 32768 + high]


def contains(territory, point):
    return (min(territory["StartX"], territory["EndX"]) <= point[0] <= max(territory["StartX"], territory["EndX"])
            and min(territory["StartY"], territory["EndY"]) <= point[1] <= max(territory["StartY"], territory["EndY"]))


def relations(record, lands, territories, portals):
    raw, asset, source, target = decode_record(record)
    exact = []
    for portal in portals.values():
        source_land = lands[portal["SourceLandID"]]
        if source_land["AssetPath"] != asset or [portal["SourceX"], portal["SourceY"]] != source:
            continue
        territory = territories[portal["TargetTerritoryID"]]
        exact.append({"Portal": portal, "SourceLand": source_land,
                      "TargetTerritory": territory, "TargetLand": lands[territory["LandID"]]})
    direct = [row for row in exact if row["TargetLand"]["ID"] == record["raw_target_u16"]]
    numeric = [row for row in exact if row["TargetLand"]["AssetPath"] == str(record["raw_target_u16"]) + "/"]
    contained = [row["Portal"]["ID"] for row in direct if contains(row["TargetTerritory"], target)]
    return raw, asset, source, target, exact, direct, numeric, contained


def _verify_delivery(root, archive):
    archive_raw = read_bytes(archive)
    require(len(archive_raw) == ARCHIVE_BYTES and sha(archive_raw) == ARCHIVE_SHA256, "Parent archive size/SHA256 mismatch")
    with zipfile.ZipFile(archive) as zipped:
        require(zipped.testzip() is None, "Parent archive CRC failure")
        archive_members = set(zipped.namelist())
        manifest = read_json(root / "DELIVERY_MANIFEST.json")
        files = manifest["files"]
        index(files, lambda row: row["path"], "delivery path")
        for proof in files:
            relative = proof["path"]
            require(not Path(relative).is_absolute() and all(part not in ("", ".", "..") for part in relative.split("/")), "Unsafe delivery path")
            raw = read_bytes(root / relative)
            require(len(raw) == proof["bytes"] and sha(raw) == proof["sha256"], "Handoff member size/SHA mismatch: " + relative)
            require(relative in archive_members and zipped.read(relative) == raw, "Extracted handoff differs from pinned archive: " + relative)
        require(zipped.read("DELIVERY_MANIFEST.json") == read_bytes(root / "DELIVERY_MANIFEST.json"), "Extracted delivery manifest differs from archive")
    return {"bytes": len(archive_raw), "sha256": sha(archive_raw), "CRC": "PASS",
            "manifest_files_verified": len(files), "manifest_payload_bytes": sum(row["bytes"] for row in files)}


def _named_offsets(decoded):
    tail = decoded["uninterpreted_tail"]
    require(len(tail) >= 2, "Missing named tail count")
    count, = struct.unpack_from("<H", tail)
    cursor, found = 2, {}
    require(count <= (len(tail) - 2) // 9, "Unbounded named tail count")
    for _ in range(count):
        require(cursor < len(tail), "Truncated named label")
        start = cursor
        cursor += 1 + tail[cursor] + 8
        require(cursor <= len(tail), "Truncated named record")
        found[decoded["core_end"] + start] = tail[start:cursor]
    return found


def verify(root, archive, native_inputs, pack_root, contract_path):
    root, native_inputs, pack_root = Path(root), Path(native_inputs), Path(pack_root)
    delivery = _verify_delivery(root, Path(archive))
    target = root / "target4_namespace"
    tables, table_proofs = {}, {}
    for name, expected in INPUT_SHA256.items():
        raw = read_bytes(native_inputs / (name + ".json"))
        require(sha(raw) == expected, "Native table SHA256 mismatch: " + name)
        rows = json.loads(raw.decode("utf-8-sig"))["rows"]
        tables[name] = index(rows, lambda row: row["ID"], "native " + name + " ID")
        table_proofs[name] = {"member": "content/" + name + ".json", "bytes": len(raw), "sha256": sha(raw), "rows": len(rows)}
    for name in ("current_M_table_identity.json", "independent_review/independent_current_M_table_identity.json"):
        for identity in read_json(target / name):
            table = Path(identity["member"]).stem
            require(all(identity.get(key) == value for key, value in table_proofs[table].items()), "Handoff current table identity differs: " + table)
    lands, territories, portals = tables["Land"], tables["Territories"], tables["Portal"]
    require(lands[4]["AssetPath"] == "Aden/", "Native Land4 must resolve to Aden/")
    contract_raw = read_bytes(contract_path)
    require(sha(contract_raw) == CONTRACT_SHA256, "Pinned portal contract changed")
    contract = json.loads(contract_raw)
    compiled = index(contract["raw_records"], record_key, "compiled raw record")
    compiled_portals = index(contract["portals"], lambda row: row["id"], "compiled Portal ID")
    manifest = codec.validate_manifest(read_json(pack_root / codec.MANIFEST_NAME))
    members = {row["member"]: row for row in manifest["members"]}
    rows = read_json(target / "new50_target4_to_M_Land4_Aden_candidates.json")
    proofs = index(read_json(target / "new50_fresh_original_record_and_source_proofs.json"), record_key, "fresh proof")
    independent = index(read_json(target / "independent_review/independent_new50_records.json"), record_key, "independent record")
    independent_proofs = index(read_json(target / "independent_review/independent_new50_raw_proofs.json"), record_key, "independent raw proof")
    row_index = index(rows, lambda row: record_key(row["raw_record"]), "new50 record")
    require(len(rows) == 50 and set(row_index) == set(proofs) == set(independent) == set(independent_proofs), "All50 record/proof key sets must agree")
    require(read_json(target / "independent_review/independent_published_output_differences.json") == []
            and read_json(target / "independent_review/independent_published_raw_proof_differences.json") == [], "Independent review differences exist")
    scope, actual, report = set(), {}, []
    for row in rows:
        record = row["raw_record"]
        key = record_key(record)
        raw, asset, source, destination, exact, direct, numeric, contained = relations(record, lands, territories, portals)
        require(record["raw_target_u16"] == 4 and len(exact) == len(direct) == 1 and numeric == [], "New50 namespace qualification changed: " + str(key))
        relation = direct[0]
        portal, territory = relation["Portal"], relation["TargetTerritory"]
        portal_id = portal["ID"]
        require(row["source_asset_path"] == asset and row["source_coordinate_candidate"] == source
                and row["signed_packed_target_coordinate_candidate"] == destination
                and row["M_source_coordinate_exact_Portals"] == exact
                and row["direct_LandID_target_candidate_PortalIDs"] == [portal_id]
                and row["numeric_AssetPath_target_candidate_PortalIDs"] == []
                and row["direct_LandID_candidate_target_containment_PortalIDs"] == contained
                and row["new_direct_LandID_not_numeric_AssetPath_candidate"] is True, "Published join differs from current native rows: " + str(key))
        proof, independent_proof, reviewed = proofs[key], independent_proofs[key], independent[key]
        require(proof["raw_record_hex"] == raw.hex() and proof["raw_record_sha256"] == sha(raw)
                and proof["fields_fresh_read_match"] is True
                and 0 <= key[1] <= proof["bytes"] - len(raw), "Fresh raw proof differs: " + str(key))
        require(independent_proof["raw_fields"] == {k: record[k] for k in RAW_KEYS}
                and independent_proof["raw_record_sha256"] == sha(raw)
                and independent_proof["record_bytes"] == len(raw)
                and independent_proof["record_end_exclusive"] == key[1] + len(raw)
                and independent_proof["member_sha256_fresh"] == proof["member_sha256"]
                and independent_proof["member_bytes_fresh"] == proof["bytes"]
                and independent_proof["ledger_container"] == proof["container"]
                and independent_proof["current_expected_DAT_SHA1"] == proof["current_expected_DAT_SHA1"]
                and independent_proof["ledger_evidence_level"] == proof["evidence_level"]
                and independent_proof["current_full_DAT_SHA1_freshly_rehashed"] == proof["current_DAT_SHA1_freshly_rehashed"], "Independent raw proof differs: " + str(key))
        expected_review = {"source_asset_path": asset, "source_xy_candidate": source,
                           "raw_target_u16": 4, "source_Portals": [portal_id],
                           "source_LogicalLandIDs": [portal["SourceLandID"]],
                           "all_table_LogicalLandIDs_sharing_source_AssetPath": sorted(land["ID"] for land in lands.values() if land["AssetPath"] == asset),
                           "numeric_AssetPath_PortalIDs": [], "direct_LandID_PortalIDs": [portal_id],
                           "direct_LandID_source_LogicalLandIDs": [portal["SourceLandID"]],
                           "packed_target_xy_candidate": destination, "contained_PortalIDs": contained, "new": True}
        require(all(reviewed.get(k) == value for k, value in expected_review.items()), "Independent native relation differs: " + str(key))
        scope.update((("Portal", portal_id), ("Land", portal["SourceLandID"]),
                      ("Land", territory["LandID"]), ("Territories", territory["ID"])))
        internal = asset == "Aden/"
        if internal:
            require(proof["evidence_level"] == "fresh_current_DAT_SHA1_and_member_bytes"
                    and proof["current_DAT_SHA1_freshly_rehashed"] is True, "Internal handoff provenance changed")
            metadata = members[record["member"]]
            require(metadata["sha256"] == proof["member_sha256"] and metadata["bytes"] == proof["bytes"]
                    and metadata["source_container"] == proof["container"], "Handoff source/member identity differs")
            if record["member"] not in actual:
                original = read_bytes(pack_root / metadata["path"], codec.MAX_BYTES)
                require(sha(original) == metadata["sha256"] and len(original) == metadata["bytes"], "Actual Aden original digest mismatch")
                decoded = codec.read_s32(original, metadata["member"])
                require(decoded["sections"] == metadata["sections"] and codec.write_s32(decoded) == original, "Aden lossless partition mismatch")
                actual[record["member"]] = _named_offsets(decoded)
            require(actual[record["member"]].get(key[1]) == raw, "Raw record is not at actual named-record boundary")
            compiled_raw, compiled_portal = compiled[key], compiled_portals[portal_id]
            require(all(compiled_raw[k] == record[k] for k in RAW_KEYS)
                    and compiled_raw["source_sha256"] == proof["member_sha256"]
                    and compiled_portal["portal"] == portal and compiled_portal["target_territory"] == territory
                    and compiled_portal["activation_candidate"] == bool(contained), "Pinned Aden contract differs from new parent evidence")
            if portal_id == 350:
                require(destination == [34278,32224] and [territory["StartX"],territory["StartY"]] == [34275,32222]
                        and not contained and "raw_destination_outside_declared_territory" in compiled_portal["blockers"], "Portal350 mismatch was corrected or lost")
        else:
            require(proof["evidence_level"] == "current_selected_retained508_original_member"
                    and proof["current_DAT_SHA1_freshly_rehashed"] is False, "External retained508 provenance changed")
            require(record["member"] not in members and not (pack_root / "originals" / record["member"]).exists(), "External source availability must be reviewed separately")
            require(portal_id not in compiled_portals and key not in compiled, "External source record must not become an Aden activation candidate")
        report.append({"member": key[0], "source_byte_offset": key[1], "member_sha256": proof["member_sha256"],
                       "raw_record_sha256": sha(raw), "portal_id": portal_id,
                       "source_land_id": portal["SourceLandID"], "target_territory_id": territory["ID"],
                       "source_position": source, "raw_destination_candidate": destination,
                       "declared_destination_bounds": [territory[k] for k in ("StartX","StartY","EndX","EndY")],
                       "destination_contained": bool(contained), "provenance": proof["evidence_level"],
                       "local_original_reread": internal,
                       "runtime_status": "existing_static_candidate_requires_both_field_endpoints" if internal and contained else "blocked_raw_destination_mismatch" if internal else "metadata_only_external_source_not_supplied"})
    lineage = read_json(target / "new50_current_vs_comparison508_declaration_lineage.json")
    lineage_rows = index(lineage["rows"], lambda row: (row["table"], row["ID"]), "lineage table row")
    require(set(lineage_rows) == scope and len(scope) == 113, "113 unique linked native rows must cover exact relation scope")
    for (table, row_id), row in lineage_rows.items():
        require(row["equal_508_to_current523"] is True and row["base508_row"] == row["current523_row"] == tables[table][row_id], "Scoped current508 lineage row disagrees: " + str((table,row_id)))
    internal_rows = [row for row in report if row["local_original_reread"]]
    expected_candidates = {row["portal_id"] for row in internal_rows if row["destination_contained"]}
    require(expected_candidates == {row["id"] for row in contract["portals"] if row["activation_candidate"]}, "Internal30 candidate set differs")
    require(len(internal_rows) == 31 and len(expected_candidates) == 30
            and sum(row["destination_contained"] for row in report) == 42, "Parent50/internal31/contained42 counts changed")
    obstacles = read_json(root / "obstacle_cells/obstacle_disjoint_schema_comparison.json")["statistics"]
    gates = read_json(root / "obstacle_cells/gate_length_nooccupy_comparison.json")["statistics"]
    interactions = read_json(root / "obstacle_cells/interaction_cells_are_separate.json")["statistics"]
    typed = read_json(root / "movement_states/all10_typed_movement_state_declarations_and_units.json")
    bonuses = read_json(root / "movement_states/all_selected_bonus_rows_and_explicit_owner_links.json")
    boundaries = {"obstacle": obstacles, "gate": gates, "interaction_cell": interactions,
                  "typed_movement_declarations": len(typed), "bonus_rows": len(bonuses["selected_bonus_rows"]),
                  "explicit_bonus_owner_links": len(bonuses["explicit_links"]),
                  "native_collision_meaning": "UNVERIFIED", "runtime_rules_changed": False}
    require(obstacles["classes"] == 139 and obstacles["categories"] == {"BuffProvider":139}
            and obstacles["values"] == {"2":139} and gates["gate_classes"] == 27
            and gates["nooccupy_values"] == {"1":7,"0":20}
            and interactions["referencing_categories"] == {"DynamicPortal":28}
            and interactions["nonzero_territory_spawn_rows"] == 0
            and len(typed) == 10 and boundaries["bonus_rows"] == 178 and boundaries["explicit_bonus_owner_links"] == 173,
            "Handoff typed-boundary counts changed")
    require(sha(read_bytes(contract_path)) == CONTRACT_SHA256, "Portal contract changed during read-only verification")
    return {"status":"PASS", "archive":delivery, "all50_rows_read_and_rejoined":len(report),
            "distinct_source_members":len({row["member"] for row in report}),
            "internal_Aden_records":len(internal_rows), "internal_original_members_reread":len(actual),
            "internal_static_candidates_unchanged":sorted(expected_candidates), "Portal350_mismatch_preserved":True,
            "external_records_metadata_only":50-len(internal_rows),
            "provenance_counts":dict(Counter(row["provenance"] for row in report)),
            "linked_current_native_rows_verified":{name:sum(table == name for table, _ in scope) for name in ("Portal","Land","Territories")},
            "linked_current_native_row_total":len(scope), "packed_target_contained_records":42,
            "native_table_identities":table_proofs, "contract_sha256_unchanged":CONTRACT_SHA256,
            "boundaries":boundaries, "records":report,
            "qualification":"This consumer reread 31 Aden original records. External 19 originals, comparison 508 archives and whole DAT containers were not reread here. Parent and independent provenance remain separate. No runtime activation, collision, trigger, fee, typed state priority or new delivery is established."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--handoff-dir", required=True)
    parser.add_argument("--archive", required=True)
    parser.add_argument("--native-inputs", required=True)
    parser.add_argument("--pack-root", required=True)
    parser.add_argument("--contract", required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.handoff_dir,args.archive,args.native_inputs,args.pack_root,args.contract), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
