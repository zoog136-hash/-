#!/usr/bin/env python3
"""Validate the pinned map84 handoff and build a NON-PLAYABLE review pack.

No source executable, overview image, spawn importer, save writer, or live map
catalog is used. Raw collision bytes retain their provenance, not a guessed mask.
"""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import tempfile
import zipfile

LINKAGE_SHA = "33e0b552f1cbd75aef1d299886603107185df1e89cd76432268f94c5bd3b5c77"
PROTECTED = ["albino_01", "albino_02"] + [f"escaros_{i:02}" for i in range(1, 6)] + [f"faith_{i:02}" for i in range(1, 5)]
REMOVED = {639, 1930, 1931, 2042, 2043, 2044}
SELECTED = {0, 4, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 53, 54, 55, 56, 77, 78, 79, 80, 81, 82, 106, 244, 303, 480, 495, 601, 783}
REPLACEMENTS = {4: "aden_world", 200: "domination_summit", **{i: f"oman_{i-100:02}" for i in range(101, 111)}}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def digest(path):
    with Path(path).open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode()


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(encoded(value))
    return digest(path)


def safe_path(value):
    require(isinstance(value, str) and value and "\\" not in value, "invalid relative path")
    require(not PurePosixPath(value).is_absolute() and all(p not in ("", ".", "..") for p in value.split("/")), "unsafe relative path")
    return value


def target_for(row):
    source = row["source_map_id"]
    folder = row["source_map_folder"]
    require(source not in REMOVED, "retired source map")
    expected = ("source_variant_" + folder.replace("/", "_")) if source is None else REPLACEMENTS.get(source, f"source_{source}")
    require(row["target_map_id"] == expected and expected not in PROTECTED, "unapproved target mapping")
    require(expected not in ("albino_03", "albino_04", "yahee_temple", "balrog_temple"), "existing identity must be preserved")
    return expected


def validate_contract(handoff, selection, safety, assets):
    require(handoff["schema"] == "twilight-map-replacement-input-contract-v1", "handoff schema")
    require(set(handoff["protected_existing_game_ids_or_families"]) == set(PROTECTED), "protected IDs changed")
    require(set(handoff["removed_maps_never_restore"]) == REMOVED, "retirement set changed")
    rows = handoff["maps"]
    require(len(rows) == 84 and len({r["source_map_folder"] for r in rows}) == 84, "84 unique source folders required")
    require(len({target_for(r) for r in rows}) == 84, "duplicate target ID")
    require(sum(r["source_map_id"] is None for r in rows) == 5, "variant count")
    require({r["source_map_id"] for r in rows if r["selected_collision_version"] == "360"} == SELECTED, "collision selection changed")
    for r in rows:
        require(r["selected_collision_version"] == ("360" if r["source_map_id"] in SELECTED else None), "unauthorized collision fallback")
    require(set(selection["selected_map_ids"]) == SELECTED and len(selection["selected_grids"]) == 31, "selected grid count")
    require(selection["fallback_allowed"] is False and selection["runtime_import_enabled"] is False, "unsafe selection flags")
    require(safety["semantic_collision_validation_incomplete"] is True and safety["runtime_playability_claim_allowed"] is False, "unexpected playability claim")
    require(safety["all_nonretained_destination_routes_disabled"] is True and safety["all_variant_map_id_inheritance_forbidden"] is True, "unsafe route or variant policy")
    gates = safety["must_keep_disabled"]
    require(len(gates) == 10 and all(r["enabled"] is False for r in gates), "safety gates changed")
    require([(r["map_id"], r["id"]) for r in gates if r["kind"] == "door"] == [(0, 107)], "door 107 is one ID, not 107 doors")
    require(len({r["route_id"] for r in gates if r["kind"] == "route"}) == 9, "nine disabled routes required")
    require(len(assets) == 1920 and len({r["raw_source_sha256"] for r in assets}) == 1920, "asset identity count")
    require(sum(r["bytes"] for r in assets) == 1882144870, "asset byte count")


def placement(chunk, asset, origin):
    x, y, x1, y1 = chunk["world_bounds"]
    require(x1-x == 63 and y1-y == 63, "not a 64-cell chunk")
    dx, dy = x-origin[0], y-origin[1]
    ox, oy = asset["origin_pixels"]
    # The raw image has the local center offset (24,768) already in its pixels.
    # Only chunk translation and the measured expanded-image origin go here.
    return [24*(dx+dy)+ox, 12*(dy-dx)+oy]


