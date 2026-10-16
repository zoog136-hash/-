"""Strict one-for-one repair of rejected poses in an immutable legacy pack.

The complete baseline is revalidated by the unchanged legacy importer. Its
whole PNGs and rejected poses remain preserved, including their full geometry.
Only explicitly failed slots may receive new whole, connected PNGs. Retained
poses keep every original RGBA byte, rectangle, margin and anchor. No arbitrary
source exclusions, weakened thresholds, raster assembly or image rewriting.
"""
import copy
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import import_original_based_motion as core


def pinned_json(path, digest):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or core.sha(path) != digest:
        raise ValueError("Pinned review/baseline JSON differs: " + str(path))
    return path, json.loads(path.read_text())


def sheet_index(path):
    stem = Path(path).stem
    if stem == "poses":
        return 0
    if not stem.startswith("poses-") or not stem[6:].isdigit():
        raise ValueError("Unexpected legacy baseline PNG name")
    return int(stem[6:])


def prepare(root, candidate, actor, keys, apply):
    root = Path(root).resolve()
    allowed = {"input_mode", "texture_binding", "key", "prompt", "review", "baseline", "patches", "final_review"}
    if (not isinstance(candidate, dict) or set(candidate) - allowed
            or candidate.get("input_mode") != "pose_patch_v1"
            or candidate.get("texture_binding") != "immutable_baseline_one_for_one"):
        raise ValueError("Explicit immutable one-for-one pose patch required")
    if keys != [candidate.get("key")]:
        raise ValueError("One explicit target identity per patch pack")
    if (not isinstance(actor, str) or not 1 <= len(actor) <= 80
            or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in actor)):
        raise ValueError("Use a bounded ASCII actor folder name")
    review = candidate.get("review", {})
    if (not isinstance(review, dict) or any(review.get(k) is not True for k in
            ["identity_preserved", "eight_views", "motion_roles", "no_clipping"])
            or not isinstance(review.get("notes"), str) or not review["notes"].strip()
            or not isinstance(candidate.get("prompt"), str) or not candidate["prompt"].strip()):
        raise ValueError("All explicit full-matrix source visual reviews and instructions required")
    baseline = candidate.get("baseline", {})
    required = {"root", "actor", "candidate_path", "candidate_sha256", "provenance_sha256", "resource_sha256"}
    if not isinstance(baseline, dict) or set(baseline) != required:
        raise ValueError("Pin the complete baseline recipe, proof and SpriteFrames")
    base_root = Path(baseline["root"]).resolve()
    base_actor = baseline["actor"]
    if (not isinstance(base_actor, str) or not base_actor
            or any(c not in "abcdefghijklmnopqrstuvwxyz0123456789_-" for c in base_actor)):
        raise ValueError("Unsafe baseline actor")
    recipe_path, recipe = pinned_json(baseline["candidate_path"], baseline["candidate_sha256"])
    if recipe.get("input_mode") is not None:
        raise ValueError("Initial patch version accepts only unchanged legacy baselines")
    base_folder = base_root / "assets/actors/eight_direction/original_based" / base_actor
    proof_path, base = pinned_json(base_folder / "provenance.json", baseline["provenance_sha256"])
    resource_path = base_folder / "SpriteFrames.tres"
    if resource_path.is_symlink() or core.sha(resource_path) != baseline["resource_sha256"]:
        raise ValueError("Baseline SpriteFrames differs")
    # This reconstructs and checks exact proof/resource/PNG outputs as well as
    # complete-source, pose uniqueness and every unchanged legacy requirement.
    core._legacy_sheet(base_root, recipe, base_actor, keys, False, read_only=True)
    if base.get("action_aliases") or set(base.get("tracks", {})) != set(core.ROLES):
        raise ValueError("Initial patch version preserves only the five mandatory legacy roles")
    targets = {r["key"]: r for r in core.expansion.read(root / "data/animation_authoring_sources.json")["targets"]}
    target = targets[keys[0]]
    if (base.get("target_keys") != keys or base.get("reference") != target["reference"]
            or base.get("presentation_to_preserve") != target["presentation_to_preserve"]):
        raise ValueError("Baseline original identity/presentation differs from target")
    original = root / target["reference"]["path"].removeprefix("res://")
    if core.sha(original) != target["reference"]["sha256"]:
        raise ValueError("Original reference bytes changed")
    folder = root / "assets/actors/eight_direction/original_based" / actor
    for parent in (folder, *folder.parents):
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise ValueError("Output must use regular directories")
        if parent == root:
            break
    frames = copy.deepcopy(base["frames"])
    atlases, slots = {}, {}
    for role in core.ROLES:
        track = base["tracks"][role]
        for atlas in track["atlas_files"]:
            index = sheet_index(atlas["path"])
            if index in atlases and atlases[index] != atlas:
                raise ValueError("Ambiguous baseline PNG descriptor")
            atlases[index] = atlas
        for direction in core.DIRECTIONS:
            spec = track.get("source_rows_by_direction", {}).get(direction)
            rows = spec["source_rows"] if spec else track["source_rows"]
            for phase, row in enumerate(rows):
                paths = {a["path"] for a in track["atlas_files"]}
                matches = [i for i, f in enumerate(frames) if f["direction"] == direction and f["row"] == row
                           and f["sheet"] in atlases and atlases[f["sheet"]]["path"] in paths
                           and (not spec or atlases[f["sheet"]]["path"] == spec["atlas_path"])]
                if len(matches) != 1 or matches[0] in slots.values():
                    raise ValueError("Missing/ambiguous baseline mandatory slot")
                slots[(role, direction, phase)] = matches[0]
    counts = {r: len([s for s in slots if s[0] == r and s[1] == "E"]) for r in core.ROLES}
    expected = {(r, d, p) for r in core.ROLES for d in core.DIRECTIONS for p in range(counts[r])}
    if (set(slots) != expected or len(slots) != len(frames) or len(frames) not in (104, 112)
            or any(counts[r] < len(core.ROLES[r]) for r in core.ROLES)
            or set(atlases) != set(range(len(atlases)))):
        raise ValueError("Complete unchanged104/112 baseline matrix required")
    copies, sources = [], []
    for index, atlas in sorted(atlases.items()):
        source = core._pose_file_source(base_root, atlas["path"])
        destination = folder / f"poses-{index}.png"
        if core.sha(source) != atlas["sha256"]:
            raise ValueError("Baseline PNG SHA differs")
        copies.append((source, destination, atlas["sha256"]))
        sources.append({**atlas, "path": "res://" + str(destination.relative_to(root))})
    patches = candidate.get("patches")
    if not isinstance(patches, list) or not 1 <= len(patches) < len(frames):
        raise ValueError("Explicit nonempty rejected-slot replacements required")
    retired, used, patch_ids = [], set(), set()
    pins = [(recipe_path, baseline["candidate_sha256"]), (proof_path, baseline["provenance_sha256"]),
            (resource_path, baseline["resource_sha256"])]
    patch_fields = {"id", "role", "direction", "phase", "baseline_frame_index", "baseline_rgba_sha256",
                    "output_path", "source_sha256", "canvas_size", "source_anchor", "scale_review_note",
                    "defect_record", "defect_record_sha256"}
    for number, patch in enumerate(patches):
        if not isinstance(patch, dict) or set(patch) != patch_fields:
            raise ValueError("Each replacement needs exact failed slot, PNG and pinned defect evidence")
        if (not isinstance(patch["role"], str) or not isinstance(patch["direction"], str)
                or type(patch["phase"]) is not int):
            raise ValueError("Explicit role/direction/integer phase required")
        slot = patch["role"], patch["direction"], patch["phase"]
        index = slots.get(slot)
        if index is None or index in used or type(patch["baseline_frame_index"]) is not int or patch["baseline_frame_index"] != index:
            raise ValueError("Wrong/duplicate replaced slot")
        old = frames[index]
        if old["rgba_sha256"] != patch["baseline_rgba_sha256"]:
            raise ValueError("Failed baseline pose SHA differs")
        defect_path, defect = pinned_json(patch["defect_record"], patch["defect_record_sha256"])
        if (defect.get("target_key") != keys[0] or defect.get("baseline_provenance_sha256") != baseline["provenance_sha256"]
                or defect.get("slot") != dict(zip(["role", "direction", "phase"], slot))
                or defect.get("baseline_rgba_sha256") != old["rgba_sha256"] or defect.get("decision") != "FAIL"
                or not isinstance(defect.get("reason"), str) or not defect["reason"].strip()
                or not isinstance(defect.get("evidence"), list) or not defect["evidence"]):
            raise ValueError("Explicit independent failed-slot evidence required; no arbitrary exclusions")
        pins.append((defect_path, patch["defect_record_sha256"]))
        for evidence in defect["evidence"]:
            p = Path(evidence["path"])
            if p.is_symlink() or core.sha(p) != evidence["sha256"]:
                raise ValueError("Failed-slot evidence body missing/changed")
            pins.append((p, evidence["sha256"]))
        if (not isinstance(patch["scale_review_note"], str) or not patch["scale_review_note"].strip()
                or not isinstance(patch["id"], str) or not patch["id"].strip()
                or len(patch["id"]) > 120 or patch["id"] in patch_ids):
            raise ValueError("Record replacement identity and homologous model/root review")
        patch_ids.add(patch["id"])
        source = core._pose_file_source(root, patch["output_path"])
        if core.sha(source) != patch["source_sha256"]:
            raise ValueError("Replacement PNG SHA differs")
        if (not isinstance(patch["source_anchor"], list) or len(patch["source_anchor"]) != 2
                or any(type(v) is not int for v in patch["source_anchor"])):
            raise ValueError("Replacement needs reviewed integer source anchor")
        part = core.analyze(source, 1, [0], None, "columns", patch["canvas_size"], [patch["source_anchor"]], [slot[1]])
        core.require_complete_pose_regions(source, part)
        with Image.open(source) as image:
            if image.format != "PNG" or ndimage.label(np.asarray(image)[:, :, 3] > 100, np.ones((3, 3), int))[1] != 1:
                raise ValueError("Replacement must be one connected visible whole PNG body")
            x, y, w, h = part["frames"][0]["region"]
            new_visible = core._visible_pose_fingerprint(np.asarray(image)[y:y + h, x:x + w])
        with Image.open(copies[old["sheet"]][0]) as image:
            x, y, w, h = old["region"]
            if new_visible == core._visible_pose_fingerprint(np.asarray(image)[y:y + h, x:x + w]):
                raise ValueError("Replacement must actually change the failed visible pose")
        new = part["frames"][0]
        new.update(sheet=len(sources), role=slot[0], phase=slot[2], pose_id=patch["id"])
        frames[index] = new
        destination = folder / f"replacement-{number:03d}.png"
        copies.append((source, destination, patch["source_sha256"]))
        sources.append({"path": "res://" + str(destination.relative_to(root)), "sha256": patch["source_sha256"],
                        "size": part["image_size"], "canvas_size": part["canvas_size"], "foot": part["foot"], "directions": [slot[1]]})
        retired.append({"index": index, "slot": list(slot), "original_frame": copy.deepcopy(old), "defect": defect,
                        "defect_sha256": patch["defect_record_sha256"], "replacement_source_sha256": patch["source_sha256"]})
        used.add(index)
    raw, visible = set(), set()
    pixels = {}
    for source, _, _ in copies:
        with Image.open(source) as image:
            pixels[len(pixels)] = np.asarray(image).copy()
    for i, f in enumerate(frames):
        if i not in used and f != base["frames"][i]:
            raise ValueError("A retained pose changed")
        x, y, w, h = f["region"]
        crop = pixels[f["sheet"]][y:y + h, x:x + w]
        digest = hashlib.sha256(crop.tobytes()).hexdigest()
        fingerprint = core._visible_pose_fingerprint(crop)
        if digest != f["rgba_sha256"] or digest in raw or fingerprint in visible:
            raise ValueError("Active matrix contains duplicate/changed raw or visible pose")
        raw.add(digest); visible.add(fingerprint)
    for slot, index in slots.items():
        frames[index].update(role=slot[0], phase=slot[2])
        frames[index].setdefault("pose_id", "%s:%s:%d" % slot)
    geometry_sha = hashlib.sha256(json.dumps({"frames": frames, "sources": [s["sha256"] for s in sources]}, sort_keys=True).encode()).hexdigest()
    role_frames = {r: [[slots[(r, d, p)] for p in range(counts[r])] for d in core.DIRECTIONS] for r in core.ROLES}
    proof = copy.deepcopy(base)
    proof.update(input_representation="pose_patch_v1", texture_binding="immutable_baseline_one_for_one", frames=frames,
                 source_files=sources, phase_counts=counts, visual_review=review, authoring_instructions=candidate["prompt"],
                 actual_Main="not_run", completed_added=0, geometry_sha256=geometry_sha,
                 baseline_history={"provenance_sha256": baseline["provenance_sha256"], "resource_sha256": baseline["resource_sha256"],
                    "full_original_provenance": base, "retired_slots": retired, "retained_pose_count": len(frames) - len(used),
                    "all_baseline_poses_accounted_retained_or_failed_and_replaced": True,
                    "all_original_whole_PNG_bytes_preserved": True})
    proof["tracks"] = {}
    for role, directions in role_frames.items():
        contributing = sorted({frames[i]["sheet"] for group in directions for i in group})
        proof["tracks"][role] = {"atlas_files": [sources[i] for i in contributing],
            "source_poses_by_direction": {d: [frames[i]["pose_id"] for i in group] for d, group in zip(core.DIRECTIONS, directions)},
            "source_frames_per_direction": counts[role], "unique_frames_per_direction": counts[role],
            "direction_unique_frames": dict.fromkeys(core.DIRECTIONS, counts[role]),
            "source_duration_seconds": core.SECONDS[role], "loop_type": "loop" if role in ("idle", "walk") else "play_once"}
    resource = core.spriteframes([s["path"] for s in sources], {"frames": frames}, role_frames)
    metadata = [(folder / "SpriteFrames.tres", resource), (folder / "provenance.json", json.dumps(proof, ensure_ascii=False, indent=2) + "\n")]
    profile_plan = core._pose_file_profiles(root, targets, keys, target, folder, base["display_reference_height"], counts["walk"], {}) if apply else None
    for _, destination, digest in copies:
        core.require_preserved_output(destination, digest)
    for path, content in metadata:
        core.require_preserved_output(path, hashlib.sha256(content.encode()).hexdigest())
    result = {"resource": str(folder), "identities": keys, "poses": len(frames), "applied": apply,
              "original_unchanged": True, "input_mode": "pose_patch_v1", "actual_Main": "not_run", "completed_added": 0,
              "replaced": len(used), "retained_exact": len(frames) - len(used), "geometry_sha256": geometry_sha}
    return {"root": root, "folder": folder, "copies": copies, "metadata": metadata, "profile_plan": profile_plan,
            "originals": [(original, target["reference"]["sha256"]), *pins], "result": result}


