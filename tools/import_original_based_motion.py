#!/usr/bin/env python3
"""Import reviewed articulated poses without rewriting source image pixels.

The generated sheet is copied byte-for-byte. Connected-component analysis only
finds AtlasTexture rectangles; it never generates, mirrors or duplicates poses.
Only complete, explicitly partitioned role sheets with separated bodies and a
visual review are accepted. Original reference hashes are checked again.
Direction-subset sheets need an explicit canvas_size and scale_review_note;
they are imported only after all five roles cover all eight directions.
"""
import argparse
import hashlib
import json
import os
import shutil
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import build_animation_expansion as expansion

DIRECTIONS = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
ROLES = {"idle": [0, 1], "walk": [2, 3, 4], "attack": [5, 6, 7], "hit": [8, 9], "death": [10, 11, 12]}
SECONDS = {"idle": 1.2, "walk": .48, "attack": .42, "hit": .22, "death": .65, "cast": .42}
# PresentationCatalog.configure prefers these reviewed source bodies to the
# unused fallback atlas body. This is deliberately limited to named records;
# other bodies, references and presentations retain their existing strictness.
REVIEWED_BODY_EQUIVALENCES = (
    {"fallback_bodies": {"monster:하피": "harpy", "monster:블루 하피": "blue_harpy"},
     "path": "res://assets/external_l1j/monsters/1024.png",
     "sha256": "2e77475b545a94ffb9ac39a97eed51957fbb9c666867fc5104c1ec8cb2e7d1dd",
     "rendered_body": "flying", "shared_body": "harpy", "visual_height": 78, "floating": True},
    {"fallback_bodies": {"monster:질투의 좀비 나이트": "dark_knight", "monster:질투의 좀비 메이드": "zombie"},
     "path": "res://assets/external_l1j/monsters/5110.png",
     "sha256": "cec611c763c6b172f8c4e4f5ec8d2c05b451fbd033bdefa4ea171b96ea89ad9f",
     "rendered_body": "undead", "shared_body": "zombie", "visual_height": 86, "floating": False},
)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _visible_pose_fingerprint(crop):
    """Compare rendered pixels only; never change source/provenance bytes.

    Fully transparent RGB and transparent border widths cannot distinguish
    poses. Every nonzero alpha value, including antialiasing, stays exact.
    """
    ys, xs = np.nonzero(crop[:, :, 3] > 0)
    visible = crop[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
    visible[visible[:, :, 3] == 0] = 0
    dimensions = f"{visible.shape[1]}x{visible.shape[0]}:".encode("ascii")
    return hashlib.sha256(dimensions + visible.tobytes()).hexdigest()


def require_preserved_output(path, expected_sha):
    """Preflight every immutable output before creating any import artifact."""
    if path.is_symlink() or (path.exists() and (not path.is_file() or sha(path) != expected_sha)):
        raise ValueError("Existing authored output differs; use a new reviewed version, do not overwrite: " + str(path))


def candidate_image(root, value):
    if value.startswith("res://"):
        if not value.startswith("res://assets/") or ".." in Path(value).parts:
            raise ValueError("Unsafe candidate resource path")
        return root / value.removeprefix("res://")
    path = Path(value)
    return path if path.is_absolute() else root / path


def sharing_identity(target, root=None):
    """Ignore only fallback ornament data that production does not render.

    MonsterArt.material_for returns no shader for external_l1j portraits, and
    MonsterVisual omits fallback weapons/crests for these existing family
    bindings. Byte-identical portrait files may have distinct names/bindings;
    their SHA, dimensions, body, height, attack style and animation profile
    must agree, except the explicitly pinned source-body reviews above.
    Every bound source is independently checked by import_sheet.
    Project atlas artwork (including its selected region) stays strict.
    """
    presentation = json.loads(json.dumps(target["presentation_to_preserve"]))
    reference = target["reference"]
    if (target["group"] == "normal_monster" and reference["kind"] == "existing_family_portrait"
            and reference["path"].startswith("res://assets/external_l1j/monsters/")):
        visual = presentation.get("visual", {})
        presentation["visual"] = {key: value for key, value in visual.items()
                                  if key not in {"atlas", "cell", "variant", "width", "weapon", "crest", "accent"}}
        reference = {key: reference[key] for key in ("kind", "sha256", "image_size")}
    key = target.get("key", "")
    for reviewed in REVIEWED_BODY_EQUIVALENCES:
        if key not in reviewed["fallback_bodies"]:
            continue
        expected = {"visual": {"body": reviewed["fallback_bodies"][key]},
                    "animation_profile": {"motion_style": "slash", "attack_hit_ratio": .44,
                                          "floating": reviewed["floating"]},
                    "attack_type": "melee", "visual_height": reviewed["visual_height"]}
        original = target["reference"]
        if (target["group"] != "normal_monster" or target.get("name") != key.removeprefix("monster:")
                or original.get("kind") != "existing_family_portrait" or original.get("path") != reviewed["path"]
                or original.get("sha256") != reviewed["sha256"] or original.get("image_size") != [82, 123]
                or presentation != expected):
            raise ValueError("Reviewed source presentation changed; explicit re-review required: " + key)
        project = Path(root) if root is not None else Path(__file__).resolve().parents[1]
        try:
            source = expansion.read(project / "data/animation_presentation.json")["monster_sources"][reviewed["path"]]
        except (OSError, ValueError, KeyError, TypeError) as error:
            raise ValueError("Reviewed source presentation cannot be verified: " + key) from error
        if source != {"body": reviewed["rendered_body"], "evidence": "installed_source_contact_review",
                      "sha256": reviewed["sha256"]}:
            raise ValueError("Reviewed source presentation override changed; explicit re-review required: " + key)
        # Comparison only: provenance and target profiles keep their own data.
        presentation["visual"]["body"] = reviewed["shared_body"]
        break
    return reference, presentation


def reviewed_directions(value):
    """Accept only a nonempty, unique subset in the canonical compass order."""
    if (not isinstance(value, list) or not value
            or any(not isinstance(direction, str) or direction not in DIRECTIONS for direction in value)
            or value != [direction for direction in DIRECTIONS if direction in value]):
        raise ValueError("directions must be a nonempty unique subset in canonical E,SE,S,SW,W,NW,N,NE order")
    return value.copy()


def analyze(path, rows_count=13, reference_rows=None, reference_height=None,
            directions_axis="columns", canvas_size=None, source_anchors=None, directions=DIRECTIONS):
    """Return phase-major metadata, rejecting clipped or repeated poses.

    rows_count is the number of logical pose phases. A directions_axis="rows"
    sheet has len(directions) physical rows and rows_count physical columns. A
    directions_axis="blocks4x2" sheet places E/SE/S/SW in a phase's first
    physical row and W/NW/N/NE in its second row, using four columns.
    Partial-direction columns/rows sheets need an explicitly reviewed canvas.
    Pixels stay untouched; only the resulting frame indices are normalized.
    """
    selected = reviewed_directions(directions)
    direction_count = len(selected)
    if directions_axis not in {"columns", "rows", "blocks4x2"}:
        raise ValueError("Unknown direction axis")
    if directions_axis == "blocks4x2" and direction_count != 8:
        raise ValueError("blocks4x2 does not support a direction subset")
    if directions_axis == "blocks4x2" and (type(rows_count) is not int or rows_count < 1):
        raise ValueError("blocks4x2 requires a positive integer number of logical phases")
    if type(rows_count) is not int or rows_count < 1:
        raise ValueError("A sheet requires a positive integer number of logical phases")
    if direction_count != 8 and canvas_size is None:
        raise ValueError("Direction subset sheets require an explicit reviewed canvas_size")
    if canvas_size is not None and (type(canvas_size) is not int or not 64 <= canvas_size <= 2048):
        raise ValueError("Reviewed canvas size must be an integer from 64 to 2048")
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
        expected = rows_count * direction_count
        if len(bodies) != expected:
            raise ValueError(f"Expected exactly {expected} separated poses, found {len(bodies)}; review/re-author, never invent slots")
        # Normalize metadata to phase-major order, without transposing pixels.
        # Some long-weapon atlases put the eight directions in physical rows.
        if directions_axis == "blocks4x2":
            columns = 4
            physical_rows = [[None] * columns for _ in range(rows_count * 2)]
            for item in bodies:
                x1, y1, x2, y2 = item["box"]
                column = int((x1 + x2) / 2 / source.width * columns)
                physical_row = int((y1 + y2) / 2 / source.height * len(physical_rows))
                if physical_rows[physical_row][column] is not None:
                    raise ValueError("Each blocks4x2 cell must contain exactly one separated pose")
                physical_rows[physical_row][column] = item
            if any(item is None for row in physical_rows for item in row):
                raise ValueError("Each blocks4x2 cell must contain exactly one separated pose")
            rows = [physical_rows[phase * 2] + physical_rows[phase * 2 + 1]
                    for phase in range(rows_count)]
        else:
            # Keep the established column/row packing byte-for-byte stable.
            bodies.sort(key=lambda item: item["box"][1])
            columns = rows_count if directions_axis == "rows" else direction_count
            physical_rows = [sorted(bodies[start:start + columns], key=lambda item: item["box"][0])
                             for start in range(0, expected, columns)]
            rows = [[physical_rows[direction][phase] for direction in range(direction_count)]
                    for phase in range(rows_count)] if directions_axis == "rows" else physical_rows
        neutral_rows = reference_rows if reference_rows is not None else [0, 1]
        if (not isinstance(neutral_rows, list) or not neutral_rows
                or any(type(row) is not int or row < 0 or row >= rows_count for row in neutral_rows)):
            raise ValueError("Reviewed reference_rows must select actual logical phases")
        neutral_height = float(np.median([item["box"][3] - item["box"][1] for index in neutral_rows for item in rows[index]]))
        # Preserve each sheet's actual pixels. Different source resolutions use
        # proportional virtual canvases; the runtime normalizes that canvas.
        canvas = max(64, round(256 * neutral_height / reference_height / 8) * 8) if reference_height else 256
        if canvas_size is not None:
            canvas = canvas_size
        foot_x, foot_y = canvas // 2, canvas * 5 // 8
        column_anchors = [round(float(np.median([(rows[row][direction]["box"][0] + rows[row][direction]["box"][2]) / 2 for row in neutral_rows]))) for direction in range(direction_count)] if reference_rows is not None else [round(source.width / direction_count * (direction + .5)) for direction in range(direction_count)]
        if directions_axis == "blocks4x2" and reference_rows is None:
            column_anchors = [round(source.width / columns * (direction % columns + .5))
                              for direction in range(8)]
        if source_anchors is not None and len(source_anchors) != expected:
            raise ValueError("Every reviewed pose must have its own source anchor")
        all_hashes = set()
        visible_hashes = set()
        frames = []
        for row_index, row in enumerate(rows):
            for direction, item in enumerate(row):
                x1, y1, x2, y2 = item["box"]
                center_x = (x1 + x2) / 2
                column = row_index if directions_axis == "rows" else direction
                if directions_axis == "blocks4x2":
                    column %= 4
                if abs(center_x / source.width * columns - (column + .5)) > .55:
                    raise ValueError("Pose crossed into a neighbouring direction column")
                x1, y1 = max(0, x1 - 3), max(0, y1 - 3)
                x2, y2 = min(source.width, x2 + 3), min(source.height, y2 + 3)
                foreign = set(np.unique(labels[y1:y2, x1:x2])) - {0, item["label"]}
                if any(areas[value] >= 200 for value in foreign):
                    raise ValueError("A pose rectangle includes another body; cannot safely crop")
                width, height = x2 - x1, y2 - y1
                anchor_x = (round(source.width / columns * (column + .5))
                            if directions_axis == "rows" else column_anchors[direction])
                anchor_y = item["box"][3] - 1
                if source_anchors is not None:
                    anchor = source_anchors[row_index * direction_count + direction]
                    if (not isinstance(anchor, list) or len(anchor) != 2
                            or any(not isinstance(value, int) for value in anchor)
                            or not x1 <= anchor[0] < x2 or not y1 <= anchor[1] < y2):
                        raise ValueError("Reviewed source anchor must lie inside its pose")
                    anchor_x, anchor_y = anchor
                margin_x, margin_y = foot_x - (anchor_x - x1), foot_y - (anchor_y - y1)
                if min(margin_x, margin_y) < 0 or margin_x + width > canvas or margin_y + height > canvas:
                    raise ValueError("Pose cannot fit the foot-anchored canvas")
                crop = pixels[y1:y2, x1:x2]
                fingerprint = hashlib.sha256(crop.tobytes()).hexdigest()
                if fingerprint in all_hashes:
                    raise ValueError("A repeated still was used as a different motion pose")
                all_hashes.add(fingerprint)
                visible_fingerprint = _visible_pose_fingerprint(crop)
                if visible_fingerprint in visible_hashes:
                    raise ValueError("A repeated visible pose was disguised by transparent pixels")
                visible_hashes.add(visible_fingerprint)
                frames.append({"row": row_index, "direction": selected[direction],
                               "region": [x1, y1, width, height],
                               "margin": [margin_x, margin_y, canvas - width, canvas - height],
                               "source_anchor": [anchor_x, anchor_y], "rgba_sha256": fingerprint})
        return {"image_size": list(source.size), "frames": frames, "distinct_pixel_frames": len(all_hashes),
                "neutral_height": neutral_height, "canvas_size": [canvas, canvas], "foot": [foot_x, foot_y]}


def require_complete_pose_regions(path, geometry):
    """Reject a new import that would silently drop any visible source piece."""
    with Image.open(path) as source:
        visible = np.asarray(source.getchannel("A")) > 100
    covered = np.zeros(visible.shape, dtype=bool)
    for frame in geometry["frames"]:
        x, y, width, height = frame["region"]
        covered[y:y + height, x:x + width] = True
    omitted = int(np.count_nonzero(visible & ~covered))
    if omitted:
        raise ValueError(f"{path}: {omitted} visible pixels outside pose regions; review/re-author, never discard or guess ownership")


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


def reviewed_action_aliases(candidate):
    """A reviewed spell gesture may serve both normal attack and magic casting.

    This creates a runtime track name, never new pixels or counted poses. The
    mandatory motions remain independently authored and cannot be aliased away.
    """
    aliases = candidate.get("action_aliases", {})
    if not isinstance(aliases, dict) or (aliases and aliases != {"cast": "attack"}):
        raise ValueError("Only an explicit cast-to-attack action alias is supported")
    if aliases and candidate.get("review", {}).get("cast_uses_authored_attack") is not True:
        raise ValueError("Review that the authored attack is also the actual spell gesture")
    return aliases.copy()


def import_sheet(root, candidate, actor, keys, apply):
    # Optional representation only. Keep the established sheet parser,
    # per-sheet temporal guard and serialized legacy outputs unchanged.
    if candidate.get("input_mode") == "pose_files_v1":
        return import_pose_files(root, candidate, actor, keys, apply)
    if candidate.get("input_mode") == "mixed_sources_v1":
        return import_mixed_sources(root, candidate, actor, keys, apply)
    if candidate.get("input_mode") is not None:
        raise ValueError("Unknown input_mode")
    plan = expansion.read(root / "data/animation_authoring_sources.json")
    targets = {row["key"]: row for row in plan["targets"]}
    bindings = [targets[key] for key in keys]
    first = bindings[0]
    identity = sharing_identity(first, root=root)
    if any(sharing_identity(row, root=root) != identity for row in bindings):
        raise ValueError("Cannot share an authored sheet across different original images/presentations")
    reference = first["reference"]
    originals = [(root / row["reference"]["path"].removeprefix("res://"), row["reference"]["sha256"])
                 for row in bindings]
    for original, expected_sha in originals:
        if sha(original) != expected_sha:
            raise ValueError("Original reference bytes changed: " + str(original))
    review = candidate.get("review", {})
    for key in ("identity_preserved", "eight_views", "motion_roles", "no_clipping"):
        if review.get(key) is not True:
            raise ValueError("Missing explicit visual review: " + key)
    if not review.get("notes"):
        raise ValueError("Record what was visually reviewed")
    aliases = reviewed_action_aliases(candidate)
    sheets = candidate.get("sheets", [{"output_path": candidate.get("output_path"), "rows": 13, "roles": ROLES}])
    parsed = []
    sheet_directions = []
    role_frames = {}
    role_sources = {}
    geometry = {"frames": []}
    visible_hashes = []
    for index, spec in enumerate(sheets):
        selected = reviewed_directions(spec.get("directions", DIRECTIONS))
        if len(selected) != 8:
            if spec.get("directions_axis", "columns") == "blocks4x2":
                raise ValueError("blocks4x2 does not support a direction subset")
            if spec.get("canvas_size") is None:
                raise ValueError("Direction subset sheets require an explicit reviewed canvas_size")
            if (not isinstance(spec.get("scale_review_note"), str)
                    or not spec["scale_review_note"].strip()):
                raise ValueError("Direction subset sheets require a nonempty scale_review_note")
        source = candidate_image(root, spec["output_path"])
        reference_height = parsed[0]["neutral_height"] * 256 / parsed[0]["canvas_size"][1] if parsed else None
        part = analyze(source, spec["rows"], spec.get("reference_rows"), reference_height,
                       spec.get("directions_axis", "columns"), spec.get("canvas_size"), spec.get("source_anchors"), selected)
        # Validate every candidate before creating any output directory/file.
        # Existing tracked sheets remain untouched; reimports require review.
        require_complete_pose_regions(source, part)
        # Keep this check private: raw rgba_sha256 and all serialized legacy
        # geometry remain unchanged. Aliases reuse indices, never new poses.
        with Image.open(source) as image:
            pixels = np.asarray(image)
            for frame in part["frames"]:
                x, y, width, height = frame["region"]
                fingerprint = _visible_pose_fingerprint(pixels[y:y + height, x:x + width])
                visible_hashes.append(fingerprint)
        offset = len(geometry["frames"])
        if len(sheets) > 1:
            for frame in part["frames"]: frame["sheet"] = index
        if not isinstance(spec["roles"], dict) or not spec["roles"]:
            raise ValueError("Each sheet must declare actual authored roles")
        for role, rows in spec["roles"].items():
            if (role not in ROLES or not isinstance(rows, list) or len(rows) < 2
                    or any(type(row) is not int or row < 0 or row >= spec["rows"] for row in rows)
                    or len(set(rows)) != len(rows)):
                raise ValueError("Invalid/duplicate authored role specification: " + str(role))
            groups = role_frames.setdefault(role, [None] * 8)
            sources = role_sources.setdefault(role, [None] * 8)
            prior_count = next((len(group) for group in groups if group is not None), len(rows))
            if prior_count != len(rows):
                raise ValueError("Inconsistent phase count for authored role: " + role)
            for local_direction, direction in enumerate(selected):
                direction_index = DIRECTIONS.index(direction)
                if groups[direction_index] is not None:
                    raise ValueError("Duplicate authored role direction: " + role + "/" + direction)
                groups[direction_index] = [offset + row * len(selected) + local_direction for row in rows]
                sources[direction_index] = {"sheet": index, "rows": rows.copy()}
        geometry["frames"].extend(part["frames"])
        parsed.append(part)
        sheet_directions.append(selected)
    for role in ROLES:
        if role not in role_frames or any(group is None for group in role_frames[role]):
            raise ValueError("Each mandatory role must have actual frames in all eight directions: " + role)
    used_frames = set()
    for role in ROLES:
        for indices in role_frames[role]:
            for frame in indices:
                if frame in used_frames:
                    raise ValueError("Duplicate pose reused across mandatory authored roles")
                used_frames.add(frame)
    for alias, source_role in aliases.items():
        role_frames[alias] = [indices.copy() for indices in role_frames[source_role]]
        role_sources[alias] = role_sources[source_role]
    height_basis = candidate.get("display_height_basis", "median_idle")
    if height_basis not in {"median_idle", "max_living_frame"}:
        raise ValueError("Unknown reviewed display-height basis")
    display_reference_height = parsed[0]["neutral_height"] * 256 / parsed[0]["canvas_size"][1]
    if height_basis == "max_living_frame":
        # Long quadrupeds project a much taller silhouette in N/S than E/W.
        # Fit all living poses into the existing visible-height budget while
        # keeping one uniform scale across directions, roles and source sheets.
        living = {frame for role, directions in role_frames.items() if role != "death"
                  for direction in directions for frame in direction}
        display_reference_height = max(
            geometry["frames"][index]["region"][3] * 256
            / parsed[geometry["frames"][index].get("sheet", 0)]["canvas_size"][1]
            for index in living)
    geometry["distinct_pixel_frames"] = len({frame["rgba_sha256"] for frame in geometry["frames"]})
    if geometry["distinct_pixel_frames"] != len(geometry["frames"]):
        raise ValueError("Duplicate pose across source sheets")
    if len(set(visible_hashes)) != len(visible_hashes):
        raise ValueError("Duplicate visible pose across source sheets")
    if not actor or any(char not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for char in actor):
        raise ValueError("Use a bounded ASCII actor folder name")
    folder = root / "assets/actors/eight_direction/original_based" / actor
    # Prepare all bytes and profile changes first. A later sheet conflict,
    # invalid proof or invalid runtime catalog must leave no partial import.
    atlases = []
    copies = []
    for index, spec in enumerate(sheets):
        source = candidate_image(root, spec["output_path"])
        sheet = folder / ("poses.png" if len(sheets) == 1 else f"poses-{index}.png")
        source_sha = sha(source)
        copies.append((source, sheet, source_sha))
        atlases.append({"path": "res://" + str(sheet.relative_to(root)), "sha256": source_sha, "size": parsed[index]["image_size"],
                        "canvas_size": parsed[index]["canvas_size"], "foot": parsed[index]["foot"]})
        if spec.get("directions_axis", "columns") != "columns":
            atlases[-1]["directions_axis"] = spec["directions_axis"]
        if sheet_directions[index] != DIRECTIONS:
            atlases[-1]["directions"] = sheet_directions[index]
            atlases[-1]["source_direction_indices"] = [DIRECTIONS.index(direction) for direction in sheet_directions[index]]
            atlases[-1]["scale_review_note"] = spec["scale_review_note"]
        if spec.get("source_anchors") is not None:
            atlases[-1]["source_anchor_kind"] = "reviewed per-pose foot anchors recorded in frames"
    resource = spriteframes([atlas["path"] for atlas in atlases], geometry, role_frames)
    proof = {"schema": 1, "source": "Newly authored from the existing target image; not recovered original animation",
             "reference": reference, "target_keys": keys, "presentation_to_preserve": first["presentation_to_preserve"],
             "target_references": {row["key"]: row["reference"] for row in bindings},
             "target_presentations": {row["key"]: row["presentation_to_preserve"] for row in bindings},
             "sharing_rule": "Exact original bytes/dimensions and rendered presentation. Each external portrait path is independently hash-checked; only unused fallback ornaments and byte-identical file/binding names may differ. Project atlas references remain strict.",
             "authoring_instructions": candidate["prompt"], "instruction_record_kind": candidate.get("prompt_record_kind", "exact_prompt"), "visual_review": review,
             "directions": DIRECTIONS, "source_directions": DIRECTIONS, "source_direction_indices": list(range(8)),
             "cell": [256, 256], "foot": [128, 160], "packing": "Original generated sheet bytes, alpha-bounded AtlasTexture regions and canvas margins",
             "distinct_pixel_frames": geometry["distinct_pixel_frames"], "frames": geometry["frames"], "tracks": {}}
    proof["display_height_basis"] = height_basis
    proof["display_reference_height"] = display_reference_height
    if aliases:
        proof["action_aliases"] = aliases
    for role, directions in role_frames.items():
        count = len(directions[0])
        sources = role_sources[role]
        contributing = sorted({source["sheet"] for source in sources})
        track = {"atlas_files": [atlases[index] for index in contributing]}
        if len(contributing) == 1:
            # Preserve field order and bytes for every established full-eight sheet.
            track["source_rows"] = sources[0]["rows"]
        else:
            track["source_rows_by_direction"] = {
                direction: {"atlas_path": atlases[source["sheet"]]["path"], "source_rows": source["rows"]}
                for direction, source in zip(DIRECTIONS, sources)}
        track.update({"source_frames_per_direction": count,
                      "unique_frames_per_direction": count, "direction_unique_frames": dict.fromkeys(DIRECTIONS, count),
                      "source_duration_seconds": SECONDS[role], "loop_type": "loop" if role in ("idle", "walk") else "play_once"})
        proof["tracks"][role] = track
        if role in aliases:
            proof["tracks"][role]["alias_of"] = aliases[role]
    metadata = [(folder / "SpriteFrames.tres", resource),
                (folder / "provenance.json", json.dumps(proof, ensure_ascii=False, indent=2) + "\n")]
    profiles_changed = False
    if apply:
        document = expansion.read(root / "data/combat_animation_profiles.json")
        if not isinstance(document, dict) or not isinstance(document.get("profiles"), dict):
            raise ValueError("Runtime animation profiles must contain a profiles object")
        prior_document = json.dumps(document, ensure_ascii=False)
        for key in keys:
            previous = document["profiles"].get(key, {})
            if not isinstance(previous, dict):
                raise ValueError("Runtime animation profile must be an object: " + key)
            profile = previous.copy()
            if "prior_visual_profile" not in profile:
                profile["prior_visual_profile"] = profile.copy() or None
            height = float(first["presentation_to_preserve"].get("visual_height", 100))
            source_height = display_reference_height
            scale = round(height / source_height, 6)
            profile.update({"name": targets[key]["name"], "frames_path": "res://" + str((folder / "SpriteFrames.tres").relative_to(root)),
                            "layout": "directional8", "pixel_scale": scale, "color_tint": "ffffff", "sprite_offset": [0, round(-32 * scale, 6)],
                            "embedded_shadow": False, "authored_motion_weight": 0, "hit_recoil": 0,
                            "action_hit_frames": {"attack": 1, **{alias: 1 for alias in aliases}}, "attack_hit_frame": 1, "death_duration": SECONDS["death"],
                            "movement_fps": len(role_frames["walk"][0]) / SECONDS["walk"], "authoring_reference": targets[key]["reference"]["path"]})
            previous_frames = str(previous.get("frames_path", ""))
            # Coverage recognizes native packs across this whole directory,
            # including the existing expanded/flare sequential animations.
            # Preserve every declared native eight-direction profile without
            # requiring a fresh full pixel audit for each import attempt.
            native_profile = (previous_frames.startswith("res://assets/actors/eight_direction/")
                              and previous_frames.endswith("/SpriteFrames.tres")
                              and previous.get("layout") in {"sequential8", "directional8"})
            if ((native_profile or previous_frames.startswith("res://assets/actors/eight_direction/original_based/"))
                    and previous != profile):
                raise ValueError("Existing authored runtime profile differs; explicit re-review required: " + key)
            document["profiles"][key] = profile
        profiles_changed = json.dumps(document, ensure_ascii=False) != prior_document
    for parent in (folder, *folder.parents):
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise ValueError("Authored output directory is not a regular directory: " + str(parent))
        if parent == root:
            break
    for _, sheet, source_sha in copies:
        require_preserved_output(sheet, source_sha)
    for path, content in metadata:
        require_preserved_output(path, hashlib.sha256(content.encode()).hexdigest())
    # All input, output and profile checks passed. Identical reruns need no
    # asset writes and preserve the reviewed SpriteFrames/provenance bytes.
    folder.mkdir(parents=True, exist_ok=True)
    for source, sheet, _ in copies:
        if not sheet.exists():
            shutil.copyfile(source, sheet)
    for path, content in metadata:
        if not path.exists():
            path.write_text(content)
    if apply and profiles_changed:
        expansion.save_profiles(root / "data/combat_animation_profiles.json", document)
    if any(sha(original) != expected_sha for original, expected_sha in originals) or any(sha(candidate_image(root, spec["output_path"])) != atlas["sha256"] for spec, atlas in zip(sheets, atlases)):
        raise AssertionError("Byte preservation failed")
    return {"resource": str(folder), "identities": keys, "poses": geometry["distinct_pixel_frames"], "original_unchanged": True, "applied": apply}


def _pose_file_source(root, value):
    """A whole standalone PNG, never a selected region in a multipose PNG."""
    if not isinstance(value, str) or not value or ".." in Path(value).parts:
        raise ValueError("Unsafe pose file path")
    path = candidate_image(root, value)
    if path.suffix.lower() != ".png" or not path.is_file():
        raise ValueError("Pose source must be an existing PNG file: " + str(path))
    if any(part.is_symlink() for part in (path, *path.parents)):
        raise ValueError("Pose source and its parents must not be symlinks: " + str(path))
    return path


def _pose_file_profiles(root, targets, keys, first, folder, reference_height, walk_count, aliases):
    """Prepare, but never write, the same production profile convention."""
    path = root / "data/combat_animation_profiles.json"
    if path.is_symlink():
        raise ValueError("Runtime profile catalog must not be a symlink")
    document = expansion.read(path)
    if not isinstance(document, dict) or not isinstance(document.get("profiles"), dict):
        raise ValueError("Runtime animation profiles must contain a profiles object")
    prior = json.dumps(document, ensure_ascii=False)
    for key in keys:
        previous = document["profiles"].get(key, {})
        if not isinstance(previous, dict):
            raise ValueError("Runtime animation profile must be an object: " + key)
        profile = previous.copy()
        if "prior_visual_profile" not in profile:
            profile["prior_visual_profile"] = profile.copy() or None
        scale = round(float(first["presentation_to_preserve"].get("visual_height", 100)) / reference_height, 6)
        profile.update({"name": targets[key]["name"],
                        "frames_path": "res://" + str((folder / "SpriteFrames.tres").relative_to(root)),
                        "layout": "directional8", "pixel_scale": scale, "color_tint": "ffffff",
                        "sprite_offset": [0, round(-32 * scale, 6)], "embedded_shadow": False,
                        "authored_motion_weight": 0, "hit_recoil": 0,
                        "action_hit_frames": {"attack": 1, **{alias: 1 for alias in aliases}},
                        "attack_hit_frame": 1, "death_duration": SECONDS["death"],
                        "movement_fps": walk_count / SECONDS["walk"],
                        "authoring_reference": targets[key]["reference"]["path"]})
        previous_frames = str(previous.get("frames_path", ""))
        native = (previous_frames.startswith("res://assets/actors/eight_direction/")
                  and previous_frames.endswith("/SpriteFrames.tres")
                  and previous.get("layout") in {"sequential8", "directional8"})
        if ((native or previous_frames.startswith("res://assets/actors/eight_direction/original_based/"))
                and previous != profile):
            raise ValueError("Existing authored runtime profile differs; explicit re-review required: " + key)
        document["profiles"][key] = profile
    return path, document, json.dumps(document, ensure_ascii=False) != prior, sha(path)


def _prepare_pose_files(root, candidate, actor, keys, apply):
    """Read-only complete preflight. No directories, cache or files are created.

    Temporal minima belong to the entire candidate in this representation.
    Every source is nevertheless checked as one complete whole-PNG body by the
    unchanged analyzer and complete-region guard, not a region-selection escape.
    """
    root = Path(root).resolve()
    allowed = {"input_mode", "texture_binding", "key", "prompt", "prompt_record_kind", "review",
               "phase_counts", "expected_distinct_poses", "poses", "display_height_basis",
               "action_aliases", "source_claim", "status", "actual_Main", "completed_added"}
    if not isinstance(candidate, dict) or candidate.get("input_mode") != "pose_files_v1":
        raise ValueError("Read-only pose-file validation requires input_mode=pose_files_v1")
    if set(candidate) - allowed or candidate.get("texture_binding") != "individual_png_metadata":
        raise ValueError("pose_files_v1 accepts only individual_png_metadata and explicit pose-file fields")
    if (not isinstance(actor, str) or not 1 <= len(actor) <= 80
            or any(char not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for char in actor)):
        raise ValueError("Use a bounded ASCII actor folder name")
    if (not isinstance(keys, list) or not keys or any(not isinstance(key, str) for key in keys)
            or len(set(keys)) != len(keys)):
        raise ValueError("Supply nonempty unique target keys")
    if candidate.get("key", keys[0]) != keys[0]:
        raise ValueError("Candidate key must match the primary target key")
    if not isinstance(candidate.get("prompt"), str) or not candidate["prompt"].strip():
        raise ValueError("Record the exact authoring prompt/instructions")
    review = candidate.get("review", {})
    if not isinstance(review, dict):
        raise ValueError("Record explicit visual review")
    for flag in ("identity_preserved", "eight_views", "motion_roles", "no_clipping"):
        if review.get(flag) is not True:
            raise ValueError("Missing explicit visual review: " + flag)
    if not isinstance(review.get("notes"), str) or not review["notes"].strip():
        raise ValueError("Record what was visually reviewed")
    aliases = reviewed_action_aliases(candidate)
    counts = candidate.get("phase_counts")
    if (not isinstance(counts, dict) or set(counts) != set(ROLES)
            or any(type(counts[role]) is not int or counts[role] < len(ROLES[role]) for role in ROLES)):
        raise ValueError("Global role minima are idle2/walk3/attack3/hit2/death3")
    expected = sum(counts.values()) * len(DIRECTIONS)
    if (expected not in (104, 112) or type(candidate.get("expected_distinct_poses")) is not int
            or candidate["expected_distinct_poses"] != expected):
        raise ValueError("An explicit complete 104 or 112 distinct-pose matrix is required")
    poses = candidate.get("poses")
    if not isinstance(poses, list) or len(poses) != expected:
        raise ValueError("Every global role/direction/phase slot needs exactly one pose file")
    slots, pose_ids, source_paths, pinned_hashes = {}, set(), set(), set()
    required = {"id", "role", "direction", "phase", "output_path", "source_sha256",
                "canvas_size", "source_anchor", "scale_review_note"}
    for spec in poses:
        if not isinstance(spec, dict) or not required <= set(spec) or set(spec) - required - {"independent_review_id"}:
            raise ValueError("Each pose needs explicit identity, role/direction/phase, PNG SHA, canvas, anchor and scale note")
        pose_id = spec["id"]
        if not isinstance(pose_id, str) or not pose_id.strip() or len(pose_id) > 120 or pose_id in pose_ids:
            raise ValueError("Pose IDs must be nonempty and unique")
        pose_ids.add(pose_id)
        role, direction, phase = spec["role"], spec["direction"], spec["phase"]
        if (not isinstance(role, str) or role not in ROLES or direction not in DIRECTIONS
                or type(phase) is not int or not 0 <= phase < counts[role]):
            raise ValueError("Invalid global role/direction/phase slot")
        slot = role, direction, phase
        if slot in slots:
            raise ValueError("Duplicate global role/direction/phase slot")
        anchor = spec["source_anchor"]
        if (not isinstance(anchor, list) or len(anchor) != 2 or any(type(value) is not int for value in anchor)
                or type(spec["canvas_size"]) is not int or not 64 <= spec["canvas_size"] <= 2048
                or not isinstance(spec["scale_review_note"], str) or not spec["scale_review_note"].strip()):
            raise ValueError("Every pose requires a reviewed bounded canvas, integer anchor and nonempty scale note")
        digest = spec["source_sha256"]
        if not isinstance(digest, str) or len(digest) != 64 or any(char not in "0123456789abcdef" for char in digest):
            raise ValueError("Pin each unchanged PNG SHA-256")
        source = _pose_file_source(root, spec["output_path"])
        if source.resolve() in source_paths or digest in pinned_hashes:
            raise ValueError("A source pose/file cannot be reused across mandatory slots")
        source_paths.add(source.resolve())
        pinned_hashes.add(digest)
        if sha(source) != digest:
            raise ValueError("Pose PNG SHA-256 differs: " + str(source))
        slots[slot] = spec, source
    ordered_slots = [(role, direction, phase) for role in ROLES for direction in DIRECTIONS for phase in range(counts[role])]
    if set(slots) != set(ordered_slots):
        raise ValueError("Missing/noncontiguous global role/direction/phase slots")
    targets = {row["key"]: row for row in expansion.read(root / "data/animation_authoring_sources.json")["targets"]}
    if any(key not in targets for key in keys):
        raise ValueError("Unknown target key")
    bindings = [targets[key] for key in keys]
    first = bindings[0]
    identity = sharing_identity(first, root=root)
    if any(sharing_identity(row, root=root) != identity for row in bindings):
        raise ValueError("Cannot share authored poses across different original images/presentations")
    originals = [(root / row["reference"]["path"].removeprefix("res://"), row["reference"]["sha256"]) for row in bindings]
    for original, digest in originals:
        if sha(original) != digest:
            raise ValueError("Original reference bytes changed: " + str(original))
    folder = root / "assets/actors/eight_direction/original_based" / actor
    for parent in (folder, *folder.parents):
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise ValueError("Authored output directory is not a regular directory: " + str(parent))
        if parent == root:
            break
    geometry, parsed, atlases, copies, pose_records = {"frames": []}, [], [], [], []
    role_frames = {role: [[] for _ in DIRECTIONS] for role in ROLES}
    raw_hashes, visible_hashes = set(), set()
    texel_bytes = 0
    for index, slot in enumerate(ordered_slots):
        role, direction, phase = slot
        spec, source = slots[slot]
        part = analyze(source, rows_count=1, reference_rows=[0], directions=[direction],
                       canvas_size=spec["canvas_size"], source_anchors=[spec["source_anchor"]])
        require_complete_pose_regions(source, part)
        with Image.open(source) as image:
            if image.format != "PNG":
                raise ValueError("Pose source must be a real PNG")
            pixels = np.asarray(image)
            # Stronger standalone-body check: even small opaque islands inside
            # the bounding rectangle cannot masquerade as one connected pose.
            _, connected = ndimage.label(pixels[:, :, 3] > 100, structure=np.ones((3, 3), dtype=int))
            if connected != 1:
                raise ValueError("Standalone PNG must contain one connected visible body")
            frame = part["frames"][0]
            x, y, width, height = frame["region"]
            visible = _visible_pose_fingerprint(pixels[y:y + height, x:x + width])
        if frame["rgba_sha256"] in raw_hashes or visible in visible_hashes:
            raise ValueError("Duplicate raw or visible pose across source files")
        raw_hashes.add(frame["rgba_sha256"])
        visible_hashes.add(visible)
        frame.update({"sheet": index, "pose_id": spec["id"], "role": role, "phase": phase})
        geometry["frames"].append(frame)
        role_frames[role][DIRECTIONS.index(direction)].append(index)
        parsed.append(part)
        destination = folder / ("pose-%03d-%s-%s-%d.png" % (index, role, direction.lower(), phase))
        copies.append((source, destination, spec["source_sha256"]))
        atlas = {"path": "res://" + str(destination.relative_to(root)), "sha256": spec["source_sha256"],
                 "size": part["image_size"], "canvas_size": part["canvas_size"], "foot": part["foot"],
                 "directions": [direction], "source_direction_indices": [DIRECTIONS.index(direction)],
                 "scale_review_note": spec["scale_review_note"], "source_anchor_kind": "reviewed per-pose foot anchor"}
        atlases.append(atlas)
        pose_records.append({"id": spec["id"], "role": role, "direction": direction, "phase": phase,
                             "file": atlas["path"], "source_sha256": spec["source_sha256"],
                             "source_anchor": spec["source_anchor"], "canvas_size": spec["canvas_size"],
                             "scale_review_note": spec["scale_review_note"], "rgba_sha256": frame["rgba_sha256"],
                             "visible_sha256": visible, "entire_png_complete": True,
                             **({"independent_review_id": spec["independent_review_id"]} if "independent_review_id" in spec else {})})
        texel_bytes += part["image_size"][0] * part["image_size"][1] * 4
    used = [index for role in ROLES for group in role_frames[role] for index in group]
    if len(used) != len(set(used)) or set(used) != set(range(expected)):
        raise ValueError("Every selected source pose must be used exactly once")
    for alias, source_role in aliases.items():
        role_frames[alias] = [group.copy() for group in role_frames[source_role]]
    height_basis = candidate.get("display_height_basis", "max_living_frame")
    if height_basis not in {"median_idle", "max_living_frame"}:
        raise ValueError("Unknown reviewed display-height basis")
    if height_basis == "max_living_frame":
        reference_height = max(frame["region"][3] * 256 / parsed[index]["canvas_size"][1]
                               for index, frame in enumerate(geometry["frames"]) if frame["role"] != "death")
    else:
        reference_height = float(np.median([part["neutral_height"] * 256 / part["canvas_size"][1]
                                           for part, frame in zip(parsed, geometry["frames"]) if frame["role"] == "idle"]))
    geometry["distinct_pixel_frames"] = expected
    resource = spriteframes([atlas["path"] for atlas in atlases], geometry, role_frames)
    proof = {"schema": 1, "input_representation": "pose_files_v1", "texture_binding": "individual_png_metadata",
             "source": "Newly authored from the existing target image; not recovered original animation",
             "reference": first["reference"], "target_keys": keys,
             "presentation_to_preserve": first["presentation_to_preserve"],
             "target_references": {row["key"]: row["reference"] for row in bindings},
             "target_presentations": {row["key"]: row["presentation_to_preserve"] for row in bindings},
             "sharing_rule": "Unchanged strict original reference and rendered presentation identity",
             "authoring_instructions": candidate["prompt"], "instruction_record_kind": candidate.get("prompt_record_kind", "exact_prompt"),
             "visual_review": review, "directions": DIRECTIONS, "source_directions": DIRECTIONS,
             "source_direction_indices": list(range(8)), "cell": [256, 256], "foot": [128, 160],
             "packing": "Unchanged standalone PNG files with AtlasTexture region/margin metadata; no PNG assembly or rewriting",
             "distinct_pixel_frames": expected, "phase_counts": {role: counts[role] for role in ROLES},
             "frames": geometry["frames"], "pose_files": pose_records, "tracks": {},
             "display_height_basis": height_basis, "display_reference_height": reference_height,
             "all_selected_poses_used_once": True, "source_png_logical_rgba_bytes": texel_bytes,
             "actual_Main": "not_run", "completed_added": 0}
    if aliases:
        proof["action_aliases"] = aliases
    for role, directions in role_frames.items():
        contributing = sorted({index for group in directions for index in group})
        proof["tracks"][role] = {"atlas_files": [atlases[index] for index in contributing],
                                 "source_poses_by_direction": {direction: [pose_records[index]["id"] for index in group]
                                                               for direction, group in zip(DIRECTIONS, directions)},
                                 "source_frames_per_direction": len(directions[0]), "unique_frames_per_direction": len(directions[0]),
                                 "direction_unique_frames": dict.fromkeys(DIRECTIONS, len(directions[0])),
                                 "source_duration_seconds": SECONDS[role], "loop_type": "loop" if role in ("idle", "walk") else "play_once"}
        if role in aliases:
            proof["tracks"][role]["alias_of"] = aliases[role]
    metadata = [(folder / "SpriteFrames.tres", resource), (folder / "provenance.json", json.dumps(proof, ensure_ascii=False, indent=2) + "\n")]
    profile_plan = _pose_file_profiles(root, targets, keys, first, folder, reference_height, counts["walk"], aliases) if apply else None
    for _, destination, digest in copies:
        require_preserved_output(destination, digest)
    for path, content in metadata:
        require_preserved_output(path, hashlib.sha256(content.encode()).hexdigest())
    result = {"resource": str(folder), "identities": keys, "poses": expected, "original_unchanged": True,
              "applied": apply, "input_mode": "pose_files_v1", "source_png_logical_rgba_bytes": texel_bytes,
              "actual_Main": "not_run", "completed_added": 0}
    return {"root": root, "folder": folder, "originals": originals, "copies": copies, "metadata": metadata,
            "profile_plan": profile_plan, "result": result}


def validate_pose_files(root, candidate, actor, keys, apply=True):
    """True read-only API, including output/profile-conflict checks by default.

    apply means validate the prospective runtime-profile update too; this API
    never applies it or creates output/staging directories.
    """
    plan = _prepare_pose_files(root, candidate, actor, keys, apply)
    return {**plan["result"], "applied": False, "read_only": True, "profiles_checked": bool(apply),
            "output_files": [str(destination) for _, destination, _ in plan["copies"]]
                            + [str(path) for path, _ in plan["metadata"]]}


def import_pose_files(root, candidate, actor, keys, apply=False):
    """Install only a fully preflighted optional pose-file candidate."""
    plan = _prepare_pose_files(root, candidate, actor, keys, apply)
    return _install_optional_plan(plan)


def _install_optional_plan(plan):
    """Shared transaction for optional representations; legacy install is unchanged."""
    pending = [(source, destination, digest) for source, destination, digest in plan["copies"] if not destination.exists()]
    metadata = [(path, content) for path, content in plan["metadata"] if not path.exists()]
    profile_plan = plan["profile_plan"]
    if not pending and not metadata and not (profile_plan and profile_plan[2]):
        return plan["result"]
    created, directories = [], []
    # Staging stays on the destination filesystem; no PNG is decoded/saved.
    # A failed copy/source recheck cannot leave an earlier production asset.
    with tempfile.TemporaryDirectory(prefix=".pose-files-stage-", dir=plan["root"]) as temporary:
        staging = Path(temporary)
        staged = []
        for index, (source, destination, digest) in enumerate(pending):
            path = staging / ("png-%03d" % index)
            shutil.copyfile(source, path)
            if sha(path) != digest:
                raise ValueError("Staged pose PNG differs from pinned source")
            staged.append((path, destination, digest))
        for index, (destination, content) in enumerate(metadata):
            path = staging / ("metadata-%03d" % index)
            path.write_text(content)
            staged.append((path, destination, hashlib.sha256(content.encode()).hexdigest()))
        profile_staged = None
        profile_staged_sha = None
        if profile_plan and profile_plan[2]:
            profile_staged = staging / "profiles.json"
            expansion.save_profiles(profile_staged, profile_plan[1])
            profile_staged_sha = sha(profile_staged)
        for source, _, digest in plan["copies"]:
            if sha(source) != digest:
                raise ValueError("Pose source changed during preflight/copy")
        for source, digest in plan["originals"]:
            if sha(source) != digest:
                raise ValueError("Original reference changed during preflight/copy")
        # Recheck destinations/catalog immediately before committing new files.
        for _, destination, digest in plan["copies"]:
            require_preserved_output(destination, digest)
        for destination, content in plan["metadata"]:
            require_preserved_output(destination, hashlib.sha256(content.encode()).hexdigest())
        if profile_plan and sha(profile_plan[0]) != profile_plan[3]:
            raise ValueError("Runtime profile catalog changed during preflight")
        profile_commit_attempted = False
        try:
            missing = []
            parent = plan["folder"]
            while not parent.exists():
                missing.append(parent)
                parent = parent.parent
            for directory in reversed(missing):
                directory.mkdir()
                directories.append(directory)
            for source, destination, digest in staged:
                # An exclusive link cannot overwrite a file created by another
                # writer after preflight. Removing staging leaves plain files.
                try:
                    os.link(source, destination)
                    created.append(destination)
                except FileExistsError:
                    require_preserved_output(destination, digest)
                except BaseException:
                    # A signal can arrive after link succeeded but before its
                    # destination was recorded. Track only our staged inode;
                    # a pre-existing or concurrent writer's file is not ours.
                    try:
                        if destination not in created and os.path.samefile(source, destination):
                            created.append(destination)
                    except OSError:
                        pass
                    raise
            if profile_staged is not None:
                # Linking all sources can take time. Detect a catalog writer
                # during those links before replacing its update. This is a
                # last-moment recheck, not a CAS against uncooperative writers.
                if sha(profile_plan[0]) != profile_plan[3]:
                    raise ValueError("Runtime profile catalog changed during asset installation")
                profile_commit_attempted = True
                os.replace(profile_staged, profile_plan[0])
        except BaseException as error:
            if profile_commit_attempted:
                # A signal may arrive after replace succeeded but before it
                # returned to Python. Never remove assets now referenced by
                # the committed catalog. An unknown external state must also
                # retain them rather than risk creating dangling references.
                try:
                    current_profile_sha = sha(profile_plan[0])
                except OSError:
                    current_profile_sha = None
                if current_profile_sha == profile_staged_sha:
                    raise
                if current_profile_sha != profile_plan[3]:
                    raise RuntimeError(
                        "Profile commit was interrupted and the catalog state is uncertain; "
                        "new authored assets were preserved to avoid broken references"
                    ) from error
            for path in reversed(created):
                path.unlink()
            for directory in reversed(directories):
                directory.rmdir()
            raise
    return plan["result"]


def _prepare_mixed_sources(root, candidate, actor, keys, apply):
    """Strict complete-sheet + standalone-PNG union, with no source exclusions.

    This parser is intentionally separate from the legacy sheet parser. A
    sheet contributes complete role tracks and retains the >=2-row guard;
    every analyzed source body must be used exactly once in the global matrix.
    """
    root = Path(root).resolve()
    allowed = {"input_mode", "texture_binding", "key", "prompt", "prompt_record_kind", "review",
               "phase_counts", "expected_distinct_poses", "sheets", "pose_files", "display_height_basis",
               "action_aliases", "source_claim", "status", "actual_Main", "completed_added"}
    if (not isinstance(candidate, dict) or candidate.get("input_mode") != "mixed_sources_v1"
            or candidate.get("texture_binding") != "unchanged_png_metadata" or set(candidate) - allowed):
        raise ValueError("mixed_sources_v1 requires unchanged_png_metadata and explicit mixed-source fields")
    if (not isinstance(actor, str) or not 1 <= len(actor) <= 80
            or any(char not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for char in actor)):
        raise ValueError("Use a bounded ASCII actor folder name")
    if (not isinstance(keys, list) or not keys or any(not isinstance(key, str) for key in keys)
            or len(set(keys)) != len(keys) or candidate.get("key", keys[0]) != keys[0]):
        raise ValueError("Supply unique target keys matching the candidate primary key")
    if not isinstance(candidate.get("prompt"), str) or not candidate["prompt"].strip():
        raise ValueError("Record the exact authoring prompt/instructions")
    review = candidate.get("review")
    if (not isinstance(review, dict) or any(review.get(flag) is not True for flag in
            ("identity_preserved", "eight_views", "motion_roles", "no_clipping"))
            or not isinstance(review.get("notes"), str) or not review["notes"].strip()):
        raise ValueError("Record explicit identity/eight-view/motion/clipping review and notes")
    aliases = reviewed_action_aliases(candidate)
    counts = candidate.get("phase_counts")
    if (not isinstance(counts, dict) or set(counts) != set(ROLES)
            or any(type(counts[role]) is not int or counts[role] < len(ROLES[role]) for role in ROLES)):
        raise ValueError("Global role minima are idle2/walk3/attack3/hit2/death3")
    expected = sum(counts.values()) * len(DIRECTIONS)
    if (expected not in (104, 112) or type(candidate.get("expected_distinct_poses")) is not int
            or candidate["expected_distinct_poses"] != expected):
        raise ValueError("An explicit complete 104 or 112 distinct-pose matrix is required")
    sheets, poses = candidate.get("sheets"), candidate.get("pose_files")
    if not isinstance(sheets, list) or not sheets or not isinstance(poses, list) or not poses:
        raise ValueError("Mixed mode needs both nonempty sheets and pose_files lists")
    if len(sheets) + len(poses) > expected:
        raise ValueError("Too many selected mixed PNG sources")
    source_ids, source_paths, pinned_hashes = set(), set(), set()

    def source_for(spec):
        source_id = spec["id"]
        if (not isinstance(source_id, str) or not source_id.strip()
                or len(source_id) > 120 or source_id in source_ids):
            raise ValueError("Source IDs must be nonempty and globally unique")
        source_ids.add(source_id)
        if (type(spec["canvas_size"]) is not int or not 64 <= spec["canvas_size"] <= 2048
                or not isinstance(spec["scale_review_note"], str) or not spec["scale_review_note"].strip()):
            raise ValueError("Every mixed PNG requires a bounded canvas and nonempty scale review note")
        digest = spec["source_sha256"]
        if not isinstance(digest, str) or len(digest) != 64 or any(char not in "0123456789abcdef" for char in digest):
            raise ValueError("Pin every selected whole PNG SHA-256")
        source = _pose_file_source(root, spec["output_path"])
        if source.resolve() in source_paths or digest in pinned_hashes:
            raise ValueError("A selected PNG cannot be repeated within or across source kinds")
        source_paths.add(source.resolve())
        pinned_hashes.add(digest)
        if sha(source) != digest:
            raise ValueError("Mixed source PNG SHA-256 differs: " + str(source))
        return source

    sheet_fields = {"id", "output_path", "source_sha256", "rows", "directions", "roles",
                    "canvas_size", "source_anchors", "scale_review_note"}
    pose_fields = {"id", "output_path", "source_sha256", "role", "direction", "phase",
                   "canvas_size", "source_anchor", "scale_review_note"}
    prepared = []
    for spec in sheets:
        if (not isinstance(spec, dict) or not sheet_fields <= set(spec)
                or set(spec) - sheet_fields - {"directions_axis", "reference_rows", "independent_review_id"}):
            raise ValueError("Each mixed sheet needs explicit layout, roles, SHA, canvas and per-pose anchors")
        selected = reviewed_directions(spec["directions"])
        rows, roles, anchors = spec["rows"], spec["roles"], spec["source_anchors"]
        if type(rows) is not int or rows < 2 or not isinstance(roles, dict) or not roles:
            raise ValueError("Mixed sheets retain the at-least-two-row temporal guard")
        used_rows = []
        for role, indices in roles.items():
            if (role not in ROLES or not isinstance(indices, list) or len(indices) < 2
                    or len(indices) != counts[role]
                    or any(type(row) is not int or not 0 <= row < rows for row in indices)
                    or len(set(indices)) != len(indices)):
                raise ValueError("Each sheet role must provide its complete global phase count, with >=2 unique rows")
            used_rows.extend(indices)
        if len(used_rows) != len(set(used_rows)) or set(used_rows) != set(range(rows)):
            raise ValueError("Every analyzed whole-sheet row/body must be used exactly once")
        if (not isinstance(anchors, list) or len(anchors) != rows * len(selected)
                or any(not isinstance(anchor, list) or len(anchor) != 2
                       or any(type(value) is not int for value in anchor) for anchor in anchors)):
            raise ValueError("Every mixed sheet body needs its reviewed integer source anchor")
        prepared.append(("whole_sheet", spec, source_for(spec), selected))
    for spec in poses:
        if (not isinstance(spec, dict) or not pose_fields <= set(spec)
                or set(spec) - pose_fields - {"independent_review_id"}):
            raise ValueError("Standalone mixed sources require strict pose-file metadata")
        role, direction, phase = spec["role"], spec["direction"], spec["phase"]
        if (not isinstance(role, str) or role not in ROLES or direction not in DIRECTIONS
                or type(phase) is not int or not 0 <= phase < counts[role]):
            raise ValueError("Invalid standalone global role/direction/phase slot")
        anchor = spec["source_anchor"]
        if not isinstance(anchor, list) or len(anchor) != 2 or any(type(value) is not int for value in anchor):
            raise ValueError("Every standalone PNG requires its reviewed integer source anchor")
        prepared.append(("pose_file", spec, source_for(spec), [direction]))
    # Source-ID sorting makes both input-list orders immaterial to output bytes.
    prepared.sort(key=lambda item: (item[0] != "whole_sheet", item[1]["id"]))
    targets = {row["key"]: row for row in expansion.read(root / "data/animation_authoring_sources.json")["targets"]}
    if any(key not in targets for key in keys):
        raise ValueError("Unknown target key")
    bindings = [targets[key] for key in keys]
    first = bindings[0]
    identity = sharing_identity(first, root=root)
    if any(sharing_identity(row, root=root) != identity for row in bindings):
        raise ValueError("Cannot share mixed sources across different original images/presentations")
    originals = [(root / row["reference"]["path"].removeprefix("res://"), row["reference"]["sha256"]) for row in bindings]
    for source, digest in originals:
        if sha(source) != digest:
            raise ValueError("Original reference bytes changed: " + str(source))
    folder = root / "assets/actors/eight_direction/original_based" / actor
    for parent in (folder, *folder.parents):
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise ValueError("Authored output directory is not a regular directory: " + str(parent))
        if parent == root:
            break
    geometry, atlases, copies, records, source_records = {"frames": []}, [], [], [], []
    raw_hashes, visible_hashes, pose_ids, slots = set(), set(), set(), {}
    texel_bytes = 0
    for source_index, (kind, spec, source, selected) in enumerate(prepared):
        if kind == "whole_sheet":
            part = analyze(source, spec["rows"], spec.get("reference_rows"), None,
                           spec.get("directions_axis", "columns"), spec["canvas_size"],
                           spec["source_anchors"], selected)
            local_slots = {}
            for role in ROLES:
                for phase, row in enumerate(spec["roles"].get(role, [])):
                    for local_direction, direction in enumerate(selected):
                        local_slots[row * len(selected) + local_direction] = role, direction, phase
        else:
            part = analyze(source, rows_count=1, reference_rows=[0], directions=selected,
                           canvas_size=spec["canvas_size"], source_anchors=[spec["source_anchor"]])
            local_slots = {0: (spec["role"], spec["direction"], spec["phase"])}
        require_complete_pose_regions(source, part)
        if set(local_slots) != set(range(len(part["frames"]))):
            raise ValueError("Every analyzed whole-PNG body must map to exactly one mandatory slot")
        destination = folder / ("source-%03d-%s.png" % (source_index, kind.replace("_", "-")))
        atlas = {"path": "res://" + str(destination.relative_to(root)), "sha256": spec["source_sha256"],
                 "size": part["image_size"], "canvas_size": part["canvas_size"], "foot": part["foot"],
                 "source_kind": kind, "source_id": spec["id"], "directions": selected,
                 "source_direction_indices": [DIRECTIONS.index(direction) for direction in selected],
                 "scale_review_note": spec["scale_review_note"],
                 "source_anchor_kind": "reviewed per-pose foot anchors recorded in frames"}
        if kind == "whole_sheet":
            atlas["directions_axis"] = spec.get("directions_axis", "columns")
        atlases.append(atlas)
        copies.append((source, destination, spec["source_sha256"]))
        with Image.open(source) as image:
            if image.format != "PNG":
                raise ValueError("Mixed source must be a real PNG")
            pixels = np.asarray(image)
            if kind == "pose_file":
                _, connected = ndimage.label(pixels[:, :, 3] > 100, structure=np.ones((3, 3), dtype=int))
                if connected != 1:
                    raise ValueError("Standalone PNG must contain one connected visible body")
            for local_index, frame in enumerate(part["frames"]):
                role, direction, phase = local_slots[local_index]
                slot = role, direction, phase
                if slot in slots:
                    raise ValueError("Overlapping mixed global role/direction/phase slot")
                x, y, width, height = frame["region"]
                visible = _visible_pose_fingerprint(pixels[y:y + height, x:x + width])
                if frame["rgba_sha256"] in raw_hashes or visible in visible_hashes:
                    raise ValueError("Duplicate raw or visible pose across mixed source kinds")
                raw_hashes.add(frame["rgba_sha256"])
                visible_hashes.add(visible)
                frame_index = len(geometry["frames"])
                pose_id = spec["id"] if kind == "pose_file" else f"{spec['id']}:{role}:{direction}:{phase}"
                if pose_id in pose_ids:
                    raise ValueError("Derived sheet pose IDs and standalone pose IDs must be globally unique")
                pose_ids.add(pose_id)
                frame.update({"sheet": source_index, "pose_id": pose_id, "role": role, "phase": phase})
                geometry["frames"].append(frame)
                slots[slot] = frame_index
                records.append({"id": pose_id, "source_id": spec["id"], "source_kind": kind,
                                "source_frame": local_index, "role": role, "direction": direction, "phase": phase,
                                "file": atlas["path"], "source_sha256": spec["source_sha256"],
                                "source_anchor": frame["source_anchor"], "canvas_size": spec["canvas_size"],
                                "scale_review_note": spec["scale_review_note"], "rgba_sha256": frame["rgba_sha256"],
                                "visible_sha256": visible,
                                **({"independent_review_id": spec["independent_review_id"]} if "independent_review_id" in spec else {})})
        source_records.append({**atlas, "analyzed_body_count": len(part["frames"]),
                               "mandatory_usage_count": len(local_slots), "entire_png_complete": True,
                               "every_analyzed_body_used_once": True})
        texel_bytes += part["image_size"][0] * part["image_size"][1] * 4
    required_slots = {(role, direction, phase) for role in ROLES for direction in DIRECTIONS for phase in range(counts[role])}
    if set(slots) != required_slots or len(geometry["frames"]) != expected:
        raise ValueError("Missing/noncontiguous global mixed role/direction/phase slots")
    role_frames = {role: [[slots[(role, direction, phase)] for phase in range(counts[role])]
                         for direction in DIRECTIONS] for role in ROLES}
    used = [index for role in ROLES for group in role_frames[role] for index in group]
    if len(used) != len(set(used)) or set(used) != set(range(expected)):
        raise ValueError("Every selected source body must be used exactly once")
    for alias, source_role in aliases.items():
        role_frames[alias] = [group.copy() for group in role_frames[source_role]]
    height_basis = candidate.get("display_height_basis", "max_living_frame")
    if height_basis not in {"median_idle", "max_living_frame"}:
        raise ValueError("Unknown reviewed display-height basis")
    heights = [frame["region"][3] * 256 / atlases[frame["sheet"]]["canvas_size"][1]
               for frame in geometry["frames"]
               if frame["role"] == "idle" or (height_basis == "max_living_frame" and frame["role"] != "death")]
    reference_height = max(heights) if height_basis == "max_living_frame" else float(np.median(heights))
    geometry["distinct_pixel_frames"] = expected
    resource = spriteframes([atlas["path"] for atlas in atlases], geometry, role_frames)
    proof = {"schema": 1, "input_representation": "mixed_sources_v1", "texture_binding": "unchanged_png_metadata",
             "source": "Newly authored from the existing target image; not recovered original animation",
             "reference": first["reference"], "target_keys": keys,
             "presentation_to_preserve": first["presentation_to_preserve"],
             "target_references": {row["key"]: row["reference"] for row in bindings},
             "target_presentations": {row["key"]: row["presentation_to_preserve"] for row in bindings},
             "sharing_rule": "Unchanged strict original reference and rendered presentation identity",
             "authoring_instructions": candidate["prompt"], "instruction_record_kind": candidate.get("prompt_record_kind", "exact_prompt"),
             "visual_review": review, "directions": DIRECTIONS, "source_directions": DIRECTIONS,
             "source_direction_indices": list(range(8)), "cell": [256, 256], "foot": [128, 160],
             "packing": "Unchanged whole-sheet and standalone PNGs with AtlasTexture metadata; no PNG assembly or rewriting",
             "distinct_pixel_frames": expected, "phase_counts": {role: counts[role] for role in ROLES},
             "frames": geometry["frames"], "source_files": source_records, "source_poses": records, "tracks": {},
             "display_height_basis": height_basis, "display_reference_height": reference_height,
             "all_selected_poses_used_once": True, "source_png_logical_rgba_bytes": texel_bytes,
             "actual_Main": "not_run", "completed_added": 0}
    if aliases:
        proof["action_aliases"] = aliases
    for role, directions in role_frames.items():
        contributing = sorted({geometry["frames"][index]["sheet"] for group in directions for index in group})
        proof["tracks"][role] = {"atlas_files": [atlases[index] for index in contributing],
                                 "source_poses_by_direction": {direction: [records[index]["id"] for index in group]
                                                               for direction, group in zip(DIRECTIONS, directions)},
                                 "source_frames_per_direction": len(directions[0]), "unique_frames_per_direction": len(directions[0]),
                                 "direction_unique_frames": dict.fromkeys(DIRECTIONS, len(directions[0])),
                                 "source_duration_seconds": SECONDS[role], "loop_type": "loop" if role in ("idle", "walk") else "play_once"}
        if role in aliases:
            proof["tracks"][role]["alias_of"] = aliases[role]
    metadata = [(folder / "SpriteFrames.tres", resource), (folder / "provenance.json", json.dumps(proof, ensure_ascii=False, indent=2) + "\n")]
    profile_plan = _pose_file_profiles(root, targets, keys, first, folder, reference_height, counts["walk"], aliases) if apply else None
    for _, destination, digest in copies:
        require_preserved_output(destination, digest)
    for path, content in metadata:
        require_preserved_output(path, hashlib.sha256(content.encode()).hexdigest())
    result = {"resource": str(folder), "identities": keys, "poses": expected, "original_unchanged": True,
              "applied": apply, "input_mode": "mixed_sources_v1", "source_png_logical_rgba_bytes": texel_bytes,
              "actual_Main": "not_run", "completed_added": 0}
    return {"root": root, "folder": folder, "originals": originals, "copies": copies, "metadata": metadata,
            "profile_plan": profile_plan, "result": result}


def validate_mixed_sources(root, candidate, actor, keys, apply=True):
    """Read-only mixed-source preflight, including prospective profiles by default."""
    plan = _prepare_mixed_sources(root, candidate, actor, keys, apply)
    return {**plan["result"], "applied": False, "read_only": True, "profiles_checked": bool(apply),
            "output_files": [str(destination) for _, destination, _ in plan["copies"]]
                            + [str(path) for path, _ in plan["metadata"]]}


def import_mixed_sources(root, candidate, actor, keys, apply=False):
    """Install only a completely validated mixed-source union."""
    return _install_optional_plan(_prepare_mixed_sources(root, candidate, actor, keys, apply))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("."))
    parser.add_argument("--analyze", type=Path)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--validate-candidate", type=Path,
                        help="Read-only optional-input preflight, including prospective profile/output conflicts; writes nothing")
    parser.add_argument("--actor")
    parser.add_argument("--key", action="append")
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.validate_candidate:
        if args.analyze or args.candidate or not args.actor or not args.key:
            parser.error("--validate-candidate requires --actor/--key and excludes --candidate/--analyze")
        candidate = expansion.read(args.validate_candidate)
        validate = validate_mixed_sources if candidate.get("input_mode") == "mixed_sources_v1" else validate_pose_files
        print(json.dumps(validate(args.root.resolve(), candidate, args.actor, args.key), ensure_ascii=False))
    elif args.analyze:
        result = analyze(args.analyze)
        print(json.dumps({key: result[key] for key in ("image_size", "distinct_pixel_frames")}))
    else:
        if not args.candidate or not args.actor or not args.key:
            parser.error("--candidate, --actor and --key are required")
        print(json.dumps(import_sheet(args.root.resolve(), expansion.read(args.candidate), args.actor, args.key, args.apply), ensure_ascii=False))


if __name__ == "__main__":
    main()
