"""Freeze truthful source/quality/playback evidence for the parent to commit."""
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
FOLDER = ROOT / "assets/actors/eight_direction/monster_boss_repair/ice_queen/r001"


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def rel(p):
    return p.relative_to(ROOT).as_posix()


def pin(p):
    return {"path": rel(p), "bytes": p.stat().st_size, "sha256": sha(p)}


def save(name, obj):
    p = OUT/name
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n")


candidate = json.loads((OUT/"candidate.json").read_text())
actor = candidate["actors"]["monster:얼음 여왕"]
playback = json.loads((OUT/"playback/report.json").read_text())
assert playback["clips"] == 7 and playback["poses"] == 42
assert playback["actual_ActorMotion_playback"] == "PASS"
all_rgba = [f["rgba_sha256"] for t in actor["tracks"] for f in t["geometry"]["frames"]]
assert len(set(all_rgba)) == len(all_rgba) == 42
for track in actor["tracks"]:
    source, texture = ROOT/track["source"], ROOT/track["texture"]
    assert sha(source) == track["source_sha256"] == sha(texture)
    assert Image.open(texture).mode == "RGBA"

old_n = ROOT/"docs/remake/evidence/pr122-monsters-20261023/batch03-queen/raw/queen-N-run6-v01.png"
review = {
    "schema": "pr122-queen-run-repair-private-visual-review-v1",
    "reviewed_at_utc": datetime.now(timezone.utc).isoformat(),
    "actor": "monster:얼음 여왕", "quality_tier": "mythic_transform",
    "status": "HOLD_FINAL_INDEPENDENT_QA", "new_approvals": 0,
    "actual_reference_examined": pin(OUT/"references/queen-project-canonical-crop.png"),
    "actual_selected_sources_examined": [pin(ROOT/t["source"]) for t in actor["tracks"]],
    "actual_registered_preview_examined": pin(OUT/"private/normalized-run7-contactsheet.png"),
    "actual_crown_sole_landmarks_examined": pin(OUT/"private/crown-sole-landmarks.png"),
    "observed_improvements": [
        {"criterion": "opposite_support", "result": "OBSERVED_SOURCE_IMPROVEMENT", "views": ["E", "SE", "S", "SW"],
         "observation": "Source slot0 and slot1 now show different forward planted legs: bare RIGHT-slit leg versus dark-covered LEFT leg. Slots2/3 also show opposite lifted knees. Playback order [0,2,4,1,3,5] keeps the two stride halves instead of repeating the same exposed leading leg."},
        {"criterion": "NE_camera", "result": "OBSERVED_SOURCE_IMPROVEMENT", "views": ["NE"],
         "observation": "NE v02 shows back of head/crown, flowing rear hair and back armor; face and front breastplate are turned away. This corrects the previous E/SE-like frontal NE source. Exact angular separation from adjacent views is still final QA."},
        {"criterion": "SW_camera", "result": "OBSERVED_SOURCE_IMPROVEMENT", "views": ["SW"],
         "observation": "SW v02 actually faced right and was rejected. SW v03 faces left/front with wings trailing screen right and is the selected source."},
        {"criterion": "source_density", "result": "REGISTRATION_TECHNICAL_PASS", "views": [t["direction"] for t in actor["tracks"]],
         "observation": "Separate manual crown-apex to contact-sole measurements exclude staff orb and high wing tips. Directional logical canvases plus one 86/140 profile scale produce 85.471–86.465 px median contact-body heights without resizing or recoloring any source pixels."},
        {"criterion": "gross_clipping_body_collapse", "result": "NONE_OBSERVED_IN_SELECTED_42_SAMPLES", "views": [t["direction"] for t in actor["tracks"]],
         "observation": "All selected regions pass unchanged component/whole-visible-pixel guards, and the registered private six-phase sheets show complete crown/staff/wing/boot silhouettes. This is a first-pass observation, not mythic approval."},
    ],
    "held_directions": actor["held_directions"],
    "held_sources": [{**row, "sha256": sha(ROOT/row["source"])} for row in actor["held_sources"]],
    "existing_N_reuse_probe": {
        "source": pin(old_n), "actual_private_vision": True, "selected": False,
        "finding": "Dedicated queen rear artwork retains back hair/crown, both wing roots and viewer-left LEFT-hand staff. The exposed bare slit thigh is also viewer-left in all cells; in straight rear view this contradicts the canonical anatomical RIGHT slit. Preserve the source without forcing it into the repaired RUN profile.",
    },
    "ground_registration_limit": "Contact source slots0/1 (playback phases0/3) use manually reviewed sole baselines. Other support baselines use the lowest visible bound estimate; flight slots register an invisible plane12 source pixels below the visible pose bound. These metadata estimates are NOT proof of anatomical sole contact on a moving-world ground plane. All source rectangles and RGBA hashes remain unchanged.",
    "unseen_not_reviewed": [
        "Actual default Main presentation and attack/target hitbox interaction",
        "Independent timed moving-world support/sole slip/flight-plane QA at DB speed",
        "Final 8-view angular separation, particularly E versus SE and W versus SW",
        "Rear-view exact hand/slit anatomical continuity, ornament/crown palette and wing-root anatomy at mythic acceptance level",
        "A completed new N run clip: three new N attempts and the old N reuse probe remain HOLD",
        "N v04 actual image was not visually accepted; strict foreign-body rectangle failure already prevents selection",
        "New IDLE/ATTACK/HIT/DEATH are produced separately; this candidate contains RUN only",
    ],
    "existing_approvals_and_assets_preserved": True,
}
save("quality-review.json", review)
checks = {
    "schema": "pr122-queen-run-repair-final-checkpoint-v1",
    "read_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
    "new_raw_PNG_sources": 12, "new_selected_RUN_clips": 7, "new_selected_RUN_poses": 42,
    "distinct_selected_RGBA_frames": 42, "source_HOLDs": 5,
    "strict_geometry_failure_sources": 2, "visual_rejected_sources": 3,
    "selected_strict2048_and_normalized_geometry": "PASS",
    "selected_source_RGBA_byte_preservation": "PASS",
    "SpriteFrames_and_native_profile": "PASS", "actual_Godot_ActorMotion_playback": "PASS",
    "Godot_engine": playback["engine"],
    "N_run": "HOLD_NOT_CONNECTED", "missing_required_tracks": actor["missing_required_tracks"],
    "new_approvals": 0, "default_catalog_switches": 0, "new_WALK": 0,
    "existing_WALK_DEATH_RUN48_and_approvals_preserved": True,
    "candidate": pin(OUT/"candidate.json"), "playback_report": pin(OUT/"playback/report.json"),
}
save("checkpoint.json", checks)
receipts = sorted((OUT/"requests").glob("*-result.json"))
called = {p.name.replace("-result.json", ".json") for p in receipts}
unused = [rel(p) for p in sorted((OUT/"requests").glob("*.json")) if not p.name.endswith("-result.json") and p.name not in called]
log = OUT/"playback/godot.log"
transcript = OUT/"playback/godot-output.txt"
if transcript.exists():
    assert transcript.read_bytes() == log.read_bytes()
