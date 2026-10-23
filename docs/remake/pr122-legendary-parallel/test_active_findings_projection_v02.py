import copy
import json
from pathlib import Path
import tempfile
import unittest

import active_findings_projection_v02 as active
import reconcile_remaining_findings_v02 as runner

SHA = "a" * 64
NEW_SHA = "b" * 64
REC_SHA = "c" * 64
SLOT = ("transform:402", "SW", "idle")


def clip(source="new.png", sha=NEW_SHA, slot=SLOT, record="new-record.json"):
    return {"slot": list(slot), "record": record, "record_sha256": REC_SHA,
            "SpriteFrames": "new.tres", "SpriteFrames_sha256": "d" * 64,
            "record_ancestors": [],
            "selected_poses": [{"frame": i, "source": source, "source_sha256": sha,
                                "source_phase": i, "region": [i, 0, 1, 1]} for i in range(6)]}


def result(row, category="visual_findings"):
    return {"visual_findings": [], "technical_source_findings": [], "technical_slot_findings": [],
            "targeted_quality_followup_findings": [], "new_quality_remaining_findings": [],
            "native176_registration": {"slots": []}, category: [row]}


def issue(cause="camera", status="UNMODIFIED"):
    return {"slot": list(SLOT), "actor": "402", "direction": "SW", "role": "idle",
            "affected_source": "old.png", "source_sha256": SHA, "record": "old-record.json",
            "historical_record_sha256": "e" * 64, "issue_id": "one", "cause": cause,
            "status": "ERROR_VISUAL", "resolution_status": status, "resolution_proof": None}


def lineage():
    return {("old.png", SHA): {"source": "new.png", "source_sha256": NEW_SHA,
                               "record": "new-record.json", "record_sha256": REC_SHA}}


