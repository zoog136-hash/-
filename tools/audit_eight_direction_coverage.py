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

from PIL import Image, ImageChops, ImageDraw

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


def _audit_mixed_direction_canvases(proof, actual_frames, animations, images, resource_text):
    """Independently verify optional direction scales against real resources.

    Uniform and legacy checks remain separate. No importer geometry or helpers
    are reused here: the declared direction map must explain every frame's
    actual Godot canvas, foot, source anchor and mandatory animation slot.
    """
    if proof.get("input_representation") != "mixed_sources_v1":
        if "source_files" in proof or "source_poses" in proof:
            raise ValueError("Mixed source metadata requires mixed_sources_v1 representation")
        return
    assignments = re.findall(r"^\s*metadata/twilight_canvas_size\s*=\s*(.*?)\s*$", resource_text, re.M)
    roots = re.findall(r"^\[resource\]\s*$", resource_text, re.M)
    root_text = resource_text.split("[resource]", 1)[-1]
    root_assignments = re.findall(r"^\s*metadata/twilight_canvas_size\s*=\s*(.*?)\s*$", root_text, re.M)
    if len(roots) != 1 or len(assignments) != 1 or assignments != root_assignments:
        raise ValueError("Mixed resource requires exactly one runtime normalization metadata assignment")
    match = re.fullmatch(r"Vector2\(([^)]+)\)", assignments[0])
    values = [value.strip() for value in match[1].split(",")] if match else []
    if len(values) != 2 or any(float(value) != 256 for value in values):
        raise ValueError("Mixed runtime normalization metadata must be Vector2(256, 256)")
    seen_rectangles = set()
    for resource_id, block in re.findall(
            r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', resource_text, re.S):
        if resource_id in seen_rectangles:
            raise ValueError("Repeated actual mixed AtlasTexture ID")
        seen_rectangles.add(resource_id)
        for field in ("region", "margin"):
            entries = re.findall(r"^\s*" + field + r"\s*=\s*(.*?)\s*$", block, re.M)
            match = re.fullmatch(r"Rect2\(([^)]+)\)", entries[0]) if len(entries) == 1 else None
            coordinates = [value.strip() for value in match[1].split(",")] if match else []
            if len(coordinates) != 4 or any(not float(value).is_integer() for value in coordinates):
                raise ValueError("Actual mixed Rect2 coordinates must be integer-valued")
            if tuple(int(float(value)) for value in coordinates) != actual_frames[resource_id][field]:
                raise ValueError("Raw mixed AtlasTexture coordinates differ")
    if seen_rectangles != set(actual_frames):
        raise ValueError("Actual mixed AtlasTexture rectangles are incomplete")
    sources, frames = proof.get("source_files", []), proof.get("frames", [])
    if not isinstance(sources, list) or not isinstance(frames, list):
        raise ValueError("Invalid mixed directional source/frame metadata")
    if any(not isinstance(frame, dict) for frame in frames):
        raise ValueError("Invalid mixed directional frame metadata")
    def integers(value, length):
        return isinstance(value, list) and len(value) == length and all(type(item) is int for item in value)

    counts = proof.get("phase_counts", {})
    minima = dict(idle=2, walk=3, attack=3, hit=2, death=3)
    if (not isinstance(counts, dict) or set(counts) != set(minima)
            or any(type(counts[role]) is not int or counts[role] < minimum for role, minimum in minima.items())):
        raise ValueError("Invalid directional mixed mandatory phase counts")
    expected = sum(counts.values()) * len(DIRECTIONS)
    records = proof.get("source_poses", [])
    if (expected not in (104, 112) or len(frames) != expected or len(records) != expected
            or set(actual_frames) != {"pose_%d" % index for index in range(expected)}):
        raise ValueError("Directional mixed resource must retain every mandatory pose")
    maps, source_usage, covered, slots = {}, Counter(), {}, set()
    for index, source in enumerate(sources):
        if not isinstance(source, dict):
            raise ValueError("Invalid directional source record")
        if "canvas_sizes_by_direction" not in source:
            if "feet_by_direction" in source or "canvas_size_basis" in source:
                raise ValueError("Undeclared directional canvas metadata")
            size = source.get("canvas_size")
            if (not integers(size, 2) or size[0] != size[1] or not 64 <= size[0] <= 2048
                    or not integers(source.get("foot"), 2)
                    or source["foot"] != [size[0] // 2, size[0] * 5 // 8]):
                raise ValueError("Invalid declared uniform mixed canvas/foot")
            continue
        directions, sizes = source.get("directions"), source["canvas_sizes_by_direction"]
        if (source.get("source_kind") != "whole_sheet" or not isinstance(directions, list) or not directions
                or directions != [direction for direction in DIRECTIONS if direction in directions]
                or not isinstance(sizes, dict) or set(sizes) != set(directions)
                or any(type(size) is not int or not 64 <= size <= 2048 for size in sizes.values())):
            raise ValueError("Invalid exact directional canvas map")
        largest = max(sizes.values())
        feet = {direction: [size // 2, size * 5 // 8] for direction, size in sizes.items()}
        if (not integers(source.get("canvas_size"), 2) or source["canvas_size"] != [largest, largest]
                or not integers(source.get("foot"), 2) or source["foot"] != [largest // 2, largest * 5 // 8]
                or source.get("feet_by_direction") != feet
                or any(not integers(value, 2) for value in source.get("feet_by_direction", {}).values())
                or source.get("source_direction_indices") != [DIRECTIONS.index(direction) for direction in directions]
                or source.get("canvas_size_basis") != "max_direction_analysis_only"):
            raise ValueError("Directional source canvas/foot summary differs")
        maps[index] = sizes
    by_path = {source["path"]: source for source in sources}
    for track in proof.get("tracks", {}).values():
        for atlas in track.get("atlas_files", []):
            source = by_path.get(atlas.get("path"), {})
            for field in ("canvas_sizes_by_direction", "feet_by_direction", "canvas_size_basis"):
                if atlas.get(field) != source.get(field):
                    raise ValueError("Track and whole-source directional metadata differ")
    for index, (frame, record) in enumerate(zip(frames, records)):
        source_index = frame.get("sheet")
        if type(source_index) is not int or not 0 <= source_index < len(sources):
            raise ValueError("Invalid directional frame source index")
        source = sources[source_index]
        direction, role, phase = frame.get("direction"), frame.get("role"), frame.get("phase")
        if (direction not in DIRECTIONS or role not in counts or type(phase) is not int
                or not 0 <= phase < counts[role] or (role, direction, phase) in slots):
            raise ValueError("Invalid or repeated directional mandatory slot")
        slots.add((role, direction, phase))
        track = animations.get("%s_%d" % (role, DIRECTIONS.index(direction)), {}).get("frames", [])
        if len(track) != counts[role] or track[phase].get("texture") != "pose_%d" % index:
            raise ValueError("Directional mandatory track/source order differs")
        actual = actual_frames["pose_%d" % index]
        if (not integers(frame.get("region"), 4) or not integers(frame.get("margin"), 4)
                or list(actual["region"]) != frame["region"] or list(actual["margin"]) != frame["margin"]
                or actual["path"] != source.get("path")):
            raise ValueError("Directional provenance and actual AtlasTexture differ")
        if (not isinstance(record, dict) or record.get("id") != frame.get("pose_id")
                or record.get("source_id") != source.get("source_id")
                or type(record.get("source_frame")) is not int
                or record.get("source_frame") != source_usage[source_index]
                or any(record.get(key) != frame.get(key) for key in ("role", "direction", "phase", "source_anchor"))
                or record.get("file") != source.get("path") or record.get("source_sha256") != source.get("sha256")):
            raise ValueError("Directional source-pose/frame linkage differs")
        source_usage[source_index] += 1
        if source_index not in maps:
            if "canvas_size" in frame or "foot" in frame:
                raise ValueError("Undeclared per-frame canvas/foot in mixed source")
            size = source["canvas_size"][0]
        else:
            if direction not in maps[source_index]:
                raise ValueError("Frame direction absent from declared canvas map")
            size = maps[source_index][direction]
        foot = [size // 2, size * 5 // 8]
        if source_index in maps and (not integers(frame.get("canvas_size"), 2)
                                    or frame["canvas_size"] != [size, size]
                                    or not integers(frame.get("foot"), 2) or frame["foot"] != foot):
            raise ValueError("Per-frame directional canvas/foot differs from declared map")
        if (type(record.get("canvas_size")) is not int or record["canvas_size"] != size
                or not integers(frame.get("source_anchor"), 2)):
            raise ValueError("Mixed source-pose canvas/anchor differs from declaration")
        x, y, width, height = frame["region"]
        anchor_x, anchor_y = frame["source_anchor"]
        margin_x, margin_y = foot[0] - (anchor_x - x), foot[1] - (anchor_y - y)
        if (not x <= anchor_x < x + width or not y <= anchor_y < y + height
                or min(margin_x, margin_y) < 0 or margin_x + width > size or margin_y + height > size
                or frame["margin"] != [margin_x, margin_y, size - width, size - height]):
            raise ValueError("Directional frame escapes its declared foot-anchored canvas")
        coverage = covered.setdefault(source_index, Image.new("L", images[source["path"]].size))
        ImageDraw.Draw(coverage).rectangle((x, y, x + width - 1, y + height - 1), fill=255)
    for index, source in enumerate(sources):
        if (source_usage[index] != source.get("analyzed_body_count")
                or source_usage[index] != source.get("mandatory_usage_count")
                or source.get("entire_png_complete") is not True
                or source.get("every_analyzed_body_used_once") is not True):
            raise ValueError("Directional whole-PNG body usage differs")
        visible = images[source["path"]].getchannel("A").point(lambda alpha: 255 if alpha > 100 else 0)
        if ImageChops.subtract(visible, covered[index]).getbbox() is not None:
            raise ValueError("Directional whole PNG contains unassigned visible pixels")



def _git_blob_sha1(raw: bytes) -> str:
    """Git's tracked blob identity, NOT an invented historical source SHA-256."""
    return hashlib.sha1(b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw).hexdigest()


def audit_published_boss_snapshot(root, path, tracked, proof, external, frames, animations):
    """Validate the exact current PNG/AtlasTexture snapshot without claiming
    original artist/source provenance or a complete eight-direction death set.

    These six published boss scenes have 'run' motion and one death direction.
    They are not equivalent to the fully sourced, all-direction animation packs.
    Do not silently promote them to 'native_connected' in the full coverage audit.
    """
    result = {"path": path, "tracks": {}, "errors": [], "tracked": True,
              "verification_scope": "published_boss_runtime_snapshot_v1",
              "compass_semantics": "not_independently_verified",
              "actual_gameplay": "not_run",
              "original_authoring_verified": False,
              "full_eight_direction_walk_and_death_verified": False}
    errors = result["errors"]
    try:
        if (proof.get("schema") != 1
                or proof.get("verification_scope") != "published_boss_runtime_snapshot_v1"
                or proof.get("original_authoring_verified") is not False
                or proof.get("direction_semantics_verified") is not False
                or proof.get("full_eight_direction_walk_and_death_verified") is not False):
            raise ValueError("Published boss proof must disclose its unverified original history and partial motion")
        resource_file = local_path(root, path)
        manifest = proof.get("spriteframes", {})
        if (manifest.get("path") != path
                or manifest.get("git_blob_sha1") != _git_blob_sha1(resource_file.read_bytes())):
            raise ValueError("Published boss SpriteFrames changed since pinned Git snapshot")
        declared = proof.get("images")
        if not isinstance(declared, list) or not declared:
            raise ValueError("Published boss images are not individually pinned")
        by_path = {row.get("path"): row for row in declared if isinstance(row, dict)}
        if (len(by_path) != len(declared)
                or set(by_path) != set(external.values())):
            raise ValueError("Published boss source image set differs from SpriteFrames")
        needed = {f"{role}_{direction}" for role in ("idle", "run", "attack", "hit")
                  for direction in range(8)}
        # The sole published death_2 animation is not eight-direction death.
        if set(animations) != needed | {"death_2"}:
            raise ValueError("Published boss runtime role/direction coverage changed")
        recorded_tracks = proof.get("tracks")
        actual_tracks = {name: {"frames": len(track["frames"]), "loop": track["loop"]}
                         for name, track in animations.items()}
        if recorded_tracks != actual_tracks:
            raise ValueError("Published boss animation tracks or loop policy differ from receipt")
        result["source"] = proof.get("source", "")
        if not isinstance(result["source"], str) or "NOT" not in result["source"]:
            raise ValueError("Published boss provenance must disclose unknown historical sources")
        pinned_files = {path, "res://" + str(resource_file.with_name("provenance.json").relative_to(root)),
                        *external.values()}
        missing = sorted(p for p in pinned_files if p.removeprefix("res://") not in tracked)
        if missing:
            result["tracked"] = False
            raise ValueError("Untracked boss snapshot source: " + ", ".join(missing))
        usage = {p: [] for p in by_path}
        distinct = {name: set() for name in animations}
        for name, track in animations.items():
            if not isinstance(track["loop"], bool) or len(track["frames"]) < 2:
                raise ValueError("Malformed published animation track: " + name)
            for frame in track["frames"]:
                atlas_spec = frames.get(frame.get("texture"))
                if not atlas_spec or atlas_spec["path"] not in usage:
                    raise ValueError("Missing AtlasTexture frame referenced by " + name)
                usage[atlas_spec["path"]].append((name, atlas_spec))
        if any(not frames_for_png for frames_for_png in usage.values()):
            raise ValueError("Published texture has no live AtlasTexture usage")
        for image_path in sorted(by_path):
            entry = by_path[image_path]
            file_path = local_path(root, image_path)
            raw = file_path.read_bytes()
            if (entry.get("git_blob_sha1") != _git_blob_sha1(raw)
                    or entry.get("bytes") != len(raw)):
                raise ValueError("Published boss PNG changed since pinned Git snapshot: " + image_path)
            with Image.open(file_path) as source_image:
                source_image.load()
                rgba = source_image.convert("RGBA")
                for name, spec in usage[image_path]:
                    x, y, width, height = spec["region"]
                    if (width <= 0 or height <= 0 or x < 0 or y < 0
                            or x + width > rgba.width or y + height > rgba.height):
                        raise ValueError("Invalid published AtlasTexture bounds: " + name)
                    crop = rgba.crop((x, y, x + width, y + height))
                    if crop.getchannel("A").getbbox() is None:
                        raise ValueError("Published animation references empty PNG pixels: " + name)
                    distinct[name].add(hashlib.sha256(crop.tobytes()).hexdigest())
                rgba.close()
        for name, track in animations.items():
            result["tracks"][name] = {"frames": len(track["frames"]),
                                      "distinct_rgba": len(distinct[name]),
                                      "loop": track["loop"]}
        result["pinned_png_count"] = len(by_path)
    except (OSError, ValueError, KeyError, IndexError, TypeError, AttributeError) as exc:
        errors.append(str(exc))
    result["pixel_integrity"] = "failed" if errors else "tracked_published_partial"
    return result


def audit_resource(root, path, tracked):
    result = {"path": path, "tracks": {}, "errors": [], "tracked": True,
              "compass_semantics": "source_metadata_only", "actual_gameplay": "not_run"}
    try:
        resource_path = local_path(root, path)
        proof_path = resource_path.with_name("provenance.json")
        proof = load(proof_path)
        external, frames, animations = read_spriteframes(resource_path)
        if proof.get("verification_scope") == "published_boss_runtime_snapshot_v1":
            return audit_published_boss_snapshot(root, path, tracked, proof, external, frames, animations)
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
        _audit_mixed_direction_canvases(proof, frames, animations, images, resource_path.read_text())
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
        if native and resource.get("pixel_integrity") == "tracked_published_partial":
            reason = ("Current published boss PNG and SpriteFrames pinned to Git; "
                      "historical source and eight-direction walk/death proof absent")
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
        if report.get("setup", {}).get("synthetic_fixture", False):
            raise ValueError("Synthetic fixture execution cannot prove original-art gameplay: " + str(path))
        reference = Path(os.path.relpath(path.resolve(), output_dir.resolve())).as_posix()
        matched = set()
        for kind in ("player", "monster", "boss"):
            for case in report.get(kind, []):
                key = case.get("form", "") if kind == "player" else "monster:" + case.get("name", "")
                compass = case.get("compass", "")
                if compass not in DIRECTIONS or case.get("facing") != DIRECTIONS.index(compass):
                    raise ValueError("Recorded facing differs from compass: " + str(path))
                if kind == "player":
                    exercised = case.get("attack_visible") is True and case.get("hit_count", 0) > 0 and case.get("hp_after", 0) < case.get("hp_before", 0)
                elif kind == "monster":
                    exercised = case.get("walk") is True and case.get("attack") is True and case.get("contacts", 0) > 0
                else:
                    resolved = case.get("contacts", 0) > 0
                    if case.get("kind") == "summon":
                        # Production summons actors and deliberately deals no
                        # direct area damage. Require actual spawn evidence;
                        # a warning/effect or pose sample alone is insufficient.
                        spawned = case.get("summoned")
                        resolved = case.get("contacts") == 0 and type(spawned) is int and spawned > 0
                    exercised = case.get("warning") is True and case.get("effect") is True and resolved
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
