"""The generated handoff loads in the bank builder and plans like the real SPR reader."""
import io
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

import build_reference_sp2_bank as bank
import client523_bank_metadata as gen
import original_spr

LIST = (b"#10 4 knight\r\n110.framerate(24)\r\n\t0.walk(1 2,0.0:2 0.1:2)\r\n\t101.shadow(30)\r\n"
        b"#11 4=10 knight alias\r\n\t1.attack(1 1,8.0:3)\r\n#20 1 dummy\r\n")


class GeneratedHandoffTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        src = self.tmp / "client"
        (src / "spr").mkdir(parents=True)
        (src / "spr/list_0.spr").write_bytes(LIST)
        (src / "sp2/Sprite").mkdir(parents=True)
        (src / "sp2/Sprite/10-0.sp2").write_bytes(b"\xfe\x01x")
        inventory = {"Sprite/10-0.sp2": {"bytes": 3, "crc32": "00000000", "container": "Client/Data/Sprite1.dat"},
                     "Sprite/11-8.sp2": {"bytes": 2, "crc32": "11111111", "container": "Client/Data/Sprite2.dat"}}
        (src / "client523_sp2_inventory.json").write_text(json.dumps(inventory))
        (src / "tables").mkdir()
        buffer = io.BytesIO()
        with zipfile.ZipFile(buffer, "w") as archive:
            archive.writestr("content/NpcClass.json", json.dumps({"rows": [{"ID": 1, "Sprite": 11}]}))
        (src / "tables/current523_content_tables.zip").write_bytes(buffer.getvalue())
        (src / "client523_receipt.json").write_text(json.dumps({"complete": True}))
        self.src = src
        self.summary = gen.generate(src, self.tmp / "meta")

    def test_bank_loader_accepts_declared_counts(self):
        metadata = bank.load_metadata(self.tmp / "meta")
        self.assertEqual(len(metadata["inventory"]), 2)
        self.assertEqual(metadata["targets"], {"Sprite/10-0.sp2", "Sprite/11-8.sp2"})
        self.assertEqual(metadata["proof"]["expected_counts"], {"inventory_members": 2, "target_members": 2})
        self.assertIn(11, metadata["family_roots"])  # table reference
        self.assertIn(10, metadata["family_roots"])  # declared SP2 owner
        self.assertEqual(self.summary["inventory_members_with_sha256"], 1)

    def test_metadata_plan_matches_actual_reader(self):
        metadata = bank.load_metadata(self.tmp / "meta")
        planned = bank.metadata_declarations(metadata)
        actual = original_spr.read([self.src / "spr/list_0.spr"])
        for sprite in (10, 11):
            _, plan_actions = original_spr.resolve(planned, sprite)
            _, real_actions = original_spr.resolve(actual, sprite)
            self.assertEqual(sorted(plan_actions), sorted(real_actions))
            for code, action in real_actions.items():
                source = metadata["actions"][plan_actions[code]["metadata_action_key"]]
                self.assertTrue(bank._matching_action(action, source))
        self.assertEqual(original_spr.resolve_references(planned, 11)["shadow"][0]["targets"], [30])

    def test_action_keys_follow_runtime_pattern(self):
        import re
        metadata = bank.load_metadata(self.tmp / "meta")
        for key, action in metadata["actions"].items():
            self.assertRegex(key, "^" + re.escape(action["source_file"]) + r":B[0-9]+:A" + str(action["action_id"]) + "$")

    def test_literal_dummy_declaration_is_registered(self):
        metadata = bank.load_metadata(self.tmp / "meta")
        self.assertIn(20, bank.metadata_dummy_declarations(metadata))

    def test_old_handoffs_keep_fixed_counts(self):
        manifest = json.loads((self.tmp / "meta" / bank.HANDOFF).read_text())
        del manifest["expected_counts"]
        (self.tmp / "meta" / bank.HANDOFF).write_text(json.dumps(manifest))
        with self.assertRaises(ValueError):
            bank.load_metadata(self.tmp / "meta")

    def test_client_section_default_fps_is_opt_in_and_overridden_by_110(self):
        plain = original_spr.read([self.src / "spr/list_0.spr"])
        default = original_spr.read([self.src / "spr/list_0.spr"], 24)
        self.assertIsNone(plain[11][0].actions[1]["fps"])
        self.assertEqual(default[11][0].actions[1]["fps"], 24)
        self.assertEqual(default[11][0].actions[1]["fps_provenance"]["kind"], "client_section_default")
        self.assertEqual(default[10][0].actions[0]["fps_provenance"]["raw_body"], "24")  # explicit 110 wins
        with self.assertRaises(ValueError):
            original_spr.read([self.src / "spr/list_0.spr"], 30)

    def test_generated_default_policy_is_recorded(self):
        gen.generate(self.src, self.tmp / "meta24", client_default_fps=True)
        manifest = json.loads((self.tmp / "meta24" / bank.HANDOFF).read_text())
        self.assertEqual(manifest["timing_policy"], "client_section_default_fps_24")
        metadata = bank.load_metadata(self.tmp / "meta24")
        key = next(k for k, a in metadata["actions"].items() if a["action_id"] == 1)
        self.assertEqual(metadata["actions"][key]["explicit_fps"], 24)
        contract = bank.consumer_contract(client_default_fps=True)
        self.assertEqual(contract["timing"], "source_explicit_or_client_section_default")
        self.assertEqual(contract["client_section_default_fps"], 24)

    def test_missing_layers_follow_client_rules(self):
        def frame(*layers):
            return {"duration_ticks": 1, "layers": [{"kind": k, "source_sprite_id": sid, "member": m, "group_bit": 0, "frame_index": 0} for k, sid, m in layers]}
        layers = (("body", 1, "Sprite/1-0.sp2"), ("clothes", 2, "Sprite/2-0.sp2"), ("clothes", 3, "Sprite/3-0.sp2"),
                  ("clothes", 4, "Sprite/4-0.sp2"), ("shadow", 5, "Sprite/5-0.sp2"))
        actor = {"source_sprite_id": 1, "roles": {"r": {"directions": [[frame(*layers)]]}}}
        proof = {"declarations": [{"kind": k, "declaration_path": [{"sprite_id": sid}]} for k, sid, _ in layers]}
        members = {m for _, _, m in layers}
        identities = {m: {} for m in members - {"Sprite/3-0.sp2", "Sprite/5-0.sp2"}}
        new_actor, kept, new_proof, omitted = bank.omit_missing_layers(actor, members, proof, identities)
        kinds = [(l["kind"], l["source_sprite_id"]) for l in new_actor["roles"]["r"]["directions"][0][0]["layers"]]
        self.assertEqual(kinds, [("body", 1), ("clothes", 2)])  # prefix before first missing clothes; shadow absent
        self.assertEqual(kept, {"Sprite/1-0.sp2", "Sprite/2-0.sp2"})
        self.assertEqual({(o["kind"], o["source_sprite_id"]) for o in omitted}, {("clothes", 3), ("clothes", 4), ("shadow", 5)})
        self.assertEqual(len(new_proof["declarations"]), 2)
        with self.assertRaises(ValueError):
            bank.omit_missing_layers(actor, members, proof, {m: {} for m in members - {"Sprite/1-0.sp2"}})


if __name__ == "__main__":
    unittest.main()
