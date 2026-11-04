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
LAYER_POLICY = "declared_action_if_parent_tokens_equal;otherwise_absent_action_uses_exact_parent_token_index"
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
    return original_spr.read(paths), observed, {"archive": proof_pin, "member": PROOF_MEMBER,
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


def build_actor(root_id, declarations, spr_proofs, source_roles=ROLES):
    body_id, actions = original_spr.resolve(declarations, root_id)
    paths = [{"kind": "body", "declaration_path": declaration_path(declarations, root_id, spr_proofs)}]
    layers = [{"kind": "body", "source_sprite_id": body_id, "actions": actions, "edge_path": []}]
    visited = set()

    def attach(sprite_id, parent_actions, edges, seen=()):
        require(sprite_id not in seen, f"SPR layer cycle {seen + (sprite_id,)}")
        references = original_spr.resolve_references(declarations, sprite_id)
        for kind, refs in references.items():
            require(kind in ("shadow", "clothes"), f"unknown SPR layer kind {kind}")
            for reference in refs:
                require(reference["count_valid"], f"invalid layer target count {sprite_id}")
                for target in reference["targets"]:
                    edge = {"from_sprite_id": sprite_id, "target_sprite_id": target,
                            "kind": kind, "source_reference": reference["raw"]}
                    require((sprite_id, kind, target) not in visited, f"duplicate SPR layer edge {edge}")
                    visited.add((sprite_id, kind, target))
                    target_body, target_actions = original_spr.resolve(declarations, target)
                    inherited_actions, policies = {}, {}
                    for role, action_id in source_roles:
                        parent = parent_actions[action_id]
                        own = target_actions.get(action_id)
                        if own is not None:
                            require(not own["errors"] and own["tokens"] == parent["tokens"]
                                    and own["declared_flag"] == parent["declared_flag"]
                                    and own["fps"] in (None, parent["fps"]), f"independent layer timing unsupported: {target}/{role}")
                        inherited_actions[action_id] = own if own is not None else parent
                        policies[role] = "declared_matching_action" if own is not None else "absent_action_exact_parent_token_index"
                    layers.append({"kind": kind, "source_sprite_id": target_body,
                                   "actions": inherited_actions, "edge_path": edges + [edge]})
                    paths.append({"kind": kind, "edge_path": edges + [edge], "role_policy": policies,
                                  "declaration_path": declaration_path(declarations, target, spr_proofs)})
                    attach(target, inherited_actions, edges + [edge], seen + (sprite_id,))

    for role, action_id in source_roles:
        require(action_id in actions and not actions[action_id]["errors"], f"absent/invalid source action {root_id}/{role}")
        require(actions[action_id]["declared_flag"] in (0, 1), f"unknown direction flag {root_id}/{role}")
    attach(root_id, actions, [])
    layers.sort(key=lambda layer: {"shadow": 0, "body": 1, "clothes": 2}[layer["kind"]])
    roles, required, action_proofs = {}, set(), {}
    for role, action_id in source_roles:
        action = actions[action_id]
        directions = []
        for direction in range(8):
            frames = []
            for token_index, (_, _, ticks) in enumerate(action["tokens"]):
                frame_layers = []
                for layer in layers:
                    source = layer["actions"][action_id]
                    group, frame_index, _ = source["tokens"][token_index]
                    physical, bit = original_spr.frame_address(group, direction, source["declared_flag"])
                    member = f"Sprite/{layer['source_sprite_id']}-{physical}.sp2"
                    required.add(member)
                    frame_layers.append({"member": member, "group_bit": bit, "frame_index": frame_index,
                                         "kind": layer["kind"], "source_sprite_id": layer["source_sprite_id"]})
                frames.append({"duration_ticks": ticks, "layers": frame_layers})
            directions.append(frames)
        roles[role] = {"source_action_id": action_id, "source_file": action["source_file"],
                       "source_line": action["source_line"], "fps": action["fps"], "loop": role != "attack",
                       "directions": directions}
        action_proofs[role] = {"source_action_id": action_id, **action,
                               "source_sha256": spr_proofs[action["source_file"]]["sha256"]}
    return {"source_sprite_id": root_id, "roles": roles}, required, {
        "root_sprite_id": root_id, "body_sprite_id": body_id, "declarations": paths,
        "roles": action_proofs, "layer_policy": LAYER_POLICY}


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
    for role, track in actor["roles"].items():
        action = proof["roles"][role]
        first = track["directions"][0][0]["layers"]
        layers = [{"source_sprite_id": layer["source_sprite_id"], "kind": layer["kind"]} for layer in first]
        for frames in track["directions"]:
            for frame in frames:
                require(layers == [{"source_sprite_id": layer["source_sprite_id"], "kind": layer["kind"]}
                                   for layer in frame["layers"]], "compact track changes layer identities")
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
