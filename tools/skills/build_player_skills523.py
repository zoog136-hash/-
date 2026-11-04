"""Compile exact 523 skill evidence into an external, hash-pinned runtime pack.

Original rows stay outside the public repository. No damage/hit/proc formula is
evaluated here, and no skill is chosen by fuzzy name or lowest numeric ID.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import os
import tempfile
import zipfile

SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
TABLES = ("SpellClass", "SpellLearnLimit", "Class", "SpellCost", "SpellBonus",
          "Bonus", "BonusType", "Unit", "BuffClass", "BuffBonus", "TargetKind",
          "TargettingType", "SpellMaterialType", "ItemClass", "ItemBonus",
          "SpellChangeCastGroup", "UIUnit", "BuffGroup", "BonusApplicationType", "SpecialResistanceType")
RECOVERY_ROOTS = {54703, 35443, 69601, 95662}


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def unique(rows, table):
    result = {}
    for row in rows:
        if row["ID"] in result:
            raise ValueError(f"duplicate {table} ID {row['ID']}")
        result[row["ID"]] = row
    return result


def compile_pack(source: Path, bindings_path: Path):
    if digest(source.read_bytes()) != SOURCE_SHA256:
        raise ValueError("expected exact cumulative523 source ZIP")
    binding_bytes = bindings_path.read_bytes()
    bindings = json.loads(binding_bytes)
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError("source ZIP CRC failed")
        index = {entry["path"]: entry for entry in json.loads(archive.read("index.json"))}
        tables = {}
        provenance = {}
        for name in TABLES:
            path = f"content/{name}.json"
            raw = archive.read(path)
            expected = index[path]
            if digest(raw) != expected["sha256"] or len(raw) != expected["bytes"]:
                raise ValueError(f"source table hash/size mismatch: {path}")
            tables[name] = json.loads(raw)["rows"]
            if len(tables[name]) != expected["row_count"]:
                raise ValueError(f"source table row count mismatch: {path}")
            provenance[name] = {key: expected[key] for key in ("sha256", "bytes", "row_count")}
    indexed = {name: unique(tables[name], name) for name in TABLES if name != "SpellLearnLimit"}

    def evidence(link):
        bonus = indexed["Bonus"][link["BonusID"]]
        kind = indexed["BonusType"][bonus["BonusTypeID"]]
        return {"link": link, "bonus": bonus, "type": kind,
                "unit": indexed["Unit"][kind["UnitID"]]}

    def profile_for(spell):
        bonuses = [evidence(r) for r in tables["SpellBonus"] if r["SpellClassID"] == spell["ID"]]
        buff_ids = {e["bonus"]["Value"] for e in bonuses
                    if e["type"]["Name"] in ("BuffClassID", "SideEffectBuffClassID")}
        buffs = [{"row": indexed["BuffClass"][buff_id],
                  "bonuses": [evidence(r) for r in tables["BuffBonus"] if r["BuffClassID"] == buff_id]}
                 for buff_id in sorted(buff_ids)]
        return {"row": spell, "row_json": canonical(spell).decode(),
            "learn_limits": [r for r in tables["SpellLearnLimit"] if r["SpellClassID"] == spell["ID"]], "bonuses": bonuses, "buffs": buffs,
            "costs": [r for r in tables["SpellCost"] if r["SpellClassID"] == spell["ID"]],
            "cast_groups": [r for r in tables["SpellChangeCastGroup"] if r["SpellClassID"] == spell["ID"]],
            "target_kind": indexed["TargetKind"][spell["TargetKindID"]],
            "targeting_type": indexed["TargettingType"][spell["TargettingTypeID"]]}

    profiles = {}
    for host_id, binding in bindings["skills"].items():
        spell = indexed["SpellClass"][binding["spell_id"]]
        if digest(canonical(spell)) != binding["row_sha256"] or spell["TestSpell"]:
            raise ValueError(f"unreviewed source row: {host_id}")
        profile = profile_for(spell)
        if not profile["learn_limits"] or all(r["IsTutorialSpell"] for r in profile["learn_limits"]):
            raise ValueError(f"not a learnable ordinary player source: {host_id}")
        if spell["ID"] in RECOVERY_ROOTS:
            child_ids = list(dict.fromkeys(e["bonus"]["Value"] for e in profile["bonuses"]
                if e["type"]["Name"] == "SpellClassID" and e["unit"]["Name"] == "SpellClassID"
                and e["link"]["MinSpellLevel"] == 0 and e["bonus"]["BonusApplicationTypeID"] == 0
                and e["bonus"]["BonusApplicationTargetID"] == 0))
            profile["components"] = [profile_for(indexed["SpellClass"][i]) for i in child_ids]
        profiles[host_id] = profile
    materials = {}
    for link in tables["ItemBonus"]:
        bonus = indexed["Bonus"][link["BonusID"]]
        if bonus["BonusTypeID"] == 89:
            material = str(bonus["Value"])
            materials.setdefault(material, []).append({"item": indexed["ItemClass"][link["ItemClassID"]],
                                                      "evidence": evidence(link)})
    # Validate every host material key against its explicit native item identity;
    # display-name similarity never makes an item eligible for consumption.
    for material, bridge in bindings["material_inventory_keys"].items():
        if not any(e["item"]["ID"] == bridge["native_item_id"] for e in materials.get(material, [])):
            raise ValueError(f"unverified material bridge {material}")
    return {"schema_version": 1, "patch": 523, "source_zip_sha256": SOURCE_SHA256,
            "bindings_sha256": digest(binding_bytes), "tables": provenance,
            "classes": tables["Class"], "materials": materials, "profiles": profiles,
            "ui_units": tables["UIUnit"], "buff_groups": tables["BuffGroup"],
            "bonus_application_types": tables["BonusApplicationType"], "special_resistance_types": tables["SpecialResistanceType"],
            "features": ["self_recovery_components_v1"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-zip", type=Path, required=True)
    parser.add_argument("--bindings", type=Path, default=Path(__file__).resolve().parents[2] / "data/skills/player_skills523_bindings.json")
    parser.add_argument("--output", type=Path, required=True, help="external private JSON; never a repository path")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    if args.output.resolve().is_relative_to(repo):
        parser.error("original-derived runtime pack must remain outside the repository")
    pack = compile_pack(args.source_zip, args.bindings)
    raw = canonical(pack) + b"\n"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".skills523-", dir=args.output.parent)
    try:
        with os.fdopen(fd, "wb") as out:
            out.write(raw)
            out.flush()
            os.fsync(out.fileno())
        os.replace(temporary, args.output)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print(json.dumps({"path": str(args.output), "bytes": len(raw), "sha256": digest(raw),
                      "profiles": len(pack["profiles"]), "delivery": "PRIVATE_LOCAL_ONLY"}))


if __name__ == "__main__":
    main()
