#!/usr/bin/env python3
"""Build a PRIVATE, deterministic current523 exact-identity raw actor pack.

Example (Python 3.10+, `brotli` installed):
  python3 tools/lineagem_original/build_current523_identity_pack.py \
    --tables-zip /private/lineagem_patch523_all_content_validated_and_508_520_deltas.zip \
    --checkpoints-dir /private/checkpoints --spr-dir /private/current_spr \
    --spr-proof-zip /private/TWILIGHT_current523_M_map_integration_989actual_SP2_validated_PNGs_risks_20261104.zip \
    --output /private/current523-identity-pack

No downloads, game save edits, source extraction, source overrides or report-path
trust. Only this tool is suitable for public Git: its output contains third-party
raw art and native evidence and must remain in the authorized private workflow.
Identity/address coverage does not establish original pixel geometry, blending,
hit/death coverage, gameplay equivalence or all523 resource delivery.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
import copy
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import re
import stat
import struct
import sys
import zipfile
import zlib

import original_spr


TABLES = ("lineagem_patch523_all_content_validated_and_508_520_deltas.zip", 25031173,
          "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832")
CARDS = ("cards.json", 4391274,
         "f525911816048df7ab869180b19d9e2f20297e83fc88dcea6b8bc3284e73f1b0")
WEAPON_METADATA = ("source_weapon_actions.json", 21197,
                   "fa126dadb7611ec482a4ae3356fcc723d816ad28840cd06756afbed592cb1114")
SPR_PROOF = ("TWILIGHT_current523_M_map_integration_989actual_SP2_validated_PNGs_risks_20261104.zip", 76907660,
             "b6f665d03e84e7cd01b3dd15b60d94091b3ff762cdc58fcfd820c724aa622182")
CHECKPOINTS = (
    ("TWILIGHT_current523_M_only_currentSprite_originals18_checkpoint01_20261104.zip", 190728359,
     "7dfd47a9cb0f1073437933febee72a26a27159c868220b51b476226d4e9632ae"),
    ("TWILIGHT_current523_M_only_originalSprite69_checkpoint02_20261104.zip", 189340512,
     "2280a66e69fca0f4853a6b460a9a2c315f3ebc86d46efaf83582297d6fa1091c"),
    ("TWILIGHT_current523_M_only_originalSprite69_checkpoint03_20261104.zip", 190535985,
     "3e47d38afadc8b8c55d7528acaba5148ec4c101151fa16bc7202f66e1b23da71"),
    ("TWILIGHT_current523_M_only_originalSprite69_checkpoint04_20261104.zip", 185164962,
     "4d6045fc087a8b2e1794776635ac84a6729423e1182a7627fe6bff17ae5a7770"),
)
PROOF_MEMBER = "source_origin_checks/all117_fresh_resource_origin_source_proofs.json"
ROLES = (("idle", 3), ("walk", 0), ("attack", 1))
MAX_DECODED_BYTES = 32 * 1024 * 1024
LAYER_POLICY = "auxiliary_101_105_share_parent_selector_picture_and_timing"
WEAPON_POLICY = "twilight_existing_primary_weapon_bank"
# Explicitly preserve the existing build_source_weapon_banks.py primary-family
# choice. These IDs are a TWILIGHT playback policy, not proof of native alternate
# attack intent. Never derive this mapping by sorting IDs or guessing names.
PRIMARY_WEAPON_ACTIONS = {
    1: {"idle": 7, "walk": 4, "attack": 5},
    2: {"idle": 14, "walk": 11, "attack": 12},
    3: {"idle": 23, "walk": 20, "attack": 21},
    4: {"idle": 27, "walk": 24, "attack": 25},
    5: {"idle": 43, "walk": 40, "attack": 41},
    6: {"idle": 49, "walk": 46, "attack": 47},
    7: {"idle": 53, "walk": 50, "attack": 51},
    8: {"idle": 57, "walk": 54, "attack": 55},
    9: {"idle": 61, "walk": 58, "attack": 59},
    10: {"idle": 65, "walk": 62, "attack": 63},
    11: {"idle": 86, "walk": 83, "attack": 84},
    34: {"idle": 122, "walk": 119, "attack": 120},
    54: {"idle": 127, "walk": 124, "attack": 125},
    84: {"idle": 151, "walk": 147, "attack": 148},
    102: {"idle": 156, "walk": 152, "attack": 153},
}


def require(value, detail):
    if not value:
        raise ValueError(detail)


def sha(blob):
    return hashlib.sha256(blob).hexdigest()


def file_sha(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for part in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(part)
    return digest.hexdigest()


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def safe_name(name):
    require(isinstance(name, str) and name and "\\" not in name and "\x00" not in name,
            f"unsafe member name {name!r}")
    p = PurePosixPath(name)
    require(not p.is_absolute() and all(x not in ("", ".", "..") for x in name.split("/"))
            and ":" not in name, f"unsafe member path {name!r}")
    return name


def zip_index(archive):
    result, folded = {}, set()
    for entry in archive.infolist():
        name = safe_name(entry.filename.rstrip("/") if entry.is_dir() else entry.filename)
        require(name not in result and name.casefold() not in folded, f"duplicate/case-colliding member {name}")
        require(not entry.flag_bits & 1, f"encrypted member {name}")
        mode = entry.external_attr >> 16
        require(not stat.S_ISLNK(mode), f"symlink member {name}")
        result[name] = entry
        folded.add(name.casefold())
    return result


def pin(path, expected):
    require(path.is_file(), f"source file unavailable: {path}")
    _, size, digest = expected
    require(path.stat().st_size == size and file_sha(path) == digest, f"source snapshot mismatch: {path}")
    return {"file": expected[0], "bytes": size, "sha256": digest}


def checked_member(archive, index, name):
    require(name in index and not index[name].is_dir(), f"missing source member {name}")
    body = archive.read(index[name])  # zipfile verifies actual member CRC.
    require(len(body) == index[name].file_size, f"member size mismatch {name}")
    return body


def package_rows(archive, index):
    blob = checked_member(archive, index, "package_manifest.json")
    rows = json.loads(blob)
    require(isinstance(rows, list), "package manifest must be a list")
    result = {}
    for row in rows:
        name = safe_name(row["file"])
        require(name not in result, f"duplicate package proof {name}")
        result[name] = row
    return result


def match_package(package, name, blob):
    require(name in package and package[name]["bytes"] == len(blob)
            and package[name]["sha256"] == sha(blob), f"package proof mismatch {name}")


def read_sprs(args):
    proof_pin = pin(args.spr_proof_zip, SPR_PROOF)
    with zipfile.ZipFile(args.spr_proof_zip) as archive:
        index = zip_index(archive)
        blob = checked_member(archive, index, PROOF_MEMBER)
        match_package(package_rows(archive, index), PROOF_MEMBER, blob)
        records = json.loads(blob)
    expected = {}
    for row in records:
        if row.get("kind") != "M_SPR_literal_text":
            continue
        name = PurePosixPath(row["M_path"]).name
        require(re.fullmatch(r"list_\d+\.spr", name) and name not in expected,
                f"invalid/duplicate SPR origin {name}")
        require(row.get("fresh_actual_bytes_match_current_M523_manifest") is True,
                f"SPR not current manifest verified: {name}")
        expected[name] = row
    require(len(expected) == 30, "expected all30 SPR origin proof records")
    observed, paths = {}, []
    for path in sorted(args.spr_dir.glob("*.spr")):
        require(path.name in expected and path.is_file() and not path.is_symlink(), f"unexpected SPR {path}")
        row, body = expected[path.name], path.read_bytes()
        require(len(body) == row["bytes"] and sha(body) == row["sha256"]
                and hashlib.sha1(body).hexdigest() == row["sha1"], f"stale/unverified SPR {path.name}")
        observed[path.name] = {"bytes": len(body), "sha256": sha(body), "sha1": row["sha1"],
                               "current_origin_proof": row}
        paths.append(path)
    require(paths, "no verified current SPR plaintext available")
    missing = {name: {"bytes": row["bytes"], "sha256": row["sha256"]}
               for name, row in sorted(expected.items()) if name not in observed}
    return read_native_sprs(paths), observed, {"archive": proof_pin, "member": PROOF_MEMBER,
                                             "member_sha256": sha(blob), "missing_current_plaintext": missing}


def read_tables(args):
    table_pin = pin(args.tables_zip, TABLES)
    names = ("BuffCard", "BuffClass", "BuffBonus", "Bonus", "BonusType", "Unit",
             "PolymorphSet", "PolymorphEntityForSet", "PolymorphEntity",
             "BuffCardSpriteCustomizingOption", "SpriteRun", "ListSprAction", "WeaponType")
    rows, proofs = {}, {}
    with zipfile.ZipFile(args.tables_zip) as archive:
        index = zip_index(archive)
        for name in names:
            member = f"content/{name}.json"
            blob = checked_member(archive, index, member)
            rows[name] = json.loads(blob)["rows"]
            proofs[name] = {"member": member, "sha256": sha(blob), "rows": len(rows[name])}
    by_id = {}
    for name, values in rows.items():
        by_id[name] = {row["ID"]: row for row in values if "ID" in row}
        require(len(by_id[name]) == sum("ID" in row for row in values), f"duplicate table IDs {name}")
    return rows, by_id, {"archive": table_pin, "tables": proofs}


def read_weapon_policy(repository, rows, by_id, table_origin):
    path = repository / "data/lineagem_base508" / WEAPON_METADATA[0]
    proof = pin(path, WEAPON_METADATA)
    metadata = json.loads(path.read_bytes())
    require(metadata["source_action_rows"] == {str(row["ID"]): row for row in rows["ListSprAction"]},
            "current ListSprAction differs from accepted weapon policy rows")
    require(metadata["source_weapon_type_rows"] == rows["WeaponType"],
            "current WeaponType differs from accepted weapon policy rows")
    for native, field in (("ListSprAction", "source_ListSprAction_sha256"), ("WeaponType", "source_WeaponType_sha256")):
        require(metadata[field] == table_origin["tables"][native]["sha256"], f"accepted {native} table hash mismatch")
    mapped = set(metadata["local_weapon_type_to_source"].values())
    require(mapped == {0, *PRIMARY_WEAPON_ACTIONS}, "accepted local weapon context mapping changed")
    alternatives = {}
    for weapon, primary in PRIMARY_WEAPON_ACTIONS.items():
        alternatives[str(weapon)] = [row for row in rows["ListSprAction"]
            if row["WeaponType"] == weapon and row["MotionType"] in (1, 2, 4)
            and row["ID"] not in primary.values()]
    return {"policy": WEAPON_POLICY, "interpretation": "Existing TWILIGHT primary-family playback selection; native alternate/special intent unverified",
            "accepted_metadata": proof, "local_weapon_type_to_source": metadata["local_weapon_type_to_source"],
            "primary_action_ids": PRIMARY_WEAPON_ACTIONS, "excluded_alternative_rows": alternatives,
            "alter_policy": "Only WeaponAlterType0; no inferred ranged, shield, special or extra modes"}


def primary_action_rows(weapon, native_rows):
    result = {}
    for role, action_id in PRIMARY_WEAPON_ACTIONS[weapon].items():
        row = native_rows.get(action_id)
        require(row is not None and row["ID"] == action_id and row["WeaponType"] == weapon
                and row["MotionType"] == {"idle": 4, "walk": 1, "attack": 2}[role],
                f"primary weapon table fields differ: {weapon}/{role}/{action_id}")
        require(row["WeaponAlterType"] == 0,
                f"primary action requires unsupported WeaponAlterType{row['WeaponAlterType']}: {weapon}/{role}/{action_id}")
        result[role] = row
    return result


def card_chains(card, rows, by_id):
    """Use typed PolymorphSetID relations, never portrait/name similarity."""
    bonuses, entities = defaultdict(list), defaultdict(list)
    for row in rows["BuffBonus"]:
        bonuses[row["BuffClassID"]].append(row)
    for row in rows["PolymorphEntityForSet"]:
        entities[row["PolymorphSetID"]].append(row)
    result = []

    def add_set(set_id, path):
        source_set = by_id["PolymorphSet"][set_id]
        for join in entities[set_id]:
            entity = by_id["PolymorphEntity"][join["PolymorphEntityID"]]
            result.append({"sprite_id": entity["SpriteID"], "path": path + [
                {"table": "PolymorphSet", "row": source_set},
                {"table": "PolymorphEntityForSet", "row": join},
                {"table": "PolymorphEntity", "row": entity}]})

    def walk(buff_id, path, seen=()):
        require(buff_id not in seen, f"typed buff cycle {seen + (buff_id,)}")
        buff = by_id["BuffClass"][buff_id]
        path = path + [{"table": "BuffClass", "row": buff}]
        for link in bonuses[buff_id]:
            bonus = by_id["Bonus"][link["BonusID"]]
            kind = by_id["BonusType"][bonus["BonusTypeID"]]
            extended = path + [{"table": "BuffBonus", "row": link},
                               {"table": "Bonus", "row": bonus}, {"table": "BonusType", "row": kind}]
            if kind["Name"] in ("PolymorphSetID", "SpecialPolymorphSetID"):
                add_set(bonus["Value"], extended)
            elif kind["Name"] == "SubSlotBuffClassID":
                walk(bonus["Value"], extended, seen + (buff_id,))

    base = [{"table": "BuffCard", "row": card}]
    walk(card["BuffClassID"], base)
    for option in rows["BuffCardSpriteCustomizingOption"]:
        if option["BuffCardID"] == card["ID"] and by_id["Unit"].get(option["UnitID"], {}).get("Name") == "PolymorphSetID":
            add_set(option["Value"], base + [{"table": "BuffCardSpriteCustomizingOption", "row": option}])
    return result


def read_raw(args):
    """Recheck all69 DATs and all10,338 SP2 CRC/SHA bytes, without audit inputs."""
    raw, containers, checkpoint_proofs = {}, [], []
    for expected in CHECKPOINTS:
        path = args.checkpoints_dir / expected[0]
        checkpoint_proofs.append(pin(path, expected))
        with zipfile.ZipFile(path) as archive:
            index = zip_index(archive)
            package = package_rows(archive, index)
            for name in sorted(index):
                if not re.fullmatch(r"originals/Client/Data/Sprite\d+\.dat", name):
                    continue
                data = checked_member(archive, index, name)
                proof_name = "source_proofs/" + PurePosixPath(name).name + "_proof.json"
                proof_blob = checked_member(archive, index, proof_name)
                match_package(package, name, data)
                match_package(package, proof_name, proof_blob)
                proof = json.loads(proof_blob)
                require(proof["container"] == name.removeprefix("originals/")
                        and proof["whole_current523_manifest_match"] is True
                        and proof["whole_ZIP_all_member_CRC_pass"] is True,
                        f"DAT source proof is not current {name}")
                digest = sha(data)
                digest1 = hashlib.sha1(data).hexdigest()
                require((len(data), digest, digest1) == (proof["bytes"], proof["sha256"], proof["sha1"]),
                        f"actual DAT source bytes mismatch {name}")
                current = proof["current_manifest_record"]
                require(current["path"] == proof["container"] and len(data) == current["manifest_bytes"]
                        and digest1 == current["manifest_sha1"], f"DAT current manifest mismatch {name}")
                toc = {row["name"]: row for row in proof["actual_TOC_entries"]}
                require(len(toc) == len(proof["actual_TOC_entries"]), f"duplicate proof TOC {name}")
                source = {"checkpoint": expected[0], "checkpoint_sha256": expected[2],
                          "outer_member": name, "bytes": len(data), "sha256": digest, "sha1": digest1,
                          "proof_member": proof_name, "proof_sha256": sha(proof_blob),
                          "current_manifest_record": current}
                observed, selected = {}, {}
                with zipfile.ZipFile(io.BytesIO(data)) as dat:
                    inner = zip_index(dat)
                    for member, entry in inner.items():
                        if entry.is_dir():
                            continue
                        body = checked_member(dat, inner, member)
                        row = {"name": member, "bytes": len(body), "crc32": f"{zlib.crc32(body) & 0xffffffff:08x}"}
                        observed[member] = row
                        require(toc.get(member) == row, f"actual DAT TOC mismatch {name}:{member}")
                        if not re.fullmatch(r"Sprite/\d+-\d+\.sp2", member):
                            continue
                        require(member not in raw, f"duplicate raw member across DATs {member}")
                        selected[member] = {"bytes": len(body), "crc32": row["crc32"], "sha256": sha(body)}
                        raw[member] = {"body": body, "proof": {**selected[member], "container": source,
                                      "member": member, "local_header_offset": entry.header_offset}}
                require(observed == toc, f"unmatched source TOC rows {name}")
                for row in proof["selected_members"]:
                    require(all(selected[row["member"]][key] == row[key] for key in ("bytes", "crc32", "sha256")),
                            f"selected source hash mismatch {name}:{row['member']}")
                containers.append(source)
        print(f"Verified {expected[0]} ({len(containers)} DATs, {len(raw)} SP2 members)", flush=True)
    require(len(containers) == 69 and len(raw) == 10338, "incomplete current checkpoint source set")
    return raw, {"checkpoints": checkpoint_proofs, "dat_containers": containers,
                 "verified_dat_count": len(containers), "verified_sp2_member_count": len(raw)}


class Reader:
    def __init__(self, body):
        self.body, self.pos = body, 0

    def take(self, count):
        require(0 <= count <= len(self.body) - self.pos, f"truncated SP2 at {self.pos}, count {count}")
        result = self.body[self.pos:self.pos + count]
        self.pos += count
        return result

    def uint(self, code):
        return struct.unpack("<" + code, self.take(struct.calcsize("<" + code)))[0]


def parse_layout(body, entries):
    """Current523 commandwise palette stream validation, with exact EOF."""
    reader = Reader(body)
    require(reader.uint("B") == 254, "missing FE marker")
    reader.uint("B")
    reader.take(entries * 2)
    mask = reader.uint("B")
    require(mask != 0, "empty SP2 mask")
    groups = {}
    for bit in range(8):
        if not mask & (1 << bit):
            continue
        frames = []
        for _ in range(reader.uint("B")):
            reader.take(8)  # Four native signed bounds, retained in raw bytes.
            count = reader.uint("H")
            reader.take(count * 3)  # Native coordinate and type arrays.
            refs, index = [], 0
            for number in range(count):
                value = reader.uint("h")
                index = (value & 65535) if number == 0 else (index + value + 1) & 65535
                refs.append(index)
            frames.append({"refs": refs})
        count = reader.uint("i")
        require(0 <= count <= 65536, "SP2 block count out of range")
        blocks = []
        for _ in range(count):
            _, _, commands = reader.take(3)
            words = struct.unpack("<" + "H" * commands, reader.take(commands * 2))
            blocks.append(sum((word >> 5) & 31 for word in words))
        for frame in frames:
            require(all(ref < count for ref in frame["refs"]), "SP2 block reference out of bounds")
            frame["samples"] = sum(blocks[ref] for ref in frame.pop("refs"))
        groups[bit] = {"frames": frames, "blocks": blocks}
    for group in groups.values():
        for count in group.pop("blocks"):
            require(all(sample < entries for sample in reader.take(count)), "SP2 palette index out of bounds")
    require(reader.pos == len(body), f"SP2 trailing bytes {reader.pos}/{len(body)}")
    return {"mask": mask, "palette_entries": entries, "groups": groups,
            "decoded_bytes": len(body), "decoded_sha256": sha(body)}


def parse_sp2(raw):
    require(bool(raw), "empty SP2")
    if raw[0] == 254:
        body = raw
    else:
        try:
            import brotli
        except ImportError as error:
            raise ValueError("brotli is required; install tools/lineagem_original/requirements.txt") from error
        decoder, parts, size = brotli.Decompressor(), [], 0
        for offset in range(0, len(raw), 1024):
            part = decoder.process(raw[offset:offset + 1024])
            size += len(part)
            require(size <= MAX_DECODED_BYTES, "decoded SP2 exceeds32MiB")
            parts.append(part)
        require(decoder.is_finished(), "incomplete SP2 Brotli stream")
        body = b"".join(parts)
    require(2 <= len(body) <= MAX_DECODED_BYTES and body[0] == 254, "invalid decoded SP2 header/size")
    marker = body[1]
    passed = []
    for entries in ([1, 3] if marker == 1 else [256 if marker == 0 else marker]):
        try:
            passed.append(parse_layout(body, entries))
        except (ValueError, struct.error):
            pass
    require(len(passed) == 1, f"SP2 layouts passing full validation: {len(passed)}")
    return passed[0]


def declaration_path(declarations, sprite_id, spr_proofs, seen=()):
    require(sprite_id not in seen, f"SPR alias cycle {seen + (sprite_id,)}")
    matches = declarations.get(sprite_id, [])
    require(len(matches) == 1, f"{sprite_id}: expected one current SPR declaration, found {len(matches)}")
    declaration = matches[0]
    proof = {"sprite_id": sprite_id, "alias_target": declaration.alias_target,
             "source_file": declaration.source_file, "source_line": declaration.source_line,
             "source_sha256": spr_proofs[declaration.source_file]["sha256"]}
    return [proof] + (declaration_path(declarations, declaration.alias_target, spr_proofs, seen + (sprite_id,))
                      if declaration.alias_target is not None else [])


NATIVE_SELECTOR_POLICY = "native_explicit_actions_and_immediate_alias_owner_v1"
NATIVE_ACTIVATION_POLICY = "restored525_101_immediate_action_owner_105_original_actor_bounded_projection"
NATIVE_CLOTHES_COLLECTION_POLICY = "ordered_first_null_successful_prefix"
FILE_REMAP_POLICY = "requested_high16_single_whole_sprite_remap"
NATIVE_ACTIVATION_EVIDENCE = {
    "source": "restored525 LineageM_1.10.22.0.exe",
    "exe_sha256": "9f9c3b9c9a49fb598899b3da308b4776cbbc47cbb98dbe4b4aa368cce519019d",
    "report_sha256": "b6b0dbb66413966c8b2fab1c59a1a61595ef4bffe36167d0673dc776a603332e",
    "rvas": ["035FBF10", "035FC110", "01C8F425", "01C8F495", "01C96150", "035FB915", "035FA3E0"],
    "current523_native_execution_verified": False,
}
ACTION_ALIAS = re.compile(r"(?<![\w.])(-?\d+)=(-?\d+)")


def _spr_order(path):
    match = re.fullmatch(r"list_(\d+)\.spr", path.name)
    return (0, int(match[1])) if match else (1, path.name)


def read_native_sprs(paths, section_default_fps=None):
    """Add bounded explicit-action registration to the literal SPR reader.

    P01 restored525 proves numeric list order, A=S same-action copy, source
    descriptor availability at that point and first destination insertion.
    This deliberately is not an engine-identical permissive numeric scanner:
    malformed headers/unbalanced statements remain the literal reader's limits.
    Header =S only changes the later file request, never action/metadata owners.
    Existing declaration.actions/directives/references remain the raw ledger.
    """
    paths = sorted(map(Path, paths), key=_spr_order)
    declarations = original_spr.read(paths, section_default_fps)
    by_location = {}
    for matches in declarations.values():
        for declaration in matches:
            declaration.native_action_aliases = []
            declaration.native_literal_action_declarations = []
            by_location[(declaration.source_file, declaration.source_line)] = declaration
    for path in paths:
        current, fps, rate_source = None, section_default_fps, None
        for line_number, line in enumerate(path.read_bytes().decode("cp949").splitlines(), 1):
            scan = line.lstrip()
            offset = len(line) - len(scan)
            if scan.startswith("#"):
                match = original_spr.HEADER.match(scan)
                current = by_location.get((path.name, line_number)) if match else None
                if current is None:
                    continue
                fps = section_default_fps
                rate_source = ({"kind": "client_section_default", "fps": fps,
                                "evidence": original_spr.CLIENT_DEFAULT_EVIDENCE}
                               if fps is not None else None)
                offset += match.end()
                scan = scan[match.end():]
            if current is None:
                continue
            statements = list(original_spr.ACTION.finditer(scan))
            masked = list(scan)
            events = [(match.start(), "statement", match) for match in statements]
            for match in statements:
                masked[match.start():match.end()] = " " * (match.end() - match.start())
            events.extend((match.start(), "alias", match)
                          for match in ACTION_ALIAS.finditer("".join(masked)))
            for _, kind, match in sorted(events, key=lambda item: item[0]):
                code = int(match[1])
                if kind == "statement" and code == 110:
                    # A code110 with a nonstandard name still selects native FPS.
                    require(re.fullmatch(r"\s*\d+\s*", match[3]) is not None,
                            f"unsupported native FPS statement {path.name}:{line_number}")
                    fps = int(match[3])
                    require(fps > 0, "nonpositive native FPS is unsupported")
                    rate_source = {"source_file": path.name, "source_line": line_number,
                                   "raw_name": match[2].strip(), "raw_body": match[3]}
                    continue
                origin = {"action_id": code, "raw": match[0], "source_file": path.name,
                          "source_line": line_number, "source_column": offset + match.start()}
                if kind == "alias":
                    current.native_action_aliases.append({**origin, "target_sprite_id": int(match[2])})
                    continue
                body = match[3]
                tokens = [tuple(map(int, token.groups())) for token in original_spr.TOKEN.finditer(body)]
                if not tokens:
                    continue
                count = re.match(r"^\s*(-?\d+)\s+(\d+)\s*,", body)
                errors = []
                if count is None or int(count[2]) != len(tokens): errors.append("frame count mismatch")
                if any(token[2] < 0 for token in tokens): errors.append("negative frame duration")
                if sum(token[2] for token in tokens) <= 0: errors.append("no positive playback duration")
                action = {"code": code, "name": match[2].strip(), "fps": fps, "tokens": tokens,
                          "raw_body": body, "source_file": path.name, "source_line": line_number,
                          "fps_provenance": copy.deepcopy(rate_source),
                          "declared_flag": int(count[1]) if count else None, "errors": errors,
                          "source_annotations": original_spr.source_annotations(body)}
                current.native_literal_action_declarations.append({**origin, "descriptor": action})
    return register_native_actions(declarations)


def register_native_actions(declarations):
    """Rebuild effective descriptors only from ordered raw literal/alias events.

    Metadata handoffs can call this after reconstructing these source-pinned
    event fields; precomputed effective descriptor rows are never trusted here.
    """
    events = []
    for matches in declarations.values():
        for declaration in matches:
            declaration.native_action_descriptors = {}
            literals = getattr(declaration, "native_literal_action_declarations", None)
            if literals is None:
                literals = [{"action_id": code, "source_file": action["source_file"],
                             "source_line": action["source_line"], "source_column": 0,
                             "descriptor": copy.deepcopy(action)}
                            for code, action in declaration.actions.items()]
            for literal in literals:
                events.append((literal, "literal", declaration))
            for alias in getattr(declaration, "native_action_aliases", []):
                events.append((alias, "alias", declaration))
    events.sort(key=lambda item: (_spr_order(Path(item[0]["source_file"])),
                                 item[0]["source_line"], item[0].get("source_column", 0)))
    registered = {}
    for event, kind, declaration in events:
        code = event["action_id"]
        key = (declaration.sprite_id, code)
        if key in registered:
            event["registration_status"] = "duplicate_destination"
            continue
        if kind == "alias":
            source = registered.get((event["target_sprite_id"], code))
            if source is None:
                event["registration_status"] = "source_descriptor_unavailable"
                continue
            event["registration_status"] = "registered"
            event["source_descriptor_origin_sprite_id"] = source["native_descriptor_origin_sprite_id"]
            action = copy.deepcopy(source)
            action.update(native_body_request_sprite_id=event["target_sprite_id"],
                          native_registration_kind="explicit_action_alias",
                          native_action_alias_chain=[dict(event)] + copy.deepcopy(source["native_action_alias_chain"]))
        else:
            event["registration_status"] = "registered"
            action = copy.deepcopy(event["descriptor"])
            action["tokens"] = [tuple(token) for token in action["tokens"]]
            action.update(native_body_request_sprite_id=declaration.sprite_id,
                          native_descriptor_origin_sprite_id=declaration.sprite_id,
                          native_registration_kind="literal", native_action_alias_chain=[])
        action["native_requested_sprite_id"] = declaration.sprite_id
        registered[key] = action
        declaration.native_action_descriptors[code] = action
    for matches in declarations.values():
        for declaration in matches:
            declaration.native_action_registration = [
                {key: value for key, value in event.items() if key != "descriptor"}
                for event in getattr(declaration, "native_literal_action_declarations", [])]
    return declarations


def _own_declaration(declarations, sprite_id):
    matches = declarations.get(sprite_id, [])
    require(len(matches) == 1, f"{sprite_id}: expected one current SPR declaration, found {len(matches)}")
    return matches[0]


def native_action(declarations, sprite_id, action_id):
    """Return this actor's registered action; never inherit via whole-file alias."""
    require(0 <= action_id < 173, f"unsupported native action key range: {action_id}")
    declaration = _own_declaration(declarations, sprite_id)
    actions = getattr(declaration, "native_action_descriptors", declaration.actions)
    require(action_id in actions, f"absent native source action {sprite_id}/{action_id}")
    action = copy.deepcopy(actions[action_id])
    action.setdefault("native_requested_sprite_id", sprite_id)
    action.setdefault("native_body_request_sprite_id", sprite_id)
    action.setdefault("native_descriptor_origin_sprite_id", sprite_id)
    action.setdefault("native_registration_kind", "literal")
    action.setdefault("native_action_alias_chain", [])
    return action


