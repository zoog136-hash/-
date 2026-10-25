#!/usr/bin/env python3
"""Root-invoked, one-shot Girtas default connection preparation; never approval.

Requires a reviewed immutable staging revision and an exact frame-file SHA.
Never runs Git mutations, Godot, CI, rendering, or image generation. Any partial
failure leaves original backups, new files, and a bounded event log intact.
"""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import traceback
from girtas_review_guard import checked_gate, no_links, scratch_path, strict_json

KEY = "transform:267"
BRANCH = "feature/twilight-remaining106-20261016"
REGISTER = "data/pr122_native_locomotion_staging.json"
CATALOG = "data/catalog_v19.json"
PROFILE_CATALOG = "data/combat_animation_profiles.json"
MANIFEST = "docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json"
APPROVALS = "data/pr122_native_production_approvals.json"
DESTINATION = "assets/actors/eight_direction/native_production/girtas_267/r001"
PROOF = "docs/remake/evidence/pr122-mythic-detailed/batch03/girtas-production-r001-connection-proof.json"
HASH = re.compile(r"[0-9a-f]{64}\Z")
FLAGS = ("twilight_production_connected", "twilight_detailed_completed")
WHITESPACE = " \t\r\n"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(value):
    return hashlib.sha256(value).hexdigest()


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON object key")
        result[key] = value
    return result


DECODER = json.JSONDecoder(object_pairs_hook=unique_pairs)


def parsed(data):
    return strict_json(data)


def local_path(root, value):
    relative = value.removeprefix("res://")
    path = Path(relative)
    require(not path.is_absolute() and ".." not in path.parts, "Unsafe repository path")
    candidate = root / path
    require(candidate.resolve().is_relative_to(root), "Repository path escapes root")
    for item in (candidate, *candidate.parents):
        if item == root.parent:
            break
        require(not item.is_symlink(), "Symlink path is not eligible")
    return candidate


def pin(root, path, data=None):
    return {"path": path.relative_to(root).as_posix(),
            "sha256": sha(path.read_bytes() if data is None else data)}


def skip_space(text, offset):
    while offset < len(text) and text[offset] in WHITESPACE:
        offset += 1
    return offset


def members(text, offset):
    """Return exact character spans without reserializing surrounding JSON."""
    require(text[offset] == "{", "Expected JSON object")
    offset = skip_space(text, offset + 1)
    while text[offset] != "}":
        key, offset = DECODER.raw_decode(text, offset)
        require(isinstance(key, str), "Object key must be text")
        offset = skip_space(text, offset)
        require(text[offset] == ":", "Expected object colon")
        start = skip_space(text, offset + 1)
        value, end = DECODER.raw_decode(text, start)
        yield key, value, start, end
        offset = skip_space(text, end)
        if text[offset] == "}":
            break
        require(text[offset] == ",", "Expected object comma")
        offset = skip_space(text, offset + 1)


def items(text, offset):
    require(text[offset] == "[", "Expected catalog array")
    offset = skip_space(text, offset + 1)
    while text[offset] != "]":
        start = offset
        value, end = DECODER.raw_decode(text, start)
        yield value, start, end
        offset = skip_space(text, end)
        if text[offset] == "]":
            break
        require(text[offset] == ",", "Expected array comma")
        offset = skip_space(text, offset + 1)


def catalog_span(data):
    text = data.decode("utf-8")
    groups = [row for row in members(text, skip_space(text, 0)) if row[0] == "변신"]
    require(len(groups) == 1 and isinstance(groups[0][1], list), "Expected real transformation catalog")
    matches = [(value, start, end) for value, start, end in items(text, groups[0][2])
               if isinstance(value, dict) and str(value.get("sourceId", "")) == "267"]
    require(len(matches) == 1, "Expected exactly one real Girtas catalog object")
    value, start, end = matches[0]
    return text, value, start, end


