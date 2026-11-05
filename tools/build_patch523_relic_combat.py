#!/usr/bin/env python3
"""Extract only relic22182's verified secondary Invoke16572 -> Spell89552."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
import zlib

SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
REFERENCE_SHA256 = "d32f3cbddce846ad6855d582cb59ba38c48cd0dc5700d126a7551058428a9dbf"
EXPECTED_VALUES = {"SpellDamageBase": 500, "SpellDamageDiceNumber": 1,
                   "SpellDamageDiceSpotCount": 1, "FixedMagicDamage": 1,
                   "IgnoreMagicResistance": 1, "IgnoreDamageReductionCalculation": 1}
IGNORED_OPTION_FIELDS = {"ID", "Param1", "DescID"}
ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


class Source:
    def __init__(self, path):
        require(sha(path.read_bytes()) == SOURCE_SHA256, "Unreviewed source ZIP")
        self.archive = zipfile.ZipFile(path)
        self.index = {r["path"]: r for r in json.loads(self.archive.read("index.json"))}
        self.tables = {}
        self.hashes = {}
        self.references = {}

    def rows(self, name):
        if name not in self.tables:
            member = "content/" + name + ".json"
            raw = self.archive.read(member)
            spec = self.index[member]
            rows = json.loads(raw.decode("utf-8-sig"))["rows"]
            require(sha(raw) == spec["sha256"] and len(raw) == spec["bytes"], name + " source SHA/size mismatch")
            require(f"{zlib.crc32(raw) & 0xffffffff:08x}" == spec["crc32"] and len(rows) == spec["row_count"], name + " source CRC/count mismatch")
            self.tables[name] = rows
            self.hashes[name] = sha(raw)
        return self.tables[name]

    def matching(self, name, **fields):
        result = []
        for index, row in enumerate(self.rows(name)):
            if all(row.get(key) == value for key, value in fields.items()):
                self.references[(name, index)] = {"table": name, "row_index_zero": index, "raw": row}
                result.append(row)
        return result

    def one(self, name, **fields):
        rows = self.matching(name, **fields)
        require(len(rows) == 1, name + " expected exactly one row: " + str(fields))
        return rows[0]

    def effect(self, link):
        bonus = self.one("Bonus", ID=link["BonusID"])
        typ = self.one("BonusType", ID=bonus["BonusTypeID"])
        return {"link": link, "bonus": bonus, "type": typ,
                "unit": self.one("Unit", ID=typ["UnitID"]),
                "ui_unit": self.one("UIUnit", UnitID=typ["UnitID"])}


def fixed_values(effects):
    require(len(effects) == 6, "Expected exactly six fixed spell effects")
    values = {}
    for effect in effects:
        name = effect["type"]["Name"]
        require(name in EXPECTED_VALUES and name not in values, "Unsupported or duplicate fixed spell effect")
        require(effect["link"]["MinSpellLevel"] == 0, "Conditional spell level not supported")
        require(effect["bonus"]["BonusApplicationTypeID"] == effect["bonus"]["BonusApplicationTargetID"] == 0, "Conditional spell bonus not supported")
        expected_unit = "TrueFalse" if name in ["FixedMagicDamage", "IgnoreMagicResistance"] else "Value"
        require(effect["unit"]["Name"] == expected_unit, "Fixed spell unit mismatch")
        values[name] = effect["bonus"]["Value"]
    require(values == EXPECTED_VALUES, "Fixed six-effect values changed")
    return values


def build(source_path, reference_path):
    reference_raw = reference_path.read_bytes()
    require(sha(reference_raw) == REFERENCE_SHA256, "Unreviewed existing Invoke reference")
    reference = json.loads(reference_raw)
    source = Source(source_path)
    card = source.one("BuffCard", ID=22182)
    require(card["BuffCardDeckID"] == 98 and card["BuffClassID"] == 77052, "Relic identity changed")
    main_buff = source.one("BuffClass", ID=card["BuffClassID"])
    subslot_type = source.one("BonusType", Name="SubSlotBuffClassID")
    main_links = source.matching("BuffBonus", BuffClassID=main_buff["ID"])
    subslot_links = [r for r in main_links if source.one("Bonus", ID=r["BonusID"])["BonusTypeID"] == subslot_type["ID"]]
    require(len(subslot_links) == 1, "Ambiguous secondary buff link")
    subslot_effect = source.effect(subslot_links[0])
    require(subslot_effect["bonus"]["Value"] == 98108, "Unexpected secondary relic buff")
    require(all(subslot_effect["link"][key] == 0 for key in ["CharacterLevel", "CharacterClass", "MinSpellLevel"]), "Conditional secondary link")
    require(subslot_effect["bonus"]["BonusApplicationTypeID"] == subslot_effect["bonus"]["BonusApplicationTargetID"] == 0, "Conditional secondary bonus")
    subslot_buff = source.one("BuffClass", ID=98108)
    trigger = source.effect(source.one("BuffBonus", ID=402208, BuffClassID=subslot_buff["ID"], BonusID=2365228))
    require(trigger["type"]["Name"] == "InvokeOption" and trigger["bonus"]["BonusApplicationTypeID"] == 10 and trigger["bonus"]["BonusApplicationTargetID"] == 16572, "Secondary Invoke chain mismatch")
    require(all(trigger["link"][key] == 0 for key in ["CharacterLevel", "CharacterClass", "MinSpellLevel"]), "Conditional secondary Invoke link")
    require(trigger["unit"]["Name"] == "Percentage" and trigger["ui_unit"]["Denominator"] == 10000 and trigger["bonus"]["Value"] == 30000, "Invoke raw percentage contract changed")
    application_type = source.one("BonusApplicationType", ID=10)
    require(application_type["Name"] == "InvokeOption", "Invoke application type mismatch")
    option = source.one("InvokeOption", ID=16572)
    approved = next(r for r in reference["invoke_options"] if r["ID"] == 10661)
    approved_source = source.one("InvokeOption", ID=10661)
    require(approved == approved_source, "Existing approved Invoke changed in523")
    require(set(option) == set(approved), "Invoke field schema differs from approved row")
    compared_fields = sorted(set(option) - IGNORED_OPTION_FIELDS)
    require(all(option[key] == approved[key] for key in compared_fields), "Invoke conditions differ from approved row")
    require(option["Param1"] == 89552, "Unexpected invoked spell")
    option_type = source.one("InvokeOptionType", ID=option["InvokeOptionTypeID"])
    require(option_type["Name"] == "Attack_Spell", "Unexpected Invoke type")

    spell = source.one("SpellClass", ID=89552)
    effects = [source.effect(r) for r in source.matching("SpellBonus", SpellClassID=89552)]
    fixed_values(effects)
    approved_spell = reference["invoke_spells"]["67401"]
    require(source.one("SpellClass", ID=67401) == approved_spell["source_spell"], "Existing fixed spell reference changed")
    approved_effects = [source.effect(r) for r in source.matching("SpellBonus", SpellClassID=67401)]
    require(approved_effects == approved_spell["effects"], "Existing fixed spell effects changed")
    fixed_values(approved_effects)
    require(not spell["TestSpell"] and spell["TargettingTypeID"] == 2 and spell["TargetAreaRadius"] == 0, "Unsupported target/test spell")
    require(all(spell[key] == 0 for key in ["HPCost", "MPCost", "VPCost"]), "Resource-consuming spell unsupported")
    material = source.one("SpellMaterialType", ID=spell["SpellMaterialTypeID"])
    require(material["ID"] == 0 and material["Name"] == "None", "Only explicit None material supported")
    return {
        "schema": 1, "source_snapshot": "patch523", "source_zip": source_path.name,
        "source_zip_sha256": SOURCE_SHA256, "reference_sha256": REFERENCE_SHA256,
        "scope": "active_verified_secondary_relic_22182_only_existing_InvokeOption_contract",
        "supported_card_ids": [22182], "supported_invoke_option_ids": [16572], "supported_spell_ids": [89552],
        "relic_subslot_buffs": {"98:22182": {"card": card, "effects": [trigger]}},
        "invoke_options": [option], "invoke_spells": {"89552": {"source_spell": spell, "effects": effects}},
        "spell_material_types": [material],
        "source_chain": {"card": card, "main_buff": main_buff, "subslot_link": subslot_effect, "subslot_buff": subslot_buff,
                         "application_type": application_type, "invoke_option_type": option_type},
        "approved_contract_comparison": {"reference_option_id": 10661, "reference_spell_id": 67401,
            "excluded_fields": sorted(IGNORED_OPTION_FIELDS), "compared_fields": compared_fields,
            "all_conditions_equal": True, "source_reference_option": approved_source,
            "fixed_six_values_equal": True, "fixed_values": EXPECTED_VALUES},
        "boundaries": ["No other relic Invoke is authorized by this extraction.",
            "Keep existing verified ownership, secondary-slot eligibility, server and time checks.",
            "Invoke raw percentage is preserved; no new trigger, probability convention, growth rule or damage formula is introduced.",
            "The full SpellClass row and its explicit None material type remain authoritative; art availability is separate."],
        "source_table_sha256": dict(sorted(source.hashes.items())),
        "source_rows": [source.references[key] for key in sorted(source.references)],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--reference", type=Path, default=ROOT / "data/cards/base508_option_extensions.json")
    parser.add_argument("--output", type=Path, default=ROOT / "data/cards/patch523_relic_combat.json")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    data = build(args.source, args.reference)
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if args.verify:
        require(args.output.read_text(encoding="utf-8") == text, "Committed relic combat export differs from source")
    else:
        args.output.write_text(text, encoding="utf-8")
    print("PATCH523_RELIC_COMBAT " + json.dumps({"cards": 1, "invoke_options": 1, "spells": 1, "spell_effects": 6,
        "compared_condition_fields": len(data["approved_contract_comparison"]["compared_fields"]),
        "raw_references": len(data["source_rows"]), "tables": len(data["source_table_sha256"]), "verified": True}))


if __name__ == "__main__":
    main()
