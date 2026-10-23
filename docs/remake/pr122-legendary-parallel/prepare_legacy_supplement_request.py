#!/usr/bin/env python3
"""Write exact missing-pose requests; does not call any generation service.

Usage: prepare_legacy_supplement_request.py --existing-root CHECKOUT --role death --direction S
       prepare_legacy_supplement_request.py --existing-root CHECKOUT --matrix-only
Only missing poses are requested; current production-order control belongs to
the caller. Existing requests and output clips are never overwritten.
"""
import argparse
import hashlib
import json
from pathlib import Path

import preserve_mixed_legacy_clip as compiler

ROOT = Path(__file__).resolve().parents[3]
PREFIX = ROOT / "docs/remake/pr122-legendary-parallel"
VIEWS = {
    "E": "true screen-RIGHT side profile, original anatomy and view-dependent equipment occlusion",
    "SE": "three-quarter FRONT-RIGHT view facing screen DOWN-RIGHT",
    "S": "the same elevated FRONT view facing screen DOWN",
    "SW": "three-quarter FRONT-LEFT view facing screen DOWN-LEFT",
    "W": "true screen-LEFT side profile, original anatomy and view-dependent equipment occlusion",
    "NW": "three-quarter BACK-LEFT view facing screen UP-LEFT",
    "N": "full BACK view facing screen UP, back of helmet and cape visible, NO front-facing face",
    "NE": "three-quarter BACK-RIGHT view facing screen UP-RIGHT",
}
MISSING = {
    "attack": [
        "final phase1: loaded compression between the preserved windup and launch; knees and shoulders load the original polearm while its grip remains connected",
        "final phase2: accelerating partial extension immediately BEFORE the preserved full-contact thrust, original polearm tip directed toward the facing target",
        "final phase4: immediate thrust follow-through and beginning retraction AFTER the preserved contact and BEFORE the preserved recovery; maintain the same attack axis",
    ],
    "death": [
        "final phase1: knees and hips sink further after preserved death-begin, grip and armor still connected, balance irreversibly failing",
        "final phase2: actual body fall between collapse-begin and the preserved near-ground falling/impact frame; chest drops and knees fold naturally",
        "final phase4: ground settling AFTER the preserved fall/impact and BEFORE the preserved final corpse; armor, original cape and polearm physically settle into the final pose",
    ],
    "hit": [
        "final phase1: intensify the preserved initial hit recoil into a distinct maximum nonfatal stagger, torso bends away from impact and original weapon stays safely held",
        "final phase2: counterbalance the maximum recoil before the preserved recovery frame, knees brace and arms stabilize the original weapon without attacking",
        "final phase4: after the preserved recovery, settle remaining shoulder, cape and weapon motion toward readiness with a new articulated pose",
        "final phase5: regained living guard, still recognizably distinct from preserved recovery and the preceding settling pose; no injury, fall, cast or attack",
    ],
    "idle": [
        "final phase1: begin inhalation after preserved neutral breathing, stable planted feet and original weapon hand, slight real torso/equipment articulation",
        "final phase2: continue inhalation toward the preserved second breathing frame, connected shoulders and cape react without walking or attacking",
        "final phase4: exhale after the preserved second breathing frame, original cape and equipment settle while the root and feet remain planted",
        "final phase5: complete exhalation toward preserved initial neutral for a seamless loop, a distinct subtle real pose rather than a translated duplicate",
    ],
}


