"""Privacy and identity checks; synthetic bytes are never original-art evidence."""
import hashlib
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest import mock
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools' / 'lineagem_original'))
import reference_sp2_inventory as ledger


class ReferenceSP2InventoryTests(unittest.TestCase):
    def test_repository_output_rejected_before_metadata_is_read(self):
        repository = Path(__file__).resolve().parents[1]
        output = repository / 'private-ledger-security-test'
        with mock.patch.object(ledger, 'verify_manifest', side_effect=AssertionError('metadata read')):
            with self.assertRaisesRegex(ValueError, 'outside the repository'):
                ledger.build(Path('/missing-metadata'), Path('/missing-supplemental'), output)
        self.assertFalse(output.exists())

    def test_private_copy_also_rejects_game_repository_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repository = root / 'game'
            repository.mkdir()
            (repository / 'project.godot').write_text('; synthetic game marker\n')
            module = root / 'private' / 'implementation' / 'reference_sp2_inventory.py'
            with mock.patch.object(ledger, '__file__', str(module)):
                with self.assertRaisesRegex(ValueError, 'outside the repository'):
                    ledger.private_output_path(repository / 'output')
            self.assertFalse((repository / 'output').exists())

    def test_scaffold_git_directory_does_not_reject_private_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / '.git').mkdir()
            module = root / 'private' / 'implementation' / 'reference_sp2_inventory.py'
            output = root / 'private' / 'results'
            with mock.patch.object(ledger, '__file__', str(module)):
                self.assertEqual(ledger.private_output_path(output), output)
            self.assertFalse(output.exists())

    def test_output_directory_and_artifacts_are_owner_only(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'output'
            output.mkdir(mode=0o755)
            ledger.prepare_private_output(output)
            self.assertEqual(stat.S_IMODE(output.stat().st_mode), 0o700)
            ledger.write_json(output / 'summary.json', {'synthetic': True})
            ledger.write_jsonl(output / 'rows.jsonl.gz', [{'synthetic': True}])
            for name in ('summary.json', 'rows.jsonl.gz'):
                self.assertEqual(stat.S_IMODE((output / name).stat().st_mode), 0o600)
            self.assertEqual(list(ledger.rows(output / 'rows.jsonl.gz')), [{'synthetic': True}])
            before = (output / 'summary.json').read_bytes()
            with self.assertRaises(FileExistsError):
                ledger.write_json(output / 'summary.json', {'replacement': True})
            self.assertEqual((output / 'summary.json').read_bytes(), before)

    def test_output_symlink_and_symlink_parent_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / 'actual'
            target.mkdir()
            alias = root / 'alias'
            alias.symlink_to(target, target_is_directory=True)
            for output in (alias, alias / 'output'):
                with self.assertRaisesRegex(ValueError, 'symlink'):
                    ledger.prepare_private_output(output)
            self.assertFalse((target / 'output').exists())

    def test_artifact_symlink_cannot_overwrite_its_target(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = ledger.prepare_private_output(root / 'output')
            target = root / 'sentinel'
            target.write_bytes(b'preserve synthetic sentinel')
            artifact = output / 'summary.json'
            artifact.symlink_to(target)
            with self.assertRaises(OSError):
                ledger.write_json(artifact, {'replacement': True})
            self.assertEqual(target.read_bytes(), b'preserve synthetic sentinel')
            self.assertTrue(artifact.is_symlink())
            artifact.unlink()
            artifact.symlink_to(root / 'absent')
            with self.assertRaisesRegex(ValueError, 'existing ledger'):
                ledger.prepare_private_output(output)
            self.assertFalse((root / 'absent').exists())

    def test_unsafe_member_paths_are_rejected(self):
        for member in (None, '/Sprite/1.sp2', '../Sprite/1.sp2', 'Sprite/../1.sp2',
                       'Sprite\\1.sp2', 'Sprite//1.sp2', 'Sprite/./1.sp2',
                       'Sprite/1.sp2/other', 'Sprite/\x00.sp2'):
            with self.subTest(member=member), self.assertRaises(ValueError):
                ledger.safe_member(member)

    def test_original_size_crc_and_sha_are_separate_guards(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            member = 'Sprite/1.sp2'
            path = root / member
            path.parent.mkdir()
            body = b'synthetic identity bytes; not original pixels'
            path.write_bytes(body)
            row = {'member': member, 'bytes': len(body),
                   'crc32': f'{zlib.crc32(body) & 0xffffffff:08x}',
                   'original_member_sha256_evidence': {'sha256': hashlib.sha256(body).hexdigest()}}
            self.assertEqual(ledger.inspect_original(row, [root])['status'], 'verified_local_original')
            for changed in (dict(row, bytes=len(body) + 1), dict(row, crc32='00000000'),
                            dict(row, original_member_sha256_evidence={'sha256': '0' * 64})):
                with self.subTest(changed=changed):
                    observed = ledger.inspect_original(changed, [root])
                    self.assertEqual(observed['status'], 'original_bytes_unavailable')
                    self.assertFalse(observed['matches'])
                    self.assertTrue(observed['rejected'])


if __name__ == '__main__':
    unittest.main()
