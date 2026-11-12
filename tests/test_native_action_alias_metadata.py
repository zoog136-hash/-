"""Generated native selector handoff tests; synthetic source, no original art."""
from __future__ import annotations

import copy
import gzip
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/lineagem_original"))
import client523_bank_metadata as gen


SOURCE = """#10 4 Origin
110.framerate(24)
0.walk(1 2,0.0:2 0.1:3)
8.death(1 1,0.2:4)
#20 4 Alias
110.framerate(2)
0=10
8=10
#30 4=10 Header_file_remap_only
#40 4 Forward_unavailable
0=50
#50 4 Later
0.late(1 1,8.0:9)
#60 4 Duplicate_alias
0=10
0=50
#70 4 Alias_before_literal
0=10
0.override(1 1,16.0:19)
#80 4 Duplicate_literal
0.first(1 1,24.0:7)
0.last(1 1,32.0:11)
#90 4 Alias_chain
0=20
"""


def read_rows(directory, name):
    return [json.loads(line) for line in gzip.decompress((directory / name).read_bytes()).splitlines()]


class NativeActionAliasMetadataTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="native-alias-metadata-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.source = self.base / "client"
        (self.source / "spr").mkdir(parents=True)
        (self.source / "spr/list_0.spr").write_bytes(SOURCE.encode("cp949"))
        (self.source / "spr/list_9.spr").write_bytes(b"#100 4 Cross_file_alias\n8=10\n")
        # Numeric list order matters: list_10 is after list_9, despite its
        # lexicographic filename sorting before list_9.
        (self.source / "spr/list_10.spr").write_bytes(b"#110 4 Numeric_list_order\n8=100\n")
        (self.source / "sp2").mkdir()
        (self.source / "client523_sp2_inventory.json").write_text("{}")
        (self.source / "client523_receipt.json").write_text('{"complete":true}')
        (self.source / "tables").mkdir()
        with zipfile.ZipFile(self.source / "tables/current523_content_tables.zip", "w") as archive:
            archive.writestr("content/Class.json", '{"rows":[{"ID":1,"MaleSpriteID":20}]}')
        self.before = {p.relative_to(self.source): p.read_bytes() for p in self.source.rglob("*") if p.is_file()}
        self.output = self.base / "metadata"
        self.summary = gen.generate(self.source, self.output)
        self.actions = read_rows(self.output, gen.bank.ACTIONS)
        self.declarations = {row["sprite_id"]: row for row in read_rows(self.output, gen.bank.DECLARATIONS)}

    def action(self, sprite, code):
        matches = [row for row in self.actions if row.get("native_requested_sprite_id") == sprite and row["action_id"] == code]
        self.assertEqual(len(matches), 1, f"unique registered requested action {sprite}/{code}")
        return matches[0]

    def test_explicit_alias_preserves_origin_fps_and_requested_identity(self):
        aliased = self.action(20, 0)
        self.assertEqual(aliased["explicit_fps"], 24)
        self.assertEqual(aliased["source_tokens_selector_frame_ticks"], [[0, 0, 2], [0, 1, 3]])
        self.assertEqual(aliased["native_body_request_sprite_id"], 10)
        self.assertEqual(aliased["native_descriptor_origin_sprite_id"], 10)
        self.assertEqual(aliased["native_registration_kind"], "explicit_action_alias")
        self.assertEqual(aliased["native_action_alias_chain"][0]["raw"], "0=10")
        self.assertEqual(aliased["action_key"], "list_0.spr:B5:A0")
        self.assertEqual(aliased["source_line"], 3)
        self.assertEqual(aliased["native_request_declaration"]["source_line"], 5)

    def test_header_file_remap_does_not_add_inherited_actions(self):
        self.assertEqual(self.declarations[30]["animation_action_keys"], [])
        self.assertEqual(self.declarations[30]["native_registered_action_keys"], {})
        self.assertFalse(any(row.get("native_requested_sprite_id") == 30 for row in self.actions))
        self.assertEqual(self.declarations[30]["alias_target"], 10)

    def test_forward_unavailable_source_is_retained_without_promotion(self):
        declaration = self.declarations[40]
        self.assertEqual(declaration["animation_action_keys"], [])
        self.assertEqual(declaration["native_action_aliases"][0]["raw"], "0=50")
        self.assertEqual(declaration["native_action_aliases"][0]["registration_status"], "source_descriptor_unavailable")
        self.assertEqual(self.action(50, 0)["source_tokens_selector_frame_ticks"], [[8, 0, 9]])

    def test_duplicate_alias_keeps_first_registration_and_raw_attempts(self):
        self.assertEqual(self.action(60, 0)["native_descriptor_origin_sprite_id"], 10)
        aliases = self.declarations[60]["native_action_aliases"]
        self.assertEqual([row["raw"] for row in aliases], ["0=10", "0=50"])
        self.assertEqual([row["registration_status"] for row in aliases], ["registered", "duplicate_destination"])

    def test_later_literal_cannot_replace_alias_and_literal_evidence_survives(self):
        self.assertEqual(self.action(70, 0)["source_tokens_selector_frame_ticks"], [[0, 0, 2], [0, 1, 3]])
        literal = self.declarations[70]["native_literal_action_declarations"]
        self.assertEqual(len(literal), 1)
        self.assertEqual(literal[0]["registration_status"], "duplicate_destination")
        self.assertEqual(literal[0]["descriptor"]["tokens"], [[16, 0, 19]])

    def test_duplicate_literal_keeps_first_descriptor_and_both_raw_definitions(self):
        self.assertEqual(self.action(80, 0)["source_tokens_selector_frame_ticks"], [[24, 0, 7]])
        literals = self.declarations[80]["native_literal_action_declarations"]
        self.assertEqual([row["descriptor"]["tokens"] for row in literals], [[[24, 0, 7]], [[32, 0, 11]]])
        self.assertEqual([row["registration_status"] for row in literals], ["registered", "duplicate_destination"])

    def test_alias_chain_keeps_immediate_body_and_deepest_descriptor_distinct(self):
        row = self.action(90, 0)
        self.assertEqual(row["native_requested_sprite_id"], 90)
        self.assertEqual(row["native_body_request_sprite_id"], 20)
        self.assertEqual(row["native_descriptor_origin_sprite_id"], 10)
        self.assertEqual([item["raw"] for item in row["native_action_alias_chain"]], ["0=20", "0=10"])

    def test_cross_file_requested_key_and_descriptor_pins_are_both_exact(self):
        row = self.action(100, 8)
        self.assertEqual(row["action_key"], "list_9.spr:B1:A8")
        self.assertEqual(row["source_file"], "list_0.spr")
        self.assertEqual(row["source_file_sha256"], hashlib.sha256((self.source / "spr/list_0.spr").read_bytes()).hexdigest())
        request = row["native_request_declaration"]
        self.assertEqual(request["source_file"], "list_9.spr")
        self.assertEqual(request["source_file_sha256"], hashlib.sha256((self.source / "spr/list_9.spr").read_bytes()).hexdigest())
        chained = self.action(110, 8)
        self.assertEqual(chained["native_body_request_sprite_id"], 100)
        self.assertEqual(chained["native_descriptor_origin_sprite_id"], 10)
        self.assertEqual(len(chained["native_action_alias_chain"]), 2)

    def test_policy_source_directives_counts_and_all_output_pins(self):
        manifest = json.loads((self.output / gen.bank.HANDOFF).read_text())
        expected = "native_explicit_actions_and_immediate_alias_owner_v1"
        self.assertEqual(manifest["native_selector_policy"], expected)
        self.assertEqual(self.summary["native_selector_policy"], expected)
        self.assertIn("not_native523_or_Android_execution", manifest["native_selector_scope"])
        self.assertEqual(self.summary["action_alias_events"], 9)
        self.assertEqual(self.summary["registered_action_aliases"], 7)
        self.assertEqual(self.summary["literal_action_events"], 6)
        self.assertEqual(self.declarations[10]["native_directives"][0]["body"], "24")
        for entry in manifest["members"]:
            data = (self.output / entry["name"]).read_bytes()
            self.assertEqual(len(data), entry["bytes"])
            self.assertEqual(hashlib.sha256(data).hexdigest(), entry["sha256"])
        self.assertEqual({p.relative_to(self.source): p.read_bytes() for p in self.source.rglob("*") if p.is_file()}, self.before)

    def test_generated_handoff_is_deterministic(self):
        second = self.base / "metadata_second"
        self.assertEqual(gen.generate(self.source, second), self.summary)
        self.assertEqual({p.name: p.read_bytes() for p in second.iterdir()}, {p.name: p.read_bytes() for p in self.output.iterdir()})

    def test_duplicate_headers_remain_evidence_without_aborting_whole_handoff(self):
        duplicate = self.source / "spr/list_11.spr"
        duplicate.write_bytes(b"#120 4 First_header\n0.first(1 1,0.0:2)\n#120 4 Second_header\n8.second(1 1,8.0:3)\n")
        output = self.base / "metadata_duplicates"
        gen.generate(self.source, output)
        declarations = [row for row in read_rows(output, gen.bank.DECLARATIONS) if row["sprite_id"] == 120]
        self.assertEqual([row["source_line"] for row in declarations], [1, 3])
        self.assertEqual([row["native_literal_action_declarations"][0]["raw"] for row in declarations], ["0.first(1 1,0.0:2)", "8.second(1 1,8.0:3)"])
        actions = [row for row in read_rows(output, gen.bank.ACTIONS) if row["native_requested_sprite_id"] == 120]
        self.assertEqual({row["action_key"] for row in actions}, {"list_11.spr:B1:A0", "list_11.spr:B3:A8"})
        actual = gen.identity.read_native_sprs(sorted((self.source / "spr").glob("list_*.spr")))
        with self.assertRaisesRegex(ValueError, "expected one current SPR declaration"):
            gen.identity.native_action(actual, 120, 0)

    def test_cp949_alias_column_remains_decoded_column_not_fabricated_byte_offset(self):
        line = "#130 4 한글 별칭 0=10"
        path = self.source / "spr/list_12.spr"
        path.write_bytes((line + "\n").encode("cp949"))
        output = self.base / "metadata_cp949"
        gen.generate(self.source, output)
        declaration = next(row for row in read_rows(output, gen.bank.DECLARATIONS) if row["sprite_id"] == 130)
        alias = declaration["native_action_aliases"][0]
        self.assertEqual(alias["raw"], "0=10")
        self.assertEqual(alias["source_column"], line.index("0=10"))
        self.assertNotEqual(alias["source_column"], len(line[:line.index("0=10")].encode("cp949")))

    def test_source_change_during_native_parse_is_rejected_before_output(self):
        reader = gen.identity.read_native_sprs
        def changed(paths, default_fps):
            declarations = reader(paths, default_fps)
            path = self.source / "spr/list_0.spr"
            path.write_bytes(path.read_bytes() + b"\n#999 4 changed_after_read\n")
            return declarations
        output = self.base / "metadata_changed"
        with mock.patch.object(gen.identity, "read_native_sprs", side_effect=changed):
            with self.assertRaisesRegex(SystemExit, "original SPR changed while generating metadata"):
                gen.generate(self.source, output)
        self.assertFalse(output.exists())

    def test_verified_handoff_reconstructs_the_actual_native_registration(self):
        metadata = gen.bank.load_metadata(self.output)
        self.assertEqual(metadata["proof"]["native_selector_policy"], "native_explicit_actions_and_immediate_alias_owner_v1")
        planned = gen.bank.metadata_declarations(metadata)
        actual = gen.identity.read_native_sprs(sorted((self.source / "spr").glob("list_*.spr")))
        fields = ("tokens", "fps", "source_file", "source_line", "raw_body", "native_requested_sprite_id", "native_body_request_sprite_id", "native_descriptor_origin_sprite_id", "native_registration_kind", "native_action_alias_chain")
        for sprite in (10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110):
            self.assertEqual(set(planned[sprite][0].native_action_descriptors), set(actual[sprite][0].native_action_descriptors))
            for code in actual[sprite][0].native_action_descriptors:
                expected = gen.identity.native_action(actual, sprite, code)
                projected = gen.identity.native_action(planned, sprite, code)
                self.assertEqual({key: projected[key] for key in fields}, {key: expected[key] for key in fields}, (sprite, code))
                source = metadata["actions"][projected["metadata_action_key"]]
                self.assertEqual(projected["metadata_action_key"], self.action(sprite, code)["action_key"])
                self.assertTrue(gen.bank._matching_action(expected, source))

    def test_stored_registration_status_is_recomputed_from_raw_events(self):
        metadata = gen.bank.load_metadata(self.output)
        changed = copy.deepcopy(metadata)
        declaration = next(row for row in changed["declarations"] if row["sprite_id"] == 20)
        declaration["native_action_aliases"][0]["registration_status"] = "source_descriptor_unavailable"
        declaration["native_action_aliases"][0]["source_descriptor_origin_sprite_id"] = 999
        planned = gen.bank.metadata_declarations(changed)
        action = gen.identity.native_action(planned, 20, 0)
        self.assertEqual(action["native_descriptor_origin_sprite_id"], 10)
        self.assertEqual(action["native_action_alias_chain"][0]["registration_status"], "registered")
        self.assertEqual(action["native_action_alias_chain"][0]["source_descriptor_origin_sprite_id"], 10)

    def test_metadata_plan_emits_the_same_actor_addresses_and_activation_as_original_source(self):
        metadata = gen.bank.load_metadata(self.output)
        planned = gen.bank.metadata_declarations(metadata)
        actual = gen.identity.read_native_sprs(sorted((self.source / "spr").glob("list_*.spr")))
        for sprite in sorted(actual):
            for code in actual[sprite][0].native_action_descriptors:
                roles = (("source_action:" + str(code), code),)
                expected_actor, expected_members, expected_proof = gen.identity.build_actor(sprite, actual, metadata["sources"], roles)
                actor, members, proof = gen.identity.build_actor(sprite, planned, metadata["sources"], roles)
                self.assertEqual(actor, expected_actor, (sprite, code))
                self.assertEqual(members, expected_members, (sprite, code))
                self.assertEqual(proof["native_activation_by_role"], expected_proof["native_activation_by_role"], (sprite, code))
                self.assertEqual(proof["declarations"], expected_proof["declarations"], (sprite, code))

    def test_unknown_malformed_or_partial_policy_cannot_fall_back_to_legacy(self):
        for policy in ("unknown", 7, False, None):
            changed = copy.deepcopy(gen.bank.load_metadata(self.output))
            changed["proof"]["native_selector_policy"] = policy
            with self.subTest(policy=policy), self.assertRaisesRegex(ValueError, "native selector policy"):
                gen.bank.metadata_declarations(changed)

    def test_missing_requested_header_proof_cannot_reuse_descriptor_origin(self):
        changed = copy.deepcopy(gen.bank.load_metadata(self.output))
        next(iter(changed["actions"].values())).pop("native_request_declaration")
        with self.assertRaisesRegex(ValueError, "missing native requested header proof"):
            gen.bank.metadata_declarations(changed)

    def test_changed_raw_target_cannot_reuse_the_old_registered_action_row(self):
        changed = copy.deepcopy(gen.bank.load_metadata(self.output))
        declaration = next(row for row in changed["declarations"] if row["sprite_id"] == 20)
        declaration["native_action_aliases"][0]["target_sprite_id"] = 50
        with self.assertRaisesRegex(ValueError, "native .*differ"):
            gen.bank.metadata_declarations(changed)


if __name__ == "__main__":
    unittest.main()
