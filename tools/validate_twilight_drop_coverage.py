#!/usr/bin/env python3
"""Ensure every TWILIGHT item has a real in-game acquisition path.

The supplementary data is TWILIGHT BALANCING, not NCSoft/Inven-confirmed
monster-item evidence. The audited L1J original drop mappings remain separate.
"""
import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
def load(relative):
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))

def is_boss(record):
    name = record["name"]
    return bool(record.get("is_boss", record.get("boss", False))) or (
        "보스" in str(record.get("desc", "")) or name.endswith("의 지배자") or
        name in {"흑장로", "이프리트", "드레이크", "거대 드레이크"}
    )

def main():
    db = load("data/game_db_v17.json")
    supplement = load("data/monsters/twilight_drop_coverage.json")
    verified = load("data/monsters/l1j_drop_overrides.json")["monsters"]
    monsters = {m["name"]: m for m in db["몬스터"]}
    items = {i["name"]: i for i in db["아이템"]}
    equipment = {k for k, i in items.items() if i.get("slot") not in ("consumable", "currency", "")}
    potions = {k for k, i in items.items() if i.get("slot") == "consumable" and int(i.get("heal", 0)) > 0}
    grades = {"일반": 0, "고급": 1, "희귀": 2, "영웅": 3, "전설": 4, "신화": 5, "유일": 6}
    errors, equip_access, potion_access = [], set(), set()
    seen = set()

    if supplement.get("schema_version") != 1 or "TWILIGHT" not in supplement.get("origin", ""):
        errors.append("invalid supplement schema/provenance")
    for monster in monsters.values():
        boss = is_boss(monster)
        for item_name in monster.get("drop", []):
            if item_name in equipment and (boss or grades[items[item_name]["grade"]] <= 3):
                equip_access.add(item_name)
            if item_name in potions and (boss or grades[items[item_name]["grade"]] <= 3):
                potion_access.add(item_name)
        # Default HP/strong HP potion fallback is reachable for every monster.
        default_potion = "강력 HP 물약" if boss else "HP 물약"
        if default_potion in potions:
            potion_access.add(default_potion)

    for monster_name, rows in verified.items():
        if monster_name not in monsters:
            errors.append("invalid audited monster " + monster_name)
        for row in rows:
            if row["item_name"] in equipment:
                equip_access.add(row["item_name"])

    for kind, expected in (("equipment", equipment), ("potions", potions)):
        for monster_name, rows in supplement.get(kind, {}).items():
            if monster_name not in monsters:
                errors.append(f"unknown {kind} monster: {monster_name}")
                continue
            boss = is_boss(monsters[monster_name])
            if not isinstance(rows, list):
                errors.append(f"invalid rows: {monster_name}")
                continue
            for row in rows:
                item_name = row.get("item_name")
                key = (kind, monster_name, item_name)
                if key in seen:
                    errors.append(f"duplicated row: {key}")
                seen.add(key)
                if item_name not in expected:
                    errors.append(f"wrong {kind} type or missing item: {key}")
                    continue
                grade = items[item_name].get("grade")
                if grade not in grades:
                    errors.append(f"unknown grade {grade}: {key}")
                    continue
                if not boss and grades[grade] > 3:
                    errors.append(f"field monster received above-Hero drop: {key}")
                if not isinstance(row.get("weight"), int) or not 1 <= row["weight"] <= 1000000:
                    errors.append(f"invalid positive weight: {key}")
                if kind == "equipment":
                    equip_access.add(item_name)
                else:
                    potion_access.add(item_name)

    missing_equipment = equipment - equip_access
    missing_potions = potions - potion_access
    if missing_equipment:
        errors.append("unreachable equipment: " + ", ".join(sorted(missing_equipment)))
    if missing_potions:
        errors.append("unreachable consumables: " + ", ".join(sorted(missing_potions)))
    if "아데나" not in items or items["아데나"].get("slot") != "currency":
        errors.append("adena currency missing from catalog")
    world = (ROOT / "scripts/world.gd").read_text(encoding="utf-8")
    if "gold += gained_adena" not in world:
        errors.append("adena combat-reward acquisition path missing")

    source = (ROOT / "scripts/loot_drop.gd").read_text(encoding="utf-8")
    for invariant in (
        "NORMAL_EQUIPMENT_RATES = {\"일반\":0.001, \"고급\":0.001, \"희귀\":0.001, \"영웅\":0.00015}",
        "BOSS_EQUIPMENT_RATES = {\"일반\":0.001, \"고급\":0.001, \"희귀\":0.001, \"영웅\":0.01, \"전설\":0.002, \"신화\":0.00025, \"유일\":0.00001}",
        "MAX_BOSS_EQUIPMENT_ROLLS: int = 3",
        "NORMAL_POTION_RATE: float = 0.45",
        "BOSS_POTION_RATE: float = 0.90",
        "twilight_coverage_equipment", "twilight_coverage_potions",
    ):
        if invariant not in source:
            errors.append("drop rate/integration regression: " + invariant[:64])
    report = {
        "ok": not errors,
        "total_monsters": len(monsters),
        "total_equipment": len(equipment),
        "reachable_equipment": len(equip_access),
        "total_potions": len(potions),
        "reachable_potions": len(potion_access),
        "adena_acquired_as_kill_currency": True,
        "supplement_equipment_rows": sum(map(len, supplement.get("equipment", {}).values())),
        "supplement_potion_rows": sum(map(len, supplement.get("potions", {}).values())),
        "supplement_provenance": "TWILIGHT balance, not verified official",
        "errors": errors,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if errors:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
