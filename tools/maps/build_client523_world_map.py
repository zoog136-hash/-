#!/usr/bin/env python3
"""Build the 523 world-map contract from the client's own tables.

Input: the runtime-pinned 523 tables ZIP and the installed 523 image pack
manifest. Output: contract.json, the document
scripts/maps/source523_map_image_adapter.gd open_contract() reads, plus the
offer the world-map input needs per Land:

* image_infos: every UIMapImageInfo row a UIMapWorld row names
  (MapImageInfoID), joined to its AssetView row (AssetId == ImageID) and
  AssetType row, with the exact typed path AssetType.Path + AssetView.FilePath
  and the owning UIMapWorld rows. Rows keep their table and zero-based index.
* offered_worlds: for each Land with exactly one image-bearing UIMapWorld row,
  that World, labelled with its Korean DescData text (else its Name). A Land
  with several such rows gets no offer (no choice is made for it), and a World
  whose image is not in the image pack is not offered.

The contract holds derived original rows: keep it private, like the pack.

    python3 tools/maps/build_client523_world_map.py --tables <tables ZIP> \\
        --images-manifest <pack>/images/manifest.json --output <private>/world_map
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
import sys
import zipfile
from pathlib import Path

TABLES_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
SCHEMA = "twilight-source523-world-map-v1"
COORDINATE_POLICY = "OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1"
MAX_CONTRACT_BYTES = 4 * 1024 * 1024
REPO = Path(__file__).resolve().parents[2]


class InputError(Exception):
    pass


def require(condition, message):
    if not condition:
        raise InputError(message)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def table(archive: zipfile.ZipFile, name: str) -> list:
    document = json.loads(archive.read(f"content/{name}.json"))
    rows = document.get("rows") if isinstance(document, dict) else None
    require(isinstance(rows, list), f"{name}: no rows")
    return rows


def ref(name: str, index: int, row: dict) -> dict:
    return {"table": name, "row_index_zero": index, "raw": row}


def image_paths(manifest: Path) -> set:
    document = json.loads(manifest.read_text(encoding="utf-8"))
    return {(item.get("asset_id"), item.get("asset_type_id"), item.get("path"))
            for item in document.get("assets", []) if item.get("status") == "verified_original"}


def build(tables: Path, images_manifest: Path) -> dict:
    require(sha256_file(tables) == TABLES_SHA256, "tables ZIP is not the runtime-pinned 523 tables")
    with zipfile.ZipFile(tables) as archive:
        worlds = table(archive, "UIMapWorld")
        infos = table(archive, "UIMapImageInfo")
        views = table(archive, "AssetView")
        types = table(archive, "AssetType")
        korean = {row["ID"]: row.get("Description") for row in table(archive, "DescData_Korean")}
    info_rows = {row["ID"]: (index, row) for index, row in enumerate(infos)}
    type_rows = {row["ID"]: (index, row) for index, row in enumerate(types)}
    view_rows = collections.defaultdict(list)
    for index, row in enumerate(views):
        view_rows[row["AssetId"]].append((index, row))
    available = image_paths(images_manifest)

    owners = collections.defaultdict(list)
    for index, row in enumerate(worlds):
        if row.get("MapImageInfoID"):
            owners[row["MapImageInfoID"]].append((index, row))
    entries, shown = [], {}
    for info_id in sorted(owners):
        require(info_id in info_rows, f"UIMapWorld names absent UIMapImageInfo {info_id}")
        info_index, info = info_rows[info_id]
        candidates = view_rows.get(info["ImageID"], [])
        require(len(candidates) == 1, f"UIMapImageInfo {info_id}: AssetView rows for ImageID {info['ImageID']}: {len(candidates)}")
        view_index, view = candidates[0]
        require(view["AssetTypeId"] in type_rows, f"AssetView {view['AssetId']}: absent AssetType")
        type_index, asset_type = type_rows[view["AssetTypeId"]]
        path = asset_type["Path"] + view["FilePath"]
        entries.append({"image_info": ref("UIMapImageInfo", info_index, info),
                        "asset": {"source": ref("AssetView", view_index, view), "type": ref("AssetType", type_index, asset_type),
                                  "exact_typed_path": path},
                        "owners_by_ImageInfoID": [{"source": ref("UIMapWorld", index, row), "field": "MapImageInfoID"}
                                                  for index, row in owners[info_id]]})
        shown[info_id] = (view["AssetId"], view["AssetTypeId"], path) in available

    by_land = collections.defaultdict(list)
    for row in worlds:
        if row.get("MapImageInfoID") and row.get("LandID"):
            by_land[row["LandID"]].append(row)
    offered, several, missing_image = {}, {}, []
    for land in sorted(by_land):
        rows = by_land[land]
        if len(rows) != 1:
            several[str(land)] = sorted(row["ID"] for row in rows)
            continue
        world = rows[0]
        if not shown[world["MapImageInfoID"]]:
            missing_image.append(world["ID"])
            continue
        label = korean.get(world.get("DescID")) or world.get("Name")
        require(isinstance(label, str) and label, f"UIMapWorld {world['ID']}: no label")
        offered[str(land)] = {"world_id": world["ID"], "label": label}
    return {"schema": SCHEMA, "tables_sha256": TABLES_SHA256, "image_infos": entries,
            "offered_worlds": offered, "coordinate_policy": COORDINATE_POLICY, "ratio_scale": 1.0,
            "source_anchor_offset": [0.5, 0.5],
            "receipt": {"image_infos": len(entries), "offered_lands": len(offered),
                        "lands_with_several_worlds": several, "worlds_without_pack_image": missing_image}}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--tables", type=Path, required=True, help="runtime-pinned 523 tables ZIP (d5192c3c...)")
    parser.add_argument("--images-manifest", type=Path, required=True, help="installed images/manifest.json")
    parser.add_argument("--output", type=Path, required=True, help="new private directory")
    args = parser.parse_args(argv)
    out = args.output.resolve()
    if out == REPO or REPO in out.parents:
        parser.error("--output must be outside the repository")
    if out.exists():
        parser.error("--output must be a new directory")
    try:
        contract = build(args.tables, args.images_manifest)
    except InputError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    raw = json.dumps(contract, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode() + b"\n"
    if len(raw) > MAX_CONTRACT_BYTES:
        print("error: contract is above the 4 MB adapter limit", file=sys.stderr)
        return 1
    out.mkdir(mode=0o700)
    (out / "contract.json").write_bytes(raw)
    print(json.dumps({"contract_sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw), **contract["receipt"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
