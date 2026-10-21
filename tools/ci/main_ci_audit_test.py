#!/usr/bin/env python3
"""Offline checks; not a substitute for Godot or GitHub Actions results."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import main_ci_audit as audit

SHA = "e" * 40


def report(status="completed", conclusion="success"):
    return {"sha": SHA, "errors": [], "workflows": [{"file": "test.yml", "blockers": [],
        "run": {"id": 1, "head_sha": SHA, "head_branch": "main", "status": status, "conclusion": conclusion}}]}


class VerdictTests(unittest.TestCase):
    def test_success(self):
        self.assertEqual(audit.verdict(report()), "PASS")

    def test_empty_not_success(self):
        r = report(); r["workflows"] = []
        self.assertEqual(audit.verdict(r), "BLOCKED")

    def test_queued_not_success(self):
        self.assertEqual(audit.verdict(report("queued", None)), "INCOMPLETE")

    def test_running_not_success(self):
        self.assertEqual(audit.verdict(report("in_progress", None)), "INCOMPLETE")

    def test_failure(self):
        self.assertEqual(audit.verdict(report(conclusion="failure")), "FAIL")

    def test_cancelled(self):
        self.assertEqual(audit.verdict(report(conclusion="cancelled")), "FAIL")

    def test_skipped(self):
        self.assertEqual(audit.verdict(report(conclusion="skipped")), "FAIL")

    def test_neutral(self):
        self.assertEqual(audit.verdict(report(conclusion="neutral")), "FAIL")

    def test_missing_run(self):
        r = report(); r["workflows"][0].pop("run")
        self.assertEqual(audit.verdict(r), "INCOMPLETE")

    def test_wrong_sha(self):
        r = report(); r["workflows"][0]["run"]["head_sha"] = "a" * 40
        self.assertEqual(audit.verdict(r), "INCOMPLETE")

    def test_wrong_branch(self):
        r = report(); r["workflows"][0]["run"]["head_branch"] = "feature/pr122"
        self.assertEqual(audit.verdict(r), "INCOMPLETE")

    def test_blocker(self):
        r = report(); r["workflows"][0]["blockers"] = ["not registered"]
        self.assertEqual(audit.verdict(r), "BLOCKED")

    def test_api_error(self):
        r = report(); r["errors"] = ["cannot fetch all results"]
        self.assertEqual(audit.verdict(r), "BLOCKED")

    def test_failure_visible_while_other_job_pending(self):
        r = report(conclusion="failure"); r["workflows"] += report("queued", None)["workflows"]
        self.assertEqual(audit.verdict(r), "FAIL")


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.workflows = self.root / ".github/workflows"
        self.workflows.mkdir(parents=True)
        for name in audit.REQUIRED_CI:
            self.write(name, "  workflow_dispatch:\n  pull_request:\n    branches: [main]\n")

    def write(self, name, events):
        (self.workflows / name).write_text("name: test\non:\n" + events + "jobs:\n  validate:\n    runs-on: ubuntu-latest\n    steps: []\n")

    def test_on_key_not_boolean_and_paths_ignored(self):
        self.write("filtered.yml", "  workflow_dispatch:\n  pull_request:\n    branches: [main]\n    paths: ['scripts/never_changed.gd']\n")
        rows, _ = audit.inventory(self.root)
        self.assertIn("filtered.yml", {r["file"] for r in rows})
        self.assertFalse(any(r["blockers"] for r in rows))

    def test_manual_apply_not_dispatched(self):
        self.write("equipment-collections-apply.yml", "  workflow_dispatch:\n")
        rows, excluded = audit.inventory(self.root)
        self.assertNotIn("equipment-collections-apply.yml", {r["file"] for r in rows})
        self.assertIn("equipment-collections-apply.yml", {r["file"] for r in excluded})

    def test_other_branch_not_dispatched(self):
        self.write("private-feature.yml", "  workflow_dispatch:\n  push:\n    branches: [feature/pr122]\n")
        rows, _ = audit.inventory(self.root)
        self.assertNotIn("private-feature.yml", {r["file"] for r in rows})

    def test_missing_dispatch_is_blocker(self):
        self.write("no-dispatch.yml", "  pull_request:\n    branches: [main]\n")
        rows, _ = audit.inventory(self.root)
        self.assertTrue(next(r for r in rows if r["file"] == "no-dispatch.yml")["blockers"])

    def test_required_input_is_blocker(self):
        self.write("required.yml", "  pull_request:\n  workflow_dispatch:\n    inputs:\n      pack:\n        required: true\n")
        rows, _ = audit.inventory(self.root)
        self.assertTrue(next(r for r in rows if r["file"] == "required.yml")["blockers"])

    def test_default_input_accepted(self):
        self.write("default.yml", "  pull_request:\n  workflow_dispatch:\n    inputs:\n      pack:\n        required: true\n        default: checked\n")
        rows, _ = audit.inventory(self.root)
        self.assertFalse(next(r for r in rows if r["file"] == "default.yml")["blockers"])

    def test_required_workflow_cannot_disappear(self):
        (self.workflows / "godot-validate.yml").unlink()
        with self.assertRaises(ValueError):
            audit.inventory(self.root)

    def test_manual_read_only_audit_included(self):
        self.write("main-debug-audit.yml", "  workflow_dispatch:\n")
        rows, _ = audit.inventory(self.root)
        self.assertIn("main-debug-audit.yml", {r["file"] for r in rows})

    def test_branch_pattern_order(self):
        self.assertTrue(audit.permits_main({"branches": ["*", "!main", "main"]}))
        self.assertFalse(audit.permits_main({"branches": ["*", "!main"]}))
        self.assertFalse(audit.permits_main({"branches-ignore": ["main"]}))

    def test_pagination(self):
        api = audit.GitHub("zoog136-hash/-", "unused")
        with patch.object(api, "request", side_effect=[{"items": [{"id": n} for n in range(100)]}, {"items": [{"id": 100}]}]) as request:
            self.assertEqual(len(api.pages("/test", "items")), 101)
            self.assertEqual(request.call_count, 2)

    def test_main_move_blocks_dispatch(self):
        api = audit.GitHub("zoog136-hash/-", "unused")
        with patch.object(api, "request", return_value={"object": {"sha": "a" * 40}}) as request:
            with patch.object(audit.subprocess, "check_output", return_value=SHA + "\n"):
                result = audit.run_audit(api, self.root, SHA, self.root / "report.json")
            self.assertEqual(result["verdict"], "BLOCKED")
            self.assertEqual(request.call_count, 1)
            self.assertIsNone(request.call_args.kwargs.get("data"))


if __name__ == "__main__":
    unittest.main()
