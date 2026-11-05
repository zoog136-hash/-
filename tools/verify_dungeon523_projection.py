#!/usr/bin/env python3
"""Independent comparison of a private projection with the actual cumulative523 ZIP."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import zipfile


def verify(source, pack):
    payload = (pack / "dungeons.json").read_bytes()
    manifest = json.loads((pack / "manifest.json").read_text())
    assert len(payload) == manifest["bytes"]
    assert hashlib.sha256(payload).hexdigest() == manifest["sha256"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == manifest["source_sha256"]
    data = json.loads(payload)
    checks = 0
    with zipfile.ZipFile(source) as archive:
        cache = {}

        def table(name):
            if name not in cache:
                cache[name] = json.loads(archive.read("content/" + name + ".json").decode("utf-8-sig"))["rows"]
            return cache[name]

        def index(name):
            return {row["ID"]: row for row in table(name)}

        def grouped(name, key):
            result = defaultdict(list)
            for row in table(name):
                result[row[key]].append(row)
            return result

        def check(condition, name):
            nonlocal checks
            assert condition, name
            checks += 1

        lands, territories, rewards, items = index("Land"), index("Territories"), index("Reward"), index("ItemClass")
        for kind, table_name, links_name in [("tower", "TrialTowerStage", "TrialTowerReward"), ("orim", "OrimsTrailStage", "OrimsTrailReward")]:
            stages = index(table_name)
            links = grouped(links_name,"StageID")
            check([x["stage"] for x in data[kind]] == table(table_name), kind + " all stages")
            for entry in data[kind]:
                stage = entry["stage"]
                check(stage == stages[stage["ID"]], "stage")
                place = entry["place"]
                check(place["territory"] == territories[stage["TeleportTerritoryID"]], "territory")
                check(place["land"] == lands[place["territory"]["LandID"]], "land")
                check([x["link"] for x in entry["normal_rewards"]] == links[stage["ID"]], "normal links")
                for reward in entry["normal_rewards"] + entry.get("immediate_rewards",[]) + entry.get("lucky_rewards",[]):
                    check(reward["row"] == rewards[reward["link"]["RewardID"]], "exact typed reward")
                    if reward["item"] is not None:
                        check(reward["item"]["row"] == items[reward["row"]["RewardClassID"]], "reward item")
        tower = data["tower"]
        immediate_links = grouped("TrialTowerImmediateReward","StageID")
        goals, goal_links = index("Goal"), grouped("TrialTowerGoal","StageID")
        purchases, payments, products = index("MarketPurchase_Korean"), index("MarketPayment_Korean"), index("MarketProduct")
        product_links = grouped("MarketPurchaseProduct","MarketPurchaseID")
        for entry in tower:
            stage_id = entry["stage"]["ID"]
            check([x["link"] for x in entry["immediate_rewards"]] == immediate_links[stage_id], "immediate links")
            check([x["link"] for x in entry["goals"]] == goal_links[stage_id], "goal links")
            for goal in entry["goals"]:
                check(goal["row"] == goals[goal["link"]["GoalID"]], "exact goal")
            purchase = purchases[entry["stage"]["ImmediateCompleteMarketPurchaseID"]]
            check(entry["immediate"]["purchase"] == purchase, "purchase")
            check(entry["immediate"]["payment"] == payments[purchase["MarketPaymentID"]], "payment")
            check(entry["immediate"]["products"] == [products[x["MarketProductID"]] for x in product_links[purchase["ID"]]], "product")
        wave_groups, section_groups = grouped("OrimsTrailSpawn","StageID"), grouped("OrimsTrailBossKillRewardSection","StageID")
        care_links, lucky_links = grouped("OrimsTrailCareReward","SectionID"), grouped("OrimsTrailLuckyReward","StageID")
        for entry in data["orim"]:
            stage_id = entry["stage"]["ID"]
            check(entry["spawns"] == wave_groups[stage_id], "all waves untouched")
            check([x["row"] for x in entry["sections"]] == section_groups[stage_id], "sections")
            check([x["link"] for x in entry["lucky_rewards"]] == lucky_links[stage_id], "weights")
            for section in entry["sections"]:
                check([x["link"] for x in section["care_rewards"]] == care_links[section["row"]["ID"]], "care links")
                for reward in section["care_rewards"]:
                    check(reward["row"] == rewards[reward["link"]["RewardID"]], "care typed reward")
        check([x["row"] for x in data["special"]] == table("SpecialDungeon"), "special definitions")
        teleports, destinations = index("LandTeleport"), grouped("LandTeleportTerritories","LandTeleportID")
        prerequisites, prerequisite_links = index("Prerequisite"), grouped("LandTeleportPrerequisite","LandTeleportID")
        for entry in data["special"]:
            teleport_id = entry["row"]["LandTeleportID"]
            check(entry["teleport"] == teleports[teleport_id], "special cost")
            check([x["link"] for x in entry["destinations"]] == destinations[teleport_id], "special destinations")
            check([x["link"] for x in entry["prerequisites"]] == prerequisite_links[teleport_id], "special prerequisites")
            for requirement in entry["prerequisites"]:
                check(requirement["row"] == prerequisites[requirement["link"]["PrerequisiteID"]], "special requirement value")
        check(data["land_times"] == table("LandTimeLimit"), "direct time map, never representative dungeon override")
        check([x["row"] for x in data["time_groups"]] == table("LandTimeLimitGroup"), "independent base and recharge limits")
        bonus_rows, bonus_types = index("Bonus"), index("BonusType")
        recharge_items = {x["ItemClassID"] for x in table("ItemBonus") if bonus_rows[x["BonusID"]]["BonusTypeID"] == 712}
        check({x["item"]["row"]["ID"] for x in data["rechargers"]} == recharge_items, "450 ordinary rechargers, excludes link test item")
        for entry in data["rechargers"]:
            check(entry["item"]["row"] == items[entry["item"]["row"]["ID"]], "recharge item")
            for effect in entry["effects"]:
                check(effect["row"] == bonus_rows[effect["link"]["BonusID"]], "recharge exact bonus")
                check(effect["type"] == bonus_types[effect["row"]["BonusTypeID"]], "recharge unit")
        for name, evidence in data["table_provenance"].items():
            raw = archive.read(evidence["path"])
            check(hashlib.sha256(raw).hexdigest() == evidence["sha256"], "source provenance " + name)
    print(json.dumps({"ok": True, "checks": checks, "payload_sha256": manifest["sha256"], "source_sha256": manifest["source_sha256"]}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source",type=Path)
    parser.add_argument("pack",type=Path)
    args = parser.parse_args()
    verify(args.source,args.pack)
