#!/usr/bin/env python3
"""Prove private runtime links equal the original tables, including multiplicity."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import zipfile

from build_patch523_world_links import CONTEXT, PRIMARY, SOURCE_SHA256


def bag(rows):
    return Counter(json.dumps(row, sort_keys=True, ensure_ascii=False) for row in rows)


def verify(source: Path, pack: Path):
    assert hashlib.sha256(source.read_bytes()).hexdigest() == SOURCE_SHA256, "source identity"
    manifest = json.loads((pack / "manifest.json").read_text())
    assert manifest["source_zip_sha256"] == SOURCE_SHA256
    with zipfile.ZipFile(source) as archive:
        tables = {}
        for name in PRIMARY + CONTEXT:
            raw = archive.read(f"content/{name}.json")
            tables[name] = json.loads(raw.decode("utf-8-sig"))["rows"]
            assert manifest["source_tables"][name] == {"sha256": hashlib.sha256(raw).hexdigest(), "rows": len(tables[name])}, name
    territory_ids = {row["ID"]: row for row in tables["Territories"]}
    lands = {row["ID"]: row for row in tables["Land"]}
    views = defaultdict(list)
    for row in tables["NpcSpawnPackNpcClassView"]:
        views[row["NpcSpawnPackID"]].append(row)
    npcs = {row["ID"]: row for row in tables["NpcClass"]}
    aggregate = defaultdict(list)
    for key, spec in manifest["lands"].items():
        raw = (pack / spec["file"]).read_bytes()
        assert len(raw) == spec["bytes"] and hashlib.sha256(raw).hexdigest() == spec["sha256"]
        shard = json.loads(raw)
        lid = int(key)
        assert shard["land"] == lands[lid]
        assert all(row["LandID"] == lid for row in shard["territories"])
        assert all(territory_ids[row["TerritoriesID"]]["LandID"] == lid for row in shard["spawn_relations"])
        packs = {row["NpcSpawnPackID"] for row in shard["spawn_relations"]}
        assert bag(shard["spawn_views"]) == bag([row for pid in packs for row in views[pid]])
        assert shard["unresolved_class_view_packs"] == sorted(pid for pid in packs if not views[pid])
        assert bag(shard["npc_classes"]) == bag([npcs[nid] for nid in {row["NpcClassID"] for row in shard["spawn_views"]}])
        assert set(shard["pack_context"]) == set(PRIMARY[6:]), "missing pack-context table"
        for table, rows in shard["pack_context"].items():
            assert bag(rows) == bag([row for row in tables[table] if row["NpcSpawnPackID"] in packs]), table
        for link in shard["portals"]:
            assert link["portal"]["SourceLandID"] == lid
            assert link["target_territory"] == territory_ids[link["portal"]["TargetTerritoryID"]]
            assert link["target_land"] == lands[link["target_territory"]["LandID"]]
            aggregate["Portal"].append(link["portal"])
        aggregate["Land"].append(shard["land"])
        aggregate["Territories"].extend(shard["territories"])
        aggregate["NpcSpawnPackTerritory"].extend(shard["spawn_relations"])
    for table, rows in aggregate.items():
        assert bag(rows) == bag(tables[table]), table
    raw = (pack / "conditions.json").read_bytes()
    assert len(raw) == manifest["conditions"]["bytes"] and hashlib.sha256(raw).hexdigest() == manifest["conditions"]["sha256"]
    contexts = json.loads(raw)["tables"]
    for table in CONTEXT:
        assert contexts[table] == tables[table], table
    aden = json.loads((pack / "lands/4.json").read_text())
    assert aden["land"]["Name"] == "Aden" and aden["land"]["AssetPath"] == "Aden/"
    assert len(aden["portals"]) == 93 and len(aden["unresolved_class_view_packs"]) == 142
    assert sum(link["target_land"]["ID"] == 4 for link in aden["portals"]) == 56
    assert len(manifest["coverage"]["unresolved_class_view_packs"]) == 411
    result = {"lands": len(lands), "portals": len(aggregate["Portal"]),
              "spawn_relations": len(aggregate["NpcSpawnPackTerritory"]),
              "aden_portals": 93, "aden_internal_portals": 56,
              "aden_spawn_relations": len(aden["spawn_relations"]),
              "aden_views": len(aden["spawn_views"]), "aden_unresolved_packs": 142,
              "global_unresolved_packs": 411, "raw_context_tables": len(CONTEXT),
              "manifest_sha256": hashlib.sha256((pack / "manifest.json").read_bytes()).hexdigest()}
    print(json.dumps(result))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-zip", type=Path, required=True)
    parser.add_argument("--pack", type=Path, required=True)
    args = parser.parse_args()
    verify(args.source_zip, args.pack)