def write_new_json(path, value):
    path = Path(path)
    assert path.resolve().is_relative_to(PREFIX.resolve()), "Write only the dedicated new prefix"
    assert not path.exists() and not path.is_symlink(), "Preserve existing request; do not redo it"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x") as handle:
        handle.write(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def request(existing_root, direction, role, output=None):
    existing_root = Path(existing_root).resolve()
    key = "transform:176"
    assert direction in compiler.DIRECTIONS and role in MISSING
    assert role != "death" or direction == "S"
    catalog = json.loads((ROOT / "data/catalog_v19.json").read_text())
    actor = next(a for a in catalog["변신"] if str(a["sourceId"]) == "176")
    assert actor["grade"] == "전설"
    legacy = compiler.read_legacy_track(existing_root, key, role, direction)
    config = compiler.six_pose_config(legacy)
    reference_uri = actor["image_path"]
    reference_path = ROOT / reference_uri.removeprefix("res://")
    assert reference_path.is_file()
    reference_sha = hashlib.sha256(reference_path.read_bytes()).hexdigest()
    assert reference_sha == legacy["reference"]["sha256"]
    cols, rows = config["new_source_grid"]
    count = legacy["new_poses"]
    required = MISSING[role]
    assert len(required) == count
    old_phases = ", ".join(f'pose{f["original_pose_id"]} at final phase{timing["final_phase"]}'
                           for f, timing in zip(legacy["frames"], config["reused_pose_start_times"]))
    old_coordinates = "; ".join(f'pose{f["original_pose_id"]} source rectangle x{f["region"][0]} y{f["region"][1]} w{f["region"][2]} h{f["region"][3]}'
                                for f in legacy["frames"])
    body = (f'TWILIGHT {key} {actor["name"]}: author ONLY {count} missing {direction} {role.upper()} poses. '
            f'The catalog portrait is identity authority; the additional unchanged legacy atlas establishes exact painted sprite style, small native sprite scale, facing and original hand/equipment. '
            f'Existing {legacy["reused_poses"]} poses are preserved byte-for-byte and must NOT be redrawn: {old_phases}. '
            f'Their atlas coordinates are {old_coordinates}. '
            f'Create ONE transparent RGBA PNG with EXACTLY {cols} equal columns and {rows} equal rows, {count} new full-body poses in reading order. '
            f'Every pose uses {VIEWS[direction]}; no facing or camera changes. '
            'Keep the exact silver-white closed pointed helmet and armor, dark joints, deep dark-purple cape, one original lavender-bladed long polearm, original anatomical weapon hand, body proportions and ornament. '
            'Use the small native sprite scale of the preserved atlas, not an enlarged portrait. Keep all bodies, complete polearm blade and butt, hands, feet and cape inside their own cells with generous transparent gutters. '
            'Do not replace the original weapon or add a shield, facial skin, wings, tail or extra equipment. '
            'NEW CELLS ONLY: ' + "; ".join(f'cell{i}: {step}' for i, step in enumerate(required)) + '. '
            'Articulate connected joints and equipment into different real poses; never copy, mirror, rotate, translate, recolor or interpolate a static sprite. '
            'No labels, grid, captions, extra figures, scenery, opaque background, ground, shadows, detached effects, large aura or long trails. Alpha-zero outside silhouettes. ')
    if role == "attack":
        body += 'The same original polearm performs a directional thrust; contact axis must match facing. No sideways axe chop, spin, casting or hit recoil.'
    elif role == "death":
        body += 'This is one irreversible fall toward the preserved motionless final corpse, not a bow, kneel, attack or hit recovery. No gore or detached armor/limbs.'
    elif role == "hit":
        body += 'This is a brief nonfatal impact and recovery, distinct from attack and death. No weapon swing toward a target, firing, casting, wounds or blood.'
    else:
        body += 'Living breathing loop with stable foot contact. No step, running, jumping, attack or head-bobbing translation. Last phase leads smoothly into preserved first neutral.'
    refs = [str(reference_path)] + [s["local_path"] for s in legacy["source_files"]]
    q = {"key": key, "name": actor["name"], "grade": "전설", "direction": direction, "role": role,
         "reference": reference_uri, "reference_sha256": reference_sha,
         "legacy_frames_path": legacy["legacy_frames_path"], "legacy_frames_sha256": legacy["legacy_frames_sha256"],
         "legacy_provenance_sha256": legacy["legacy_provenance_sha256"],
         "legacy_source_files": [{k: v for k, v in s.items() if k != "local_path"} for s in legacy["source_files"]],
         "existing_pose_metadata": legacy["frames"], "six_pose_config": config,
         "poses": 6, "newly_authored_poses_requested": count, "reused_poses": legacy["reused_poses"],
         "generation_request": {"prompt": body, "referenced_image_paths": refs, "transparent_background": True},
         "generation_reference_sha256": {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in refs},
         "status": "REQUEST_TEMPLATE_NOT_GENERATED", "actor_approvals_added": 0,
         "policy": "Follow caller production-stage order. Generate only missing poses; preserve source pixels, all old WALK/death views and old approvals. Scale/visual issues HOLD; no image resizing or final approval inferred."}
    path = Path(output) if output else PREFIX / "requests" / f"transform_176-{direction}-{role}-supplement-v01.json"
    write_new_json(path, q)
    return path, q


def matrix(existing_root):
    tracks = []
    # Same production order as the authorized legendary work, 33 required blocks.
    order = [("S", role) for role in ("attack", "run", "death", "hit", "idle")]
    order += [(direction, role) for direction in ("E", "SE", "SW", "W", "NW", "N", "NE")
              for role in ("idle", "run", "attack", "hit")]
    for direction, role in order:
        if role == "run":
            tracks.append({"key": "transform:176", "direction": direction, "role": role,
                           "poses": 6, "newly_authored_poses_required": 6, "reused_poses": 0,
                           "status": "NO_LEGACY_RUN_USE_SIX_NEW_PIPELINE", "legacy_walk_relabel_allowed": False})
            continue
        legacy = compiler.read_legacy_track(existing_root, "transform:176", role, direction)
        tracks.append({"key": "transform:176", "direction": direction, "role": role, "poses": 6,
                       "newly_authored_poses_required": legacy["new_poses"], "reused_poses": legacy["reused_poses"],
                       "legacy_frames_path": legacy["legacy_frames_path"], "legacy_frames_sha256": legacy["legacy_frames_sha256"],
                       "legacy_source_files": [{k: v for k, v in s.items() if k != "local_path"} for s in legacy["source_files"]],
                       "legacy_duration_seconds": legacy["legacy_duration_seconds"],
                       "legacy_nominal_duration_seconds": legacy["legacy_nominal_duration_seconds"],
                       "existing_pose_metadata": legacy["frames"], "six_pose_config": compiler.six_pose_config(legacy),
                       "missing_pose_cells_template": MISSING[role], "loop": role == "idle",
                       "terminal_frame_hold": role == "death", "status": "PARTIAL_ACTUAL_SOURCE_REUSE_ELIGIBLE_NOT_APPROVED"})
    assert len(tracks) == 33
    result = {"schema": "pr122-legendary-176-exact-partial-reuse-matrix-v1", "key": "transform:176",
              "required_tracks": 33, "required_poses": 198,
              "actual_legacy_poses_eligible_for_reuse": sum(t["reused_poses"] for t in tracks),
              "newly_authored_poses_required": sum(t["newly_authored_poses_required"] for t in tracks),
              "old_source_regions_margins_rgba_checked": "PASS",
              "all_legacy_pose_start_times_and_total_duration_preserved": True,
              "walk_and_eight_existing_death_views_preserved": True,
              "new_death_direction": "S", "source_quality_approval": "HOLD_NOT_REVIEWED",
              "actor_approvals_added": 0, "tracks": tracks,
              "already_produced_tracks_are_skipped_by_no_overwrite_compilers": True,
              "request_preparation_is_not_generation_or_production_completion": True}
    assert result["actual_legacy_poses_eligible_for_reuse"] + result["newly_authored_poses_required"] == 198
    path = PREFIX / "transform_176-reuse-matrix-v01.json"
    write_new_json(path, result)
    return path, result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--existing-root", type=Path, required=True)
    parser.add_argument("--role", choices=list(MISSING))
    parser.add_argument("--direction", choices=compiler.DIRECTIONS)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--matrix-only", action="store_true")
    args = parser.parse_args()
    if args.matrix_only:
        path, result = matrix(args.existing_root)
        print(json.dumps({"matrix": str(path), "reuse_eligible_poses": result["actual_legacy_poses_eligible_for_reuse"],
                          "missing_new_poses": result["newly_authored_poses_required"], "generated_poses": 0}))
    else:
        assert args.role and args.direction, "Choose role and direction; caller retains production order"
        path, result = request(args.existing_root, args.direction, args.role, args.output)
        print(json.dumps({"request": str(path), "new_poses_requested": result["newly_authored_poses_requested"],
                          "reused_poses": result["reused_poses"], "generation_called": False}))
