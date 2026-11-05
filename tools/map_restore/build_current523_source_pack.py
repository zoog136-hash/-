#!/usr/bin/env python3
"""Validate or build private generic LineageM523 raw map packs.

The Land table is independently pinned. The caller must separately pin the
complete input inventory JSON SHA256; a self-declared member hash is not source
identity. This parser preserves actual S32 member names and raw sections. SEG
is retained as unsupported and is never passed to the S32 parser.

Inventory: {schema:1, edition:"LineageM", cumulative_version:523,
 asset_paths:[exact native AssetPath strings], members:[{member,asset_path,
 bytes,sha256,availability:"present"|"missing",provenance:{snapshot_version:523,
 container,selection_version,evidence_level,current_selection_verified,
 expected_member_sha256}}],
 land_policy:[{land_id,excluded_content:["arena"|"ziggurat"|"guild"|"siege"],
 provenance:{source:<explicit policy source>}}]}.
Only selected asset roots are required to match the inventory exactly. A
validate-only run writes nothing. --output publishes unchanged originals plus
source523.json outside Git, without replacing an existing directory.
Canonical .s32.gz storage keeps original member/bytes/sha256/sections and adds
storage_format=gzip, stored_bytes and stored_sha256. Raw inventories and packs
remain unchanged. --gzip-inputs is a separate, explicit stable-input operation
with per-member rollback; it never rewrites old private pack hardlinks.
"""
import argparse
import hashlib
import gzip
import json
import os
from pathlib import Path
import re
import shutil
import struct
import tempfile
import zipfile
import zlib

LAND_SHA256 = "8778d18d8c23a0ccb0a555f495e056987796232c616dec805dfb4c4d633b0ef9"
FULL_HANDOFF_SHA256 = "ef9728b3ff364a3930668f80ab8c6edae93c86d036b7c0772760c25305e86366"
FULL_HANDOFF_BYTES = 2637379
MANIFEST_NAME = "source523.json"
KIND = "current523_s32_source_pack"
MAX_SOURCE_BYTES = 8 * 1024 * 1024
MAX_STORED_BYTES = MAX_SOURCE_BYTES + 65536
MAX_METADATA_BYTES = 24 * 1024 * 1024
MAX_MEMBERS = 20000
MIN_S32_BYTES = 49166
SECTION_NAMES = ("floor", "covers", "attributes", "objects", "opacity", "declared", "tail")
SEMANTICS = dict.fromkeys(("coordinates", "projection", "movement", "collision", "height", "regions", "zones", "safety_combat", "drawing_order"), "UNKNOWN")
EXCLUSIONS = {"arena", "ziggurat", "guild", "siege"}
_ASSET = re.compile(r"[A-Za-z0-9_-]+/?\Z")
_MEMBER = re.compile(r"Map/([A-Za-z0-9_-]+)/([A-Za-z0-9_-]+)\.(s32|seg)\Z")
_SHA = re.compile(r"[0-9a-f]{64}\Z")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def require(condition, message):
    if not condition: raise ValueError(message)


def integer(value, maximum=MAX_SOURCE_BYTES, minimum=0):
    require(type(value) is int and minimum <= value <= maximum, "Invalid bounded integer")
    return value


def digest(value):
    require(isinstance(value, str) and _SHA.fullmatch(value), "Invalid SHA256")
    return value


def asset_root(asset):
    require(isinstance(asset, str) and _ASSET.fullmatch(asset), "Unsafe literal AssetPath")
    return "Map/" + asset.rstrip("/") + "/"


def member_name(member, asset=None):
    require(isinstance(member, str) and len(member) <= 256 and _MEMBER.fullmatch(member), "Unsafe literal source member")
    if asset is not None: require(member.startswith(asset_root(asset)), "Member does not match exact AssetPath binding")
    return member


def candidate_origin(member):
    member_name(member)
    stem = Path(member).stem
    if not re.fullmatch(r"[0-9a-fA-F]{8}", stem): return None
    return [(int(stem[:4], 16) - 0x7e00) * 64, (int(stem[4:], 16) - 0x7e00) * 64]


def _pairs(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key")
        result[key] = value
    return result


def read_json(path):
    path = Path(path)
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= MAX_METADATA_BYTES, "Expected bounded regular JSON")
    with path.open("rb") as handle: raw = handle.read(MAX_METADATA_BYTES + 1)
    require(len(raw) <= MAX_METADATA_BYTES, "Metadata grew beyond bound")
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=_pairs), raw


def source_bytes(path, expected_size):
    require(path.stat().st_size == expected_size, "Source size differs from pinned inventory")
    with path.open("rb") as handle: data = handle.read(MAX_SOURCE_BYTES + 1)
    require(len(data) == expected_size, "Source changed size during bounded read")
    return data


