"""Original-member inventory/support and partial Main observations, never a95% shortcut."""
from __future__ import annotations

import argparse
import collections
import gzip
import hashlib
import json
from pathlib import Path
import zipfile

CATALOG_MEMBER = "maps/current523_Map_Tile_full_catalog_and_lineage_diff.jsonl.gz"
CATALOG_SHA = "c395f35afa067dfad04db3d615c7f39acbdea7134ae8f2023bbbf75c5639f1b7"
SOURCE_SHA = "6b71f4adb533b7acae6a7327e83af1b1322001a0f67c417bb3fae1bec35d96ca"
TILE_SHA = "8a954372eed28e360dc3c7c77f361fba1e0fcc7ee1daa7ffa204f6a679e28482"


def verified_json(path: Path, expected: str):
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError(f"Pinned manifest identity differs: {path.name}")
    return json.loads(raw)


def union_bytes(ranges: list[tuple[int, int]], limit: int) -> int:
    """Union exact original byte intervals; overlapping owners/runs count once."""
    spans = []
    for begin, length in ranges:
        if begin < 0 or length <= 0 or begin + length > limit:
            raise ValueError("Observation range exceeds the original member")
        spans.append((begin, begin + length))
    total = 0
    previous_end = -1
    for begin, end in sorted(spans):
        total += max(0, end - max(begin, previous_end))
        previous_end = max(previous_end, end)
    return total


def load_catalog(path: Path) -> dict:
    digest = hashlib.sha256()
    rows = {}
    with zipfile.ZipFile(path) as archive:
        with archive.open(CATALOG_MEMBER) as compressed, gzip.GzipFile(fileobj=compressed) as stream:
            for line in stream:
                digest.update(line)
                row = json.loads(line)
                if row["member"] in rows or row["category"] not in {"Map", "Tile"}:
                    raise ValueError("Duplicate or wrong-domain original member")
                rows[row["member"]] = row
    if digest.hexdigest() != CATALOG_SHA or len(rows) != 16825:
        raise ValueError("Fixed original catalog identity differs")
    return rows


def merge_observations(paths: list[Path]) -> dict:
    merged = {}
    for path in paths:
        snapshot = json.loads(path.read_bytes())
        if snapshot.get("schema") != 1 or snapshot.get("inventory_JSONL_SHA256") != CATALOG_SHA:
            raise ValueError("Observation inventory/schema differs")
        for key, row in snapshot["members"].items():
            if key != row["member"] + "|" + row["sha256"]:
                raise ValueError("Observation identity key differs")
            if row.get("whole_file_used") or row.get("original_member_bytes_fully_used_proven") != 0:
                raise ValueError("Partial observations cannot claim whole original files")
            target = merged.setdefault(key, {
                "member": row["member"], "sha256": row["sha256"],
                "original_member_bytes": row["original_member_bytes"], "origins": {},
            })
            if target["original_member_bytes"] != row["original_member_bytes"]:
                raise ValueError("Conflicting original member sizes")
            for origin, event in row["origins"].items():
                if origin not in {"AUTOMATED_ACTUAL_MAIN", "USER_MAIN"}:
                    raise ValueError("Inspection/fixture is not a Main observation")
                combined = target["origins"].setdefault(origin, {"units": set(), "ranges": set()})
                combined["units"].update(event["units"])
                combined["ranges"].update(tuple(map(int, value.split(":"))) for value in event["source_ranges"])
    return merged


def audit(catalog: dict, source: dict, tiles: dict, source_root: Path,
          tile_root: Path, observations: dict) -> dict:
    inventory = {kind: {"files": 0, "original_member_bytes": 0} for kind in ("Map", "Tile")}
    classes = collections.defaultdict(lambda: {"files": 0, "original_member_bytes": 0})
    for row in catalog.values():
        target = inventory[row["category"]]
        target["files"] += 1
        target["original_member_bytes"] += row["bytes"]
        label = row.get("lineage_gap_classification") or "within_previous_target_lineage"
        classes[label]["files"] += 1
        classes[label]["original_member_bytes"] += row["bytes"]
    support = {kind: {"lossless_carrier_present_files": 0, "carrier_original_member_bytes": 0,
                      "partial_consumer_target_files": 0, "target_original_size_context_only": 0}
               for kind in ("Map", "Tile")}
    for kind, rows, root in (("Map", source["members"], source_root), ("Tile", tiles["tiles"], tile_root)):
        for row in rows:
            original = catalog[row["member"]]
            size = int(row["bytes"] if kind == "Map" else row["source_bytes"])
            sha = row["sha256"] if kind == "Map" else row["source_sha256"]
            if original["bytes"] != size or original.get("sha256") not in (None, sha):
                raise ValueError("Runtime/original inventory identity differs")
            carrier = root / (row["path"] if kind == "Map" else row["original_path"])
            if carrier.is_file():
                support[kind]["lossless_carrier_present_files"] += 1
                support[kind]["carrier_original_member_bytes"] += size
            supported = kind == "Tile" or (row.get("format") == "s32" and row.get("status") == "ready")
            if supported:
                support[kind]["partial_consumer_target_files"] += 1
                support[kind]["target_original_size_context_only"] += size
    usage = {}
    for row in observations.values():
        category = row["member"].split("/", 1)[0]
        if row["member"] in catalog:
            original = catalog[row["member"]]
            if original["bytes"] != row["original_member_bytes"] or original.get("sha256") not in (None, row["sha256"]):
                raise ValueError("Observed original inventory identity differs")
        for origin, event in row["origins"].items():
            counter = usage.setdefault(origin, {}).setdefault(category, {
                "partially_observed_files": 0, "partial_member_size_context_only": 0,
                "observed_units": 0, "original_byte_ranges_proven": 0,
                "members_with_unquantified_partial_bytes": 0,
                "whole_files_used": 0, "whole_original_bytes_used": 0,
            })
            counter["partially_observed_files"] += 1
            counter["partial_member_size_context_only"] += row["original_member_bytes"]
            counter["observed_units"] += len(event["units"])
            counter["original_byte_ranges_proven"] += union_bytes(list(event["ranges"]), row["original_member_bytes"])
            if not event["ranges"]:
                counter["members_with_unquantified_partial_bytes"] += 1
    return {
        "schema": 1, "scope_owner": "MAPS", "inventory_JSONL_SHA256": CATALOG_SHA,
        "fixed_original_Map_Tile_denominator": inventory,
        "original_classifications_preserved_not_subtracted_from_denominator": dict(classes),
        "current_runtime_pack_support_not_game_usage": support,
        "observations_by_execution_origin": usage,
        "global_non_sound_denominator_known": False, "usage95_verified": False,
        "rules": ["Original member bytes only; ZIP/gzip/pixels/cache sizes are not numerator bytes.",
                  "Partial members' nominal sizes are context only; never whole-file usage.",
                  "Compressed Sprite/TI2 frame-unit ratios are not original-byte ratios.",
                  "Same member/hash and overlapping source ranges count once across owners/runs.",
                  "Unobserved does not mean permanently unused. Existing evidence outside this window stays separate."],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog-zip", type=Path, required=True)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--tile-root", type=Path, required=True)
    parser.add_argument("--observations", type=Path, action="append", default=[])
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    result = audit(load_catalog(args.catalog_zip),
                   verified_json(args.source_root / "source523.json", SOURCE_SHA),
                   verified_json(args.tile_root / "tilepack523.json", TILE_SHA),
                   args.source_root, args.tile_root, merge_observations(args.observations))
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
