#!/usr/bin/env python3
"""Losslessly assemble two pinned contact keys and four newly authored poses.

``assemble(contact0, contact3, newfour, output, direction='N', metadata=spec)``
requires a dict or JSON path with schema ``pr122-native-pose-keys-v1``.
``contact0``/``contact3`` pin path, sha256, rgba_sha256, source_path,
source_sha256 and source_region [x,y,width,height]. ``new_four`` pins path
and sha256. Optional missing_pose_order is a reviewed permutation of 0..3
for playback frames 1,2,4,5. Paths in JSON resolve against that JSON's folder.

This translates complete RGBA rectangles only. It never rescales, mirrors,
cleans fringes, changes body proportions or approves animation quality.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

import numpy as np
from PIL import Image

import import_original_based_motion as importer


SCHEMA = "pr122-native-pose-keys-v1"


def _sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _rgba_sha(image):
    return hashlib.sha256(np.asarray(image).tobytes()).hexdigest()


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _read_spec(metadata):
    if isinstance(metadata, (str, Path)):
        path = Path(metadata).resolve(strict=True)
        spec, base = json.loads(path.read_text()), path.parent
    else:
        spec, base = metadata, Path.cwd()
    _require(isinstance(spec, dict) and spec.get("schema") == SCHEMA,
             "Require metadata schema " + SCHEMA)
    return spec, base


def _path(value, base):
    _require(isinstance(value, (str, Path)), "Pinned source path is required")
    path = Path(value)
    return (path if path.is_absolute() else base / path).resolve(strict=True)


def _pin(path, expected):
    _require(isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected),
             "Require a complete lowercase SHA-256 pin")
    _require(path.is_file() and _sha(path) == expected, "Source SHA mismatch: " + str(path))


def _rgba(path):
    with Image.open(path) as source:
        _require(source.mode == "RGBA", "Require original RGBA pixels: " + str(path))
        return source.copy()


def _region(value, size):
    _require(isinstance(value, list) and len(value) == 4
             and all(type(n) is int for n in value), "Region must be four exact integers")
    x, y, width, height = value
    _require(min(x, y) >= 0 and min(width, height) > 0
             and x + width <= size[0] and y + height <= size[1], "Region outside source")
    return x, y, width, height


def _crop(image, region):
    x, y, width, height = _region(region, image.size)
    return image.crop((x, y, x + width, y + height))


def _complete_rgba_regions(image, geometry):
    """Reject unassigned/ambiguous alpha, including faint fringe; never clean it."""
    alpha = np.asarray(image)[:, :, 3]
    coverage = np.zeros(alpha.shape, dtype=np.uint8)
    for frame in geometry["frames"]:
        x, y, width, height = _region(frame["region"], image.size)
        coverage[y:y + height, x:x + width] += 1
    _require(not np.any((alpha > 0) & (coverage == 0)),
             "Nontransparent pixels outside exact pose regions; no fringe removal allowed")
    _require(not np.any((alpha > 0) & (coverage > 1)),
             "Pose regions would duplicate nontransparent pixels")


def _contact(pin, base, label):
    image = _rgba(_path(pin["path"], base))
    source_path = _path(pin["source_path"], base)
    source = _rgba(source_path)
    source_region = list(_region(pin["source_region"], source.size))
    original = _crop(source, source_region)
    _require(image.size == original.size and np.array_equal(np.asarray(image), np.asarray(original)),
             label + " is not an exact original-source RGBA crop")
    _require(_rgba_sha(image) == pin.get("rgba_sha256"), label + " RGBA pin mismatch")
    return image, {"kind": "reused_contact", "source_path": str(_path(pin["path"], base)),
                   "source_sha256": pin["sha256"], "source_region": [0, 0, *image.size],
                   "original_source_path": str(source_path),
                   "original_source_sha256": pin["source_sha256"],
                   "original_source_region": source_region,
                   "original_source_phase": pin.get("source_phase"), "contact_key": label}


def assemble(contact0, contact3, newfour, output, direction="N", *, metadata):
    """Write one new atlas/proof exclusively; return proof, never mutate inputs.

    On post-write validation failure the atlas and an exclusive error receipt
    remain for review. No success proof or approval is emitted on failure.
    Physical body-scale/foot/leg/compass review remains external.
    """
    output = Path(output).absolute()
    proof_path = output.with_suffix(".assembly.json")
    error_path = output.with_suffix(".assembly-error.json")
    if any(path.exists() for path in (output, proof_path, error_path)):
        raise FileExistsError("Refuse existing atlas/proof/error receipt: " + str(output))
    spec, base = _read_spec(metadata)
    metadata_is_file = isinstance(metadata, (str, Path))
    metadata_sha = (_sha(Path(metadata).resolve(strict=True)) if metadata_is_file else
                    hashlib.sha256(json.dumps(spec, sort_keys=True, separators=(",", ":"))
                                   .encode("utf-8")).hexdigest())
    _require(direction in importer.DIRECTIONS, "Unknown direction")
    _require(spec.get("direction", direction) == direction, "Metadata direction mismatch")
    order = spec.get("missing_pose_order", [0, 1, 2, 3])
    _require(isinstance(order, list) and len(order) == 4
             and all(type(n) is int for n in order) and sorted(order) == list(range(4)),
             "missing_pose_order must be an exact four-int permutation of 0,1,2,3")
    pins = [spec["contact0"], spec["contact3"], spec["new_four"]]
    supplied = [Path(path).resolve(strict=True) for path in (contact0, contact3, newfour)]
    # Verify every PNG/source pin before opening any image or writing anything.
    for supplied_path, pin in zip(supplied, pins):
        _require(supplied_path == _path(pin["path"], base), "Argument/pinned path mismatch")
        _pin(supplied_path, pin.get("sha256"))
    for pin in pins[:2]:
        _pin(_path(pin["source_path"], base), pin.get("source_sha256"))
    _require(output.resolve() not in supplied, "Output must not be an input")
    old0, origin0 = _contact(pins[0], base, "contact0")
    old3, origin3 = _contact(pins[1], base, "contact3")
    four = _rgba(supplied[2])
    new_geometry = importer.analyze(supplied[2], rows_count=4, reference_rows=[0, 2],
                                    directions_axis="phase_grid2", canvas_size=1024,
                                    directions=[direction])
    importer.require_complete_pose_regions(supplied[2], new_geometry)
    _require(new_geometry["distinct_pixel_frames"] == 4, "Require four distinct new poses")
    _complete_rgba_regions(four, new_geometry)
    new = []
    for frame in new_geometry["frames"]:
        region = frame["region"]
        new.append((_crop(four, region), {"kind": "newly_authored", "source_path": str(supplied[2]),
                    "source_sha256": pins[2]["sha256"], "source_region": region,
                    "authored_row": frame["row"]}))
    poses = [(old0, origin0), new[order[0]], new[order[1]], (old3, origin3),
             new[order[2]], new[order[3]]]
    visible_hashes = [importer._visible_pose_fingerprint(np.asarray(image)) for image, _ in poses]
    _require(len(set(visible_hashes)) == 6, "Duplicate visible pose among six playback frames")
    max_width = max(image.width for image, _ in poses)
    max_height = max(image.height for image, _ in poses)
    cell_width = ((max(768, max_width + 64) + 63) // 64) * 64
    cell_height = ((max(768, max_height + 64) + 63) // 64) * 64
    atlas = Image.new("RGBA", (cell_width * 2, cell_height * 3))
    audit_poses = []
    for phase, (image, origin) in enumerate(poses):
        dx = (phase % 2) * cell_width + (cell_width - image.width) // 2
        dy = (phase // 2) * cell_height + (cell_height - image.height) // 2
        # Unmasked paste retains partial-alpha RGB and alpha EXACTLY.
        atlas.paste(image, (dx, dy))
        copied = atlas.crop((dx, dy, dx + image.width, dy + image.height))
        _require(np.array_equal(np.asarray(copied), np.asarray(image)), "RGBA copy mismatch")
        rgba = np.asarray(image)
        sx, sy, _, _ = origin["source_region"]
        audit_poses.append({"phase": phase, **origin, "rgba_sha256": _rgba_sha(image),
                            "visible_pose_sha256": visible_hashes[phase],
                            "output_region": [dx, dy, *image.size],
                            "translation": [dx - sx, dy - sy],
                            "nontransparent_pixels": int(np.count_nonzero(rgba[:, :, 3] > 0)),
                            "foreground_alpha_gt16_pixels": int(np.count_nonzero(rgba[:, :, 3] > 16))})
    output.parent.mkdir(parents=True, exist_ok=True)
    created = False
    try:
        with output.open("xb") as stream:
            created = True
            atlas.save(stream, format="PNG")
        _require(np.array_equal(np.asarray(_rgba(output)), np.asarray(atlas)),
                 "Written PNG did not retain the exact assembled RGBA")
        geometry = importer.analyze(output, rows_count=6, reference_rows=[0, 3],
                                    directions_axis="phase_grid2", canvas_size=1024,
                                    directions=[direction])
        importer.require_complete_pose_regions(output, geometry)
        _require(geometry["distinct_pixel_frames"] == 6, "Require six distinct final poses")
        _complete_rgba_regions(atlas, geometry)
        heights = [image.height for image, _ in poses]
        proof = {"schema": SCHEMA, "direction": direction, "output": str(output),
                 "metadata_sha256": metadata_sha,
                 "metadata_hash_basis": "file_bytes" if metadata_is_file else "canonical_json",
                 "metadata_path": str(Path(metadata).resolve()) if metadata_is_file else None,
                 "output_sha256": _sha(output), "output_canvas": list(atlas.size),
                 "cell_size": [cell_width, cell_height], "newly_authored_poses": 4,
                 "reused_poses": 2, "missing_pose_order": order,
                 "missing_pose_order_review": spec.get("missing_pose_order_review"),
                 "resampled": False, "mirrored": False, "recolored": False,
                 "removed_pixels": 0, "preserved_all_nontransparent_rgba": True,
                 "preserved_all_alpha_gt16_rgba": True, "poses": audit_poses,
                 "new_four_geometry": new_geometry, "geometry": geometry,
                 "strict_importer": "PASS", "approval": False, "visual_approval": "NOT_RUN",
                 "physical_body_scale_review": "REQUIRED_EXTERNAL_LANDMARK_REVIEW",
                 "region_height_span": [min(heights), max(heights)],
                 "possible_height_mismatch": max(heights) / min(heights) > 1.15,
                 "height_note": "Region extents include gear/pose changes; not anatomical body scale. Pixels were not normalized."}
        with proof_path.open("x") as stream:
            stream.write(json.dumps(proof, indent=2) + "\n")
        return proof
    except Exception as error:
        if created:
            receipt = {"status": "STOP_PRESERVED_NOT_APPROVED", "output": str(output),
                       "output_exists": output.exists(), "error": str(error)[:1000],
                       "approval": False, "success_proof_emitted": False}
            try:
                with error_path.open("x") as stream:
                    stream.write(json.dumps(receipt, indent=2) + "\n")
            except FileExistsError:
                pass
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--direction", default="N", choices=importer.DIRECTIONS)
    args = parser.parse_args()
    try:
        spec, base = _read_spec(args.spec)
        proof = assemble(_path(spec["contact0"]["path"], base),
                         _path(spec["contact3"]["path"], base),
                         _path(spec["new_four"]["path"], base), args.output,
                         args.direction, metadata=args.spec)
        print(json.dumps({"strict_importer": proof["strict_importer"], "output": proof["output"],
                          "output_sha256": proof["output_sha256"], "newly_authored_poses": 4,
                          "reused_poses": 2, "approval": False}))
        return 0
    except Exception as error:
        print(json.dumps({"status": "STOP_PRESERVE_INPUTS", "error": str(error)[:1000]}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
