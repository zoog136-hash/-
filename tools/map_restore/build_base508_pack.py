"""Build a private, versioned map pack without changing live maps or saves.

Inputs are the validated base508 analysis, structural inventory, optional
extracted Map/<AssetPath>/*.s32 and the separately authenticated original PNG.
No downloads, A3 collision conversion, tail-portal guesses or game execution.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zlib

from base508 import read_s32, write_s32


def sha(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, separators=(",", ":"))+"\n")


def build(args):
    if args.out.exists():
        raise ValueError("Output must be a new private directory; existing packs are preserved")
    analysis, inventory = args.analysis, args.structure / "inventory"
    lands = json.loads((analysis / "land_catalog.json").read_text())
    land = next(row for row in lands if row["ID"] == args.land)
    asset = land["AssetPath"].strip("/")
    if not asset.replace("_", "").isalnum():
        raise ValueError("Unsafe AssetPath")
    maps = json.loads((inventory / "map_id_to_archive.json").read_text())[asset]
    tile_index = json.loads((inventory / "tile_id_to_archive.json").read_text())
    portals = [p for p in json.loads((analysis / "portal_links.json").read_text()) if p["SourceLandID"] == args.land]
    earth = [p for p in json.loads((analysis / "earth_object_placements.json").read_text()) if p.get("Territory", {}).get("LandID") == args.land]
    args.out.mkdir(parents=True)
    save(args.out / "registrations.json", [{"land_id": l["ID"], "asset_path": l["AssetPath"]} for l in lands])
    save(args.out / "portals.json", portals)
    save(args.out / "object_occupancy_evidence.json", earth)
    npc_evidence = []
    npc_classes = {}
    if args.tables:
        npc_classes = {row["ID"]: row for row in json.loads((args.tables / "content/NpcClass.json").read_text(encoding="utf-8-sig"))["rows"]}
    with (analysis / "npc_spawnpack_index.jsonl").open() as handle:
        for line in handle:
            row = json.loads(line)
            territories = [t for t in row["TerritoryReferences"] if t.get("Territory", {}).get("LandID") == args.land]
            if not territories:
                continue
            classes = []
            for view in row["NpcClassViews"]:
                original = npc_classes.get(view["NpcClassID"], {})
                classes.append({"view": view, "IsOccupyLandTile": original.get("IsOccupyLandTile"), "flag_source": "NpcClass" if original else "UNAVAILABLE"})
            npc_evidence.append({"NpcSpawnPackID": row["NpcSpawnPackID"], "TerritoryReferences": territories, "classes": classes, "runtime_placements": "UNCONFIRMED"})
    save(args.out / "npc_occupancy_evidence.json", npc_evidence)
    # One shared visual resource, with exact per-Land tables kept separately.
    shared_lands = [l for l in lands if l["AssetPath"].strip("/") == asset]
    all_portals = json.loads((analysis / "portal_links.json").read_text())
    all_earth = json.loads((analysis / "earth_object_placements.json").read_text())
    contexts = {l["ID"]:{"land":l,"portals":[p for p in all_portals if p["SourceLandID"]==l["ID"]],"npc_evidence":[],"earth_object_evidence":[p for p in all_earth if p.get("Territory",{}).get("LandID")==l["ID"]]} for l in shared_lands}
    with (analysis / "npc_spawnpack_index.jsonl").open() as handle:
        for line in handle:
            row = json.loads(line)
            for lid, context in contexts.items():
                territories = [t for t in row["TerritoryReferences"] if t.get("Territory",{}).get("LandID")==lid]
                if not territories: continue
                classes = [{"view":view,"IsOccupyLandTile":npc_classes.get(view["NpcClassID"],{}).get("IsOccupyLandTile"),"flag_source":"NpcClass" if view["NpcClassID"] in npc_classes else "UNAVAILABLE"} for view in row["NpcClassViews"]]
                context["npc_evidence"].append({"NpcSpawnPackID":row["NpcSpawnPackID"],"TerritoryReferences":territories,"classes":classes,"runtime_placements":"UNCONFIRMED"})
    save(args.out / "land_contexts.json", list(contexts.values()))
    chunks, chunk_data, missing, tile_ids = [], [], [], set()
    for record in maps:
        source = args.source / record["member"] if args.source else None
        if source is None or not source.is_file():
            missing.append(record)
            continue
        data = source.read_bytes()
        if len(data) != record["bytes"] or f"{zlib.crc32(data):08x}" != record["crc32"]:
            raise ValueError("Source inventory CRC/size mismatch: " + str(source))
        row = read_s32(data, record["member"])
        if write_s32(row) != data:
            raise ValueError("Lossless roundtrip failed: " + str(source))
        chunk_data.append(row)
        relative = "geometry/" + source.stem + ".json"
        save(args.out / relative, row)
        original_file = args.out / "source" / record["member"]
        original_file.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, original_file)
        tile_ids.update(pair[0] for pair in row["tile_pairs"])
        chunks.append({"file": relative, "origin": row["origin"], "sha256": sha(args.out / relative), "source_file": "source/"+record["member"], "source_sha256": row["source_sha256"]})
    # The audited corpus still provides exact requests when S32 bytes are absent.
    if missing:
        import gzip
        with gzip.open(args.structure / "maps/chunks.jsonl.gz", "rt") as handle:
            for line in handle:
                row = json.loads(line)
                if row["member"].startswith("Map/" + asset + "/"):
                    tile_ids.update(row.get("floor_tile_ids", []))
                    tile_ids.update(row.get("foreground_tile_ids", []))
    requests = maps + [entry for tile in sorted(tile_ids) for entry in tile_index[str(tile)]]
    save(args.out / "source_requests.json", requests)
    containers = json.loads((inventory / "map_tile_catalog_summary.json").read_text())["containers"]
    save(args.out / "container_requests.json", [row for row in containers if row["name"] in {r["archive"] for r in requests}])
    art = {"status": "MISSING", "coordinate_space": "PNG_PIXELS_ONLY", "source_to_png_transform": None, "chunks": []}
    image, composition = None, None
    if args.png:
        # Pin the original through its existing authenticated source manifest.
        manifest = json.loads(args.png_manifest.read_text())
        expected = next(r for r in manifest["sources"] if r["file"] == asset + ".png")
        if args.png.stat().st_size != expected["bytes"] or sha(args.png) != expected["sha256"]:
            raise ValueError("Original PNG hash/size mismatch")
        from PIL import Image
        Image.MAX_IMAGE_PIXELS = 160_000_000
        image = Image.open(args.png)
        image.load()
        if list(image.size) != expected["size"] or image.mode != "RGBA":
            raise ValueError("Original PNG dimensions/mode mismatch")
        art.update(status="ORIGINAL_PNG_RENDERABLE", size=list(image.size), visible_bounds=list(image.getchannel("A").getbbox()), source_sha256=expected["sha256"], provenance="Existing authenticated original PNG; base508 S32 composition not proven")
    elif args.compose_tiles:
        if not args.source or missing:
            raise ValueError("TI2 composition requires all inventoried original S32 chunks")
        from compose_base508 import compose
        from base508_tile_cache import TileCache
        cache = TileCache(args.tile_cache) if getattr(args,"tile_cache",None) else None
        try:
            image, composition = compose(chunk_data, args.source, tile_index, args.out,cache)
        finally:
            if cache is not None: cache.close()
        art.update(status="S32_TI2_RENDERABLE", coordinate_space="SOURCE_DERIVED_DISPLAY_ONLY", size=list(image.size), visible_bounds=list(image.getchannel("A").getbbox()), provenance="Original base508 S32 placements and original TI2 RGB565 pixels", source_to_png_transform={"anchor": "source_cell_half_tile_origin", "source_origin": composition["source_origin"], "basis_x": [24,-12], "basis_y": [24,12], "translation": composition["pixel_translation"]}, composition_file="composition.json", composition_sha256=sha(args.out / "composition.json"))
    if image is not None:
        art["pixel_sha256"] = hashlib.sha256(image.tobytes()).hexdigest()
        for y in range(0, image.height, 1024):
            for x in range(0, image.width, 1024):
                piece = image.crop((x, y, min(x+1024, image.width), min(y+1024, image.height)))
                if piece.getchannel("A").getbbox() is None:
                    continue
                relative = f"art/{x//1024}-{y//1024}.png"
                path = args.out / relative
                path.parent.mkdir(exist_ok=True)
                piece.save(path)
                art["chunks"].append({"file": relative, "position": [x, y], "size": list(piece.size), "sha256": sha(path)})
        image.thumbnail((1800, 1800))
        image.save(args.out / "overview.png")
        art["overview"] = "overview.png"
        art["overview_sha256"] = sha(args.out / "overview.png")
    preserved = []
    for path in args.preserve:
        target = args.out / "preserved_navigation" / path.name
        target.parent.mkdir(exist_ok=True)
        shutil.copyfile(path, target)
        preserved.append({"file": str(target.relative_to(args.out)), "sha256": sha(target), "status": "PRESERVED_EXISTING_UNMAPPED_TO_SOURCE"})
    report = {"registered_land_rows": len(lands), "distinct_asset_paths": len({l["AssetPath"] for l in lands}),
              "target_chunks_expected": len(maps), "target_chunks_losslessly_loaded": len(chunks),
              "original_png_maps_renderable": int(bool(art["chunks"]) and bool(args.png)), "s32_ti2_maps_renderable": int(bool(composition)), "visual_s32_tiles_restored": 0,
              "portal_links_preserved": len(portals), "portal_regions_preserved": sum(not p["TargetIsPoint"] for p in portals),
              "portal_runtime_connections": 0, "confirmed_terrain_collision_cells": 0,
              "unresolved_terrain_attribute_words": len(maps)*8192,
              "earth_object_placement_evidence": len(earth), "confirmed_object_occupied_cells": 0,
              "npc_spawnpack_evidence": len(npc_evidence),
              "npc_classes_with_occupancy_true": len({c["view"]["NpcClassID"] for p in npc_evidence for c in p["classes"] if c["IsOccupyLandTile"] is True}),
              "preserved_existing_navigation_files": len(preserved), "missing_s32_files": len(missing),
              "required_tile_ids": len(tile_ids), "required_source_bytes": sum(r["bytes"] for r in requests)}
    if composition:
        report.update(composition["statistics"])
    pack = {"schema": 1, "edition": "LineageM_base508", "land": land, "geometry": chunks,
            "land_contexts_file":"land_contexts.json","land_contexts_sha256":sha(args.out / "land_contexts.json"),
            "art": art, "portals_file": "portals.json", "portals_sha256": sha(args.out / "portals.json"), "npc_occupancy_file": "npc_occupancy_evidence.json", "npc_occupancy_sha256": sha(args.out / "npc_occupancy_evidence.json"), "preserved_navigation": preserved,
            "terrain_collision": "UNKNOWN", "default_movement": "BLOCK_UNCONFIRMED",
            "report": report}
    if chunks:
        from base508_contract import contract
        save(args.out / "source_contract.json", contract(pack))
        pack['source_contract_file'] = 'source_contract.json'
        pack['source_contract_sha256'] = sha(args.out / 'source_contract.json')
    save(args.out / "map.json", pack)
    save(args.out / "build_report.json", report)
    print(json.dumps(report, ensure_ascii=False))
    return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--analysis", type=Path, required=True)
    p.add_argument("--structure", type=Path, required=True)
    p.add_argument("--land", type=int, required=True)
    p.add_argument("--source", type=Path)
    p.add_argument("--tables", type=Path, help="Validated all-content root; retains original NpcClass occupancy flags")
    p.add_argument("--png", type=Path)
    p.add_argument("--png-manifest", type=Path)
    p.add_argument("--tile-cache",type=Path,help="Shared content-addressed TI2/frame SQLite cache across all maps")
    p.add_argument("--compose-tiles", action="store_true", help="Render original S32 layers with original Brotli TI2 pixels")
    p.add_argument("--preserve", type=Path, action="append", default=[])
    p.add_argument("--out", type=Path, required=True)
    args = p.parse_args()
    if bool(args.png) != bool(args.png_manifest):
        p.error("--png and --png-manifest must be provided together")
    if args.png and args.compose_tiles:
        p.error("Use either the existing original PNG or original S32/TI2 composition")
    build(args)


if __name__ == "__main__":
    main()
