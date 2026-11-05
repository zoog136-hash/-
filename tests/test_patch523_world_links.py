import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "map_restore"))
from build_patch523_world_links import CONTEXT, PRIMARY, SOURCE_SHA256, compile_links


class WorldLinksTests(unittest.TestCase):
    def tables(self):
        tables = {name: [] for name in PRIMARY + CONTEXT}
        tables.update({
            "Land": [{"ID": 4, "AssetPath": "Aden/"}, {"ID": 30, "AssetPath": "30/"}],
            "Territories": [
                {"ID": 90, "LandID": 4, "StartX": 9, "StartY": 3, "EndX": 0, "EndY": 0},
                {"ID": 91, "LandID": 30, "StartX": 1, "StartY": 1, "EndX": 2, "EndY": 2}],
            "Portal": [{"ID": 30, "SourceLandID": 4, "SourceX": 7, "SourceY": 8, "AssetID": 0, "TargetTerritoryID": 91}],
            "NpcClass": [{"ID": 8}, {"ID": 9}],
            "NpcSpawnPackTerritory": [
                {"ID": 1, "NpcSpawnPackID": 8, "TerritoriesID": 90, "Probability": 0},
                {"ID": 2, "NpcSpawnPackID": 10, "TerritoriesID": 90, "Probability": 1},
                {"ID": 3, "NpcSpawnPackID": 10, "TerritoriesID": 91, "Probability": 0}],
            "NpcSpawnPackNpcClassView": [
                {"ID": 1, "NpcSpawnPackID": 10, "NpcClassID": 9, "NpcLevel": 7, "IsSpawn": 0, "ServerLimitSetID": 274},
                {"ID": 2, "NpcSpawnPackID": 10, "NpcClassID": 9, "NpcLevel": 9, "IsSpawn": 1, "ServerLimitSetID": 772}],
            "DaynightSpawnPack": [{"ID": 1, "NpcSpawnPackID": 10}, {"ID": 1, "NpcSpawnPackID": 10}],
        })
        return tables

    def compile(self, tables):
        return compile_links(tables, {name: "f" * 64 for name in PRIMARY + CONTEXT}, SOURCE_SHA256)

    def test_shared_pack_variants_disabled_rows_and_multiplicity_survive(self):
        tables = self.tables()
        before = copy.deepcopy(tables)
        files, _ = self.compile(tables)
        aden = json.loads(files["lands/4.json"])
        other = json.loads(files["lands/30.json"])
        self.assertEqual(aden["spawn_views"], tables["NpcSpawnPackNpcClassView"])
        self.assertEqual(other["spawn_views"], aden["spawn_views"])
        self.assertEqual(aden["pack_context"]["DaynightSpawnPack"], tables["DaynightSpawnPack"])
        self.assertEqual(tables, before)

    def test_missing_pack_is_not_filled_from_same_number_class(self):
        files, _ = self.compile(self.tables())
        aden = json.loads(files["lands/4.json"])
        self.assertEqual(aden["unresolved_class_view_packs"], [8])
        self.assertNotIn({"ID": 8}, aden["npc_classes"])

    def test_inverted_area_direction_and_region_destination_unchanged(self):
        tables = self.tables()
        files, _ = self.compile(tables)
        aden = json.loads(files["lands/4.json"])
        self.assertEqual(aden["territories"], [tables["Territories"][0]])
        self.assertEqual(aden["portals"][0]["target_territory"], tables["Territories"][1])
        self.assertEqual(json.loads(files["lands/30.json"])["portals"], [])

    def test_foreign_key_rejection(self):
        for table, field in [("Portal", "TargetTerritoryID"), ("NpcSpawnPackTerritory", "TerritoriesID"), ("NpcSpawnPackNpcClassView", "NpcClassID")]:
            with self.subTest(table=table):
                tables = self.tables()
                tables[table][0][field] = 999
                with self.assertRaises(ValueError): self.compile(tables)

    def test_duplicate_primary_identity_rejected(self):
        tables = self.tables()
        tables["Land"].append(tables["Land"][0])
        with self.assertRaises(ValueError): self.compile(tables)


if __name__ == "__main__":
    unittest.main()
