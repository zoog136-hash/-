"""Synthetic compiler-contract tests; these fixtures are never original-art evidence."""
import contextlib
import gzip
import hashlib
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest import mock
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "lineagem_original"))
import build_reference_sp2_bank as bank
import original_spr


def synthetic_sp2(bits=(0,), frames=1):
    """Tiny valid structural fixture, not a pixel or composition reference."""
    body = bytearray(b"\xfe\x02" + b"\x00" * 4 + bytes([sum(1 << bit for bit in bits)]))
    for _ in bits:
        body.extend(bytes([frames]))
        for _ in range(frames):
            body.extend(b"\x00" * 8 + struct.pack("<H", 1) + b"\x00" * 3 + struct.pack("<h", 0))
        body.extend(struct.pack("<i", 1) + bytes([0, 0, 1]) + struct.pack("<H", 1 << 5))
    body.extend(b"\x00" * len(bits))
    return bytes(body)


def fixture():
    source_body = "0 1,0.0:2"
    text = "#100 1 synthetic_contract_fixture\n110.framerate(24)\n3.Breath(" + source_body + ")\n"
    source = {"action_key": "fixture:A3", "action_id": 3, "action_name_literal": "Breath",
              "source_file": "Client/Text/list_fixture.spr", "source_line": 3,
              "source_file_sha256": hashlib.sha256(text.encode("cp949")).hexdigest(),
              "raw_body": source_body, "declared_flag": 0,
              "source_tokens_selector_frame_ticks": [[0, 0, 2]], "explicit_fps": 24,
              "parse_issues": [], "fps_source": None, "opaque_token_annotations": []}
    row = {"sprite_id": 100, "alias_target": None, "source_file": source["source_file"],
           "source_file_sha256": source["source_file_sha256"], "source_line": 1,
           "animation_action_keys": [source["action_key"]], "explicit_layer_references": []}
    raw = synthetic_sp2()
    member = "Sprite/100-0.sp2"
    identity = {"member": member, "archive": "Client/Data/SyntheticFixture.dat", "bytes": len(raw),
                "crc32": f"{zlib.crc32(raw) & 0xffffffff:08x}", "source_family_categories": ["fixture_only"],
                "original_member_sha256_evidence": {"sha256": bank.sha(raw)},
                "saved_SP2_frame_evidence": {"stored_direction_bits": [0], "stored_frame_counts": [1]}}
    metadata = {"actions": {source["action_key"]: source}, "declarations": [row],
                "sources": {"list_fixture.spr": {"source_file": source["source_file"], "sha256": source["source_file_sha256"]}},
                "identities": {member: identity}, "inventory": {member: identity},
                "targets": {member}, "proof": {"fixture_only": True}}
    request = {"actor_id": 100, "action_id": 3, "action_key": source["action_key"],
               "target_members": [member], "selection_semantics": "explicit_source_id_only_no_gameplay_intent"}
    return metadata, request, text, raw


