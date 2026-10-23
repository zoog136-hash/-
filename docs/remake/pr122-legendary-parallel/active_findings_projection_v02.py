"""Project historical JSON findings onto the exact selected clip metadata.

No image/resource reads and no new review. Historical resolutions are retained;
activity, replacement and current uncertainty are reported in separate fields.
"""
from __future__ import annotations

import collections
import re

HEX = re.compile(r"^[0-9a-f]{64}$")
SOURCE_CODES = {
    "FOREIGN_POSE_FOREGROUND_INSIDE_FRAME",
    "DETACHED_FOREGROUND_OWNER_AMBIGUOUS",
    "ALPHA_BRIDGE_BETWEEN_TEMPORAL_POSES",
    "VISIBLE_FOREGROUND_TOUCHES_SOURCE_EDGE",
    "CONNECTED_OR_OPAQUE_POSE_LAYOUT",
}


def path(value):
    return str(value or "").removeprefix("res://")


def pair(source, sha):
    return path(source), sha


def selected_poses(record):
    """Use actual selected sequences; never traverse raw-parent history fields."""
    primary = path(record.get("source"))
    files = {path(x.get("path", x.get("source"))): x["sha256"]
             for x in record.get("source_files", [])}
    files[primary] = record["source_sha256"]
    aliases = {path(x["original_path"]): path(x["path"])
               for x in record.get("source_files", []) if x.get("original_path")}
    legacy = {x.get("original_pose_id"): x for x in record.get("existing_pose_metadata", [])}
    checks = {x["index"]: x for x in record.get("automatic_checks", [])}
    sequence = record.get("revision_source_pose_sequence") or record.get("source_pose_sequence")
    if not sequence:
        sequence = [{"phase": i} for i in range(6)]
    if len(sequence) != 6 or set(checks) != set(range(6)):
        raise ValueError("Active clip must have six selected poses and six checks")
    out = []
    for i, pose in enumerate(sequence):
        source = pose.get("source") or pose.get("source_path")
        old = legacy.get(pose.get("original_pose_id"))
        if not source and pose.get("source_kind") == "reused" and old:
            source = old["source_path"]
        source = aliases.get(path(source), path(source)) if source else primary
        if source not in files or not HEX.fullmatch(files[source]):
            raise ValueError("Selected texture has no exact source metadata SHA: " + source)
        source_phase = pose.get("idle_phase", pose.get("new_sheet_cell", pose.get("phase", i)))
        # A revised sequence may reorder original action phases. The physical
        # source-sheet cell is derived from its preserved original pose entry,
        # rather than treating final playback index as a source-sheet index.
        original_phase = pose.get("original_phase")
        original_sequence = record.get("source_pose_sequence", [])
        if original_phase is not None and 0 <= original_phase < len(original_sequence):
            original = original_sequence[original_phase]
            source_phase = original.get("idle_phase", original.get("new_sheet_cell", original.get("phase", original_phase)))
        out.append({"frame": i, "source": source, "source_sha256": files[source],
                    "source_phase": source_phase,
                    "region": pose.get("region", pose.get("original_region", checks[i].get("region"))),
                    "rgba_sha256": checks[i]["rgba_sha256"]})
    return out


