"""Native-selector receipt connections; synthetic source/opaque bytes, no art."""
from __future__ import annotations

from contextlib import redirect_stdout
import copy
import gzip
import hashlib
import io
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest import mock
import zipfile
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/lineagem_original"))
import client523_bank_metadata as metadata_generator
import connect_received_sp2_bank as connector


def write_rows(path, rows):
    path.write_bytes(gzip.compress(b"".join((json.dumps(row) + "\n").encode() for row in rows), mtime=0))


class ConnectReceivedNativeSelectorTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="connect-native-selector-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.client = self.base / "client"
        spr = self.client / "spr"
        spr.mkdir(parents=True)
        (spr / "list_0.spr").write_bytes(b"#10 4 Source\n110.framerate(24)\n0.walk(0 1,0.0:2)\n#30 4=10 File_alias_only\n")
        (spr / "list_9.spr").write_bytes(b"#20 4 Requested_alias\n110.framerate(2)\n0=10\n#21 4 Alias_chain\n0=20\n")
        self.body = b"opaque_received_fixture_not_decoded_by_receipt_connection"
        self.member = "Sprite/10-0.sp2"
        path = self.client / "sp2" / self.member
        path.parent.mkdir(parents=True)
        path.write_bytes(self.body)
        inventory = {self.member: {"bytes": len(self.body), "crc32": f"{zlib.crc32(self.body) & 0xffffffff:08x}", "container": "synthetic.dat"}}
        (self.client / "client523_sp2_inventory.json").write_text(json.dumps(inventory))
        (self.client / "client523_receipt.json").write_text('{"complete":true}')
        (self.client / "tables").mkdir()
        with zipfile.ZipFile(self.client / "tables/current523_content_tables.zip", "w") as archive:
            archive.writestr("content/Class.json", '{"rows":[{"ID":1,"MaleSpriteID":20}]}')
        self.metadata = self.base / "metadata"
        metadata_generator.generate(self.client, self.metadata)
        self.sources = {p.name: {"source_file": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in spr.glob("*.spr")}
        self.declarations = connector.bank.identity.read_native_sprs(sorted(spr.glob("*.spr")))
        self.rows = list(connector.bank.records(self.metadata / connector.bank.ACTIONS))
        self.index = connector.metadata_action_index(self.rows)
        self.plan = self.base / "plan"
        self.plan.mkdir()
        (self.plan / "summary.json").write_text(json.dumps({"source_spr_hashes": self.sources}))
        request = {"actor_id": 20, "action_id": 0, "action_key": "list_9.spr:B1:A0", "target_members": [self.member], "required_members": [self.member], "status": "planned_requires_original_source_and_sp2_validation", "compiled": False}
        write_rows(self.plan / "action-outcomes.jsonl.gz", [request])
        write_rows(self.plan / "file-outcomes.jsonl.gz", [{"member": self.member, "status": "blocked_original_sp2_not_received", "compiled": False, "requests": [request]}])
        self.receipt = self.base / "received.jsonl.gz"
        write_rows(self.receipt, [{"member": self.member, "local_path": str(path), "bytes": len(self.body), "crc32": inventory[self.member]["crc32"], "sha256": None, "archive": "synthetic-received.zip", "source_snapshot": "current523", "stage": "received_not_additionally_validated", "supplied_source_current523_manifest_match": True}])

    def key(self, sprite, action=0, index=None):
        return connector.requested_action_key(self.declarations, self.index if index is None else index, self.sources, sprite, action)

    def args(self, name="connected", resume=None):
        return SimpleNamespace(output=self.base / name, saved_plan=self.plan, allow_host_timing=False, metadata=self.metadata, input_receipt=[self.receipt], followup_receipt=[], followup_scope=None, original_root=self.client / "sp2", spr_root=self.client / "spr", resume_bank=resume, reconnect_source_contract=[], normal_visual_context=[], map_placement_exclusion_sprite=[], source_receipt=None)

    def connect(self, args):
        with redirect_stdout(io.StringIO()):
            return connector.connect(args)

    def test_cross_file_alias_uses_requested_key_and_original_descriptor(self):
        self.assertEqual(self.key(20), "list_9.spr:B1:A0")
        self.assertEqual(self.key(21), "list_9.spr:B4:A0")
        actions = connector.native_source_actions(self.declarations, 20)
        self.assertEqual(actions[0]["fps"], 24)
        self.assertEqual(actions[0]["native_descriptor_origin_sprite_id"], 10)
        self.assertEqual(actions[0]["native_body_request_sprite_id"], 10)

    def test_header_file_remap_does_not_inherit_source_actions(self):
        self.assertEqual(connector.native_source_actions(self.declarations, 30), {})
        with self.assertRaisesRegex(ValueError, "absent native source action"):
            self.key(30)

    def test_origin_only_metadata_cannot_substitute_for_requested_alias_row(self):
        rows = [row for row in self.rows if row.get("native_requested_sprite_id") != 20]
        self.assertTrue(any(row.get("native_requested_sprite_id") == 10 for row in rows))
        with self.assertRaisesRegex(ValueError, "regenerate native metadata and saved plan"):
            self.key(20, index=connector.metadata_action_index(rows))

    def test_ambiguous_requested_action_row_is_not_selected(self):
        rows = self.rows + [copy.deepcopy(next(row for row in self.rows if row["native_requested_sprite_id"] == 20))]
        with self.assertRaisesRegex(ValueError, "absent or ambiguous"):
            self.key(20, index=connector.metadata_action_index(rows))

    def test_alias_metadata_must_preserve_each_identity_and_pin(self):
        for field, value in [("native_requested_sprite_id", 99), ("native_body_request_sprite_id", 21), ("native_descriptor_origin_sprite_id", 20), ("native_action_alias_chain", []), ("native_request_declaration", {})]:
            with self.subTest(field=field):
                rows = copy.deepcopy(self.rows)
                next(row for row in rows if row["native_requested_sprite_id"] == 20)[field] = value
                with self.assertRaisesRegex(ValueError, "regenerate native metadata and saved plan"):
                    self.key(20, index=connector.metadata_action_index(rows))

    def test_literal_legacy_row_is_exact_but_alias_requires_native_ledger(self):
        rows = copy.deepcopy(self.rows)
        for row in rows:
            for key in list(row):
                if key.startswith("native_"):
                    del row[key]
        index = connector.metadata_action_index(rows)
        self.assertEqual(self.key(10, index=index), "list_0.spr:B1:A0")
        with self.assertRaisesRegex(ValueError, "no matching native selector ledger"):
            self.key(20, index=index)

    def test_descriptor_source_pin_and_fps_mismatch_are_rejected(self):
        for field, value in [("source_file_sha256", "0" * 64), ("explicit_fps", 2), ("source_line", 1)]:
            with self.subTest(field=field):
                rows = copy.deepcopy(self.rows)
                next(row for row in rows if row["native_requested_sprite_id"] == 20)[field] = value
                with self.assertRaisesRegex(ValueError, "differs from its literal descriptor"):
                    self.key(20, index=connector.metadata_action_index(rows))

    def test_real_connection_keeps_requested_record_origin_and_crc_identity(self):
        args = self.args()
        result = self.connect(args)
        self.assertEqual(result["counts"]["registered_actor_action_records"], 1)
        manifest = json.loads((args.output / "manifest.json").read_text())
        entry = manifest["actors"]["sprite:20"]["0"]
        record = json.loads((args.output / entry["path"]).read_text())
        self.assertEqual(record["action_key"], "list_9.spr:B1:A0")
        self.assertEqual(record["actor"]["roles"]["source_action:0"]["source_file"], "list_0.spr")
        self.assertEqual(record["source_proof"]["roles"]["source_action:0"]["native_requested_sprite_id"], 20)
        self.assertEqual((args.output / "raw" / self.member).read_bytes(), self.body)
        self.assertIsNone(manifest["members"][self.member]["sha256"])
        self.assertEqual(manifest["members"][self.member]["stage"], "received_not_additionally_validated")
        self.assertFalse(manifest["independent_source_layers_opt_in"])
        self.assertEqual(manifest["native_selector_policy"], connector.bank.identity.NATIVE_SELECTOR_POLICY)
        domain = manifest["source_action_domains"]["sprite:20"]
        self.assertEqual(domain["action_ids"], [0])
        self.assertEqual(domain["native_body_request_sprite_ids_by_action"], {"0": 10})
        self.assertEqual(domain["native_physical_body_sprite_ids_by_action"], {"0": 10})
        self.assertEqual(domain["resolved_body_sprite_id"], 10)

    def test_old_saved_origin_key_is_blocked_without_linking_raw(self):
        rows = list(connector.bank.records(self.plan / "action-outcomes.jsonl.gz"))
        rows[0]["action_key"] = "list_0.spr:B1:A0"
        write_rows(self.plan / "action-outcomes.jsonl.gz", rows)
        args = self.args("stale_plan")
        result = self.connect(args)
        self.assertEqual(result["counts"]["registered_actor_action_records"], 0)
        outcomes = list(connector.bank.records(args.output / "action-outcomes.jsonl.gz"))
        self.assertIn("Saved request key differs", outcomes[0]["reason"])
        self.assertIn("regenerate", outcomes[0]["reason"])
        self.assertFalse((args.output / "raw" / self.member).exists())
        self.assertEqual((self.client / "sp2" / self.member).read_bytes(), self.body)

    def test_legacy_resume_is_rejected_before_linking_and_keeps_old_files(self):
        resume = self.base / "old_bank"
        resume.mkdir()
        legacy = {key: value for key, value in connector.bank.consumer_contract().items() if key not in ("native_selector_policy", "native_activation_policy")}
        (resume / "manifest.json").write_text(json.dumps({"consumer_contract": legacy, "actors": {}, "members": {}}))
        original = resume / "original_member.bin"
        original.write_bytes(b"keep_original_old_pack")
        before = {p.name: p.read_bytes() for p in resume.iterdir()}
        args = self.args("new_from_legacy", resume)
        with mock.patch.object(connector, "link_or_copy", side_effect=AssertionError("must not link a mismatched resume")):
            with self.assertRaisesRegex(ValueError, "regenerate a native-selector bank"):
                self.connect(args)
        self.assertEqual({p.name: p.read_bytes() for p in resume.iterdir()}, before)
        self.assertEqual(list(args.output.iterdir()), [])

    def test_action_dependent_body_ids_remain_explicit_in_complete_domain(self):
        spr = self.client / "spr"
        (spr / "list_1.spr").write_bytes(b"#11 4 Other_descriptor\n110.framerate(12)\n8.death(0 1,0.0:3)\n")
        path = spr / "list_9.spr"
        path.write_bytes(path.read_bytes().replace(b"0=10\n#21", b"0=10\n8=11\n#21"))
        metadata = self.base / "metadata_domains"
        metadata_generator.generate(self.client, metadata)
        sources = {p.name: {"source_file": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in spr.glob("*.spr")}
        (self.plan / "summary.json").write_text(json.dumps({"source_spr_hashes": sources}))
        args = self.args("mixed_body_domain")
        args.metadata = metadata
        self.connect(args)
        manifest = json.loads((args.output / "manifest.json").read_text())
        domain = manifest["source_action_domains"]["sprite:20"]
        self.assertEqual(sorted(manifest["actors"]["sprite:20"]), ["0"])
        self.assertEqual(domain["action_ids"], [0, 8])  # Complete source domain includes uncompiled8.
        self.assertEqual(domain["native_body_request_sprite_ids_by_action"], {"0": 10, "8": 11})
        self.assertEqual(domain["native_physical_body_sprite_ids_by_action"], {"0": 10, "8": 11})
        self.assertIsNone(domain["resolved_body_sprite_id"])
        proofs = list(connector.bank.records(args.output / "source-action-domain-proofs.jsonl.gz"))
        self.assertEqual(len(proofs[0]["declaration_path"]), 1)
        self.assertEqual(proofs[0]["declaration_path"][0]["sprite_id"], 20)
        death = next(row for row in proofs[0]["source_actions"] if row["action_id"] == 8)
        self.assertEqual(death["source_action_key"], "list_9.spr:B1:A8")
        self.assertEqual(death["source_file"], "list_1.spr")

    def test_followup_header_alias_without_action_stays_unconnected(self):
        followup = self.base / "followup.jsonl.gz"
        receipt = next(connector.bank.records(self.receipt))
        receipt["followup_consumer_gate"] = {"metadata": {"sprite_id": 30}}
        write_rows(followup, [receipt])
        args = self.args("followup_header")
        args.followup_receipt = [followup]
        self.connect(args)
        outcomes = list(connector.bank.records(args.output / "followup-action-outcomes.jsonl.gz"))
        header = next(row for row in outcomes if row["actor_id"] == 30)
        self.assertEqual(header["status"], "blocked_no_literal_source_action_requires_supported_parent_binding")
        self.assertFalse(header["compiled"])
        manifest = json.loads((args.output / "manifest.json").read_text())
        self.assertNotIn("sprite:30", manifest["actors"])

    def test_explicit_client_default_timing_matches_its_native_metadata(self):
        path = self.client / "spr/list_0.spr"
        path.write_bytes(path.read_bytes().replace(b"110.framerate(24)\n", b""))
        metadata = self.base / "metadata_default"
        metadata_generator.generate(self.client, metadata, client_default_fps=True)
        sources = {p.name: {"source_file": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in (self.client / "spr").glob("*.spr")}
        (self.plan / "summary.json").write_text(json.dumps({"source_spr_hashes": sources}))
        args = self.args("client_default")
        args.metadata = metadata
        args.client_section_default_fps = True
        result = self.connect(args)
        self.assertEqual(result["counts"]["registered_actor_action_records"], 1)
        manifest = json.loads((args.output / "manifest.json").read_text())
        self.assertEqual(manifest["consumer_contract"]["timing"], "source_explicit_or_client_section_default")
        self.assertEqual(manifest["consumer_contract"]["client_section_default_fps"], 24)
        entry = manifest["actors"]["sprite:20"]["0"]
        record = json.loads((args.output / entry["path"]).read_text())
        self.assertEqual(record["consumer_contract"], manifest["consumer_contract"])
        self.assertEqual(record["actor"]["roles"]["source_action:0"]["fps"], 24)
        self.assertEqual(record["source_proof"]["roles"]["source_action:0"]["fps_provenance"]["kind"], "client_section_default")

    def test_conflicting_explicit_timing_modes_are_rejected_before_output(self):
        args = self.args("conflicting_timing")
        args.allow_host_timing = True
        args.client_section_default_fps = True
        with self.assertRaisesRegex(ValueError, "choose host timing or the client section default"):
            self.connect(args)
        self.assertFalse(args.output.exists())

    def test_incomplete_uncompiled_action_domain_blocks_before_any_raw_link(self):
        spr = self.client / "spr"
        path = spr / "list_0.spr"
        path.write_bytes(path.read_bytes().replace(b"#30", b"8.death(0 1,0.0:3)\n#30"))
        path = spr / "list_9.spr"
        path.write_bytes(path.read_bytes().replace(b"0=10\n#21", b"0=10\n8=10\n#21"))
        metadata = self.base / "metadata_incomplete_domain"
        metadata_generator.generate(self.client, metadata)
        rows = [row for row in connector.bank.records(metadata / connector.bank.ACTIONS) if not (row["native_requested_sprite_id"] == 20 and row["action_id"] == 8)]
        write_rows(metadata / connector.bank.ACTIONS, rows)
        sources = {p.name: {"source_file": p.name, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in spr.glob("*.spr")}
        (self.plan / "summary.json").write_text(json.dumps({"source_spr_hashes": sources}))
        args = self.args("incomplete_domain")
        args.metadata = metadata
        with mock.patch.object(connector, "link_or_copy", side_effect=AssertionError("must not link before complete domain is known")):
            result = self.connect(args)
        self.assertEqual(result["counts"]["registered_actor_action_records"], 0)
        outcomes = list(connector.bank.records(args.output / "action-outcomes.jsonl.gz"))
        self.assertIn("list_9.spr:B1:A8", outcomes[0]["reason"])
        self.assertIn("regenerate native metadata", outcomes[0]["reason"])
        self.assertFalse((args.output / "raw" / self.member).exists())

    def test_matching_native_resume_keeps_existing_record_bytes(self):
        initial = self.args("matching_native_bank")
        self.connect(initial)
        manifest_path = initial.output / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        entry = manifest["actors"]["sprite:20"]["0"]
        record_path = initial.output / entry["path"]
        record = json.loads(record_path.read_text())
        record["preserved_test_annotation"] = "existing_record_not_implicitly_rewritten"
        data = connector.bank.json_bytes(record)
        record_path.write_bytes(data)
        entry["sha256"] = hashlib.sha256(data).hexdigest()
        manifest_path.write_bytes(connector.bank.json_bytes(manifest))
        before = {str(p.relative_to(initial.output)): p.read_bytes() for p in initial.output.rglob("*") if p.is_file()}
        resumed = self.args("matching_native_resume", initial.output)
        result = self.connect(resumed)  # The saved request still asks for construction.
        self.assertEqual(result["counts"].get("new_actor_action_records_written", 0), 0)
        self.assertEqual((resumed.output / entry["path"]).read_bytes(), data)
        self.assertEqual({str(p.relative_to(initial.output)): p.read_bytes() for p in initial.output.rglob("*") if p.is_file()}, before)


if __name__ == "__main__":
    unittest.main()
