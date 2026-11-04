#!/usr/bin/env python3
"""Compile exact book-to-existing-skill contracts; raw source rows stay private."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"


def build(archive, reviewed):
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SOURCE:
        raise ValueError("unexpected source archive")
    if reviewed.get("source_zip_sha256") != SOURCE:
        raise ValueError("reviewed skill mapping has different source")
    with zipfile.ZipFile(archive) as pack:
        if pack.testzip() is not None:
            raise ValueError("source CRC failure")
        def rows(name):
            return json.loads(pack.read("content/"+name+".json"))["rows"]
        bonuses = {r["ID"]: r for r in rows("Bonus")}
        types = {r["ID"]: r["Name"] for r in rows("BonusType")}
        cards = {r["ID"]: r for r in rows("BuffCard")}
        spells = {r["ID"]: r for r in rows("SpellClass")}
        items = {r["ID"]: r for r in rows("ItemClass")}
        learn_limits = rows("SpellLearnLimit")
        labels = {r["ID"]: r["Description"] for r in rows("DescData_Korean")}
        reviewed_spells = {}
        for key, entry in reviewed["skills"].items():
            spell = spells[entry["spell_id"]]
            digest = hashlib.sha256(json.dumps(spell, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
            if digest != entry["row_sha256"]:
                raise ValueError("reviewed spell row changed: "+key)
            if entry["spell_id"] in reviewed_spells:
                raise ValueError("ambiguous reviewed spell")
            reviewed_spells[entry["spell_id"]] = key
        item_cards = {}
        for row in rows("ItemBonus"):
            bonus = bonuses[row["BonusID"]]
            if not row["IsPossession"] and types[bonus["BonusTypeID"]] == "BuffCardID":
                item_cards.setdefault(row["ItemClassID"], set()).add(bonus["Value"])
        output = {}
        for sale in rows("MerchantGoods"):
            if sale["MerchantsID"] != 10 or sale["DialogActionTypeID"] != 1:
                continue
            item, card = items[sale["ItemClassID"]], cards.get(sale["LimitRepeatedBuyCardID"], {})
            spell_id = card.get("SpellClassID", 0)
            if item_cards.get(item["ID"], set()) != {card.get("ID")} or spell_id not in reviewed_spells or item["TestItem"]:
                continue
            classes = {}
            for job, class_id in reviewed["class_ids"].items():
                limits = [r for r in learn_limits if r["SpellClassID"] == spell_id and r["ClassID"] == class_id and not r["IsTutorialSpell"]]
                if limits:
                    classes[job] = [{"minimum_level": r["CharacterMinLevel"], "required_card": r["LimitBuffCardID"], "polymorph_grade": r["CharacterPolymorphGradeID"]} for r in limits]
            output[str(item["ID"])] = {"name": labels[item["DescID"]], "card_id": card["ID"], "spell_id": spell_id, "skill_id": reviewed_spells[spell_id], "classes": classes}
        return {"schema": "twilight.source523.book-contracts.v1", "source_sha256": SOURCE, "books": output}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("reviewed_bindings", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    if args.output.resolve() in [args.archive.resolve(), args.reviewed_bindings.resolve()]:
        raise ValueError("preserve source inputs")
    result = build(args.archive, json.loads(args.reviewed_bindings.read_bytes()))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n")
    print("EXACT_BOOK_CONTRACTS", len(result["books"]))


if __name__ == "__main__":
    main()
