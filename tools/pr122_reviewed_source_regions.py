"""Expand explicitly reviewed atlas regions without editing source pixels.

Required review fields: status=REVIEWED_SOURCE_REGIONS_PROPOSAL, source_sha256,
base_geometry_sha256, direction, review_basis, regions, nearest_owner_sha256.
Regions are six [x, y, width, height] lists indexed by the original authored row.
The owner pin hashes a uint8 image: detached alpha>16 pixels contain their
reviewed nearest physical-body row; all other pixels contain 255. Physical-body
seeds use the original importer's alpha>100, four-connected, >=200-pixel rule.
Connected alpha>16 parts inherit their single physical body. Every detached
component must have one nearest body throughout and a >32px runner-up margin.

This metadata-only operation leaves the default importer/repacker unchanged.
Its proof is not source-art, runtime, or actor approval. It cannot repack a sheet
whose original automatic rectangles already overlap or contain another body.
"""

from copy import deepcopy
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re

import numpy as np
from PIL import Image
from scipy import ndimage

import import_original_based_motion as importer


STATUS = "REVIEWED_SOURCE_REGIONS_PROPOSAL"
OWNERSHIP_RULE = "alpha16-components-alpha100-body-seeds-detached-nearest-v1"
MINIMUM_OWNER_MARGIN = 32.0


def _digest(value):
    try:
        encoded = json.dumps(value, sort_keys=True, separators=(",", ":"),
                             allow_nan=False).encode("utf-8")
    except (TypeError, ValueError) as error:
        raise ValueError("Review and geometry must contain finite JSON metadata") from error
    return hashlib.sha256(encoded).hexdigest()


def _sha(value, label):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value):
        raise ValueError(label + " must be a lowercase SHA256")
    return value


def _rect(value, image_size, label):
    if (not isinstance(value, list) or len(value) != 4
            or any(type(item) is not int for item in value)):
        raise ValueError(label + " must contain four integers")
    x, y, width, height = value
    if (min(x, y) < 0 or min(width, height) <= 0
            or x + width > image_size[0] or y + height > image_size[1]):
        raise ValueError(label + " must be a positive rectangle inside the source")
    return x, y, x + width, y + height


def _disjoint(rectangles, label):
    for index, (left, top, right, bottom) in enumerate(rectangles):
        for other in rectangles[index + 1:]:
            if (max(left, other[0]) < min(right, other[2])
                    and max(top, other[1]) < min(bottom, other[3])):
                raise ValueError(label + " rectangles must be pairwise disjoint")


def _foreground_owners(alpha, frames):
    """Return topology-owned foreground and a pin for reviewed detached parts.

    A detached fragment never votes for itself: distance seeds contain only the
    six large physical components selected by the unchanged original importer.
    """
    strong_labels, _ = ndimage.label(alpha > 100)
    areas = np.bincount(strong_labels.ravel())
    body_labels = []
    for frame in frames:
        x, y, width, height = frame["region"]
        labels = np.unique(strong_labels[y:y + height, x:x + width])
        bodies = [int(value) for value in labels if value and areas[value] >= 200]
        if len(bodies) != 1 or bodies[0] in body_labels:
            raise ValueError("Each base region must identify one distinct physical body")
        body_labels.append(bodies[0])
    if int(np.count_nonzero(areas[1:] >= 200)) != 6:
        raise ValueError("Exactly six original strong physical bodies are required")

    components, count = ndimage.label(alpha > 16, np.ones((3, 3)))
    component_owner = np.full(count + 1, 255, dtype=np.uint8)
    for row, body in enumerate(body_labels):
        component_ids = np.unique(components[strong_labels == body])
        if len(component_ids) != 1 or component_ids[0] == 0:
            raise ValueError("A physical body must occupy one connected foreground component")
        component = int(component_ids[0])
        if component_owner[component] != 255:
            raise ValueError("Foreground connects two different physical bodies")
        component_owner[component] = row

    detached = ((components > 0) & (component_owner[components] == 255))
    ys, xs = np.where(detached)
    pin = np.full(alpha.shape, 255, dtype=np.uint8)
    fragments = []
    if len(xs):
        distances = np.empty((6, len(xs)), dtype=np.float64)
        for row, body in enumerate(body_labels):
            distance = ndimage.distance_transform_edt(strong_labels != body)
            distances[row] = distance[ys, xs]
        nearest = np.argmin(distances, axis=0).astype(np.uint8)
        ordered = np.sort(distances, axis=0)
        margins = ordered[1] - ordered[0]
        if np.any(margins <= MINIMUM_OWNER_MARGIN):
            raise ValueError("Detached foreground has ambiguous physical-body ownership")
        pin[ys, xs] = nearest
        detached_ids = components[ys, xs]
        for component in np.unique(detached_ids):
            selected = detached_ids == component
            rows = np.unique(nearest[selected])
            if len(rows) != 1:
                raise ValueError("A detached fragment changes nearest owner across its pixels")
            row = int(rows[0])
            component_owner[int(component)] = row
            fx, fy = xs[selected], ys[selected]
            fragments.append({"row": row, "pixels": int(selected.sum()),
                              "bbox": [int(fx.min()), int(fy.min()),
                                       int(fx.max()) + 1, int(fy.max()) + 1],
                              "nearest_max": float(ordered[0, selected].max()),
                              "second_nearest_min": float(ordered[1, selected].min()),
                              "owner_margin_min": float(margins[selected].min())})
    owners = component_owner[components]
    return owners, {"ownership_rule": OWNERSHIP_RULE,
                    "nearest_owner_sha256": hashlib.sha256(pin.tobytes()).hexdigest(),
                    "foreground_owner_sha256": hashlib.sha256(owners.tobytes()).hexdigest(),
                    "detached_pixels": int(len(xs)), "detached_fragments": fragments,
                    "minimum_required_owner_margin": MINIMUM_OWNER_MARGIN}