def resource_properties(data):
    text = data.decode("utf-8")
    require("\r" not in text and text.endswith("\n"), "Expected immutable LF resource")
    require(text.count("\n[resource]\n") == 1, "Expected one resource body")
    body = text.split("\n[resource]\n", 1)[1]
    result = {}
    for line in body.splitlines():
        match = re.fullmatch(r"([A-Za-z_][A-Za-z_0-9]*) = (.+)", line)
        if match:
            require(match[1] not in result, "Duplicate resource property")
            result[match[1]] = match[2]
    return text, result


def resource_value(properties, name, default=None):
    if name not in properties:
        return copy.deepcopy(default)
    value = properties[name]
    if value.startswith("Vector2("):
        match = re.fullmatch(r"Vector2\(([^,]+), ([^)]+)\)", value)
        require(match is not None, "Malformed resource vector")
        return [float(match[1]), float(match[2])]
    return json.loads(value)


def resource_clone(data, *, old_frames=None, new_frames=None):
    text, properties = resource_properties(data)
    require(text.count("metadata/twilight_native_locomotion_staging = true\n") == 1,
            "Native format marker must remain enabled")
    for flag in FLAGS:
        old = f"metadata/{flag} = false\n"
        new = f"metadata/{flag} = true\n"
        require(new not in text, "Source must not already claim production completion")
        if old in text:
            require(text.count(old) == 1, "Duplicate metadata flag")
            text = text.replace(old, new)
        else:
            require(flag == "twilight_production_connected", "Missing expected detailed metadata flag")
            text += new
    if old_frames is not None:
        require(resource_value(properties, "frames_path") == old_frames, "Profile points at a different staging frame file")
        old = "frames_path = " + json.dumps(old_frames) + "\n"
        new = "frames_path = " + json.dumps(new_frames) + "\n"
        require(text.count(old) == 1, "Expected exact source frames_path line")
        text = text.replace(old, new)
    return text.encode("utf-8")


def resource_body(data, *, omit_frames=False):
    return b"".join(line for line in data.splitlines(keepends=True)
                    if not any(line.startswith(("metadata/" + flag + " = ").encode()) for flag in FLAGS)
                    and not (omit_frames and line.startswith(b"frames_path = ")))


def inline_settings(profile_data, frames_path):
    _, properties = resource_properties(profile_data)
    require(resource_value(properties, "profile_id") == KEY, "Wrong native profile identity")
    defaults = {"native_width_ratio": 1.0, "movement_cadence_width_ratio": 1.0,
                "attack_animation_speed": 1.0}
    fields = ["frames_path", "layout", "motion_style", "movement_fps", "reference_speed",
              "pixel_scale", "native_width_ratio", "movement_cadence_width_ratio",
              "embedded_shadow", "authored_motion_weight", "hit_recoil", "death_duration",
              "body_kind", "floating", "attack_hit_frame", "action_hit_frames",
              "attack_animation_speed", "sprite_offset"]
    settings = {}
    for name in fields:
        require(name in properties or name in defaults, "Missing native setting: " + name)
        settings[name] = resource_value(properties, name, defaults.get(name))
    require(settings["frames_path"] == frames_path and settings["layout"] == "directional8", "Wrong native frame binding")
    require(settings["attack_hit_frame"] == 3 and settings["action_hit_frames"].get("attack") == 3,
            "Girtas native attack contact must remain pose3")
    if "color_tint" in properties:
        require(properties["color_tint"] in ("Color(1, 1, 1, 1)", "Color(1.0, 1.0, 1.0, 1.0)"), "Native art requires white tint")
    settings["color_tint"] = "ffffff"
    use_ratio = resource_value(properties, "use_profile_hit_ratio", False)
    require(isinstance(use_ratio, bool), "Invalid profile ratio flag")
    if use_ratio:
        settings["attack_hit_ratio"] = resource_value(properties, "attack_hit_ratio")
    for value in settings.values():
        if isinstance(value, float):
            require(math.isfinite(value), "Nonfinite native setting")
    return settings


def combat_clock(settings):
    style = settings.get("motion_style", "slash")
    marker = (max(0.1, min(0.85, float(settings["attack_hit_ratio"])))
              if "attack_hit_ratio" in settings else
              {"thrust": .34, "heavy": .56, "bow": .38, "magic": .52}.get(style, .44))
    return {"motion_style": style, "authoritative_hit_ratio": marker,
            "death_duration": float(settings.get("death_duration", .35)),
            "attack_animation_speed": float(settings.get("attack_animation_speed", 1.0))}


