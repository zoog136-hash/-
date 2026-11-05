import unittest
from copy import deepcopy
from patch523_item_icons import compile_icon_links, attach_icon_links, compact_icon_index


class IconIdentityTest(unittest.TestCase):
    def setUp(self):
        self.tables = {
            'ItemClass': [
                {'ID': 26, 'IconID': 2932, 'TestItem': False},
                {'ID': 27, 'IconID': 352, 'TestItem': False},
                {'ID': 28, 'IconID': 0, 'TestItem': False},
                {'ID': 29, 'IconID': 2932, 'TestItem': True}],
            'Icon': [{'ID': 2932, 'AssetID': 30962}, {'ID': 352, 'AssetID': 923},
                     {'ID': 0, 'AssetID': 0}],
            'AssetView': [
                {'AssetId': 30962, 'AssetTypeId': 1, 'FilePath': 'Item/adena_3.png'},
                {'AssetId': 923, 'AssetTypeId': 101, 'FilePath': 'icon/Fx_Item_example.csb'},
                {'AssetId': 0, 'AssetTypeId': 1, 'FilePath': ''}]}

    def test_join_preserves_source_and_distinguishes_non_pixels(self):
        before = deepcopy(self.tables)
        links = compile_icon_links(self.tables)
        self.assertEqual(self.tables, before)
        self.assertEqual(set(links), {'26', '27', '28'})
        self.assertEqual(links['26']['asset_id'], 30962)
        self.assertEqual(links['26']['file_path'], 'Item/adena_3.png')
        self.assertEqual(links['27']['status'], 'source_scene_player_required')
        self.assertEqual(links['28']['status'], 'source_empty_path')
        self.assertTrue(all(r['pixel_verification'] == 'not_performed' for r in links.values()))

    def test_compact_index_deduplicates_without_changing_identity(self):
        self.tables['ItemClass'].append({'ID': 30, 'IconID': 2932, 'TestItem': False})
        links = compile_icon_links(self.tables)
        index = compact_icon_index(links)
        self.assertEqual(len(index['items']), 4)
        self.assertEqual(len(index['icons']), 3)
        self.assertEqual(index['items']['26'], index['items']['30'])
        for item_id, icon_id in index['items'].items():
            self.assertEqual(index['icons'][str(icon_id)]['file_path'], links[item_id]['file_path'])

    def test_ambiguous_dangling_and_unsafe_paths_fail(self):
        mutations = [
            lambda t: t['Icon'].append(t['Icon'][0]),
            lambda t: t['AssetView'].pop(0),
            lambda t: t['AssetView'][0].update(FilePath='../other.png'),
            lambda t: t['AssetView'][0].update(FilePath='Item//other.png'),
            lambda t: t['AssetView'][0].update(FilePath='C:/other.png')]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                tables = deepcopy(self.tables); mutate(tables)
                with self.assertRaises(ValueError): compile_icon_links(tables)

    def test_attach_preserves_save_and_option_identity(self):
        links = compile_icon_links(self.tables)
        definitions = {k: {'native_record': {
            'source_item_class_id': int(k), 'sourceId': 'legacy:'+k, 'def': 7}}
            for k in links}
        before = deepcopy(definitions)
        attach_icon_links(definitions, links)
        for k in links:
            r = definitions[k]['native_record']
            self.assertEqual(r['source_icon_identity']['item_class_id'], r['source_item_class_id'])
            without = {f:v for f,v in r.items() if f != 'source_icon_identity'}
            self.assertEqual(without, before[k]['native_record'])
        definitions['26']['native_record']['source_item_class_id'] = 27
        with self.assertRaises(ValueError): attach_icon_links(definitions, links)


if __name__ == '__main__': unittest.main()
