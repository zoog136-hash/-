#!/usr/bin/env python3
"""Prove a local composite-action extraction preserves effective CI contracts.

Usage: python3 tools/ci/validate_workflow_refactor.py --baseline-ref <commit>
Requires PyYAML and the baseline git commit locally. Does not execute CI.
"""
import argparse
import copy
import pathlib
import subprocess
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]


def expand(document, action_loader):
    document = copy.deepcopy(document)
    for job in document['jobs'].values():
        expanded = []
        for step in job.get('steps', []):
            if step.get('uses', '').startswith('./.github/actions/'):
                assert set(step) <= {'name', 'uses'}, 'Conditional/parameterized action requires explicit validation'
                action = action_loader(step['uses'])
                assert action['runs']['using'] == 'composite'
                if step['uses'] == './.github/actions/setup-godot-linux':
                    body = {'run': validate_cached_setup_action(action)}
                else:
                    assert len(action['runs']['steps']) == 1
                    body = copy.deepcopy(action['runs']['steps'][0])
                    assert set(body) == {'shell', 'run'} and body['shell'] == 'bash'
                    body.pop('shell')
                if 'name' in step:
                    body['name'] = step['name']
                expanded.append(body)
            else:
                expanded.append(step)
        job['steps'] = expanded
    return document


STALE_WORKFLOWS = {
    '.github/workflows/main-debug-audit.yml',
    '.github/workflows/twilight-shop-buyback.yml',
    '.github/workflows/twilight-npc-teleport.yml',
    '.github/workflows/skill-mechanism-validate.yml',
    '.github/workflows/twilight-crafting-validate.yml',
}
STALE_POLICY = "${{ github.event_name == 'pull_request' && github.event.pull_request.number != 157 && github.event.pull_request.number != 158 }}"
NEW_WORKFLOW = '.github/workflows/cancel-superseded-pr-ci.yml'


def assert_preserved_workflow(path, before, after, action_loader):
    expanded = expand(after, action_loader)
    expanded = normalize_shared_import_cache_reader(path, expanded)
    expanded = normalize_phase3_services(path, before, expanded)
    if path in STALE_WORKFLOWS:
        original = before['concurrency']
        assert original['cancel-in-progress'] is False, path
        expected = copy.deepcopy(original)
        expected['cancel-in-progress'] = STALE_POLICY
        assert expanded['concurrency'] == expected, path + ': unexpected change'
        expanded['concurrency'] = original
    expanded = normalize_cached_direct(path, before, expanded)
    assert expanded == before, path + ': effective workflow contract changed'



# Phase 3: only five proven subset service jobs are suppressed on ordinary PRs.
# Buyback remains the automatic superset test for every original target base.
PHASE3_SUBSET_JOBS = {
    '.github/workflows/twilight-shop-authority.yml': 'shop-authority',
    '.github/workflows/twilight-warehouse-validate.yml': 'local-warehouse',
    '.github/workflows/twilight-npc-teleport.yml': 'npc-transit',
    '.github/workflows/twilight-local-crafting.yml': 'crafting',
    '.github/workflows/twilight-npc-dialogue.yml': 'npc-dialogue',
}
PHASE3_MANUAL_OR_PROTECTED = "${{ github.event_name != 'pull_request' || github.event.pull_request.number == 157 || github.event.pull_request.number == 158 }}"
PHASE3_BUYBACK = '.github/workflows/twilight-shop-buyback.yml'
PHASE3_EXTRA_BASES = (
    'feature/twilight-shop-authoritative-transactions-20261010',
    'feature/twilight-warehouse-persistent-instances-20261010',
    'feature/twilight-npc-teleport-20261010',
    'feature/twilight-shop-buyback-20261010',
)
PHASE3_COVERED_TESTS = (
    'tests/npc_dialogue_branching_test.gd', 'tests/shop_buyback_test.gd', 'tests/local_crafting_test.gd',
    'tests/npc_teleport_test.gd', 'tests/warehouse_persistence_test.gd',
    'tests/shop_authority_test.gd',
)
PHASE3_COVERED_MARKERS = (
    'BUYBACK_OK', 'NPC_DIALOGUE_OK', 'CRAFT_OK', 'NPC_TELEPORT_OK', 'WAREHOUSE_OK',
    'SHOP_AUTHORITY_OK',
)