def build_active_index(evidence, gate, ownership):
    staging, staging_sha = evidence.artifact(gate["active_staging"])
    manifest, manifest_sha = evidence.artifact(gate["active_manifest"])
    evidence.committed_json(gate["active_staging"]["path"], evidence.head, staging_sha)
    evidence.committed_json(gate["active_manifest"]["path"], evidence.head, manifest_sha)
    corrections = staging["corrections"]
    if (path(corrections["active_revision_library"]) != path(gate["active_manifest"]["path"])
            or corrections["active_revision_library_sha256"] != manifest_sha):
        raise ValueError("Active manifest differs from exact staging selection")
    configs = {}
    for actor in staging["actors"]:
        for draft in actor["drafts"]:
            slot = (draft["key"], draft["direction"], draft["role"])
            if slot in configs:
                raise ValueError("Duplicate staging clip")
            configs[slot] = draft
    seen = set()
    for revision in manifest["revisions"]:
        slot = tuple(revision["slot"])
        if slot in seen:
            raise ValueError("Duplicate active revision slot")
        seen.add(slot)
        configs[slot] = revision
    derivative_regions = {}
    for claim in ownership.values():
        proof, _ = evidence.json(claim["proof"], claim["proof_sha256"])
        derivative_regions[pair(claim["output"], claim["output_sha256"])] = {
            tuple(x["region"]): x["original_phase"] for x in proof["poses"]}
    clips = {}
    for slot, config in sorted(configs.items()):
        record, sha = evidence.json(config["record"], config.get("record_sha256"))
        evidence.committed_json(config["record"], evidence.head, sha)
        if (record["key"], record["direction"], record["role"]) != slot:
            raise ValueError("Active record actor/direction/action mismatch")
        if record["output_spriteframes_sha256"] != config["SpriteFrames_sha256"]:
            raise ValueError("Active resource SHA differs from record metadata")
        poses = selected_poses(record)
        for pose in poses:
            regions = derivative_regions.get(pair(pose["source"], pose["source_sha256"]))
            if regions is not None:
                if tuple(pose["region"]) not in regions:
                    raise ValueError("Selected derivative region is absent from exact proof")
                pose["source_phase"] = regions[tuple(pose["region"])]
        ancestors = []
        parent = record
        visited = set()
        for _ in range(16):
            parent_path = path(parent.get("revision_parent"))
            parent_sha = parent.get("revision_parent_sha256")
            if not parent_path or not parent_sha:
                break
            if parent_path in visited:
                raise ValueError("Cycle in active record ancestry")
            visited.add(parent_path)
            parent, actual_sha = evidence.json(parent_path, parent_sha)
            evidence.committed_json(parent_path, evidence.head, actual_sha)
            ancestors.append({"record": parent_path, "record_sha256": actual_sha})
        clips[slot] = {"slot": list(slot), "record": path(config["record"]),
                       "record_sha256": sha, "SpriteFrames": config["SpriteFrames"],
                       "SpriteFrames_sha256": config["SpriteFrames_sha256"],
                       "selected_poses": poses, "record_ancestors": ancestors}
    return clips, {"staging": gate["active_staging"], "manifest": gate["active_manifest"],
                   "selected_existing_clips": len(clips), "selected_revision_slots": len(seen),
                   "source_SHA_scope": "Exact committed record metadata; no PNG reads"}


def uses_of(clips, source_pair, phase=None):
    out = []
    for slot, clip in clips.items():
        frames = [p["frame"] for p in clip["selected_poses"]
                  if pair(p["source"], p["source_sha256"]) == source_pair
                  and (phase is None or p["source_phase"] == phase)]
        if frames:
            out.append({"slot": list(slot), "frames": frames, "record": clip["record"],
                        "record_sha256": clip["record_sha256"]})
    return out


def finding_severity(row):
    if row.get("cause") in ("blocked", "MISSING_REQUIRED_SLOT"):
        return "BLOCKED"
    return "ERROR" if row.get("finding", {}).get("severity") == "ERROR" or row.get("status") == "ERROR_VISUAL" else "HOLD"


def quality_lineages(evidence, saved):
    out = {}
    for item in saved:
        record, _ = evidence.json(item["record"], item["record_sha256"])
        old = pair(record["previous_source"], record["previous_source_sha256"])
        out[old] = dict(item, previous_source=old[0], previous_source_sha256=old[1],
                        previous_record=path(record.get("previous_record")),
                        previous_record_sha256=record.get("previous_record_sha256"))
    return out


def hydrate_historical_records(evidence, result):
    """Attach committed old JSON SHAs, without assigning a source SHA by filename."""
    for category in ("visual_findings", "technical_slot_findings"):
        for row in result.get(category, []):
            if not row.get("record") or row.get("cause") in ("blocked", "MISSING_REQUIRED_SLOT"):
                continue
            record, sha = evidence.json(row["record"])
            evidence.committed_json(row["record"], evidence.head, sha)
            row["historical_record_sha256"] = sha
            if row.get("source_sha256"):
                continue
            source = path(row.get("source"))
            candidates = {path(x.get("path", x.get("source"))): x["sha256"]
                          for x in record.get("source_files", [])}
            candidates[path(record["source"])] = record["source_sha256"]
            for item in record.get("source_files", []):
                if item.get("original_path"):
                    candidates[path(item["original_path"])] = item["sha256"]
            if source in candidates:
                row["source_sha256"] = candidates[source]