def _own_proof(declarations, sprite_id, spr_proofs):
    declaration = _own_declaration(declarations, sprite_id)
    return {"sprite_id": sprite_id, "alias_target": declaration.alias_target,
            "source_file": declaration.source_file, "source_line": declaration.source_line,
            "source_sha256": spr_proofs[declaration.source_file]["sha256"]}


def _file_request(declarations, sprite_id, spr_proofs):
    declaration = _own_declaration(declarations, sprite_id)
    mapped = declaration.alias_target if declaration.alias_target is not None else sprite_id
    path = [_own_proof(declarations, sprite_id, spr_proofs)]
    if mapped != sprite_id:
        path.append(_own_proof(declarations, mapped, spr_proofs))
    return mapped, path


def raw_candidate_declarations(root_id, declarations, spr_proofs):
    """Preserve reachable literal declarations; these are not active layers."""
    result, pending, visited = [], [root_id], set()
    while pending:
        sprite_id = pending.pop(0)
        if sprite_id in visited:
            continue
        visited.add(sprite_id)
        matches = declarations.get(sprite_id, [])
        if len(matches) != 1:
            result.append({"sprite_id": sprite_id, "projection_status": "unavailable_or_ambiguous_declaration",
                           "declaration_count": len(matches), "activation_inferred": False})
            continue
        declaration = matches[0]
        aliases = copy.deepcopy(getattr(declaration, "native_action_aliases", []))
        result.append({**_own_proof(declarations, sprite_id, spr_proofs),
                       "literal_directives": copy.deepcopy(declaration.directives),
                       "literal_references": copy.deepcopy(declaration.references),
                       "literal_actions": copy.deepcopy(declaration.actions), "native_action_aliases": aliases,
                       "native_action_registration": copy.deepcopy(getattr(declaration, "native_action_registration", [])),
                       "native_literal_action_declarations": copy.deepcopy(getattr(declaration, "native_literal_action_declarations", [])),
                       "activation_inferred": False})
        targets = [target for ref in declaration.references for target in ref["targets"]]
        targets.extend(alias["target_sprite_id"] for alias in aliases)
        if declaration.alias_target is not None:
            targets.append(declaration.alias_target)
        pending.extend(target for target in targets if target not in visited)
    return result


