#!/usr/bin/env python3
"""Export source-verified blockers; this does not implement skill awakening growth."""
import argparse
import collections
import hashlib
import json
import pathlib
import zipfile
import zlib


SOURCE_ZIP_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
TARGET_DECKS = [1, 2, 98]
SKILL_EXP_ITEMS = list(range(193364, 193455, 10))
OPTION_EXP_ITEMS = list(range(193464, 193555, 10))
BOOK_ITEMS = [75184, 75194, 95624, 118992, 243043]
MATERIAL_STATUS = "source_material_contract_unresolved"
PROBABILITY_STATUS = "source_enhancement_probability_unresolved"
BLOCKED_REASON = "경험치 재료의 획득량·소모 규칙과 강화 성공·실패 확률 미확인"
TABLES = [
    "Bonus", "BonusType", "Unit", "ItemClass", "ItemBonus", "BuffCard", "BuffCardDeck",
    "BuffCardExperience", "BuffCardExperienceGrade", "BuffCardExperienceMapping",
    "BuffCardLevelUp", "BuffCardLevelUpMapping", "BuffCardLevelUpProbability",
    "BuffCardSkillAwakenExp", "BuffCardSkillAwakenValue",
    "BuffCardSkillAwakenSkillEnchantProb", "BuffCardSkillAwakenSkillEnchantProbGroup",
    "BuffCardSkillAwakenSkillInvokeProb", "BuffCardOptionAwakenValueType",
    "ItemCraftInput", "ItemCraftOutputView", "ItemCraftView", "ItemCraftRestriction",
    "MarketPurchaseProduct", "Reward", "LuckyBagEntityView", "GotChaEntityView", "NpcItemDropView",
]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha256(raw):
    return hashlib.sha256(raw).hexdigest()


