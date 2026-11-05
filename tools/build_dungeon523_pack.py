#!/usr/bin/env python3
"""Build a private, deterministic dungeon projection from the exact cumulative523 ZIP.

No game art, source rows or generated packs belong in the public repository.
No server timers, payment algorithms, RNG or wave placement are synthesized.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import tempfile
import zipfile
import zlib

SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"


def require(condition, message="Source declaration mismatch"):
    if not condition:
        raise ValueError(message)


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def build(source):
    require(hashlib.sha256(source.read_bytes()).hexdigest() == SOURCE_SHA256, "Requires exact cumulative523 archive")
    tables, provenance = {}, {}
    with zipfile.ZipFile(source) as archive:
        require(archive.testzip() is None, "Source ZIP CRC failure")
        index = {r["path"]: r for r in json.loads(archive.read("index.json"))}

        def rows(name):
            if name not in tables:
                member = "content/" + name + ".json"
                raw = archive.read(member)
                evidence = index[member]
                require(len(raw) == evidence["bytes"])
                require(hashlib.sha256(raw).hexdigest() == evidence["sha256"])
                require(f"{zlib.crc32(raw):08x}" == evidence["crc32"])
                result = json.loads(raw.decode("utf-8-sig"))["rows"]
                require(len(result) == evidence["row_count"])
                tables[name] = result
                provenance[name] = {k: evidence[k] for k in ("path", "bytes", "sha256", "crc32", "row_count")}
            return tables[name]

        def keyed(name):
            result = {}
            for row in rows(name):
                # Some market tables contain duplicated sentinel ID0, never used here.
                require(row["ID"] == 0 or row["ID"] not in result, (name, row["ID"]))
                result[row["ID"]] = row
            return result

        def grouped(name, key):
            result = defaultdict(list)
            for row in rows(name):
                result[row[key]].append(row)
            return result

        desc = keyed("DescData_Korean")
        lands, territories = keyed("Land"), keyed("Territories")
        items, reward_types = keyed("ItemClass"), keyed("RewardType")
        reward_index = keyed("Reward")
        attrs = grouped("LandAttribute", "LandID")
        attr_types = keyed("LandAttributeType")
        groups = keyed("LandTimeLimitGroup")
        land_times = grouped("LandTimeLimit", "LandID")
        reset_types = keyed("ContentsResetScheduleType")
        dates = keyed("DateTimes_Korean")
        currencies = keyed("Currency")
        currency_sources = grouped("CurrencyUnitClass", "CurrencyID")
        units = keyed("Unit")
        bonuses, bonus_types = keyed("Bonus"), keyed("BonusType")
        item_bonuses = grouped("ItemBonus", "ItemClassID")

        def text(identifier):
            return desc.get(identifier, {}).get("Description", "")

        def item(identifier):
            row = items[identifier]
            deletion = []
            for link in item_bonuses[identifier]:
                bonus = bonuses[link["BonusID"]]
                if bonus["BonusTypeID"] == 492:
                    deletion.append({"link": link, "row": bonus,
                                     "date": dates.get(bonus["BonusApplicationTargetID"]) if bonus["BonusApplicationTypeID"] == 298 else None})
            return {"row": row, "name": text(row["DescID"]) or row["Name"], "deletion": deletion}

        def currency(identifier):
            row = currencies[identifier]
            return {"row": row, "name": text(row["DescID"]) or row["Name"], "sources": currency_sources[identifier]}

        def rewards(links):
            result = []
            for link in links:
                row = reward_index[link["RewardID"]]
                type_name = reward_types[row["RewardTypeID"]]["Name"]
                result.append({"link": link, "row": row, "type": type_name,
                               "item": item(row["RewardClassID"]) if type_name == "Item" else None})
            return result

        def time_group(identifier):
            row = groups[identifier]
            return {"row": row, "name": text(row["DescID"]),
                    "reset": reset_types.get(row["ContentsResetScheduleTypeID"]),
                    "start": dates.get(row["StartDateTimeID"]), "end": dates.get(row["EndDateTimeID"])}

        def place(identifier):
            territory = territories[identifier]
            land = lands[territory["LandID"]]
            return {"territory": territory, "land": land, "name": text(territory["DescID"]) or territory["Name"],
                    "attributes": [{"row": a, "type": attr_types[a["LandAttributeTypeID"]]["Name"]} for a in attrs[land["ID"]]],
                    "time_groups": [time_group(x["LandTimeLimitGroupID"]) for x in land_times[land["ID"]]]}

        goals, goal_types = keyed("Goal"), keyed("GoalType")
        tower_goals = grouped("TrialTowerGoal", "StageID")
        tower_rewards = grouped("TrialTowerReward", "StageID")
        tower_immediate = grouped("TrialTowerImmediateReward", "StageID")
        purchases, payments = keyed("MarketPurchase_Korean"), keyed("MarketPayment_Korean")
        purchase_products = grouped("MarketPurchaseProduct", "MarketPurchaseID")
        products = keyed("MarketProduct")
        stage_types = keyed("TrialTowerStageType")
        tower = []
        for stage in rows("TrialTowerStage"):
            purchase = purchases[stage["ImmediateCompleteMarketPurchaseID"]]
            payment = payments[purchase["MarketPaymentID"]]
            targets = [products[x["MarketProductID"]] for x in purchase_products[purchase["ID"]]]
            require(len(targets) == 1 and units[targets[0]["UnitID"]]["Name"] == "TrialTowerStageID")
            require(targets[0]["ClassID"] == stage["ID"] and targets[0]["Amount"] == 1)
            require(units[payment["UnitID"]]["Name"] == "CurrencyID" and payment["ClassID"] == 764)
            linked_goals = []
            for link in tower_goals[stage["ID"]]:
                goal = goals[link["GoalID"]]
                kind = goal_types[goal["GoalTypeID"]]["Name"]
                linked_goals.append({"link": link, "row": goal, "type": kind,
                                     "item": item(goal["GoalClassID"]) if kind == "ItemCollect" else None})
            tower.append({"stage": stage, "type": stage_types[stage["StageTypeID"]]["Name"],
                          "place": place(stage["TeleportTerritoryID"]), "goals": linked_goals,
                          "normal_rewards": rewards(tower_rewards[stage["ID"]]),
                          "immediate_rewards": rewards(tower_immediate[stage["ID"]]),
                          "immediate": {"purchase": purchase, "payment": payment, "products": targets,
                                        "currency": currency(payment["ClassID"])}})
        orim_rewards, orim_lucky = grouped("OrimsTrailReward", "StageID"), grouped("OrimsTrailLuckyReward", "StageID")
        sections, care = grouped("OrimsTrailBossKillRewardSection", "StageID"), grouped("OrimsTrailCareReward", "SectionID")
        spawns, messages = grouped("OrimsTrailSpawn", "StageID"), grouped("OrimsTrailStageMessage", "StageID")
        orim = [{"stage": stage, "place": place(stage["TeleportTerritoryID"]),
                 "normal_rewards": rewards(orim_rewards[stage["ID"]]), "lucky_rewards": rewards(orim_lucky[stage["ID"]]),
                 "sections": [{"row": section, "care_rewards": rewards(care[section["ID"]])} for section in sections[stage["ID"]]],
                 "spawns": spawns[stage["ID"]], "messages": messages[stage["ID"]]}
                for stage in rows("OrimsTrailStage")]
        teleports = keyed("LandTeleport")
        destinations = grouped("LandTeleportTerritories", "LandTeleportID")
        prereq_links, prereqs, prereq_types = grouped("LandTeleportPrerequisite", "LandTeleportID"), keyed("Prerequisite"), keyed("PrerequisiteType")
        special_types = keyed("SpecialDungeonType")
        special = []
        for row in rows("SpecialDungeon"):
            teleport = teleports[row["LandTeleportID"]]
            conditions = []
            for link in prereq_links[teleport["ID"]]:
                condition = prereqs[link["PrerequisiteID"]]
                conditions.append({"link": link, "row": condition, "type": prereq_types[condition["PrerequisiteTypeID"]]["Name"]})
            special.append({"row": row, "type": special_types[row["SpecialDungeonTypeID"]],
                            "teleport": teleport, "currency": currency(teleport["CurrencyID"]),
                            "destinations": [{"link": x, "place": place(x["TerritoryID"])} for x in destinations[teleport["ID"]]],
                            "prerequisites": conditions})

        use_desc = keyed("UseDesc")
        rechargers = []
        for identifier, links in item_bonuses.items():
            group_links = [x for x in links if bonuses[x["BonusID"]]["BonusTypeID"] == 712]
            if not group_links:
                continue
            require(len(group_links) == 1)
            target = bonuses[group_links[0]["BonusID"]]["Value"]
            require(target in groups)
            selected = [{"link": x, "row": bonuses[x["BonusID"]], "type": bonus_types[bonuses[x["BonusID"]]["BonusTypeID"]]} for x in links]
            recharge = [x for x in selected if x["row"]["BonusTypeID"] == 722]
            require(len(recharge) == 1 and recharge[0]["row"]["Value"] == 3600)
            require(units[recharge[0]["type"]["UnitID"]]["Name"] == "Seconds")
            require(not any(x["IsPossession"] for x in links))
            info = item(identifier)
            rechargers.append({"item": info, "group_id": target, "effects": selected,
                               "use_text": text(use_desc.get(info["row"]["UseDescID"], {}).get("DescID", 0))})
        require(len(tower) == 200 and len(orim) == 20 and len(special) == 22 and len(rechargers) == 450)
        controls = [x for x in rows("ContentsControl") if x["Name"] in ("TrialTower", "TrialTowerHardMode", "OrimsTrail") or x["ID"] in {r["type"]["ContentsControlID"] for r in special}]
        categories = [x for x in rows("DungeonCategory") if x["Name"] in ("TrialTower", "OrimsTrail", "Special")]
        seasons = [x for x in rows("SeasonDungeon") if x["Name"] in ("시련의 탑", "오림의 흔적")]
        server_ids = {x["ServerLimitSetID"] for x in controls}
        server_ids.update(x["ServerLimitSetId"] for x in categories)
        server_ids.update(x["ServerLimitsetID"] for x in seasons)
        server_ids.update(x["row"]["ServerLimitSetID"] for x in special)
        servers = [x for x in rows("ServerLimit") if x["ServerLimitSetID"] in server_ids]
        # Retain declarations for inspection; do not invent an execution policy.
        declarations = {name: rows(name) for name in ["TrialTowerConstant", "TrialTowerTryCountPurchase", "TrialTowerBuff", "TrialTowerBanCondition", "TrialTowerBanConditionType", "OrimsTrailConstant", "OrimsTrailBuff", "OrimsTrailRerollCurrencyCost", "OrimsTrailSeason"]}
        result = {"schema": 1, "source_sha256": SOURCE_SHA256, "version": 523,
                  "tower": tower, "orim": orim, "special": special,
                  "time_groups": [time_group(x) for x in groups], "land_times": rows("LandTimeLimit"),
                  "rechargers": rechargers, "controls": controls, "categories": categories,
                  "seasons": seasons, "servers": servers, "declarations": declarations,
                  "table_provenance": provenance}
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path, help="New private directory outside repository")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    destination = args.destination.resolve()
    require(not destination.is_relative_to(repo), "Private packs must remain outside repository")
    require(not destination.exists(), "Preserve existing packs; choose a new directory")
    payload = encoded(build(args.source))
    manifest = {"schema": 1, "version": 523, "source_sha256": SOURCE_SHA256,
                "payload": "dungeons.json", "bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:
        staging = Path(temporary) / "pack"
        staging.mkdir()
        (staging / "dungeons.json").write_bytes(payload)
        (staging / "manifest.json").write_bytes(encoded(manifest))
        staging.rename(destination)
    print(json.dumps({"directory": str(destination), **manifest}))


if __name__ == "__main__":
    main()
