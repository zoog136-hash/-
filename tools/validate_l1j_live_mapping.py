#!/usr/bin/env python3
"""Validate explicit L1J <-> TWILIGHT IDs and the live equipment registry.

This is a guard, not a fuzzy translator. An optional original ZIP verifies
source row IDs/chances/quantities without committing copyrighted source data.
"""
import argparse
import json
import re
from pathlib import Path
from zipfile import ZipFile

from import_l1j_drops import convert

DEFAULT_SQL_MEMBER = "L1j-TW-main/db/InnoDB_TW/droplist.sql"
ORIGINAL_ROOT = "L1j-TW-main/db/InnoDB_TW/"
EQUIPMENT_NON_SLOTS = {"currency", "consumable", ""}
SQL_NAME_ROW = re.compile(r"INSERT INTO `(?P<table>npc|weapon|armor|etcitem)` VALUES \\('(?P<id>\\d+)', '(?P<name>[^']*)'")

def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))

def validate(mapping, overrides, twilight):
    errors = []
    monsters = {record["name"]: record for record in twilight.get("몬스터", [])}
    items = {record["name"]: record for record in twilight.get("아이템", [])}
    monster_ids = mapping.get("monster_id_to_twilight", {})
    item_ids = mapping.get("item_id_to_twilight", {})
    live = overrides.get("monsters", {})
    if mapping.get("schema_version") != 1 or overrides.get("schema_version") != 1:
        errors.append("unsupported mapping/registry schema version")
    for original_id, name in monster_ids.items():
        if not original_id.isdecimal() or name not in monsters:
            errors.append(f"unknown TWILIGHT monster: {original_id} -> {name}")
    for original_id, item_link in item_ids.items():
        if not original_id.isdecimal() or not isinstance(item_link, dict):
            errors.append(f"malformed item mapping {original_id}")
            continue
        name, kind = item_link.get("name", ""), item_link.get("kind", "")
        record = items.get(name)
        if record is None:
            errors.append(f"unknown TWILIGHT item: {original_id} -> {name}")
        elif kind == "equipment" and record.get("slot", "") in EQUIPMENT_NON_SLOTS:
            errors.append(f"equipment mapping points to non-equipment: {original_id}")
        elif kind == "currency" and record.get("slot") != "currency":
            errors.append(f"currency mapping points to non-currency: {original_id}")
        if kind not in {"equipment", "currency", "potion", "material", "consumable", "scroll"}:
            errors.append(f"unknown mapped item kind: {original_id} -> {kind}")
    seen = set()
    live_rows = 0
    for monster_name, rows in live.items():
        if monster_name not in monsters:
            errors.append(f"unknown live monster: {monster_name}")
        if not isinstance(rows, list):
            errors.append(f"non-array drop registry: {monster_name}")
            continue
        for row in rows:
            live_rows += 1
            if not isinstance(row, dict):
                errors.append(f"invalid drop row: {monster_name}")
                continue
            mob_id, item_id = str(row.get("l1j_monster_id")), str(row.get("l1j_item_id"))
            key = (mob_id, item_id)
            if key in seen:
                errors.append(f"duplicated source pair: {key}")
            seen.add(key)
            if monster_ids.get(mob_id) != monster_name:
                errors.append(f"source mob ID/name mismatch: {mob_id} -> {monster_name}")
            item_link = item_ids.get(item_id, {})
            if not isinstance(item_link, dict) or item_link.get("kind") != "equipment":
                errors.append(f"non-equipment item in equipment registry: {item_id}")
                continue
            if item_link.get("name") != row.get("item_name"):
                errors.append(f"source item ID/name mismatch: {item_id}")
            if int(row.get("weight", 0)) < 1 or int(row.get("weight", 0)) > 1000000:
                errors.append(f"invalid weight: {key}")
            if int(row.get("min", 0)) < 1 or int(row.get("max", 0)) < int(row.get("min", 0)):
                errors.append(f"invalid quantity range: {key}")
            if int(row.get("max", 0)) > 10000:
                errors.append(f"quantity above safety cap: {key}")
    return {
        "valid": not errors, "errors": errors,
        "mapped_monster_ids": len(monster_ids),
        "mapped_item_ids": len(item_ids),
        "live_equipment_rows": live_rows,
        "live_monster_names": len(live),
        "mapped_monsters_without_live_equipment": sorted(set(monster_ids.values()) - set(live)),
        "mapped_items_without_live_equipment": sorted(
            id for id in item_ids if id not in {str(r["l1j_item_id"]) for rows in live.values() for r in rows if isinstance(r, dict)}
        ),
        "source_zip_validated": False,
    }

def validate_original_zip(archive_path, sql_member, mapping, overrides):
    errors = []
    with ZipFile(archive_path) as archive:
        raw = archive.read(sql_member)
        source, summary = convert(raw, mapping, f"{Path(archive_path).name}:{sql_member}")
        if source["monsters"] != overrides.get("monsters", {}):
            errors.append("live drops differ from deterministic original SQL conversion")
        item_id_info = {}
        mob_ids = set()
        for table in ("weapon", "armor", "etcitem", "npc"):
            path = ORIGINAL_ROOT + table + ".sql"
            source_text = archive.read(path).decode("utf-8-sig")
            for match in SQL_NAME_ROW.finditer(source_text):
                if match.group("table") != table:
                    continue
                source_id = match.group("id")
                if table == "npc":
                    mob_ids.add(source_id)
                else:
                    item_id_info[source_id] = table
        for source_id in mapping["monster_id_to_twilight"]:
            if source_id not in mob_ids:
                errors.append(f"source monster ID missing in npc.sql: {source_id}")
        for source_id, row in mapping["item_id_to_twilight"].items():
            table = item_id_info.get(source_id)
            if table is None:
                errors.append(f"source item ID missing in original SQL: {source_id}")
            if row["kind"] == "equipment" and table not in {"weapon", "armor"}:
                errors.append(f"source equipment ID does not point to weapon/armor: {source_id}")
            if row["kind"] == "currency" and table != "etcitem":
                errors.append(f"source currency ID does not point to etcitem: {source_id}")
    return summary, errors

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--db", default="data/game_db_v17.json")
    p.add_argument("--id-map", default="data/monsters/l1j_id_map.json")
    p.add_argument("--overrides", default="data/monsters/l1j_drop_overrides.json")
    p.add_argument("--zip", help="Optional local original L1j-TW-main.zip; never commit source ZIP")
    p.add_argument("--sql-member", default=DEFAULT_SQL_MEMBER)
    p.add_argument("--report")
    args = p.parse_args()
    mapping, overrides, twilight = (read_json(x) for x in (args.id_map, args.overrides, args.db))
    report = validate(mapping, overrides, twilight)
    if args.zip:
        summary, errors = validate_original_zip(args.zip, args.sql_member, mapping, overrides)
        report["source_zip_validated"] = True
        report["source_rows"] = summary["source_rows"]
        report["source_monster_ids"] = summary["unique_source_monster_ids"]
        report["source_item_ids"] = summary["unique_source_item_ids"]
        report["source_sha256"] = summary["input_sha256"]
        report["unmapped_source_rows_by_reason"] = summary["rejected_rows_by_reason"]
        report["errors"].extend(errors)
        report["valid"] = not report["errors"]
    if args.report:
        Path(args.report).write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if not report["valid"]:
        raise SystemExit(1)

if __name__ == "__main__":
    main()