class ReferenceSP2BankTests(unittest.TestCase):
    def test_source_id_track_preserves_ticks_and_has_no_inferred_loop(self):
        metadata, request, _, _ = fixture()
        actor, members, proof = bank.plan_action(request, bank.metadata_declarations(metadata), metadata)
        track = actor["roles"]["source_action:3"]
        self.assertIsNone(track["loop"])
        self.assertEqual((track["fps"], track["source_action_id"]), (24, 3))
        self.assertEqual(members, {"Sprite/100-0.sp2"})
        self.assertEqual(track["directions"][7][0]["duration_ticks"], 2)
        self.assertEqual(track["directions"][7][0]["layers"][0]["group_bit"], 0)
        compact = bank.identity.compact_roles(actor, proof)["source_action:3"]
        self.assertEqual(compact["tokens"], [(0, 0, 2)])
        self.assertIsNone(compact["loop"])

    def test_literal_layer_attributes_keep_alias_path_without_inferred_inheritance(self):
        metadata, request, text, _ = fixture()
        text += "104.attr(8)\n#101 1=100 synthetic_alias\n104.attr(128)\n3.Breath(0 1,0.0:2)\n"
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "list_fixture.spr"
            source.write_bytes(text.encode("cp949"))
            declarations = original_spr.read([source])
            _, _, proof = bank.identity.build_actor(101, declarations, metadata["sources"], (("source_action:3", 3),))
            evidence = bank.source_layer_declarations(proof, declarations)[0]
            self.assertEqual(evidence["source_sprite_id"], 100)
            self.assertEqual(evidence["attribute_inheritance"], "alias_path_unverified")
            self.assertEqual([r["literal_attribute_directives"][0]["body"] for r in evidence["declaration_path"]], ["128", "8"])

    def test_directional_address_crosses_chunk_without_padding(self):
        metadata, request, _, _ = fixture()
        source = metadata["actions"][request["action_key"]]
        source["declared_flag"] = 1
        source["raw_body"] = "1 1,7.0:2"
        source["source_tokens_selector_frame_ticks"] = [[7, 0, 2]]
        metadata["identities"]["Sprite/100-8.sp2"] = dict(metadata["identities"]["Sprite/100-0.sp2"], member="Sprite/100-8.sp2")
        actor, members, _ = bank.plan_action(request, bank.metadata_declarations(metadata), metadata)
        directions = actor["roles"]["source_action:3"]["directions"]
        self.assertEqual(members, {"Sprite/100-0.sp2", "Sprite/100-8.sp2"})
        self.assertEqual([directions[i][0]["layers"][0]["group_bit"] for i in (0, 1, 7)], [7, 0, 6])

    def test_missing_timing_does_not_use_table_or_host_defaults(self):
        metadata, request, _, _ = fixture()
        metadata["actions"][request["action_key"]]["explicit_fps"] = None
        with self.assertRaisesRegex(ValueError, "explicit source FPS"):
            bank.plan_action(request, bank.metadata_declarations(metadata), metadata)

    def test_alias_uses_exact_override_and_rejects_wrong_source_key(self):
        metadata, request, _, _ = fixture()
        alias = dict(metadata["declarations"][0], sprite_id=101, alias_target=100, animation_action_keys=[])
        metadata["declarations"].append(alias)
        request["actor_id"] = 101
        with self.assertRaisesRegex(ValueError, "absent native source action 101/3"):
            bank.plan_action(request, bank.metadata_declarations(metadata), metadata)
        # A file-remap header cannot inherit actions. An explicit own literal
        # can use that physical file while retaining its requested owner.
        alias["animation_action_keys"] = [request["action_key"]]
        actor, _, _ = bank.plan_action(request, bank.metadata_declarations(metadata), metadata)
        self.assertEqual(actor["source_sprite_id"], 101)
        self.assertEqual(actor["roles"]["source_action:3"]["directions"][0][0]["layers"][0]["source_sprite_id"], 100)
        override = dict(metadata["actions"][request["action_key"]], action_key="override:A3", raw_body="0 1,0.0:5", source_tokens_selector_frame_ticks=[[0, 0, 5]])
        metadata["actions"][override["action_key"]] = override
        alias["animation_action_keys"] = [override["action_key"]]
        with self.assertRaisesRegex(ValueError, "effective alias/override"):
            bank.plan_action(request, bank.metadata_declarations(metadata), metadata)

    def test_dependency_identity_required_without_filename_inference(self):
        metadata, request, _, _ = fixture()
        parent = metadata["declarations"][0]
        parent["explicit_layer_references"] = [{"kind": "clothes", "targets": [102], "raw": "105.clothes(1 102)"}]
        metadata["declarations"].append(dict(parent, sprite_id=102, animation_action_keys=[], explicit_layer_references=[]))
        declarations = bank.metadata_declarations(metadata)
        with self.assertRaisesRegex(ValueError, "dependency identity unavailable.*Sprite/102-0.sp2"):
            bank.plan_action(request, declarations, metadata)
        metadata["identities"]["Sprite/102-0.sp2"] = dict(metadata["inventory"]["Sprite/100-0.sp2"], member="Sprite/102-0.sp2")
        actor, members, _ = bank.plan_action(request, declarations, metadata)
        self.assertEqual(len(actor["roles"]["source_action:3"]["directions"][0][0]["layers"]), 2)
        self.assertIn("Sprite/102-0.sp2", members)

    def test_auxiliary_child_own_timing_is_not_selected(self):
        metadata, request, _, _ = fixture()
        parent = metadata["declarations"][0]
        parent["explicit_layer_references"] = [{"kind": "clothes", "targets": [102], "raw": "105.clothes(1 102)"}]
        child = dict(metadata["actions"][request["action_key"]], action_key="child:A3", explicit_fps=36)
        metadata["actions"][child["action_key"]] = child
        metadata["declarations"].append(dict(parent, sprite_id=102, animation_action_keys=[child["action_key"]], explicit_layer_references=[]))
        metadata["identities"]["Sprite/102-0.sp2"] = dict(metadata["inventory"]["Sprite/100-0.sp2"], member="Sprite/102-0.sp2")
        actor, _, proof = bank.plan_action(request, bank.metadata_declarations(metadata), metadata)
        self.assertEqual(actor["roles"]["source_action:3"]["fps"], 24)
        self.assertEqual(proof["layer_policy"], bank.identity.LAYER_POLICY)
        self.assertEqual(len(actor["roles"]["source_action:3"]["directions"][0][0]["layers"]), 2)

    def test_saved_missing_direction_and_out_of_range_are_not_padded(self):
        metadata, request, _, _ = fixture()
        actor, _, _ = bank.plan_action(request, bank.metadata_declarations(metadata), metadata)
        evidence = metadata["identities"]["Sprite/100-0.sp2"]["saved_SP2_frame_evidence"]
        evidence["stored_direction_bits"] = [1]
        self.assertEqual(bank.saved_address_issues(actor, metadata["identities"])[0]["issue"], "stored_direction_absent")
        evidence["stored_direction_bits"] = [0]
        evidence["stored_frame_counts"] = [0]
        self.assertEqual(bank.saved_address_issues(actor, metadata["identities"])[0]["issue"], "stored_frame_out_of_range")

    def test_complete_original_spr_hash_is_required(self):
        metadata, _, text, _ = fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(ValueError, "original SPR unavailable"):
                bank.verified_declarations(metadata, root)
            (root / "list_fixture.spr").write_bytes(text.encode("cp949"))
            self.assertIn(100, bank.verified_declarations(metadata, root))
            (root / "list_fixture.spr").write_bytes(text.encode("cp949") + b" ")
            with self.assertRaisesRegex(ValueError, "complete original SPR SHA256 mismatch"):
                bank.verified_declarations(metadata, root)

    def _check_missing_spr_scope(self, required):
        metadata, request, text, raw = fixture()
        missing_text = "#102 1 synthetic_separate_file_fixture\n"
        missing_proof = {"source_file": "Client/Text/list_missing.spr", "sha256": bank.sha(missing_text.encode("cp949"))}
        metadata["sources"]["list_missing.spr"] = missing_proof
        if required:
            text += "105.clothes(1 102)\n"
            digest = bank.sha(text.encode("cp949"))
            metadata["sources"]["list_fixture.spr"]["sha256"] = digest
            metadata["actions"][request["action_key"]]["source_file_sha256"] = digest
            parent = metadata["declarations"][0]
            parent["source_file_sha256"] = digest
            parent["explicit_layer_references"] = [{"kind": "clothes", "targets": [102], "raw": "105.clothes(1 102)"}]
            metadata["declarations"].append(dict(parent, sprite_id=102, source_line=1,
                source_file=missing_proof["source_file"], source_file_sha256=missing_proof["sha256"],
                animation_action_keys=[], explicit_layer_references=[]))
            metadata["identities"]["Sprite/102-0.sp2"] = dict(metadata["identities"][request["target_members"][0]], member="Sprite/102-0.sp2")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            requests = root / "requests.jsonl"
            requests.write_text(json.dumps(request) + "\n")
            spr_root = root / "spr"
            spr_root.mkdir()
            (spr_root / "list_fixture.spr").write_bytes(text.encode("cp949"))
            original_root = root / "originals"
            for member in metadata["identities"]:
                path = original_root / member
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(raw)
            args = bank.argparse.Namespace(metadata=root, requests=requests, output=root / "output", plan_only=False,
                                           original_root=original_root, spr_root=spr_root, dependency_index=None)
            with mock.patch.object(bank, "load_metadata", return_value=metadata), contextlib.redirect_stdout(io.StringIO()):
                summary = bank.build(args)
            self.assertEqual(summary["original_spr_inputs"]["verified_count"], 1)
            self.assertEqual(summary["original_spr_inputs"]["expected_count"], 2)
            self.assertEqual(summary["original_spr_inputs"]["missing"], {"list_missing.spr": missing_proof})
            self.assertFalse(summary["actual_original_spr_files_verified"])
            self.assertEqual(summary["counts"]["compiled_actions"], 0 if required else 1)
            if required:
                result = next(bank.records(args.output / "action-outcomes.jsonl.gz"))
                self.assertEqual(result["status"], "blocked_actual_source_contract")
                self.assertIn("102: expected one", result["reason"])
                self.assertFalse((args.output / "manifest.json").exists())
            else:
                self.assertTrue((args.output / "manifest.json").exists())

    def test_missing_unrelated_complete_spr_does_not_block_actual_action(self):
        self._check_missing_spr_scope(required=False)

    def test_missing_required_complete_spr_blocks_actual_layer_closure(self):
        self._check_missing_spr_scope(required=True)

    def test_original_sp2_crc_and_sha_are_independent_guards(self):
        metadata, request, _, raw = fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / request["target_members"][0]
            path.parent.mkdir()
            path.write_bytes(raw)
            result = bank.verified_raw(root, set(request["target_members"]), metadata["identities"])
            bank.identity.validate_actor(bank.plan_action(request, bank.metadata_declarations(metadata), metadata)[0], result, {})
            metadata["identities"][request["target_members"][0]]["original_member_sha256_evidence"]["sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "SHA256 mismatch"):
                bank.verified_raw(root, set(request["target_members"]), metadata["identities"])
            metadata["identities"][request["target_members"][0]]["original_member_sha256_evidence"] = None
            path.write_bytes(raw[:-1] + b"\x01")
            with self.assertRaisesRegex(ValueError, "size/CRC mismatch"):
                bank.verified_raw(root, set(request["target_members"]), metadata["identities"])

    def test_unverified_external_dependency_rejected(self):
        metadata, _, _, _ = fixture()
        row = metadata["inventory"]["Sprite/100-0.sp2"]
        with self.assertRaisesRegex(ValueError, "explicit current523 identity"):
            bank.check_identity(row, external=True)
        row.update(source_snapshot="patch523", identity_evidence="synthetic_fixture_only")
        bank.check_identity(row, external=True)

    def test_malformed_source_layer_count_is_retained_and_rejected(self):
        metadata, request, _, _ = fixture()
        metadata["declarations"][0]["reference_issues"] = [{"raw": "105.clothes(2 102)", "source_line": 4}]
        declarations = bank.metadata_declarations(metadata)
        self.assertFalse(declarations[100][0].references[0]["count_valid"])
        with self.assertRaisesRegex(ValueError, "invalid active clothes target count 100"):
            bank.plan_action(request, declarations, metadata)

    def test_invalid_metadata_header_does_not_become_a_declaration(self):
        metadata, request, _, _ = fixture()
        metadata["declarations"][0]["header_valid"] = False
        self.assertEqual(bank.metadata_declarations(metadata), {})
        with self.assertRaisesRegex(ValueError, "expected one.*declaration, found 0"):
            bank.plan_action(request, bank.metadata_declarations(metadata), metadata)

    def _family_fixture(self):
        metadata, request, _, _ = fixture()
        parent = metadata["declarations"][0]
        parent["explicit_layer_references"] = [{"kind": "clothes", "targets": [102], "raw": "105.clothes(1 102)"}]
        metadata["declarations"].append(dict(parent, sprite_id=102, animation_action_keys=[], explicit_layer_references=[]))
        child = "Sprite/102-0.sp2"
        row = dict(metadata["inventory"][request["target_members"][0]], member=child)
        metadata["inventory"] = {child: row}
        metadata["identities"] = {child: row}
        metadata["targets"] = {child}
        metadata["family_roots"] = {100: {"table:synthetic_fixture:100"}}
        metadata["family_related_targets"] = {100: {child}}
        metadata["family_evidence"] = {100: [{"evidence_key": "table:synthetic_fixture:100", "fixture_only": True}]}
        return metadata, child

    def test_family_parent_outside_inventory_is_discovered_before_identity_rejection(self):
        metadata, child = self._family_fixture()
        failures, statistics = [], bank.Counter()
        declarations = bank.metadata_declarations(metadata)
        expanded = list(bank.expanded_requests([], declarations, metadata, failures, statistics))
        self.assertEqual(len(expanded), 1)
        request, prepared = expanded[0]
        self.assertEqual((request["actor_id"], request["action_id"]), (100, 3))
        self.assertEqual(request["target_members"], [child])
        self.assertEqual(request["seed_target_members"], [])
        self.assertIn("Sprite/100-0.sp2", prepared[1])
        with self.assertRaisesRegex(ValueError, "dependency identity unavailable.*Sprite/100-0.sp2"):
            bank.plan_action(request, declarations, metadata, prepared)

    def test_family_source_addresses_are_kept_when_fps_is_unknown(self):
        metadata, child = self._family_fixture()
        metadata["actions"]["fixture:A3"]["explicit_fps"] = None
        declarations = bank.metadata_declarations(metadata)
        request, prepared = list(bank.expanded_requests([], declarations, metadata, [], bank.Counter()))[0]
        self.assertEqual(request["target_members"], [child])
        with self.assertRaisesRegex(ValueError, "explicit source FPS"):
            bank.plan_action(request, declarations, metadata, prepared)

    def test_family_ambiguous_root_records_context_without_action_usage(self):
        metadata, child = self._family_fixture()
        metadata["declarations"].append(dict(metadata["declarations"][0]))
        failures = []
        self.assertEqual(list(bank.expanded_requests([], bank.metadata_declarations(metadata), metadata, failures, bank.Counter())), [])
        self.assertEqual(len(failures), 1)
        self.assertFalse(failures[0]["file_action_usage_proven"])
        self.assertIn(child, failures[0]["related_family_target_members"])
        self.assertIn("found 2", failures[0]["reason"])

    def test_family_expansion_does_not_mutate_seed_requests(self):
        metadata, request, _, _ = fixture()
        metadata["family_roots"] = {100: {"table:synthetic_fixture:100"}}
        before = json.dumps(request, sort_keys=True)
        expanded = list(bank.expanded_requests([request], bank.metadata_declarations(metadata), metadata, [], bank.Counter()))
        self.assertEqual(json.dumps(request, sort_keys=True), before)
        self.assertEqual(expanded[0][0]["seed_target_members"], request["target_members"])

    def test_family_expansion_is_default_pipeline_and_missing_body_stays_blocked(self):
        metadata, child = self._family_fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seeds = root / "seeds.jsonl"
            seeds.write_text("")
            args = bank.argparse.Namespace(metadata=root, requests=seeds, output=root / "output", plan_only=True,
                                           original_root=None, spr_root=None, dependency_index=None)
            with mock.patch.object(bank, "load_metadata", return_value=metadata), contextlib.redirect_stdout(io.StringIO()):
                summary = bank.build(args)
            self.assertEqual(summary["counts"]["seed_requested_actions"], 0)
            self.assertEqual(summary["counts"]["requested_actions"], 1)
            self.assertEqual(summary["counts"]["compiled_actions"], 0)
            effective = list(bank.records(args.output / "effective-requests.jsonl.gz"))
            self.assertEqual(effective[0]["target_members"], [child])
            outcomes = list(bank.records(args.output / "file-outcomes.jsonl.gz"))
            self.assertIn("dependency identity unavailable", outcomes[0]["requests"][0]["reason"])
            self.assertFalse(outcomes[0]["seed_directly_requested"])

    def _run_build(self, actual=False, corrupt_source=False):
        metadata, request, text, raw = fixture()
        extra = "Sprite/999-0.sp2"
        metadata["targets"].add(extra)
        metadata["inventory"][extra] = dict(metadata["inventory"][request["target_members"][0]], member=extra)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            requests = root / "requests.jsonl"
            requests.write_text(json.dumps(request) + "\n")
            args = bank.argparse.Namespace(metadata=root, requests=requests, output=root / "output", plan_only=not actual,
                                           original_root=None, spr_root=None, dependency_index=None)
            if actual:
                args.original_root = root / "originals"
                target = args.original_root / request["target_members"][0]
                target.parent.mkdir(parents=True)
                target.write_bytes(raw)
                args.spr_root = root / "spr"
                args.spr_root.mkdir()
                (args.spr_root / "list_fixture.spr").write_bytes(text.encode("cp949") + (b"x" if corrupt_source else b""))
            with mock.patch.object(bank, "load_metadata", return_value=metadata), contextlib.redirect_stdout(io.StringIO()):
                result = bank.build(args)
            self.assertEqual(result["requests_sha256"], bank.sha(requests.read_bytes()))
            outcomes = list(bank.records(args.output / "file-outcomes.jsonl.gz"))
            self.assertEqual(len(outcomes), 2)
            self.assertEqual(outcomes[1]["status"], "blocked_no_source_action_request")
            self.assertFalse(any(row["installed_this_run"] or row["played_this_run"] for row in outcomes))
            self.assertTrue(all(row["active_installation"] is None and row["playback_evidence"] is None for row in outcomes))
            if actual and not corrupt_source:
                self.assertEqual(result["counts"]["compiled_actions"], 1)
                manifest = json.loads((args.output / "manifest.json").read_text())
                record = manifest["actors"]["sprite:100"]["3"]
                body = (args.output / record["path"]).read_bytes()
                self.assertEqual(bank.sha(body), record["sha256"])
                actor = json.loads(body)["actor"]
                self.assertIsNone(actor["roles"]["source_action:3"]["loop"])
                self.assertEqual((args.output / "raw" / request["target_members"][0]).read_bytes(), raw)
            else:
                self.assertEqual(result["counts"]["compiled_actions"], 0)
                self.assertFalse((args.output / "manifest.json").exists())
                self.assertFalse((args.output / "raw").exists())
            return result

    def test_metadata_plan_keeps_every_target_and_never_compiles(self):
        self.assertEqual(self._run_build()["stage"], "metadata_plan_only")

    def test_synthetic_actual_compilation_uses_existing_validator(self):
        result = self._run_build(actual=True)
        self.assertTrue(result["actual_original_spr_files_verified"])
        self.assertFalse(result["consumer_contract"]["native_dispatch_verified"])

    def test_metadata_cannot_substitute_for_missing_complete_source(self):
        result = self._run_build(actual=True, corrupt_source=True)
        self.assertIn("SHA256 mismatch", result["source_problem"])
        self.assertFalse(result["actual_original_spr_files_verified"])

    def test_existing_output_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            marker = root / "existing-user-file.txt"
            marker.write_text("preserve")
            with self.assertRaisesRegex(ValueError, "new private directory"):
                bank.build(bank.argparse.Namespace(output=root))
            self.assertEqual(marker.read_text(), "preserve")

    def test_request_mutation_cannot_publish_mislabeled_manifest(self):
        metadata, request, _, _ = fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "requests.jsonl"
            path.write_text(json.dumps(request) + "\n")
            args = bank.argparse.Namespace(metadata=root, requests=path, output=root / "output", plan_only=True,
                                           original_root=None, spr_root=None, dependency_index=None)
            original_write = bank.write_records

            def mutate_after_first_output(*values):
                original_write(*values)
                path.write_bytes(path.read_bytes() + b"\n")

            with mock.patch.object(bank, "load_metadata", return_value=metadata), mock.patch.object(bank, "write_records", side_effect=mutate_after_first_output):
                with self.assertRaisesRegex(ValueError, "requests changed during build"):
                    bank.build(args)
            self.assertFalse((args.output / "manifest.json").exists())
            self.assertFalse((args.output / "summary.json").exists())

    def test_failed_action_does_not_reject_other_actions_for_actor(self):
        metadata, request, _, _ = fixture()
        unsupported = dict(metadata["actions"][request["action_key"]], action_key="fixture:A8", action_id=8, explicit_fps=None)
        metadata["actions"][unsupported["action_key"]] = unsupported
        metadata["declarations"][0]["animation_action_keys"].append(unsupported["action_key"])
        bad_request = dict(request, action_id=8, action_key=unsupported["action_key"])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "requests.jsonl"
            path.write_text(json.dumps(request) + "\n" + json.dumps(bad_request) + "\n")
            args = bank.argparse.Namespace(metadata=root, requests=path, output=root / "output", plan_only=True,
                                           original_root=None, spr_root=None, dependency_index=None)
            with mock.patch.object(bank, "load_metadata", return_value=metadata), contextlib.redirect_stdout(io.StringIO()):
                result = bank.build(args)
            outcomes = list(bank.records(args.output / "action-outcomes.jsonl.gz"))
            self.assertEqual(result["counts"]["requested_actions"], 2)
            self.assertEqual(outcomes[0]["status"], "planned_requires_original_source_and_sp2_validation")
            self.assertEqual(outcomes[1]["status"], "blocked_source_contract")
            self.assertEqual(result["counts"]["compiled_actions"], 0)

    def test_compile_without_originals_returns_blocked_and_no_manifest(self):
        metadata, request, _, _ = fixture()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "requests.jsonl"
            path.write_text(json.dumps(request) + "\n")
            output = root / "output"
            with mock.patch.object(bank, "load_metadata", return_value=metadata), contextlib.redirect_stdout(io.StringIO()):
                status = bank.main(["--metadata", str(root), "--requests", str(path), "--output", str(output)])
            self.assertEqual(status, 2)
            summary = json.loads((output / "summary.json").read_text())
            self.assertEqual(summary["counts"]["compiled_actions"], 0)
            self.assertEqual(summary["counts"]["compiled_raw_members"], 0)
            self.assertEqual(summary["counts"]["file_statuses"], {"blocked_original_spr_unavailable_or_unverified": 1})
            self.assertFalse((output / "manifest.json").exists())
            self.assertFalse((output / "raw").exists())

    def _check_emitted_dependency_coverage(self, actual):
        metadata, request, text, raw = fixture()
        child = "Sprite/102-0.sp2"
        text += "105.clothes(1 102)\n#102 1 synthetic_clothes_fixture\n"
        digest = bank.sha(text.encode("cp949"))
        metadata["sources"]["list_fixture.spr"]["sha256"] = digest
        metadata["actions"][request["action_key"]]["source_file_sha256"] = digest
        parent = metadata["declarations"][0]
        parent["source_file_sha256"] = digest
        parent["explicit_layer_references"] = [{"kind": "clothes", "targets": [102], "raw": "105.clothes(1 102)"}]
        metadata["declarations"].append(dict(parent, sprite_id=102, source_line=5,
                                              animation_action_keys=[], explicit_layer_references=[]))
        child_identity = dict(metadata["inventory"][request["target_members"][0]], member=child)
        metadata["targets"].add(child)
        metadata["inventory"][child] = metadata["identities"][child] = child_identity
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            requests = root / "requests.jsonl"
            requests.write_text(json.dumps(request) + "\n")
            args = bank.argparse.Namespace(metadata=root, requests=requests, output=root / "output", plan_only=not actual,
                                           original_root=None, spr_root=None, dependency_index=None)
            if actual:
                args.original_root = root / "originals"
                for member in metadata["targets"]:
                    path = args.original_root / member
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(raw)
                args.spr_root = root / "spr"
                args.spr_root.mkdir()
                (args.spr_root / "list_fixture.spr").write_bytes(text.encode("cp949"))
            with mock.patch.object(bank, "load_metadata", return_value=metadata), contextlib.redirect_stdout(io.StringIO()):
                summary = bank.build(args)
            rows = {row["member"]: row for row in bank.records(args.output / "file-outcomes.jsonl.gz")}
            dependency = rows[child]
            self.assertFalse(dependency["directly_requested"])
            self.assertTrue(dependency["planned_emitted"])
            self.assertEqual(dependency["request_selection_status"], "emitted_dependency_without_direct_request")
            self.assertTrue(dependency["requests"][0]["planned_emitted"])
            self.assertEqual(dependency["compiled"], actual)
            self.assertEqual(summary["counts"]["directly_requested_target_files"], 1)
            self.assertEqual(summary["counts"]["planned_emitted_target_files"], 2)
            self.assertEqual(summary["counts"]["compiled_target_files"], 2 if actual else 0)
            if actual:
                self.assertEqual(summary["counts"]["compiled_raw_members"], 2)
                self.assertEqual(dependency["status"], "compiled_source_action_bank_not_installed")
                self.assertTrue((args.output / "raw" / child).is_file())
            else:
                self.assertEqual(dependency["status"], "planned_requires_original_source_and_sp2_validation")
                self.assertFalse((args.output / "manifest.json").exists())

    def test_plan_counts_emitted_clothes_dependency_without_direct_request(self):
        self._check_emitted_dependency_coverage(actual=False)

    def test_compile_counts_written_clothes_dependency_without_direct_request(self):
        self._check_emitted_dependency_coverage(actual=True)


if __name__ == "__main__":
    unittest.main()
