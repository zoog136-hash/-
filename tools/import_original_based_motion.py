#!/usr/bin/env python3
"""Import reviewed articulated poses without rewriting source image pixels.

The generated sheet is copied byte-for-byte. Connected-component analysis only
finds AtlasTexture rectangles; it never generates, mirrors or duplicates poses.
Only complete, explicitly partitioned role sheets with separated bodies and a
visual review are accepted. Original reference hashes are checked again.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import build_animation_expansion as expansion

DIRECTIONS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
ROLES = {"idle": [0, 1], "walk": [2, 3, 4], "attack": [5, 6, 7], "hit": [8, 9], "death": [10, 11, 12]}
SECONDS = {"idle": 1.2, "walk": .48, "attack": .42, "hit": .22, "death": .65}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def candidate_image(root, value):
    if value.startswith("res://"):
        if not value.startswith("res://assets/") or ".." in Path(value).parts:
            raise ValueError("Unsafe candidate resource path")
        return root / value.removeprefix("res://")
    path = Path(value)
    return path if path.is_absolute() else root / path


def sharing_identity(target):
    """Ignore only fallback ornament data that production does not render.

    MonsterArt.material_for returns no shader for external_l1j portraits, and
    MonsterVisual omits fallback weapons/crests for these existing family
    bindings. Their exact reference, body category, height, attack style and
    animation profile must still agree. Project atlas artwork stays strict.
    """
    presentation = json.loads(json.dumps(target["presentation_to_preserve"]))
    reference = target["reference"]
    if (target["group"] == "normal_monster" and reference["kind"] == "existing_family_portrait"
            and reference["path"].startswith("res://assets/external_l1j/monsters/")):
        visual = presentation.get("visual", {})
        presentation["visual"] = {key: value for key, value in visual.items()
                                  if key not in {"atlas", "cell", "variant", "width", "weapon", "crest", "accent"}}
    return reference, presentation


def analyze(path, rows_count=13, reference_rows=None, reference_height=None):
    """Reject wrong pose counts, clipping, overlaps, and repeated stills."""
    with Image.open(path) as source:
        if source.mode != "RGBA":
            raise ValueError("The generated sheet must have a real alpha channel")
        pixels = np.asarray(source)
        alpha = pixels[:, :, 3]
        if any(np.any(edge > 100) for edge in (alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1])):
            raise ValueError("A visible pose touches the image boundary")
        labels, _ = ndimage.label(alpha > 100)
        areas = np.bincount(labels.ravel())
        boxes = ndimage.find_objects(labels)
        bodies = []
        for index, area in enumerate(areas[1:]):
            if area < 200:
                continue
            y, x = boxes[index]
            bodies.append({"label": index + 1, "box": [x.start, y.start, x.stop, y.stop], "area": int(area)})
        expected = rows_count * 8
        if len(bodies) != expected:
            raise ValueError(f"Expected exactly {expected} separated poses, found {len(bodies)}; review/re-author, never invent slots")
        # Row top, rather than center, is stable for long weapons and collapse
        # poses. Within each eight-body row, retain the reviewed compass order.
        bodies.sort(key=lambda item: item["box"][1])
        rows = [sorted(bodies[start:start + 8], key=lambda item: item["box"][0]) for start in range(0, expected, 8)]
        neutral_rows = reference_rows if reference_rows is not None else [0, 1]
        neutral_height = float(np.median([item["box"][3] - item["box"][1] for index in neutral_rows for item in rows[index]]))
        # Preserve each sheet's actual pixels. Different source resolutions use
        # proportional virtual canvases; the runtime normalizes that canvas.
        canvas = max(64, round(256 * neutral_height / reference_height / 8) * 8) if reference_height else 256
        foot_x, foot_y = canvas // 2, canvas * 5 // 8
        column_anchors = [round(float(np.median([(rows[row][direction]["box"][0] + rows[row][direction]["box"][2]) / 2 for row in neutral_rows]))) for direction in range(8)] if reference_rows is not None else [round(source.width / 8 * (direction + .5)) for direction in range(8)]
        all_hashes = set()
        frames = []
        for row_index, row in enumerate(rows):
            for direction, item in enumerate(row):
                x1, y1, x2, y2 = item["box"]
                center_x = (x1 + x2) / 2
                if abs(center_x / source.width * 8 - (direction + .5)) > .55:
                    raise ValueError("Pose crossed into a neighbouring direction column")
                x1, y1 = max(0, x1 - 3), max(0, y1 - 3)
                x2, y2 = min(source.width, x2 + 3), min(source.height, y2 + 3)
                foreign = set(np.unique(labels[y1:y2, x1:x2])) - {0, item["label"]}
                if any(areas[value] >= 200 for value in foreign):
                    raise ValueError("A pose rectangle includes another body; cannot safely crop")
                width, height = x2 - x1, y2 - y1
                anchor_x = column_anchors[direction]
                anchor_y = item["box"][3] - 1
                margin_x, margin_y = foot_x - (anchor_x - x1), foot_y - (anchor_y - y1)
                if min(margin_x, margin_y) < 0 or margin_x + width > canvas or margin_y + height > canvas:
                    raise ValueError("Pose cannot fit the foot-anchored canvas")
                crop = pixels[y1:y2, x1:x2]
                fingerprint = hashlib.sha256(crop.tobytes()).hexdigest()
                if fingerprint in all_hashes:
                    raise ValueError("A repeated still was used as a different motion pose")
                all_hashes.add(fingerprint)
                frames.append({"row": row_index, "direction": DIRECTIONS[direction],
                               "region": [x1, y1, width, height],
                               "margin": [margin_x, margin_y, canvas - width, canvas - height],
                               "source_anchor": [anchor_x, anchor_y], "rgba_sha256": fingerprint})
        return {"image_size": list(source.size), "frames": frames, "distinct_pixel_frames": len(all_hashes),
                "neutral_height": neutral_height, "canvas_size": [canvas, canvas], "foot": [foot_x, foot_y]}


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
    if len(paths) > 1:
        text.append('metadata/twilight_canvas_size = Vector2(256, 256)\n')
    return '\n'.join(text)


def import_sheet(root, candidate, actor, keys, apply):
    plan = expansion.read(root / "data/animation_authoring_sources.json")
    targets = {row["key"]: row for row in plan["targets"]}
    bindings = [targets[key] for key in keys]
    first = bindings[0]
    identity = sharing_identity(first)
    if any(sharing_identity(row) != identity for row in bindings):
        raise ValueError("Cannot share an authored sheet across different original images/presentations")
    reference = first["reference"]
    original = root / reference["path"].removeprefix("res://")
    if sha(original) != reference["sha256"]:
        raise ValueError("Original reference bytes changed")
    review = candidate.get("review", {})
    for key in ("identity_preserved", "eight_views", "motion_roles", "no_clipping"):
        if review.get(key) is not True:
            raise ValueError("Missing explicit visual review: " + key)
    if not review.get("notes"):
        raise ValueError("Record what was visually reviewed")
    sheets = candidate.get("sheets", [{"output_path": candidate.get("output_path"), "rows": 13, "roles": ROLES}])
    parsed = []
    role_frames = {}
    geometry = {"frames": []}
    for index, spec in enumerate(sheets):
        source = candidate_image(root, spec["output_path"])
        part = analyze(source, spec["rows"], spec.get("reference_rows"), parsed[0]["neutral_height"] if parsed else None)
        offset = len(geometry["frames"])
        if len(sheets) > 1:
            for frame in part["frames"]: frame["sheet"] = index
        for role, rows in spec["roles"].items():
            if role in role_frames or role not in ROLES or len(rows) < 2 or any(row < 0 or row >= spec["rows"] for row in rows):
                raise ValueError("Invalid/duplicate authored role specification: " + role)
            role_frames[role] = [[offset + row * 8 + direction for row in rows] for direction in range(8)]
        geometry["frames"].extend(part["frames"])
        parsed.append(part)
    if set(role_frames) != set(ROLES):
        raise ValueError("Each mandatory role must have actual frames")
    geometry["distinct_pixel_frames"] = len({frame["rgba_sha256"] for frame in geometry["frames"]})
    if geometry["distinct_pixel_frames"] != len(geometry["frames"]):
        raise ValueError("Duplicate pose across source sheets")
    if not actor or any(char not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for char in actor):
        raise ValueError("Use a bounded ASCII actor folder name")
    folder = root / "assets/actors/eight_direction/original_based" / actor
    folder.mkdir(parents=True, exist_ok=True)
    atlases = []
    for index, spec in enumerate(sheets):
        source = candidate_image(root, spec["output_path"])
        sheet = folder / ("poses.png" if len(sheets) == 1 else f"poses-{index}.png")
        if sheet.exists() and sha(sheet) != sha(source):
            raise ValueError("Existing authored sheet differs; use a new reviewed version, do not overwrite")
        if source.resolve() != sheet.resolve():
            shutil.copyfile(source, sheet)
        atlases.append({"path": "res://" + str(sheet.relative_to(root)), "sha256": sha(sheet), "size": parsed[index]["image_size"],
                        "canvas_size": parsed[index]["canvas_size"], "foot": parsed[index]["foot"]})
    (folder / "SpriteFrames.tres").write_text(spriteframes([atlas["path"] for atlas in atlases], geometry, role_frames))
    proof = {"schema": 1, "source": "Newly authored from the existing target image; not recovered original animation",
             "reference": reference, "target_keys": keys, "presentation_to_preserve": first["presentation_to_preserve"],
             "target_presentations": {row["key"]: row["presentation_to_preserve"] for row in bindings},
             "sharing_rule": "Exact original reference and rendered presentation. Existing external portrait family aliases omit only unused fallback ornaments; project atlases remain strict.",
             "authoring_instructions": candidate["prompt"], "instruction_record_kind": candidate.get("prompt_record_kind", "exact_prompt"), "visual_review": review,
             "directions": DIRECTIONS, "source_directions": DIRECTIONS, "source_direction_indices": list(range(8)),
             "cell": [256, 256], "foot": [128, 160], "packing": "Original generated sheet bytes, alpha-bounded AtlasTexture regions and canvas margins",
             "distinct_pixel_frames": geometry["distinct_pixel_frames"], "frames": geometry["frames"], "tracks": {}}
    for role, directions in role_frames.items():
        count = len(directions[0])
        sheet_index = geometry["frames"][directions[0][0]].get("sheet", 0)
        proof["tracks"][role] = {"atlas_files": [atlases[sheet_index]], "source_rows": sheets[sheet_index]["roles"][role], "source_frames_per_direction": count,
                                  "unique_frames_per_direction": count, "direction_unique_frames": dict.fromkeys(DIRECTIONS, count),
                                  "source_duration_seconds": SECONDS[role], "loop_type": "loop" if role in ("idle", "walk") else "play_once"}
    expansion.save(folder / "provenance.json", proof)
    if apply:
        document = expansion.read(root / "data/combat_animation_profiles.json")
        for key in keys:
            profile = document["profiles"].get(key, {}).copy()
            if "prior_visual_profile" not in profile:
                profile["prior_visual_profile"] = profile.copy() or None
            height = float(first["presentation_to_preserve"].get("visual_height", 100))
            source_height = parsed[0]["neutral_height"]
            scale = round(height / source_height, 6)
            profile.update({"name": targets[key]["name"], "frames_path": "res://" + str((folder / "SpriteFrames.tres").relative_to(root)),
                            "layout": "directional8", "pixel_scale": scale, "color_tint": "ffffff", "sprite_offset": [0, round(-32 * scale, 6)],
                            "embedded_shadow": False, "authored_motion_weight": 0, "hit_recoil": 0,
                            "action_hit_frames": {"attack": 1}, "attack_hit_frame": 1, "death_duration": SECONDS["death"],
                            "movement_fps": len(ROLES["walk"]) / SECONDS["walk"], "authoring_reference": reference["path"]})
            document["profiles"][key] = profile
        expansion.save_profiles(root / "data/combat_animation_profiles.json", document)
    if sha(original) != reference["sha256"] or any(sha(candidate_image(root, spec["output_path"])) != atlas["sha256"] for spec, atlas in zip(sheets, atlases)):
        raise AssertionError("Byte preservation failed")
    return {"resource": str(folder), "identities": keys, "poses": geometry["distinct_pixel_frames"], "original_unchanged": True, "applied": apply}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--analyze", type=Path)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--actor")
    parser.add_argument("--key", action="append")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.analyze:
        result = analyze(args.analyze)
        print(json.dumps({key: result[key] for key in ("image_size", "distinct_pixel_frames")}))
    else:
        if not args.candidate or not args.actor or not args.key:
            parser.error("--candidate, --actor and --key are required")
        print(json.dumps(import_sheet(args.root.resolve(), expansion.read(args.candidate), args.actor, args.key, args.apply), ensure_ascii=False))


if __name__ == "__main__":
    main()