def normalize_phase3_services(path, before, expanded):
    if path not in PHASE3_SUBSET_JOBS and path != PHASE3_BUYBACK:
        return expanded
    result = copy.deepcopy(expanded)
    if path in PHASE3_SUBSET_JOBS:
        job = PHASE3_SUBSET_JOBS[path]
        assert list(result['jobs']) == [job], path + ': job identity changed'
        assert 'if' not in before['jobs'][job], path + ': baseline already had a gate'
        assert result['jobs'][job].pop('if', None) == PHASE3_MANUAL_OR_PROTECTED, (
            path + ': missing protected-PR/manual fallback')
    else:
        event_key = 'on' if 'on' in result else True  # PyYAML 1.1 bool coercion
        baseline_key = 'on' if 'on' in before else True
        branches = result[event_key]['pull_request']['branches']
        original_branches = before[baseline_key]['pull_request']['branches']
        required = set(original_branches) | set(PHASE3_EXTRA_BASES)
        assert len(branches) == len(required) and set(branches) == required, (
            path + ': original or historical PR base omitted')
        assert result[event_key]['workflow_dispatch'] == before[baseline_key]['workflow_dispatch'], (
            path + ': manual trigger changed')
        step = [x for x in result['jobs']['item-buyback']['steps']
                if x.get('name') == 'Buyback and earlier stage regression']
        assert len(step) == 1, path + ': canonical test step missing'
        body = step[0].get('run', '')
        original_steps = [x for x in before['jobs']['item-buyback']['steps']
                          if x.get('name') == 'Buyback and earlier stage regression']
        assert len(original_steps) == 1, path + ': original canonical test missing'
        original_body = original_steps[0]['run']
        expected_body = original_body.replace(
            'for test in tests/shop_buyback_test.gd ',
            'for test in tests/npc_dialogue_branching_test.gd tests/shop_buyback_test.gd ')
        expected_body = expected_body.replace(
            'for marker in BUYBACK_OK CRAFT_OK ',
            'for marker in BUYBACK_OK NPC_DIALOGUE_OK CRAFT_OK ')
        assert expected_body != original_body and body == expected_body, (
            path + ': canonical suite must only add NPC dialogue and marker')
        for required_test in PHASE3_COVERED_TESTS:
            assert required_test in body, path + ': missing ' + required_test
        for required_marker in PHASE3_COVERED_MARKERS:
            assert required_marker in body, path + ': missing ' + required_marker
        result[event_key]['pull_request']['branches'] = copy.deepcopy(original_branches)
        step[0]['run'] = original_body
    return result


def assert_new_cleanup(doc):
    assert doc.get('name') == 'Cancel superseded PR CI'
    assert doc.get('on') == {'pull_request_target': {'types': ['synchronize']}}
    assert doc.get('permissions') == {'actions': 'write', 'pull-requests': 'read', 'contents': 'read'}
    jobs = doc.get('jobs', {})
    assert list(jobs) == ['cleanup']
    job = jobs['cleanup']
    assert '157' in str(job.get('if', '')) and '158' in str(job.get('if', ''))
    steps = job.get('steps', [])
    assert len(steps) == 1 and steps[0].get('uses') == 'actions/github-script@v7'
    script = steps[0].get('with', {}).get('script', '')
    for needle in ("run.event !== 'pull_request'", "run.head_sha === head",
                   'run.head_sha !== oldSha', 'getWorkflowRun', 'cancelWorkflowRun',
                   'some(p => p.number === number)', 'isHead(await getPr())'):
        assert needle in script, needle


# Cache only the version-locked Linux binary. Do not restore .godot/imported:
# asset provenance, editor state and large map sources differ between PRs.
ENGINE_PATH = '/tmp/Godot_v4.7.2-stable_linux.x86_64'
ENGINE_KEY = 'twilight-godot-4.7.2-stable-linux-x86_64-engine-v1'
ENGINE_CHECK = "test -x " + ENGINE_PATH + " && " + ENGINE_PATH + " --version | grep -q '^4\\.7\\.2\\.stable'"
ENGINE_VALIDATE = ENGINE_PATH + " --version | grep -q '^4\\.7\\.2\\.stable'"
ENGINE_INSTALL = "curl -L --fail --retry 2 -o /tmp/godot.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip\nunzip -q /tmp/godot.zip -d /tmp\nchmod +x /tmp/Godot_v4.7.2-stable_linux.x86_64\n"
ENGINE_MAIN_INSTALL = "curl -L --fail --retry 3 -o /tmp/godot.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip\nunzip -q /tmp/godot.zip -d /tmp\nchmod +x /tmp/Godot_v4.7.2-stable_linux.x86_64\n"
ENGINE_CACHE_RESTORE = {
    'name': 'Restore pinned Godot engine cache', 'id': 'engine-cache',
    'uses': 'actions/cache/restore@v4', 'continue-on-error': True,
    'with': {'path': ENGINE_PATH, 'key': ENGINE_KEY},
}
ENGINE_CACHE_SAVE = {
    'name': 'Save verified Godot engine cache on trusted main',
    'if': "${{ github.event_name == 'push' && github.ref == 'refs/heads/main' && steps.engine-cache.outputs.cache-hit != 'true' }}",
    'uses': 'actions/cache/save@v4', 'continue-on-error': True,
    'with': {'path': ENGINE_PATH, 'key': ENGINE_KEY},
}


