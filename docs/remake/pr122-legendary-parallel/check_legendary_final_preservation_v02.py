#!/usr/bin/env python3
"""Final scope and protected-original integrity only; no art or corpus review."""
import hashlib
import json
from pathlib import Path
import subprocess

import deliver_legendary_isolation_batches_v01 as D

BASE = '16bb178426134dbc5ffcc32306de0a2509352c8f'
REVIEW_BASE = '6bcd94f5a0868426ac4b5ae0ebffd93916fad1ba'
EXPECTED_NATIVE = {
    'da13e98e7135e215455ab934668cd5d1d7f06d05f553076510f552da7f0f0ba4',
    '01520a092553b0244a582804c1bf064f191d14b555375fe70efff3ce1f1210f7'}


def raw_git(*args):
    return subprocess.check_output(['git', *args], cwd=D.REPO)


def check():
    assert not D.git('status', '--porcelain'), 'Commit prepared artifacts before final integrity evidence'
    head = D.git('rev-parse', 'HEAD')
    changed = D.git('diff', '--name-only', BASE, head).splitlines()
    outside = [name for name in changed if not (name == str(D.LEDGER) or name.startswith(str(D.DOCS) + '/') or name.startswith(str(D.ASSETS) + '/'))]
    assert not outside, outside
    changed_old = D.git('diff', '--name-only', '--diff-filter=MDR', REVIEW_BASE, head).splitlines()
    assert not [name for name in changed_old if name.startswith(str(D.ASSETS) + '/')], 'Existing art/resources must stay immutable'
    protected = []
    for name in ['data/catalog_v19.json', 'docs/remake/evidence/pr122-remaining106/batch17/all498-production-status.json']:
        original = raw_git('show', BASE + ':' + name)
        current = (D.REPO / name).read_bytes()
        assert original == current
        protected.append({'path': name, 'sha256': hashlib.sha256(current).hexdigest(), 'base_bytes_equal': True})
    native = {}
    for path in (D.REPO / D.ASSETS / 'transform_176' / 'draft001').glob('*record*.json'):
        record = D.read(path)
        for source in record.get('source_files', []):
            if source['sha256'] in EXPECTED_NATIVE:
                relative = source['path'].removeprefix('res://')
                assert D.sha((D.REPO / relative).read_bytes()) == source['sha256']
                native[relative] = source['sha256']
    assert set(native.values()) == EXPECTED_NATIVE
    result = subprocess.run(['python3', 'tools/check_resource_integrity.py', '--root', '.'], cwd=D.REPO,
                            text=True, capture_output=True)
    assert result.returncode == 0, result.stdout + result.stderr
    output = {'schema': 'legendary-final-protected-originals-integrity-v2', 'checked_head': head,
              'production_base': BASE, 'review_baseline': REVIEW_BASE, 'allowed_scope_paths': [str(D.ASSETS), str(D.DOCS), str(D.LEDGER)],
              'outside_scope_changes': outside, 'existing_legendary_art_or_resources_mutated': 0,
              'protected_catalog_and_legacy_ledger': protected, 'native_png_sha256': native,
              'mythic_heroic_unique_and_existing_catalog_git_blobs_unchanged': True,
              'resource_integrity_exit_code': result.returncode, 'resource_integrity_output': result.stdout.strip(),
              'new_generation_calls': 0, 'whole_quality_reviews_added': 0, 'final_approved': 0}
    target = D.WORK / D.DOCS / 'final-protected-originals-integrity-v02.json'
    D.write_json(target, output, immutable=True)
    print(json.dumps({'head': head, 'outside_scope_changes': 0, 'native_sha_verified': len(native), 'resource_integrity': 'PASS'}))


if __name__ == '__main__':
    check()
