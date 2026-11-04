#!/usr/bin/env python3
"""Project every QuestView row from the private patch523 content ZIP.

No source rows are embedded in this tool or published in Git. The output ZIP is
installed through the quest screen and contains data only, never engine code.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import zipfile
from datetime import datetime, timezone, timedelta


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode()


def build(source, destination):
    tables, evidence = {}, {}
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError("Source ZIP CRC failure")
        names = ["QuestView", "QuestType", "QuestLevel", "QuestPrerequisite", "Prerequisite", "PrerequisiteType", "QuestGoal", "Goal", "GoalType", "QuestReward", "Reward", "RewardType", "QuestRewardEnhancement", "RewardEnhancement", "ItemClass", "DescData_Korean", "DateTimes_Korean", "Class", "StartingQuest", "Currency", "CurrencyUnitClass"]
        for name in names:
            data = archive.read("content/" + name + ".json")
            tables[name] = json.loads(data.decode("utf-8-sig"))["rows"]
            evidence[name] = {"rows": len(tables[name]), "sha256": digest(data)}
    indexes = {name: {r["ID"]: r for r in rows if "ID" in r} for name, rows in tables.items()}
    if len(indexes["QuestView"]) != len(tables["QuestView"]):
        raise ValueError("Duplicate original quest ID")
    desc = {k: v["Description"] for k, v in indexes["DescData_Korean"].items()}
    links = {}
    for name in ["QuestPrerequisite", "QuestGoal", "QuestReward", "QuestRewardEnhancement"]:
        links[name] = collections.defaultdict(list)
        for row in tables[name]:
            links[name][row["QuestID"]].append(row)

    def text(identifier):
        return desc.get(identifier, "")

    def timestamp(identifier):
        row = indexes["DateTimes_Korean"].get(identifier)
        if not row:
            return None
        return int(datetime(row["Year"], row["Month"], row["Day"], row["Hour"], row["Minute"], tzinfo=timezone(timedelta(hours=9))).timestamp())

    quests = []
    exclusions = collections.Counter()
    for original in tables["QuestView"]:
        identifier = original["ID"]
        row = {"id": "m523:quest:" + str(identifier), "source_id": identifier,
               "title": text(original["TitleDescID"]) or "퀘스트 " + str(identifier),
               "description": text(original["ScenarioDescID"]), "definition": original,
               "category": "main" if original["TypeID"] == 1 else "achievement" if original["TypeID"] in [4, 46, 121] else "daily" if original["TypeID"] == 3 else "other",
               "type_name": indexes["QuestType"].get(original["TypeID"], {}).get("Name", "Unknown"),
               "starts_at": timestamp(original["StartTime"]), "ends_at": timestamp(original["EndTime"]),
               "prerequisites": [], "goals": [], "source_rewards": [], "enhancements": [], "blockers": []}
        for link, table, key, target in [("QuestPrerequisite", "Prerequisite", "PrerequisiteID", "prerequisites"), ("QuestGoal", "Goal", "GoalID", "goals"), ("QuestReward", "Reward", "RewardID", "source_rewards"), ("QuestRewardEnhancement", "RewardEnhancement", "RewardEnhancementID", "enhancements")]:
            for relation in links[link][identifier]:
                value = indexes[table].get(relation[key])
                if value is None:
                    row["blockers"].append("원본 참조 누락: " + table + ":" + str(relation[key]))
                else:
                    row[target].append(dict(value, relation=relation))
        for condition in row["prerequisites"]:
            condition["type_name"] = indexes["PrerequisiteType"].get(condition["PrerequisiteTypeID"], {}).get("Name", "Unknown")
        for goal in row["goals"]:
            goal["type_name"] = indexes["GoalType"].get(goal["GoalTypeID"], {}).get("Name", "Unknown")
            goal["description"] = text(goal["DescID"])
        for reward in row["source_rewards"]:
            reward["type_name"] = indexes["RewardType"].get(reward["RewardTypeID"], {}).get("Name", "Unknown")
            if reward["RewardTypeID"] == 2:
                item = indexes["ItemClass"].get(reward["RewardClassID"])
                if item is None:
                    row["blockers"].append("원본 아이템 참조 누락: " + str(reward["RewardClassID"]))
                else:
                    reward["source_item"] = item
        excluded = []
        if original["TypeID"] == 31:
            excluded.append("혈맹 퀘스트 제외")
        for goal in row["goals"]:
            if any(word in goal["type_name"].lower() for word in ["clan", "siege", "pet", "arena", "ziggurat"]):
                excluded.append("제외 시스템 목표: " + goal["type_name"])
        # A goal is bypassed by the user's immediate-completion rule. It must
        # never trigger a removed system or restore its UI/engine.
        row["excluded_reasons"] = sorted(set(excluded))
        for reason in row["excluded_reasons"]:
            exclusions[reason] += 1
        quests.append(row)
    document = {"schema_version": 2, "source_snapshot": "patch523", "source_sha256": digest(Path(source).read_bytes()),
                "provenance": "verified_original_quest_projection", "quests": quests,
                "classes": [{"id": r["ID"], "name": text(r["DescID"]), "source_name": r["Name"]} for r in tables["Class"]],
                "starting_quests": tables["StartingQuest"], "currency_links": tables["CurrencyUnitClass"], "currencies": tables["Currency"], "tables": evidence}
    payload = encode(document)
    header = {"schema": 1, "kind": "twilight-quests-current523", "source_sha256": document["source_sha256"], "payload_sha256": digest(payload), "quests": len(quests), "bytes": len(payload)}
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        archive.writestr("quest_pack.json", encode(header))
        archive.writestr("quests.json", payload)
    receipt = dict(header, pack_sha256=digest(destination.read_bytes()), pack_bytes=destination.stat().st_size, tables=evidence,
                   types=dict(collections.Counter(r["type_name"] for r in quests)), exclusions=dict(exclusions),
                   missing_references=sum(bool(r["blockers"]) for r in quests), source_drive_id="1EJGI2VV4u4P2yNlrMAlp0H2U28jjUH6K")
    destination.with_suffix(".receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_zip")
    parser.add_argument("output_zip")
    arguments = parser.parse_args()
    print(json.dumps(build(arguments.source_zip, arguments.output_zip), ensure_ascii=False, indent=2))