def build(linkage, assets_root, output, receipt=None, link_assets=False):
    require(digest(linkage) == LINKAGE_SHA, "linkage v3 SHA mismatch")
    require(not output.exists(), "output already exists; use a new versioned destination")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(linkage) as z:
        require(z.testzip() is None, "linkage CRC failure")
        names = z.namelist()
        require(len(names) == len(set(names)), "duplicate ZIP members")
        for name in names:
            safe_path(name.rstrip("/"))
        def read(name):
            return json.loads(z.read("map_source3_links/" + safe_path(name)))
        h, s, safety, assets = (read(n) for n in ("game_handoff.json", "collision_selection.json", "runtime_safety.json", "game_asset_manifest.json"))
        validate_contract(h, s, safety, assets)
        by_hash = {a["raw_source_sha256"]: a for a in assets}
        grid_by_id = {g["map_id"]: g for g in s["selected_grids"]}
        require(set(grid_by_id) == SELECTED, "grid selection identity mismatch")
        routes = read("routes.json") + read("hardcoded_routes.json")
        doors = read("doors.json")
        require(all(r.get("enabled") is False for r in routes + doors), "upstream action unexpectedly enabled")
        route_ids = {r["route_id"] for r in routes}
        for gate in safety["must_keep_disabled"]:
            if gate["kind"] == "route":
                require(gate["route_id"] in route_ids, "disabled route missing")
        with tempfile.TemporaryDirectory(prefix=".map84-build-", dir=output.parent) as tmp:
            stage = Path(tmp) / "pack"
            stage.mkdir()
            from PIL import Image
            for asset in assets:
                rel = safe_path(asset["asset_relative_path"])
                require(rel == f"chunks/{asset['raw_source_sha256']}.webp", "unexpected chunk filename")
                source = assets_root / rel
                require(source.is_file() and source.stat().st_size == asset["bytes"] and digest(source) == asset["webp_sha256"], f"asset hash mismatch: {rel}")
                with Image.open(source) as im:
                    require(im.format == "WEBP" and list(im.size) == asset["dimensions"], f"asset dimensions: {rel}")
                    im.verify()
                dest = stage / rel
                dest.parent.mkdir(exist_ok=True)
                if link_assets:
                    os.link(source, dest)
                else:
                    shutil.copyfile(source, dest)
            index = {"schema": 1, "kind": "source-map-review-only", "linkage_sha256": LINKAGE_SHA, "playable": False,
                     "protected_ids": PROTECTED, "maps": {}, "asset_count": len(assets), "asset_bytes": sum(a["bytes"] for a in assets)}
            for row in sorted(h["maps"], key=lambda r: r["target_map_id"]):
                mid = target_for(row)
                source_id = row["source_map_id"]
                chunks = row["chunks"]
                require(chunks, f"empty map: {mid}")
                origin = [min(c["world_bounds"][i] for c in chunks) for i in (0, 1)]
                record = {k: row[k] for k in ("source_map_folder", "source_map_id", "target_map_id", "korean_name", "mapping_basis", "integration_status", "selected_collision_version")}
                record.update(playable=False, semantic_collision_verified=False, origin_source=origin, chunks=[], collision=None,
                              migration_required=source_id in REPLACEMENTS, monster_spawns=[], routes=[], doors=[])
                for chunk in chunks:
                    a = by_hash[chunk["asset_raw_sha256"]]
                    record["chunks"].append({"file": a["asset_relative_path"], "sha256": a["webp_sha256"], "size": a["dimensions"],
                        "position": placement(chunk, a, origin), "world_bounds": chunk["world_bounds"], "source": chunk["source"]})
                if source_id in SELECTED:
                    g = grid_by_id[source_id]
                    require(g["archive_version_label"] == "360" and g["client_scenery_semantically_verified"] is False, "grid provenance")
                    raw = z.read(f"map_source3_links/collision/grids/360/{source_id}.u8.gz")
                    require(hashlib.sha256(raw).hexdigest() == g["grid_sha256"], "compressed grid SHA")
                    cells = gzip.decompress(raw)
                    require(len(cells) == g["width"]*g["height"] and hashlib.sha256(cells).hexdigest() == g["raw_u8_sha256"], "raw grid SHA")
                    rel = f"collision/{source_id}.u8.gz"
                    (stage / "collision").mkdir(exist_ok=True)
                    (stage / rel).write_bytes(raw)
                    record["collision"] = {"file": rel, "sha256": g["grid_sha256"], "raw_sha256": g["raw_u8_sha256"], "width": g["width"], "height": g["height"],
                        "bounds": g["world_bounds_candidate"], "version": "360", "encoding": "raw-u8-directional-not-boolean", "playable": False}
                if source_id is not None:
                    # Reference-only records, never inject these into World population.
                    record["routes"] = [{k: r.get(k) for k in ("route_id", "kind", "source_map_id", "source_x", "source_y", "destination_map_id", "destination_x", "destination_y", "status", "enabled")} for r in routes if r.get("source_map_id") == source_id]
                    record["doors"] = [{k: d.get(k) for k in ("id", "mapid", "locx", "locy", "dynamic_door_cells", "initial_open", "enabled")} for d in doors if d["mapid"] == source_id]
                path = f"maps/{mid}.json"
                sha = write_json(stage / path, record)
                index["maps"][mid] = {"file": path, "sha256": sha, "name": row["korean_name"], "source_map_id": source_id, "playable": False}
            index["safety"] = {"file": "runtime_safety.json", "sha256": write_json(stage / "runtime_safety.json", safety)}
            index_sha = write_json(stage / "index.json", index)
            # No current pack or save is overwritten; publish only a fully built directory.
            os.rename(stage, output)
    result = {"schema": 1, "index_sha256": index_sha, "linkage_sha256": LINKAGE_SHA,
              "library_file_id": "libfile_8915c315c714819199ece61649702d96", "library_version": 3,
              "maps": 84, "selected_collision_maps": 31, "unselected_numeric_maps": 48, "asset_only_variants": 5,
              "playable_maps": 0, "new_monster_spawns": 0}
    if receipt:
        write_json(receipt, result)
    return result


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--linkage-zip", type=Path, required=True)
    p.add_argument("--assets", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--receipt", type=Path)
    a = p.parse_args()
    try:
        print(json.dumps(build(a.linkage_zip, a.assets, a.output, a.receipt), ensure_ascii=False))
    except (ValueError, OSError, KeyError, zipfile.BadZipFile) as e:
        p.exit(1, f"SOURCE_MAP_PACK_FAILED: {e}\n")