def apply_reviewed_regions(source_path, base_geometry, review):
    """Return (derived geometry, proof) for one explicitly pinned region review.

    Only region, matching AtlasTexture margin, and exact crop hash may change.
    Source anchors, virtual canvas/foot, phase/direction and PNG bytes stay exact.
    All alpha>16 pixels must have exactly one physically correct region owner.
    """
    required = {"status", "source_sha256", "base_geometry_sha256", "direction",
                "review_basis", "regions", "nearest_owner_sha256"}
    allowed = required | {"schema", "ownership_rule"}
    if (not isinstance(review, dict) or not required <= review.keys()
            or set(review) - allowed or review.get("status") != STATUS):
        raise ValueError("An explicit complete REVIEWED_SOURCE_REGIONS_PROPOSAL is required")
    if "schema" in review and (type(review["schema"]) is not int or review["schema"] != 1):
        raise ValueError("Only reviewed source regions schema 1 is supported")
    if review.get("ownership_rule", OWNERSHIP_RULE) != OWNERSHIP_RULE:
        raise ValueError("Unknown reviewed ownership rule")
    if not isinstance(review["review_basis"], str) or not review["review_basis"].strip():
        raise ValueError("A nonempty review_basis is required")
    source_sha = _sha(review["source_sha256"], "source_sha256")
    base_sha = _sha(review["base_geometry_sha256"], "base_geometry_sha256")
    _sha(review["nearest_owner_sha256"], "nearest_owner_sha256")
    review_sha = _digest(review)
    if not isinstance(base_geometry, dict) or _digest(base_geometry) != base_sha:
        raise ValueError("Reviewed base geometry SHA256 does not match")

    path = Path(source_path)
    if path.is_symlink() or not path.is_file():
        raise ValueError("The source must be a regular immutable PNG file")
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != source_sha:
        raise ValueError("Reviewed source SHA256 does not match the exact PNG bytes")
    with Image.open(BytesIO(raw)) as image:
        if image.format != "PNG" or image.mode != "RGBA":
            raise ValueError("The exact source must be an RGBA PNG")
        pixels = np.array(image)
        image_size = list(image.size)
    alpha = pixels[:, :, 3]
    if any(np.any(edge > 100) for edge in (alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1])):
        raise ValueError("A strong physical pose touches the source boundary")

    frames = base_geometry.get("frames")
    if (not isinstance(frames, list) or len(frames) != 6
            or any(not isinstance(frame, dict) for frame in frames)):
        raise ValueError("Base geometry must contain exactly six original poses")
    direction = frames[0].get("direction")
    if (direction not in importer.DIRECTIONS or review["direction"] != direction
            or any(frame.get("direction") != direction for frame in frames)):
        raise ValueError("Reviewed direction must match all six original poses")
    if any(type(frame.get("row")) is not int or frame["row"] != row
           for row, frame in enumerate(frames)):
        raise ValueError("Original pose order must remain rows 0 through 5")
    canvas = base_geometry.get("canvas_size")
    if (not isinstance(canvas, list) or len(canvas) != 2 or canvas[0] != canvas[1]
            or any(type(value) is not int or not 64 <= value <= 2048 for value in canvas)):
        raise ValueError("Base geometry must retain one canonical square canvas")
    anchors = [frame.get("source_anchor") for frame in frames]
    if any(not isinstance(anchor, list) or len(anchor) != 2
           or any(type(value) is not int for value in anchor) for anchor in anchors):
        raise ValueError("Each original source anchor must contain two integers")
    base_rects = [_rect(frame.get("region"), image_size, "Base region") for frame in frames]
    _disjoint(base_rects, "Base")
    fresh = importer.analyze(path, rows_count=6, reference_rows=[0, 3],
                             directions_axis="phase_grid2", canvas_size=canvas[0],
                             source_anchors=anchors, directions=[direction])
    for key in ("image_size", "frames", "distinct_pixel_frames", "neutral_height", "canvas_size", "foot"):
        if base_geometry.get(key) != fresh[key]:
            raise ValueError("Base geometry changed original physical-pose identity or canonical metadata")
    if base_geometry["foot"] != [canvas[0] // 2, canvas[0] * 5 // 8]:
        raise ValueError("The canonical original foot must remain unchanged")

    if not isinstance(review["regions"], list) or len(review["regions"]) != 6:
        raise ValueError("Six explicitly reviewed regions in authored row order are required")
    expanded = [_rect(value, image_size, "Reviewed region") for value in review["regions"]]
    _disjoint(expanded, "Reviewed")
    for old, new in zip(base_rects, expanded):
        if not (new[0] <= old[0] and new[1] <= old[1]
                and new[2] >= old[2] and new[3] >= old[3]):
            raise ValueError("Reviewed regions may only expand the exact original rectangles")

    owners, owner_proof = _foreground_owners(alpha, frames)
    if review["nearest_owner_sha256"] != owner_proof["nearest_owner_sha256"]:
        raise ValueError("Reviewed detached nearest-owner pin does not match")
    region_owner = np.full(alpha.shape, 255, dtype=np.uint8)
    old_covered = np.zeros(alpha.shape, dtype=bool)
    derived = deepcopy(base_geometry)
    hashes, visible_hashes = set(), set()
    for row, ((left, top, right, bottom), frame) in enumerate(zip(expanded, derived["frames"])):
        region_owner[top:bottom, left:right] = row
        ox, oy, ow, oh = frames[row]["region"]
        old_covered[oy:oy + oh, ox:ox + ow] = True
        width, height = right - left, bottom - top
        anchor_x, anchor_y = frame["source_anchor"]
        margin_x = base_geometry["foot"][0] - (anchor_x - left)
        margin_y = base_geometry["foot"][1] - (anchor_y - top)
        if (min(margin_x, margin_y) < 0 or margin_x + width > canvas[0]
                or margin_y + height > canvas[1]):
            raise ValueError("Expanded region cannot fit the unchanged foot-anchored canvas")
        crop = pixels[top:bottom, left:right]
        fingerprint = hashlib.sha256(crop.tobytes()).hexdigest()
        visible = importer._visible_pose_fingerprint(crop)
        if fingerprint in hashes or visible in visible_hashes:
            raise ValueError("Expanded regions must retain six distinct original visible poses")
        hashes.add(fingerprint)
        visible_hashes.add(visible)
        frame.update(region=[left, top, width, height],
                     margin=[margin_x, margin_y, canvas[0] - width, canvas[1] - height],
                     rgba_sha256=fingerprint)
    foreground = alpha > 16
    if np.any(region_owner[foreground] == 255):
        raise ValueError("Reviewed regions omit alpha>16 source pixels")
    if np.any(region_owner[foreground] != owners[foreground]):
        raise ValueError("A reviewed region contains another physical body's foreground")
    importer.require_complete_pose_regions(path, derived)
    if path.read_bytes() != raw:
        raise ValueError("Source PNG bytes changed during reviewed region analysis")
    proof = {"status": "DERIVED_SOURCE_REGIONS_PROPOSAL_NOT_APPROVED",
             "source_sha256": source_sha, "source_RGBA_sha256": hashlib.sha256(pixels.tobytes()).hexdigest(),
             "base_geometry_sha256": base_sha, "derived_geometry_sha256": _digest(derived),
             "review_sha256": review_sha, "review_basis": review["review_basis"],
             "source_unchanged": True, "canonical_canvas_foot_anchors_unchanged": True,
             "all_alpha_gt16_covered_exactly_once": True, "foreign_foreground_pixels": 0,
             "alpha_gt16_pixels": int(foreground.sum()),
             "added_alpha_gt16_pixels": int((foreground & ~old_covered).sum()),
             "all_alpha_positive_covered": bool(np.all(region_owner[alpha > 0] != 255)),
             "expanded_regions": review["regions"], "default_importer_repacker_unchanged": True,
             **owner_proof}
    return derived, proof