def native_layers_for_role(root_id, action_id, declarations, spr_proofs, role=None):
    """Bounded animated refresh_aux=true projection, not live actor activation.

    Original-actor 105 first insertion and immediate-action-owner 101 last low15
    are separate. No auxiliary-of-auxiliary traversal is evidenced here. The
    caller must separately apply lookup/null-prefix, flags and include_aux gates.
    """
    role = role or "source_action:" + str(action_id)
    action = native_action(declarations, root_id, action_id)
    require(not action["errors"], f"invalid native source action {root_id}/{action_id}")
    require(action["declared_flag"] in (0, 1), f"unknown direction flag {root_id}/{action_id}")
    body_request = action["native_body_request_sprite_id"]
    require(body_request != 0, "native body request high16 zero is null; not an actor artwork request")
    root = _own_declaration(declarations, root_id)
    body = _own_declaration(declarations, body_request)
    shadow_refs = [(index, ref) for index, ref in enumerate(body.references) if ref["kind"] == "shadow"]
    clothes_refs = [(index, ref) for index, ref in enumerate(root.references) if ref["kind"] == "clothes"]
    layers, paths = [], []
    zero_stop = None

    def add(kind, requested, metadata_owner, reference_index=None, target_index=None, ref=None):
        physical, path = _file_request(declarations, requested, spr_proofs)
        edge_path = [] if ref is None else [{"from_sprite_id": body_request if kind == "shadow" else root_id,
            "target_sprite_id": requested, "kind": kind, "source_reference": ref["raw"],
            "source_reference_index": reference_index, "target_index": target_index}]
        binding = f"native:{root_id}:A{action_id}:{kind}:R{requested}:D{reference_index}:T{target_index}"
        common = {"kind": kind, "source_sprite_id": physical, "requested_sprite_id": requested,
                  "metadata_owner_sprite_id": metadata_owner, "source_reference_index": reference_index,
                  "target_index": target_index, "native_binding_id": binding, "file_remap_policy": FILE_REMAP_POLICY}
        layers.append({**common, "edge_path": edge_path})
        source_declaration = None
        if ref is not None:
            owner_id = body_request if kind == "shadow" else root_id
            owner = _own_declaration(declarations, owner_id)
            reference_directives = [(index, item) for index, item in enumerate(owner.directives)
                                    if item["code"] in (101, 105) and item["name"].lower() in ("shadow", "clothes", "clothe")]
            require(reference_index < len(reference_directives), "active source reference directive unavailable")
            directive_index, directive = reference_directives[reference_index]
            require(directive["body"] == ref["raw"], "active source reference order differs from literal declaration")
            source_declaration = {**_own_proof(declarations, owner_id, spr_proofs),
                "source_line": directive["line"], "source_directive_index": directive_index,
                "source_reference_index": reference_index, "code": directive["code"],
                "name": directive["name"], "body": directive["body"]}
        paths.append({**common, "edge_path": edge_path, "roles": [role], "declaration_path": path,
                      "attribute_owner_declaration_path": [_own_proof(declarations, metadata_owner, spr_proofs)],
                      "source_declaration": source_declaration,
                      "role_policy": {role: "exact_parent_selector_picture_and_timing"}})

    if shadow_refs:
        index, ref = shadow_refs[-1]
        require(ref["count_valid"] and len(ref["targets"]) == 1,
                f"unsupported active shadow declaration {body_request}")
        shadow = ref["targets"][0] & 0x7fff
        if shadow:
            add("shadow", shadow, root_id, index, 0, ref)
    add("body", body_request, root_id)
    if clothes_refs:
        index, ref = clothes_refs[0]
        require(ref["count_valid"], f"invalid active clothes target count {root_id}")
        for target_index, target in enumerate(ref["targets"]):
            if target == 0:
                zero_stop = {"reason": "requested_high16_zero_always_null", "target_index": target_index,
                             "source_reference_index": index, "source_reference": ref["raw"]}
                break
            add("clothes", target, target, index, target_index, ref)
    return {"action": action, "layers": layers, "declarations": paths,
            "raw_candidate_declarations": raw_candidate_declarations(root_id, declarations, spr_proofs),
            "activation": {"policy": NATIVE_ACTIVATION_POLICY, "original_actor_sprite_id": root_id,
                "body_request_sprite_id": body_request, "shadow_metadata_owner_sprite_id": body_request,
                "clothes_metadata_owner_sprite_id": root_id, "shadow_selection": "own_last_low15",
                "clothes_selection": "own_first_map_insertion_order_and_multiplicity",
                "file_remap_policy": FILE_REMAP_POLICY, "auxiliary_recursion": False,
                "assumed_branch": "animated_descriptor_valid_refresh_aux_true",
                "clothes_collection_policy": NATIVE_CLOTHES_COLLECTION_POLICY,
                "clothes_zero_target_stop": zero_stop,
                "clothes_zero_target_prefix_applied": zero_stop is not None,
                "native_lookup_null_prefix_applied": False, "runtime_activation_verified": False,
                "evidence": NATIVE_ACTIVATION_EVIDENCE}}


