#!/usr/bin/env python3
"""Deliver only selected ownership execution deltas; normal push is separate."""
import argparse
import copy
from pathlib import Path
import shutil
import subprocess
import os

import deliver_legendary_isolation_batches_v01 as D
import prepare_legendary_ownership_delta_v02 as P


def deliver(batch):
    pending = D.LOGS / f'ownership-delta-batch{batch:03d}-pending-remote.json'
    if pending.exists():
        print(pending.read_text(), flush=True)
        return
    assert not D.git('status', '--porcelain')
    assert D.git('branch', '--show-current') == D.BRANCH
    delta = D.read(D.WORK / P.DELTA)
    group = delta['batches'][batch - 1]
    version = f'ownership-delta-v{batch:02d}'
    manifest_path = D.DOCS / f'ownership-delta-batch{batch:03d}-library-v01.json'
    if not (D.WORK / manifest_path).exists():
        D.run(['python3', str(D.WORK / D.DOCS / 'prepare_legendary_ownership_delta_v02.py'),
               'apply', '--batch', str(batch)], f'ownership-delta-batch{batch:03d}-apply.log')
    manifest = D.read(D.WORK / manifest_path)
    validation_path = D.DOCS / f'ownership-delta-batch{batch:03d}-affected-validation-v01.json'
    if not (D.WORK / validation_path).exists():
        env = dict(os.environ, XDG_DATA_HOME='/workspace/legendary_runtime/data',
                   XDG_CACHE_HOME='/workspace/legendary_runtime/cache', XDG_CONFIG_HOME='/workspace/legendary_runtime/config')
        D.run([D.GODOT, '--headless', '--fixed-fps', '60', '--path', str(D.WORK), '--script',
               'res://' + str(D.DOCS / 'validate_legendary_corrected_dependencies_v01.gd'), '--',
               'res://' + str(manifest_path), 'res://' + str(validation_path)],
              f'ownership-delta-batch{batch:03d}-validation.log', env=env)
    validation = D.read(D.WORK / validation_path)
    assert validation['failures'] == 0 and len(validation['records']) == len(manifest['revisions'])
    paths = {P.DELTA, manifest_path, validation_path}
    for actor in group['actors']:
        folder = D.ASSETS / ('transform_' + actor.split(':')[1]) / 'corrections' / version
        paths.update(path.relative_to(D.WORK) for path in (D.WORK / folder).glob('*') if path.is_file())
    names = ['prepare_legendary_ownership_delta_v02.py', 'deliver_legendary_ownership_delta_v02.py',
             'review_changed_quality_sources_once_v01.py']
    for name in names:
        paths.add(D.DOCS / name)
    for name in ['changed-source-technical-review-v01.json', 'changed-source-technical-index-v01.json',
                 'guard-dependency-followup-selection-v01.json', 'guard-dependency-bindings-v02.json']:
        path = D.DOCS / 'quality-v02' / name
        if (D.WORK / path).exists():
            paths.add(path)
    for path in sorted(paths):
        D.copy_new(path)
    ledger, previous, _ = P.active_library()
    original_counts = copy.deepcopy(ledger['counts'])
    merged = {tuple(entry['slot']): entry for entry in previous['revisions']}
    for entry in manifest['revisions']:
        merged[tuple(entry['slot'])] = entry
    aggregate = copy.deepcopy(previous)
    aggregate['revisions'] = [merged[key] for key in sorted(merged)]
    aggregate['dependency_required_slots'] = [list(slot) for slot in sorted(set(merged))]
    aggregate.setdefault('execution_delta_manifests', []).append({'path': 'res://' + str(manifest_path),
                                                                 'sha256': D.sha((D.WORK / manifest_path).read_bytes())})
    aggregate_path = D.DOCS / f'revision-library-ownership-delta-through-batch{batch:03d}-v01.json'
    D.write_json(D.WORK / aggregate_path, aggregate, immutable=True)
    D.copy_new(aggregate_path)
    corrections = ledger['corrections']
    section = corrections.setdefault('ownership_execution_delta', {
        'selection': 'res://' + str(P.DELTA), 'selection_sha256': D.sha((D.WORK / P.DELTA).read_bytes()),
        'planned_sources': delta['planned_sources'], 'additional_original_safe_sources': delta['additional_original_safe_sources'],
        'targeted_new_safe_sources': delta['targeted_new_safe_sources'], 'batches': []})
    assert all(entry['batch'] != batch for entry in section['batches'])
    success = sum(item['status'] == 'INTEGER_TRANSLATION_PROOF_PASS' for item in manifest['source_outcomes'])
    section['batches'].append({'batch': batch, 'actors': group['actors'], 'isolated_sources': success,
                               'revised_configurations': len(manifest['revisions']), 'manifest': 'res://' + str(manifest_path),
                               'manifest_sha256': D.sha((D.WORK / manifest_path).read_bytes()),
                               'validation': 'res://' + str(validation_path), 'validation_sha256': D.sha((D.WORK / validation_path).read_bytes()),
                               'source_holds': [item for item in manifest['source_outcomes'] if item['status'] != 'INTEGER_TRANSLATION_PROOF_PASS'],
                               'held_dependencies': manifest['held_dependencies']})
    section.update(isolated_sources=sum(item['isolated_sources'] for item in section['batches']),
                   revised_configuration_events=sum(item['revised_configurations'] for item in section['batches']),
                   original_source_mutations=0, newly_authored_poses_added=0, camera_identity_action_approvals_added=0,
                   quality_status='HOLD', final_approved=0)
    corrections.update(active_revision_library='res://' + str(aggregate_path),
                       active_revision_library_sha256=D.sha((D.WORK / aggregate_path).read_bytes()))
    by_slot = {tuple(entry['slot']): entry for entry in manifest['revisions']}
    for actor in ledger['actors']:
        for draft in actor['drafts']:
            slot = (actor['key'], draft['direction'], draft['role'])
            if slot in by_slot:
                draft.setdefault('correction_revisions', []).append(dict(by_slot[slot], kind='ownership_execution_delta',
                                                                         manifest='res://' + str(manifest_path), quality_status='HOLD'))
    assert ledger['counts'] == original_counts
    D.write_json(D.REPO / D.LEDGER, ledger)
    shutil.copyfile(D.REPO / D.LEDGER, D.WORK / D.LEDGER)
    paths.update([aggregate_path, D.LEDGER])
    subprocess.run(['git', 'add', '--', *map(str, sorted(paths))], cwd=D.REPO, check=True)
    staged = D.git('diff', '--cached', '--name-only').splitlines()
    assert all(path == str(D.LEDGER) or path.startswith(str(D.DOCS) + '/') or path.startswith(str(D.ASSETS) + '/') for path in staged)
    subprocess.run(['git', 'diff', '--cached', '--check'], cwd=D.REPO, check=True)
    subprocess.run(['git', 'commit', '-m', f'[skip ci] Repair selected legendary ownership execution delta {batch:03d}'],
                   cwd=D.REPO, check=True, stdout=subprocess.DEVNULL)
    receipt = {'status': 'LOCAL_COMMIT_WAITING_REMOTE', 'kind': 'ownership_execution_delta', 'batch': batch,
               'actors': group['actors'], 'remote_sha': D.git('rev-parse', 'HEAD'), 'batch_sources': success,
               'batch_clips': len(manifest['revisions']), 'cumulative_sources': section['isolated_sources'],
               'cumulative_clip_revision_events': section['revised_configuration_events'], 'final_approved': 0,
               'quality_status': 'HOLD', 'newly_authored_poses_added': 0}
    D.write_json(pending, receipt, immutable=True)
    print(__import__('json').dumps(receipt), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('first', type=int); parser.add_argument('last', type=int)
    args = parser.parse_args()
    count = len(D.read(D.WORK / P.DELTA)['batches'])
    assert 1 <= args.first <= args.last <= count
    for batch in range(args.first, args.last + 1):
        deliver(batch)
