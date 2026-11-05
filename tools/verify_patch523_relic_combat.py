#!/usr/bin/env python3
"""Independently compare the restricted relic combat export to source ZIP rows."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import zipfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
REFERENCE_SHA256 = "d32f3cbddce846ad6855d582cb59ba38c48cd0dc5700d126a7551058428a9dbf"


def demand(value, message):
    if not value:
        raise ValueError(message)


def verify(data, archive, reference_raw):
    demand(hashlib.sha256(reference_raw).hexdigest() == REFERENCE_SHA256, "Reference hash")
    reference = json.loads(reference_raw)
    index = {r["path"]: r for r in json.loads(archive.read("index.json"))}
    tables = {}
    for name, expected in data["source_table_sha256"].items():
        raw = archive.read("content/" + name + ".json")
        spec = index["content/" + name + ".json"]
        actual = hashlib.sha256(raw).hexdigest()
        tables[name] = json.loads(raw.decode("utf-8-sig"))["rows"]
        demand(actual == expected == spec["sha256"] and len(raw) == spec["bytes"], "Table SHA/size " + name)
        demand(len(tables[name]) == spec["row_count"] and f"{zlib.crc32(raw) & 0xffffffff:08x}" == spec["crc32"], "Table count/CRC " + name)

    def one(name, **fields):
        values = [r for r in tables[name] if all(r.get(key) == value for key, value in fields.items())]
        demand(len(values) == 1, "Nonunique source row " + name)
        return values[0]

    def effect(link):
        bonus = one("Bonus", ID=link["BonusID"])
        typ = one("BonusType", ID=bonus["BonusTypeID"])
        return {"link": link, "bonus": bonus, "type": typ, "unit": one("Unit", ID=typ["UnitID"]), "ui_unit": one("UIUnit", UnitID=typ["UnitID"])}

    demand(data["schema"] == 1 and data["source_snapshot"] == "patch523", "Schema")
    demand(data["source_zip_sha256"] == SOURCE_SHA256 and data["reference_sha256"] == REFERENCE_SHA256, "Provenance")
    demand(data["scope"] == "active_verified_secondary_relic_22182_only_existing_InvokeOption_contract", "Activation scope")
    demand(data["supported_card_ids"] == [22182] and data["supported_invoke_option_ids"] == [16572] and data["supported_spell_ids"] == [89552], "Overbroad scope")
    demand(set(data["relic_subslot_buffs"]) == {"98:22182"}, "Extra relic buff")
    card = one("BuffCard", ID=22182)
    trigger = effect(one("BuffBonus", ID=402208, BuffClassID=98108, BonusID=2365228))
    demand(data["relic_subslot_buffs"]["98:22182"] == {"card": card, "effects": [trigger]}, "Runtime trigger differs from source")
    demand(trigger["bonus"]["Value"] == 30000 and trigger["bonus"]["BonusApplicationTypeID"] == 10 and trigger["bonus"]["BonusApplicationTargetID"] == 16572, "Raw Invoke boundary")
    demand(trigger["unit"]["Name"] == "Percentage" and trigger["ui_unit"]["Denominator"] == 10000, "Raw Invoke units")
    option = one("InvokeOption", ID=16572)
    demand(data["invoke_options"] == [option] and set(data["invoke_spells"]) == {"89552"}, "Extra or changed runtime Invoke")
    approved = next(r for r in reference["invoke_options"] if r["ID"] == 10661)
    ignored = {"ID", "Param1", "DescID"}
    fields = sorted(set(option) - ignored)
    demand(one("InvokeOption", ID=10661) == approved and set(option) == set(approved), "Approved reference changed")
    demand(all(option[key] == approved[key] for key in fields), "Condition fields differ")
    spell = one("SpellClass", ID=89552)
    links = [r for r in tables["SpellBonus"] if r["SpellClassID"] == 89552]
    effects = [effect(r) for r in links]
    demand(data["invoke_spells"]["89552"] == {"source_spell": spell, "effects": effects}, "Runtime spell differs from source")
    expected_values = {"SpellDamageBase": 500, "SpellDamageDiceNumber": 1, "SpellDamageDiceSpotCount": 1,
                       "FixedMagicDamage": 1, "IgnoreMagicResistance": 1, "IgnoreDamageReductionCalculation": 1}
    demand(len(effects) == 6 and {e["type"]["Name"]: e["bonus"]["Value"] for e in effects} == expected_values, "Fixed six effects")
    for e in effects:
        demand(e["link"]["MinSpellLevel"] == e["bonus"]["BonusApplicationTypeID"] == e["bonus"]["BonusApplicationTargetID"] == 0, "Conditional spell")
        demand(e["unit"]["Name"] == ("TrueFalse" if e["type"]["Name"] in ["FixedMagicDamage", "IgnoreMagicResistance"] else "Value"), "Spell unit")
    demand(not spell["TestSpell"] and spell["TargettingTypeID"] == 2 and spell["TargetAreaRadius"] == 0, "Target restrictions")
    demand(all(spell[k] == 0 for k in ["HPCost", "MPCost", "VPCost"]), "Resource cost")
    material = one("SpellMaterialType", ID=spell["SpellMaterialTypeID"])
    demand(material["ID"] == 0 and material["Name"] == "None" and data["spell_material_types"] == [material], "Material type")
    chain = data["source_chain"]
    demand(chain["card"] == card and chain["main_buff"] == one("BuffClass", ID=77052) and card["BuffClassID"] == 77052, "Main buff chain")
    demand(chain["subslot_link"] == effect(one("BuffBonus", ID=405598, BuffClassID=77052, BonusID=2368608)), "Subslot link")
    demand(chain["subslot_link"]["bonus"]["Value"] == 98108 and chain["subslot_link"]["type"]["Name"] == "SubSlotBuffClassID", "Subslot target")
    demand(chain["subslot_buff"] == one("BuffClass", ID=98108), "Subslot buff")
    demand(chain["application_type"] == one("BonusApplicationType", ID=10) and chain["invoke_option_type"] == one("InvokeOptionType", ID=1), "Typed Invoke references")
    comparison = data["approved_contract_comparison"]
    demand(comparison["reference_option_id"] == 10661 and comparison["reference_spell_id"] == 67401 and comparison["excluded_fields"] == sorted(ignored) and comparison["compared_fields"] == fields, "Comparison scope")
    demand(comparison["all_conditions_equal"] is True and comparison["fixed_six_values_equal"] is True and comparison["fixed_values"] == expected_values and comparison["source_reference_option"] == approved, "Comparison result")
    ref_spell = reference["invoke_spells"]["67401"]
    demand(ref_spell["source_spell"] == one("SpellClass", ID=67401), "Reference spell source")
    ref_effects = [effect(r) for r in tables["SpellBonus"] if r["SpellClassID"] == 67401]
    demand(ref_effects == ref_spell["effects"] and {e["type"]["Name"]: e["bonus"]["Value"] for e in ref_effects} == expected_values, "Reference fixed six effects")
    identities = set()
    for row in data["source_rows"]:
        key = (row["table"], row["row_index_zero"])
        demand(key not in identities, "Duplicate evidence reference")
        identities.add(key)
        demand(tables[row["table"]][row["row_index_zero"]] == row["raw"], "Raw evidence row mismatch")
    demand(len(identities) > 30, "Evidence reference set incomplete")
    return {"raw_references": len(identities), "tables": len(tables), "condition_fields": len(fields), "spell_effects": len(effects)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--data", type=Path, default=ROOT / "data/cards/patch523_relic_combat.json")
    parser.add_argument("--reference", type=Path, default=ROOT / "data/cards/base508_option_extensions.json")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    demand(hashlib.sha256(args.source.read_bytes()).hexdigest() == SOURCE_SHA256, "Source ZIP hash")
    data = json.loads(args.data.read_text(encoding="utf-8"))
    reference_raw = args.reference.read_bytes()
    with zipfile.ZipFile(args.source) as archive:
        result = verify(data, archive, reference_raw)
        rejected = 0
        if args.self_test:
            cases = []
            changed = copy.deepcopy(data);changed["invoke_options"][0]["WeaponGroupID"] = 1;cases.append(changed)
            changed = copy.deepcopy(data);changed["supported_card_ids"].append(21518);cases.append(changed)
            changed = copy.deepcopy(data);changed["invoke_spells"]["89552"]["effects"][0]["bonus"]["Value"] += 1;cases.append(changed)
            changed = copy.deepcopy(data);changed["relic_subslot_buffs"]["98:22182"]["effects"][0]["bonus"]["Value"] = 1000000;cases.append(changed)
            changed = copy.deepcopy(data);changed["invoke_spells"]["89552"]["source_spell"]["TestSpell"] = True;cases.append(changed)
            for changed in cases:
                try:
                    verify(changed, archive, reference_raw)
                except ValueError:
                    rejected += 1
            demand(rejected == len(cases), "Unsafe mutation accepted")
    print("VERIFY_PATCH523_RELIC_COMBAT " + json.dumps({**result, "unsafe_mutations_rejected": rejected, "verified": True}, sort_keys=True))


if __name__ == "__main__":
    main()
