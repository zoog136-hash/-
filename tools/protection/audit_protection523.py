#!/usr/bin/env python3
"""Local-only exhaustive typed reference audit; never copy original rows to Git."""
import argparse, collections, hashlib, json, pathlib, zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source-zip", required=True, type=pathlib.Path)
parser.add_argument("--output", required=True, type=pathlib.Path)
args = parser.parse_args()
ROOT = args.output.resolve()
ROOT.mkdir(parents=True, exist_ok=True)
ZIP = args.source_zip.resolve()
TARGETS = {200723, 245718, 297828, 327823, 328254, 346911, 371108}
DEPENDENCIES = {123373, 200698, 3631}
assert ZIP.stat().st_size == 25031173
assert hashlib.sha256(ZIP.read_bytes()).hexdigest() == "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
tables, audit, refs = {}, {}, collections.defaultdict(list)
with zipfile.ZipFile(ZIP) as z:
    assert z.testzip() is None
    for name in z.namelist():
        if not name.startswith("content/") or not name.endswith(".json"):
            continue
        blob = z.read(name)
        obj = json.loads(blob.decode("utf-8-sig"))
        if not isinstance(obj, dict) or not isinstance(obj.get("rows"), list):
            raise ValueError(name)
        table = pathlib.PurePosixPath(name).stem
        rows = obj["rows"]
        audit[table] = {"rows": len(rows), "sha256": hashlib.sha256(blob).hexdigest(), "bytes": len(blob)}
        # Keep only tables needed for the follow-up graph, not all DBs in RAM.
        if table in {"ItemClass", "ItemBonus", "Bonus", "BuffClass", "BuffBonus", "Appellation",
                     "ItemCraftView", "ItemCraftOutputView", "ItemCraftInput", "ItemCraftRestriction",
                     "Reward", "QuestReward", "QuestClass", "QuestGoal", "Quest", "LuckyBagEntity",
                     "LuckyBagClass", "BonusType", "ItemCategory", "NpcItemDropView",
                     "QuestView", "QuestPrerequisite", "Prerequisite", "PrerequisiteType",
                     "Goal", "GoalType", "DateTimes_Korean", "DescData_Korean"}:
            tables[table] = rows
        for row in rows:
            hits = []
            for key, value in row.items():
                if isinstance(value, bool) or not isinstance(value, int):
                    continue
                typed_item = key in {"ItemClassID", "MaterialClassID", "OutputItemClassID", "ResultItemClassID",
                                     "ConsumeItemClassID", "RequiredItemClassID"}
                typed_item |= table == "ItemClass" and key == "ID"
                typed_item |= table == "Reward" and key == "RewardClassID" and row.get("RewardTypeID") == 2
                typed_item |= table == "MarketProduct" and key == "ClassID" and row.get("UnitID") == 4
                if typed_item and value in TARGETS | DEPENDENCIES:
                    hits.append({"field": key, "item_id": value, "role": "target" if value in TARGETS else "dependency"})
            if hits:
                refs[table].append({"row": row, "typed_item_refs": hits})