else:
    transcript.write_bytes(log.read_bytes())
artifacts = sorted(p for base in [OUT, FOLDER] for p in base.rglob("*") if p.is_file() and p.name != "file-manifest.json" and p != log and "__pycache__" not in str(p))
ignored = []
for p in artifacts:
    if subprocess.run(["git", "check-ignore", "--quiet", "--", rel(p)], cwd=ROOT).returncode == 0:
        ignored.append(rel(p))
assert not ignored, "Generated evidence/assets must not be silently ignored"
manifest = {
    "schema": "pr122-queen-run-repair-file-manifest-v1", "new_approvals": 0,
    "new_raw_sources": 12, "called_exact_requests": len(receipts),
    "selected_new_clips": 7, "selected_new_poses": 42,
    "held_source_count": 5, "selected_reused_poses": 0,
    "prepared_not_called_requests": unused,
    "PNG_bytes": "Exact tool-generated bytes; staged copies are byte-identical to durable raw sources. Atlas region/margin metadata only; no flips, warps, palette changes or source-pixel edits.",
    "registration": "Direction-specific logical canvas; ONE NativeMotionProfile scale; manual contact crown/sole measurement; other ground-plane estimates remain quality HOLD.",
    "commit_or_push_performed_by_child": False, "ignored_artifacts": ignored,
    "gitignored_raw_log_preserved_locally_and_exactly_copied_to_txt": {"raw": pin(log), "durable_transcript": pin(transcript)},
    "files": [pin(p) for p in artifacts],
}
save("file-manifest.json", manifest)
print(json.dumps({"selected_clips": 7, "selected_poses": 42, "raw_sources": 12, "held_sources": 5,
                  "exact_request_receipts": len(receipts), "manifest_files": len(artifacts),
                  "candidate_sha256": sha(OUT/"candidate.json"), "manifest_sha256": sha(OUT/"file-manifest.json"),
                  "engine": playback["engine"], "new_approvals": 0}))
