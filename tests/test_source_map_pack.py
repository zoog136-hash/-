"""Contract/coordinate regressions run against the supplied real ZIP, never fixtures posing as art."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location("source_map_pack", Path(__file__).resolve().parents[1]/"tools/source_map_pack.py")
pack = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pack)


class MapContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = os.environ.get("TWILIGHT_MAP84_LINKAGE")
        if not path:
            raise unittest.SkipTest("TWILIGHT_MAP84_LINKAGE real ZIP required")
        assert pack.digest(Path(path)) == pack.LINKAGE_SHA
        with zipfile.ZipFile(path) as z:
            cls.inputs = [json.loads(z.read("map_source3_links/"+n)) for n in ("game_handoff.json", "collision_selection.json", "runtime_safety.json", "game_asset_manifest.json")]

    def test_real_contract_and_exact_mapping(self):
        pack.validate_contract(*self.inputs)
        rows = {r["source_map_folder"]: r for r in self.inputs[0]["maps"]}
        self.assertEqual(pack.target_for(rows["200"]), "domination_summit")
        self.assertEqual(pack.target_for(rows["4"]), "aden_world")
        self.assertEqual(pack.target_for(rows["602"]), "source_602")
        self.assertEqual(pack.target_for(rows["54/25"]), "source_variant_54_25")

    def test_rejects_protected_deleted_and_guessed_alias(self):
        original = self.inputs[0]["maps"][0]
        for mid in pack.PROTECTED + ["yahee_temple", "balrog_temple", "albino_03"]:
            with self.assertRaises(ValueError):
                pack.target_for(dict(original, target_map_id=mid))
        with self.assertRaises(ValueError):
            pack.target_for(dict(original, source_map_id=639, target_map_id="source_639"))

    def test_no_collision_fallback_or_variant_inheritance(self):
        for choose in (lambda r: r["source_map_id"] is None, lambda r: r["source_map_id"] == 200):
            values = copy.deepcopy(self.inputs)
            next(r for r in values[0]["maps"] if choose(r))["selected_collision_version"] = "360"
            with self.assertRaises(ValueError):
                pack.validate_contract(*values)

    def test_safety_flags_cannot_be_relaxed(self):
        for key in ("runtime_playability_claim_allowed", "all_nonretained_destination_routes_disabled", "all_variant_map_id_inheritance_forbidden"):
            values = copy.deepcopy(self.inputs)
            values[2][key] = not values[2][key]
            with self.assertRaises(ValueError): pack.validate_contract(*values)
        values = copy.deepcopy(self.inputs)
        values[2]["must_keep_disabled"][0]["enabled"] = True
        with self.assertRaises(ValueError): pack.validate_contract(*values)

    def test_expanded_chunk_origin_and_shared_seam(self):
        # An x-neighbor moves +1536,-768; local x=0 exactly equals x=64
        # of its predecessor. Expanded top margin is subtracted by image pixels.
        a = {"world_bounds": [32768,32768,32831,32831]}
        b = {"world_bounds": [32832,32768,32895,32831]}
        self.assertEqual(pack.placement(a, {"origin_pixels":[0,-24]}, [32768,32768]), [0,-24])
        self.assertEqual(pack.placement(b, {"origin_pixels":[0,0]}, [32768,32768]), [1536,-768])
        self.assertEqual([24*64+24,768-12*64], [1536+24,-768+768])

    def test_path_rejection(self):
        for path in ("../chunk.webp", "/tmp/a", "chunks/../a", "a\\b", "a//b"):
            with self.assertRaises(ValueError): pack.safe_path(path)

    def test_bad_input_and_existing_output_are_never_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            bad_zip = root/"bad.zip"
            bad_zip.write_bytes(b"not the approved contract")
            with self.assertRaisesRegex(ValueError, "SHA mismatch"):
                pack.build(bad_zip, root/"assets", root/"new-pack")
            self.assertFalse((root/"new-pack").exists())
            existing = root/"existing-pack"
            existing.mkdir()
            (existing/"save.json").write_bytes(b"must remain unchanged")
            with self.assertRaisesRegex(ValueError, "already exists"):
                pack.build(Path(os.environ["TWILIGHT_MAP84_LINKAGE"]), root/"assets", existing)
            self.assertEqual((existing/"save.json").read_bytes(), b"must remain unchanged")


if __name__ == "__main__":
    unittest.main()
