#!/usr/bin/env python3
"""Prepare four action poses while reusing exact same-direction IDLE guards."""
import argparse
import hashlib
import json
from pathlib import Path

import preserve_mixed_draft_guard_clip as compiler

ROOT = Path(__file__).resolve().parents[3]
PREFIX = ROOT / "docs/remake/pr122-legendary-parallel"


def prepare(existing_root, actor_id, direction, role, motion_notes="", output=None):
    existing_root = Path(existing_root).resolve()
    assert str(actor_id).isdigit() and str(actor_id) != "176" and role in ("attack", "hit")
    assert direction in compiler.common.DIRECTIONS
    key = "transform:" + str(actor_id)
    actor = next(a for a in json.loads((ROOT / "data/catalog_v19.json").read_text())["변신"] if str(a["sourceId"]) == str(actor_id))
    assert actor["grade"] == "전설"
    plan = compiler.read_guards(existing_root, key, direction)
    reference = ROOT / actor["image_path"].removeprefix("res://")
    assert hashlib.sha256(reference.read_bytes()).hexdigest() == plan["reference_sha256"]
    refs = [str(reference)] + [str(existing_root / s["path"].removeprefix("res://")) for s in plan["source_files"]]
    if role == "attack":
        steps = ["phase1: articulated anticipation and backswing with coherent grip and weight shift",
                 "phase2: fully loaded torso and knees; original weapon, bow, firearm, rod or casting system ready for its own authentic attack",
                 "phase3: active contact/release/discharge exactly toward the requested facing direction",
                 "phase4: coherent follow-through and partial recovery that leads into the preserved final living guard"]
        action = "Preserve the original equipment's attack kind: do not swing a gun, replace a rod, turn casting into melee, or invent weapons. " + motion_notes
    else:
        steps = ["phase1: initial nonfatal impact response, body recoils away from impact while equipment stays gripped",
                 "phase2: maximum stagger with plausible supporting feet and connected joints",
                 "phase3: counterbalance and brace without attacking or falling dead",
                 "phase4: regain control and approach the preserved final living guard"]
        action = "A brief nonfatal HIT, distinct from ATTACK and DEATH. No weapon strike, firing, casting, blood or wounds. " + motion_notes
    prompt = (f'TWILIGHT {key}, {actor["name"]}: create ONLY FOUR NEW {direction} {role.upper()} middle poses. '
              'The first original catalog PNG is identity authority. The second saved same-character/same-direction IDLE atlas is authoritative for the existing draft guard, body scale, camera, equipment hand, ground level and rendering. '
              'Its first top-left cell (IDLE frame0) and last bottom-right cell (IDLE frame5) will be reused EXACTLY as action frames0 and5. DO NOT redraw, output, mirror or modify these guards. '
              'Create ONE transparent RGBA source PNG, ideally 1024x1024, exactly TWO equal columns and TWO equal rows, reading order cell0..3. One complete full-body new pose per cell. '
              f'All four face {direction} at the same elevated game camera as the supplied {direction} IDLE; newly articulate body parts without changing its orientation or substituting a front/back view. '
              'Match the existing 512x512 IDLE cell sprite scale and placement when possible; keep full head/hair, all feet, original costume and the entire original equipment inside every cell with generous transparent gutters. '
              'Preserve exact catalog identity, original weapon/armor silhouette, colors, face, anatomy and original anatomical equipment hand. No invented shield, wings, tail, new weapons or generic model. '
              'Only output these middle poses: ' + '; '.join(f'cell{i}, {s}' for i, s in enumerate(steps)) + '. '
              + action + ' Six-frame assembly will be: preserved IDLE0, new cell0, new cell1, new cell2, new cell3, preserved IDLE5. '
              'Four genuine different joint poses, not translated/rotated/recolored/cloned stills. No duplicate guard cells, text, labels, grids, scenery, ground, opaque/gradient background, extra characters, detached limbs or diffuse effects. Alpha zero outside the full figure. Output only the four-pose supplement.')
    q = {"key": key, "name": actor["name"], "grade": "전설", "direction": direction, "role": role,
         "reference": actor["image_path"], "reference_sha256": plan["reference_sha256"],
         "draft_guard_reuse": plan, "poses": 6, "newly_authored_poses_requested": 4, "reused_poses": 2,
         "generation_request": {"prompt": prompt, "referenced_image_paths": refs, "transparent_background": True},
         "generation_reference_sha256": {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in refs},
         "motion_notes": motion_notes, "status": "REQUESTED_DRAFT_GUARD_SUPPLEMENT_NOT_APPROVED",
         "policy": "Preserve IDLE0/5 pixels and their HOLD status. Reuse adds no approval. transform176 legacy source takes priority. RUN remains six new poses. Existing authored ATTACK/HIT outputs are skipped, never overwritten."}
    path = Path(output) if output else PREFIX / "requests" / f"transform_{actor_id}-{direction}-{role}-guard-supplement-v01.json"
    assert path.resolve().is_relative_to(PREFIX.resolve()) and not path.exists() and not path.is_symlink()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x") as handle:
        handle.write(json.dumps(q, ensure_ascii=False, indent=2) + "\n")
    return path, q


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--existing-root", type=Path, required=True)
    parser.add_argument("--id", required=True)
    parser.add_argument("--direction", choices=compiler.common.DIRECTIONS, required=True)
    parser.add_argument("--role", choices=("attack", "hit"), required=True)
    parser.add_argument("--motion-notes", default="")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    path, q = prepare(args.existing_root, args.id, args.direction, args.role, args.motion_notes, args.output)
    print(json.dumps({"request": str(path), "newly_authored_poses_requested": 4, "reused_poses": 2,
                      "guard_quality": q["draft_guard_reuse"]["source_visual_status"], "generation_called": False}))
