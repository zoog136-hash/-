"""Synthetic selector regressions; no fixture is original art or native render proof."""
import copy
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "lineagem_original"))
import build_reference_sp2_bank as bank
import original_spr


SOURCE = """#100 1 selector_fixture
110.framerate(24)
3.Breath(1 2,7.4:2 ]999 15.9:3)
101.shadow(201)
105.clothes(1 200)
#200 1=202 requested_clothes_fixture
110.framerate(2)
3.Unrelated(0 1,80.0:999)
104.attr(8)
#201 1 shadow_fixture
110.framerate(5)
3.Invalid_unused_child_action(0 2,96.0:-1)
#202 1 physical_clothes_fixture
104.attr(128)
"""


def source_fixture(text=SOURCE):
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "list_fixture.spr"
        path.write_bytes(text.encode("cp949"))
        declarations = original_spr.read([path])
    sources = {"list_fixture.spr": {"sha256": hashlib.sha256(text.encode("cp949")).hexdigest()}}
    return declarations, sources


class SourceAuxiliarySelectorTests(unittest.TestCase):
    def test_auxiliary_ignores_own_action_rate_selector_and_parse_errors(self):
        declarations, sources = source_fixture()
        actor, members, proof = bank.identity.build_actor(100, declarations, sources, (("source_action:3", 3),))
        track = actor["roles"]["source_action:3"]
        self.assertEqual(track["fps"], 24)
        self.assertEqual([frame["duration_ticks"] for frame in track["directions"][0]], [2, 3])
        for direction, frames in enumerate(track["directions"]):
            for token, frame in enumerate(frames):
                group, picture, _ = [(7, 4, 2), (15, 9, 3)][token]
                expected_file, expected_bit = original_spr.frame_address(group, direction, 1)
                self.assertEqual({(layer["group_bit"], layer["frame_index"]) for layer in frame["layers"]},
                                 {(expected_bit, picture)})
                self.assertEqual({layer["member"] for layer in frame["layers"]},
                                 {f"Sprite/{sprite}-{expected_file}.sp2" for sprite in (100, 201, 202)})
        self.assertFalse(any("-80.sp2" in member or "-96.sp2" in member for member in members))
        self.assertEqual(proof["layer_policy"], "auxiliary_101_105_share_parent_selector_picture_and_timing")

    def test_graph_uses_one_parent_record_without_child_action_registry(self):
        declarations, sources = source_fixture()
        lookups = []
        def key_for(actor, action):
            lookups.append((actor, action))
            self.assertEqual((actor, action), (100, 3))
            return "fixture:100:A3"
        graph = bank.construct_source_graph(100, 3, declarations, sources, key_for)
        self.assertEqual(set(graph["records"]), {(100, 3)})
        self.assertEqual(graph["record"]["independent_source_layers"], [])
        self.assertFalse(graph["record"]["independent_source_layers_opt_in"])
        self.assertEqual(graph["record"]["auxiliary_selector_policy"], bank.identity.LAYER_POLICY)
        self.assertTrue(lookups)
        self.assertEqual({item["target_sprite_id"] for item in graph["record"]["source_reference_instances"]}, {200, 201})
        compact = graph["record"]["compact_roles"]["source_action:3"]
        self.assertEqual(compact["tokens"], [(7, 4, 2), (15, 9, 3)])
        self.assertEqual({layer["source_sprite_id"] for layer in compact["layers"]}, {100, 201, 202})

    def test_requested_owner_alias_path_and_raw_input_remain_intact(self):
        declarations, sources = source_fixture()
        before = copy.deepcopy(declarations)
        graph = bank.construct_source_graph(100, 3, declarations, sources, lambda actor, action: "fixture:A3")
        self.assertEqual(declarations, before)
        clothes = next(item for item in graph["record"]["source_layer_declarations"] if item["kind"] == "clothes")
        self.assertEqual(clothes["source_sprite_id"], 202)
        self.assertEqual([item["sprite_id"] for item in clothes["declaration_path"]], [200, 202])
        self.assertEqual([item["literal_attribute_directives"][0]["body"] for item in clothes["declaration_path"]], ["8", "128"])
        proof = next(item for item in graph["record"]["source_proof"]["declarations"] if item["kind"] == "clothes")
        self.assertEqual(proof["edge_path"][-1]["target_sprite_id"], 200)
        self.assertEqual(proof["role_policy"], {"source_action:3": "exact_parent_selector_picture_and_timing"})

    def test_parent_token_annotations_are_preserved_and_not_auxiliary_clocks(self):
        declarations, sources = source_fixture()
        graph = bank.construct_source_graph(100, 3, declarations, sources, lambda actor, action: "fixture:A3")
        proof = graph["record"]["source_proof"]["roles"]["source_action:3"]
        self.assertEqual(proof["source_annotations"][0]["raw"], "]999")
        self.assertFalse(any("999-" in member for member in graph["members"]))
        self.assertEqual(len(graph["record"]["source_reference_instances"]), 2)

    def test_absent_child_action_uses_same_selector_contract(self):
        text = SOURCE.replace("110.framerate(2)\n3.Unrelated(0 1,80.0:999)\n", "")
        declarations, sources = source_fixture(text)
        graph = bank.construct_source_graph(100, 3, declarations, sources, lambda actor, action: "fixture:A3")
        self.assertEqual(graph["record"]["independent_source_layers"], [])
        self.assertIn("Sprite/202-16.sp2", graph["members"])
        self.assertNotIn("Sprite/202-80.sp2", graph["members"])

    def test_parent_picture_still_uses_existing_per_asset_clamp_and_null_rules(self):
        declarations, sources = source_fixture()
        graph = bank.construct_source_graph(100, 3, declarations, sources, lambda actor, action: "fixture:A3")
        actor = graph["record"]["actor"]
        parsed = {}
        for member in graph["members"]:
            frames = [{"samples": 1}, {"samples": 1}]
            parsed[member] = {"groups": {bit: {"frames": copy.deepcopy(frames)} for bit in range(8)}}
        # One source direction is absent only for shadow; no invented mirror.
        parsed["Sprite/201-0.sp2"]["groups"].pop(7)
        adapted = bank.apply_client_frame_rules(actor, {}, parsed)
        first = adapted["roles"]["source_action:3"]["directions"][0][0]
        by_kind = {layer["kind"]: layer for layer in first["layers"]}
        self.assertEqual(by_kind["shadow"]["client_null"], "direction_absent")
        for kind in ("body", "clothes"):
            self.assertEqual(by_kind[kind]["frame_index"], 1)
            self.assertEqual(by_kind[kind]["clamped_from_frame_index"], 4)
        self.assertEqual(actor["roles"]["source_action:3"]["directions"][0][0]["layers"][0]["frame_index"], 4)

    def test_missing_parent_addressed_original_is_not_replaced_by_own_action_file(self):
        declarations, sources = source_fixture()
        graph = bank.construct_source_graph(100, 3, declarations, sources, lambda actor, action: "fixture:A3")
        raw = b"synthetic_byte_identity_fixture_not_SP2_art"
        identities = {member: {"member": member, "bytes": len(raw),
            "crc32": f"{zlib.crc32(raw) & 0xffffffff:08x}",
            "original_member_sha256_evidence": {"sha256": bank.sha(raw)}} for member in graph["members"]}
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for member in graph["members"]:
                if member.startswith("Sprite/202-"): continue
                target = root / member
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            # The target's own action addresses80. It cannot satisfy parent
            # selector7/picture4, whose required original file is202-0.
            (root / "Sprite/202-80.sp2").write_bytes(raw)
            with self.assertRaisesRegex(ValueError, "original SP2 unavailable: Sprite/202-0.sp2"):
                bank.verified_raw(root, graph["members"], identities)

    def test_dummy_exclusion_preserves_original_and_parent_connection(self):
        declarations, sources = source_fixture()
        before = copy.deepcopy(declarations)
        dummy = {200: {"sprite_id": 200, "literal_name": "dummy_fixture"}}
        graph = bank.construct_source_graph(100, 3, declarations, sources, lambda actor, action: "fixture:A3", excluded_dummy=dummy)
        self.assertEqual(declarations, before)
        self.assertEqual({layer["kind"] for layer in graph["record"]["actor"]["roles"]["source_action:3"]["directions"][0][0]["layers"]}, {"body", "shadow"})
        self.assertEqual(graph["record"]["excluded_dummy_source_edges"][0]["target_sprite_id"], 200)
        self.assertTrue(graph["record"]["excluded_dummy_source_edges"][0]["originals_preserved"])


if __name__ == "__main__":
    unittest.main()
