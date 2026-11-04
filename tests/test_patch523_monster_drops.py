"""Synthetic compiler regressions. Original tables stay outside public Git."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zlib
import sys

SCRIPT = Path(__file__).resolve().parents[1]/'tools/monsters/build_patch523_monster_drops.py'
sys.path.insert(0, str(SCRIPT.parent))
spec = importlib.util.spec_from_file_location('patch523_drops', SCRIPT)
compiler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compiler)

class DropCompilerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root/'content').mkdir()
        rows = [dict(ID=i, NpcClassID=10, ItemClassID=20, Bless=b, RequiredQuestID=q)
                for i, b, q in [(1,1,0),(2,1,0),(3,2,0),(4,1,99)]]
        self.tables = {
            'NpcClass':[dict(ID=10,Sprite=100,Name='variant-10',DescId=1,TestNPC=False,Category=1)],
            'NpcCategory':[dict(ID=1,IsShowDropInfo=True,IsAttackable=True)],
            'ItemClass':[dict(ID=20,Name='source-sword',DescID=2,IdentifiedDescID=2,CategoryID=1,GradeID=3)],
            'NpcItemDropView':rows,
            'ItemBlessCode':[dict(ID=1,Name='Normal'),dict(ID=2,Name='Blessed')],
            'DescData_Korean':[dict(ID=1,Description='NPC'),dict(ID=2,Description='Sword'),dict(ID=3,Description='희귀')],
            'ItemCategory':[dict(ID=1,Name='Weapon',DescID=2,IsConsumable=False,IsStackable=False)],
            'Grade':[dict(ID=3,Name='Grade3',DescID=3)],
            'EquipSlot':[dict(ID=8,Name='WeaponHold',DescID=2)],
            'ItemEquipSlot':[dict(ItemClassID=20,EquipSlotID=8)],
            'ItemBonus':[], 'Bonus':[], 'BonusType':[], 'Unit':[], 'Class':[],
            'ItemClassLimit':[], 'WeaponType':[]}
        for name in compiler.ITEM_TABLES:
            self.tables.setdefault(name, [])
        self.write_source()
        self.catalog = self.root/'catalog.json'
        self.item = dict(name='Sword',source='inven',sourceId='20',sourceUrl='https://lineagem.inven.co.kr/db/item/20',slot='weapon',type='sword',grade='희귀')
        self.write_catalog([self.item])

    def write_source(self):
        index = []
        for name, rows in self.tables.items():
            data = ('\ufeff'+json.dumps({'rows':rows})).encode()
            path = 'content/'+name+'.json'
            (self.root/path).write_bytes(data)
            index.append(dict(path=path,sha256=compiler.digest(data),bytes=len(data),crc32=f'{zlib.crc32(data):08x}',row_count=len(rows)))
        (self.root/'index.json').write_text(json.dumps(index))

    def write_catalog(self, rows):
        self.catalog.write_text(json.dumps({'아이템':rows}))

    def test_conditions_and_provenance(self):
        pack = compiler.compile_pack(self.root, self.catalog)
        self.assertEqual([r['ID'] for r in pack['drops']['10']], [1,2,3,4])
        self.assertEqual([r['source_row_1based'] for r in pack['drops']['10']], [1,2,3,4])
        self.assertEqual(pack['counts']['duplicate_extra_rows'], 1)
        self.assertEqual(pack['counts']['distinct_payloads'], 3)
        self.assertEqual(pack['counts']['pairs_with_condition_variants'], 1)
        self.assertEqual(pack['counts']['quest_conditional_rows'], 1)
        self.assertEqual(pack['bindings']['20']['sourceId'], '20')
        self.assertFalse(any(k in r for r in pack['drops']['10'] for k in ('chance','min','max','quantity','weight')))

    def test_deterministic_private_zip(self):
        pack = compiler.compile_pack(self.root, self.catalog)
        a = compiler.write_pack(pack, self.root/'a')
        b = compiler.write_pack(pack, self.root/'b')
        self.assertEqual(a,b)
        self.assertEqual((self.root/'a/TWILIGHT_patch523_monster_drops.zip').read_bytes(),(self.root/'b/TWILIGHT_patch523_monster_drops.zip').read_bytes())

    def test_exact_ids_and_unique_inventory_names(self):
        for key, value in [('sourceId','21'),('sourceUrl','https://example.com/20'),('name','similar sword')]:
            with self.subTest(key=key):
                self.write_catalog([{**self.item,key:value}])
                pack = compiler.compile_pack(self.root,self.catalog)
                self.assertEqual(pack['bindings']['20']['binding_kind'],'native_523_definition')
                self.assertIn('20',pack['existing_catalog_gaps'])
                self.assertEqual(pack['bindings']['20']['sourceId'],'m523:item:20')
                self.assertEqual(pack['unresolved_item_ids'],{})
        self.write_catalog([self.item,{**self.item,'sourceId':'21'}])
        self.assertEqual(compiler.compile_pack(self.root,self.catalog)['bindings']['20']['sourceId'],'m523:item:20')

    def test_tampered_source_rejected(self):
        path = self.root/'content/NpcItemDropView.json'
        path.write_bytes(path.read_bytes()+b' ')
        with self.assertRaisesRegex(ValueError,'source index mismatch'):
            compiler.compile_pack(self.root,self.catalog)

    def test_variant_npc_not_merged(self):
        self.tables['NpcClass'].append({**self.tables['NpcClass'][0],'ID':11,'Name':'variant-11'})
        self.tables['NpcItemDropView'].append(dict(ID=5,NpcClassID=11,ItemClassID=20,Bless=2,RequiredQuestID=0))
        self.write_source()
        pack = compiler.compile_pack(self.root,self.catalog)
        self.assertEqual(list(pack['drops']),['10','11'])
        self.assertEqual(pack['drops']['11'][0]['NpcClassID'],11)

if __name__ == '__main__':
    unittest.main()
