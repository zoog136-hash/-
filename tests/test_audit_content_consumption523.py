"""Synthetic contract tests. They do not certify original gameplay consumption."""

import copy
import contextlib
import hashlib
import importlib.util
import json
import io
from pathlib import Path
import sys
import struct
import tempfile
import unittest
import warnings
import zipfile


TOOL = Path(__file__).resolve().parents[1] / "tools" / "audit_content_consumption523.py"
SPEC = importlib.util.spec_from_file_location("audit_content_consumption523", TOOL)
audit = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = audit
SPEC.loader.exec_module(audit)


class ConsumptionAuditTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.repo = self.root / "checkout"
        (self.repo / "scripts").mkdir(parents=True)
        (self.repo / "tools").mkdir()
        (self.repo / "tests").mkdir()
        (self.repo / "scripts" / "consumer.gd").write_text(
            '# TableOne is a code mention, not evidence.\nfunc consume(): pass\n', encoding="utf-8")
        (self.repo / "tools" / "import.py").write_text("# TableOne\n", encoding="utf-8")
        (self.repo / "tests" / "fixture.gd").write_text("# TableOne\n", encoding="utf-8")
        self.source = self.root / "source.zip"
        self.make_zip([
            ("content/TableOne.json", {"rows": [{"ID": 1, "Value": 12}, {"ID": 2, "Value": 19}]}),
            ("content/TableTwo.json", {"rows": [{"ID": 1}]}),
            ("content/Empty.json", {"rows": []}),
            ("manifest.json", {"metadata": "not a content definition"}),
        ])
        self.source_sha, self.tables = audit.inventory_source(self.source)
        self.one = next(table for table in self.tables if table.name == "TableOne")

    def tearDown(self):
        self.temporary.cleanup()

    def make_zip(self, members):
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(self.source, "w", zipfile.ZIP_DEFLATED) as archive:
                for name, payload in members:
                    archive.writestr(name, json.dumps(payload, ensure_ascii=False).encode("utf-8"))

    def ledger(self, *records):
        return {"schema_version": 1, "source_sha256": self.source_sha, "records": list(records)}

    def record(self, status="partial"):
        return {
            "table": "TableOne", "status": status, "feature": "synthetic reader",
            "owner": "test owner", "reason": "Synthetic proof boundary test.",
            "remaining": "Not original runtime evidence.",
            "pipeline": {
                "parser": [{"path": "tools/import.py", "line": 1}],
                "runtime_consumer": [{"path": "scripts/consumer.gd", "symbol": "consume"}],
                "caller": [{"path": "scripts/consumer.gd", "line": 2}],
            },
            "evidence": [],
        }

    def gameplay(self, scope="partial_rows_or_fields"):
        # Synthetic metadata tests the gate. It is never sent to a real audit.
        trace = {
            "schema_version": 1, "kind": "gameplay_consumption_trace", "origin": "normal_gameplay",
            "fixture": False, "inspection_render": False, "source_sha256": self.source_sha,
            "source_json_sha256": self.one.sha256, "run_id": "synthetic-schema-test", "table": "TableOne",
            "caller": {"path": "scripts/consumer.gd"},
            "observations": [{"row_indices": [0, 1] if scope == "all_rows_all_fields" else [0], "fields": ["ID", "Value"]}],
        }
        artifact = self.root / "synthetic-trace.json"
        artifact.write_text(json.dumps(trace))
        return {
            "id": "run-proof", "kind": "gameplay", "origin": "normal_gameplay",
            "run_id": "synthetic-schema-test", "source_json_sha256": self.one.sha256,
            "reference": "private-trace-label", "scope": scope,
            "artifact": {"path": str(artifact), "sha256": hashlib.sha256(artifact.read_bytes()).hexdigest()},
        }

    def report(self, ledger=None, scan_static=True):
        return audit.build_report(self.source_sha, self.tables, ledger, self.repo, scan_static=scan_static)

    def test_inventory_is_complete_and_counts_original_bytes(self):
        self.assertEqual([table.name for table in self.tables], ["Empty", "TableOne", "TableTwo"])
        report = self.report()
        self.assertEqual(report["denominators"]["content_tables"], 3)
        self.assertEqual(report["denominators"]["source_rows"], 3)
        self.assertEqual(report["denominators"]["source_uncompressed_json_bytes"], sum(t.json_bytes for t in self.tables))
        self.assertEqual(report["metrics"]["status_table_counts"]["empty"], 1)

    def test_static_candidates_and_tests_do_not_prove_use(self):
        report = self.report()
        one = next(entry for entry in report["tables"] if entry["table"] == "TableOne")
        self.assertEqual(one["status"], "unresolved")
        self.assertEqual(len(one["static_candidates"]), 3)
        self.assertIn("fixture_or_test", {entry["role"] for entry in one["static_candidates"]})
        self.assertEqual(report["metrics"]["fully_consumed_tables_with_reviewed_gameplay_attestation"], 0)
        self.assertFalse(report["metrics"]["reviewed_ledger_attests_95_percent"])

    def test_load_only_and_fixture_records_cannot_claim_full_use(self):
        for kind in ("static_reference", "parse", "compile", "install", "fixture", "inspection_render"):
            with self.subTest(kind=kind):
                record = self.record("used")
                record["evidence"] = [{"id": "proof", "kind": kind, "reference": "probe", "scope": "all_rows_all_fields"}]
                record["coverage"] = {"rows": 2, "fields": ["ID", "Value"], "evidence_id": "proof"}
                with self.assertRaisesRegex(audit.AuditError, "normal-gameplay"):
                    self.report(self.ledger(record))

    def test_partial_table_never_adds_its_entire_bytes_to_use(self):
        record = self.record()
        record["evidence"] = [self.gameplay()]
        record["coverage"] = {"rows": 1, "fields": ["ID", "Value"], "evidence_id": "run-proof"}
        report = self.report(self.ledger(record))
        self.assertEqual(report["metrics"]["partial_tables"], 1)
        self.assertEqual(report["metrics"]["fully_consumed_tables_source_json_bytes"], 0)
        self.assertEqual(report["metrics"]["partial_table_source_bytes_counted_as_fully_consumed"], 0)
        self.assertIsNone(report["metrics"]["actual_gameplay_consumed_byte_extents"])

    def test_full_use_requires_every_row_field_and_explicit_gameplay_scope(self):
        record = self.record("used")
        record["evidence"] = [self.gameplay("all_rows_all_fields")]
        record["coverage"] = {"rows": 2, "fields": ["ID", "Value"], "evidence_id": "run-proof"}
        report = self.report(self.ledger(record))
        self.assertEqual(report["metrics"]["fully_consumed_tables_source_json_bytes"], self.one.json_bytes)
        for mutation in ("row", "field", "scope", "source", "origin"):
            broken = copy.deepcopy(record)
            if mutation == "row":
                broken["coverage"]["rows"] = 1
            elif mutation == "field":
                broken["coverage"]["fields"] = ["ID"]
            elif mutation == "scope":
                broken["evidence"][0]["scope"] = "load_only"
            elif mutation == "source":
                broken["evidence"][0]["source_json_sha256"] = "0" * 64
            else:
                broken["evidence"][0]["origin"] = "test_fixture"
            with self.subTest(mutation=mutation), self.assertRaises(audit.AuditError):
                self.report(self.ledger(broken))

    def test_gameplay_label_without_retained_runtime_artifact_is_rejected(self):
        record = self.record("used")
        evidence = self.gameplay("all_rows_all_fields")
        del evidence["artifact"]
        record["evidence"] = [evidence]
        record["coverage"] = {"rows": 2, "fields": ["ID", "Value"], "evidence_id": "run-proof"}
        with self.assertRaisesRegex(audit.AuditError, "retained runtime artifact"):
            self.report(self.ledger(record))

    def test_trace_checks_source_caller_integrity_and_row_field_coverage(self):
        for mutation in ("hash", "caller", "rows", "fields", "fixture", "source"):
            record = self.record("used")
            evidence = self.gameplay("all_rows_all_fields")
            path = Path(evidence["artifact"]["path"])
            trace = json.loads(path.read_text())
            if mutation == "hash":
                evidence["artifact"]["sha256"] = "0" * 64
            elif mutation == "caller":
                trace["caller"]["path"] = "scripts/unreviewed.gd"
            elif mutation == "rows":
                trace["observations"][0]["row_indices"] = [0]
            elif mutation == "fields":
                trace["observations"] = [
                    {"row_indices": [0], "fields": ["ID"]},
                    {"row_indices": [1], "fields": ["Value"]},
                ]
            elif mutation == "fixture":
                trace["fixture"] = True
            else:
                trace["source_sha256"] = "0" * 64
            if mutation != "hash":
                path.write_text(json.dumps(trace))
                evidence["artifact"]["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
            record["evidence"] = [evidence]
            record["coverage"] = {"rows": 2, "fields": ["ID", "Value"], "evidence_id": "run-proof"}
            with self.subTest(mutation=mutation), self.assertRaises(audit.AuditError):
                self.report(self.ledger(record))

    def test_exclusion_keeps_both_original_denominators(self):
        record = self.record("excluded")
        record["evidence"] = [{"id": "review", "kind": "source_review", "reference": "user-scope", "scope": "sound excluded"}]
        report = self.report(self.ledger(record))
        self.assertEqual(report["denominators"]["content_tables"], 3)
        self.assertFalse(report["denominators"]["exclusions_removed_from_denominators"])
        self.assertEqual(report["metrics"]["status_source_json_bytes"]["excluded"], self.one.json_bytes)
        self.assertEqual(report["metrics"]["fully_consumed_tables_source_json_bytes"], 0)

    def test_unknown_duplicate_and_invalid_status_records_are_rejected(self):
        unknown = self.record(); unknown["table"] = "Absent"
        invalid = self.record(); invalid["status"] = "loaded_so_used"
        for ledger in (self.ledger(unknown), self.ledger(self.record(), self.record()), self.ledger(invalid)):
            with self.subTest(ledger=ledger), self.assertRaises(audit.AuditError):
                self.report(ledger)

    def test_empty_status_must_match_source_rows(self):
        record = self.record("empty")
        with self.assertRaisesRegex(audit.AuditError, "zero-row"):
            self.report(self.ledger(record))

    def test_ledger_and_pipeline_are_bound_to_source_and_checkout(self):
        ledger = self.ledger(self.record()); ledger["source_sha256"] = "0" * 64
        with self.assertRaisesRegex(audit.AuditError, "source SHA256"):
            self.report(ledger)
        for name in ("../outside.py", "/absolute.py", "scripts/missing.gd"):
            record = self.record(); record["pipeline"]["parser"] = [{"path": name}]
            with self.subTest(name=name), self.assertRaises(audit.AuditError):
                self.report(self.ledger(record))

    def test_ambiguous_nested_duplicate_and_noncanonical_members_rejected(self):
        cases = [
            [("content/nested/Table.json", {"rows": []})],
            [("content/Table.json", {"rows": []}), ("content/Table.json", {"rows": []})],
            [("content/Table.json", {"rows": []}), ("content/table.json", {"rows": []})],
            [("content/../Table.json", {"rows": []})],
            [("content//Table.json", {"rows": []})],
        ]
        for members in cases:
            with self.subTest(members=members):
                self.make_zip(members)
                with self.assertRaises(audit.AuditError):
                    audit.inventory_source(self.source)

    def test_duplicate_json_keys_rejected(self):
        with self.assertRaisesRegex(audit.AuditError, "duplicate JSON key"):
            audit.read_json('{"records": [], "records": []}', "ledger")

    def test_top_level_payload_outside_rows_cannot_inflate_full_table_bytes(self):
        self.make_zip([("content/TableOne.json", {"rows": [{"ID": 1}], "unused": "x" * 10000})])
        with self.assertRaises(audit.AuditError):
            audit.inventory_source(self.source)

    def test_pinned_source_hash_and_table_count_are_enforced(self):
        with self.assertRaisesRegex(audit.AuditError, "expected-sha256"):
            audit.inventory_source(self.source, "0" * 64)
        with self.assertRaisesRegex(audit.AuditError, "expect-tables"):
            audit.inventory_source(self.source, self.source_sha, 1)
        self.assertEqual(len(audit.inventory_source(self.source, self.source_sha, 3)[1]), 3)

    def test_crc_is_checked_for_non_definition_metadata_too(self):
        raw = bytearray(self.source.read_bytes())
        offset = 0
        while True:
            offset = raw.find(b"PK\x01\x02", offset)
            self.assertGreaterEqual(offset, 0)
            name_size = struct.unpack_from("<H", raw, offset + 28)[0]
            name = bytes(raw[offset + 46:offset + 46 + name_size])
            if name == b"manifest.json":
                crc = struct.unpack_from("<I", raw, offset + 16)[0]
                struct.pack_into("<I", raw, offset + 16, crc ^ 1)
                break
            offset += 4
        self.source.write_bytes(raw)
        with self.assertRaisesRegex(audit.AuditError, "valid source ZIP"):
            audit.inventory_source(self.source)

    def test_bundled_index_and_summary_are_compared_with_actual_definitions(self):
        index = [{"path": t.member, "bytes": t.json_bytes, "row_count": t.rows,
                  "sha256": t.sha256, "fields": list(t.fields)} for t in self.tables]
        summary = {"tables": 3, "table_rows": 3, "raw_bytes": sum(t.json_bytes for t in self.tables)}
        with zipfile.ZipFile(self.source, "a") as archive:
            archive.writestr("index.json", json.dumps(index))
            archive.writestr("summary.json", json.dumps(summary))
        self.assertEqual(audit.verify_source_metadata(self.source, self.tables), ["index.json", "summary.json"])
        bad_tables = [audit.Table(t.name, t.member, t.rows + 1, t.json_bytes,
                                 t.compressed_bytes, t.sha256, t.fields, t.row_fields) for t in self.tables]
        with self.assertRaisesRegex(audit.AuditError, "index.*mismatch"):
            audit.verify_source_metadata(self.source, bad_tables)

    def test_source_and_ledger_aliases_cannot_be_overwritten(self):
        original = self.source.read_bytes()
        alias = self.root / "source-hardlink.zip"
        alias.hardlink_to(self.source)
        for output in (self.source, alias):
            with self.subTest(output=output), contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(audit.main([
                    "--source", str(self.source), "--repo", str(self.repo), "--output", str(output),
                ]), 1)
            self.assertEqual(self.source.read_bytes(), original)

    def test_runtime_trace_input_cannot_be_overwritten_by_report(self):
        record = self.record()
        record["evidence"] = [self.gameplay()]
        record["coverage"] = {"rows": 1, "fields": ["ID", "Value"], "evidence_id": "run-proof"}
        trace = Path(record["evidence"][0]["artifact"]["path"])
        original = trace.read_bytes()
        ledger_path = self.root / "ledger.json"
        ledger_path.write_text(json.dumps(self.ledger(record)))
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(audit.main([
                "--source", str(self.source), "--repo", str(self.repo),
                "--ledger", str(ledger_path), "--output", str(trace),
            ]), 1)
        self.assertEqual(trace.read_bytes(), original)

    def test_private_report_cannot_be_written_into_checkout(self):
        with self.assertRaisesRegex(audit.AuditError, "outside the checkout"):
            audit.private_output(self.repo / "docs" / "private-report.json", self.repo, "report")
        sibling = self.root / "other-checkout"
        (sibling / ".git").mkdir(parents=True)
        (sibling / ".git" / "HEAD").write_text("ref: refs/heads/main\n")
        with self.assertRaisesRegex(audit.AuditError, "another Git checkout"):
            audit.private_output(sibling / "report.json", self.repo, "report")

    def test_cli_writes_private_metadata_without_source_row_values(self):
        out = self.root / "report.json"
        old_tmp = out.with_name(out.name + ".tmp")
        old_tmp.symlink_to(self.source)
        original = self.source.read_bytes()
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(audit.main([
                "--source", str(self.source), "--repo", str(self.repo), "--output", str(out),
            ]), 0)
        self.assertEqual(self.source.read_bytes(), original)
        report = json.loads(out.read_text())
        self.assertEqual(report["classification"], "private_audit_metadata_do_not_publish")
        self.assertNotIn('"Value": 12', out.read_text())
        self.assertEqual(out.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