def annotate(result, clips, ownership, lineages, targeted_sources):
    """Pure projection; never change historical resolution_status or frozen rows."""
    claims = {pair(x["source"], x["source_sha256"]): x for x in ownership.values()}
    targeted = {pair(x["source"], x["sha256"]): x for x in targeted_sources}
    native = {tuple(x["slot"]): x for x in result["native176_registration"]["slots"]}
    residual = []
    source_catalog = {}
    use_cache = {}

    def selected_uses(source_pair, phase=None):
        key = (source_pair, phase)
        if key not in use_cache:
            use_cache[key] = uses_of(clips, source_pair, phase)
        return use_cache[key]

    def derivative_uses(source_pair, phase=None):
        claim = claims.get(source_pair)
        return selected_uses(pair(claim["output"], claim["output_sha256"]), phase) if claim else []

    for category in ("visual_findings", "technical_source_findings", "technical_slot_findings",
                     "targeted_quality_followup_findings"):
        for row in result.get(category, []):
            slot = tuple(row["slot"])
            active = clips.get(slot)
            source = row.get("affected_source", row.get("source"))
            sha = row.get("source_sha256")
            old_pair = pair(source, sha)
            # A slot finding without a source SHA is record-scoped, never matched
            # to a file by name alone. The active record relation remains visible.
            phase = row.get("finding", {}).get("phase") if category.endswith("source_findings") else None
            exact = selected_uses(old_pair, phase) if sha else []
            derived = derivative_uses(old_pair, phase) if sha else []
            global_exact = selected_uses(old_pair) if sha else []
            global_derived = derivative_uses(old_pair) if sha else []
            lineage = lineages.get(old_pair)
            replacement_uses = []
            replacement_pair = None
            if lineage:
                replacement_pair = pair(lineage["source"], lineage["source_sha256"])
                replacement_uses = selected_uses(replacement_pair) + derivative_uses(replacement_pair)
            state = ("ACTIVE_EXACT_SOURCE" if global_exact else "ACTIVE_LOSSLESS_DERIVATIVE" if global_derived
                     else "SUPERSEDED_BY_EXACT_QUALITY_REPLACEMENT" if replacement_uses
                     else "RECORD_SCOPED_SOURCE_SHA_UNSPECIFIED" if not sha
                     else "NOT_SELECTED_BY_ACTIVE_MANIFEST")
            historical_record = path(row.get("record"))
            ancestors = active["record_ancestors"] if active else []
            old_record_sha = row.get("historical_record_sha256")
            same_record = bool(active and historical_record == active["record"]
                               and old_record_sha == active["record_sha256"])
            related = bool(active and (same_record or any(x["record"] == historical_record
                           and x["record_sha256"] == old_record_sha for x in ancestors)))
            record_state = ("MISSING_ACTIVE_CLIP" if not active else
                            "SAME_EXACT_RECORD" if same_record else
                            "CONFIRMED_REVISION_ANCESTRY" if related else
                            "REPLACED_RECORD_REQUIRES_QA")
            row["active_annotation"] = {"source_activity": state,
                "exact_source_uses": global_exact, "lossless_derivative_uses": global_derived,
                "finding_phase_exact_uses": exact, "finding_phase_derivative_uses": derived,
                "quality_replacement_uses": replacement_uses,
                "quality_replacement": lineage, "historical_record": historical_record or None,
                "historical_record_sha256": old_record_sha,
                "active_authored_clip": ({k: active[k] for k in ("slot", "record", "record_sha256", "SpriteFrames", "SpriteFrames_sha256")} if active else None), "record_relation": record_state,
                "native_registration_technical_coverage": native.get(slot),
                "historical_resolution_status_preserved": row["resolution_status"]}
            if sha:
                source_catalog[old_pair] = {"source": old_pair[0], "source_sha256": sha,
                    "activity": state, "active_exact_or_lossless_uses": global_exact + global_derived,
                    "replacement": lineage, "replacement_uses": replacement_uses}
            resolved = row["resolution_status"].startswith("RESOLVED_")
            projection = None
            severity = finding_severity(row)
            targets = [slot]
            if severity == "BLOCKED":
                projection = "BLOCKED_MISSING_ACTIVE_CLIP" if not active else "MISSING_HISTORY_NOW_HAS_ACTIVE_CLIP_REQUIRES_QA"
                if active:
                    severity = "HOLD"
            elif category == "technical_source_findings" or category == "targeted_quality_followup_findings":
                if exact or derived:
                    targets = list({tuple(x["slot"]) for x in exact + derived})
                    projection = None if resolved else "ACTIVE_SOURCE_FINDING"
                elif replacement_uses:
                    updated = targeted.get(replacement_pair)
                    code = row["cause"]
                    current_findings = [x for x in (updated or {}).get("findings", []) if x["code"] == code]
                    followup_claim = claims.get(replacement_pair)
                    all_current_proven = bool(current_findings and followup_claim and code == "FOREIGN_POSE_FOREGROUND_INSIDE_FRAME"
                                              and all(x.get("phase") in followup_claim["phases"] for x in current_findings))
                    # This is source-code coverage from the exact changed-source
                    # index, never a camera/identity/action or slot-level approval.
                    if updated and code in SOURCE_CODES and (not current_findings or all_current_proven):
                        projection = None
                        row["active_annotation"]["current_source_code_status"] = "REPLACED_EXACT_TARGETED_CODE_COVERED"
                    else:
                        projection = "SUPERSEDED_REQUIRES_QA"
                        severity = "HOLD"
                else:
                    projection = "SUPERSEDED_REQUIRES_QA" if not resolved else None
                    severity = "HOLD"
            elif category == "technical_slot_findings":
                # Technical registration proof is kept separate from visual
                # posture/camera acceptance. Revised slot measurements are not
                # claimed as the old baseline measurements.
                if not resolved:
                    projection = "ACTIVE_SLOT_FINDING" if record_state == "SAME_EXACT_RECORD" else "ACTIVE_RECORD_REVISED_REQUIRES_QA"
                    if record_state != "SAME_EXACT_RECORD":
                        severity = "HOLD"
            elif resolved:
                proof = row.get("resolution_proof") or {}
                corrected_pair = pair(proof.get("corrected_source"), proof.get("corrected_source_sha256"))
                if row["resolution_status"] == "RESOLVED_STATIC_CAMERA":
                    corrected_used = any(tuple(x["slot"]) == slot for x in selected_uses(corrected_pair) + derivative_uses(corrected_pair))
                    if not corrected_used:
                        projection = "HISTORICAL_CAMERA_PROOF_NOT_SELECTED_REQUIRES_QA"
                        severity = "HOLD"
            elif state == "SUPERSEDED_BY_EXACT_QUALITY_REPLACEMENT":
                projection = "SUPERSEDED_REQUIRES_QA"
                severity = "HOLD"
            elif state == "NOT_SELECTED_BY_ACTIVE_MANIFEST":
                projection = "SUPERSEDED_REQUIRES_QA"
                severity = "HOLD"
            else:
                projection = "ACTIVE_VISUAL_FINDING"
                if row["cause"] == "scale_registration" and slot in native:
                    projection = "OLD_RECORD_REGISTRATION_REPLACED_TECHNICAL_ONLY"
                    severity = "HOLD"
            row["active_annotation"]["active_residual_status"] = projection or "NO_ACTIVE_RESIDUAL_FOR_THIS_EXACT_CAUSE"
            if projection:
                for target in targets:
                    current = clips.get(target)
                    residual.append({"slot": list(target), "key": target[0], "actor": target[0].split(":")[-1],
                        "direction": target[1], "role": target[2], "cause": row["cause"],
                        "severity": severity, "projection_status": projection,
                        "evidence_category": category, "issue_id": row["issue_id"],
                        "historical_source": source, "historical_source_sha256": sha,
                        "active_record": current["record"] if current else None,
                        "active_record_sha256": current["record_sha256"] if current else None,
                        "active_sources": sorted({(x["source"], x["source_sha256"]) for x in current["selected_poses"]}) if current else [],
                        "source_activity": state})
    for index, old in enumerate(result.get("new_quality_remaining_findings", [])):
        slot = ("transform:" + old["actor"], old["direction"], old["role"])
        source_pair = pair(old["source"], old["source_sha256"])
        current = clips.get(slot)
        if not any(tuple(x["slot"]) == slot for x in selected_uses(source_pair) + derivative_uses(source_pair)):
            continue
        residual.append({"slot": list(slot), "key": slot[0], "actor": old["actor"],
            "direction": slot[1], "role": slot[2], "cause": old["cause"], "severity": "HOLD",
            "projection_status": "EXACT_CHANGED_SOURCE_REMAINING_HOLD", "evidence_category": "changed_source_visual_review",
            "issue_id": "changed-quality-hold-" + str(index), "historical_source": old["source"],
            "historical_source_sha256": old["source_sha256"], "active_record": current["record"],
            "active_record_sha256": current["record_sha256"],
            "active_sources": sorted({(x["source"], x["source_sha256"]) for x in current["selected_poses"]}),
            "source_activity": "ACTIVE_EXACT_OR_LOSSLESS_CHANGED_SOURCE"})
    for finding in result.get("targeted_active_quality_findings", []):
        slot = tuple(finding["slot"])
        current = clips[slot]
        residual.append({"slot": list(slot), "key": slot[0], "actor": slot[0].split(":")[-1],
            "direction": slot[1], "role": slot[2], "cause": finding["cause"],
            "severity": finding["status"], "projection_status": "EXACT_TARGETED_RUNTIME_REMAINING_FINDING",
            "evidence_category": "targeted_active_runtime_followup", "issue_id": finding["issue_id"],
            "historical_source": None, "historical_source_sha256": None,
            "active_record": current["record"], "active_record_sha256": current["record_sha256"],
            "active_sources": sorted({(x["source"], x["source_sha256"]) for x in current["selected_poses"]}),
            "source_activity": "ACTIVE_EXACT_TARGETED_RUNTIME_RECORD"})
    result["historical_source_activity"] = list(source_catalog.values())
    result["active_residual_issue_projections"] = residual
    result.update(deduplicate(residual))
    result["active_projection_notes"] = [
        "Historical issue occurrences and resolution_status are unchanged; active projections are a separate unit.",
        "SUPERSEDED_REQUIRES_QA denotes uncertainty on a revised active clip, not confirmation that an old defect persists.",
        "Exact changed-source technical-code absence is source-ownership scope only; visual clipping, camera, identity, action and registration are not implied clean.",
        "Native176 registration coverage is technical only; no camera/action approval is added.",
        "A clip may occur under several causes. Per-cause clip counts must not be summed as global unique clips."]
    return result


