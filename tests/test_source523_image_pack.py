#!/usr/bin/env python3
"""Structural pack checks with metadata and opaque bytes; no image fixtures."""
import copy
import hashlib
import importlib.util
import json
import pathlib
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'tools/images/build_source523_image_pack.py'
SPEC = importlib.util.spec_from_file_location('source523_image_pack_builder', SCRIPT)
BUILDER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILDER)


def sha(data):
    return hashlib.sha256(data).hexdigest()


class ImagePackStructuralFixtures(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='source523-pack-structure-')
        self.root = pathlib.Path(self.temporary.name)

    def tearDown(self):
        self.temporary.cleanup()

    def table_fixture(self):
        rows = [{'AssetId': 17, 'AssetTypeId': 3, 'FilePath': 'opaque.bin'}]
        raw = json.dumps({'rows': rows}).encode()
        index = [{'version': 523, 'path': 'content/AssetView.json',
                  'bytes': len(raw), 'sha256': sha(raw), 'row_count': len(rows),
                  'status': 'strict_json_pass', 'member_crc_verified': True}]
        return rows, raw, index

    def member_fixture(self, changed=False):
        container_hash = sha(b'opaque current DAT identity')
        row = {'path': 'fixture/image/opaque.bin', 'container': 'fixture/current.dat',
               'relative_output_path': 'decoded/fixture/image/opaque.bin',
               'current523_component': ('changed4_current523' if changed else 'retained_noncard_lineage14964'),
               'original_container_sha256': container_hash, 'original_container_bytes': 128,
               'encrypted_bytes': 32, 'plain_bytes': 23, 'width': 2, 'height': 3,
               'sha256': sha(b'opaque original file'), 'stored_member_sha256': sha(b'opaque stored member'),
               'original_bytes_preserved': True, 'pkcs7_padding_verified': True,
               'pillow_verify_and_load': True, 'format': 'JPEG',
               'retained_prior_catalog_all_fields_verified': not changed,
               'current523_alignment': ('exact_current523_changed_original_size_sha1_sha256' if changed
                                        else 'retained_container_size_sha1_identical')}
        spec = {'container': row['container'], 'sha256': container_hash, 'bytes': 128,
                'original_container_identity_verified': True, 'index_exactly_consumed': True,
                'errors': 0, 'identity_basis': {'retained_prior_catalog_container_identity': not changed,
                                               'sha256': container_hash, 'bytes': 128}}
        inherited = {(row['container'], row['path']): dict(row, historical_card_pack_lineage=False)}
        changed_specs = {row['container']: {'sha256': container_hash, 'bytes': 128}} if changed else {}
        return row, spec, inherited, changed_specs

    def test_literal_relative_paths_reject_unsafe_or_normalized_aliases(self):
        self.assertEqual(BUILDER.safe_relative('fixture/opaque.bin'), 'fixture/opaque.bin')
        for path in ['', '../escape', '/absolute', 'fixture/../escape',
                     'fixture/./opaque.bin', 'fixture//opaque.bin', 'fixture\\opaque.bin',
                     'user://opaque.bin', 'C:/opaque.bin', 'fixture/\x00opaque.bin']:
            with self.subTest(path=repr(path)), self.assertRaises(ValueError):
                BUILDER.safe_relative(path)

    def test_duplicate_logical_paths_never_select_a_last_member(self):
        record = {'path': 'fixture/opaque.bin'}
        with self.assertRaises(ValueError):
            BUILDER.unique_members([record, dict(record)])

    def test_casefold_path_conflict_is_rejected_without_case_fallback(self):
        with self.assertRaises(ValueError):
            BUILDER.unique_members([{'path': 'fixture/opaque.bin'}, {'path': 'Fixture/OPAQUE.bin'}])

    def test_original_opaque_file_bytes_are_rechecked_even_at_same_size(self):
        path = self.root / 'opaque.bin'
        original = b'opaque original bytes, not an image'
        path.write_bytes(original)
        self.assertEqual(BUILDER.verify_file(path, len(original), sha(original)), original)
        path.write_bytes(b'X' + original[1:])
        with self.assertRaises(ValueError):
            BUILDER.verify_file(path, len(original), sha(original))

    def test_file_size_and_absence_are_separate_integrity_failures(self):
        path = self.root / 'opaque.bin'
        original = b'opaque payload'
        path.write_bytes(original)
        with self.assertRaises(ValueError):
            BUILDER.verify_file(path, len(original) + 1, sha(original))
        path.unlink()
        with self.assertRaises((ValueError, FileNotFoundError)):
            BUILDER.verify_file(path, len(original), sha(original))

    def test_source_table_requires_exact_pinned_index_bytes(self):
        rows, raw, index = self.table_fixture()
        self.assertEqual(BUILDER.validate_table('AssetView', raw, index), rows)
        altered = raw.replace(b'opaque.bin', b'altered.bin')
        with self.assertRaises(ValueError):
            BUILDER.validate_table('AssetView', altered, index)

    def test_old_or_unverified_source_index_cannot_assert_current_identity(self):
        _, raw, index = self.table_fixture()
        for field, value in [('version', 508), ('status', 'unverified'),
                             ('member_crc_verified', False), ('row_count', 2)]:
            changed = copy.deepcopy(index)
            changed[0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                BUILDER.validate_table('AssetView', raw, changed)

    def test_ambiguous_source_index_entry_is_rejected(self):
        _, raw, index = self.table_fixture()
        with self.assertRaises(ValueError):
            BUILDER.validate_table('AssetView', raw, index + copy.deepcopy(index))

    def test_asset_binding_uses_exact_literal_typed_path(self):
        assets = [{'AssetId': 17, 'AssetTypeId': 3, 'FilePath': 'opaque.bin'}]
        types = [{'ID': 3, 'Path': 'fixture/image/'}]
        unrelated = {'fixture/image/OPAQUE.bin': {'member_index': 0}}
        result = BUILDER.compile_assets(assets, types, unrelated)
        self.assertEqual(result[0]['path'], 'fixture/image/opaque.bin')
        self.assertEqual(result[0]['status'], 'missing_current_member')
        self.assertNotIn('member_index', result[0])

    def test_zero_csb_and_other_types_remain_explicit_unresolved_routes(self):
        types = [{'ID': 1, 'Path': 'fixture/icon/'}, {'ID': 101, 'Path': 'fixture/csb/'},
                 {'ID': 2, 'Path': 'fixture/other/'}]
        assets = [{'AssetId': 0, 'AssetTypeId': 1, 'FilePath': ''},
                  {'AssetId': 17, 'AssetTypeId': 101, 'FilePath': 'opaque.bin'},
                  {'AssetId': 18, 'AssetTypeId': 2, 'FilePath': 'opaque.bin'}]
        result = BUILDER.compile_assets(assets, types, {})
        self.assertEqual([r['status'] for r in result],
                         ['zero_sentinel', 'unsupported_csb', 'unsupported_asset_type'])
        self.assertEqual(result[1]['path'], 'fixture/csb/opaque.bin')
        self.assertTrue(all('member_index' not in r for r in result))

    def test_duplicate_asset_or_type_identity_is_rejected(self):
        assets = [{'AssetId': 17, 'AssetTypeId': 3, 'FilePath': 'opaque.bin'}]
        types = [{'ID': 3, 'Path': 'fixture/image/'}]
        with self.assertRaises(ValueError):
            BUILDER.compile_assets(assets + copy.deepcopy(assets), types, {})
        with self.assertRaises(ValueError):
            BUILDER.compile_assets(assets, types + copy.deepcopy(types), {})

    def test_asset_cannot_escape_its_declared_type_prefix(self):
        assets = [{'AssetId': 17, 'AssetTypeId': 3, 'FilePath': '../opaque.bin'}]
        with self.assertRaises(ValueError):
            BUILDER.compile_assets(assets, [{'ID': 3, 'Path': 'fixture/image/'}], {})

    def test_changed_container_rejects_matching_old_record_and_old_dat(self):
        row, spec, retained, changed = self.member_fixture(changed=True)
        self.assertEqual(BUILDER.validate_member_record(row, spec, retained, changed), row)
        old_hash = sha(b'opaque stale prior DAT identity')
        row['original_container_sha256'] = spec['sha256'] = old_hash
        with self.assertRaises(ValueError):
            BUILDER.validate_member_record(row, spec, retained, changed)

    def test_changed_container_cannot_relabel_itself_as_retained(self):
        row, spec, retained, changed = self.member_fixture(changed=True)
        row['current523_component'] = 'retained_noncard_lineage14964'
        row['retained_prior_catalog_all_fields_verified'] = True
        spec['identity_basis']['retained_prior_catalog_container_identity'] = True
        with self.assertRaises(ValueError):
            BUILDER.validate_member_record(row, spec, retained, changed)

    def test_retained_whole_dat_metadata_hash_and_size_must_match(self):
        row, spec, retained, changed = self.member_fixture()
        self.assertEqual(BUILDER.validate_member_record(row, spec, retained, changed), row)
        for field, value in [('sha256', sha(b'opaque different metadata DAT')), ('bytes', 129)]:
            altered = copy.deepcopy(spec)
            altered['identity_basis'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                BUILDER.validate_member_record(row, altered, retained, changed)

    def test_retained_member_fields_and_identity_proofs_are_not_optional(self):
        row, spec, retained, changed = self.member_fixture()
        tampered = dict(row, plain_bytes=row['plain_bytes'] + 1)
        with self.assertRaises(ValueError):
            BUILDER.validate_member_record(tampered, spec, retained, changed)
        unverified = dict(row, retained_prior_catalog_all_fields_verified=False)
        with self.assertRaises(ValueError):
            BUILDER.validate_member_record(unverified, spec, retained, changed)

    def client_member_fixture(self):
        row, spec, _, _ = self.member_fixture()
        sha1 = hashlib.sha1(b'opaque client DAT').hexdigest()
        row = dict(row, current523_component=BUILDER.CLIENT_COMPONENT,
                    current523_alignment=BUILDER.CLIENT_ALIGNMENT,
                    retained_prior_catalog_all_fields_verified=False)
        spec = dict(spec, sha1=sha1, identity_basis={'sha256': spec['sha256'], 'bytes': spec['bytes'], 'sha1': sha1,
                                                     'current523_alignment': BUILDER.CLIENT_ALIGNMENT})
        return row, spec

    def test_client_files_info_member_needs_exact_container_identity(self):
        row, spec = self.client_member_fixture()
        self.assertEqual(BUILDER.validate_member_record(row, spec, {}, {}), row)
        for change in ({'sha1': '0' * 40}, {'current523_alignment': 'retained_container_size_sha1_identical'}):
            altered = copy.deepcopy(spec)
            altered['identity_basis'].update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                BUILDER.validate_member_record(row, altered, {}, {})
        with self.assertRaises(ValueError):
            BUILDER.validate_member_record(dict(row, current523_alignment='other'), spec, {}, {})

    def test_client_member_cannot_mix_with_handoff_identities(self):
        row, spec = self.client_member_fixture()
        with self.assertRaises(ValueError):
            BUILDER.validate_member_record(row, spec, {(row['container'], row['path']): row}, {})
        with self.assertRaises(ValueError):
            BUILDER.validate_member_record(row, spec, {}, {row['container']: {'sha256': spec['sha256'], 'bytes': 128}})

    def test_bool_is_not_a_member_byte_count(self):
        row, spec, retained, changed = self.member_fixture()
        row['plain_bytes'] = True
        with self.assertRaises(ValueError):
            BUILDER.validate_member_record(row, spec, retained, changed)

    def test_output_cannot_overwrite_existing_or_private_inputs(self):
        protected = self.root / 'private-input'
        protected.mkdir()
        existing = self.root / 'existing-output'
        existing.mkdir()
        for output in [protected / 'output', existing]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                BUILDER.validate_output_destination(output, [protected], SCRIPT)

    def test_public_project_output_is_rejected_before_creation(self):
        project = self.root / 'public-project'
        project.mkdir()
        (project / 'project.godot').write_text('; structural marker only\n')
        script = project / 'tools/images/build_source523_image_pack.py'
        output = project / 'private-output'
        with self.assertRaises(ValueError):
            BUILDER.validate_output_destination(output, [], script)
        self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
