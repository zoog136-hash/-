#!/usr/bin/env python3
"""Compile private cumulative523 Content into lossless, Land-scoped runtime links.

No source rows or generated private payloads belong in the public code PR.
This is a definition catalog, not an instance/spawn-density generator.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
PRIMARY = (
    "Land", "Territories", "Portal", "NpcSpawnPackTerritory",
    "NpcSpawnPackNpcClassView", "NpcClass", "NpcSpawnPackSchedulePeriod",
    "DaynightSpawnPack", "WorldBossRaidView", "NpcRepresentativeSpawnView",
)
CONTEXT = (
    "NpcCategory", "ServerLimit", "WeeklyOpenTimeGroup", "WeeklyOpenTimeGroupSet",
    "WeeklyOpenTime", "WeeklyOpenTimeEntity", "LandAttribute", "LandAttributeType",
    "LandTimeLimit", "LandTimeLimitGroup", "LandWeeklyOpenTime", "DateTimes",
    "DateTimes_Korean",
    "CompetitionDungeon", "CompetitionDungeonLand", "CompetitionDungeonView",
    "LandTeleport", "LandTeleportTerritories", "LandTeleportPrerequisite",
    "Prerequisite", "PrerequisiteType", "WorldBossRaidPrerequisite",
    "WorldBossRaidPrerequisiteView",
)


def grouped(rows, field):
    result = defaultdict(list)
    for row in rows:
        result[row[field]].append(row)
    return result


def unique(rows, table):
    result = {}
    for row in rows:
        if type(row.get("ID")) is not int or row["ID"] in result:
            raise ValueError(f"{table}: duplicate or invalid identity")
        result[row["ID"]] = row
    return result


def encode(value):
    return (json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n").encode()


def compile_links(tables, source_hashes, source_sha):
    """Preserve repeated relation/view/schedule rows in source order."""
    lands = unique(tables["Land"], "Land")
    territories = unique(tables["Territories"], "Territories")
    npcs = unique(tables["NpcClass"], "NpcClass")
    unique(tables["Portal"], "Portal")
    portals = grouped(tables["Portal"], "SourceLandID")
    land_territories = grouped(tables["Territories"], "LandID")
    views = grouped(tables["NpcSpawnPackNpcClassView"], "NpcSpawnPackID")
    relations = defaultdict(list)
    all_packs = set()
    for territory in territories.values():
        if territory["LandID"] not in lands:
            raise ValueError("Territories.LandID is unresolved")
    for row in tables["Portal"]:
        if row["SourceLandID"] not in lands or row["TargetTerritoryID"] not in territories:
            raise ValueError("Portal foreign key is unresolved")
    for row in tables["NpcSpawnPackNpcClassView"]:
        if row["NpcClassID"] not in npcs:
            raise ValueError("NpcClassID is unresolved")
    for row in tables["NpcSpawnPackTerritory"]:
        territory = territories.get(row["TerritoriesID"])
        if territory is None:
            raise ValueError("NpcSpawnPackTerritory.TerritoriesID is unresolved")
        relations[territory["LandID"]].append(row)
        all_packs.add(row["NpcSpawnPackID"])
    pack_contexts = {name: grouped(tables[name], "NpcSpawnPackID") for name in PRIMARY[6:]}
    files = {}
    records = {}
    for land_id, land in lands.items():
        packs = {row["NpcSpawnPackID"] for row in relations[land_id]}
        selected_views = [row for pack in sorted(packs) for row in views[pack]]
        selected_classes = {row["NpcClassID"] for row in selected_views}
        links = []
        for portal in portals[land_id]:
            target = territories[portal["TargetTerritoryID"]]
            links.append({"portal": portal, "target_territory": target,
                          "target_land": lands[target["LandID"]]})
        missing = sorted(pack for pack in packs if not views[pack])
        shard = {"schema": 1, "source_snapshot": "patch523", "land": land,
                 "territories": land_territories[land_id], "portals": links,
                 "spawn_relations": relations[land_id], "spawn_views": selected_views,
                 "npc_classes": [npcs[key] for key in sorted(selected_classes)],
                 "unresolved_class_view_packs": missing,
                 "pack_context": {name: [row for pack in sorted(packs) for row in groups[pack]]
                                  for name, groups in pack_contexts.items()}}
        relative = f"lands/{land_id}.json"
        blob = encode(shard)
        files[relative] = blob
        records[str(land_id)] = {"file": relative, "sha256": hashlib.sha256(blob).hexdigest(),
                                 "bytes": len(blob), "asset_path": land["AssetPath"],
                                 "portals": len(links), "spawn_relations": len(relations[land_id]),
                                 "unresolved_packs": len(missing)}
    context = encode({"schema": 1, "source_snapshot": "patch523",
                      "tables": {name: tables[name] for name in CONTEXT}})
    files["conditions.json"] = context
    missing = sorted(pack for pack in all_packs if not views[pack])
    manifest = {"schema": 1, "source_snapshot": "patch523", "source_zip_sha256": source_sha,
                "source_tables": {name: {"sha256": source_hashes[name], "rows": len(tables[name])}
                                  for name in PRIMARY + CONTEXT},
                "conditions": {"file": "conditions.json", "sha256": hashlib.sha256(context).hexdigest(),
                               "bytes": len(context)}, "lands": records,
                "coverage": {"lands": len(lands), "portals": len(tables["Portal"]),
                             "spawn_relations": len(tables["NpcSpawnPackTerritory"]),
                             "unresolved_class_view_packs": missing,
                             "is_spawn_rows": dict(Counter(str(row.get("IsSpawn")) for row in tables["NpcSpawnPackNpcClassView"]))},
                "runtime_scope": "DEFINITIONS_ONLY; INSTANCE_COUNT_RESPAWN_TRIGGER_AND_ARRIVAL_POLICY_UNKNOWN"}
    files["manifest.json"] = encode(manifest)
    return files, manifest


def build(source_zip: Path, output: Path):
    digest = hashlib.sha256(source_zip.read_bytes()).hexdigest()
    if digest != SOURCE_SHA256:
        raise ValueError("Expected the verified cumulative523 source ZIP SHA256")
    if output.exists():
        raise ValueError("Use a new output directory; preserve existing packs")
    with zipfile.ZipFile(source_zip) as archive:
        if archive.testzip() is not None:
            raise ValueError("Source ZIP CRC failure")
        tables, hashes = {}, {}
        for name in PRIMARY + CONTEXT:
            raw = archive.read(f"content/{name}.json")
            hashes[name] = hashlib.sha256(raw).hexdigest()
            data = json.loads(raw.decode("utf-8-sig"))
            rows = data.get("rows") if isinstance(data, dict) else None
            if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
                raise ValueError(f"Invalid original table {name}")
            tables[name] = rows
    files, manifest = compile_links(tables, hashes, digest)
    # Finish validation before creating output, never overwrite an older pack.
    output.mkdir(parents=True)
    for relative, raw in files.items():
        path = output / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)
    print(json.dumps({"directory": str(output.resolve()), "files": len(files),
                      "bytes": sum(map(len, files.values())),
                      "manifest_sha256": hashlib.sha256(files["manifest.json"]).hexdigest(),
                      "lands": manifest["coverage"]["lands"],
                      "portals": manifest["coverage"]["portals"],
                      "unresolved_packs": len(manifest["coverage"]["unresolved_class_view_packs"])}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-zip", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    build(args.source_zip, args.output)