bonus = {r["ID"]: r for r in tables["Bonus"]}
types = {r["ID"]: r for r in tables["BonusType"]}
links = [r for r in tables["ItemBonus"] if r["ItemClassID"] in TARGETS]
item_bonuses = [{"link": r, "bonus": bonus[r["BonusID"]], "type": types[bonus[r["BonusID"]]["BonusTypeID"]]} for r in links]
buff_ids = {int(x["bonus"]["Value"]) for x in item_bonuses if x["type"]["Name"] == "BuffClassID"}
title_ids = {int(x["bonus"]["Value"]) for x in item_bonuses if x["type"]["Name"] == "ItemCraftPermanentAppellationID"}
titles = [r for r in tables["Appellation"] if r["ID"] in title_ids]
buff_ids |= {r["RewardID"] for r in titles}
buff_links = [r for r in tables["BuffBonus"] if r["BuffClassID"] in buff_ids]
crafts = [r for r in tables["ItemCraftView"] if r["ItemClassID"] in TARGETS]
craft_ids = {r["ItemCraftID"] for r in crafts}
reward_ids = {r["ID"] for r in tables["Reward"] if r["RewardTypeID"] == 2 and r["RewardClassID"] in TARGETS | DEPENDENCIES}
quest_reward = [r for r in tables.get("QuestReward", []) if r["RewardID"] in reward_ids]
quest_ids = {r["QuestID"] for r in quest_reward}
material_reward_ids = {r["ID"] for r in tables["Reward"] if r["RewardTypeID"] == 2 and r["RewardClassID"] in {123373,200698}}
material_quests = {r["QuestID"] for r in tables.get("QuestReward", []) if r["RewardID"] in material_reward_ids}
material_views = [r for r in tables.get("QuestView", []) if r["ID"] in material_quests]
prerequisites = [r for r in tables.get("QuestPrerequisite", []) if r["QuestID"] in material_quests]
goals = [r for r in tables.get("QuestGoal", []) if r["QuestID"] in material_quests]
prerequisite_ids = {r["PrerequisiteID"] for r in prerequisites}
goal_ids = {r["GoalID"] for r in goals}
date_ids = {r[key] for r in material_views for key in ["StartTime","EndTime"]}
descriptions = {r["ID"]:r["Description"] for r in tables["DescData_Korean"]}
result = {
    "source_zip_sha256": hashlib.sha256(ZIP.read_bytes()).hexdigest(),
    "source_zip_bytes": ZIP.stat().st_size,
    "source_zip_crc": "pass",
    "all_content_tables": audit,
    "target_item_ids": sorted(TARGETS),
    "dependency_item_ids": sorted(DEPENDENCIES),
    "typed_item_reference_rows": dict(refs),
    "all_item_bonus_layers": item_bonuses,
    "all_related_buff_classes": [r for r in tables["BuffClass"] if r["ID"] in buff_ids],
    "all_related_buff_bonuses": [{"link":r,"bonus":bonus[r["BonusID"]],"type":types[bonus[r["BonusID"]]["BonusTypeID"]]} for r in buff_links],
    "all_appellations": titles,
    "all_group604_buff_classes": [r for r in tables["BuffClass"] if r["BuffGroupID"] == 604],
    "appellation_reward_namespace": "BuffClass; do not join general Reward",
    "craft_views": crafts,
    "craft_inputs": [r for r in tables["ItemCraftInput"] if r["ItemCraftID"] in craft_ids],
    "craft_outputs": [r for r in tables["ItemCraftOutputView"] if r["ItemCraftID"] in craft_ids],
    "craft_restrictions": [r for r in tables["ItemCraftRestriction"] if r["ItemCraftID"] in craft_ids],
    "quest_reward_links": quest_reward,
    "quest_definitions": {n:[r for r in tables.get(n,[]) if r.get("ID",r.get("QuestID")) in quest_ids] for n in ["Quest","QuestClass","QuestGoal"]},
    "material_supply": {
        "quest_views":material_views,
        "display_titles":{str(r["ID"]):descriptions.get(r["TitleDescID"],"") for r in material_views},
        "quest_prerequisite_links":prerequisites,
        "prerequisites":[r for r in tables["Prerequisite"] if r["ID"] in prerequisite_ids],
        "quest_goal_links":goals,
        "goals":[r for r in tables["Goal"] if r["ID"] in goal_ids],
        "dates":[r for r in tables["DateTimes_Korean"] if r["ID"] in date_ids],
        "normal3_recipe_view":[r for r in tables["ItemCraftView"] if r["ItemClassID"] == 123373],
        "normal3_recipe_inputs":[r for r in tables["ItemCraftInput"] if r["ItemCraftID"] == 47273],
        "test_bag":[r for r in tables["LuckyBagClass"] if r["ID"] == 80548],
        "execution":"General source quests remain excluded from this task; no partial reward is granted as a substitute for completing their full reward contract.",
    },
    "execution_boundary": {
        "normal_item_ids":[200723,245718,297828,328254,346911,371108],
        "disabled_item_id":327823, "disabled_recipe_id":222693,
        "source_numeric_rules":"preserved",
        "twilight_policies":["PvP projection to current solo combat","highest owned tier","Group604 replacement order","absolute local-clock persistence"],
        "general_quests":"audited read-only, existing instant-completion policy preserved",
        "native_art":"not delivered by these code changes",
    },
}
(ROOT / "source-reference-audit-LOCAL_ONLY.json").write_text(json.dumps(result, ensure_ascii=False, indent=2))
summary = {
    "all_tables":len(audit), "all_rows":sum(v["rows"] for v in audit.values()),
    "referencing_tables":{k:len(v) for k,v in refs.items()},
    "item_bonus_rows":len(item_bonuses), "item_bonus_types":dict(collections.Counter(x["type"]["Name"] for x in item_bonuses)),
    "buff_class_rows":len(result["all_related_buff_classes"]), "buff_bonus_rows":len(buff_links),
    "appellations":len(titles), "craft_views":len(crafts), "craft_inputs":len(result["craft_inputs"]),
    "craft_outputs":len(result["craft_outputs"]), "craft_restrictions":len(result["craft_restrictions"]),
    "quest_reward_links":len(quest_reward),
    "local_audit_path":str(ROOT / "source-reference-audit-LOCAL_ONLY.json"),
}
(ROOT / "source-audit-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2))
print(json.dumps(summary, ensure_ascii=False, indent=2))