def cached_script(original, *, symlink=False):
    script = ("if ! { " + ENGINE_CHECK + "; }; then\n" +
              "  rm -f " + ENGINE_PATH + "\n" +
              "\n".join("  " + line for line in original.rstrip("\n").split("\n")) +
              "\nfi\n" + ENGINE_VALIDATE + "\n")
    if symlink:
        script += "ln -sf " + ENGINE_PATH + " Godot_v4.7.2-stable_linux.x86_64\n"
    return script


def validate_cached_setup_action(action):
    steps = action['runs']['steps']
    assert len(steps) == 3, 'cached setup step count changed'
    assert steps[0] == {
        'name': 'Restore pinned Godot from default-branch cache',
        'id': 'engine-cache', 'uses': 'actions/cache/restore@v4',
        'continue-on-error': True, 'with': {'path': ENGINE_PATH, 'key': ENGINE_KEY}}
    assert steps[1] == {'shell': 'bash', 'run': cached_script(ENGINE_INSTALL)}
    assert steps[2] == {
        'name': 'Save verified Godot on trusted main push',
        'if': ENGINE_CACHE_SAVE['if'], 'uses': 'actions/cache/save@v4',
        'continue-on-error': True, 'with': {'path': ENGINE_PATH, 'key': ENGINE_KEY}}
    return ENGINE_INSTALL


# Import artifacts from the default-branch-only cache are revalidated by the
# unchanged real --import and full Godot checks. No PR can seed this cache.
IMPORT_CACHE_PATHS = ".godot/imported\n**/*.import\n"
IMPORT_CACHE_KEY = "twilight-godot-import-4.7.2-linux-compat-main-v1"

# Phase 2 only restores immutable, default-branch-produced import artifacts.
# PRs cannot write this cache; every original Godot import/test still runs.
SHARED_IMPORT_READER_STEPS = {
    '.github/workflows/twilight-local-crafting.yml': 'Project asset import and GDScript parse',
    '.github/workflows/twilight-npc-dialogue.yml': 'Import and parse entire project',
    '.github/workflows/twilight-crafting-validate.yml': 'Import project and GDScript',
    '.github/workflows/original-skills-validate.yml': 'Skill behavior and combat regressions',
    '.github/workflows/twilight-integration-validate.yml': 'Full project regression, import, boot and all smoke tests',
    '.github/workflows/twilight-shop-buyback.yml': 'Godot import and parse project',
}
SHARED_IMPORT_READER = {
    'name': 'Restore trusted Godot imported resources',
    'if': "${{ github.event_name != 'pull_request' || (github.event.pull_request.number != 157 && github.event.pull_request.number != 158) }}",
    'id': 'trusted-import-cache',
    'uses': 'actions/cache/restore@v4',
    'continue-on-error': True,
    'with': {'path': IMPORT_CACHE_PATHS, 'key': IMPORT_CACHE_KEY},
}


def normalize_shared_import_cache_reader(path, expanded):
    if path not in SHARED_IMPORT_READER_STEPS:
        return expanded
    result = copy.deepcopy(expanded)
    jobs = result['jobs']
    assert len(jobs) == 1, path + ': unexpectedly changed job count'
    steps = next(iter(jobs.values()))['steps']
    positions = [i for i, step in enumerate(steps)
                 if step.get('id') == 'trusted-import-cache' or
                 step.get('name') == SHARED_IMPORT_READER['name']]
    assert len(positions) == 1, path + ': reader missing or duplicated'
    index = positions[0]
    assert steps[index] == SHARED_IMPORT_READER, path + ': cache reader not read-only/exact'
    checkout = [i for i, step in enumerate(steps) if step.get('uses') == 'actions/checkout@v4']
    checks = [i for i, step in enumerate(steps)
              if step.get('name') == SHARED_IMPORT_READER_STEPS[path]]
    assert len(checkout) >= 1 and len(checks) == 1, path + ': anchor changed'
    assert checkout[0] < index < checks[0], path + ': cache restore must precede full validation'
    steps.pop(index)
    return result

IMPORT_EXTRA_NAMES = (
    "Restore trusted Godot imported resources",
    "Start Godot import timing",
    "Report Godot import time and enforce cache size limit",
    "Save fully validated Godot import cache on trusted main",
)
IMPORT_MAIN_ONLY = "${{ success() && github.event_name == 'push' && github.ref == 'refs/heads/main' && steps.imported-cache.outputs.cache-hit != 'true' && steps.import-metrics.outputs.cacheable == 'true' }}"


