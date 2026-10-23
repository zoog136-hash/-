#!/usr/bin/env python3
"""Compile six actual poses from immutable legacy art plus only missing poses.

This compiler supports two- and three-pose legacy tracks, preserves their
original pixel regions/margins and original pose start times, and writes only
legendary_parallel artifacts. New PNG pixels are never resized or transformed.
Usage: preserve_mixed_legacy_clip.py REQUEST NEW_PNG --existing-root CHECKOUT
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re

import numpy as np
from PIL import Image

import preserve_generated_clip as common

ROOT = Path(__file__).resolve().parents[3]
DIRECTIONS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
ANIMATION_RE = r'\{"frames": \[[\s\S]*?\], "loop": (?:true|false), "name": &"[^"]+", "speed": [^}]*\}'
LEGACY_176 = "res://assets/actors/eight_direction/original_based/spear_captain/SpriteFrames.tres"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def resolve_resource(root, value):
    assert isinstance(value, str) and value.startswith("res://assets/") and ".." not in Path(value).parts
    path = root / value.removeprefix("res://")
    assert path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(root.resolve())
    return path


def read_legacy_track(existing_root, key, role, direction, frames_uri=LEGACY_176):
    """Read exact legacy pose bindings and both nominal and actual durations."""
    existing_root = Path(existing_root).resolve()
    assert direction in DIRECTIONS and role in ("idle", "attack", "hit", "death")
    assert role != "death" or direction == "S", "Existing other death views stay preserved; new death supplementation is S only"
    frames_path = resolve_resource(existing_root, frames_uri)
    provenance_path = frames_path.with_name("provenance.json")
    provenance_raw = provenance_path.read_bytes()
    prov = json.loads(provenance_raw)
    assert key in prov["target_keys"]
    resource_raw = frames_path.read_bytes()
    text = resource_raw.decode("utf-8")
    animation = f"{role}_{DIRECTIONS.index(direction)}"
    entries = re.findall(ANIMATION_RE, text)
    matching = [e for e in entries if f'"name": &"{animation}"' in e]
    assert len(matching) == 1
    entry = matching[0]
    bindings = [(float(duration), int(index)) for duration, index in re.findall(r'\{"duration": ([0-9.eE+-]+), "texture": SubResource\("pose_(\d+)"\)\}', entry)]
    assert len(bindings) in (2, 3), "This partial-reuse compiler requires two or three real legacy poses"
    speed = float(re.search(r'"speed": ([0-9.eE+-]+)', entry).group(1))
    assert speed > 0 and all(duration > 0 for duration, _ in bindings)
    assert ('"loop": true' in entry) == (role == "idle")
    ext = dict(re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text))
    # ext_resource captures are path,id, and IDs can be strings.
    by_id = {identifier: uri for uri, identifier in ext.items()}
    sources, frames, elapsed = {}, [], 0.0
    for ordinal, (duration, index) in enumerate(bindings):
        original = prov["frames"][index]
        assert original["direction"] == direction
        block = re.search(r'\[sub_resource type="AtlasTexture" id="pose_' + str(index) + r'"\]([\s\S]*?)(?=\n\[|\Z)', text).group(1)
        source_id = re.search(r'atlas = ExtResource\("([^"]+)"\)', block).group(1)
        uri = by_id[source_id]
        path = resolve_resource(existing_root, uri)
        raw = path.read_bytes()
        actual_sha = sha(raw)
        expected = [a for a in prov["tracks"][role]["atlas_files"] if a["path"] == uri]
        assert len(expected) == 1 and actual_sha == expected[0]["sha256"]
        sources[uri] = {"original_path": uri, "sha256": actual_sha, "bytes": len(raw), "local_path": str(path)}
        frame = {"ordinal": ordinal, "original_pose_id": index, "source_path": uri,
                 "duration": duration, "start_seconds": elapsed / speed,
                 "rgba_sha256": original["rgba_sha256"], "source_anchor": original.get("source_anchor")}
        for label in ("region", "margin"):
            actual = [int(x.strip()) for x in re.search(label + r' = Rect2\(([^)]+)\)', block).group(1).split(",")]
            assert actual == original[label]
            frame[label] = actual
        with Image.open(path) as image:
            assert image.mode == "RGBA"
            x, y, w, h = frame["region"]
            assert sha(np.asarray(image.crop((x, y, x + w, y + h))).tobytes()) == frame["rgba_sha256"]
        frames.append(frame)
        elapsed += duration
    return {"key": key, "role": role, "direction": direction, "animation": animation,
            "legacy_frames_path": frames_uri, "legacy_frames_sha256": sha(resource_raw),
            "legacy_provenance_sha256": sha(provenance_raw), "reference": prov["reference"],
            "legacy_fps": speed, "legacy_duration_weights": [b[0] for b in bindings],
            "legacy_duration_seconds": elapsed / speed,
            "legacy_nominal_duration_seconds": prov["tracks"][role]["source_duration_seconds"],
            "reused_poses": len(frames), "new_poses": 6 - len(frames),
            "frames": frames, "source_files": list(sources.values())}


def six_pose_config(legacy):
    """Preserve every old frame start time while inserting missing real poses."""
    count = len(legacy["frames"])
    assert count in (2, 3)
    sequence = [("reused", 0), ("new", 0), ("new", 1), ("reused", 1)]
    sequence += [("new", 2), ("reused", 2)] if count == 3 else [("new", 2), ("new", 3)]
    speed = 6.0 / legacy["legacy_duration_seconds"]
    weights = [0.0] * 6
    for ordinal in range(count):
        start = sequence.index(("reused", ordinal))
        stop = sequence.index(("reused", ordinal + 1)) if ordinal + 1 < count else 6
        segment_weight = legacy["frames"][ordinal]["duration"] * speed / legacy["legacy_fps"]
        for phase in range(start, stop):
            weights[phase] = segment_weight / (stop - start)
    elapsed, reused_times = 0.0, []
    for phase, (kind, ordinal) in enumerate(sequence):
        if kind == "reused":
            old_start = legacy["frames"][ordinal]["start_seconds"]
            assert math.isclose(elapsed / speed, old_start, abs_tol=1e-10)
            reused_times.append({"legacy_pose_id": legacy["frames"][ordinal]["original_pose_id"],
                                 "final_phase": phase, "legacy_start_seconds": old_start,
                                 "new_start_seconds": elapsed / speed})
        elapsed += weights[phase]
    assert math.isclose(elapsed / speed, legacy["legacy_duration_seconds"], abs_tol=1e-10)
    return {"sequence": [{"kind": kind, "ordinal": ordinal} for kind, ordinal in sequence],
            "duration_weights": weights, "speed": speed,
            "total_duration_seconds": elapsed / speed, "reused_pose_start_times": reused_times,
            "legacy_pose_start_times_preserved": True, "legacy_total_duration_preserved": True,
            "new_source_grid": [3, 1] if count == 3 else [2, 2]}


def frame_check(image, region, phase, kind):
    x, y, w, h = region
    pixels = np.asarray(image.crop((x, y, x + w, y + h)))
    alpha = pixels[:, :, 3]
    ys, xs = np.nonzero(alpha > 0)
    assert len(xs) and int((alpha > 16).sum()) > 0
    box = [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)]
    visible = pixels[box[1]:box[3], box[0]:box[2]].copy()
    visible[visible[:, :, 3] == 0] = 0
    border = np.zeros(alpha.shape, dtype=bool)
    border[:2] = border[-2:] = True
    border[:, :2] = border[:, -2:] = True
    return {"index": phase, "source_kind": kind, "region": region,
            "rgba_sha256": sha(pixels.tobytes()),
            "normalized_visible_sha256": sha(f"{visible.shape[1]}x{visible.shape[0]}:".encode() + visible.tobytes()),
            "visible_pixels": int((alpha > 16).sum()), "visible_height": box[3] - box[1],
            "visible_width": box[2] - box[0], "alpha_bbox_in_region": box,
            "border_alpha_pixels": int(((alpha > 16) & border).sum())}


def preserve(request_path, generated_png, existing_root):
    request_path, generated_png, existing_root = Path(request_path), Path(generated_png), Path(existing_root)
    request_raw = request_path.read_bytes()
    q = json.loads(request_raw)
    assert re.fullmatch(r"transform:[0-9]+", q["key"])
    actor_id = q["key"].split(":")[1]
    role, direction = q["role"], q["direction"]
    assert role in ("attack", "hit", "idle", "death") and direction in DIRECTIONS
    assert role != "death" or direction == "S"
    catalog = json.loads((ROOT / "data/catalog_v19.json").read_text())
    actors = [a for a in catalog["변신"] if str(a["sourceId"]) == actor_id]
    assert len(actors) == 1 and actors[0]["grade"] == q["grade"] == "전설" and actors[0]["name"] == q["name"]
    reference = common.local_reference(q["reference"])
    assert sha(reference.read_bytes()) == q["reference_sha256"]
    legacy = read_legacy_track(existing_root, q["key"], role, direction, q["legacy_frames_path"])
    assert legacy["reference"]["sha256"] == q["reference_sha256"]
    assert legacy["legacy_frames_sha256"] == q["legacy_frames_sha256"]
    config = six_pose_config(legacy)
    assert config == q["six_pose_config"], "Use the exact saved reuse/timing configuration"
    assert isinstance(q["generation_request"], dict)
    assert generated_png.is_file() and not generated_png.is_symlink()
    new_raw = generated_png.read_bytes()
    assert new_raw.startswith(b"\x89PNG\r\n\x1a\n")
    image = Image.open(generated_png)
    assert image.mode == "RGBA" and image.format == "PNG"
    image.load()
    columns, rows = config["new_source_grid"]
    assert image.width >= columns and image.height >= rows
    integer_grid_rounding = image.width % columns != 0 or image.height % rows != 0
    grid_x = [i * image.width // columns for i in range(columns + 1)]
    grid_y = [i * image.height // rows for i in range(rows + 1)]
    cell_w, cell_h = image.width // columns, image.height // rows
    folder = ROOT / "assets/actors/eight_direction/legendary_parallel" / f"transform_{actor_id}" / "draft001"
    new_path = folder / f"{direction}-{role}-source-v01.png"
    resource_path = folder / f"{direction}-{role}-SpriteFrames.tres"
    record_path = folder / f"{direction}-{role}-record-v01.json"
    for path in (folder, *folder.parents):
        assert not path.is_symlink()
        if path == ROOT:
            break
    assert not any(p.exists() or p.is_symlink() for p in (new_path, resource_path, record_path)), "Already produced; preserve it and skip, never redo"
    source_files, source_raws, source_indices, images = [], [], {}, {}
    for entry in sorted(legacy["source_files"], key=lambda e: e["original_path"]):
        path = folder / f'legacy-source-{entry["sha256"][:16]}.png'
        raw = Path(entry["local_path"]).read_bytes()
        assert sha(raw) == entry["sha256"]
        if path.exists():
            assert not path.is_symlink() and path.read_bytes() == raw
        source_indices[entry["original_path"]] = len(source_files)
        source_files.append({"path": "res://" + path.relative_to(ROOT).as_posix(), "sha256": entry["sha256"],
                             "bytes": len(raw), "source_kind": "reused", "original_path": entry["original_path"]})
        source_raws.append((path, raw))
        images[entry["original_path"]] = Image.open(Path(entry["local_path"]))
    new_sheet = len(source_files)
    source_files.append({"path": "res://" + new_path.relative_to(ROOT).as_posix(), "sha256": sha(new_raw),
                         "bytes": len(new_raw), "source_kind": "new"})
    geometry, checks, sequence = {"frames": []}, [], []
    for phase, slot in enumerate(config["sequence"]):
        kind, ordinal = slot["kind"], slot["ordinal"]
        if kind == "reused":
            old = legacy["frames"][ordinal]
            frame = {"region": old["region"], "margin": old["margin"], "sheet": source_indices[old["source_path"]]}
            check = frame_check(images[old["source_path"]], frame["region"], phase, kind)
            assert check["rgba_sha256"] == old["rgba_sha256"]
            sequence.append({"phase": phase, "source_kind": kind, "original_pose_id": old["original_pose_id"],
                             "original_region": old["region"], "original_margin": old["margin"],
                             "original_source_anchor": old["source_anchor"], "rgba_sha256": old["rgba_sha256"]})
        else:
            column, row = ordinal % columns, ordinal // columns
            region = [grid_x[column], grid_y[row], grid_x[column+1]-grid_x[column], grid_y[row+1]-grid_y[row]]
            frame = {"region": region, "margin": [0, 0, 0, 0], "sheet": new_sheet}
            check = frame_check(image, region, phase, kind)
            sequence.append({"phase": phase, "source_kind": kind, "new_sheet_cell": ordinal,
                             "region": region, "rgba_sha256": check["rgba_sha256"]})
        geometry["frames"].append(frame)
        checks.append(check)
    assert len({c["rgba_sha256"] for c in checks}) == 6 and len({c["normalized_visible_sha256"] for c in checks}) == 6
    indices = [[] for _ in DIRECTIONS]
    indices[DIRECTIONS.index(direction)] = list(range(6))
    compiled = common.spriteframes([f["path"] for f in source_files], geometry, {role: indices})
    anim = f"{role}_{DIRECTIONS.index(direction)}"
    entries = re.findall(ANIMATION_RE, compiled)
    selected = next(e for e in entries if f'"name": &"{anim}"' in e)
    texture_frames = ',\n'.join('{"duration": %.15g, "texture": SubResource("pose_%d")}' % (weight, i)
                               for i, weight in enumerate(config["duration_weights"]))
    selected = '{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.15g}' % (texture_frames, str(role == "idle").lower(), anim, config["speed"])
    resource = compiled.split("animations = [", 1)[0] + "animations = [\n" + selected + "\n]\n"
    resource += ('metadata/twilight_canvas_size = Vector2(256, 256)\n'
                 'metadata/twilight_detailed_completed = false\n'
                 'metadata/twilight_source_visual_status = "HOLD_NOT_REVIEWED"\n'
                 f'metadata/twilight_actor_key = "{q["key"]}"\n')
    resource_raw = resource.encode()
    old_height = float(np.median([c["visible_height"] for c in checks if c["source_kind"] == "reused"]))
    scale_hold = any(abs(c["visible_height"] / old_height - 1.0) > .25 for c in checks if c["source_kind"] == "new")
    record = dict(q)
    record.update(schema="pr122-legendary-generated-clip-v1", input_representation="mixed_legacy_supplement_v1",
                  status="MIXED_REUSED_AND_NEW_DRAFT_NOT_REVIEWED", source=new_path.relative_to(ROOT).as_posix(),
                  source_resource_path=source_files[-1]["path"], source_sha256=sha(new_raw), source_bytes=len(new_raw),
                  source_files=source_files, source_grid=[columns, rows], cell_size=[cell_w, cell_h],
                  partition_edges={"x": grid_x, "y": grid_y}, integer_grid_rounding_hold=integer_grid_rounding,
                  output_spriteframes="res://" + resource_path.relative_to(ROOT).as_posix(), output_spriteframes_sha256=sha(resource_raw),
                  poses=6, new_poses=legacy["new_poses"], newly_authored_poses=legacy["new_poses"], reused_poses=legacy["reused_poses"],
                  frame_order=list(range(6)), source_pose_sequence=sequence, automatic_checks=checks,
                  original_reused_regions_margins_rgba_unchanged=True,
                  legacy_fps=legacy["legacy_fps"], legacy_duration_seconds=legacy["legacy_duration_seconds"],
                  legacy_nominal_duration_seconds=legacy["legacy_nominal_duration_seconds"],
                  legacy_pose_start_times_preserved=True, legacy_total_duration_preserved=True,
                  duration_weights=config["duration_weights"], animation_speed=config["speed"],
                  animation_duration_seconds=config["total_duration_seconds"], reused_pose_start_times=config["reused_pose_start_times"],
                  animation=anim, loop=role == "idle", terminal_frame_hold=role == "death",
                  scale_comparison_hold=scale_hold, legacy_median_body_height=old_height,
                  clipped_cell_count=sum(c["border_alpha_pixels"] > 0 for c in checks), compiler_origin=common.COMPILER_ORIGIN,
                  request_file_sha256=sha(request_raw), generation_service="image_gen.imagegen",
                  generation_request_sha256=sha(json.dumps(q["generation_request"], ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()),
                  hold_reasons=["Mixed-source original appearance, camera, footing and motion continuity require later quality review"] +
                               (["Complete integer source partitions differ by at most one pixel; display registration review pending"] if integer_grid_rounding else []) +
                               (["New-source body scale differs; no PNG resizing performed"] if scale_hold else []) +
                               (["Visible alpha reaches a selected region boundary"] if any(c["border_alpha_pixels"] for c in checks) else []),
                  minimal_checks={"actual_png_exists": "PASS", "six_real_mixed_source_frames_extractable": "PASS",
                                  "reused_source_regions_margins_rgba_exact": "PASS", "legacy_timing_preserved": "PASS",
                                  "catalog_id_name_grade_match": "PASS", "original_reference_sha256": "PASS",
                                  "six_distinct_rgba_and_visible_frames": "PASS", "SpriteFrames_actual_Godot_playback": "NOT_RUN"},
                  source_visual_status="HOLD_NOT_REVIEWED", actual_Main_Player="NOT_RUN", required_Godot_4_7_2_full_QA="NOT_RUN",
                  production_connected=False, actor_approvals_added=0, final_motion_approvals_added=0)
    folder.mkdir(parents=True, exist_ok=True)
    for path, raw in source_raws:
        if not path.exists():
            with path.open("xb") as handle:
                handle.write(raw)
        assert sha(path.read_bytes()) == sha(raw)
    for path, raw in ((new_path, new_raw), (resource_path, resource_raw),
                      (record_path, (json.dumps(record, ensure_ascii=False, indent=2) + "\n").encode())):
        with path.open("xb") as handle:
            handle.write(raw)
    return {"key": q["key"], "direction": direction, "role": role, "poses": 6,
            "newly_authored_poses": legacy["new_poses"], "reused_poses": legacy["reused_poses"],
            "record": record_path.relative_to(ROOT).as_posix(), "legacy_timing_preserved": True,
            "scale_hold": scale_hold, "status": "DRAFT_FINAL_APPROVAL_HOLD", "actor_approvals_added": 0}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("request", type=Path)
    parser.add_argument("generated_png", type=Path)
    parser.add_argument("--existing-root", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(preserve(args.request, args.generated_png, args.existing_root), ensure_ascii=False))
