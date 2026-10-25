#!/usr/bin/env python3
"""Prove all twelve intentionally invalid source fixtures fail before Godot."""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    base = root / 'docs/remake/evidence/pr122-remaining106'
    fixtures = []
    for folder in ('batch08/negative-source-controls', 'batch09/negative-source-controls',
                   'batch09/negative-run-registration-controls'):
        for path in sorted((base / folder).glob('*.json')):
            if 'prototype_only' in json.loads(path.read_text()):
                fixtures.append(path)
    assert len(fixtures) == 12, 'Every existing and new negative control must be present'
    results = []
    for fixture in fixtures:
        target = output / fixture.stem
        command = [sys.executable, str(root / 'tools/run_pr122_locomotion_source_preview.py'),
                   '--root', str(root), '--godot', str(output / 'ENGINE_MUST_NEVER_EXECUTE'),
                   '--fixture', str(fixture.relative_to(root)), '--output', str(target)]
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=60)
        log = output / (fixture.stem + '.txt')
        log.write_text(result.stdout)
        assert result.returncode != 0 and any(error in result.stdout for error in
                                             ('AssertionError', 'ValueError', 'KeyError')), result.stdout
        assert 'FileNotFoundError' not in result.stdout, 'Invalid fixture reached the engine invocation'
        assert not (target / 'process-result.json').exists()
        results.append(dict(fixture=str(fixture.relative_to(root)), returncode=result.returncode,
                            rejected_before_engine=True, refusal_log=log.name))
    receipt = dict(status='PASS', cases=len(results), controls=results,
                   source_guards_relaxed=False, production_applied=False, completed_added=0)
    (output / 'controls.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print('PR122_SOURCE_NEGATIVE_CONTROLS_PASS', len(results))


if __name__ == '__main__':
    main()