def decode_gzip(data, expected_size):
    """One fixed-header gzip member, bounded output, strict EOF and no suffix."""
    integer(expected_size,minimum=1)
    require(isinstance(data,bytes) and 18 <= len(data) <= MAX_STORED_BYTES, "Gzip stored size outside bounds")
    require(data[:4] == b"\x1f\x8b\x08\x00", "Unsupported gzip header or flags")
    require(struct.unpack_from("<I",data,len(data)-4)[0] == expected_size, "Gzip ISIZE differs from original size")
    decoder = zlib.decompressobj(31)
    try:
        raw = decoder.decompress(data,expected_size+1)
    except zlib.error as exc:
        raise ValueError("Invalid gzip stream") from exc
    require(len(raw) == expected_size and decoder.eof and not decoder.unused_data and not decoder.unconsumed_tail,
            "Gzip output size, EOF, trailing or concatenated stream mismatch")
    return raw


def storage_payload(path, maximum=MAX_STORED_BYTES):
    require(path.is_file() and not path.is_symlink() and 0 < path.stat().st_size <= maximum, "Invalid stored source size or path")
    size = path.stat().st_size
    with path.open("rb") as handle: data = handle.read(maximum+1)
    require(len(data) == size, "Stored source changed during bounded read")
    return data


def storage_metadata(row):
    """The original member is always canonical; only its stored suffix varies."""
    member_name(row["member"])
    fmt = row.get("storage_format","raw")
    require(fmt in ("raw","gzip"), "Unknown source storage format")
    if fmt == "gzip":
        require(row["member"].endswith(".s32"), "SEG gzip storage is unsupported")
        integer(row.get("stored_bytes"),MAX_STORED_BYTES,18)
        digest(row.get("stored_sha256"))
        return {"storage_format":"gzip","stored_bytes":row["stored_bytes"],"stored_sha256":row["stored_sha256"]}
    if any(key in row for key in ("stored_bytes","stored_sha256")):
        require(row.get("stored_bytes") == row["bytes"] and row.get("stored_sha256") == row["sha256"], "Raw stored identity differs from original identity")
    return {"storage_format":"raw","stored_bytes":row["bytes"],"stored_sha256":row["sha256"]}


def verify_payload(data, row, storage):
    require(len(data) == storage["stored_bytes"] and sha(data) == storage["stored_sha256"], "Stored source size/SHA256 mismatch")
    raw = decode_gzip(data,row["bytes"]) if storage["storage_format"] == "gzip" else data
    require(len(raw) == row["bytes"] and sha(raw) == row["sha256"], "Original source size/SHA256 mismatch after storage decode")
    return raw


def canonical_source(source_dir, row):
    """Resolve only literal member or member+'.gz'; verify both if both exist."""
    member = member_name(row["member"])
    size, value = integer(row["bytes"],minimum=1), digest(row["sha256"])
    raw_path, gzip_path = Path(source_dir)/member, Path(source_dir)/(member+".gz")
    require(not raw_path.is_symlink() and not gzip_path.is_symlink(), "Symlink canonical source representation")
    raw = None
    result = None
    if raw_path.exists():
        path = regular_child(source_dir,member)
        raw = source_bytes(path,size)
        require(sha(raw) == value, "Original source SHA256 differs from pinned inventory")
        result = (raw,{"storage_format":"raw","stored_bytes":size,"stored_sha256":value},path,raw)
    if gzip_path.exists():
        require(member.endswith(".s32"), "Only canonical S32 gzip storage is supported")
        path = regular_child(source_dir,member+".gz")
        stored = storage_payload(path)
        decoded = decode_gzip(stored,size)
        require(sha(decoded) == value and (raw is None or raw == decoded), "Ambiguous or incorrect canonical raw/gzip identities")
        info = {"storage_format":"gzip","stored_bytes":len(stored),"stored_sha256":sha(stored)}
        result = (decoded,info,path,stored)
    require(result is not None, "Missing regular canonical source: "+member)
    if "storage_format" in row or "stored_bytes" in row or "stored_sha256" in row:
        require(storage_metadata(row) == result[1], "Stored representation differs from pinned input inventory")
    return result


def canonical_audit_member(relative):
    if relative.endswith(".s32.gz"): return member_name(relative[:-3])
    return member_name(relative)


def regular_child(root, relative):
    require(not Path(root).is_symlink(), "Symlink input root")
    current = Path(root)
    for part in relative.split("/"):
        require(part not in ("", ".", "..") and "\\" not in part, "Unsafe relative source path")
        current /= part
        require(not current.is_symlink(), "Symlink in source tree")
    require(current.is_file(), "Missing regular source: " + relative)
    return current


