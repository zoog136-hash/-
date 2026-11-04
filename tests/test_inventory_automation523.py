"""Private-source compiler checks; set TWILIGHT_SOURCE523_ZIP to run them."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('inventory_builder', ROOT/'tools/build_inventory_automation523.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
SOURCE = Path(os.environ.get('TWILIGHT_SOURCE523_ZIP', '/nonexistent/private-source523.zip'))

@unittest.skipUnless(SOURCE.is_file(), 'verified private source ZIP required')
class Inventory523CompilerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.prices = ROOT/'data/automation/inventory523_prices.json'
        cls.catalog = ROOT/'data/catalog_v19.json'
        cls.document = builder.compile_pack(SOURCE, cls.catalog, cls.prices)

    def test_full_source_counts_and_identity_join(self):
        self.assertEqual(self.document['counts'], {'storage_rows':84,'sell_rows':25,'items':80,'inven_storage_rows':43,'inven_sell_rows':9,'confirmed_prices':11,'virtual_selectors':4,'test_items':5})
        self.assertEqual(self.document['items']['767']['price']['adena'], 20000)
        self.assertEqual(self.document['items']['767']['binding']['sourceId'], '767')

    def test_virtual_selectors_do_not_hide_real_test_item(self):
        for item_id in ('45011','45021','45031','45041'):
            self.assertTrue(self.document['items'][item_id]['virtual'])
        fragment = self.document['items']['8271']
        self.assertTrue(fragment['test_item'])
        self.assertFalse(fragment['virtual'])

    def test_deterministic_pack_matches_runtime_pin(self):
        with tempfile.TemporaryDirectory() as folder:
            result = builder.write_pack(self.document, Path(folder))
            second = builder.write_pack(copy.deepcopy(self.document), Path(folder)/'second')
            self.assertEqual(result, second)
            runtime = (ROOT/'scripts/warehouse/inventory_source523.gd').read_text()
            self.assertIn(result['payload_sha256'], runtime)
            self.assertIn(result['zip_sha256'], runtime)
            self.assertIn(str(result['payload_bytes']), runtime)
            self.assertIn(str(result['zip_bytes']), runtime)

    def test_corrupt_source_rejected_before_parse(self):
        with tempfile.TemporaryDirectory() as folder:
            damaged = Path(folder)/'source.zip'
            damaged.write_bytes(b'not the authorized original')
            with self.assertRaisesRegex(ValueError, 'unsupported source bytes'):
                builder.compile_pack(damaged, self.catalog, self.prices)

    def test_corroborated_prices_cannot_disagree_with_original(self):
        policies = json.loads(self.prices.read_text())
        policies['prices']['767']['adena'] = 1
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'prices.json'
            path.write_text(json.dumps(policies))
            with self.assertRaisesRegex(ValueError, 'source/public price disagreement: 767'):
                builder.compile_pack(SOURCE, self.catalog, path)

    def test_price_outside_native_selection_rejected(self):
        policies = json.loads(self.prices.read_text())
        policies['prices']['999999999'] = {'adena':1}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'prices.json'
            path.write_text(json.dumps(policies))
            with self.assertRaisesRegex(ValueError, 'outside native sell selection'):
                builder.compile_pack(SOURCE, self.catalog, path)

    def test_url_tamper_and_name_similarity_never_join(self):
        catalog = json.loads(self.catalog.read_text('utf-8-sig'))
        original = next(row for row in catalog['아이템'] if row.get('source') == 'inven' and str(row.get('sourceId')) == '767')
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'catalog.json'
            original['sourceUrl'] += '-wrong'
            path.write_text(json.dumps(catalog, ensure_ascii=False))
            document = builder.compile_pack(SOURCE, path, self.prices)
            self.assertEqual(document['items']['767']['binding'], {})
            self.assertEqual(document['items']['767']['binding_pending'], 'source_url_id_mismatch')
            original['sourceUrl'] = 'https://lineagem.inven.co.kr/db/item/767'
            original['name'] += ' (비슷한 이름)'
            path.write_text(json.dumps(catalog, ensure_ascii=False))
            document = builder.compile_pack(SOURCE, path, self.prices)
            self.assertEqual(document['items']['767']['binding'], {})
            self.assertEqual(document['items']['767']['binding_pending'], 'exact_descriptor_mismatch')

    def test_ambiguous_inventory_name_is_not_joined(self):
        catalog = json.loads(self.catalog.read_text('utf-8-sig'))
        original = next(row for row in catalog['아이템'] if row.get('source') == 'inven' and str(row.get('sourceId')) == '767')
        duplicate = copy.deepcopy(original)
        duplicate['source'] = 'test-duplicate'
        catalog['아이템'].append(duplicate)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'catalog.json'
            path.write_text(json.dumps(catalog, ensure_ascii=False))
            document = builder.compile_pack(SOURCE, path, self.prices)
            self.assertEqual(document['items']['767']['binding'], {})
            self.assertEqual(document['items']['767']['binding_pending'], 'ambiguous_inventory_name')

if __name__ == '__main__':
    unittest.main()