class ActiveProjectionTests(unittest.TestCase):
    def test_exact_selected_camera_proof_closes_only_its_current_cause(self):
        row = issue(status="RESOLVED_STATIC_CAMERA")
        row["resolution_proof"] = {"corrected_source": "new.png", "corrected_source_sha256": NEW_SHA}
        r = result(row)
        active.annotate(r, {SLOT: clip()}, {}, lineage(), [])
        self.assertEqual(r["active_residual_units"]["unique_active_or_missing_clips"], 0)
        self.assertEqual(row["resolution_status"], "RESOLVED_STATIC_CAMERA")

    def test_wrong_source_sha_does_not_select_historical_camera_proof(self):
        row = issue(status="RESOLVED_STATIC_CAMERA")
        row["resolution_proof"] = {"corrected_source": "new.png", "corrected_source_sha256": SHA}
        r = result(row)
        active.annotate(r, {SLOT: clip()}, {}, lineage(), [])
        self.assertEqual(r["active_residual_issue_projections"][0]["severity"], "HOLD")
        self.assertIn("NOT_SELECTED", r["active_residual_issue_projections"][0]["projection_status"])

    def test_replaced_source_technical_clean_does_not_clear_visual_clipping(self):
        row = issue("FOREIGN_POSE_FOREGROUND_INSIDE_FRAME")
        row["source"] = row.pop("affected_source")
        row["finding"] = {"severity": "ERROR", "phase": 0}
        technical = result(row, "technical_source_findings")
        targeted = [{"source": "new.png", "sha256": NEW_SHA, "findings": []}]
        active.annotate(technical, {SLOT: clip()}, {}, lineage(), targeted)
        self.assertEqual(technical["active_residual_units"]["unique_active_or_missing_clips"], 0)
        visual = result(issue("clipped_or_foreign_body"))
        active.annotate(visual, {SLOT: clip()}, {}, lineage(), targeted)
        self.assertEqual(visual["active_residual_issue_projections"][0]["projection_status"], "SUPERSEDED_REQUIRES_QA")
        self.assertEqual(visual["visual_findings"][0]["resolution_status"], "UNMODIFIED")

    def test_borrowed_old_pose_remains_active_after_author_clip_replacement(self):
        borrowed_slot = ("transform:402", "SW", "attack")
        borrowed = clip("old.png", SHA, borrowed_slot)
        borrowed["selected_poses"] = borrowed["selected_poses"][:1] + clip(slot=borrowed_slot)["selected_poses"][1:]
        row = issue("FOREIGN_POSE_FOREGROUND_INSIDE_FRAME")
        row["source"] = row.pop("affected_source")
        row["finding"] = {"severity": "ERROR", "phase": 0}
        r = result(row, "technical_source_findings")
        active.annotate(r, {SLOT: clip(), borrowed_slot: borrowed}, {}, lineage(), [])
        self.assertEqual(r["active_residual_issue_projections"][0]["slot"], list(borrowed_slot))
        self.assertEqual(row["active_annotation"]["source_activity"], "ACTIVE_EXACT_SOURCE")

    def test_native_registration_does_not_grant_camera_or_motion_approval(self):
        slot = ("transform:176", "S", "idle")
        row = issue("scale_registration")
        row.update(slot=list(slot), actor="176", direction="S", status="HOLD")
        r = result(row)
        r["native176_registration"]["slots"] = [{"slot": list(slot), "record": "new-record.json"}]
        active.annotate(r, {slot: clip("old.png", SHA, slot)}, {}, {}, [])
        self.assertEqual(r["active_residual_issue_projections"][0]["projection_status"], "OLD_RECORD_REGISTRATION_REPLACED_TECHNICAL_ONLY")
        self.assertEqual(row["resolution_status"], "UNMODIFIED")

    def test_dedup_counts_occurrences_and_clip_units_separately(self):
        row = {"slot": list(SLOT), "key": SLOT[0], "actor": "402", "direction": "SW", "role": "idle",
               "cause": "camera", "severity": "ERROR", "active_record": "r.json", "active_record_sha256": REC_SHA,
               "issue_id": "one", "evidence_category": "visual", "projection_status": "ACTIVE",
               "historical_source": "old.png", "historical_source_sha256": SHA, "active_sources": [("old.png", SHA)]}
        two = dict(row, issue_id="two")
        three = dict(row, issue_id="three", cause="articulation", severity="HOLD")
        r = active.deduplicate([row, two, three])
        self.assertEqual(r["active_residual_units"]["projected_issue_occurrences"], 3)
        self.assertEqual(r["active_residual_units"]["unique_active_or_missing_clips"], 1)
        self.assertEqual(r["active_residual_clip_counts_by_cause_and_severity"]["camera"]["ERROR"], 1)

    def test_actual_selected_sequence_excludes_raw_parent_history(self):
        record = {"source": "new.png", "source_sha256": NEW_SHA, "source_files": [],
                  "automatic_checks": [{"index": i, "rgba_sha256": SHA, "region": [0, 0, 1, 1]} for i in range(6)],
                  "revision_source_pose_sequence": [{"source": "new.png", "phase": i, "region": [i, 0, 1, 1]} for i in range(6)],
                  "raw_parent_source_pose_sequence": [{"source": "old.png"}]}
        self.assertEqual({x["source"] for x in active.selected_poses(record)}, {"new.png"})

    def test_false_gate_prevents_any_final_reconciliation(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "gate.json"
            p.write_text(json.dumps({"all_possible_corrections_complete": False,
                                     "local_integration_checks_complete": False}))
            with self.assertRaisesRegex(ValueError, "no reconciliation executed"):
                runner.finalize(p)

    def test_targeted_runtime_hold_requires_exact_selected_record(self):
        class Evidence:
            def artifact(self, reference):
                return {"findings": [{"slot": list(SLOT), "active_record": "new-record.json",
                        "active_record_sha256": SHA, "status": "HOLD", "cause": "articulation",
                        "rendered_evidence": {"path": "render.png", "sha256": NEW_SHA}}]}, REC_SHA
        gate = {"targeted_active_quality_followups": [{"path": "followup.json", "sha256": REC_SHA}]}
        with self.assertRaisesRegex(ValueError, "selected exact record"):
            runner.targeted_active_followups(Evidence(), gate, {SLOT: clip()})

    def test_reordered_clip_retains_physical_source_sheet_phase(self):
        record = {"source": "new.png", "source_sha256": NEW_SHA, "source_files": [],
                  "automatic_checks": [{"index": i, "rgba_sha256": SHA, "region": [0, 0, 1, 1]} for i in range(6)],
                  "source_pose_sequence": [{"phase": i, "new_sheet_cell": i // 2} for i in range(6)],
                  "revision_source_pose_sequence": [{"source": "new.png", "phase": i,
                      "original_phase": old, "region": [old, 0, 1, 1]} for i, old in enumerate([0, 1, 2, 3, 5, 4])]}
        poses = active.selected_poses(record)
        self.assertEqual(poses[4]["source_phase"], 2)


if __name__ == "__main__":
    unittest.main()
