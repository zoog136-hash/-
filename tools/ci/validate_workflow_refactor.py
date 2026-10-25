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
    if path in STALE_WORKFLOWS:
        original = before['concurrency']
        assert original['cancel-in-progress'] is False, path
        expected = copy.deepcopy(original)
        expected['cancel-in-progress'] = STALE_POLICY
        assert expanded['concurrency'] == expected, path + ': unexpected change'
        expanded['concurrency'] = original
    assert expanded == before, path + ': effective workflow contract changed'


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