def validate(root, candidate, actor, keys):
    plan = prepare(root, candidate, actor, keys, True)
    return {**plan["result"], "applied": False, "read_only": True, "profiles_checked": True,
            "output_files": [str(p) for _, p, _ in plan["copies"]] + [str(p) for p, _ in plan["metadata"]]}


def install(root, candidate, actor, keys, apply):
    plan = prepare(root, candidate, actor, keys, apply)
    if apply:
        final = candidate.get("final_review", {})
        path, record = pinned_json(final.get("path", ""), final.get("sha256", ""))
        if (record.get("geometry_sha256") != plan["result"]["geometry_sha256"] or any(record.get(k) != "PASS" for k in
                ["static_review", "temporal_review", "Main_headless", "Main_OpenGL", "independent_visual_review"])
                or not record.get("review_stage") or not isinstance(record.get("evidence"), list)
                or not record["evidence"] or any(not isinstance(e, dict) for e in record["evidence"])):
            raise ValueError("Production apply requires separate final Main and visual review of this exact geometry")
        plan["originals"].append((path, final["sha256"]))
        evidence_by_role = {e.get("role"): e for e in record["evidence"]}
        if len(evidence_by_role) != 4 or set(evidence_by_role) != {"headless", "OpenGL", "temporal", "visual"}:
            raise ValueError("Pin separate headless/OpenGL/temporal/independent visual JSON bodies")
        for role, evidence in evidence_by_role.items():
            p, report = pinned_json(evidence["path"], evidence["sha256"])
            if role == "visual":
                if (report.get("decision") != "PASS" or report.get("geometry_sha256") != plan["result"]["geometry_sha256"]
                        or not report.get("review_stage")):
                    raise ValueError("Separate exact-geometry visual approval required")
            else:
                if (report.get("failures") != [] or report.get("checks", 0) <= 0
                        or len(report.get("cases", [])) != 1):
                    raise ValueError("Final automatic Main report is failed/incomplete")
                case = report["cases"][0]
                if role == "temporal":
                    if (report.get("rendered") is not True or case.get("native_phases") != plan["result"]["poses"]
                            or case.get("rendered_native_phases") != plan["result"]["poses"]):
                        raise ValueError("Every native phase needs actual rendered temporal evidence")
                elif case.get("folder") != actor or (role == "OpenGL" and case.get("screenshots", 0) <= 0):
                    raise ValueError("Main evidence must cover this actor and rendered OpenGL frames")
            plan["originals"].append((p, evidence["sha256"]))
    return core._install_optional_plan(plan)
