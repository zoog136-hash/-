"""Guard against hiding changed CI coverage behind a shared setup action."""
import copy
import unittest
from validate_workflow_refactor import expand, assert_preserved_workflow, STALE_POLICY, assert_new_cleanup, IMPORT_EXTRA_NAMES, IMPORT_MAIN_ONLY, IMPORT_CACHE_KEY, IMPORT_CACHE_PATHS, cached_script, ENGINE_INSTALL, ENGINE_MAIN_INSTALL, ENGINE_CHECK, validate_cached_setup_action, normalize_cached_direct, ENGINE_CACHE_RESTORE, ENGINE_CACHE_SAVE, SHARED_IMPORT_READER_STEPS, SHARED_IMPORT_READER, normalize_shared_import_cache_reader


class RefactorContractTest(unittest.TestCase):
    def setUp(self):
        self.action = {'runs': {'using': 'composite', 'steps': [{'shell': 'bash', 'run': 'curl --fail pinned.zip\n'}]}}
        self.before = {'name': 'stable check', 'on': {'pull_request': None}, 'jobs': {'regression': {'runs-on': 'ubuntu-latest', 'steps': [{'name': 'engine', 'run': 'curl --fail pinned.zip\n'}, {'run': 'run-test && grep -q EXPECTED evidence.log\n'}]}}}
        self.after = copy.deepcopy(self.before)
        self.after['jobs']['regression']['steps'][0] = {'name': 'engine', 'uses': './.github/actions/setup'}

    def test_exact_expansion(self):
        self.assertEqual(self.before, expand(self.after, lambda _: self.action))

    def test_changed_install_command_is_visible(self):
        self.action['runs']['steps'][0]['run'] = 'true\n'
        self.assertNotEqual(self.before, expand(self.after, lambda _: self.action))

    def test_assertion_and_check_name_and_filter_changes_are_visible(self):
        for kind in ('assertion', 'name', 'filter'):
            with self.subTest(kind=kind):
                changed = copy.deepcopy(self.after)
                if kind == 'assertion':
                    changed['jobs']['regression']['steps'][1]['run'] = 'run-test\n'
                elif kind == 'name':
                    changed['jobs']['other'] = changed['jobs'].pop('regression')
                else:
                    changed['on']['pull_request'] = {'paths': ['docs/**']}
                self.assertNotEqual(self.before, expand(changed, lambda _: self.action))

    def test_conditional_or_parameterized_extraction_is_rejected(self):
        for key in ('if', 'with', 'env', 'continue-on-error'):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.after)
                changed['jobs']['regression']['steps'][0][key] = 'unexpected'
                with self.assertRaises(AssertionError):
                    expand(changed, lambda _: self.action)

    def test_multi_step_action_is_rejected(self):
        self.action['runs']['steps'].append({'shell': 'bash', 'run': 'unexpected'})
        with self.assertRaises(AssertionError):
            expand(self.after, lambda _: self.action)


class SupersededCIContractTest(unittest.TestCase):
    def test_only_allowlisted_pr_cancel_field_can_change(self):
        name = '.github/workflows/twilight-shop-buyback.yml'
        before = {'concurrency': {'group': 'one-pr', 'cancel-in-progress': False},
                  'jobs': {'check': {'steps': [{'run': 'run-tests'}]}}}
        after = copy.deepcopy(before)
        after['concurrency']['cancel-in-progress'] = STALE_POLICY
        assert_preserved_workflow(name, before, after, lambda _: None)
        for modification in ('command', 'global_cancel', 'group'):
            changed = copy.deepcopy(after)
            if modification == 'command':
                changed['jobs']['check']['steps'][0]['run'] = 'true'
            if modification == 'global_cancel':
                changed['concurrency']['cancel-in-progress'] = True
            if modification == 'group':
                changed['concurrency']['group'] = 'all-prs'
            with self.subTest(modification=modification), self.assertRaises(AssertionError):
                assert_preserved_workflow(name, before, changed, lambda _: None)

    def test_other_workflow_cannot_change_concurrency(self):
        name = '.github/workflows/resource-integrity.yml'
        before = {'concurrency': {'cancel-in-progress': False}, 'jobs': {}}
        after = copy.deepcopy(before)
        after['concurrency']['cancel-in-progress'] = STALE_POLICY
        with self.assertRaises(AssertionError):
            assert_preserved_workflow(name, before, after, lambda _: None)


class GodotCacheContracts(unittest.TestCase):
    def test_exact_cache_fallback_preserves_original_installer(self):
        script = cached_script(ENGINE_INSTALL)
        self.assertIn(ENGINE_CHECK, script)
        self.assertIn(ENGINE_INSTALL.rstrip('\n').split('\n')[0], script)
        self.assertIn('rm -f /tmp/Godot_v4.7.2-stable_linux.x86_64', script)
        self.assertNotIn('.godot/imported', script)

    def test_cache_save_requires_trusted_main(self):
        self.assertIn("github.event_name == 'push'", ENGINE_CACHE_SAVE['if'])
        self.assertIn("github.ref == 'refs/heads/main'", ENGINE_CACHE_SAVE['if'])
        self.assertNotIn('restore-keys', ENGINE_CACHE_RESTORE['with'])

    def test_validation_rejects_runtime_change(self):
        before = {'jobs': {'validate': {'steps': [
            {'name': 'Install Godot 4.7.2', 'run':
             'curl -L --fail --retry 3 -o godot.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip\n'
             'unzip -q godot.zip\nchmod +x Godot_v4.7.2-stable_linux.x86_64\n'
             './Godot_v4.7.2-stable_linux.x86_64 --version\n'},
            {'name': 'Run tests', 'run': 'must-pass\n'}]}}}
        after = copy.deepcopy(before)
        after['jobs']['validate']['steps'][0]['run'] = after['jobs']['validate']['steps'][0]['run'].replace(
            'curl -L --fail --retry 3 -o godot.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip\n'
            'unzip -q godot.zip\nchmod +x Godot_v4.7.2-stable_linux.x86_64\n',
            "set -euo pipefail\n" + cached_script(ENGINE_MAIN_INSTALL, symlink=True))
        after['jobs']['validate']['steps'].insert(0, copy.deepcopy(ENGINE_CACHE_RESTORE))
        after['jobs']['validate']['steps'].insert(2, copy.deepcopy(ENGINE_CACHE_SAVE))
        self.assertEqual(normalize_cached_direct('.github/workflows/godot-validate.yml', before, after), before)
        after['jobs']['validate']['steps'][-1]['run'] = 'skip-all-tests\n'
        with self.assertRaises(AssertionError):
            normalize_cached_direct('.github/workflows/godot-validate.yml', before, after)