def build_actor(root_id, declarations, spr_proofs, source_roles=ROLES):
    roles, required, action_proofs, paths = {}, set(), {}, []
    activations, body_ids = {}, {}
    candidates = None
    for role, action_id in source_roles:
        projection = native_layers_for_role(root_id, action_id, declarations, spr_proofs, role)
        action, layers = projection["action"], projection["layers"]
        candidates = projection["raw_candidate_declarations"]
        paths.extend(projection["declarations"])
        activations[role] = projection["activation"]
        body_ids[role] = next(layer["source_sprite_id"] for layer in layers if layer["kind"] == "body")
        directions = []
        for direction in range(8):
            frames = []
            for group, picture, ticks in action["tokens"]:
                physical, bit = original_spr.frame_address(group, direction, action["declared_flag"])
                frame_layers = []
                for layer in layers:
                    member = f"Sprite/{layer['source_sprite_id']}-{physical}.sp2"
                    required.add(member)
                    frame_layers.append({key: value for key, value in layer.items() if key != "edge_path"} |
                                        {"member": member, "group_bit": bit, "frame_index": picture})
                frames.append({"duration_ticks": ticks, "layers": frame_layers})
            directions.append(frames)
        roles[role] = {"source_action_id": action_id, "source_file": action["source_file"],
                       "source_line": action["source_line"], "fps": action["fps"], "loop": role != "attack",
                       "directions": directions}
        action_proofs[role] = {"source_action_id": action_id, **action,
                               "source_sha256": spr_proofs[action["source_file"]]["sha256"]}
    return {"source_sprite_id": root_id, "roles": roles}, required, {
        "root_sprite_id": root_id, "body_sprite_id": next(iter(body_ids.values())),
        "body_sprite_ids_by_role": body_ids, "declarations": paths,
        "roles": action_proofs, "layer_policy": LAYER_POLICY,
        "native_activation_policy": NATIVE_ACTIVATION_POLICY,
        "native_activation_by_role": activations, "raw_candidate_declarations": candidates,
        "existing_private_banks_require_regeneration": True}


