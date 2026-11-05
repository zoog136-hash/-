#!/usr/bin/env python3
"""Build private runtime projections; v1 stays byte-compatible with PR263.

v2 retains the complete reviewed deck/card/slot graph. Existing primary effects
are replaced only for the one verified Level0 -> Level1 correction; secondary
groups remain references consumed by their independent slot owner.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "76c9e38e90fdbb77ec13931e7e0e319486b8559c"
REGISTRY_COMMIT = "918c8e84e6a5ecbe7a071b263751e10899c282a1"
SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
V1_SHA256 = "98cfdb4f604fba7dad2de41cb290aee3d35087e0d4b805d416a372570dc1cc66"
CHANGED_PRIMARY = ["2:25002:1"]


def git_bytes(path, repository_root=ROOT, commit=COMMIT):
    raw = subprocess.check_output(["git", "show", commit + ":" + path], cwd=repository_root)
    blob = subprocess.check_output(
        ["git", "rev-parse", commit + ":" + path], cwd=repository_root, text=True
    ).strip()
    actual = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
    if actual != blob:
        raise ValueError("Git blob checksum mismatch: " + path)
    return raw, blob


def source(name, repository_root=ROOT):
    raw, blob = git_bytes("data/cards/" + name + ".json", repository_root)
    return json.loads(raw), blob


def project(name, data, blob):
    # Preserve v1 metadata and serialization exactly.
    data["projection_source"] = {"commit": COMMIT, "blob": blob,
                                 "policy": "runtime fields only; original preserved at source"}
    return data


def signature(effect):
    bonus, typ = effect["bonus"], effect["type"]
    return (typ["ID"], bonus["Value"], bonus["BonusApplicationTypeID"],
            bonus["BonusApplicationTargetID"], effect["link"]["Level"],
            json.dumps(effect["unit"], sort_keys=True),
            json.dumps(effect["ui_unit"], sort_keys=True))


def effects(slots, group):
    result = []
    for link in group["links"]:
        bonus = slots["bonuses"][str(link["BonusID"])]
        typ = slots["types"][str(bonus["BonusTypeID"])]
        key = str(typ["UnitID"])
        result.append({"link": link, "bonus": bonus, "type": typ,
                       "unit": slots["units"][key], "ui_unit": slots["ui_units"].get(key, {})})
    return result


def validate_options(slots, base, registry):
    groups = slots["groups"]
    actual_counts = {"cards": len({g["card"]["ID"] for g in groups.values()}),
                     "groups": len(groups),
                     "effects": sum(len(g["links"]) for g in groups.values()),
                     "slot_pairs": sum(g["group"]["SlotIndex"] == 11 for g in groups.values()),
                     "compatible_primary_groups": len(base["definitions"])}
    if actual_counts != {"cards": 305, "groups": 446, "effects": 2392,
                         "slot_pairs": 141, "compatible_primary_groups": 289}:
        raise ValueError("Unexpected option counts")
    if slots["counts"] != actual_counts:
        raise ValueError("Declared option counts disagree")
    if len(registry) != 720:
        raise ValueError("Existing 720-card identity registry required")
    raw_keys = {str(r["source_deck_id"]) + ":" + str(r["source_card_id"]) for r in registry.values()}
    reviewed, changed = [], []
    for row in base["definitions"]:
        old = row["native_source"]
        card = old["card"]
        key = f"{card['BuffCardDeckID']}:{card['ID']}:1"
        group = groups[key]
        if key.rsplit(":", 1)[0] not in raw_keys:
            raise ValueError("Primary group missing from existing registry: " + key)
        if old["group"] != group["group"] or any(
                card[field] != group["card"][field] for field in
                ("BuffCardDeckID", "GradeID", "ServerLimitSetID", "StartDateTimeID", "EndDateTimeID")):
            raise ValueError("Unreviewed primary identity/condition change: " + key)
        target = collections.Counter(map(signature, effects(slots, group)))
        if collections.Counter(map(signature, old["effects"])) != target:
            adjusted = json.loads(json.dumps(old["effects"]))
            touched = set()
            for effect in adjusted:
                if effect["link"]["ID"] in (23062, 23072, 23082) and effect["link"]["Level"] == 0:
                    touched.add(effect["link"]["ID"])
                    effect["link"]["Level"] = 1
            if key != "2:25002:1" or touched != {23062, 23072, 23082} or collections.Counter(map(signature, adjusted)) != target:
                raise ValueError("Unreviewed primary effect change: " + key)
            changed.append(key)
        reviewed.append(key)
    if slots["reviewed_primary_keys"] != sorted(reviewed) or slots["changed_primary_keys"] != sorted(changed) or changed != CHANGED_PRIMARY:
        raise ValueError("Reviewed primary replacement boundary changed")
    removed_names = {2: ["ExperienceAdditionPercent", "CarryPlus", "EinasadSavingPercent"],
                     98: ["ExperienceAdditionPercent", "SpellCastDelayDecreasePercent"]}
    for key, group in groups.items():
        card, raw = group["card"], group["group"]
        if key != f"{card['BuffCardDeckID']}:{card['ID']}:{raw['SlotIndex']}" or raw["BuffCardID"] != card["ID"]:
            raise ValueError("Deck/card/slot join mismatch: " + key)
        if key.rsplit(":", 1)[0] not in raw_keys:
            raise ValueError("Option group missing from existing registry: " + key)
        if raw["SlotIndex"] != 11:
            if raw["SlotIndex"] != 1:
                raise ValueError("Unsupported slot")
            continue
        primary = groups[key.rsplit(":", 1)[0] + ":1"]
        main = collections.Counter(map(signature, effects(slots, primary)))
        extra = collections.Counter(map(signature, effects(slots, group)))
        names = sorted(slots["types"][str(entry[0])]["Name"]
                       for entry, count in (main - extra).items() for _ in range(count))
        if extra - main or names != sorted(removed_names[card["BuffCardDeckID"]]):
            raise ValueError("Unreviewed primary/secondary relation: " + key)
    return actual_counts


def verify_original(source_zip, documents, slots, registry):
    digest = hashlib.sha256(source_zip.read_bytes()).hexdigest()
    if digest != SOURCE_SHA256:
        raise ValueError("Expected the verified patch523 source ZIP")
    with zipfile.ZipFile(source_zip) as archive:
        if archive.testzip() is not None:
            raise ValueError("Source ZIP CRC mismatch")
        tables, hashes = {}, {}
        for document in documents:
            if document.get("source_zip_sha256") != digest:
                raise ValueError("Projection source ZIP identity mismatch")
            for name, expected in document["source_table_sha256"].items():
                if name not in hashes:
                    raw = archive.read("content/" + name + ".json")
                    hashes[name] = hashlib.sha256(raw).hexdigest()
                    tables[name] = json.loads(raw.decode("utf-8-sig"))["rows"]
                if hashes[name] != expected:
                    raise ValueError("Source table SHA256 mismatch: " + name)
        indices = {name: {r["ID"]: r for r in tables[name]}
                   for name in ["BuffCard", "BuffCardOptionAwakenGroup", "BuffCardOptionAwakenLevelBonus", "Bonus", "BonusType", "Unit"]}
        for group in slots["groups"].values():
            if group["card"] != indices["BuffCard"].get(group["card"]["ID"]) or group["group"] != indices["BuffCardOptionAwakenGroup"].get(group["group"]["ID"]):
                raise ValueError("Raw card/group differs from original")
            for link in group["links"]:
                if link != indices["BuffCardOptionAwakenLevelBonus"].get(link["ID"]) or link["BuffCardOptionAwakenGroupID"] != group["group"]["ID"]:
                    raise ValueError("Raw option link differs from original")
        for name, table_name in [("bonuses", "Bonus"), ("types", "BonusType"), ("units", "Unit")]:
            for key, raw in slots[name].items():
                if raw != indices[table_name].get(int(key)):
                    raise ValueError("Raw option value differs from original: " + table_name)
        ui_units = {r["UnitID"]: r for r in tables["UIUnit"]}
        if any(raw != ui_units.get(int(key)) for key, raw in slots["ui_units"].items()):
            raise ValueError("Raw option UI unit differs from original")
        for row in registry.values():
            original = indices["BuffCard"].get(int(row["source_card_id"]))
            if row["source_original_card"] != original or int(row["source_deck_id"]) != original["BuffCardDeckID"]:
                raise ValueError("720 registry identity differs from original: " + row["sourceId"])
        embedded_rows = 0

        def verify_references(value):
            nonlocal embedded_rows
            if isinstance(value, dict):
                if {"table", "row_index_zero", "raw"} <= value.keys():
                    name, index = value["table"], value["row_index_zero"]
                    if name not in tables or type(index) is not int or index < 0 or index >= len(tables[name]) or value["raw"] != tables[name][index]:
                        raise ValueError("Embedded original row mismatch: " + str(name) + ":" + str(index))
                    embedded_rows += 1
                for child in value.values():
                    verify_references(child)
            elif isinstance(value, list):
                for child in value:
                    verify_references(child)

        for document in documents:
            verify_references(document)
    return {"source_zip_sha256": digest, "verified_table_count": len(hashes),
            "source_table_sha256": hashes, "verified_embedded_rows": embedded_rows,
            "zip_crc_checked": True}


def build(output, version=1, repository_root=ROOT, source_zip=None):
    if version not in (1, 2):
        raise ValueError("Unsupported slot pack version")
    if version == 2 and source_zip is None:
        raise ValueError("v2 requires the verified original --source-zip")
    sections, documents = {}, []
    new, blob = source("patch523_new_cards", repository_root)
    documents.append(new)
    registry_bytes, registry_blob = git_bytes("data/lineagem_base508/cards_patch523.json", repository_root, REGISTRY_COMMIT)
    catalog = json.loads(registry_bytes)
    by_id = {r["sourceId"]: r for rows in catalog["catalog"].values() for r in rows}
    identities = set()
    for category, rows in new["catalog"].items():
        overlays = []
        for row in rows:
            base = by_id[row["sourceId"]]
            if row["source_original_card"] != base["source_original_card"]:
                raise ValueError("New-card overlay original identity mismatch")
            identities.add(row["sourceId"])
            overlay = {k: v for k, v in row.items() if k not in base or base[k] != v}
            overlay["sourceId"] = row["sourceId"]
            overlays.append(overlay)
        new["catalog"][category] = overlays
    if len(by_id) != 720 or len(identities) != 16:
        raise ValueError("Expected 720 registered identities and 16 overlays")
    sections["new_cards"] = project("patch523_new_cards", new, blob)

    slots, blob = source("patch523_option_slots", repository_root)
    documents.append(slots)
    if version == 1:
        keys = {identity.split(":", 1)[1] for identity in identities}
        slots["groups"] = {k: v for k, v in slots["groups"].items() if k.rsplit(":", 1)[0] in keys}
        used = {str(int(link["BonusID"])) for row in slots["groups"].values() for link in row["links"]}
        slots["bonuses"] = {k: v for k, v in slots["bonuses"].items() if k in used}
        slots["reviewed_primary_keys"] = []
        slots["changed_primary_keys"] = []
        slots["counts"] = {"groups": len(slots["groups"]), "bonuses": len(used)}
    else:
        base_bytes, _ = git_bytes("data/cards/base508_option_awakening.json", repository_root, REGISTRY_COMMIT)
        validate_options(slots, json.loads(base_bytes), by_id)
        primary_keys = {k for k, row in slots["groups"].items() if row["group"]["SlotIndex"] == 1}
        new_keys = {identity.split(":", 1)[1] + ":1" for identity in identities}
        if set(slots["reviewed_primary_keys"]) & new_keys or primary_keys != set(slots["reviewed_primary_keys"]) | new_keys:
            raise ValueError("Existing/new primary ownership boundary mismatch")
    sections["options"] = project("patch523_option_slots", slots, blob)

    relic, blob = source("patch523_relic_subslot", repository_root)
    documents.append(relic)
    card_fields = {"Name", "ID", "BuffCardDeckID", "GradeID", "StartDateTimeID", "EndDateTimeID", "ServerLimitSetID"}
    rows = {}
    for key, row in relic["cards"].items():
        out = {"card": {k: v for k, v in row["card"].items() if k in card_fields},
               "source_card_row_index_zero": row["source_card_row_index_zero"],
               "effects": row["effects"], "summon_binding": row["summon_binding"]}
        if "subslot_buff" in row:
            out["subslot_buff"] = {"ID": row["subslot_buff"]["ID"]}
        rows[key] = out
    relic["cards"] = rows
    for key in ["summon_item", "deck", "buff_groups", "equip_slots", "equip_slot_configs"]:
        relic.pop(key, None)
    sections["relic"] = project("patch523_relic_subslot", relic, blob)
    combat, blob = source("patch523_relic_combat", repository_root)
    documents.append(combat)
    sections["relic_combat"] = project("patch523_relic_combat", {
        k: combat[k] for k in ["relic_subslot_buffs", "invoke_options", "invoke_spells"]
    }, blob)
    result = {"schema": "twilight.card-slots523.v" + str(version), "source_commit": COMMIT, **sections}
    if version == 2:
        for name in ["card_acquisition", "relic_acquisition"]:
            document, blob = source("patch523_" + name, repository_root)
            documents.append(document)
            result[name] = project("patch523_" + name, document, blob)
        result["verification"] = verify_original(source_zip, documents, slots, by_id)
        result["verification"]["registry_blob"] = registry_blob
        result["execution_contract"] = {
            "primary": "replace only changed_primary_keys; never append the reviewed graph to primary stats",
            "secondary": "slot11 groups are consumed only by the independently eligible secondary owner",
            "ownership": "overlay 16 existing identities; never add cards to the 720 registry",
            "same_awakening_ledger": True,
        }
    payload = (json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n").encode()
    digest = hashlib.sha256(payload).hexdigest()
    if version == 1 and digest != V1_SHA256:
        raise ValueError("v1 reproduction mismatch; refusing to replace a compatible pack")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(payload)
    print(json.dumps({"path": str(output), "bytes": len(payload), "sha256": digest,
                      "schema": result["schema"]}, ensure_ascii=False))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", type=int, choices=(1, 2), default=1)
    parser.add_argument("--repository-root", type=Path, default=ROOT)
    parser.add_argument("--source-zip", type=Path)
    args = parser.parse_args()
    build(args.output, args.version, args.repository_root, args.source_zip)
