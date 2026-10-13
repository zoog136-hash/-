#!/usr/bin/env python3
"""Rebuild the current-ID section of the sole resource delivery ledger.

Runtime export is a read-only Godot registry/load probe, not a visual test.
Pixel diversity is measured; it is never interpreted as original pose quality.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from PIL import Image

LEDGER = "data/resource_delivery_ledger.json"
MANIFEST = "data/visuals/runtime_manifest.json"


def read(path):
    return json.loads(Path(path).read_text())


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_ledger(path, ledger):
    """Keep generated per-ID rows on one line without a second status file."""
    def encode(value, keys=(), depth=0):
        compact_row = (len(keys) == 4 and keys[:2] == ("current_id_audit", "entities")) or (len(keys) == 3 and keys[:2] == ("current_id_audit", "motions"))
        if compact_row or not isinstance(value, dict):
            return json.dumps(value, ensure_ascii=False, separators=(",", ":") if compact_row else None)
        if not value:
            return "{}"
        padding = "  " * (depth + 1)
        return "{\n" + ",\n".join(padding + json.dumps(key, ensure_ascii=False) + ": " + encode(child, keys + (key,), depth + 1) for key, child in value.items()) + "\n" + "  " * depth + "}"
    Path(path).write_text(encode(ledger) + "\n")


def pixel_hash(image, crop_alpha=False):
    """Ignore hidden RGB and, optionally, pure translation/empty padding."""
    rgba = image.convert("RGBA")
    rgba.paste((0, 0, 0, 0), mask=rgba.getchannel("A").point(lambda a: 255 if a == 0 else 0))
    if crop_alpha:
        bounds = rgba.getchannel("A").getbbox()
        if bounds is None:
            return "empty"
        rgba = rgba.crop(bounds)
    return hashlib.sha256(str(rgba.size).encode() + rgba.tobytes()).hexdigest()


def frame_stats(image, entry):
    width, height = entry["cell"]
    tracks = {}
    direction_signatures = defaultdict(set)
    for track in entry["tracks"]:
        raw, cropped = [], []
        row, count = int(track["row"]), int(track["count"])
        if min(width, height, count) <= 0 or (row + 1) * height > image.height or count * width > image.width:
            raise ValueError(f"Atlas bounds invalid: {track['name']}")
        for column in range(count):
            frame = image.crop((column * width, row * height, (column + 1) * width, (row + 1) * height))
            raw.append(pixel_hash(frame))
            cropped.append(pixel_hash(frame, True))
        name = track["name"]
        action, _, direction = name.rpartition("_")
        if direction not in ("down", "up", "left", "right"):
            action = name
        direction_signatures[action].add(tuple(cropped))
        tracks[name] = {"cells": count, "unique_rgba_frames": len(set(raw)),
                        "unique_alpha_cropped_frames": len(set(cropped)),
                        "nonempty_unique_alpha_cropped_frames": len(set(cropped) - {"empty"}),
                        "fps": track.get("fps"), "loop": track.get("loop", False)}
    return {"tracks": tracks, "distinct_direction_sequences_by_action":
            {key: len(value) for key, value in sorted(direction_signatures.items())}}


class Audit:
    def __init__(self, root):
        self.root = Path(root)
        self.tracked = set(subprocess.check_output(["git", "ls-files", "-z"], cwd=root).decode().split("\0"))
        self.assets = {}

    def asset(self, path):
        if not path:
            return {"path": "", "exists": False, "sha256": None, "tracked": False}
        if path not in self.assets:
            relative = path.removeprefix("res://")
            local = self.root / relative
            valid = path.startswith("res://") and ".." not in Path(relative).parts
            exists = valid and local.is_file()
            self.assets[path] = {"path": path, "exists": exists,
                                 "sha256": digest(local) if exists else None,
                                 "tracked": relative in self.tracked}
        return self.assets[path]

    def status(self, source, loaded):
        return {"source": source, "runtime_load_tested": bool(loaded),
                "runtime_visually_tested": False,
                "rights": "existing_repository_asset_no_new_rights_determination",
                "delivery": "repository_file" if source.get("exists") and source.get("tracked") else "missing_or_untracked",
                "original_delivery": "not_delivered"}


def duplicate_groups(records, field):
    groups = defaultdict(list)
    for key, record in records.items():
        value = record["source"].get(field) if field in ("path", "sha256") else record.get(field)
        if value:
            groups[value].append(key)
    return [{field: key, "ids": sorted(ids)} for key, ids in sorted(groups.items()) if len(ids) > 1]


def reference_evidence(directory):
    """Store verification metadata only. No extracted source art is copied."""
    directory = Path(directory)
    inventory = read(directory / "reference_inventory.json")
    independent = read(directory / "independent_reference_verification.json")
    kit = directory / "animation_kit"
    manifest = read(kit / "motion_proof/manifest.json")
    result = {"inventory_sha256": digest(directory / "reference_inventory.json"),
              "independent_verification_sha256": digest(directory / "independent_reference_verification.json"),
              "archives_and_reports": [], "actors": {}}
    for source in inventory:
        local = Path(source["local_path"])
        actual = digest(local) if local.is_file() else None
        result["archives_and_reports"].append({"name": source["name"], "drive_url": source["url"],
            "sha256": source["sha256"], "bytes": source["actual_size"],
            "verified_in_current_workspace": actual == source["sha256"],
            "zip_crc_bad_member": source.get("zip_crc_bad_member"),
            "repository_delivery": "metadata_only", "rights": "not_verified_for_redistribution"})
    for actor_id, actor in manifest["actors"].items():
        actor_dir = kit / "motion_proof/actors" / actor_id
        pages = [Image.open(actor_dir / page).convert("RGBA") for page in actor["atlases"]]
        hashes = {}
        for key, frame in actor["frames"].items():
            x, y, width, height = frame["rect"]
            hashes[key] = pixel_hash(pages[frame["page"]].crop((x, y, x + width, y + height)), True)
        actions = {}
        for action_id, action in actor["actions"].items():
            sequences = []
            for direction in range(8 if action["directional"] else 1):
                sequences.append([hashes[f"{int(frame['sequence_base']) + direction}/{frame['frame']}"] for frame in action["frames"]])
            actions[action_id] = {"source_name": action["source_name"], "directions": len(sequences),
                "cells_per_direction": len(action["frames"]), "unique_alpha_cropped_frames_per_direction": [len(set(seq) - {"empty"}) for seq in sequences],
                "total_ticks": action["total_ticks"], "frame_ticks": [frame["ticks"] for frame in action["frames"]],
                "hit_marker_indices": [index for index, frame in enumerate(action["frames"]) if frame["hit_marker"]]}
        result["actors"][actor_id] = {"source_header": actor["source_header"],
            "spriteframes_path_in_kit": f"motion_proof/actors/{actor_id}/SpriteFrames.tres",
            "spriteframes_sha256": digest(actor_dir / "SpriteFrames.tres"),
            "atlas_sha256": {page: digest(actor_dir / page) for page in actor["atlases"]},
            "frame_records": len(actor["frames"]), "unique_alpha_cropped_frames": len(set(hashes.values()) - {"empty"}),
            "directions": "source_indices_0_to_7_cardinal_mapping_unverified", "actions": actions,
            "timing_basis": {"source_action_sha256": manifest["source_action_sha256"],
                "preview_ticks_per_second": manifest["preview_ticks_per_second"], "ticks_per_second_verified": False},
            "layers": actor["attributes"], "independent_reference_checks": independent["actors"][actor_id],
            "runtime_game_ids": [], "link_status": "no_verified_current_game_id_binding",
            "rights": "not_verified_for_redistribution", "delivery": "reference_available_private_drive_not_runtime_delivery",
            "runtime_load_tested": False, "runtime_visually_tested": False}
        for page in pages:
            page.close()
    return result


def build(root, runtime, references=None, previous=None):
    audit = Audit(root)
    manifest = read(Path(root) / MANIFEST)
    raw_catalog = read(Path(root) / "data/catalog_v19.json")
    raw_db = read(Path(root) / "data/game_db_v17.json")
    entities = {name: {} for name in ("classes", "transforms", "dolls", "relics", "monsters", "bosses", "maps", "items", "legacy_items", "effects")}
    motions = {}
    for key, info in sorted(manifest["catalog"].items()):
        source = audit.asset(info["atlas"])
        measured = {}
        if source["exists"]:
            with Image.open(Path(root) / info["atlas"].removeprefix("res://")) as image:
                measured = frame_stats(image, info)
        motions[key] = {"source": source, "portrait_or_directional_source": audit.asset(info["source"]),
            "directions_declared": info.get("directions"), "motion_status": "generated_catalog_atlas",
            "dedicated_original_motion_verified": False, "timing_basis": "TWILIGHT_manifest_fps_and_combat_profile_not_measured_source_timing",
            "layers": "flattened_rgba_no_independent_body_weapon_shadow_effect_layers", **measured}
    for category, kind, target in (("변신", "transform", "transforms"), ("마법인형", "doll", "dolls"), ("성물", "relic", "relics")):
        for row in runtime["catalog"][category]:
            key = f"{kind}:{row['sourceId']}"
            motion = motions.get(key, {})
            source = motion.get("source", audit.asset(row["image_path"]))
            entities[target][key] = {"name": row["name"], **audit.status(source, row["profile"]["loaded"]),
                "source_status": "existing_generated_catalog_derivative", "source_url": row["sourceUrl"],
                "motion_id": key if motion else None, "link_status": "registered_exact_source_id",
                "runtime_mapping": row["profile"], "common_fallback_supported": bool(row["profile"]["loaded"])}
    for row in runtime["classes"]:
        key = "class:" + row["name"]
        linked = "transform:" + row["source_id"]
        source = entities["transforms"][linked]["source"]
        entities["classes"][key] = {"name": row["name"], **audit.status(source, entities["transforms"][linked]["runtime_load_tested"]),
            "source_status": "representative_mythic_transform", "runtime_mapping": linked,
            "link_status": "world_job_class_source_id", "motion_id": linked,
            "dedicated_class_motion_verified": False, "common_fallback_supported": True}
    spawn_refs = defaultdict(list)
    for row in runtime["maps"]:
        key = "map:" + row["id"]
        definitions = row["spawns"]
        for spawn in definitions:
            for name in spawn.get("monster_types", []):
                spawn_refs[name].append({"map_id": row["id"], "spawn_id": spawn["id"],
                                         "mode": spawn.get("mode", "normal"), "region_capacity": spawn.get("max_count", 0)})
        source = audit.asset(row["definition_path"])
        entities["maps"][key] = {"name": row["name"], **audit.status(source, row["loaded"]),
            "source_status": "authored_gameplay_definition_not_original_tile_restoration",
            "motion_status": "not_applicable", "layers": {path: audit.asset(path) for path in sorted(row["asset_paths"])},
            "layer_runtime_loads": row["asset_loads"],
            "link_status": "registered_runtime_map_id", "runtime_mapping": row["definition_path"],
            "spawn_regions": len(definitions), "spawn_capacity": sum(int(spawn.get("max_count", 0)) for spawn in definitions),
            "referenced_monster_names": sorted({name for spawn in definitions for name in spawn.get("monster_types", [])}),
            "live_instances_observed": None}
    for row in runtime["monsters"]:
        key = "monster:" + row["name"]  # Runtime monster identity is the name, not a fabricated numeric ID.
        category = "bosses" if row["is_boss"] else "monsters"
        texture = row["texture"]
        source = audit.asset(texture["path"])
        entities[category][key] = {"name": row["name"], **audit.status(source, texture["loaded"]),
            "source_status": "shared_family_or_cropped_silhouette", "texture_region": texture.get("region"),
            "link_status": "runtime_name_identity", "runtime_mapping": row["profile"],
            "motion_status": "common_procedural_actor_motion", "dedicated_original_motion_verified": False,
            "directions_authored": 1, "unique_source_poses": 1, "timing_basis": "TWILIGHT_combat_and_presentation_profiles",
            "layers": "body_texture_plus_procedural_shadow_and_effects", "common_fallback_supported": texture["loaded"],
            "spawn_references": spawn_refs.get(row["name"], []), "live_instances_observed": None,
            "manifest_binding": row["manifest_binding"]}
    for category, rows in (("items", runtime["catalog"]["아이템"]), ("legacy_items", runtime["legacy_items"])):
        for index, row in enumerate(rows):
            identity = str(row["sourceId"]) if row["sourceId"] else "local:" + row["name"]
            key = "item:" + identity
            if key in entities[category]:
                raise ValueError(f"Duplicate runtime item identity: {category}/{key}")
            source = audit.asset(row["icon"]["path"])
            entities[category][key] = {"name": row["name"], "runtime_row": index,
                **audit.status(source, row["icon"]["loaded"]), "source_status": row["icon"]["selection"],
                "declared_image": audit.asset(row["image_path"]), "source_url": row["sourceUrl"],
                "rendered_icon_sha256": row["icon"].get("rgba_sha256"),
                "resolver_identity_evidence": row.get("resolver_description", {}),
                "ground_icon": {"source": audit.asset(row.get("ground_icon", {}).get("path", "")),
                    "loaded": row.get("ground_icon", {}).get("loaded"),
                    "rendered_sha256": row.get("ground_icon", {}).get("rgba_sha256"),
                    "resolver_identity_evidence": row.get("ground_resolver_description", {})} if "ground_icon" in row else None,
                "link_status": "exact_source_id" if row["sourceId"] else "local_name_identity",
                "runtime_mapping": "renewal_theme.item_icon", "motion_status": "static_icon",
                "common_fallback_supported": row["icon"]["loaded"], "manifest_binding": row["manifest_binding"]}
    effects = read(Path(root) / "data/skills/vfx.json")
    for row in runtime["effects"]:
        preset = effects.get(row["id"], {})
        source = audit.asset("res://scripts/skills/skill_vfx.gd")
        entities["effects"]["effect:" + row["id"]] = {"name": row["name"], **audit.status(source, bool(preset)),
            "source_status": "TWILIGHT_procedural_canvas_effect", "icon": audit.asset(row["icon"]),
            "link_status": "exact_skill_id_preset" if preset else "generic_effect_fallback", "runtime_mapping": row["id"],
            "motion_status": "procedural_shared_motif", "dedicated_original_motion_verified": False,
            "timing_basis": preset.get("animation_timeline", {}), "layers": "procedural_cast_projectile_impact_persistent_audio",
            "directions_authored": None, "unique_source_frames": None,
            "motif": preset.get("motif"), "gameplay_runtime_effect": row["runtime_effect"]}
    categories = {}
    for kind, records in entities.items():
        categories[kind] = {"registered": len(records), "runtime_load_pass": sum(row["runtime_load_tested"] for row in records.values()),
            "runtime_visually_tested": sum(row["runtime_visually_tested"] for row in records.values()),
            "source_missing": sum(not row["source"]["exists"] for row in records.values()),
            "dedicated_original_motion_verified": sum(row.get("dedicated_original_motion_verified", False) for row in records.values())}
        if kind in ("monsters", "bosses"):
            categories[kind]["spawn_referenced"] = sum(bool(row["spawn_references"]) for row in records.values())
    registered_names = {row["name"] for kind in ("monsters", "bosses") for row in entities[kind].values()}
    issue_ids = {kind: [key for key, row in records.items() if not row["source"]["exists"] or not row["runtime_load_tested"]
                       or not all(row.get("layer_runtime_loads", {}).values())
                       or (row.get("ground_icon") is not None and (not row["ground_icon"]["loaded"] or not row["ground_icon"]["source"]["exists"]))
                       or (kind == "effects" and not row["icon"]["exists"])] for kind, records in entities.items()}
    result = {"schema": 1, "verified_date": "2026-10-13", "engine": runtime["engine"],
        "authority": "This section of resource_delivery_ledger.json is the single current-ID status ledger.",
        "evidence_scope": "Read-only runtime registry and texture-load probe; pixel hashes; no per-ID visual playtest or original delivery proof.",
        "definitions": {"registered": "After world._load_data, including local merged records; monsters and bosses partition the expanded runtime registry.",
            "spawn_referenced": "Unique registered monster names present in effective map spawn definitions after MonsterCatalog.apply_map.",
            "spawn_capacity": "Configured region max_count sum; not simultaneously live actors and not a per-species count.",
            "unique_rgba_frames": "Exact visible pixel diversity; duplicates excluded. Changes caused by translation, scale or deformation are not proof of articulated animation.",
            "unique_alpha_cropped_frames": "Exact diversity after removing transparent margins; pure translation does not increase it.",
            "directions_declared": "Manifest layout count, not independently verified original viewpoints.",
            "runtime_load_pass": "Godot resource load, map definition parse, or skill preset registration; does not assert full effect execution or visual quality.",
            "delivery": "Repository file presence only; original_* legacy ledger statuses remain authoritative and not_delivered."},
        "summary": {"categories": categories, "raw_db": {key: len(value) for key, value in raw_db.items()},
            "raw_catalog": {key: len(value) for key, value in raw_catalog.items()},
            "manifest_catalog_entries": len(motions), "manifest_declared_cells": sum(t["cells"] for m in motions.values() for t in m.get("tracks", {}).values()),
            "spawn_capacity": sum(row["spawn_capacity"] for row in entities["maps"].values()),
            "spawn_referenced_unique_names": len(spawn_refs), "unknown_spawn_names": sorted(set(spawn_refs) - registered_names),
            "source_map_registry_entries": len(runtime.get("source_maps", [])),
            "item_icon_selections": dict(sorted(Counter(row["source_status"] for row in entities["items"].values()).items())),
            "item_duplicate_path_groups": len(duplicate_groups(entities["items"], "path")),
            "item_duplicate_sha256_groups": len(duplicate_groups(entities["items"], "sha256")),
            "item_duplicate_rendered_pixel_groups": len(duplicate_groups(entities["items"], "rendered_icon_sha256")),
            "live_instances_observed": None, "issue_ids": issue_ids},
        "entities": entities, "motions": motions,
        "item_icon_duplicates": {"same_path": duplicate_groups(entities["items"], "path"), "same_bytes": duplicate_groups(entities["items"], "sha256"),
            "same_rendered_pixels": duplicate_groups(entities["items"], "rendered_icon_sha256")},
        "inputs": {}, "references": reference_evidence(references) if references else (previous or {}).get("references", {})}
    # Hash all runtime code/data dependencies, not incidental build cache or reports.
    inputs = [p for top in ("scripts", "addons", "data", "scenes") for p in (Path(root) / top).rglob("*")
              if p.is_file() and p.suffix in (".json", ".gd", ".gdshader", ".tscn") and str(p.relative_to(root)) != LEDGER]
    inputs.extend(Path(root) / p for p in ("project.godot", "Main.tscn", "tests/remake_resource_export.gd", "tools/remake_resource_audit.py"))
    result["inputs"] = {str(p.relative_to(root)): digest(p) for p in sorted(inputs)}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--runtime-export", type=Path)
    source.add_argument("--godot", type=Path)
    parser.add_argument("--reference-dir", type=Path)
    parser.add_argument("--check", action="store_true", help="Fail if regenerated current-ID evidence differs from the ledger")
    args = parser.parse_args()
    root = args.root.resolve()
    ledger = read(root / LEDGER)
    preserved = {key: value for key, value in ledger.items() if key != "current_id_audit"}
    if args.godot:
        with tempfile.TemporaryDirectory(prefix="twilight-resource-audit-") as temp:
            output = Path(temp) / "runtime.json"
            env = os.environ | {"TWILIGHT_RESOURCE_EXPORT": str(output), "XDG_DATA_HOME": temp, "XDG_CACHE_HOME": temp}
            process = subprocess.run([str(args.godot.resolve()), "--headless", "--path", str(root), "--script", "res://tests/remake_resource_export.gd"], env=env, capture_output=True, text=True)
            log = process.stdout + process.stderr
            if process.returncode or "SCRIPT ERROR" in log or "ERROR:" in log or "REMAKE_RESOURCE_EXPORT_OK" not in log:
                raise SystemExit("RESOURCE_EXPORT_FAILED:\n" + log[-12000:])
            print(log.strip())
            runtime = read(output)
    else:
        runtime = read(args.runtime_export)
    result = build(root, runtime, args.reference_dir, ledger.get("current_id_audit"))
    if args.check:
        if ledger.get("current_id_audit") != result:
            raise SystemExit("RESOURCE_AUDIT_STALE: regenerate the current-ID ledger")
    else:
        ledger["current_id_audit"] = result
        assert all(ledger[key] == value for key, value in preserved.items())
        write_ledger(root / LEDGER, ledger)
    print(json.dumps(result["summary"], ensure_ascii=False, indent=2))
    failures = sum(len(ids) for ids in result["summary"]["issue_ids"].values()) + len(result["summary"]["unknown_spawn_names"])
    if failures:
        raise SystemExit(f"RESOURCE_AUDIT_RECORDED_GAPS: {failures}")
    print("REMAKE_RESOURCE_AUDIT_OK (registry/load evidence only; originals remain not_delivered)")


if __name__ == "__main__":
    main()
