"""Derive reviewed virtual-canvas metadata without changing any source pixels."""

from copy import deepcopy
import hashlib
import json
import math
from pathlib import Path

import import_original_based_motion as importer


def _digest(value):
    try:
        encoded = json.dumps(value, sort_keys=True, separators=(",", ":"),
                             allow_nan=False).encode("utf-8")
    except (TypeError, ValueError) as error:
        raise ValueError("Geometry must contain finite JSON metadata") from error
    return hashlib.sha256(encoded).hexdigest()



def declared_canonical_preflight_kwargs(canvas_review, layout_review, source_sha, direction, canvas):
    """Optional exact declared-root seed; absent descriptors retain legacy kwargs."""
    a = (canvas_review or {}).get("canonical_preflight")
    b = (layout_review or {}).get("canonical_preflight")
    if a != b:
        raise ValueError("Canonical preflight must be identical in canvas and layout reviews")
    if a is None:
        return {}
    required = {"status", "source_sha256", "packing_proof_sha256", "direction",
                "canonical_canvas", "physical_canvases", "root_float", "root_integer",
                "tile_size", "storage_translations", "atlas_origins", "source_anchors"}
    if not isinstance(a, dict) or set(a) != required:
        raise ValueError("Exact complete declared canonical preflight required")
    if a["status"] != "REVIEWED_FIXED_RIG_CANONICAL_PREFLIGHT_V1" or canvas != 2048 or a["canonical_canvas"] != canvas:
        raise ValueError("Declared bridge preserves canonical2048")
    if a["source_sha256"] != source_sha or a["direction"] != direction or direction not in importer.DIRECTIONS:
        raise ValueError("Declared preflight source/direction mismatch")
    for field in ("source_sha256", "packing_proof_sha256"):
        if not isinstance(a[field], str) or len(a[field]) != 64 or any(c not in "0123456789abcdef" for c in a[field]):
            raise ValueError("Declared preflight exact SHA256 required")
    pin = _digest(a)
    if any((r or {}).get("canonical_preflight_sha256") != pin for r in (canvas_review, layout_review)):
        raise ValueError("Declared canonical preflight pin mismatch")
    sizes = a["physical_canvases"]
    if not isinstance(sizes, list) or len(sizes) != 6 or any(type(v) is not int or not 256 <= v <= 4096 or v % 8 for v in sizes) or len(set(sizes)) != 1:
        raise ValueError("Six identical declared physical body canvases required")
    if (layout_review or {}).get("authored_pose_canvas_sizes") != sizes:
        raise ValueError("Canonical bridge physical C differs from final authored C")
    root = a["root_float"]
    if not isinstance(root, list) or len(root) != 2 or any(type(v) not in (int,float) or not math.isfinite(v) for v in root):
        raise ValueError("One finite declared root required")
    rounded = [math.floor(v + .5) for v in root]
    if not isinstance(a["root_integer"], list) or len(a["root_integer"]) != 2 or any(type(v) is not int for v in a["root_integer"]) or a["root_integer"] != rounded:
        raise ValueError("Only one common declared-root rounding allowed")
    tile = a["tile_size"]
    if type(tile) is not int or tile not in (1536,2304):
        raise ValueError("Unchanged explicit storage sizes required")
    offsets = a["storage_translations"]
    if not isinstance(offsets, list) or len(offsets) != 6 or any(not isinstance(v,list) or len(v) != 2 or any(type(x) is not int or x < 0 for x in v) for v in offsets):
        raise ValueError("Explicit six storage-only translations required")
    origins = [[tile*(i%2), tile*(i//2)] for i in range(6)]
    if not isinstance(a["atlas_origins"], list) or len(a["atlas_origins"]) != 6 or any(not isinstance(v,list) or len(v) != 2 or any(type(x) is not int for x in v) for v in a["atlas_origins"]) or a["atlas_origins"] != origins:
        raise ValueError("Fixed phase-grid tile origins required")
    anchors = [[rounded[j]+offsets[i][j]+origins[i][j] for j in (0,1)] for i in range(6)]
    if not isinstance(a["source_anchors"], list) or len(a["source_anchors"]) != 6 or any(not isinstance(v,list) or len(v) != 2 or any(type(x) is not int for x in v) for v in a["source_anchors"]) or a["source_anchors"] != anchors or (layout_review or {}).get("source_anchors") != anchors:
        raise ValueError("Only declared root plus storage plus tile origin may seed canonical geometry")
    return {"source_anchors": anchors}

def _pose_identity(frame):
    return {key: frame.get(key) for key in ("row", "direction", "region", "rgba_sha256")}


def _validated_authored_canvas_sizes(review, canvas):
    if "authored_pose_canvas_sizes" not in review:
        return None
    sizes = review["authored_pose_canvas_sizes"]
    if canvas != 2048:
        raise ValueError("Per-pose canvases require strict nominal canvas_size 2048")
    if (not isinstance(sizes, list) or len(sizes) != 6
            or any(type(value) is not int or not 256 <= value <= 4096 or value % 8
                   for value in sizes)):
        raise ValueError("authored_pose_canvas_sizes must contain six integer multiples of 8 from 256 to 4096")
    return list(sizes)


def _apply_actual_pose_layout(geometry, canvas, sizes, anchors):
    # Validate against each authored physical canvas before playback permutation.
    # The nominal canvas remains only the reference metadata when sizes exist.
    for row, frame in enumerate(geometry["frames"]):
        size = sizes[row] if sizes is not None else canvas
        x, y, width, height = frame["region"]
        anchor_x, anchor_y = anchors[row] if anchors is not None else frame["source_anchor"]
        if not (x <= anchor_x < x + width and y <= anchor_y < y + height):
            raise ValueError("Reviewed source anchor must remain inside its exact source region")
        foot_x, foot_y = size // 2, size * 5 // 8
        margin_x, margin_y = foot_x - (anchor_x - x), foot_y - (anchor_y - y)
        if min(margin_x, margin_y) < 0 or margin_x + width > size or margin_y + height > size:
            raise ValueError("Pose cannot fit its reviewed physical foot-anchored canvas")
        frame.update(source_anchor=[anchor_x, anchor_y],
                     margin=[margin_x, margin_y, size - width, size - height])
        if sizes is not None:
            frame.update(canvas_size=[size, size], foot=[foot_x, foot_y])


def apply_reviewed_layout(source_path, base_geometry, review, *, source_region_review=None):
    """Return ``(geometry, proof)`` for a SHA-pinned six-pose layout proposal.

    A larger virtual canvas reduces runtime body size without resampling its
    PNG. Optional source anchors change metadata only. Neither a valid layout
    nor its proof grants source-art, runtime-scale, or actor approval. A reviewed
    movement permutation changes playback only; each frame retains its authored row.
    Optional per-pose virtual canvases are indexed by authored row before playback.
    An explicit source-region review is validated against fresh canonical source
    geometry before its exact expanded result can receive layout metadata.
    """
    if not isinstance(review, dict) or review.get("status") != "REVIEWED_LAYOUT_PROPOSAL":
        raise ValueError("An explicit REVIEWED_LAYOUT_PROPOSAL is required")
    if not isinstance(review.get("review_basis"), str) or not review["review_basis"].strip():
        raise ValueError("A nonempty review_basis is required")
    canvas = review.get("canvas_size")
    if type(canvas) is not int or not 256 <= canvas <= 2048 or canvas % 8:
        raise ValueError("Reviewed canvas_size must be a multiple of 8 from 256 to 2048")
    path = Path(source_path)
    if path.is_symlink() or not path.is_file():
        raise ValueError("The source must be a regular immutable PNG file")
    source_sha = hashlib.sha256(path.read_bytes()).hexdigest()
    if review.get("source_sha256") != source_sha:
        raise ValueError("Reviewed source SHA256 does not match the exact source bytes")
    if not isinstance(base_geometry, dict):
        raise ValueError("Base geometry is required")
    frames = base_geometry.get("frames")
    if not isinstance(frames, list) or len(frames) != 6 or any(not isinstance(f, dict) for f in frames):
        raise ValueError("Base geometry must contain exactly six ordered poses")
    direction = frames[0].get("direction")
    if direction not in importer.DIRECTIONS or any(f.get("direction") != direction for f in frames):
        raise ValueError("All six poses must share one explicit valid direction")
    if "direction" in review and review["direction"] != direction:
        raise ValueError("Reviewed direction differs from the source geometry")
    if any(type(f.get("row")) is not int or f["row"] != i for i, f in enumerate(frames)):
        raise ValueError("Base pose order must be exactly phases 0 through 5")
    fingerprints = [f.get("rgba_sha256") for f in frames]
    if (any(not isinstance(value, str) or len(value) != 64 for value in fingerprints)
            or len(set(fingerprints)) != 6 or base_geometry.get("distinct_pixel_frames") != 6):
        raise ValueError("Base geometry must retain six distinct RGBA poses")
    base_canvas = base_geometry.get("canvas_size")
    if (not isinstance(base_canvas, list) or len(base_canvas) != 2
            or any(type(value) is not int or value <= 0 for value in base_canvas)
            or base_canvas[0] != base_canvas[1]):
        raise ValueError("Base geometry must identify its square virtual canvas")
    sizes = _validated_authored_canvas_sizes(review, canvas)
    canonical_kwargs = declared_canonical_preflight_kwargs(review, review, source_sha, direction, base_canvas[0])
    if canonical_kwargs and canonical_kwargs["source_anchors"] != [f.get("source_anchor") for f in frames]:
        raise ValueError("Declared canonical roots differ from exact base geometry")
    anchors = review.get("source_anchors")
    if "source_anchors" in review and (
            not isinstance(anchors, list) or len(anchors) != 6
            or any(not isinstance(anchor, list) or len(anchor) != 2
                   or any(type(value) is not int for value in anchor) for anchor in anchors)):
        raise ValueError("Reviewed source_anchors must contain six integer [x, y] pairs")
    if source_region_review is None:
        # Reviewed physical anchors may not fit the nominal reference canvas.
        # Revalidate source identity with its original canonical anchors first.
        seed_anchors = [f.get("source_anchor") for f in frames] if sizes is not None else anchors
        derived = importer.analyze(path, rows_count=6, reference_rows=[0, 3],
                                   directions_axis="phase_grid2", canvas_size=canvas,
                                   source_anchors=seed_anchors, directions=[direction])
        if sizes is not None:
            _apply_actual_pose_layout(derived, canvas, sizes, anchors)
    else:
        # The original automatic rectangles can legitimately fail the complete-
        # foreground gate. Validate the explicit region review before that gate,
        # never by reanalyzing the expanded rectangles as an automatic layout.
        import pr122_reviewed_source_regions as reviewed_regions

        canonical = importer.analyze(path, rows_count=6, reference_rows=[0, 3],
                                     directions_axis="phase_grid2", canvas_size=base_canvas[0],
                                     directions=[direction], **canonical_kwargs)
        checked, _ = reviewed_regions.apply_reviewed_regions(path, canonical, source_region_review)
        if checked != base_geometry or _digest(checked) != _digest(base_geometry):
            raise ValueError("Reviewed expanded geometry differs from the supplied exact base geometry")
        derived = deepcopy(checked)
        foot_x, foot_y = canvas // 2, canvas * 5 // 8
        derived.update(canvas_size=[canvas, canvas], foot=[foot_x, foot_y])
        _apply_actual_pose_layout(derived, canvas, sizes, anchors)
    importer.require_complete_pose_regions(path, derived)
    if ([_pose_identity(f) for f in derived["frames"]] != [_pose_identity(f) for f in frames]
            or derived["distinct_pixel_frames"] != 6
            or derived["image_size"] != base_geometry.get("image_size")):
        raise ValueError("Layout changed source regions, RGBA pixels, direction, or phase order")
    if derived["foot"] != [canvas // 2, canvas * 5 // 8]:
        raise ValueError("Derived layout changed the canonical half-width, five-eighths foot")
    if hashlib.sha256(path.read_bytes()).hexdigest() != source_sha:
        raise ValueError("Source bytes changed during layout analysis")
    if "playback_order" in review:
        order = review["playback_order"]
        if review.get("role") not in ("walk", "run"):
            raise ValueError("Reviewed playback_order is only allowed for walk/run")
        if (not isinstance(order, list) or len(order) != 6
                or any(type(value) is not int for value in order)
                or sorted(order) != list(range(6))):
            raise ValueError("Reviewed playback_order must be an exact integer permutation of 0 through 5")
        derived["frames"] = [derived["frames"][phase] for phase in order]
        derived["authored_phase_order"] = list(order)
    proof = {"status": "DERIVED_LAYOUT_PROPOSAL_NOT_APPROVED", "source_sha256": source_sha,
             "base_geometry_sha256": _digest(base_geometry), "derived_geometry_sha256": _digest(derived),
             "review_sha256": _digest(review), "review_basis": review["review_basis"],
             "direction": direction, "pose_count": 6, "canvas_size": derived["canvas_size"],
             "foot": derived["foot"], "source_anchors": [f["source_anchor"] for f in derived["frames"]],
             "runtime_pixel_scale_ratio": [base_canvas[0], canvas],
             "source_pixels_unchanged": True, "resampled": False, "approval_granted": False}
    if source_region_review is not None:
        proof["source_region_review_sha256"] = _digest(source_region_review)
    if "playback_order" in review:
        proof.update(playback_order=list(review["playback_order"]), newly_authored_poses=0)
    if "authored_pose_canvas_sizes" in review:
        sizes = [frame["canvas_size"][0] for frame in derived["frames"]]
        proof.update(pose_canvas_sizes=sizes, runtime_reference_canvas_size=1024,
                     per_pose_runtime_pixel_scale_ratios=[[1024, size] for size in sizes],
                     pose_canvas_size_allowed_range=[256, 4096],
                     runtime_pixel_scale_ratio=[1024, canvas], newly_authored_poses=0)
    return derived, proof