def validate_actor(actor, raw, parsed):
    for role, action in actor["roles"].items():
        for direction, frames in enumerate(action["directions"]):
            for token, frame in enumerate(frames):
                for layer in frame["layers"]:
                    member = layer["member"]
                    if member not in parsed:
                        parsed[member] = parse_sp2(raw[member]["body"])
                    group = parsed[member]["groups"].get(layer["group_bit"])
                    require(group is not None, f"{member}: absent mask bit {layer['group_bit']}")
                    require(layer["frame_index"] < len(group["frames"]), f"{member}: frame outside group")
                    if layer["kind"] == "body":
                        require(group["frames"][layer["frame_index"]]["samples"] > 0,
                                f"empty body {role}/{direction}/{token}")


def compact_roles(actor, proof):
    """Retain exact SPR tokens; runtime expands addresses with frame_address()."""
    result = {}
    identity_fields = ("source_sprite_id", "kind", "requested_sprite_id", "metadata_owner_sprite_id",
                       "source_reference_index", "target_index", "native_binding_id", "file_remap_policy")
    def layer_identity(layer):
        return {key: layer[key] for key in identity_fields if key in layer}
    for role, track in actor["roles"].items():
        action = proof["roles"][role]
        first = track["directions"][0][0]["layers"]
        layers = [layer_identity(layer) for layer in first]
        for frames in track["directions"]:
            for frame in frames:
                require(layers == [layer_identity(layer) for layer in frame["layers"]],
                        "compact track changes layer identities")
        result[role] = {"fps": track["fps"], "loop": track["loop"],
                        "source_action_id": track["source_action_id"], "source_file": track["source_file"],
                        "source_line": track["source_line"], "source_sprite_id": actor["source_sprite_id"],
                        "declared_flag": action["declared_flag"], "tokens": action["tokens"], "layers": layers}
    return result