def build(source_dir, source_zip):
    index_raw = (source_dir / "index.json").read_bytes()
    index_rows = json.loads(index_raw)
    index = {row["path"]: row for row in index_rows}
    require(len(index_rows) == len(index) == 1065, "Expected the complete 1065-table source inventory")
    require(sha256(source_zip.read_bytes()) == SOURCE_ZIP_SHA256, "Source content ZIP SHA256 mismatch")
    source_hashes, tables = {}, {}
    with zipfile.ZipFile(source_zip) as archive:
        require(archive.read("index.json") == index_raw, "Source ZIP and extracted index differ")
        for name in TABLES:
            relative = "content/" + name + ".json"
            raw = (source_dir / relative).read_bytes()
            spec = index[relative]
            require(raw == archive.read(relative), name + ": ZIP/extracted bytes differ")
            require(len(raw) == spec["bytes"] and sha256(raw) == spec["sha256"], name + ": index checksum mismatch")
            require(f"{zlib.crc32(raw) & 0xffffffff:08x}" == spec["crc32"], name + ": index CRC mismatch")
            records = json.loads(raw.decode("utf-8-sig"))["rows"]
            require(len(records) == spec["row_count"], name + ": row count mismatch")
            tables[name] = records
            source_hashes[name] = {"sha256": sha256(raw), "bytes": len(raw), "rows": len(records)}

    items = {row["ID"]: row for row in tables["ItemClass"]}
    cards = {row["ID"]: row for row in tables["BuffCard"]}
    bonuses = {row["ID"]: row for row in tables["Bonus"]}
    types = {row["ID"]: row for row in tables["BonusType"]}
    units = {row["ID"]: row for row in tables["Unit"]}
    bonus_links = collections.defaultdict(list)
    for row in tables["ItemBonus"]:
        bonus_links[row["ItemClassID"]].append(row)
    named_exp_items = sorted(row["ID"] for row in items.values() if "경험치 카드" in row["Name"])
    require(named_exp_items == SKILL_EXP_ITEMS + OPTION_EXP_ITEMS, "EXP card inventory changed; review the material boundary")
    rejected = []
    for item_id in named_exp_items:
        item = items[item_id]
        require(item["TestItem"] is True, "A source EXP card is no longer a test item")
        require(not bonus_links[item_id], "A source EXP card now has a bonus chain; review it")
        rejected.append({
            "item_class_id": item_id, "system": "skill" if item_id in SKILL_EXP_ITEMS else "option",
            "source_item": item, "item_bonus_rows": 0, "approved": False,
            "reasons": ["source_test_item", "item_bonus_chain_missing"],
        })
    references = {}
    item_fields = {"ItemClassID", "ClassID", "ItemClassId"}
    exp_item_set = set(named_exp_items)
    for name in ["ItemCraftInput", "ItemCraftOutputView", "MarketPurchaseProduct", "Reward",
                 "LuckyBagEntityView", "GotChaEntityView", "NpcItemDropView"]:
        hits = [row for row in tables[name] if any(row.get(field) in exp_item_set for field in item_fields)]
        require(not hits, name + ": EXP card references changed; review acquisition evidence")
        references[name] = {"matched_item_columns": sorted(item_fields & {key for row in tables[name] for key in row}), "rows": 0}
    dummy_cards = [row for row in cards.values() if row["BuffCardDeckID"] in [74, 84, 118]]
    require(not dummy_cards, "Dummy skill deck gained physical card definitions")

    excluded_mappings = {}
    for name, field in [("BuffCardExperienceMapping", "BuffCardExperienceID"), ("BuffCardLevelUpMapping", "BuffCardLevelUpID")]:
        records = tables[name]
        deck_counts = collections.Counter(cards[row["BuffCardID"]]["BuffCardDeckID"] for row in records)
        require(set(deck_counts) == {41}, name + ": mappings no longer belong exclusively to Spell deck41")
        excluded_mappings[name] = {
            "rows": len(records), "deck_counts": {str(key): value for key, value in sorted(deck_counts.items())},
            "awakening_deck_matches": 0, "mapping_sample": records[0],
            "card_sample": cards[records[0]["BuffCardID"]], "referenced_rule_field": field,
        }
    spell_deck = next(row for row in tables["BuffCardDeck"] if row["ID"] == 41)
    require(spell_deck["Name"] == "Spell" and spell_deck["CharacterBased"] is True, "Spell deck identity changed")
    missing_enum = "content/BuffCardSkillAwakenValueType.json" not in index
    require(missing_enum, "Typed skill awakening enum is now available; review its contract")
    require(not (source_dir / "content/BuffCardSkillAwakenValueType.json").exists(), "Unindexed skill awakening enum present")
    selection = tables["BuffCardSkillAwakenSkillEnchantProb"]
    invokes = tables["BuffCardSkillAwakenSkillInvokeProb"]
    require(len(invokes) == 300 and all(row["CastTotalProb"] == 10000 for row in invokes), "Cast-proc contract changed")
    valid_groups = {row["ID"] for row in tables["BuffCardSkillAwakenSkillEnchantProbGroup"]}
    placeholders = [row for row in selection if row["GroupID"] == 0 or row["SpellClassID"] == 0]
    require(len(placeholders) == 5 and 0 not in valid_groups, "Placeholder pool boundary changed")

    book_chains = []
    for item_id in BOOK_ITEMS:
        item_links = bonus_links[item_id]
        require(len(item_links) == 3, "Live awakening book bonus inventory changed")
        for link in item_links:
            bonus = bonuses[link["BonusID"]]
            typ = types[bonus["BonusTypeID"]]
            require(typ["Name"] in ["MagicDollAwakenSkillEnchantProbGroupID", "PolymorphAwakenSkillEnchantProbGroupID", "HolyStuffAwakenSkillEnchantProbGroupID"], "Live book bonus gained another meaning")
            require(units[typ["UnitID"]]["Name"] == "BuffCardSkillAwakenSkillEnchantProbGroupID", "Book bonus unit changed")
            book_chains.append({"item_class_id": item_id, "link": link, "bonus": bonus, "bonus_type": typ["Name"]})

    recipe_ids = [38334, 38344, 38354, 43282, 160543]
    recipes = []
    for recipe_id in recipe_ids:
        recipes.append({
            "item_craft_id": recipe_id,
            "view_rows": [row for row in tables["ItemCraftView"] if row["ItemCraftID"] == recipe_id],
            "input_rows": [row for row in tables["ItemCraftInput"] if row["ItemCraftID"] == recipe_id],
            "output_rows": [row for row in tables["ItemCraftOutputView"] if row["ItemCraftID"] == recipe_id],
            "restriction_rows": [row for row in tables["ItemCraftRestriction"] if row["ItemCraftID"] == recipe_id],
        })

    return {
        "schema": 1, "source_snapshot": "patch523", "diagnostic_only": True,
        "source_zip": source_zip.name, "source_zip_sha256": SOURCE_ZIP_SHA256,
        "source_zip_bytes": source_zip.stat().st_size, "source_index_sha256": sha256(index_raw),
        "source_table_sha256": source_hashes,
        "original_patch_archive": {"name": "20261028_523.zip", "sha256": None, "status": "whole_original_archive_checksum_not_available_in_supplied_content_bundle"},
        "target_deck_ids": TARGET_DECKS, "approved_material_item_class_ids": [],
        "material_status": MATERIAL_STATUS, "probability_status": PROBABILITY_STATUS,
        "blocked_reason": BLOCKED_REASON,
        "reasons": [
            {"code": "source_exp_cards_test_only", "detail": "스킬 경험치 카드 10종은 모두 원본 테스트 아이템이며 ItemBonus 연결이 없습니다."},
            {"code": "material_exp_conversion_unresolved", "detail": "실사용 재료 ID별 경험치 획득량·소모·레벨 적용 계약이 확인되지 않았습니다."},
            {"code": "spell_deck_growth_is_separate", "detail": "명시된 EXP·레벨업 표는 캐릭터 스킬 덱 41 전용입니다."},
            {"code": "skill_value_type_definition_missing", "detail": "스킬 각성 ValueType 정의표가 없어 수치에 EXP·비용·확률 의미를 부여할 수 없습니다."},
            {"code": "enhancement_probability_unresolved", "detail": "강화 성공·실패 확률과 분모가 확인되지 않았습니다. 발동 확률·스킬 선택 가중치를 전용하지 않습니다."},
            {"code": "failure_and_transaction_contract_unresolved", "detail": "실패 시 재료·EXP 처리와 서버 거래 계약이 확인되지 않았습니다."},
        ],
        "evidence_counts": {
            "source_inventory_tables": len(index), "verified_tables": len(TABLES),
            "skill_exp_card_items": len(SKILL_EXP_ITEMS), "option_exp_card_items": len(OPTION_EXP_ITEMS),
            "test_exp_card_items": len(rejected), "exp_card_item_bonus_rows": 0,
            "approved_material_items": 0, "dummy_skill_deck_card_rows": 0,
            "spell_deck_experience_mapping_rows": len(tables["BuffCardExperienceMapping"]),
            "spell_deck_level_up_mapping_rows": len(tables["BuffCardLevelUpMapping"]),
            "awakening_deck_growth_mapping_rows": 0, "skill_awaken_value_rows": len(tables["BuffCardSkillAwakenValue"]),
            "skill_awaken_value_type_tables": 0, "cast_proc_rows": len(invokes),
            "selection_rows": len(selection), "placeholder_selection_rows": len(placeholders),
            "live_book_pool_bonus_links": len(book_chains),
        },
        "rejected_exp_card_items": rejected, "exp_card_acquisition_reference_scan": references,
        "excluded_spell_deck_growth": {"deck": spell_deck, "mappings": excluded_mappings,
            "experience_rules": tables["BuffCardExperience"], "experience_grade_rules": tables["BuffCardExperienceGrade"],
            "level_up_rules": tables["BuffCardLevelUp"], "level_up_probability_rows": tables["BuffCardLevelUpProbability"]},
        "probability_boundaries": {
            "enhancement_probability": None, "enhancement_total_probability": None,
            "missing_enum_table": "BuffCardSkillAwakenValueType",
            "untyped_value_type_ids": sorted({row["BuffCardSkillAwakenValueTypeID"] for row in tables["BuffCardSkillAwakenValue"]}),
            "selection_table": "BuffCardSkillAwakenSkillEnchantProb", "selection_use": "candidate_selection_only",
            "cast_table": "BuffCardSkillAwakenSkillInvokeProb", "cast_use": "skill_activation_only", "cast_total_probability": 10000,
            "placeholder_rows": placeholders, "option_value_types_not_applicable": tables["BuffCardOptionAwakenValueType"],
        },
        "live_book_pool_bonus_chains": book_chains,
        "book_acquisition_raw_summary": {"scope": "book_acquisition_only_not_growth_material_conversion_or_book_consumption", "shared_slot_semantics": "not_inferred", "recipes": recipes},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=pathlib.Path, required=True, help="Extracted content bundle root containing index.json")
    parser.add_argument("--source-zip", type=pathlib.Path, required=True, help="Supplied extracted-content ZIP, not the original full patch archive")
    parser.add_argument("--output", type=pathlib.Path, default=pathlib.Path("data/cards/patch523_skill_growth_readiness.json"))
    parser.add_argument("--verify", action="store_true", help="Compare checked-in diagnostic JSON without writing")
    args = parser.parse_args()
    result = build(args.source_dir, args.source_zip)
    text = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.verify:
        require(args.output.read_text(encoding="utf-8") == text, "Diagnostic export differs from verified source")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    print("PATCH523_SKILL_GROWTH_READINESS " + json.dumps({"verified": True, "diagnostic_only": True, "can_feed": False, "can_enhance": False, "counts": result["evidence_counts"]}, sort_keys=True))


if __name__ == "__main__":
    main()
