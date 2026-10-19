"""Derive reviewed virtual-canvas metadata without changing any source pixels."""

import hashlib
import json
from pathlib import Path

import import_original_based_motion as importer


def _digest(value):
    try:
        encoded = json.dumps(value, sort_keys=True, separators=(",", ":"),
                             allow_nan=False).encode("utf-8")
    except (TypeError, ValueError) as error:
        raise ValueError("Geometry must contain finite JSON metadata") from error
    return hashlib.sha256(encoded).hexdigest()


def _pose_identity(frame):
    return {key: frame.get(key) for key in ("row", "direction", "region", "rgba_sha256")}


def apply_reviewed_layout(source_path, base_geometry, review):
    """Return ``(geometry, proof)`` for a SHA-pinned six-pose layout proposal.

    A larger virtual canvas reduces runtime body size without resampling its
    PNG. Optional source anchors change metadata only. Neither a valid layout
    nor its proof grants source-art, runtime-scale, or actor approval. A reviewed
    movement permutation changes playback only; each frame retains its authored row.
    Optional per-pose virtual canvases are indexed by authored row before playback.
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
    anchors = review.get("source_anchors")
    if "source_anchors" in review and (
            not isinstance(anchors, list) or len(anchors) != 6
            or any(not isinstance(anchor, list) or len(anchor) != 2
                   or any(type(value) is not int for value in anchor) for anchor in anchors)):
        raise ValueError("Reviewed source_anchors must contain six integer [x, y] pairs")
    derived = importer.analyze(path, rows_count=6, reference_rows=[0, 3],
                               directions_axis="phase_grid2", canvas_size=canvas,
                               source_anchors=anchors, directions=[direction])
    importer.require_complete_pose_regions(path, derived)
    if ([_pose_identity(f) for f in derived["frames"]] != [_pose_identity(f) for f in frames]
            or derived["distinct_pixel_frames"] != 6
            or derived["image_size"] != base_geometry.get("image_size")):
        raise ValueError("Layout changed source regions, RGBA pixels, direction, or phase order")
    if derived["foot"] != [canvas // 2, canvas * 5 // 8]:
        raise ValueError("Derived layout changed the canonical half-width, five-eighths foot")
    if hashlib.sha256(path.read_bytes()).hexdigest() != source_sha:
        raise ValueError("Source bytes changed during layout analysis")
    if "authored_pose_canvas_sizes" in review:
        sizes = review["authored_pose_canvas_sizes"]
        if canvas != 2048:
            raise ValueError("Per-pose canvases require strict nominal canvas_size 2048")
        if (not isinstance(sizes, list) or len(sizes) != 6
                or any(type(value) is not int or not 256 <= value <= 4096 or value % 8
                       for value in sizes)):
            raise ValueError("authored_pose_canvas_sizes must contain six integer multiples of 8 from 256 to 4096")
        for frame, size in zip(derived["frames"], sizes):
            x, y, width, height = frame["region"]
            anchor_x, anchor_y = frame["source_anchor"]
            foot_x, foot_y = size // 2, size * 5 // 8
            margin_x, margin_y = foot_x - (anchor_x - x), foot_y - (anchor_y - y)
            if min(margin_x, margin_y) < 0 or margin_x + width > size or margin_y + height > size:
                raise ValueError("Pose cannot fit its reviewed per-pose foot-anchored canvas")
            frame.update(margin=[margin_x, margin_y, size - width, size - height],
                         canvas_size=[size, size], foot=[foot_x, foot_y])
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
    if "playback_order" in review:
        proof.update(playback_order=list(review["playback_order"]), newly_authored_poses=0)
    if "authored_pose_canvas_sizes" in review:
        sizes = [frame["canvas_size"][0] for frame in derived["frames"]]
        proof.update(pose_canvas_sizes=sizes, runtime_reference_canvas_size=1024,
                     per_pose_runtime_pixel_scale_ratios=[[1024, size] for size in sizes],
                     pose_canvas_size_allowed_range=[256, 4096],
                     runtime_pixel_scale_ratio=[1024, canvas], newly_authored_poses=0)
    return derived, proof