def compile_weapon_profiles(root, run_rows, declarations, spr_proofs, native_rows, raw, parsed):
    profiles, proofs, selected, rejected, rejected_runs = {}, {}, set(), [], []
    for weapon in sorted(PRIMARY_WEAPON_ACTIONS):
        try:
            family = primary_action_rows(weapon, native_rows)
            source_roles = tuple((role, family[role]["ID"]) for role, _ in ROLES)
            actor, members, proof = build_actor(root, declarations, spr_proofs, source_roles)
            missing = sorted(members - raw.keys())
            require(not missing, f"missing current weapon raw members: {missing}")
            validate_actor(actor, raw, parsed)
            profile = {"source_weapon_type": weapon, "policy": WEAPON_POLICY,
                       "source_action_rows": family, "roles": compact_roles(actor, proof)}
        except (ValueError, KeyError) as error:
            rejected.append({"root_sprite_id": root, "source_weapon_type": weapon,
                             "primary_action_ids": PRIMARY_WEAPON_ACTIONS[weapon], "reason": str(error)})
            continue
        profiles[str(weapon)] = profile
        proofs[str(weapon)] = {"source_action_rows": family, **proof}
        selected.update(members)
        if not run_rows:
            continue
        try:
            require(len(run_rows) == 1, f"ambiguous current SpriteRun rows for {root}")
            run_root = run_rows[0]["RunSpriteID"]
            # A weapon run uses its matching weapon walk action in the exact
            # SpriteRun root. Generic run0 is never substituted for this track.
            run_actor, run_members, run_proof = build_actor(
                run_root, declarations, spr_proofs, (("run", family["walk"]["ID"]),))
            missing = sorted(run_members - raw.keys())
            require(not missing, f"missing current weapon run raw members: {missing}")
            validate_actor(run_actor, raw, parsed)
            profile["roles"].update(compact_roles(run_actor, run_proof))
            proofs[str(weapon)]["run"] = {"source_table_row": run_rows[0], **run_proof}
            selected.update(run_members)
        except (ValueError, KeyError) as error:
            rejected_runs.append({"root_sprite_id": root, "source_weapon_type": weapon,
                                  "source_rows": run_rows, "source_action_id": family["walk"]["ID"],
                                  "reason": str(error)})
    return profiles, proofs, selected, rejected, rejected_runs


