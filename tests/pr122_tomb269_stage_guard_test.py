"""Explicit isolated review must preserve the production importer guard."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core
import stage_pr122_tomb269_review as stage


class Tomb269StageGuardTest(unittest.TestCase):
    def fixture(self, project):
        (project / 'Main.tscn').write_text('[gd_scene format=3]\n')
        (project / 'project.godot').write_text('config_version=5\n')
        (project / 'data').mkdir()
        prior = {'frames_path': 'res://assets/actors/eight_direction/original_based/approved/SpriteFrames.tres',
                 'layout': 'directional8', 'motion_style': 'slash', 'preserve_marker': {'unchanged': True}}
        document = {'schema': 1, 'profiles': {'transform:269': prior, 'transform:393': {'approved': True}}}
        path = project / 'data/combat_animation_profiles.json'
        path.write_text(json.dumps(document))
        target = {'key': 'transform:269', 'name': 'Tomb269',
                  'reference': {'path': 'res://assets/reference.png'},
                  'presentation_to_preserve': {'visual_height': 80}}
        destination = project / 'assets/actors/eight_direction/original_based/tomb_guardian269_source_trial01'
        return path, document, target, destination

    def test_production_importer_still_refuses_authored_profile_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            path, _, target, destination = self.fixture(project)
            before = path.read_bytes()
            with self.assertRaisesRegex(ValueError, 'Existing authored runtime profile differs'):
                core._pose_file_profiles(project, {'transform:269': target}, ['transform:269'],
                                         target, destination, 160, 4, {})
            self.assertEqual(path.read_bytes(), before)
            self.assertFalse(destination.exists())

    def test_review_prepares_only_target_without_writing_or_mutating_prior(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            path, original, target, destination = self.fixture(project)
            before = path.read_bytes()
            snapshot = copy.deepcopy(original)
            result_path, proposed, prior_sha = stage._review_profile(project, target, destination, 160)
            self.assertEqual(result_path, path)
            self.assertEqual(prior_sha, core.sha(path))
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(original, snapshot)
            self.assertEqual([key for key in proposed['profiles']
                              if proposed['profiles'][key] != original['profiles'][key]], ['transform:269'])
            candidate = proposed['profiles']['transform:269']
            self.assertEqual(candidate['prior_visual_profile'], original['profiles']['transform:269'])
            self.assertEqual(candidate['motion_style'], 'slash')
            self.assertEqual(candidate['preserve_marker'], {'unchanged': True})
            self.assertEqual(candidate['pixel_scale'], 0.5)
            self.assertEqual(candidate['frames_path'], 'res://' + (destination / 'SpriteFrames.tres').relative_to(project).as_posix())
            self.assertFalse(destination.exists())

    def test_real_repository_or_git_copy_cannot_receive_review(self):
        with self.assertRaisesRegex(ValueError, 'separate, non-Git'):
            stage._require_isolated_main(ROOT)
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory)
            _, _, target, destination = self.fixture(project)
            (project / '.git').write_text('gitdir: another-worktree')
            with self.assertRaisesRegex(ValueError, 'separate, non-Git'):
                stage._review_profile(project, target, destination, 160)

    def test_symlink_catalog_and_outside_destination_are_rejected(self):
        for condition in ('symlink', 'outside'):
            with self.subTest(condition=condition), tempfile.TemporaryDirectory() as directory:
                project = Path(directory)
                path, _, target, destination = self.fixture(project)
                if condition == 'symlink':
                    preserved = path.with_suffix('.saved')
                    path.rename(preserved)
                    path.symlink_to(preserved)
                else:
                    destination = project.parent / 'outside-trial'
                with self.assertRaises(ValueError):
                    stage._review_profile(project, target, destination, 160)

    def test_ancestor_symlinks_cannot_redirect_review_outside_project(self):
        for condition in ('data', 'destination'):
            with self.subTest(condition=condition), tempfile.TemporaryDirectory() as directory:
                base = Path(directory)
                project = base / 'isolated'
                project.mkdir()
                path, _, target, destination = self.fixture(project)
                before = path.read_bytes()
                external = base / 'preserved-outside'
                if condition == 'data':
                    (project / 'data').rename(external)
                    (project / 'data').symlink_to(external, target_is_directory=True)
                else:
                    external.mkdir()
                    (project / 'assets').symlink_to(external, target_is_directory=True)
                with self.assertRaisesRegex(ValueError, 'inside the isolated|symlink ancestors'):
                    stage._review_profile(project, target, destination, 160)
                self.assertEqual(path.read_bytes(), before)
                self.assertFalse(destination.exists())


if __name__ == '__main__':
    unittest.main()
