"""Run with --source-input pointing to the verified private Library input bundle."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE_INPUT = None
DESC_INPUT = None
spec = importlib.util.spec_from_file_location('identity', ROOT / 'tools/l1j/verify_source3_item_identities.py')
identity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(identity)


class IdentityRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if SOURCE_INPUT is None:
            raise unittest.SkipTest('Private verified input required; use --source-input')
        cls.manifest = json.loads((ROOT / 'data/l1j/source3_item_identities.json').read_text())
        cls.items = [json.loads(line) for line in (SOURCE_INPUT / 'source_items.jsonl').read_text().splitlines()]
        cls.catalog = json.loads((ROOT / 'data/catalog_v19.json').read_text())
        cls.visuals = json.loads((ROOT / 'data/l1j/live_visual_bindings.json').read_text())
        cls.tables = identity.load_desc_evidence(cls.manifest, DESC_INPUT, SOURCE_INPUT, cls.items)

    def setUp(self):
        self.binding = copy.deepcopy(self.manifest['bindings'][0])
        self.rows = copy.deepcopy(self.items)
        self.game = copy.deepcopy(self.catalog)
        self.art = copy.deepcopy(self.visuals)
        self.source = next(r for r in self.rows if r['source_item_key'] == self.binding['source_item_key'])

    def validate(self):
        return identity.validate_identity(self.binding, self.rows, self.game, self.art, self.tables)

    def rejected(self):
        with self.assertRaises(identity.IdentityError):
            self.validate()

    def test_verified_input_accepts_only_five_plain_identities_without_mutation(self):
        before = copy.deepcopy((self.rows, self.game, self.art))
        result = identity.verify(ROOT, SOURCE_INPUT, DESC_INPUT)
        self.assertEqual(len(result['identity_bindings_verified']), 5)
        self.assertEqual({r['source_item_key'].split(':')[-1]: r['game_source_id']
                          for r in result['identity_bindings_verified']},
                         {'1': '326', '8': '422', '11': '423', '29': '6391', '181': '339'})
        self.assertEqual(result['identity_bindings_verified'][0]['game_source_id'], '423')
        self.assertFalse(result['gameplay_enabled'])
        self.assertEqual((result['drops_enabled'], result['recipes_enabled'], result['npc_actions_enabled']), (0, 0, 0))
        self.validate()
        self.assertEqual((self.rows, self.game, self.art), before)

    def test_bare_numeric_id_is_not_identity(self):
        self.binding['source_item_key'] = '11'
        self.rejected()

    def test_duplicate_typed_source_is_rejected(self):
        self.rows.append(copy.deepcopy(self.source))
        self.rejected()

    def test_second_plain_template_with_same_display_is_rejected(self):
        other = copy.deepcopy(self.source)
        other['source_item_key'] = 'source3:tw380:Taiwan:weapon:100011'
        other['source_item_id'] = '100011'
        self.rows.append(other)
        self.rejected()

    def test_blessed_and_cursed_names_are_composed_without_merging(self):
        expected = {'100008': '축복받은 미스릴 단검', '100029': '축복받은 은장검',
                    '100181': '축복받은 장궁', '200001': '저주받은 오크족 단검'}
        for source_id, name in expected.items():
            source = next(r for r in self.rows if r['source_item_key'] ==
                          'source3:tw380:Taiwan:weapon:' + source_id)
            self.assertEqual(identity.identify_display(source, self.tables, 'k'), name)
            self.assertNotIn(source['source_item_key'], [b['source_item_key'] for b in self.manifest['bindings']])

    def test_blessed_template_cannot_be_adopted_as_plain_even_with_rewritten_binding(self):
        source = next(r for r in self.rows if r['source_item_key'].endswith(':100008'))
        self.binding = copy.deepcopy(next(b for b in self.manifest['bindings'] if b['source_item_id'] == '8'))
        self.binding['source_item_key'] = source['source_item_key']
        self.binding['source_item_id'] = source['source_item_id']
        self.binding['source_variant'] = source['source_variant']
        self.rejected()

    def test_unknown_bless_flag_is_not_treated_as_plain(self):
        self.source['raw_fields']['bless'] = self.source['source_variant']['bless_raw'] = '3'
        with self.assertRaises(identity.IdentityError):
            identity.identify_display(self.source, self.tables, 'k')

    def test_missing_desc_token_is_rejected(self):
        self.source['raw_fields']['identified_name_id'] = '$9999999'
        with self.assertRaises(identity.IdentityError):
            identity.identify_display(self.source, self.tables, 'k')

    def test_source_variant_changed_is_rejected(self):
        self.source['source_variant']['bless_raw'] = '2'
        self.rejected()

    def test_excluded_feature_is_rejected(self):
        self.source['excluded_feature_reasons'] = ['quest']
        self.rejected()

    def test_wrong_weapon_subtype_is_rejected(self):
        self.source['source_type'] = 'sword'
        self.rejected()

    def test_translation_projection_mismatch_is_rejected(self):
        self.source['local_desc_translation_evidence']['identified_name_id']['resolved']['k'] = '다른 아이템'
        self.rejected()

    def test_changed_source_tuple_is_rejected(self):
        self.source['source_row']['raw_sql_row'] += ' '
        self.rejected()

    def test_duplicate_game_source_id_is_rejected(self):
        row = next(r for r in self.game['아이템'] if r.get('sourceId') == '423')
        self.game['아이템'].append(copy.deepcopy(row))
        self.rejected()

    def test_game_stats_changed_requires_review(self):
        row = next(r for r in self.game['아이템'] if r.get('sourceId') == '423')
        row['atk'] += 1
        self.rejected()

    def test_missing_prior_review_is_rejected(self):
        self.art['items'] = []
        self.rejected()

    def test_icon_reference_mismatch_is_rejected(self):
        row = next(r for r in self.art['items'] if r['game_source_id'] == '423')
        row['inventory_source_member'] = 'appcenter/img/item/34.png'
        self.rejected()

    def test_engraved_or_enchanted_game_name_is_not_normalized_to_plain(self):
        for name in ('수정 단검 (각인)', '봉인된 수정 단검', '+1 수정 단검'):
            with self.subTest(name=name):
                row = next(r for r in self.game['아이템'] if r.get('sourceId') == '423')
                row['name'] = name
                self.rejected()

    def test_changed_db_or_input_bytes_require_review(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            game_root, source_root, desc_root = base / 'game', base / 'source', base / 'desc'
            files = list(self.manifest['game_file_guards']) + ['data/l1j/source3_item_identities.json']
            for relative in files:
                target = game_root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, target)
            for relative in self.manifest['input_file_guards']:
                target = source_root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(SOURCE_INPUT / relative, target)
            desc_root.mkdir()
            for relative in self.manifest['desc_evidence']['file_guards']:
                shutil.copyfile(DESC_INPUT / relative, desc_root / relative)
            for base_dir, relative in [(game_root, 'data/game_db_v17.json'),
                                       (game_root, 'data/catalog_v19.json'),
                                       (source_root, 'source_items.jsonl'),
                                       (desc_root, 'desc-k.tbl.decoded-original.bin'),
                                       (desc_root, 'desc-k.tbl.encrypted-range.bin'),
                                       (desc_root, 'S_IdentifyDesc_lines29_47.java.txt')]:
                with self.subTest(file=relative):
                    path = base_dir / relative
                    original = path.read_bytes()
                    path.write_bytes(original + b' ')
                    with self.assertRaisesRegex(identity.IdentityError, 'changed'):
                        identity.verify(game_root, source_root, desc_root)
                    path.write_bytes(original)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-input', required=True, type=Path)
    parser.add_argument('--desc-input', required=True, type=Path)
    args, remaining = parser.parse_known_args()
    SOURCE_INPUT = args.source_input
    DESC_INPUT = args.desc_input
    unittest.main(argv=[__file__] + remaining)