def assert_import_cache_contract(steps):
    by_name = {step.get('name'): step for step in steps if step.get('name') in IMPORT_EXTRA_NAMES}
    assert set(by_name) == set(IMPORT_EXTRA_NAMES), 'Missing imported-resource cache step'
    assert by_name[IMPORT_EXTRA_NAMES[0]] == {
        'name': IMPORT_EXTRA_NAMES[0], 'id': 'imported-cache',
        'uses': 'actions/cache/restore@v4', 'continue-on-error': True,
        'with': {'path': IMPORT_CACHE_PATHS, 'key': IMPORT_CACHE_KEY}}
    assert by_name[IMPORT_EXTRA_NAMES[1]] == {
        'name': IMPORT_EXTRA_NAMES[1], 'shell': 'bash',
        'run': 'date +%s > "$RUNNER_TEMP/twilight-import-start"'}
    report = by_name[IMPORT_EXTRA_NAMES[2]]
    assert set(report) == {'name', 'id', 'shell', 'run'}
    assert report['id'] == 'import-metrics' and report['shell'] == 'bash'
    for fragment in (
        'set -euo pipefail', 'TWILIGHT_IMPORT_SECONDS=', 'TWILIGHT_IMPORTED_BYTES=',
        'TWILIGHT_CACHE_RESTORED=', 'du -sb .godot/imported',
        'bytes > 0 && bytes < 1610612736', 'echo "cacheable=false"',
        'echo "cacheable=true"', '>> "$GITHUB_OUTPUT"'):
        assert fragment in report['run'], 'Missing import cache metric/gate: ' + fragment
    assert by_name[IMPORT_EXTRA_NAMES[3]] == {
        'name': IMPORT_EXTRA_NAMES[3], 'if': IMPORT_MAIN_ONLY,
        'uses': 'actions/cache/save@v4', 'continue-on-error': True,
        'with': {'path': IMPORT_CACHE_PATHS, 'key': IMPORT_CACHE_KEY}}
    return [step for step in steps if step.get('name') not in IMPORT_EXTRA_NAMES]


def normalize_cached_direct(path, before, expanded):
    if path not in ('.github/workflows/godot-validate.yml',
                    '.github/workflows/twilight-integration-validate.yml'):
        return expanded
    before_jobs = list(before['jobs'])
    assert len(before_jobs) == 1
    original_steps = before['jobs'][before_jobs[0]]['steps']
    current_steps = expanded['jobs'][before_jobs[0]]['steps']
    expected = copy.deepcopy(original_steps)
    if path.endswith('godot-validate.yml'):
        current_steps = assert_import_cache_contract(current_steps)
    if path.endswith('godot-validate.yml'):
        name = 'Install Godot 4.7.2'
        old = ("curl -L --fail --retry 3 -o godot.zip https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip\n"
               "unzip -q godot.zip\nchmod +x Godot_v4.7.2-stable_linux.x86_64\n")
        updated = "set -euo pipefail\n" + cached_script(ENGINE_MAIN_INSTALL, symlink=True)
    else:
        name = 'Install Godot 4.7.2 and software GL'
        old = ENGINE_MAIN_INSTALL
        updated = cached_script(ENGINE_MAIN_INSTALL)
    matches = [i for i, step in enumerate(expected) if step.get('name') == name]
    assert len(matches) == 1
    index = matches[0]
    assert expected[index]['run'].count(old) == 1, path + ': no exact source installer'
    expected[index]['run'] = expected[index]['run'].replace(old, updated)
    expected[index:index] = [copy.deepcopy(ENGINE_CACHE_RESTORE)]
    expected.insert(index + 2, copy.deepcopy(ENGINE_CACHE_SAVE))
    assert current_steps == expected, path + ': cache may not change existing tests'
    restored = copy.deepcopy(expanded)
    restored['jobs'][before_jobs[0]]['steps'] = original_steps
    return restored


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-ref', required=True)
    args = parser.parse_args()
    files = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', args.baseline_ref, '.github/workflows'], cwd=ROOT, text=True).splitlines()
    current = sorted(str(p.relative_to(ROOT)) for p in (ROOT / '.github/workflows').glob('*.yml'))
    assert set(current) == set(files) | {NEW_WORKFLOW}, 'Unexpected workflow additions/removals'
    def load_action(path):
        return yaml.safe_load((ROOT / path / 'action.yml').read_text())
    for file in files:
        before = yaml.safe_load(subprocess.check_output(['git', 'show', args.baseline_ref + ':' + file], cwd=ROOT, text=True))
        after = yaml.safe_load((ROOT / file).read_text())
        assert_preserved_workflow(file, before, after, load_action)
    assert_new_cleanup(yaml.safe_load((ROOT / NEW_WORKFLOW).read_text()))
    print(f'PASS: {len(files)} original contracts retained (5 explicit concurrency changes) + guarded stale PR cleaner')


if __name__ == '__main__':
    main()
