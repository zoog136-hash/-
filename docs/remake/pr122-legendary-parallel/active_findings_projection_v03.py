"""Keep QA capture-environment limitations out of character-art residual units.

The v02 metadata projection is reused unchanged. Only the newly supplied targeted
runtime findings typed capture_environment/QA_ENVIRONMENT_HOLD are separated.
"""
from __future__ import annotations

import active_findings_projection_v02 as previous

build_active_index = previous.build_active_index
hydrate_historical_records = previous.hydrate_historical_records
quality_lineages = previous.quality_lineages


def is_qa_environment(finding):
    return finding.get("cause") == "capture_environment" or finding.get("finding_type") == "QA_ENVIRONMENT_HOLD"


def annotate(result, clips, ownership, lineages, targeted_sources):
    all_targeted = result.get("targeted_active_quality_findings", [])
    qa = [finding for finding in all_targeted if is_qa_environment(finding)]
    art = [finding for finding in all_targeted if not is_qa_environment(finding)]
    result["targeted_active_quality_findings"] = art
    try:
        previous.annotate(result, clips, ownership, lineages, targeted_sources)
    finally:
        result["targeted_active_quality_findings"] = all_targeted
    rows = []
    for finding in qa:
        slot = tuple(finding["slot"])
        selected = clips[slot]
        rows.append({"slot": list(slot), "key": slot[0], "actor": slot[0].split(":")[-1],
                     "direction": slot[1], "role": slot[2], "cause": finding["cause"],
                     "severity": finding["status"], "finding_type": "QA_ENVIRONMENT_HOLD",
                     "projection_status": "QA_CAPTURE_ENVIRONMENT_LIMITATION_NOT_IDENTIFIED_ART_DEFECT",
                     "evidence_category": "targeted_capture_environment_followup", "issue_id": finding["issue_id"],
                     "detail": finding["detail"], "frames": finding.get("frames", []),
                     "active_record": selected["record"], "active_record_sha256": selected["record_sha256"],
                     "active_sources": sorted({(pose["source"], pose["source_sha256"]) for pose in selected["selected_poses"]}),
                     "historical_source": None, "historical_source_sha256": None,
                     "rendered_evidence": finding["rendered_evidence"],
                     "artifact": finding["artifact"], "artifact_sha256": finding["artifact_sha256"]})
    qa_dedup = previous.deduplicate(rows)
    result["qa_environment_remaining_findings"] = qa
    result["qa_environment_issue_projections"] = rows
    result["qa_environment_residual_clips_by_cause_and_severity"] = qa_dedup["active_residual_clips_by_cause_and_severity"]
    result["qa_environment_residual_unique_clips"] = qa_dedup["active_residual_unique_clips"]
    result["qa_environment_residual_units"] = qa_dedup["active_residual_units"]
    art_slots = {tuple(row["slot"]) for row in result["active_residual_unique_clips"]}
    qa_slots = {tuple(row["slot"]) for row in result["qa_environment_residual_unique_clips"]}
    result["art_and_QA_residual_unit_relationship"] = {
        "art_or_art_uncertainty_unique_clips": len(art_slots),
        "qa_environment_unique_clips": len(qa_slots),
        "shared_clip_keys": [list(slot) for slot in sorted(art_slots & qa_slots)],
        "union_unique_clips": len(art_slots | qa_slots),
        "do_not_add_art_and_QA_clip_counts_without_dedup": True,
        "qa_capture_hold_is_not_source_or_resource_load_failure": True,
        "production_native_import_export_approval": False,
    }
    result["active_projection_notes"].append(
        "capture_environment is reported in separate QA environment fields; it is not an identified character-art defect, does not change prior actual full-render proof, and grants no native import/export approval.")
    return result
