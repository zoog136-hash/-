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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline-ref', required=True)
    args = parser.parse_args()
    files = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', args.baseline_ref, '.github/workflows'], cwd=ROOT, text=True).splitlines()
    current = sorted(str(p.relative_to(ROOT)) for p in (ROOT / '.github/workflows').glob('*.yml'))
    assert sorted(files) == current, 'Workflow added/removed'
    def load_action(path):
        return yaml.safe_load((ROOT / path / 'action.yml').read_text())
    for file in files:
        before = yaml.safe_load(subprocess.check_output(['git', 'show', args.baseline_ref + ':' + file], cwd=ROOT, text=True))
        after = yaml.safe_load((ROOT / file).read_text())
        assert before == expand(after, load_action), file + ': effective workflow contract changed'
    print(f'PASS: {len(files)} effective workflow contracts identical to {args.baseline_ref}')


if __name__ == '__main__':
    main()
