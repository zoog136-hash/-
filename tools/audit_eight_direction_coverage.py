#!/usr/bin/env python3
"""Audit production identities and actual native poses, without inflating coverage.

The CSV contains every registered transform, monster, boss and class in all eight
screen directions. PNG pixel/hash checks establish installed source motions;
they do not establish direction semantics or actual gameplay/device execution.
"""
import argparse
import csv
import hashlib
import json
import os
import re
import subprocess
from collections import Counter
from pathlib import Path

from PIL import Image

import build_animation_expansion as expansion

DIRECTIONS = ("E", "SE", "S", "SW", "W", "NW", "N", "NE")
VECTORS = ((1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1))
REQUIRED_ROLES = ("idle", "walk", "attack", "hit", "death")
ROLES = REQUIRED_ROLES + ("ranged_attack", "cast", "special")
NATIVE_PREFIX = "res://assets/actors/eight_direction/"


def load(path):
    return json.loads(path.read_text())


def local_path(root, path):
    if not path.startswith("res://assets/") or ".." in Path(path).parts:
        raise ValueError("unsafe resource path: " + path)
    return root / path.removeprefix("res://")


def read_spriteframes(path):
    """Read the bounded AtlasTexture SpriteFrames used by the existing pack."""
    text = path.read_text()
    external = dict((resource_id, resource_path) for resource_path, resource_id in re.findall(
        r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text))
    subresources = {}
    for resource_id, block in re.findall(
            r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', text, re.S):
        atlas = re.search(r'atlas = ExtResource\("([^"]+)"\)', block)
        rects = {}
        for key in ("region", "margin"):
            match = re.search(key + r' = Rect2\(([^)]+)\)', block)
            rects[key] = tuple(int(float(value.strip())) for value in match[1].split(",")) if match else (0, 0, 0, 0)
        if atlas is None or atlas[1] not in external:
            raise ValueError("missing atlas reference: " + resource_id)
        subresources[resource_id] = {"path": external[atlas[1]], **rects}
    block = text.split("animations = ", 1)[1]
    block = re.sub(r'SubResource\("([^"]+)"\)', r'"\1"', block)
    block = block.replace('&"', '"')
    # Resource metadata may follow the animations array (e.g. an explicit
    # normalized canvas for original-based sheets of different resolutions).
    animations, _end = json.JSONDecoder().raw_decode(block.lstrip())
    return external, subresources, {track["name"]: track for track in animations}


def audit_resource(root, path, tracked):
    result = {"path": path, "tracks": {}, "errors": [], "tracked": True,
              "compass_semantics": "source_metadata_only", "actual_gameplay": "not_run"}
    try:
        resource_path = local_path(root, path)
        proof_path = resource_path.with_name("provenance.json")
        proof = load(proof_path)
        external, frames, animations = read_spriteframes(resource_path)
        result["source"] = proof.get("source", "unknown")
        result["source_direction_indices"] = proof.get("source_direction_indices", [])
        result["source_directions"] = proof.get("source_directions", [])
        result["resource_sha256"] = hashlib.sha256(resource_path.read_bytes()).hexdigest()
        file_paths = {path, "res://" + str(proof_path.relative_to(root)), *external.values()}
        untracked = sorted(p for p in file_paths if p.removeprefix("res://") not in tracked)
        result["tracked"] = not untracked
        if untracked:
            result["errors"].append("untracked native resources: " + ", ".join(untracked))
        images = {}
        for atlas_path in external.values():
            images[atlas_path] = Image.open(local_path(root, atlas_path)).convert("RGBA")
        for role, source_track in proof.get("tracks", {}).items():
            atlas_records = source_track.get("atlas_files", [])
            if not atlas_records and source_track.get("sha256"):
                atlas_paths = {frames[f["texture"]]["path"] for name, track in animations.items()
                               if name.startswith(role + "_") for f in track["frames"]}
                if len(atlas_paths) == 1:
                    atlas_records = [{"path": next(iter(atlas_paths)), "sha256": source_track["sha256"]}]
            for atlas in atlas_records:
                actual_hash = hashlib.sha256(local_path(root, atlas["path"]).read_bytes()).hexdigest()
                if actual_hash != atlas["sha256"]:
                    result["errors"].append("atlas SHA-256 differs: " + atlas["path"])
        for name, track in animations.items():
            poses = set()
            for frame in track["frames"]:
                spec = frames[frame["texture"]]
                atlas = images[spec["path"]]
                x, y, width, height = spec["region"]
                if width <= 0 or height <= 0 or x < 0 or y < 0 or x + width > atlas.width or y + height > atlas.height:
                    raise ValueError("out-of-bounds source frame: " + name)
                cropped = atlas.crop((x, y, x + width, y + height))
                if cropped.getchannel("A").getbbox() is None:
                    result["errors"].append("empty actual pose: " + name)
                margin_x, margin_y, margin_w, margin_h = spec["margin"]
                # Reconstruct the same virtual canvas used by Godot AtlasTexture.
                canvas = Image.new("RGBA", (width + margin_w, height + margin_h))
                canvas.paste(cropped, (margin_x, margin_y))
                poses.add(hashlib.sha256(canvas.tobytes()).hexdigest())
            result["tracks"][name] = {"frames": len(track["frames"]), "distinct_rgba": len(poses), "loop": track["loop"]}
            role, _, direction = name.rpartition("_")
            source_track = proof.get("tracks", {}).get(role, {})
            expected = source_track.get("direction_unique_frames", {}).get(DIRECTIONS[int(direction)]) if direction.isdigit() and int(direction) < 8 else None
            if expected is not None and len(poses) != expected:
                result["errors"].append("distinct source pose mismatch: " + name)
        for role in REQUIRED_ROLES:
            for direction in range(8):
                name = f"{role}_{direction}"
                track = result["tracks"].get(name)
                if track is None or track["distinct_rgba"] < 2:
                    result["errors"].append("missing real sequential motion: " + name)
                elif track["loop"] != (role in ("idle", "walk")):
                    result["errors"].append("incorrect action loop: " + name)
        for image in images.values():
            image.close()
    except (OSError, ValueError, KeyError, IndexError, TypeError) as exc:
        result["errors"].append(str(exc))
    result["pixel_integrity"] = "failed" if result["errors"] else "verified"
    return result


def identities(root):
    catalog = load(root / "data/catalog_v19.json")["변신"]
    records = [{"key": "transform:" + str(row["sourceId"]), "name": row["name"], "group": "hero_plus" if row["grade"] in expansion.GRADES else "other_transform"}
               for row in catalog]
    recipes = expansion.plan(root)
    boss_by_key = {key: value["boss"] for section in ("bindings", "unmatched")
                   for key, value in recipes[section].items() if key.startswith("monster:")}
    for row in expansion.monsters(root):
        key = "monster:" + row["name"]
        records.append({"key": key, "name": row["name"], "group": "boss" if boss_by_key.get(key, False) else "normal_monster"})
    for index, name in enumerate(("기본 기사", "기본 마법사", "기본 요정", "기본 암살자")):
        records.append({"key": f"class:{index}", "name": name, "group": "class"})
    return records, recipes


def audit(root):
    profiles = load(root / "data/combat_animation_profiles.json")["profiles"]
    tracked = set(subprocess.check_output(["git", "ls-files"], cwd=root, text=True).splitlines())
    records, recipes = identities(root)
    resources = {}
    rows = []
    count = Counter()
    for record in records:
        path = profiles.get(record["key"], {}).get("frames_path", "")
        native = path.startswith(NATIVE_PREFIX) and path.endswith("/SpriteFrames.tres")
        if native and path not in resources:
            resources[path] = audit_resource(root, path, tracked)
        resource = resources.get(path, {})
        verified = native and resource["pixel_integrity"] == "verified"
        count[record["group"] + ":registered"] += 1
        if verified:
            count[record["group"] + ":native_connected"] += 1
        reason = recipes["unmatched"].get(record["key"], {}).get("reason", "Existing legacy art retained; no native sequential8 profile") if not native else ""
        record.update({"native_connected": verified, "frames_path": path, "missing_source": reason,
                       "actual_gameplay": "not_run", "compass_semantics": resource.get("compass_semantics", "not_verified")})
        for direction, (x, y) in enumerate(VECTORS):
            row = {"id": record["key"], "name": record["name"], "group": record["group"], "direction": DIRECTIONS[direction],
                   "input_x": x, "input_y": y, "source_state": resource.get("pixel_integrity", "legacy_retained"),
                   "frames_path": path, "compass_semantics": record["compass_semantics"], "actual_gameplay": "not_run", "missing_source": reason}
            for role in ROLES:
                track = resource.get("tracks", {}).get(f"{role}_{direction}", {})
                row[role + "_frames/distinct"] = f'{track["frames"]}/{track["distinct_rgba"]}' if track else "missing"
            rows.append(row)
    errors = [{"path": path, "errors": value["errors"]} for path, value in resources.items() if value["errors"]]
    return {"schema": 1, "evidence_scope": "Production profiles + tracked PNG hashes + reconstructed RGBA; gameplay/compass semantics/device execution require separate Godot evidence",
            "supplementary_evidence": ["../resource-mapping-audit.json", "../DIRECTION_CAUSE.md", "../gameplay.json"],
            "directions": list(DIRECTIONS), "mandatory_roles": list(REQUIRED_ROLES), "counts": dict(count),
            "identities": records, "resources": list(resources.values()), "errors": errors,
            "missing_categories": dict(Counter(value["missing_source"] for value in records if value["missing_source"]))}, rows


def attach_gameplay_evidence(result, rows, paths, output_dir):
    """Link only explicitly exercised identities/directions, never shared aliases.

    A recorded Main run is separate from current PNG integrity. Pose sampling
    alone is not an input/AI combat case and cannot promote a direction row.
    """
    indexed = {(row["id"], row["direction"]): row for row in rows}
    for row in rows:
        row["gameplay_evidence"] = ""
    result["recorded_main_evidence"] = []
    for path in paths:
        report = load(path)
        if report.get("failures") != [] or report.get("setup", {}).get("scene") != "Main.tscn" or report.get("checks", 0) < 1:
            raise ValueError("Not a successful production Main report: " + str(path))
        reference = Path(os.path.relpath(path.resolve(), output_dir.resolve())).as_posix()
        matched = set()
        for kind in ("player", "monster", "boss"):
            for case in report.get(kind, []):
                key = case.get("form", "") if kind == "player" else "monster:" + case.get("name", "")
                compass = case.get("compass", "")
                if compass not in DIRECTIONS or case.get("facing") != DIRECTIONS.index(compass):
                    raise ValueError("Recorded facing differs from compass: " + str(path))
                exercised = (case.get("attack_visible") is True and case.get("hit_count", 0) > 0 and case.get("hp_after", 0) < case.get("hp_before", 0)) if kind == "player" else (
                    case.get("walk") is True and case.get("attack") is True and case.get("contacts", 0) > 0) if kind == "monster" else (
                    case.get("warning") is True and case.get("effect") is True and case.get("contacts", 0) > 0)
                if not exercised:
                    raise ValueError("Incomplete recorded gameplay case: " + str(path))
                row = indexed.get((key, compass))
                if row is None:
                    raise ValueError("Recorded identity is not registered: " + key)
                row["actual_gameplay"] = "recorded_Main_sample"
                existing = row["gameplay_evidence"].split(";") if row["gameplay_evidence"] else []
                if reference not in existing: existing.append(reference)
                row["gameplay_evidence"] = ";".join(existing)
                matched.add((key, compass))
        result["recorded_main_evidence"].append({"path":reference, "sha256":hashlib.sha256(path.read_bytes()).hexdigest(),
                                                "scope":report.get("scope", "full"), "direction_rows":len(matched)})
    for identity in result["identities"]:
        count = sum(row["actual_gameplay"] == "recorded_Main_sample" for row in rows if row["id"] == identity["key"])
        identity["actual_gameplay"] = f"recorded_Main_{count}_directions" if count else "not_run"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--source-tree", type=Path, help="Optional pinned Flare animation descriptor inventory from GitHub (JSON lines path/sha records)")
    parser.add_argument("--gameplay-report", type=Path, action="append", default=[], help="Successful actual Main JSON; repeat for each exercised identity. Shared art does not imply another identity was played.")
    args = parser.parse_args()
    result, rows = audit(args.root.resolve())
    attach_gameplay_evidence(result, rows, args.gameplay_report, args.output_dir)
    evidence = args.root.resolve() / "docs/remake/evidence/pr100-direction-fix"
    result["supplementary_evidence"] = [Path(os.path.relpath(evidence / name, args.output_dir.resolve())).as_posix()
                                         for name in ("resource-mapping-audit.json", "DIRECTION_CAUSE.md", "gameplay.json")]
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "coverage.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    missing = [value for value in result["identities"] if value["group"] in ("hero_plus", "normal_monster", "boss") and not value["native_connected"]]
    missing_report = {"schema": 1, "scope": "Remaining target identities; compatible source motion unavailable, legacy art preserved",
                      "missing_counts": dict(Counter(value["group"] for value in missing)),
                      "categories": dict(Counter(value["missing_source"] for value in missing)),
                      "identities": [{key: value[key] for key in ("key", "name", "group", "missing_source")} for value in missing]}
    if args.source_tree:
        descriptors = [json.loads(line) for line in args.source_tree.read_text().splitlines() if line.strip()]
        missing_report["inspected_source"] = {"repository": "https://github.com/flareteam/flare-game", "revision": "af6eee6d339ac98011864bfe89da837fe7769c28",
            "descriptor_inventory_sha256": hashlib.sha256(args.source_tree.read_bytes()).hexdigest(), "descriptors": len(descriptors),
            "enemy_names": sorted({Path(row["path"]).stem for row in descriptors if "/enemies/" in row["path"]}),
            "avatar_part_names": sorted({Path(row["path"]).stem for row in descriptors if "/avatar/" in row["path"]}),
            "enemy_descriptors": [row for row in descriptors if "/enemies/" in row["path"]],
            "result": "No additional identity-compatible remaining body/costume/weapon found; no unsupported substitutions or fabricated frames added"}
    (args.output_dir / "missing-native-sources.json").write_text(json.dumps(missing_report, ensure_ascii=False, indent=2) + "\n")
    with (args.output_dir / "all-identities-eight-directions.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print("EIGHT_DIRECTION_COVERAGE " + json.dumps({"counts": result["counts"], "identities": len(result["identities"]), "direction_rows": len(rows), "native_resources": len(result["resources"]), "errors": result["errors"]}, ensure_ascii=False))
    raise SystemExit(1 if result["errors"] else 0)


if __name__ == "__main__":
    main()