def build(args):
    requested = args.output.absolute()
    require(not requested.exists() and not requested.is_symlink(), f"output already exists: {requested}")
    output = requested.resolve()
    require(not output.exists(), f"resolved output already exists: {output}")
    repository = Path(__file__).resolve().parents[2]
    require(not output.is_relative_to(repository), "private pack output must be outside the public repository")
    pin(args.cards_json, CARDS)
    declarations, spr_proofs, spr_origin = read_sprs(args)
    rows, by_id, table_origin = read_tables(args)
    weapon_policy = read_weapon_policy(repository, rows, by_id, table_origin)
    raw, raw_origin = read_raw(args)
    catalog_blob = args.cards_json.read_bytes()
    require(len(catalog_blob) == CARDS[1] and sha(catalog_blob) == CARDS[2], "existing cards changed while reading")
    catalog = json.loads(catalog_blob)["catalog"]
    contexts, rejected_cards = defaultdict(list), []
    for category in catalog.values():
        for card in category:
            native = by_id["BuffCard"].get(card["source_card_id"])
            if native is None or native.get("BuffCardDeckID") != 1:
                continue
            require(card["sourceId"] == f"m508:1:{native['ID']}",
                    f"existing card source identity mismatch {card['sourceId']}")
            if card["source_original_card"] != native:
                rejected_cards.append({"sourceId": card["sourceId"], "reason": "complete_source_original_card_differs"})
                continue
            chains = card_chains(native, rows, by_id)
            roots = sorted({chain["sprite_id"] for chain in chains})
            if roots != sorted(card["source_inworld_sprite_ids"]):
                rejected_cards.append({"sourceId": card["sourceId"], "reason": "current_typed_identity_differs"})
                continue
            for root in roots:
                contexts[root].append({"key": "transform:" + card["sourceId"], "native": native,
                                       "chains": [chain for chain in chains if chain["sprite_id"] == root]})
    actors, actor_proofs, rejected, parsed, selected = {}, {}, [], {}, set()
    rejected_runs, rejected_weapons, rejected_weapon_runs = [], [], []
    for root, root_contexts in sorted(contexts.items()):
        try:
            actor, members, proof = build_actor(root, declarations, spr_proofs)
            missing = sorted(members - raw.keys())
            require(not missing, f"missing current raw members: {missing}")
            validate_actor(actor, raw, parsed)
        except (ValueError, KeyError) as error:
            rejected.append({"root_sprite_id": root, "card_keys": sorted(context["key"] for context in root_contexts),
                             "reason": str(error)})
            continue
        actors[f"sprite:{root}"] = actor
        actor_proofs[f"sprite:{root}"] = {**proof, "typed_card_chains": root_contexts,
                                          "declared_run_rows": [row for row in rows["SpriteRun"] if row["WalkSpriteID"] == root]}
        selected.update(members)
        run_rows = actor_proofs[f"sprite:{root}"]["declared_run_rows"]
        if run_rows:
            try:
                require(len(run_rows) == 1, f"ambiguous current SpriteRun rows for {root}")
                run_root = run_rows[0]["RunSpriteID"]
                run_actor, run_members, run_proof = build_actor(run_root, declarations, spr_proofs, (("run", 0),))
                missing = sorted(run_members - raw.keys())
                require(not missing, f"missing current run raw members: {missing}")
                validate_actor(run_actor, raw, parsed)
                actor["roles"]["run"] = {**run_actor["roles"]["run"], "source_sprite_id": run_root}
                actor_proofs[f"sprite:{root}"]["run"] = {"source_table_row": run_rows[0], **run_proof}
                selected.update(run_members)
            except (ValueError, KeyError) as error:
                rejected_runs.append({"root_sprite_id": root, "source_rows": run_rows, "reason": str(error)})
        profiles, weapon_proofs, weapon_members, omitted, omitted_runs = compile_weapon_profiles(
            root, run_rows, declarations, spr_proofs, by_id["ListSprAction"], raw, parsed)
        actor["weapon_profiles"] = profiles
        actor_proofs[f"sprite:{root}"]["weapon_profiles"] = weapon_proofs
        selected.update(weapon_members)
        rejected_weapons.extend(omitted)
        rejected_weapon_runs.extend(omitted_runs)
    require(actors, "no complete exact-identity actors; no pack written")
    cards = {}
    for root, root_contexts in sorted(contexts.items()):
        if f"sprite:{root}" not in actors:
            continue
        for context in root_contexts:
            entry = cards.setdefault(context["key"], {"source_original_card": context["native"], "sprite_ids": []})
            entry["sprite_ids"].append(root)
    manifest = {"schema": 1, "snapshot": "patch523", "mode": "exact_identity_estimated_pixels",
                "members": {name: {"path": "raw/" + name, "bytes": raw[name]["proof"]["bytes"],
                                    "sha256": raw[name]["proof"]["sha256"]} for name in sorted(selected)},
                "cards": cards, "actors": actors}
    provenance = {"schema": 1, "snapshot": "patch523", "mode": manifest["mode"],
                  "scope": "Existing unchanged deck1 transform cards; generic and explicit TWILIGHT primary weapon idle/walk/attack, optional exact SpriteRun tracks, all8 directions; exact identity and source addresses; pixels/composition estimated. No native alternate-mode intent, hit/death or all523 completion claim.",
                  "layer_policy": LAYER_POLICY, "weapon_policy": weapon_policy,
                  "sources": {"tables": table_origin, "spr": spr_origin, "raw": raw_origin,
                  "existing_cards": {"file": args.cards_json.name, "bytes": len(catalog_blob), "sha256": sha(catalog_blob)}},
                  "verified_spr_files": spr_proofs, "actors": actor_proofs,
                  "members": {name: {**raw[name]["proof"], "structure": parsed[name]} for name in sorted(selected)},
                  "rejected_roots": rejected, "rejected_cards": rejected_cards, "rejected_runs": rejected_runs,
                  "rejected_weapons": rejected_weapons, "rejected_weapon_runs": rejected_weapon_runs,
                  "counts": {"actors": len(actors), "cards": len(cards), "raw_members": len(selected),
                             "verified_run_roles": sum("run" in actor["roles"] for actor in actors.values()),
                             "verified_weapon_profiles": sum(len(actor["weapon_profiles"]) for actor in actors.values()),
                             "verified_weapon_run_roles": sum("run" in profile["roles"] for actor in actors.values()
                                                                for profile in actor["weapon_profiles"].values()),
                             "raw_bytes": sum(len(raw[name]["body"]) for name in selected)}}
    # Every source and address check completes before creating a new output directory.
    output.mkdir(parents=True, exist_ok=False, mode=0o700)
    files = {"manifest.json": json_bytes(manifest), "provenance.json": json_bytes(provenance)}
    files.update({"raw/" + name: raw[name]["body"] for name in sorted(selected)})
    for name, blob in files.items():
        target = output / safe_name(name)
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        with target.open("xb") as stream:
            stream.write(blob)
        target.chmod(0o600)
    pack = output / "TWILIGHT-current523-identity-pack.zip"
    with zipfile.ZipFile(pack, "x", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
        for name, blob in sorted(files.items()):
            info = zipfile.ZipInfo(safe_name(name), date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o600) << 16
            info.compress_type = zipfile.ZIP_STORED
            archive.writestr(info, blob)
    pack.chmod(0o600)
    with zipfile.ZipFile(pack) as archive:
        require(archive.testzip() is None, "generated pack ZIP CRC mismatch")
        require(set(zip_index(archive)) == set(files), "generated pack inventory mismatch")
        require(all(archive.read(name) == blob for name, blob in files.items()), "generated pack bytes mismatch")
    receipt = {"schema": 1, **provenance["counts"], "zip": pack.name, "zip_bytes": pack.stat().st_size,
               "zip_sha256": file_sha(pack), "manifest_bytes": len(files["manifest.json"]),
               "manifest_sha256": sha(files["manifest.json"]), "provenance_sha256": sha(files["provenance.json"]),
               "status": "private_local_verified_not_yet_durable_delivery"}
    (output / "build-receipt.json").write_bytes(json_bytes(receipt))
    print(json.dumps(receipt, sort_keys=True), flush=True)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--tables-zip", type=Path, required=True)
    parser.add_argument("--checkpoints-dir", type=Path, required=True)
    parser.add_argument("--spr-dir", type=Path, required=True)
    parser.add_argument("--spr-proof-zip", type=Path, required=True)
    parser.add_argument("--cards-json", type=Path,
                        default=Path(__file__).resolve().parents[2] / "data/lineagem_base508/cards.json")
    parser.add_argument("--output", type=Path, required=True, help="New private output directory outside the repository")
    args = parser.parse_args()
    try:
        build(args)
    except (ValueError, KeyError, OSError, zipfile.BadZipFile, RuntimeError) as error:
        print(f"CURRENT523_IDENTITY_PACK_FAILED: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
