#!/usr/bin/env python3
"""Preserve one real legendary draft PNG and compile its six-pose track.

Usage: python3 preserve_generated_clip.py REQUEST_JSON GENERATED_PNG
Writes only legendary_parallel/transform_<id>/draft001; never overwrites.
The source image bytes remain exact. This is a draft, not visual approval.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
DIRECTIONS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
ROLES = {"idle": [0, 1], "walk": [2, 3, 4], "attack": [5, 6, 7], "hit": [8, 9], "death": [10, 11, 12]}
SECONDS = {"idle": 1.2, "walk": .48, "run": .48, "attack": .42, "hit": .22, "death": .65, "cast": .42}
COMPILER_ORIGIN = {
    "repository": "zoog136-hash/-",
    "commit": "16bb178426134dbc5ffcc32306de0a2509352c8f",
    "path": "tools/import_original_based_motion.py",
    "source_file_sha256": "8e44eb850d27125e8704926925ffb00d241a591b2a7f149bb6d16b69acc647e2",
    "function": "spriteframes",
    "function_source_sha256": "90c168656ec82b680e96f7bea822dd11161085fe75233366f459b9cab2c1451c",
    "reuse": "Exact function source copied. A single selected animation is retained; run loops explicitly.",
}


def spriteframes(sheet_path, geometry, role_frames=None):
    paths = [sheet_path] if isinstance(sheet_path, str) else sheet_path
    text = [f'[gd_resource type="SpriteFrames" load_steps={len(geometry["frames"])+len(paths)+1} format=3]']
    for index, path in enumerate(paths):
        text.extend(['', f'[ext_resource type="Texture2D" path="{path}" id="{index+1}"]'])
    for index, frame in enumerate(geometry["frames"]):
        text.extend(['', f'[sub_resource type="AtlasTexture" id="pose_{index}"]',
                     'atlas = ExtResource("%d")' % (frame.get("sheet", 0) + 1),
                     'region = Rect2(%s)' % ', '.join(map(str, frame["region"])),
                     'margin = Rect2(%s)' % ', '.join(map(str, frame["margin"])),
                     'filter_clip = true'])
    animations = []
    if role_frames is None:
        role_frames = {role: [[row * 8 + direction for row in rows] for direction in range(8)] for role, rows in ROLES.items()}
    for role, directions in role_frames.items():
        for direction in range(8):
            indices = directions[direction]
            frames = ',\n'.join('{"duration": 1.0, "texture": SubResource("pose_%d")}' % index for index in indices)
            animations.append('{"frames": [%s], "loop": %s, "name": &"%s_%d", "speed": %.9f}' %
                              (frames, str(role in ("idle", "walk")).lower(), role, direction, len(indices) / SECONDS[role]))
    text.extend(['', '[resource]', 'animations = [\n' + ',\n'.join(animations) + '\n]', ''])
    # A single reviewed sheet may also use a larger virtual canvas. The
    # runtime must normalize it to the same 256-pixel world foot convention.
    # Keep existing one-sheet 256-pixel resources byte-for-byte unchanged.
    needs_canvas_normalization = any(frame["region"][2] + frame["margin"][2] != 256
                                     or frame["region"][3] + frame["margin"][3] != 256
                                     for frame in geometry["frames"])
    if len(paths) > 1 or needs_canvas_normalization:
        text.append('metadata/twilight_canvas_size = Vector2(256, 256)\n')
    return '\n'.join(text)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def local_reference(value):
    path = Path(value.removeprefix("res://"))
    if not path.is_absolute():
        path = ROOT / path
    assert path.is_file() and not path.is_symlink(), "Reference PNG missing or unsafe"
    assert path.resolve().is_relative_to(ROOT), "Reference must be preserved inside this checkout"
    return path


def preserve(request_path, generated):
    request_path, generated = Path(request_path).resolve(), Path(generated)
    request_raw = request_path.read_bytes()
    q = json.loads(request_raw)
    assert isinstance(q, dict)
    assert re.fullmatch(r"transform:[0-9]+", q["key"]), "Use a real catalog transform ID"
    actor_id = q["key"].split(":")[1]
    role, direction = q["role"], q["direction"]
    assert role in ("attack", "run", "death", "hit", "idle"), "No new WALK production"
    assert direction in DIRECTIONS
    assert role != "death" or direction == "S", "New DEATH sources are S only"
    catalog = json.loads((ROOT / "data/catalog_v19.json").read_text())
    actors = [a for a in catalog["변신"] if str(a["sourceId"]) == actor_id]
    assert len(actors) == 1 and actors[0]["grade"] == q["grade"] == "전설"
    assert actors[0]["name"] == q["name"], "Request name differs from original catalog ID"
    reference = local_reference(q["reference"])
    assert digest(reference.read_bytes()) == q["reference_sha256"], "Original reference SHA changed"
    assert isinstance(q["generation_request"], dict)
    assert generated.is_file() and not generated.is_symlink(), "Generated PNG missing or unsafe"
    raw = generated.read_bytes()
    assert raw.startswith(b"\x89PNG\r\n\x1a\n"), "Output must be an actual PNG"
    with Image.open(generated) as source:
        assert source.format == "PNG" and source.mode == "RGBA", "A real RGBA PNG is required"
        source.load()
        assert source.width % 3 == 0 and source.height % 2 == 0, "Six equal cells must fit a 3x2 sheet"
        width, height = source.width // 3, source.height // 2
        assert width > 0 and height > 0
        geometry, checks = {"frames": []}, []
        for phase in range(6):
            x, y = phase % 3 * width, phase // 3 * height
            region = [x, y, width, height]
            rgba = np.asarray(source.crop((x, y, x + width, y + height)))
            alpha = rgba[:, :, 3]
            ys, xs = np.nonzero(alpha > 0)
            assert len(xs), f"Frame {phase} is blank"
            bounds = [int(xs.min()), int(ys.min()), int(xs.max() + 1), int(ys.max() + 1)]
            visible = rgba[bounds[1]:bounds[3], bounds[0]:bounds[2]].copy()
            visible[visible[:, :, 3] == 0] = 0
            shape = f"{visible.shape[1]}x{visible.shape[0]}:".encode("ascii")
            border = np.zeros(alpha.shape, dtype=bool)
            border[:2] = True
            border[-2:] = True
            border[:, :2] = True
            border[:, -2:] = True
            checks.append({"index": phase, "region": region,
                           "rgba_sha256": digest(rgba.tobytes()),
                           "normalized_visible_sha256": digest(shape + visible.tobytes()),
                           "visible_pixels": int((alpha > 16).sum()),
                           "alpha_bbox_in_cell": bounds,
                           "border_alpha_pixels": int(((alpha > 16) & border).sum())})
            geometry["frames"].append({"region": region, "margin": [0, 0, 0, 0]})
    assert all(c["visible_pixels"] > 0 for c in checks), "A cell has no visible character pixels"
    assert len({c["rgba_sha256"] for c in checks}) == 6, "Six distinct RGBA frames required"
    assert len({c["normalized_visible_sha256"] for c in checks}) == 6, "A shifted duplicate still is not a new pose"
    folder = ROOT / "assets/actors/eight_direction/legendary_parallel" / f"transform_{actor_id}" / "draft001"
    source_path = folder / f"{direction}-{role}-source-v01.png"
    resource_path = folder / f"{direction}-{role}-SpriteFrames.tres"
    record_path = folder / f"{direction}-{role}-record-v01.json"
    for path in (folder, *folder.parents):
        assert not path.is_symlink(), "Unsafe output directory"
        if path == ROOT:
            break
    assert not any(p.exists() or p.is_symlink() for p in (source_path, resource_path, record_path)), "Output exists; preserve it, never redo/overwrite"
    resource_uri = "res://" + resource_path.relative_to(ROOT).as_posix()
    source_uri = "res://" + source_path.relative_to(ROOT).as_posix()
    direction_index = DIRECTIONS.index(direction)
    role_indices = [[] for _ in DIRECTIONS]
    role_indices[direction_index] = list(range(6))
    compiled = spriteframes(source_uri, geometry, {role: role_indices})
    pattern = r'\{"frames": \[[\s\S]*?\], "loop": (?:true|false), "name": &"' + re.escape(role) + r'_(\d)", "speed": [^}]*\}'
    entries = list(re.finditer(pattern, compiled))
    assert len(entries) == 8
    selected = next(m.group(0) for m in entries if int(m.group(1)) == direction_index)
    assert selected.count('SubResource("pose_') == 6
    if role == "run":
        selected = selected.replace('"loop": false', '"loop": true')
    prefix = compiled.split("animations = [", 1)[0]
    resource = prefix + "animations = [\n" + selected + "\n]\n"
    resource += ('metadata/twilight_canvas_size = Vector2(256, 256)\n'
                 'metadata/twilight_detailed_completed = false\n'
                 'metadata/twilight_source_visual_status = "HOLD_NOT_REVIEWED"\n'
                 f'metadata/twilight_actor_key = "{q["key"]}"\n')
    resource_raw = resource.encode("utf-8")
    request_canonical = json.dumps(q["generation_request"], ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    record = dict(q)
    record.update(schema="pr122-legendary-generated-clip-v1", status="GENERATED_DRAFT_NOT_REVIEWED",
                  source=source_path.relative_to(ROOT).as_posix(), source_resource_path=source_uri,
                  source_sha256=digest(raw), source_bytes=len(raw),
                  output_spriteframes=resource_uri, output_spriteframes_sha256=digest(resource_raw),
                  generated_original_path=str(generated.resolve()), request_file=str(request_path),
                  request_file_sha256=digest(request_raw), generation_request_sha256=digest(request_canonical),
                  generation_service="image_gen.imagegen", poses=6, cell_size=[width, height],
                  frame_order=list(range(6)), animation=f"{role}_{direction_index}",
                  loop=role in ("idle", "run"), automatic_checks=checks,
                  clipped_cell_count=sum(c["border_alpha_pixels"] > 0 for c in checks),
                  compiler_origin=COMPILER_ORIGIN,
                  minimal_checks={"actual_png_exists": "PASS", "six_cells_extractable": "PASS",
                                  "catalog_id_name_grade_match": "PASS", "original_reference_sha256": "PASS",
                                  "six_distinct_rgba_and_visible_frames": "PASS",
                                  "SpriteFrames_actual_Godot_playback": "NOT_RUN"},
                  source_visual_status="HOLD_NOT_REVIEWED", geometry_review="NOT_RUN",
                  hold_reasons=["Full source identity, footing, camera, articulation and clipping review pending"] +
                               (["Visible alpha reaches cell edge"] if any(c["border_alpha_pixels"] for c in checks) else []),
                  actual_Main_Player="NOT_RUN", required_Godot_4_7_2_full_QA="NOT_RUN",
                  final_motion_approvals_added=0, actor_approvals_added=0, production_connected=False)
    folder.mkdir(parents=True, exist_ok=True)
    for path, content in ((source_path, raw), (resource_path, resource_raw),
                          (record_path, (json.dumps(record, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))):
        with path.open("xb") as target:
            target.write(content)
    assert source_path.read_bytes() == raw and digest(resource_path.read_bytes()) == record["output_spriteframes_sha256"]
    return {"key": q["key"], "direction": direction, "role": role, "poses": 6,
            "record": record_path.relative_to(ROOT).as_posix(), "source_sha256": digest(raw),
            "resource": resource_uri, "clipped_cells": record["clipped_cell_count"],
            "status": "DRAFT_FINAL_APPROVAL_HOLD", "new_final_approvals": 0}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("request", type=Path)
    parser.add_argument("generated_png", type=Path)
    args = parser.parse_args()
    print(json.dumps(preserve(args.request, args.generated_png), ensure_ascii=False))