class Reader:
    def __init__(self, data):
        require(isinstance(data, bytes) and MIN_S32_BYTES <= len(data) <= MAX_SOURCE_BYTES, "S32 source size outside bounds")
        self.data, self.pos = data, 0
    def take(self, size):
        require(0 <= size <= len(self.data) - self.pos, "Truncated S32 record")
        start = self.pos
        self.pos += size
        return self.data[start:self.pos]
    def unpack(self, fmt):
        return struct.unpack("<" + fmt, self.take(struct.calcsize("<" + fmt)))
    def count(self, fmt, width, maximum, reserve=0):
        value, = self.unpack(fmt)
        require(value <= maximum and value <= (len(self.data) - self.pos - reserve) // width, "Unbounded S32 record count")
        return value


def read_s32(data, member):
    """Same bounded raw format as Aden, using the actual generic member identity."""
    member_name(member)
    require(member.endswith(".s32"), "SEG format unsupported; cannot decode as S32")
    reader = Reader(data)
    sections, raw_sections = {}, {}
    def section(name, start, **metadata):
        raw = data[start:reader.pos]
        sections[name] = {"offset": start, "bytes": len(raw), "sha256": sha(raw), **metadata}
        raw_sections[name] = raw
    reader.take(32768)
    section("floor", 0)
    start = reader.pos
    count = reader.count("H", 6, 65535, 16384 + 12)
    reader.take(count * 6)
    section("covers", start, count=count, records_offset=start + 2)
    start = reader.pos
    reader.take(16384)
    section("attributes", start)
    start = reader.pos
    count = reader.count("I", 4, 65535, 8)
    parts = 0
    for index in range(count):
        _, part_count = reader.unpack("HH")
        parts += part_count
        require(parts <= 262144 and part_count <= (len(data) - reader.pos - 4 * (count - index - 1) - 8) // 7, "Unbounded S32 object parts")
        reader.take(part_count * 7)
    section("objects", start, count=count, records_offset=start + 4, part_count=parts)
    for name, width, maximum, reserve in (("opacity", 5, 262144, 4), ("declared", 4, 65535, 0)):
        start = reader.pos
        count = reader.count("I", width, maximum, reserve)
        reader.take(count * width)
        section(name, start, count=count, records_offset=start + 4)
    core_end = reader.pos
    require(len(data) - core_end <= 1024 * 1024, "Oversized S32 opaque tail")
    reader.take(len(data) - core_end)
    section("tail", core_end)
    return {"member": member, "source_bytes": len(data), "source_sha256": sha(data),
            "core_end": core_end, "object_part_count": parts,
            "attribute_offset": sections["attributes"]["offset"],
            "attribute_sha256": sections["attributes"]["sha256"],
            "sections": sections, "raw_sections": raw_sections}


def write_s32(decoded):
    data = b"".join(decoded["raw_sections"][name] for name in SECTION_NAMES)
    reread = read_s32(data, decoded["member"])
    require(all(decoded[key] == reread[key] for key in reread), "Lossless S32 section/identity mismatch")
    return data


def inventory_digest(members):
    rows = sorted((member_name(row["member"]), integer(row["bytes"], minimum=1), digest(row["sha256"])) for row in members)
    require(len(rows) <= MAX_MEMBERS and len({row[0] for row in rows}) == len(rows), "Duplicate or excessive source members")
    return sha("".join(f"{member}\t{size}\t{value}\n" for member, size, value in rows).encode())


def _native_lands(path):
    value, raw = read_json(path)
    require(sha(raw) == LAND_SHA256, "Native Land table is not the independently pinned M523 input")
    rows = value.get("rows")
    require(isinstance(rows, list) and len(rows) == 1065, "Invalid native Land rows")
    lands = {}
    for row in rows:
        integer(row.get("ID"), maximum=2147483647)
        asset_root(row.get("AssetPath"))
        require(row["ID"] not in lands, "Duplicate native Land ID")
        lands[row["ID"]] = row
    return lands, {"bytes": len(raw), "sha256": sha(raw), "rows": len(lands)}


def prepare_manifest(source_dir, land_table, inventory_path, expected_inventory_sha256):
    """Verify exact originals and return metadata only; does not write any file."""
    digest(expected_inventory_sha256)
    inventory, inventory_raw = read_json(inventory_path)
    require(sha(inventory_raw) == expected_inventory_sha256, "Input inventory SHA256 differs from caller trust pin")
    require(inventory.get("schema") == 1 and type(inventory.get("schema")) is int and inventory.get("edition") == "LineageM"
            and type(inventory.get("cumulative_version")) is int and inventory["cumulative_version"] == 523, "Inventory must select native M cumulative523")
    lands, land_proof = _native_lands(land_table)
    assets = inventory.get("asset_paths")
    require(isinstance(assets, list) and 0 < len(assets) <= 2000 and len(set(assets)) == len(assets), "Invalid exact AssetPath selection")
    for asset in assets:
        asset_root(asset)
        require(any(row["AssetPath"] == asset for row in lands.values()), "AssetPath has no exact native Land declaration")
    roots = [asset_root(asset) for asset in assets]
    require(len(set(roots)) == len(roots), "Ambiguous AssetPath physical root aliases")
    policies = {}
    for policy in inventory.get("land_policy", []):
        land_id = integer(policy.get("land_id"), maximum=2147483647)
        flags = policy.get("excluded_content")
        require(land_id in lands and land_id not in policies
                and isinstance(flags, list) and len(set(flags)) == len(flags) and set(flags) <= EXCLUSIONS
                and isinstance(policy.get("provenance"), dict) and policy["provenance"].get("source"), "Invalid separate logical Land exclusion policy")
        policies[land_id] = {"excluded_content": sorted(flags), "policy_provenance": policy["provenance"]}
    require({row["ID"] for row in lands.values() if row["AssetPath"] in assets} <= set(policies), "Every selected logical Land requires an explicit exclusion policy and provenance")
    evidence = inventory.get("members")
    require(isinstance(evidence, list) and 0 < len(evidence) <= MAX_MEMBERS, "Expected bounded explicit source member inventory")
    inventory_digest(evidence)
    expected, members = {}, []
    source_dir = Path(source_dir)
    require(source_dir.is_dir() and not source_dir.is_symlink(), "Expected regular source directory")
    for row in sorted(evidence, key=lambda row: row["member"]):
        member, asset = row.get("member"), row.get("asset_path")
        require(asset in assets, "Member AssetPath is outside selected inventory scope")
        member_name(member, asset)
        size, value = integer(row.get("bytes"), minimum=1), digest(row.get("sha256"))
        availability, provenance = row.get("availability"), row.get("provenance")
        require(availability in ("present", "missing") and isinstance(provenance, dict), "Missing explicit source availability/provenance")
        require(provenance.get("snapshot_version") == 523 and type(provenance.get("snapshot_version")) is int
                and isinstance(provenance.get("container"), str) and provenance["container"].startswith("Client/Data/")
                and isinstance(provenance.get("evidence_level"), str) and provenance["evidence_level"]
                and type(provenance.get("selection_version")) is int and 0 <= provenance["selection_version"] <= 523,
                "Invalid pinned source selection provenance")
        expected[member] = availability
        fmt = Path(member).suffix[1:]
        metadata = {"member": member, "asset_path": asset, "path": "originals/" + member,
                    "bytes": size, "sha256": value, "format": fmt,
                    "status": "unsupported_format" if fmt == "seg" else "ready" if availability == "present" else "missing_source",
                    "availability": availability, "provenance": provenance}
        if availability == "present":
            data, storage, _, _ = canonical_source(source_dir,row)
            if storage["storage_format"] == "gzip":
                metadata.update(storage)
                metadata["path"] += ".gz"
            if fmt == "s32":
                if provenance.get("current_selection_verified") is not True or provenance.get("expected_member_sha256") != value:
                    metadata["status"] = "unverified_current_selection"
                else:
                    try:
                        decoded = read_s32(data, member)
                        require(write_s32(decoded) == data, "S32 roundtrip failed")
                        metadata.update({key: decoded[key] for key in ("sections", "core_end", "object_part_count", "attribute_offset", "attribute_sha256")})
                    except ValueError as exc:
                        metadata["status"] = "quarantined_malformed_s32"
                        metadata["problem"] = str(exc)
        elif row.get("storage_format") == "gzip":
            metadata.update(storage_metadata(row))
            metadata["path"] += ".gz"
        members.append(metadata)
    actual = set()
    for root in roots:
        directory = source_dir / root
        require(not directory.is_symlink(), "Symlink asset root")
        if not directory.exists(): continue
        for path in directory.rglob("*"):
            require(not path.is_symlink(), "Symlink in selected source root")
            if path.is_file(): actual.add(canonical_audit_member(path.relative_to(source_dir).as_posix()))
            else: require(path.is_dir(), "Nonregular source tree entry")
    require(actual == {name for name, availability in expected.items() if availability == "present"}, "Selected asset root contains missing, extra or misdeclared sources")
    asset_rows = []
    for asset in sorted({row["AssetPath"] for row in lands.values()}):
        selected = [row for row in members if row["asset_path"] == asset]
        ready = sum(row["status"] == "ready" for row in selected)
        asset_rows.append({"asset_path": asset, "source_root": asset_root(asset),
                           "land_ids": sorted(row["ID"] for row in lands.values() if row["AssetPath"] == asset),
                           "source_count": len(selected), "ready_count": ready,
                           "status": "ready" if selected and ready == len(selected) else "partial" if ready else "unavailable_or_quarantined" if selected else "missing_inventory",
                           "source_inventory_sha256": inventory_digest(selected)})
    return {"schema": 1, "kind": KIND, "edition": "LineageM", "cumulative_version": 523,
            "delivery_status": "PRIVATE_LOCAL_ONLY", "native_land_table": land_proof,
            "input_inventory": {"bytes": len(inventory_raw), "sha256": sha(inventory_raw), "asset_paths": sorted(assets)},
            "source_count": len(members), "source_inventory_sha256": inventory_digest(members),
            "assets": asset_rows, "logical_lands": [{"declaration": row, **policies.get(row["ID"],
                {"excluded_content":[],"policy_provenance":{"source":"UNCLASSIFIED_NO_CONTENT_ENABLEMENT"}}),
                "policy_status":"classified" if row["ID"] in policies else "unclassified"}
                for row in sorted(lands.values(), key=lambda row: row["ID"])],
            "members": members, "semantics": dict(SEMANTICS), "SEG_parser_status": "UNSUPPORTED"}


def manifest_bytes(manifest):
    return (json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def normalize_handoff(handoff_dir, archive_path, land_table, source_dir):
    """Normalize pinned full-map metadata; parent-environment paths stay provenance.

    Availability is established only by exact files in this caller's canonical
    source_dir. Source rows from excluded-only roots are not materialized.
    """
    root, source_dir = Path(handoff_dir), Path(source_dir)
    archive = Path(archive_path)
    require(archive.is_file() and not archive.is_symlink() and archive.stat().st_size == FULL_HANDOFF_BYTES, "Full-map handoff archive size differs from independent pin")
    archive_raw = archive.read_bytes()
    require(len(archive_raw) == FULL_HANDOFF_BYTES and sha(archive_raw) == FULL_HANDOFF_SHA256, "Full-map handoff archive differs from independent pin")
    artifact_rows, artifact_raw = read_json(root / "ARTIFACT_MANIFEST.json")
    require(isinstance(artifact_rows, list) and len(artifact_rows) == 23, "Expected complete full-map artifact manifest")
    artifacts = {}
    with zipfile.ZipFile(archive) as zipped:
        require(zipped.testzip() is None, "Full-map handoff ZIP CRC failure")
        require(zipped.read("ARTIFACT_MANIFEST.json") == artifact_raw, "Full-map handoff manifest differs from pinned ZIP")
        for proof in artifact_rows:
            relative = proof["path"]
            require(not Path(relative).is_absolute() and all(part not in ("", ".", "..") for part in relative.split("/")), "Unsafe handoff artifact path")
            require(relative not in artifacts, "Duplicate handoff artifact")
            _, raw = read_json(root / relative) if relative.endswith(".json") else (None,(root / relative).read_bytes())
            require(len(raw) == proof["bytes"] and sha(raw) == proof["sha256"] and zipped.read(relative) == raw, "Handoff artifact identity mismatch: " + relative)
            artifacts[relative] = proof
    lands, _ = _native_lands(land_table)
    scoped = read_json(root / "all1065_Land_availability_and_scope.json")[0]
    sources = read_json(root / "all8311_existing_original_member_locations.json")[0]
    require(len(scoped) == 1065 and len(sources) == 8311, "Full-map handoff scope cardinality mismatch")
    policies, included_assets, seen_lands = [], set(), set()
    for position, row in enumerate(scoped):
        declaration = row["Land_source"]["row"]
        land_id = declaration["ID"]
        require(land_id in lands and land_id not in seen_lands and declaration == lands[land_id]
                and row["Land_source"]["row_index_zero"] == position, "Full-map handoff native Land row differs")
        seen_lands.add(land_id)
        reasons = row["scope_excluded_reasons"]
        require(isinstance(reasons,list) and set(reasons) <= {"siege","clan","ziggurat","arena"}
                and row["scope_included"] is (not bool(reasons)), "Explicit Land scope classification differs")
        if not reasons: included_assets.add(declaration["AssetPath"])
        policies.append({"land_id":land_id,"excluded_content":sorted("guild" if reason == "clan" else reason for reason in reasons),
                         "provenance":{"source":"Pinned full-map handoff explicit logical Land scope; no name heuristic or service activation is inferred.",
                             "handoff_archive_sha256":FULL_HANDOFF_SHA256,"native_land_sha256":LAND_SHA256,
                             "classification_file":"all1065_Land_availability_and_scope.json",
                             "classification_file_sha256":artifacts["all1065_Land_availability_and_scope.json"]["sha256"],
                             "original_scope_excluded_reasons":reasons,"scope_included":row["scope_included"]}})
    require(sum(not row["excluded_content"] for row in policies) == 997 and len(included_assets) == 577, "Expected 997 ordinary-scope Lands and 577 exact asset bindings")
    by_root = {asset_root(asset):asset for asset in included_assets}
    require(len(by_root) == 577, "Ambiguous raw AssetPath physical root")
    members, seen_members = [], set()
    source_index_sha = artifacts["all8311_existing_original_member_locations.json"]["sha256"]
    for row in sources:
        member = member_name(row["member"])
        require(member not in seen_members, "Duplicate full-map source member")
        seen_members.add(member)
        root_key = "/".join(member.split("/")[:2])+"/"
        if root_key not in by_root: continue
        level = row["evidence_level"]
        require(level in ("fresh_current_DAT_SHA1_and_member_bytes","current_selected_retained508_original_member"), "Unknown parent source evidence level")
        require(row["current_DAT_SHA1_freshly_rehashed"] is (level == "fresh_current_DAT_SHA1_and_member_bytes"), "Parent whole-DAT provenance flag differs")
        size, value = integer(row["bytes"],minimum=1), digest(row["sha256"])
        available = (source_dir / member).exists() or (source_dir / (member+".gz")).exists()
        stored_fields = {}
        if available:
            data, storage, _, _ = canonical_source(source_dir,{"member":member,"bytes":size,"sha256":value})
            require(sha(data) == value and f"{zlib.crc32(data)&0xffffffff:08x}" == row["crc32"], "Local source SHA/CRC differs from current full-map index")
            if storage["storage_format"] == "gzip": stored_fields = storage
        retained = level == "current_selected_retained508_original_member"
        members.append({"member":member,"asset_path":by_root[root_key],"bytes":size,"sha256":value,
                        "crc32":row["crc32"],"availability":"present" if available else "missing",
                        **stored_fields,
                        "provenance":{"snapshot_version":523,"container":row["container"],
                            "selection_version":508 if retained else 523,
                            "selection_version_kind":"retained_archive_version" if retained else "verified_current_snapshot",
                            "evidence_level":level,"current_selection_verified":True,"expected_member_sha256":value,
                            "current_expected_DAT_SHA1":row["current_expected_DAT_SHA1"],
                            "parent_current_DAT_SHA1_freshly_rehashed":row["current_DAT_SHA1_freshly_rehashed"],
                            "whole_dat_freshly_consumed_this_environment":False,
                            "historical_parent_source_file":row["source_file"],
                            "handoff_archive_sha256":FULL_HANDOFF_SHA256,"current_source_index_sha256":source_index_sha}})
    require(len(members) == 6570 and sum(row["bytes"] for row in members) == 795660419
            and sum(row["member"].endswith(".seg") for row in members) == 12, "Expected 6570 normal-root source rows including 12 unsupported SEG")
    return {"schema":1,"edition":"LineageM","cumulative_version":523,"asset_paths":sorted(included_assets),
            "land_policy":policies,"members":sorted(members,key=lambda row:row["member"]),
            "scope_provenance":{"handoff_archive_sha256":FULL_HANDOFF_SHA256,"handoff_archive_bytes":FULL_HANDOFF_BYTES,
                "artifact_manifest_sha256":sha(artifact_raw),"native_land_sha256":LAND_SHA256,
                "included_logical_lands":997,"excluded_logical_lands":68,"normal_physical_asset_paths":577,
                "expected_members":6570,"S32_members":6558,"unsupported_SEG_members":12,
                "locally_present_members":sum(row["availability"] == "present" for row in members),
                "parent_source_paths_are_availability_proof_here":False}}


def write_normalized_inventory(value, output):
    from build_current523_aden_pack import _is_repository
    output = Path(output).expanduser()
    require(not output.is_symlink(), "Normalized inventory must not replace a symlink")
    output = output.resolve()
    require(not output.exists() and not any(_is_repository(parent) for parent in (output.parent,*output.parent.parents)), "Normalized native inventory must be new and outside Git")
    raw = manifest_bytes(value)
    require(len(raw) <= MAX_METADATA_BYTES, "Normalized native inventory exceeds bound")
    output.parent.mkdir(parents=True,exist_ok=True)
    descriptor = os.open(output,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(descriptor,"wb") as handle: handle.write(raw)
    return sha(raw)


def _fsync_directory(path):
    descriptor = os.open(path,os.O_RDONLY|os.O_DIRECTORY)
    try: os.fsync(descriptor)
    finally: os.close(descriptor)


def gzip_input_member(source_dir, row):
    """One lossless storage transaction; rollback restores its raw canonical path.

    Previously completed members are independent committed gzip representations.
    Old pack hardlinks are neither rewritten nor removed.
    """
    member = member_name(row["member"])
    require(member.endswith(".s32"), "Only ready S32 input members may be compressed")
    raw, storage, _, _ = canonical_source(source_dir,row)
    raw_path = Path(source_dir)/member
    target = Path(source_dir)/(member+".gz")
    original_mode = raw_path.stat().st_mode if raw_path.exists() else None
    if original_mode is not None: require(original_mode & 0o077 == 0, "Compression requires private immutable raw inputs")
    transaction = Path(tempfile.mkdtemp(prefix=".gzip-input-",dir=source_dir))
    transaction.chmod(0o700)
    backup = transaction/"raw-rollback"
    created = False
    retired = False
    preserve = False
    try:
        if raw_path.exists():
            regular_child(source_dir,member)
            os.link(raw_path,backup,follow_symlinks=False)
            require(not backup.is_symlink(), "Refusing raw rollback symlink")
            _fsync_directory(transaction)
        if storage["storage_format"] != "gzip":
            payload = gzip.compress(raw,compresslevel=6,mtime=0)
            require(decode_gzip(payload,row["bytes"]) == raw, "Gzip roundtrip differs before publication")
            stage = transaction/"payload.gz"
            with stage.open("xb") as handle:
                handle.write(payload)
                handle.flush()
                os.fsync(handle.fileno())
            stage.chmod(0o600)
            os.link(stage,target,follow_symlinks=False)
            created = True
            _fsync_directory(target.parent)
        stored = storage_payload(regular_child(source_dir,member+".gz"))
        info = {"storage_format":"gzip","stored_bytes":len(stored),"stored_sha256":sha(stored)}
        require(verify_payload(stored,row,info) == raw, "Published gzip differs before raw retirement")
        with target.open("rb") as handle: os.fsync(handle.fileno())
        _fsync_directory(target.parent)
        if backup.exists():
            require(source_bytes(raw_path,row["bytes"]) == raw, "Raw input changed before retirement")
            raw_path.unlink()
            retired = True
            _fsync_directory(raw_path.parent)
        return {"member":member,"bytes":row["bytes"],"sha256":row["sha256"],**info,
                "raw_canonical_retired":retired,"old_pack_hardlinks_unchanged":True}
    except BaseException:
        try:
            if backup.exists() and not raw_path.exists():
                os.link(backup,raw_path,follow_symlinks=False)
                _fsync_directory(raw_path.parent)
            if backup.exists(): require(source_bytes(raw_path,row["bytes"]) == raw, "Raw rollback identity failed")
            if created: target.unlink(missing_ok=True)
            _fsync_directory(target.parent)
        except BaseException as rollback_error:
            preserve = True
            raise ValueError("Compression rollback blocked; preserve recovery bytes at "+str(transaction)) from rollback_error
        raise
    finally:
        if not preserve: shutil.rmtree(transaction)


def gzip_inputs(source_dir, land_table, inventory_path, expected_inventory_sha256):
    """Explicit stable-input operation, never an implicit side effect of build."""
    manifest = prepare_manifest(source_dir,land_table,inventory_path,expected_inventory_sha256)
    selected = [row for row in manifest["members"] if row["status"] == "ready"]
    for row in selected:
        path = Path(source_dir)/row["member"]
        if path.exists(): require(path.stat().st_mode & 0o077 == 0, "Compression requires private immutable raw inputs before any conversion")
    # Single-link raw members can release space immediately. Existing private
    # pack aliases remain raw until their own lifecycle is managed separately.
    selected.sort(key=lambda row:(not (Path(source_dir)/row["member"]).exists()
        or (Path(source_dir)/row["member"]).stat().st_nlink != 1,row["member"]))
    records = []
    for row in selected:
        # The original inventory pins identity. Stored representation may have
        # changed after earlier completed transactions; resolve it afresh.
        identity = {"member":row["member"],"bytes":row["bytes"],"sha256":row["sha256"]}
        records.append(gzip_input_member(source_dir,identity))
    return {"operation":"explicit_gzip_inputs","input_inventory_sha256":expected_inventory_sha256,
            "transaction_boundary":"per_member_with_raw_rollback","members":records,
            "raw_original_bytes":sum(row["bytes"] for row in records),
            "stored_gzip_bytes":sum(row["stored_bytes"] for row in records),
            "no_old_pack_mutations":True}


def publish(manifest, source_dir, output, storage_mode="copy"):
    from build_current523_aden_pack import _is_repository, _publish_directory
    output = Path(output).expanduser()
    require(not output.exists() and not output.is_symlink(), "Output already exists")
    output = output.resolve()
    require(not any(_is_repository(parent) for parent in (output,*output.parents)), "Private originals must remain outside Git")
    source_dir = Path(source_dir).resolve()
    require(storage_mode in ("copy","hardlink"), "Unknown original storage mode")
    require(output != source_dir and source_dir not in output.parents, "Output must be outside original source tree")
    output.parent.mkdir(parents=True, exist_ok=True)
    required = len(manifest_bytes(manifest))
    if storage_mode == "copy": required += sum(row.get("stored_bytes",row["bytes"]) for row in manifest["members"] if row["availability"] == "present")
    require(shutil.disk_usage(output.parent).free >= required + 1024 * 1024, "Insufficient free space; use validate-only without --output")
    stage = Path(tempfile.mkdtemp(prefix=".source523-", dir=output.parent))
    try:
        stage.chmod(0o700)
        for row in manifest["members"]:
            if row["availability"] != "present": continue
            _, storage, original, data = canonical_source(source_dir,row)
            expected_path = "originals/"+row["member"]+(".gz" if storage["storage_format"] == "gzip" else "")
            require(row["path"] == expected_path, "Noncanonical output storage path")
            destination = stage / row["path"]
            destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            if storage_mode == "hardlink":
                require(original.stat().st_mode & 0o077 == 0, "Hardlink mode requires private immutable source permissions")
                os.link(original,destination,follow_symlinks=False)
                require(not destination.is_symlink(), "Refusing hardlinked symlink")
                linked = storage_payload(destination)
                verify_payload(linked,row,storage)
                # Never chmod or write the shared original inode.
            else:
                destination.write_bytes(data)
                destination.chmod(0o600)
                verify_payload(storage_payload(destination),row,storage)
        path = stage / MANIFEST_NAME
        path.write_bytes(manifest_bytes(manifest))
        path.chmod(0o600)
        _publish_directory(stage, output)
        stage = None
    finally:
        if stage is not None: shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source-dir", required=True)
    parser.add_argument("--land-table", required=True)
    parser.add_argument("--inventory")
    parser.add_argument("--expected-inventory-sha256")
    parser.add_argument("--handoff-dir", help="Normalize the independently pinned full-map handoff instead of --inventory")
    parser.add_argument("--handoff-archive")
    parser.add_argument("--normalized-inventory-output")
    parser.add_argument("--gzip-inputs", action="store_true", help="Explicit stable-input per-member gzip transaction; does not build a pack")
    parser.add_argument("--gzip-receipt", help="New private receipt path for --gzip-inputs")
    parser.add_argument("--output", help="Omit for read-only validation without copying originals")
    parser.add_argument("--storage-mode", choices=("copy","hardlink"), default="copy",
                        help="hardlink uses only already private immutable inputs; loader remains read-only and verifies every read")
    args = parser.parse_args()
    inventory_path, inventory_pin = args.inventory, args.expected_inventory_sha256
    if args.handoff_dir:
        require(not inventory_path and not inventory_pin and args.handoff_archive and args.normalized_inventory_output,
                "Handoff mode requires its archive and new normalized output, without a second inventory")
        normalized = normalize_handoff(args.handoff_dir,args.handoff_archive,args.land_table,args.source_dir)
        inventory_path = args.normalized_inventory_output
        inventory_pin = write_normalized_inventory(normalized,inventory_path)
    require(inventory_path and inventory_pin, "Explicit inventory path and independent whole-file SHA256 are required")
    if args.gzip_inputs:
        require(not args.output and not args.handoff_dir and args.gzip_receipt, "Explicit gzip operation requires pinned --inventory and a new --gzip-receipt, without build output")
        from build_current523_aden_pack import _is_repository
        receipt_path = Path(args.gzip_receipt).expanduser()
        require(not receipt_path.is_symlink() and not receipt_path.exists(), "Gzip receipt must be a new private path before conversion")
        receipt_path = receipt_path.resolve()
        require(not any(_is_repository(parent) for parent in (receipt_path.parent,*receipt_path.parent.parents)), "Gzip receipt must remain outside Git")
        receipt = gzip_inputs(args.source_dir,args.land_table,inventory_path,inventory_pin)
        receipt_pin = write_normalized_inventory(receipt,args.gzip_receipt)
        print(json.dumps({"operation":receipt["operation"],"members":len(receipt["members"]),
            "raw_original_bytes":receipt["raw_original_bytes"],"stored_gzip_bytes":receipt["stored_gzip_bytes"],
            "receipt_sha256":receipt_pin},sort_keys=True))
        return
    manifest = prepare_manifest(args.source_dir,args.land_table,inventory_path,inventory_pin)
    if args.output: publish(manifest,args.source_dir,args.output,args.storage_mode)
    print(json.dumps({"mode":"PRIVATE_LOCAL_ONLY" if args.output else "VALIDATED_ONLY_NOT_BUILT",
                      "storage_mode":args.storage_mode if args.output else "not_published",
                      "manifest_sha256":sha(manifest_bytes(manifest)), "source_count":manifest["source_count"],
                      "input_inventory_sha256":inventory_pin,
                      "source_inventory_sha256":manifest["source_inventory_sha256"],
                      "native_logical_lands":len(manifest["logical_lands"]), "native_asset_paths":len(manifest["assets"]),
                      "selected_asset_paths_count":len(manifest["input_inventory"]["asset_paths"]),
                      "available_assets":[row for row in manifest["assets"] if row["ready_count"] > 0],
                      "native_land_table":manifest["native_land_table"]}, sort_keys=True))


if __name__ == "__main__":
    main()
