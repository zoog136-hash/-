#!/usr/bin/env python3
"""Preview scripts/maps/current523_source_spawns.gd on a private world-links pack.

Mirrors the GDScript selection/count rules so the regions a Land would receive
can be checked without Godot. Reads only the locally installed private pack and
no old base508 catalog or pack; writes nothing unless --out is given.

    python3 tools/map_restore/current523_spawn_preview.py \
      --pack /private/patch523-world-links --land 4
"""
import argparse
import collections
import hashlib
import json
import math
from pathlib import Path

PINNED = "2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
CELLS_PER_ACTOR, MIN_PER_RELATION, MAX_PER_RELATION, MAX_PER_VIEW = 800, 1, 6, 4
MAX_TERRITORY_CELLS = 200000
TAGS = ["[QUEST]", "[퀘스트]", "[메인]", "[깃발전]", "[스케줄]", "[이벤트]"]
NON_HUNT = {"Citizen", "Guard", "Slime", "SiegeNpc", "PartyNpc", "PartyImportantNpc", "LastavardGateKeeper", "Companion"}
CONDITION_TABLES = ["NpcSpawnPackSchedulePeriod", "DaynightSpawnPack", "WorldBossRaidView"]


def preview(pack: Path, land_id: int) -> dict:
    manifest = json.loads((pack / "manifest.json").read_text())
    shard = json.loads((pack / manifest["lands"][str(land_id)]["file"]).read_text())
    categories = {row["ID"]: row for row in json.loads((pack / "conditions.json").read_text())["tables"]["NpcCategory"]}
    territories = {row["ID"]: row for row in shard["territories"]}
    npcs = {row["ID"]: row for row in shard["npc_classes"]}
    views = collections.defaultdict(list)
    for view in shard["spawn_views"]:
        views[view["NpcSpawnPackID"]].append(view)
    conditioned = {row["NpcSpawnPackID"] for table in CONDITION_TABLES for row in shard["pack_context"][table]}

    def boss(npc_id, territory):
        names = (npcs[npc_id]["Name"], territory["Name"])
        return any(label in name for name in names for label in ("[필드보스", "[필드 보스"))

    def enemy(npc):
        category = categories.get(npc.get("Category"), {})
        return npc.get("TestNPC") is False and int(npc.get("Exp", 0)) > 0 and category.get("IsAttackable") is True and category.get("Name") not in NON_HUNT

    skipped, regions, seen, boss_ids = collections.Counter(), [], set(), set()
    for relation in shard["spawn_relations"]:
        territory = territories[relation["TerritoriesID"]]
        pack_id = relation["NpcSpawnPackID"]
        width = territory["EndX"] - territory["StartX"] + 1
        height = territory["EndY"] - territory["StartY"] + 1
        if territory.get("IsVillage") is True:
            skipped["village"] += 1; continue
        if any(tag in territory["Name"] for tag in TAGS):
            skipped["territory_tag"] += 1; continue
        if pack_id in conditioned:
            skipped["scheduled_pack"] += 1; continue
        if width < 1 or height < 1 or width * height > MAX_TERRITORY_CELLS:
            skipped["invalid_territory_area"] += 1; continue
        eligible = [v for v in views[pack_id] if v.get("IsSpawn") == 1 and v.get("ServerLimitSetID") == 0 and enemy(npcs[v["NpcClassID"]])]
        if not eligible:
            skipped["no_enemy_view"] += 1; continue
        budget = min(MAX_PER_RELATION, max(MIN_PER_RELATION, math.ceil(width * height / CELLS_PER_ACTOR)))
        counts = {v["ID"]: 1 for v in eligible if boss(v["NpcClassID"], territory)}
        normal = sorted((v for v in eligible if not boss(v["NpcClassID"], territory)), key=lambda v: v["ID"])
        for index in range(min(budget, len(normal) * MAX_PER_VIEW)):
            chosen = normal[(index + relation["ID"]) % len(normal)]
            counts[chosen["ID"]] = counts.get(chosen["ID"], 0) + 1
        for view in eligible:
            count = counts.get(view["ID"], 0)
            key = f"lineagem_base508:npc:{view['NpcClassID']}:spawn:{view['ID']}:territory:{relation['ID']}"
            if count < 1 or key in seen:
                continue
            seen.add(key)
            is_boss = boss(view["NpcClassID"], territory)
            if is_boss:
                boss_ids.add(view["NpcClassID"])
            regions.append({"key": key, "name": npcs[view["NpcClassID"]]["Name"], "boss": is_boss,
                            "max_count": 1 if is_boss else min(count, MAX_PER_VIEW),
                            "source_rect": [territory["StartX"], territory["StartY"], width, height]})
    return {"land_id": land_id, "asset_path": shard["land"]["AssetPath"], "name": shard["land"]["Name"],
            "regions": len(regions), "slots": sum(r["max_count"] for r in regions), "bosses": len(boss_ids),
            "kinds": len({r["key"].split(":")[2] for r in regions}), "skipped": dict(skipped), "rows": regions}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pack", required=True, type=Path)
    parser.add_argument("--land", type=int, action="append", help="Land.ID; repeat, or omit for every Land")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    digest = hashlib.sha256((args.pack / "manifest.json").read_bytes()).hexdigest()
    if digest != PINNED:
        raise SystemExit(f"manifest SHA256 {digest} is not the pinned cumulative523 pack")
    lands = args.land or sorted(int(k) for k in json.loads((args.pack / "manifest.json").read_text())["lands"])
    results = [preview(args.pack, land) for land in lands]
    for result in results:
        if result["regions"]:
            print(f"Land{result['land_id']:>6} {result['name'][:28]:<28} regions={result['regions']:>4} slots={result['slots']:>4} kinds={result['kinds']:>3} bosses={result['bosses']:>2}")
    populated = [r for r in results if r["regions"]]
    print(f"populated lands {len(populated)}/{len(results)}; regions {sum(r['regions'] for r in results)}; slots {sum(r['slots'] for r in results)}")
    if args.out:
        args.out.write_text(json.dumps(results, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
