#!/usr/bin/env python3
"""Versioned JSON-only reconciliation with separate character-art and QA residuals.

Derived from preserved reconcile_remaining_findings_v02.py SHA256
fd6021ac04f73aa93e023c190a587b60652832231ba2218921c27a264f000741.

--prepare-gate collects completed evidence references but never resolves findings.
--finalize requires the root's explicit completed runtime/CI gate and runs once.
No PNG/resource read, generation, visual review or repository mutation occurs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import reconcile_remaining_findings_v01 as core
import active_findings_projection_v04 as active

CORE_SHA = "a7f618848349d7a1c7334bb328fa6852aa7ce047dd01df558a96643a32f991c3"


class Evidence(core.Evidence):
    """Memoize identical committed-JSON checks, retaining every exact SHA check."""
    def __init__(self, repo, head):
        super().__init__(repo, head)
        self.committed_checks = set()

    def committed_json(self, path, commit, expected):
        key = (str(path), commit, expected)
        if key not in self.committed_checks:
            super().committed_json(path, commit, expected)
            self.committed_checks.add(key)


def assert_core():
    if hashlib.sha256(Path(core.__file__).read_bytes()).hexdigest() != CORE_SHA:
        raise ValueError("Preserved v01 implementation differs from the pinned source")


def ref(path):
    _, sha = core.safe_json(path)
    return {"path": str(path), "sha256": sha}


def local_ref(reference):
    raw = core.path_text(reference["path"])
    return Path(raw) if raw.startswith("/") else core.WORK / raw


def prepare_gate():
    """Preparation only: no reconciliation/projection/whole-corpus traversal."""
    folder = core.WORK / core.PREFIX
    template, _ = core.safe_json(folder / "remaining-findings-final-gate-template-v01.json")
    delivery, delivery_sha = core.safe_json(folder / "final-correction-delivery-evidence-v01.json")
    native_path = folder / "native-registration-remote-saved-v01.json"
    native, _ = core.safe_json(native_path)
    gate = dict(template)
    gate.update(schema="pr122-legendary-final-reconciliation-gate-v4",
                all_possible_corrections_complete=False,
                local_integration_checks_complete=False,
                repository_head="ROOT_TO_SET_FULL_40_CHARACTER_COMMIT",
                asset_staging_freeze_head=delivery["asset_staging_freeze_head"],
                delivery_evidence=ref(folder / "final-correction-delivery-evidence-v01.json"),
                active_staging={"path": "res://data/pr122_legendary_parallel_staging.json",
                                "sha256": delivery["staging_sha256"]},
                active_manifest={"path": delivery["active_manifest"],
                                 "sha256": delivery["active_manifest_sha256"]},
                targeted_technical_artifacts=delivery["targeted_technical_artifacts"],
                targeted_active_quality_followups=[],
                integration_receipts=[], output_stem="remaining-findings-final-v04",
                preparation_status="PREPARED_ONLY_FINAL_EXECUTIONS_0",
                generation_calls=0, PNG_reads=0)
    complete = []
    excluded = []
    for batch in delivery["batches"]:
        receipt, receipt_sha = core.safe_json(local_ref(batch["remote_receipt"]))
        if receipt_sha != batch["remote_receipt"]["sha256"]:
            raise ValueError("Prepared remote receipt SHA drift")
        if receipt.get("status") != "REMOTE_SAVED":
            excluded.append(batch)
            continue
        for reference in [batch["manifest"], *batch["validations"]]:
            _, sha = core.safe_json(local_ref(reference))
            if sha != reference["sha256"]:
                raise ValueError("Prepared manifest/validation SHA drift")
        complete.append(batch)
    # Receipt kinds are preserved verbatim by the writer; select quality by its
    # fixed typed kind, and recognize ownership delta by its source manifest.
    gate["ownership_batches"] = [x for x in complete if x["kind"] != "quality_source_correction"]
    gate["quality"] = {"review": ref(folder / "quality-v02/changed-source-visual-review-v01.json"),
                       "exact_receipt": ref(folder / "quality-v02/changed-source-visual-review-receipt-v01.json"),
                       "quota_checkpoint": ref(folder / "quality-v02/tool-quota-checkpoint-v01.json"),
                       "batches": [x for x in complete if x["kind"] == "quality_source_correction"]}
    if native.get("status") != "REMOTE_SAVED":
        raise ValueError("Native registration is not remotely saved")
    gate["native176"] = {"library": native["manifest"], "review_input": native["review_input"],
                         "validations": native["validations"], "remote_receipt": ref(native_path)}
    gate["excluded_pending_batches"] = excluded
    gate["prepared_remote_batch_counts"] = {"ownership": len(gate["ownership_batches"]),
                                            "quality": len(gate["quality"]["batches"]), "native_registration": 1}
    gate["instruction"] = ("Root must supply the final full repository HEAD, exact final runtime/CI integration_receipts, "
                           "and explicitly set both completion booleans only after those checks finish. "
                           "Active staging/manifest SHA are frozen at the asset head. Pending remote is inadmissible. "
                           "No active residual or resolved count is computed by preparation. Historical findings stay separate "
                           "from active cause/severity/slot-deduplicated residuals. Native176 remains technical registration only.")
    gate["repository_head"] = "a2dbbb01659e562980653c8d33898d3b7d761e58"
    gate["staging_import_exclusion_head"] = gate["repository_head"]
    gate["targeted_active_quality_followups"] = [
        ref(folder / "targeted-runtime-quality-followup-v01.json"),
        ref(folder / "targeted-runtime-capture-environment-hold-v01.json"),
    ]
    gate["integration_receipts"] = [
        ref(folder / "final-runtime-integration-reconciled-v01.json"),
        ref(folder / "staging-import-exclusion-validation-v01.json"),
        ref(folder / "final-github-ci-receipt-v01.json"),
    ]
    gate["qa_environment_scope"] = "capture_environment is a QA limitation, reported separately from visual/art defects"
    gate["production_native_import_export_approval"] = False
    gate["pending_final_inputs"] = ["Root completed final CI2 receipt+SHA", "Root final repository HEAD confirmation", "Root explicit both completion booleans true"]
    output = folder / "remaining-findings-final-gate-prepared-v04.json"
    core.write_new(output, gate)
    print(json.dumps({"status": "GATE_PREPARED_NOT_EXECUTED", "remote_batches": len(complete),
                      "delivery_evidence_sha256": delivery_sha, "final_executions": 0, "PNG_reads": 0}))


def followup_rows(followups, ownership):
    rows = []
    for item in followups:
        source = item["source"]
        claim = ownership.get(source["source"])
        for i, finding in enumerate(source["findings"]):
            resolved = bool(claim and claim["source_sha256"] == source["sha256"]
                            and finding["code"] == "FOREIGN_POSE_FOREGROUND_INSIDE_FRAME"
                            and finding.get("phase") in claim["phases"])
            rows.append({"issue_id": "targeted-source-" + source["sha256"][:16] + "-" + str(i),
                         "slot": source["authored_slot"], "source": source["source"],
                         "source_sha256": source["sha256"], "cause": finding["code"], "finding": finding,
                         "targeted_artifact": item["artifact"], "targeted_artifact_sha256": item["artifact_sha256"],
                         "resolution_status": "RESOLVED_TECHNICAL_OWNERSHIP" if resolved else
                         ("HOLD" if finding["severity"] == "HOLD" else "UNMODIFIED"),
                         "resolution_proof": core.proof_reference(claim) if resolved else None})
    return rows


def korean_markdown(result, name):
    units = result["active_residual_units"]
    correction = result["correction_attempts"]
    native = result["native176_registration"]
    lines = ["전설급 최종 증거 대조와 활성 구성 잔여", "",
             f"확정 검토 `{core.BASELINE[:12]}`의 역사 원본·오류 목록은 보존했습니다. 최종 승인 추가0.", "",
             "역사 issue 발생건수와 현재 활성 clip 수는 별도입니다. 대체된 원본의 HOLD는 활성 원본에서 같은 오류가 확인됐다는 뜻이 아닙니다.", "",
             f"현재 오류·불확실성 투영은 {units['projected_issue_occurrences']}건이며, 중복 제거한 활성/미생성 구성은 {units['unique_active_or_missing_clips']}개입니다. 원인별 구성 수는 서로 겹칠 수 있습니다.", "",
             "|현재 원인|ERROR 구성|HOLD 구성|BLOCKED 구성|", "|---|---:|---:|---:|"]
    for cause, counts in sorted(result["active_residual_clip_counts_by_cause_and_severity"].items()):
        lines.append(f"|{cause}|{counts['ERROR']}|{counts['HOLD']}|{counts['BLOCKED']}|")
    lines += ["", "SUPERSEDED_REQUIRES_QA와 수정 record 재검토 HOLD는 이전 원본과 현재 clip을 구분하는 불확실성입니다. 기존 결함의 잔존 확정으로 집계하지 않았습니다.", "",
              f"원래 미생성은274 NE ATTACK moderation BLOCKED1개입니다. 교정 PNG {correction['verified_remote_saved_sources']}개와 API한도 실패 {correction['blocked_quota_no_retry']}개, 미호출 {correction['pending_never_called']}개를 구분했습니다.", "",
              f"176 등록 {native['verified_clips']}구성/{native['verified_frames']}프레임은 기술 등록만 확인했습니다. 카메라·동작 승인0입니다.", "",
              f"정확한 actor·방향·동작·원본/활성 record/source SHA·proof·원인별 ERROR/HOLD/BLOCKED 목록은 [{name}]({name})에 있습니다. PNG 재열람·전체 시각 재검토·추가 생성0.", ""]
    qa = result["qa_environment_residual_units"]
    lines += ["", f"별도 QA 환경 HOLD는 {qa['projected_issue_occurrences']}건/{qa['unique_active_or_missing_clips']}구성입니다. 원화 결함과 분리했고, 기존 전체 실제 재생1319 PASS 증거는 별도로 유지합니다. staging 자동 import 분리는 네이티브 import/export 통합 승인이 아닙니다.", ""]
    return "\n".join(lines)


def integration_artifacts(evidence, gate):
    """Pin completed result JSONs and reject active-input mismatches if present."""
    output = []
    for reference in gate["integration_receipts"]:
        report, sha = evidence.artifact(reference)
        if report.get("staging_sha256") and report["staging_sha256"] != gate["active_staging"]["sha256"]:
            raise ValueError("Integration report observed a different staging SHA")
        if report.get("manifest_sha256") and report["manifest_sha256"] != gate["active_manifest"]["sha256"]:
            raise ValueError("Integration report observed a different active manifest SHA")
        metadata = {k: report[k] for k in ("schema", "status", "conclusion", "complete", "commit", "engine",
                    "staging_sha256", "manifest_sha256", "real_render", "expected_configurations",
                    "PASS", "EXPECTED_BLOCKED", "FAIL", "failures", "errors", "run_id", "workflow", "url",
                    "production_native_import_export_approval", "explicit_loader_cases_passed", "source_or_resource_load_errors",
                    "normal_speed_render_capture", "staging_PNG_import_sidecars") if k in report}
        output.append({"path": reference["path"], "sha256": sha, "reported_result": metadata})
    return output


def targeted_active_followups(evidence, gate, clips):
    findings = []
    for reference in gate.get("targeted_active_quality_followups", []):
        artifact, artifact_sha = evidence.artifact(reference)
        if artifact.get("frozen_review_sha256", core.FROZEN_SHA) != core.FROZEN_SHA:
            raise ValueError("Targeted active followup changed the frozen review")
        for i, finding in enumerate(artifact.get("findings", [])):
            slot = tuple(finding["slot"])
            selected = clips.get(slot)
            if not selected or core.path_text(finding["active_record"]) != selected["record"] or finding["active_record_sha256"] != selected["record_sha256"]:
                raise ValueError("Targeted active followup does not match the selected exact record")
            if finding.get("status") not in ("HOLD", "ERROR"):
                raise ValueError("Targeted followup may report only residual HOLD/ERROR; it cannot approve or resolve")
            rendered = finding["rendered_evidence"]
            if not core.HEX.fullmatch(rendered.get("sha256", "")):
                raise ValueError("Targeted render evidence must have an exact SHA")
            findings.append(dict(finding, issue_id="targeted-active-" + artifact_sha[:16] + "-" + str(i),
                                 artifact=reference["path"], artifact_sha256=artifact_sha))
    return findings


def finalize(gate_path):
    assert_core()
    gate, gate_sha = core.safe_json(gate_path)
    if not gate.get("all_possible_corrections_complete") or not gate.get("local_integration_checks_complete"):
        raise ValueError("Root completion gate is not final; no reconciliation executed")
    if not gate.get("integration_receipts"):
        raise ValueError("Exact final runtime/CI receipt artifacts are required; no reconciliation executed")
    if not gate.get("active_staging") or not gate.get("active_manifest"):
        raise ValueError("Exact active staging and manifest are required")
    head = gate.get("repository_head", "")
    if not core.COMMIT.fullmatch(head):
        raise ValueError("Final repository head must be a full commit SHA")
    stem = gate.get("output_stem", "remaining-findings-final-v04")
    if not core.re.fullmatch("[a-z0-9-]+", stem):
        raise ValueError("Invalid output name")
    out = core.WORK / core.PREFIX / (stem + ".json")
    md = core.WORK / core.PREFIX / (stem + "-KO.md")
    if out.exists() or md.exists():
        raise ValueError("Final report already exists; no second final reconciliation")
    evidence = Evidence(gate.get("repository_root", str(core.REPO)), head)
    frozen, frozen_sha = evidence.artifact(gate["frozen"])
    technical, technical_sha = evidence.artifact(gate["technical_review"])
    if frozen_sha != core.FROZEN_SHA or frozen.get("baseline_sha") != core.BASELINE:
        raise ValueError("Immutable frozen review mismatch")
    pinned = next(x for x in frozen["source_artifacts"] if x["path"].endswith("technical-single-review-v01.json"))
    if pinned["sha256"] != technical_sha:
        raise ValueError("Technical review differs from frozen artifact")
    ownership, batches, followups = core.ownership_evidence(evidence, gate, technical, technical_sha)
    camera, holds, quota, qproof = core.quality_evidence(evidence, gate, frozen)
    native = core.native_registration_evidence(evidence, gate)
    adjudications = {}
    for reference in gate.get("visual_issue_adjudications", []):
        artifact, sha = evidence.artifact(reference)
        if artifact.get("frozen_review_sha256") != core.FROZEN_SHA:
            raise ValueError("Issue adjudication frozen SHA mismatch")
        for claim in artifact.get("claims", []):
            adjudications[claim["issue_id"]] = dict(claim, adjudication_artifact=reference["path"], adjudication_sha256=sha)
    result = core.reconcile(frozen, technical, camera, ownership, holds, quota, native,
                            adjudications, qproof["verified_saved_corrections"])
    result.update(schema="pr122-legendary-proof-reconciled-active-and-QA-residuals-v4",
                  final_repository_head=head, final_gate_sha256=gate_sha,
                  ownership_completed_batches=batches, proven_unique_ownership_sources=len(ownership),
                  ownership_proof_catalog=list(ownership.values()), quality_review_proofs=qproof,
                  rejected_or_incomplete_evidence=evidence.rejected,
                  integration_evidence=integration_artifacts(evidence, gate))
    result["targeted_quality_followup_findings"] = followup_rows(followups, ownership)
    result["targeted_followup_proven_sources"] = [x for x in ownership.values() if x.get("origin") == "targeted_quality_followup"]
    active.hydrate_historical_records(evidence, result)
    clips, selection = active.build_active_index(evidence, gate, ownership)
    result["active_selection_evidence"] = selection
    result["active_selected_clips"] = list(clips.values())
    result["targeted_active_quality_findings"] = targeted_active_followups(evidence, gate, clips)
    lineages = active.quality_lineages(evidence, qproof["verified_saved_corrections"])
    targeted = [item["source"] for item in followups]
    active.annotate(result, clips, ownership, lineages, targeted)
    core.write_new(out, result)
    core.write_new(md, korean_markdown(result, out.name))
    print(json.dumps({"status": "FINAL_JSON_PROOF_RECONCILIATION_COMPLETE", "JSON": str(out),
                      "Korean_MD": str(md), "PNG_reads": 0, "new_approvals": 0}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--prepare-gate", action="store_true")
    mode.add_argument("--finalize", action="store_true")
    parser.add_argument("--gate", type=Path)
    args = parser.parse_args()
    if args.prepare_gate:
        assert_core()
        prepare_gate()
    elif args.gate:
        finalize(args.gate)
    else:
        parser.error("--finalize requires the root's completed --gate JSON")