def git(root, *args):
    completed = subprocess.run(["git", *args], cwd=root, capture_output=True, check=False)
    require(completed.returncode == 0, "Git preflight failed: " + " ".join(args[:2]))
    return completed.stdout


def exclusive(path, data, mode=0o600):
    with path.open("xb") as handle:
        handle.write(data)
        handle.flush()
        os.fsync(handle.fileno())
    path.chmod(mode)


def replace_known(path, expected, replacement, suffix):
    require(path.read_bytes() == expected, "Concurrent change preserved: " + path.name)
    temporary = path.with_name("." + path.name + ".pr122-" + suffix + ".tmp")
    exclusive(temporary, replacement, path.stat().st_mode & 0o777)
    require(path.read_bytes() == expected, "Concurrent change preserved; prepared temporary retained")
    os.replace(temporary, path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("/workspace/twilight"))
    parser.add_argument("--expected-frames-sha256", required=True)
    parser.add_argument("--expected-revision")
    parser.add_argument("--backup-dir", type=Path)
    parser.add_argument("--apply", action="store_true", help="Explicit reviewed future write; default is scratch plan only")
    parser.add_argument("--plan-dir", type=Path)
    args = parser.parse_args()
    root = no_links(args.root.absolute()).resolve()
    backup = None
    stage = "READ_ONLY_PREFLIGHT"
    events = []
    try:
        require(HASH.fullmatch(args.expected_frames_sha256), "Provide the exact expected staging frames SHA256")
        require(git(root, "branch", "--show-current").decode().strip() == BRANCH, "Exact PR122 branch required")
        require(not git(root, "diff", "--cached", "--name-only").strip(), "Preserve existing staged changes; empty index required")
        original = {name: local_path(root, name).read_bytes()
                    for name in (REGISTER, CATALOG, PROFILE_CATALOG, MANIFEST)}
        register, catalog, table, manifest = (parsed(original[name]) for name in (REGISTER, CATALOG, PROFILE_CATALOG, MANIFEST))
        actor = register["actors"][KEY]
        require(register["approved_history_preserved"] == manifest["approved_history_preserved"] == 405, "Historical approval count changed")
        require(type(register["detailed_complete"]) is int and register["detailed_complete"] == 1
                and type(manifest["mythic_detail_complete"]) is int and manifest["mythic_detail_complete"] == 1,
                "Additive Girtas preparation requires exactly one proof-backed prior approval")
        checked_gate(root)
        sys.dont_write_bytecode = True
        sys.path.insert(0, str(root / "tools"))
        import pr122_native_production_approvals as gate
        frozen_state = gate.load_state(root, manifest=manifest, register=register)
        require(set(frozen_state.approved_keys) == {"transform:393"}, "Keep existing Halpas certificate/freeze; Girtas must still be unapproved")
        frozen393_actor = canonical(register["actors"]["transform:393"])
        frozen_registry = approvals_path_bytes = local_path(root, APPROVALS).read_bytes()
        require(register["detailed_total"] == manifest["mythic_detail_total"] == 31, "Detailed total changed")
        require(actor["production_connected"] is False and actor["detailed_completed"] is False
                and type(actor["completed_added"]) is int and actor["completed_added"] == 0, "Actor already approved or connected")
        approvals_path = local_path(root, APPROVALS)
        if approvals_path.exists():
            require(KEY not in parsed(approvals_path.read_bytes()).get("approved_actors", {}), "Approved actor is immutable")
        require(len(table["profiles"]) == 1490, "Unexpected combat profile table size")
        source_frames = local_path(root, actor["frames"])
        source_profile = local_path(root, actor["native_profile"])
        require("native_locomotion_staging/girtas_267/" in actor["frames"], "Expected Girtas staging source")
        if args.expected_revision:
            require(re.fullmatch(r"r\d{3}", args.expected_revision) and source_frames.parent.name == args.expected_revision,
                    "Current staging revision differs from expected revision")
        require(source_profile.parent == source_frames.parent, "Native profile and frames revisions differ")
        frames_before, profile_before = source_frames.read_bytes(), source_profile.read_bytes()
        require(sha(frames_before) == actor["frames_sha256"] == args.expected_frames_sha256, "Stale staging frames SHA256")
        require(sha(profile_before) == actor["native_profile_sha256"], "Stale staging native profile SHA256")
        related = [REGISTER, CATALOG, PROFILE_CATALOG, MANIFEST, APPROVALS,
                   source_frames.relative_to(root).as_posix(), source_profile.relative_to(root).as_posix()]
        require(not git(root, "status", "--porcelain=v1", "--untracked-files=normal", "--", *related).strip(),
                "Related uncommitted data exists; preserve and checkpoint it before preparation")
        for path in (source_frames, source_profile):
            git(root, "ls-files", "--error-unmatch", "--", path.relative_to(root).as_posix())
        require(type(actor["native_track_count"]) is int and actor["native_track_count"] == 48
                and type(actor["native_pose_count"]) is int and actor["native_pose_count"] == 288
                and len(actor["tracks"]) == 48, "Exact 48 tracks and 288 poses required")
        expected_slots = {(direction, role) for direction in ("E", "SE", "S", "SW", "W", "NW", "N", "NE")
                          for role in ("idle", "walk", "run", "attack", "hit", "death")}
        strict_selection = gate._selection(gate._Reader(root), KEY, actor, manifest)
        rows, slots, fingerprints = [], set(), set()
        for track in actor["tracks"]:
            slot = (track["direction"], track["role"])
            require(slot in expected_slots and slot not in slots, "Missing or duplicate directional track")
            slots.add(slot)
            phases = track["geometry"]["frames"]
            require(len(phases) == 6, "Every selected track must have six poses")
            source = local_path(root, track["source"])
            texture = local_path(root, track["texture"])
            source_pin, texture_pin = pin(root, source), pin(root, texture)
            require(source_pin["sha256"] == track["source_sha256"], "Selected source SHA256 changed")
            raw = [item for item in manifest["raw_images"] if item["source"] == track["source"]]
            require(len(raw) == 1 and raw[0]["sha256"] == source_pin["sha256"]
                    and raw[0]["geometry"]["status"] == "GEOMETRY_PASS", "Selected source lacks pinned geometry pass")
            frame_hashes = [phase["rgba_sha256"] for phase in phases]
            require(all(HASH.fullmatch(item) for item in frame_hashes), "Invalid pose fingerprint")
            require(not fingerprints.intersection(frame_hashes) and len(set(frame_hashes)) == 6, "Repeated native pose fingerprint")
            fingerprints.update(frame_hashes)
            rows.append({"direction": slot[0], "role": slot[1], "source": source_pin, "texture": texture_pin,
                         "geometry_sha256": sha(canonical(track["geometry"])),
                         "frame_rgba_sha256": frame_hashes,
                         "frame_region_margin_anchor_sha256": [sha(canonical(phase)) for phase in phases]})
        require(slots == expected_slots and len(fingerprints) == 288, "Incomplete independent directional coverage")
        destination = local_path(root, DESTINATION)
        proof_path = local_path(root, PROOF)
        require(not destination.exists() and not proof_path.exists(), "Production r001 or proof already exists; never overwrite or retry")
        new_frames_path = "res://" + DESTINATION + "/SpriteFrames.tres"
        new_profile_path = "res://" + DESTINATION + "/NativeMotionProfile.tres"
        frames_after = resource_clone(frames_before)
        profile_after = resource_clone(profile_before, old_frames=actor["frames"], new_frames=new_frames_path)
        require(resource_body(frames_before) == resource_body(frames_after), "Frame payload changed beyond allowed metadata")
        require(resource_body(profile_before, omit_frames=True) == resource_body(profile_after, omit_frames=True),
                "Native profile physical or timing property changed")
        settings = inline_settings(profile_after, new_frames_path)
        text, old_catalog_actor, start, end = catalog_span(original[CATALOG])
        old_effective = copy.deepcopy(table["profiles"][KEY])
        old_effective.update(old_catalog_actor.get("animation_profile", {}))
        new_effective = copy.deepcopy(table["profiles"][KEY])
        new_effective.update(settings)
        _, native_properties = resource_properties(profile_after)
        require(("attack_hit_ratio" in new_effective)
                == resource_value(native_properties, "use_profile_hit_ratio", False),
                "Inherited profile ratio flag would differ from the native profile")
        require(combat_clock(old_effective) == combat_clock(new_effective), "Authoritative existing combat timing would change")
        replacement_actor = copy.deepcopy(old_catalog_actor)
        replacement_actor["animation_profile"] = settings
        replacement_text = json.dumps(replacement_actor, ensure_ascii=False, separators=(",", ":"), allow_nan=False)
        catalog_after = (text[:start] + replacement_text + text[end:]).encode("utf-8")
        expected_catalog = copy.deepcopy(catalog)
        catalog_index = next(index for index, item in enumerate(expected_catalog["변신"]) if str(item.get("sourceId", "")) == "267")
        expected_catalog["변신"][catalog_index] = replacement_actor
        require(parsed(catalog_after) == expected_catalog, "Unexpected catalog change outside target record")
        require({k: v for k, v in old_catalog_actor.items() if k != "animation_profile"}
                == {k: v for k, v in replacement_actor.items() if k != "animation_profile"}, "Existing Girtas catalog fields changed")
        preserved_catalog = copy.deepcopy(catalog)
        preserved_catalog["변신"][catalog_index] = {"excluded_selected_actor": KEY}
        new_register = copy.deepcopy(register)
        history = new_register.setdefault("history", {}).setdefault(KEY, [])
        require(not any(item.get("frames") == actor["frames"] for item in history), "Current source revision already duplicated in history")
        history.append(copy.deepcopy(actor))
        new_actor = new_register["actors"][KEY]
        new_actor.update(frames=new_frames_path, frames_sha256=sha(frames_after),
                         native_profile=new_profile_path, native_profile_sha256=sha(profile_after),
                         production_connected=False, detailed_completed=False, completed_added=0,
                         status="PRODUCTION_CANDIDATE_PENDING_REAL_DEFAULT_MAIN_AND_INDEPENDENT_QUALITY",
                         integration="Real default catalog wired to immutable production candidate; approval pending actual default Main and independent full quality")
        new_actor.setdefault("verification", {})["actual_Main_default_catalog"] = "NOT_RUN"
        require(new_actor["tracks"] == actor["tracks"], "Native track or geometry changed")
        register_after = json_bytes(new_register)
        require(canonical(new_register["actors"]["transform:393"]) == frozen393_actor, "Approved Halpas actor changed")
        frozen_state.assert_preserved(manifest, new_register)
        require(local_path(root, APPROVALS).read_bytes() == frozen_registry, "Existing approval registry changed")
        timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        if not args.apply:
            plan = scratch_path(args.plan_dir or Path("/workspace/scratch/pr122-girtas-production-reviewed") / ("readonly-plan-" + timestamp))
            plan.mkdir(parents=True, exist_ok=False)
            exclusive(plan / "SpriteFrames.proposed.tres", frames_after)
            exclusive(plan / "NativeMotionProfile.proposed.tres", profile_after)
            exclusive(plan / "catalog267.before.json", json_bytes(old_catalog_actor))
            exclusive(plan / "catalog267.proposed.json", json_bytes(replacement_actor))
            exclusive(plan / "actor267.proposed.json", json_bytes(new_actor))
            summary = {"status": "READ_ONLY_PRODUCTION_PLAN_NOT_APPROVED", "key": KEY,
                       "source_frames": pin(root, source_frames), "source_profile": pin(root, source_profile),
                       "proposed_destination": DESTINATION, "proposed_connection_proof": PROOF,
                       "catalog_before_sha256": sha(original[CATALOG]), "catalog_proposed_sha256": sha(catalog_after),
                       "register_before_sha256": sha(original[REGISTER]), "register_proposed_sha256": sha(register_after),
                       "source_manifest_unchanged_sha256": sha(original[MANIFEST]),
                       "all1490_including54_color_profiles_unchanged_sha256": sha(original[PROFILE_CATALOG]),
                       "frozen393_actor_sha256": sha(frozen393_actor), "frozen_registry_sha256": sha(frozen_registry),
                       "native_tracks": 48, "native_poses": 288, "detailed_before": 1, "detailed_after": 1,
                       "approval_issued": False, "repository_mutations": False,
                       "next_required": ["Root review before explicit --apply", "Actual new Girtas default Main test", "Independent full48 production quality exact pins", "Guarded additive certificate before count2"]}
            exclusive(plan / "production-plan.json", json_bytes(summary))
            print(json.dumps({"status": summary["status"], "plan": str(plan), "repo_writes": 0, "approval_delta": 0}))
            return 0
        backup = scratch_path(args.backup_dir or Path("/workspace/scratch/pr122-girtas-production-reviewed") / ("production-backup-" + timestamp))
        backup.mkdir(mode=0o700, parents=True, exist_ok=False)
        stage = "BACKUP_ORIGINALS"
        for label, data in (("catalog_v19.original.json", original[CATALOG]),
                            ("native_register.original.json", original[REGISTER]),
                            ("girtas_actor.original.json", json_bytes(actor)),
                            ("source_manifest.original.json", original[MANIFEST]),
                            ("combat_animation_profiles.original.json", original[PROFILE_CATALOG]),
                            ("SpriteFrames.original.tres", frames_before),
                            ("NativeMotionProfile.original.tres", profile_before)):
            exclusive(backup / label, data)
        exclusive(backup / "preparation-events.jsonl", b"")
        def event(name):
            events.append(name)
            with (backup / "preparation-events.jsonl").open("ab") as handle:
                handle.write(canonical({"stage": name, "utc": dt.datetime.now(dt.timezone.utc).isoformat()}) + b"\n")
        event(stage)
        # Check every preflight input again immediately before the first write.
        for name, data in original.items():
            require(local_path(root, name).read_bytes() == data, "Concurrent input change preserved: " + name)
        require(source_frames.read_bytes() == frames_before and source_profile.read_bytes() == profile_before, "Concurrent source resource change preserved")
        require(gate._selection(gate._Reader(root), KEY, actor, manifest) == strict_selection,
                "Concurrent source/texture/geometry selection change preserved")
        frozen_state.assert_preserved(manifest, new_register)
        require(local_path(root, APPROVALS).read_bytes() == frozen_registry, "Registry drift before production write")
        stage = "CREATE_IMMUTABLE_PRODUCTION_RESOURCES"
        destination.mkdir(parents=True, exist_ok=False)
        exclusive(destination / "SpriteFrames.tres", frames_after, 0o644)
        exclusive(destination / "NativeMotionProfile.tres", profile_after, 0o644)
        event(stage)
        stage = "UPDATE_REGISTER_PENDING_APPROVAL"
        replace_known(local_path(root, REGISTER), original[REGISTER], register_after, timestamp)
        event(stage)
        stage = "SURGICAL_REAL_DEFAULT_CATALOG_CONNECTION"
        replace_known(local_path(root, CATALOG), original[CATALOG], catalog_after, timestamp)
        event(stage)
        require(local_path(root, PROFILE_CATALOG).read_bytes() == original[PROFILE_CATALOG]
                and local_path(root, MANIFEST).read_bytes() == original[MANIFEST], "Unrelated profile catalog or source manifest changed concurrently")
        require(local_path(root, REGISTER).read_bytes() == register_after and local_path(root, CATALOG).read_bytes() == catalog_after,
                "Prepared target bytes changed concurrently")
        proof = {"schema": "pr122-native-production-connection-preparation-v1", "key": KEY,
                 "status": "PREPARED_PENDING_REAL_DEFAULT_MAIN_AND_INDEPENDENT_QUALITY", "utc": timestamp,
                 "approval_issued": False, "approved_history_preserved": 405, "detailed_complete_before": 1,
                 "detailed_complete_after": 1, "completed_added": 0, "backup_directory": str(backup),
                 "frozen393": {"actor_record_sha256": gate.json_digest(register["actors"]["transform:393"]),
                               "registry_entry": parsed(frozen_registry)["approved_actors"]["transform:393"]},
                 "original_frames": pin(root, source_frames, frames_before),
                 "production_frames": pin(root, destination / "SpriteFrames.tres", frames_after),
                 "original_profile": pin(root, source_profile, profile_before),
                 "production_profile": pin(root, destination / "NativeMotionProfile.tres", profile_after),
                 "register_before_sha256": sha(original[REGISTER]), "register_after_sha256": sha(register_after),
                 "original_actor_record_sha256": sha(canonical(actor)), "prepared_actor_record_sha256": sha(canonical(new_actor)),
                 "preserved_history_entries_before": len(register.get("history", {}).get(KEY, [])),
                 "preserved_history_entries_after": len(history), "entire_previous_actor_appended_to_history": True,
                 "native_track_count": 48, "native_pose_count": 288,
                 "equivalence": {"frames_except_two_metadata_flags_byte_identical": True,
                                 "profile_except_frames_path_and_two_metadata_flags_byte_identical": True,
                                 "all_288_regions_RGBA_margins_anchors_identical": True,
                                 "all_native_track_records_identical": True, "no_PNG_written": True,
                                 "native_format_marker_preserved": True,
                                 "physical_and_timing_profile_body_sha256": sha(resource_body(profile_after, omit_frames=True)),
                                 "frame_resource_body_sha256": sha(resource_body(frames_after)),
                                 "authoritative_combat_clock_before": combat_clock(old_effective),
                                 "authoritative_combat_clock_after": combat_clock(new_effective)},
                 "default_catalog": {"path": CATALOG, "before_sha256": sha(original[CATALOG]), "after_sha256": sha(catalog_after),
                                     "source_id": "267", "group": "변신", "only_target_object_replaced": True,
                                     "unchanged_prefix_sha256": sha(text[:start].encode("utf-8")),
                                     "unchanged_suffix_sha256": sha(text[end:].encode("utf-8")),
                                     "all_other_records_sha256": sha(canonical(preserved_catalog)),
                                     "old_target_record_sha256": sha(canonical(old_catalog_actor)),
                                     "new_target_record_sha256": sha(canonical(replacement_actor)),
                                     "inline_profile_sha256": sha(canonical(settings))},
                 "profile_catalog": {"path": PROFILE_CATALOG, "sha256": sha(original[PROFILE_CATALOG]),
                                     "profile_count": 1490, "all_profiles_including_54_color_shared_profiles_unchanged": True},
                 "source_manifest": {"path": MANIFEST, "sha256": sha(original[MANIFEST]), "unchanged": True},
                 "selected_tracks_unchanged": sorted(rows, key=lambda row: (row["direction"], row["role"])),
                 "required_next": ["Actual default Main 48-track behavioral PASS", "Independent full 48-track quality proof pinned to these exact production resources", "Proof-backed completion certificate before any approval count change"]}
        gate.load_state(root)  # Existing393 remains valid;267 still pending and count remains1.
        stage = "WRITE_DURABLE_EQUIVALENCE_PROOF"
        exclusive(proof_path, json_bytes(proof), 0o644)
        event(stage)
        stage = "PREPARED_NOT_APPROVED"
        exclusive(backup / "preparation-result.json", json_bytes({"status": stage, "proof": PROOF,
                  "proof_sha256": sha(proof_path.read_bytes()), "events": events}))
        print("PREPARED_NOT_APPROVED key=transform:267 tracks=48 poses=288 "
              f"frames_sha256={sha(frames_after)} proof={PROOF} backup={backup}")
        return 0
    except Exception as error:
        if backup is not None and backup.is_dir():
            failure = {"status": "STOP_PRESERVED", "stage": stage, "error": str(error),
                       "traceback": traceback.format_exc(), "completed_events": events,
                       "no_rollback_or_deletion_performed": True}
            failure_path = backup / "preparation-failure.json"
            if not failure_path.exists():
                exclusive(failure_path, json_bytes(failure))
        print(f"STOP_PRESERVED stage={stage} error={str(error)[:360]} backup={backup or 'not_created'}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
