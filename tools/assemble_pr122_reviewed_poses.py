#!/usr/bin/env python3
"""Assemble six explicitly reviewed source regions without changing their RGBA.

assemble_pose_map(spec, output) accepts a dict or JSON path. Schema is
pr122-reviewed-pose-map-v1, with key, role, direction and six ordered poses.
Each pose pins path, source_sha256, region [x,y,w,h], rgba_sha256,
source_pose, newly_authored (bool), and a nonempty review_basis. JSON-relative
paths resolve against its own directory. Include all gear/fringe and any
desired padding in the pinned region; this tool never guesses crop padding.

Source images may contain other, unselected poses. All selected connected
alpha>16 parts and their nearest main-body foreground must fit the reviewed
region. Ambiguous bridges/foreign bodies remain HOLD. Anatomy, timing and
physical body scale require external review, never bbox normalization.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

import import_original_based_motion as importer


SCHEMA = "pr122-reviewed-pose-map-v1"
ROLES = {"walk", "run", "idle", "attack", "hit", "death"}


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _rgba_sha(image):
    return hashlib.sha256(np.asarray(image).tobytes()).hexdigest()


def _read_spec(spec):
    if isinstance(spec, (str, Path)):
        path = Path(spec).resolve(strict=True)
        data = json.loads(path.read_text())
        return data, path.parent, _sha(path), str(path)
    _require(isinstance(spec, dict), "Require a metadata dict or JSON path")
    canonical = json.dumps(spec, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return spec, Path.cwd(), hashlib.sha256(canonical).hexdigest(), None


def _path(value, base):
    _require(isinstance(value, (str, Path)), "Require a pinned source path")
    path = Path(value)
    return (path if path.is_absolute() else base / path).resolve(strict=True)


def _pin(path, expected):
    _require(isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected),
             "Require a complete lowercase source SHA-256")
    _require(path.is_file() and _sha(path) == expected, "Source SHA mismatch: " + str(path))


def _rgba(path):
    with Image.open(path) as image:
        _require(image.mode == "RGBA", "Require original RGBA input: " + str(path))
        return image.copy()


def _region(value, size):
    _require(isinstance(value, list) and len(value) == 4
             and all(type(n) is int for n in value), "Region must be four exact integers")
    x, y, width, height = value
    _require(min(x, y) >= 0 and min(width, height) > 0
             and x + width <= size[0] and y + height <= size[1], "Region outside source")
    return x, y, width, height


def _inside(box, region):
    yslice, xslice = box
    x, y, width, height = region
    return (x <= xslice.start and xslice.stop <= x + width
            and y <= yslice.start and yslice.stop <= y + height)


def _source_geometry(image):
    alpha = np.asarray(image)[:, :, 3]
    labels, _ = ndimage.label(alpha > 100)
    areas = np.bincount(labels.ravel())
    bodies = set(int(n) for n in np.flatnonzero(areas >= 200) if n)
    _require(bool(bodies), "Source has no complete main body")
    nearest = ndimage.distance_transform_edt(~np.isin(labels, list(bodies)),
                                            return_distances=False, return_indices=True)
    owners = labels[nearest[0], nearest[1]]
    foreground_labels, _ = ndimage.label(alpha > 16, np.ones((3, 3)))
    return {"alpha": alpha, "labels": labels, "bodies": bodies,
            "body_boxes": ndimage.find_objects(labels), "owners": owners,
            "foreground_labels": foreground_labels,
            "foreground_boxes": ndimage.find_objects(foreground_labels)}


def _reviewed_crop(image, geometry, entry):
    region = list(_region(entry["region"], image.size))
    x, y, width, height = region
    selection = np.s_[y:y + height, x:x + width]
    visible_ids = set(int(n) for n in np.unique(geometry["labels"][selection]))
    main_bodies = visible_ids & geometry["bodies"]
    _require(len(main_bodies) == 1, "Each reviewed region requires one main body and no foreign body")
    body = main_bodies.pop()
    _require(_inside(geometry["body_boxes"][body - 1], region),
             "Region cuts a main-body component")
    foreground = geometry["alpha"] > 16
    selected_foreground = foreground & (geometry["owners"] == body)
    ys, xs = np.nonzero(selected_foreground)
    _require(xs.size > 0, "Empty selected foreground")
    _require(xs.min() > 0 and ys.min() > 0 and xs.max() < image.width - 1
             and ys.max() < image.height - 1, "Selected foreground touches source boundary")
    _require(xs.min() >= x and ys.min() >= y and xs.max() < x + width
             and ys.max() < y + height,
             "Region omits alpha>16 foreground owned by the selected body")
    local_foreground = foreground[selection]
    _require(not np.any(local_foreground & (geometry["owners"][selection] != body)),
             "Reviewed region includes foreign-body foreground")
    component_ids = np.unique(geometry["foreground_labels"][selection][local_foreground])
    for component in component_ids:
        _require(_inside(geometry["foreground_boxes"][int(component) - 1], region),
                 "Region cuts an alpha>16 part or an ambiguous foreground bridge")
    crop = image.crop((x, y, x + width, y + height))
    _require(_rgba_sha(crop) == entry["rgba_sha256"], "Reviewed crop RGBA hash mismatch")
    return crop, int(selected_foreground.sum())


def _complete_output(image, geometry):
    foreground = np.asarray(image)[:, :, 3] > 16
    coverage = np.zeros(foreground.shape, dtype=np.uint8)
    for frame in geometry["frames"]:
        x, y, width, height = _region(frame["region"], image.size)
        coverage[y:y + height, x:x + width] += 1
    _require(not np.any(foreground & (coverage != 1)),
             "Strict output regions omit or duplicate alpha>16 pixels")


def assemble_pose_map(spec, output):
    """Exclusively write a 2560x3840 atlas/proof, preserving exact selected RGBA."""
    output = Path(output).absolute()
    proof_path = output.with_suffix(".assembly.json")
    error_path = output.with_suffix(".assembly-error.json")
    if any(path.exists() for path in (output, proof_path, error_path)):
        raise FileExistsError("Refuse existing atlas/proof/error receipt: " + str(output))
    data, base, metadata_sha, metadata_path = _read_spec(spec)
    _require(data.get("schema") == SCHEMA, "Require schema " + SCHEMA)
    _require(isinstance(data.get("key"), str) and bool(data["key"].strip()), "Require explicit actor key")
    _require(data.get("role") in ROLES, "Require explicit supported role")
    _require(data.get("direction") in importer.DIRECTIONS, "Require explicit direction")
    entries = data.get("poses")
    _require(isinstance(entries, list) and len(entries) == 6, "Require six ordered pose entries")
    paths = []
    for entry in entries:
        _require(isinstance(entry, dict), "Each pose entry must be an object")
        _require(type(entry.get("newly_authored")) is bool, "newly_authored must be an explicit bool")
        _require(isinstance(entry.get("review_basis"), str) and bool(entry["review_basis"].strip()),
                 "Require actual external review_basis for every pose")
        source_pose = entry.get("source_pose")
        _require((type(source_pose) is int and source_pose >= 0)
                 or (isinstance(source_pose, str) and bool(source_pose.strip())),
                 "Require explicit source_pose identity")
        _require(isinstance(entry.get("rgba_sha256"), str)
                 and re.fullmatch(r"[0-9a-f]{64}", entry["rgba_sha256"]),
                 "Require reviewed crop RGBA SHA-256")
        path = _path(entry.get("path"), base)
        _pin(path, entry.get("source_sha256"))
        paths.append(path)
    _require(output.resolve() not in paths, "Output must not replace any source")
    # Every source pin above is checked before any image is opened/output is written.
    images = {path: _rgba(path) for path in set(paths)}
    geometries = {path: _source_geometry(image) for path, image in images.items()}
    crops, foreground_counts = [], []
    for path, entry in zip(paths, entries):
        crop, count = _reviewed_crop(images[path], geometries[path], entry)
        _require(crop.width <= 1216 and crop.height <= 1216,
                 "Reviewed pose exceeds spacious cell; never resize to fit")
        crops.append(crop)
        foreground_counts.append(count)
    visible_hashes = [importer._visible_pose_fingerprint(np.asarray(crop)) for crop in crops]
    _require(len(set(visible_hashes)) == 6, "Duplicate visible RGBA pose in reviewed map")
    atlas = Image.new("RGBA", (2560, 3840))
    pose_proofs = []
    for phase, (path, entry, crop) in enumerate(zip(paths, entries, crops)):
        dx = phase % 2 * 1280 + (1280 - crop.width) // 2
        dy = phase // 2 * 1280 + (1280 - crop.height) // 2
        atlas.paste(crop, (dx, dy))  # No alpha mask/compositing: exact partial-alpha RGBA.
        copied = atlas.crop((dx, dy, dx + crop.width, dy + crop.height))
        _require(np.array_equal(np.asarray(copied), np.asarray(crop)), "RGBA copy mismatch")
        sx, sy, _, _ = entry["region"]
        pose_proofs.append({"phase": phase, "source_path": str(path),
                            "source_sha256": entry["source_sha256"],
                            "source_pose": entry["source_pose"], "source_region": entry["region"],
                            "rgba_sha256": entry["rgba_sha256"],
                            "visible_pose_sha256": visible_hashes[phase],
                            "newly_authored": entry["newly_authored"],
                            "review_basis": entry["review_basis"],
                            "output_region": [dx, dy, *crop.size],
                            "translation": [dx - sx, dy - sy],
                            "alpha_gt16_pixels": foreground_counts[phase]})
    output.parent.mkdir(parents=True, exist_ok=True)
    created = False
    try:
        with output.open("xb") as stream:
            created = True
            atlas.save(stream, format="PNG")
        _require(np.array_equal(np.asarray(_rgba(output)), np.asarray(atlas)),
                 "Written PNG did not retain exact assembled RGBA")
        geometry = importer.analyze(output, rows_count=6, reference_rows=[0, 3],
                                    directions_axis="phase_grid2", canvas_size=2048,
                                    directions=[data["direction"]])
        importer.require_complete_pose_regions(output, geometry)
        _require(geometry["distinct_pixel_frames"] == 6, "Require six distinct final poses")
        _complete_output(atlas, geometry)
        heights = [crop.height for crop in crops]
        new_count = sum(entry["newly_authored"] for entry in entries)
        proof = {"schema": SCHEMA, "key": data["key"], "role": data["role"],
                 "direction": data["direction"], "metadata_sha256": metadata_sha,
                 "metadata_path": metadata_path,
                 "metadata_hash_basis": "file_bytes" if metadata_path else "canonical_json",
                 "output": str(output), "output_sha256": _sha(output),
                 "output_canvas": [2560, 3840], "cell_size": [1280, 1280],
                 "virtual_canvas_size": 2048, "poses": pose_proofs,
                 "newly_authored_poses": new_count, "reused_poses": 6 - new_count,
                 "preserved_region_rgba_exact": True, "preserved_pose_alpha_gt16": True,
                 "resampled": False, "mirrored": False, "recolored": False,
                 "cleaned_pixels": 0, "strict_importer": "PASS", "geometry": geometry,
                 "approval": False, "visual_approval": "NOT_RUN",
                 "physical_body_scale_review": "REQUIRED_EXTERNAL_LANDMARK_REVIEW",
                 "external_physical_scale_review": data.get("physical_scale_review"),
                 "region_height_span": [min(heights), max(heights)],
                 "possible_region_height_mismatch": max(heights) / min(heights) > 1.15,
                 "height_note": "Gear/pose extents are not anatomical scale. No bbox normalization performed."}
        with proof_path.open("x") as stream:
            stream.write(json.dumps(proof, indent=2) + "\n")
        return proof
    except Exception as error:
        if created:
            try:
                with error_path.open("x") as stream:
                    stream.write(json.dumps({"status": "STOP_PRESERVED_NOT_APPROVED",
                                 "output": str(output), "error": str(error)[:1000],
                                 "approval": False, "success_proof_emitted": False}, indent=2) + "\n")
            except FileExistsError:
                pass
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        proof = assemble_pose_map(args.spec, args.output)
        print(json.dumps({"strict_importer": proof["strict_importer"], "output": proof["output"],
                          "output_sha256": proof["output_sha256"],
                          "newly_authored_poses": proof["newly_authored_poses"],
                          "reused_poses": proof["reused_poses"], "approval": False}))
        return 0
    except Exception as error:
        print(json.dumps({"status": "STOP_PRESERVE_INPUTS", "error": str(error)[:1000]}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