class ImportCacheSafetyContract(unittest.TestCase):
    def test_default_branch_is_the_only_writer(self):
        self.assertIn("github.ref == 'refs/heads/main'", IMPORT_MAIN_ONLY)
        self.assertIn("github.event_name == 'push'", IMPORT_MAIN_ONLY)
        self.assertIn("success()", IMPORT_MAIN_ONLY)
        self.assertIn("steps.import-metrics.outputs.cacheable == 'true'", IMPORT_MAIN_ONLY)
        self.assertIn("steps.imported-cache.outputs.cache-hit != 'true'", IMPORT_MAIN_ONLY)

    def test_import_cache_excludes_gameplay_and_secrets(self):
        self.assertIn(".godot/imported", IMPORT_CACHE_PATHS)
        self.assertIn("**/*.import", IMPORT_CACHE_PATHS)
        for banned in ("docs/", "assets/maps", "data/maps", "editor_data",
                       "secrets", "android/", ".git"):
            self.assertNotIn(banned, IMPORT_CACHE_PATHS)
        self.assertTrue(IMPORT_CACHE_KEY.startswith('twilight-godot-import-4.7.2'))

    def test_existing_check_names_are_preserved(self):
        self.assertEqual(len(IMPORT_EXTRA_NAMES), 4)
        self.assertNotIn("Import and parse project", IMPORT_EXTRA_NAMES)
        self.assertNotIn("Boot main scene", IMPORT_EXTRA_NAMES)



class PhaseTwoImportReaderContract(unittest.TestCase):
    def test_each_reader_is_exactly_read_only_and_before_real_tests(self):
        self.assertEqual(SHARED_IMPORT_READER['uses'], 'actions/cache/restore@v4')
        self.assertIn('github.event.pull_request.number != 157', SHARED_IMPORT_READER['if'])
        self.assertIn('github.event.pull_request.number != 158', SHARED_IMPORT_READER['if'])
        self.assertEqual(SHARED_IMPORT_READER['with']['key'], IMPORT_CACHE_KEY)
        self.assertEqual(SHARED_IMPORT_READER['with']['path'], IMPORT_CACHE_PATHS)
        self.assertTrue(SHARED_IMPORT_READER['continue-on-error'])
        for path, named_step in SHARED_IMPORT_READER_STEPS.items():
            with self.subTest(path=path):
                before = {'jobs': {'ci': {'steps': [
                    {'uses': 'actions/checkout@v4'},
                    {'name': named_step, 'run': 'run-all-original-checks'},
                ]}}}
                after = copy.deepcopy(before)
                after['jobs']['ci']['steps'].insert(1, copy.deepcopy(SHARED_IMPORT_READER))
                self.assertEqual(normalize_shared_import_cache_reader(path, after), before)
                damaged = copy.deepcopy(after)
                damaged['jobs']['ci']['steps'][1]['with']['key'] += '-untrusted'
                with self.assertRaises(AssertionError):
                    normalize_shared_import_cache_reader(path, damaged)
                moved = copy.deepcopy(after)
                moved['jobs']['ci']['steps'].append(moved['jobs']['ci']['steps'].pop(1))
                with self.assertRaises(AssertionError):
                    normalize_shared_import_cache_reader(path, moved)

    def test_no_existing_check_may_be_removed(self):
        path = '.github/workflows/twilight-local-crafting.yml'
        before = {'jobs': {'ci': {'steps': [
            {'uses': 'actions/checkout@v4'},
            {'name': SHARED_IMPORT_READER_STEPS[path], 'run': 'mandatory-tests'},
        ]}}}
        after = copy.deepcopy(before)
        after['jobs']['ci']['steps'].insert(1, copy.deepcopy(SHARED_IMPORT_READER))
        assert_preserved_workflow(path, before, after, lambda _: None)
        after['jobs']['ci']['steps'][2]['run'] = 'true'
        with self.assertRaises(AssertionError):
            assert_preserved_workflow(path, before, after, lambda _: None)

    def test_unrelated_workflow_cannot_use_reader(self):
        before = {'jobs': {'ci': {'steps': [{'uses': 'actions/checkout@v4'}]}}}
        after = copy.deepcopy(before)
        after['jobs']['ci']['steps'].append(copy.deepcopy(SHARED_IMPORT_READER))
        with self.assertRaises(AssertionError):
            assert_preserved_workflow('.github/workflows/resource-integrity.yml',
                                      before, after, lambda _: None)


if __name__ == '__main__':
    unittest.main()
