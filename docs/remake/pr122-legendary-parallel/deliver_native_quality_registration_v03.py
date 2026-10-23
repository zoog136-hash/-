#!/usr/bin/env python3
"""Validate and locally commit only newly reviewed native hybrid registrations."""
import argparse
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess

import deliver_legendary_isolation_batches_v01 as D
import prepare_legendary_isolation_v01 as I
import prepare_legendary_ownership_delta_v02 as P


def deliver(version, review_path):
    assert not D.git('status', '--porcelain')
    pending = D.LOGS / f'native-quality-{version}-pending-remote.json'
    assert not pending.exists(), 'Push the existing local commit without regenerating it'
    manifest_path = D.DOCS / f'transform_176-{version}-library.json'
    if not (D.WORK / manifest_path).exists():
        D.run(['python3', str(D.WORK / D.DOCS / 'prepare_native_quality_registration_v03.py'), str(review_path), '--version', version],
              f'native-quality-{version}-prepare.log')
    manifest = D.read(D.WORK / manifest_path)
    validation_path = D.DOCS / f'transform_176-{version}-affected-validation-v01.json'
    if not (D.WORK / validation_path).exists():
        env = dict(os.environ, XDG_DATA_HOME='/workspace/legendary_runtime/data',
                   XDG_CACHE_HOME='/workspace/legendary_runtime/cache', XDG_CONFIG_HOME='/workspace/legendary_runtime/config')
        D.run([D.GODOT, '--headless', '--fixed-fps', '60', '--path', str(D.WORK), '--script',
               I.resource(D.DOCS / 'validate_legendary_corrected_dependencies_v01.gd'), '--',
               I.resource(manifest_path), I.resource(validation_path)], f'native-quality-{version}-validation.log', env=env)
    validation = D.read(D.WORK / validation_path)
    assert validation['failures'] == 0 and len(validation['records']) == len(manifest['revisions'])
    paths = {manifest_path, validation_path, review_path.relative_to(D.WORK)}
    paths.update(path.relative_to(D.WORK) for path in (D.WORK / I.ASSETS / 'transform_176/corrections' / version).glob('*'))
    receipt_path = D.DOCS / 'quality-v03/parent-evidence-remote-saved-61b02feb-v01.json'
    if (D.WORK / receipt_path).exists():
        paths.add(receipt_path)
    for name in ['prepare_native_quality_registration_v03.py', 'deliver_native_quality_registration_v03.py']:
        path = D.DOCS / name
        target = D.REPO / path
        if not target.exists() or target.read_bytes() != (D.WORK / path).read_bytes():
            shutil.copyfile(D.WORK / path, target)
        paths.add(path)
    for path in sorted(paths):
        D.copy_new(path)
    ledger, previous, _ = P.active_library(); counts = copy.deepcopy(ledger['counts'])
    slots = {tuple(entry['slot']): entry for entry in previous['revisions']}
    for entry in manifest['revisions']:
        slots[tuple(entry['slot'])] = entry
    aggregate = copy.deepcopy(previous)
    aggregate['revisions'] = [slots[key] for key in sorted(slots)]
    aggregate['dependency_required_slots'] = [list(slot) for slot in sorted(slots)]
    aggregate_path = D.DOCS / 'quality-v03' / f'revision-library-with-native-{version}.json'
    D.write_json(D.WORK / aggregate_path, aggregate, immutable=True); D.copy_new(aggregate_path); paths.add(aggregate_path)
    correction = ledger['corrections']
    followups = correction.setdefault('new_native_quality_registration', {'versions': [], 'quality_status': 'HOLD', 'final_approved': 0})
    assert not any(entry['version'] == version for entry in followups['versions'])
    followups['versions'].append({'version': version, 'manifest': I.resource(manifest_path),
        'manifest_sha256': I.sha((D.WORK / manifest_path).read_bytes()), 'validation': I.resource(validation_path),
        'validation_sha256': I.sha((D.WORK / validation_path).read_bytes()), 'registered_clips': len(manifest['revisions']),
        'native_frames_preserved_in_scope': manifest['native_frames_in_affected_clips_preserved'],
        'input': I.resource(review_path.relative_to(D.WORK)), 'input_sha256': I.sha(review_path.read_bytes()),
        'camera_HOLD_retained': True, 'new_PNGs': 0})
    correction.update(active_revision_library=I.resource(aggregate_path), active_revision_library_sha256=I.sha((D.WORK / aggregate_path).read_bytes()))
    affected = {tuple(entry['slot']): entry for entry in manifest['revisions']}
    actor = next(actor for actor in ledger['actors'] if actor['key'] == 'transform:176')
    for draft in actor['drafts']:
        key = (actor['key'], draft['direction'], draft['role'])
        if key in affected:
            draft.setdefault('correction_revisions', []).append(dict(affected[key], kind='new_native_quality_registration', quality_status='HOLD'))
    assert counts == ledger['counts']
    D.write_json(D.REPO / D.LEDGER, ledger); shutil.copyfile(D.REPO / D.LEDGER, D.WORK / D.LEDGER); paths.add(D.LEDGER)
    subprocess.run(['git', 'add', '--', *map(str, sorted(paths))], cwd=D.REPO, check=True)
    assert all(path == str(D.LEDGER) or path.startswith(str(D.DOCS) + '/') or path.startswith(str(I.ASSETS) + '/transform_176/corrections/' + version + '/') for path in D.git('diff', '--cached', '--name-only').splitlines())
    subprocess.run(['git', 'diff', '--cached', '--check'], cwd=D.REPO, check=True)
    subprocess.run(['git', 'commit', '-m', f'[skip ci] Register only new native hybrids {version} from reviewed raw scales'], cwd=D.REPO, check=True, stdout=subprocess.DEVNULL)
    receipt = {'status': 'LOCAL_COMMIT_WAITING_REMOTE', 'commit_sha': D.git('rev-parse', 'HEAD'), 'version': version,
               'manifest': I.resource(manifest_path), 'registered_clips': len(manifest['revisions']),
               'native_frames_preserved_in_scope': manifest['native_frames_in_affected_clips_preserved'],
               'old_native_59_PNG_mutations': 0, 'camera_approvals_added': 0, 'final_approved': 0}
    D.write_json(pending, receipt, immutable=True); print(json.dumps(receipt))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('version'); parser.add_argument('input', type=Path)
    args = parser.parse_args(); deliver(args.version, args.input)
