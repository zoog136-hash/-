import unittest
from base508_contract import contract, supplied_cell, spawn_record, SPACE


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.manifest = {'edition':'LineageM_base508','land':{'ID':51201,'AssetPath':'13561/'},'geometry':[{'origin':[32768,32768]}], 'art':{}}
        self.spec = contract(self.manifest)
        self.view = {'ID':100,'NpcSpawnPackID':7,'NpcClassID':12,'NpcLevel':83,'IsSpawn':1,'ServerLimitSetID':0}
        self.reference = {'ID':44,'NpcSpawnPackID':7,'Probability':0,'Territory':{'ID':55,'LandID':51201,'StartX':32770,'StartY':32771,'EndX':32773,'EndY':32775}}

    def test_land_id_is_not_asset_path(self):
        self.assertEqual(self.spec['map_key'],'base508_land_51201')
        self.assertEqual(self.spec['asset_path'],'13561/')
        self.assertEqual(self.spec['coordinate_space'],SPACE)
        self.reference['Territory']['LandID'] = 13561
        with self.assertRaises(ValueError): spawn_record(self.spec,self.view,self.reference)

    def test_json_float_ids_keep_the_same_canonical_key(self):
        self.manifest['land']['ID'] = 51201.0
        self.assertEqual(contract(self.manifest)['map_key'],'base508_land_51201')
        self.manifest['land']['ID'] = 51201.5
        with self.assertRaises(ValueError): contract(self.manifest)

    def test_region_is_never_a_center_or_active_instance(self):
        record = spawn_record(self.spec,self.view,self.reference)
        self.assertEqual(record['position_kind'],'region')
        self.assertEqual(record['source_bounds'],[32770,32771,32773,32775])
        self.assertIsNone(record['source_point'])
        self.assertIsNone(record['runtime_confirmed_source_cell'])
        self.assertEqual(record['npc_level_contextual'],83)
        self.assertEqual(record['probability_raw'],0)

    def test_legacy_pixels_and_unsupplied_chunks_are_rejected(self):
        self.assertFalse(supplied_cell(self.spec,[3100,4390]))
        self.assertFalse(supplied_cell(self.spec,[32832,32768]))
        self.assertTrue(supplied_cell(self.spec,[32768,32768]))
        self.assertFalse(supplied_cell(self.spec,[32768.5,32768]))

    def test_context_join_mismatch_is_rejected(self):
        self.reference['NpcSpawnPackID'] = 8
        with self.assertRaises(ValueError): spawn_record(self.spec,self.view,self.reference)


if __name__ == '__main__': unittest.main()