def deduplicate(rows):
    priority = {"HOLD": 0, "ERROR": 1, "BLOCKED": 2}
    groups = {}
    global_groups = {}
    for row in rows:
        slot = tuple(row["slot"])
        key = (row["cause"], row["severity"], slot)
        group = groups.setdefault(key, {k: row[k] for k in ("slot", "key", "actor", "direction", "role", "cause", "severity", "active_record", "active_record_sha256")})
        group.setdefault("issue_ids", []).append(row["issue_id"])
        group.setdefault("evidence_categories", set()).add(row["evidence_category"])
        group.setdefault("projection_statuses", set()).add(row["projection_status"])
        group.setdefault("active_sources", set()).update(tuple(x) for x in row.get("active_sources", []))
        group.setdefault("historical_sources", set()).add((path(row.get("historical_source")), row.get("historical_source_sha256")))
        global_group = global_groups.setdefault(slot, {"slot": list(slot), "highest_severity": row["severity"], "causes": set()})
        if priority[row["severity"]] > priority[global_group["highest_severity"]]:
            global_group["highest_severity"] = row["severity"]
        global_group["causes"].add(row["cause"])
    result = {}
    for (cause, severity, slot), group in sorted(groups.items()):
        group["issue_ids"] = sorted(set(group["issue_ids"]))
        group["evidence_categories"] = sorted(group["evidence_categories"])
        group["projection_statuses"] = sorted(group["projection_statuses"])
        group["active_sources"] = [{"source": p, "source_sha256": sha} for p, sha in sorted(group["active_sources"])]
        group["historical_sources"] = [{"source": p, "source_sha256": sha} for p, sha in sorted(group["historical_sources"], key=lambda x: (x[0], x[1] or ""))]
        result.setdefault(cause, {"ERROR": [], "HOLD": [], "BLOCKED": []})[severity].append(group)
    counts = {cause: {severity: len(items) for severity, items in levels.items()} for cause, levels in result.items()}
    global_rows = []
    for _, group in sorted(global_groups.items()):
        group["causes"] = sorted(group["causes"])
        global_rows.append(group)
    return {"active_residual_clips_by_cause_and_severity": result,
            "active_residual_clip_counts_by_cause_and_severity": counts,
            "active_residual_unique_clips": global_rows,
            "active_residual_units": {"projected_issue_occurrences": len(rows),
                                      "unique_active_or_missing_clips": len(global_rows),
                                      "unique_clips_by_highest_severity": dict(collections.Counter(x["highest_severity"] for x in global_rows)),
                                      "cause_severity_clip_rows": len(groups),
                                      "unique_referenced_active_source_files": len({tuple(x) for row in rows for x in row.get("active_sources", [])}),
                                      "source_count_scope": "Source files referenced by residual/uncertain clips; not a count of confirmed defective artwork"}}
