#!/usr/bin/env python3
"""Sole-writer delivery of the frozen ownership subset, two actors per batch.

Normal pushes only. Raw PNGs, original resources, approvals and draft counts stay
unchanged. Each saved batch gets a remote-SHA receipt before the next starts.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

REPO = Path('/workspace/legendary_repo')
WORK = Path('/workspace/legendary_work')
DOCS = Path('docs/remake/pr122-legendary-parallel')
ASSETS = Path('assets/actors/eight_direction/legendary_parallel')
LEDGER = Path('data/pr122_legendary_parallel_staging.json')
LOGS = Path('/workspace/legendary_delivery_logs')
BRANCH = 'feature/pr122-legendary-parallel-20261023'
GODOT = '/workspace/legendary_runtime/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def write_json(path, value, *, immutable=False):
    raw = (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb' if immutable else 'wb') as handle:
        handle.write(raw)


def git(*args):
    return subprocess.check_output(['git', *args], cwd=REPO, text=True).strip()


def run(args, log_name, *, env=None):
    path = LOGS / log_name
    assert not path.exists(), 'Preserve the first failure/log; use a new attempt name'
    with path.open('x') as handle:
        result = subprocess.run(args, cwd=REPO, env=env, stdout=handle, stderr=subprocess.STDOUT)
    assert result.returncode == 0, f'Preserved failure at {path}; no automatic repeat'


def copy_new(relative):
    source, target = WORK / relative, REPO / relative
    assert str(relative).startswith((str(DOCS) + '/', str(ASSETS) + '/'))
    assert source.is_file()
    if target.exists():
        assert target.read_bytes() == source.read_bytes(), 'Never overwrite a versioned artifact: ' + str(relative)
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)


def all_manifest_paths(current):
    paths = []
    for batch in range(1, current + 1):
        path = DOCS / f'revision-library-isolation-v{batch:02d}.json'
        if (WORK / path).exists():
            paths.append(path)
    return paths


def adopt_ready_semantic_bundle():
    relative = DOCS / 'transform_176-registration-delivery-bundle-v02.json'
    if not (WORK / relative).exists():
        return set()
    bundle = read(WORK / relative)
    ledger = read(REPO / LEDGER)
    semantic = ledger['corrections'].setdefault('semantic_registration', {})
    if 'transform:176' in semantic:
        return set()
    report = read(WORK / bundle['validation'].removeprefix('res://'))
    assert report['failures_remaining'] == 0 and report['registered_clips'] == 33 and report['native_poses_preserved'] == 59
    manifest = read(WORK / bundle['manifest'].removeprefix('res://'))
    artifacts = {Path(path) for path in bundle['artifacts']} | {relative}
    for path in artifacts:
        copy_new(path)
    previous = read(WORK / ledger['corrections']['active_revision_library'].removeprefix('res://'))
    by_slot = {tuple(entry['slot']): entry for entry in previous['revisions']}
    required = {tuple(slot) for slot in previous['dependency_required_slots']}
    for entry in manifest['revisions']:
        by_slot[tuple(entry['slot'])] = entry
        required.add(tuple(entry['slot']))
    previous['revisions'] = [by_slot[key] for key in sorted(by_slot)]
    previous['dependency_required_slots'] = [list(slot) for slot in sorted(required)]
    active = DOCS / 'revision-library-with-176-registration-v02.json'
    write_json(WORK / active, previous, immutable=True)
    copy_new(active)
    artifacts.add(active)
    ledger['corrections']['active_revision_library'] = 'res://' + str(active)
    ledger['corrections']['active_revision_library_sha256'] = sha((WORK / active).read_bytes())
    semantic['transform:176'] = dict(bundle, status='ENGINE_CHECKED_REGISTRATION_ONLY',
                                      source_cameras='HOLD', final_approved=0)
    by_slot = {tuple(entry['slot']): entry for entry in manifest['revisions']}
    for actor in ledger['actors']:
        if actor['key'] != 'transform:176':
            continue
        for draft in actor['drafts']:
            entry = by_slot[(actor['key'], draft['direction'], draft['role'])]
            draft.setdefault('correction_revisions', []).append(dict(entry, kind='semantic_registration', quality_status='HOLD'))
    write_json(REPO / LEDGER, ledger)
    shutil.copyfile(REPO / LEDGER, WORK / LEDGER)
    return artifacts


def update_ledger(batch, manifest_relative, validation_relative, selection):
    ledger = read(REPO / LEDGER)
    old_counts = copy.deepcopy(ledger['counts'])
    frozen = read(WORK / DOCS / 'whole-review-frozen-v01.json')
    manifests = [(path, read(WORK / path)) for path in all_manifest_paths(batch)]
    aggregate = {'schema': 'legendary-isolation-revision-library-v1', 'baseline_sha': frozen['baseline_sha'],
                 'quality_status': 'HOLD', 'final_approved': 0, 'revisions': [],
                 'dependency_required_slots': [], 'excluded_slots': [], 'source_manifests': []}
    seen = set()
    delivered_sources = 0
    for path, manifest in manifests:
        aggregate['source_manifests'].append({'path': 'res://' + str(path), 'sha256': sha((WORK / path).read_bytes())})
        delivered_sources += sum(outcome['status'] == 'INTEGER_TRANSLATION_PROOF_PASS' for outcome in manifest['source_outcomes'])
        aggregate['dependency_required_slots'] += manifest['dependency_required_slots']
        aggregate['excluded_slots'] += manifest['excluded_slots']
        for entry in manifest['revisions']:
            slot = tuple(entry['slot'])
            assert slot not in seen
            seen.add(slot)
            aggregate['revisions'].append(entry)
    ownership_clip_count = len(aggregate['revisions'])
    # A later ownership batch must retain already delivered quality/semantic
    # overlays. Their immutable PNGs and healthy action middles are reused.
    previous_library = ledger.get('corrections', {}).get('active_revision_library')
    if previous_library:
        previous = read(WORK / previous_library.removeprefix('res://'))
        merged = {tuple(entry['slot']): entry for entry in aggregate['revisions']}
        retained = []
        for entry in previous['revisions']:
            if '/quality-v02/' in entry['record'] or entry.get('registration_status') == 'REVIEWED_ANCHORS_AND_SCALE':
                merged[tuple(entry['slot'])] = entry
                retained.append(entry['slot'])
        aggregate['revisions'] = [merged[key] for key in sorted(merged)]
        aggregate['dependency_required_slots'] = [list(slot) for slot in sorted({tuple(slot) for slot in aggregate['dependency_required_slots']} | {tuple(slot) for slot in retained})]
        aggregate['retained_quality_or_semantic_overlays'] = retained
    aggregate_relative = DOCS / f'revision-library-ownership-through-batch{batch:03d}-v01.json'
    write_json(WORK / aggregate_relative, aggregate, immutable=True)
    corrections = ledger.setdefault('corrections', {})
    corrections.update(review_baseline_sha=frozen['baseline_sha'],
                       frozen_review='res://' + str(DOCS / 'whole-review-frozen-v01.json'),
                       frozen_review_sha256=sha((WORK / DOCS / 'whole-review-frozen-v01.json').read_bytes()),
                       active_revision_library='res://' + str(aggregate_relative),
                       active_revision_library_sha256=sha((WORK / aggregate_relative).read_bytes()),
                       final_approved=0)
    ownership = corrections.setdefault('ownership_isolation', {'batches': []})
    assert all(entry['batch'] != batch for entry in ownership['batches'])
    ownership['batches'].append({'batch': batch, 'actors': selection['actors'],
                               'manifest': 'res://' + str(manifest_relative), 'manifest_sha256': sha((WORK / manifest_relative).read_bytes()),
                               'validation': 'res://' + str(validation_relative), 'validation_sha256': sha((WORK / validation_relative).read_bytes()),
                               'newly_authored_poses_added': 0, 'approvals_added': 0})
    ownership.update(status='DRAFT_REPAIRED_HOLD' if delivered_sources == 622 else 'IN_PROGRESS',
                     planned_sources=622, isolated_sources=delivered_sources,
                     revised_configurations=ownership_clip_count, newly_authored_poses_added=0,
                     original_source_mutations=0, semantic_registration_status='HOLD_REVIEWED_ANCHORS_REQUIRED')
    current = read(WORK / manifest_relative)
    by_slot = {tuple(entry['slot']): entry for entry in current['revisions']}
    for actor in ledger['actors']:
        for draft in actor.get('drafts', []):
            slot = (actor['key'], draft['direction'], draft['role'])
            if slot in by_slot:
                entry = dict(by_slot[slot], kind='ownership_isolation', manifest='res://' + str(manifest_relative), quality_status='HOLD')
                draft.setdefault('correction_revisions', []).append(entry)
    assert ledger['counts'] == old_counts, 'Corrections do not create new poses or final approvals'
    write_json(REPO / LEDGER, ledger)
    shutil.copyfile(REPO / LEDGER, WORK / LEDGER)
    return aggregate_relative, ownership


def deliver(batch, local_only=False):
    receipt_path = LOGS / f'isolation-batch{batch:03d}-delivery.json'
    if receipt_path.exists():
        receipt = read(receipt_path)
        assert receipt['status'] == 'REMOTE_SAVED'
        return receipt
    pending_path = LOGS / f'isolation-batch{batch:03d}-pending-remote.json'
    if pending_path.exists():
        pending = read(pending_path)
        if local_only:
            print(json.dumps(pending, ensure_ascii=False), flush=True)
            return pending
        assert git('rev-parse', 'HEAD') == pending['remote_sha'] and not git('status', '--porcelain')
        env = dict(os.environ, GIT_ASKPASS='/workspace/legendary_runtime/git-askpass.py', GIT_TERMINAL_PROMPT='0')
        remote = subprocess.check_output(['git', 'ls-remote', 'origin', 'refs/heads/' + BRANCH], cwd=REPO, env=env, text=True).split()[0]
        assert remote == pending['remote_sha'], 'Preserved local commit needs normal push; never regenerate or recommit it'
        pending['status'] = 'REMOTE_SAVED'
        write_json(receipt_path, pending, immutable=True)
        print(json.dumps(pending, ensure_ascii=False), flush=True)
        return pending
    assert git('branch', '--show-current') == BRANCH and not git('status', '--porcelain')
    selection_relative = DOCS / f'isolation-selection-batch{batch:03d}-v01.json'
    selection = read(WORK / selection_relative)
    assert 2 <= len(selection['actors']) <= 5
    version = selection['version']
    manifest_relative = DOCS / ('revision-library-' + version + '.json')
    if not (WORK / manifest_relative).exists():
        run(['python3', str(WORK / DOCS / 'prepare_legendary_isolation_v01.py'), '--root', str(REPO),
             '--output-root', str(WORK), '--review', str(WORK / DOCS / 'technical-single-review-v01.json'),
             '--frozen', str(WORK / DOCS / 'whole-review-frozen-v01.json'), '--selection', str(WORK / selection_relative), '--apply'],
            f'isolation-batch{batch:03d}-apply.log')
    manifest = read(WORK / manifest_relative)
    validation_relative = DOCS / f'isolation-batch{batch:03d}-affected-validation-v01.json'
    if not (WORK / validation_relative).exists():
        env = dict(os.environ, XDG_DATA_HOME='/workspace/legendary_runtime/data',
                   XDG_CACHE_HOME='/workspace/legendary_runtime/cache', XDG_CONFIG_HOME='/workspace/legendary_runtime/config')
        run([GODOT, '--headless', '--fixed-fps', '60', '--path', str(WORK), '--script',
             'res://' + str(DOCS / 'validate_legendary_corrected_dependencies_v01.gd'), '--',
             'res://' + str(manifest_relative), 'res://' + str(validation_relative)],
            f'isolation-batch{batch:03d}-affected-validation-v01.log', env=env)
    validation = read(WORK / validation_relative)
    assert validation['failures'] == 0 and len(validation['records']) == len(manifest['revisions'])
    artifact_paths = {selection_relative, manifest_relative, validation_relative}
    for actor in selection['actors']:
        folder = ASSETS / ('transform_' + actor.split(':')[1]) / 'corrections' / version
        artifact_paths.update(path.relative_to(WORK) for path in (WORK / folder).glob('*'))
    for relative in sorted(artifact_paths):
        copy_new(relative)
    for path in (WORK / DOCS).glob('isolation-*-evidence-*.json'):
        relative = path.relative_to(WORK)
        copy_new(relative)
        artifact_paths.add(relative)
    for path in (WORK / DOCS / 'quality-v02').glob('generation-claims/*.json'):
        relative = path.relative_to(WORK)
        copy_new(relative)
        artifact_paths.add(relative)
    for name in ['changed-source-visual-review-v01.json', 'changed-source-visual-review-receipt-v01.json', 'tool-quota-checkpoint-v01.json']:
        relative = DOCS / 'quality-v02' / name
        if (WORK / relative).exists():
            copy_new(relative)
            artifact_paths.add(relative)
    for name in ['prepare_legendary_isolation_v01.py', 'legendary_registered_clip_player_v01.gd',
                 'legendary_revision_library_v01.gd', 'validate_legendary_corrected_dependencies_v01.gd',
                 'deliver_legendary_isolation_batches_v01.py', 'prepare_legendary_registration_v01.py',
                 'check_registered_clip_player_fixture_v01.gd']:
        relative = DOCS / name
        target = REPO / relative
        if not target.exists() or target.read_bytes() != (WORK / relative).read_bytes():
            shutil.copyfile(WORK / relative, target)
        artifact_paths.add(relative)
    artifact_paths.update(adopt_ready_semantic_bundle())
    aggregate_relative, counts = update_ledger(batch, manifest_relative, validation_relative, selection)
    copy_new(aggregate_relative)
    artifact_paths.update([aggregate_relative, LEDGER])
    subprocess.run(['git', 'add', '--', *map(str, sorted(artifact_paths))], cwd=REPO, check=True)
    staged = git('diff', '--cached', '--name-only').splitlines()
    assert all(path == str(LEDGER) or path.startswith(str(DOCS) + '/') or ('/corrections/' in path and path.startswith(str(ASSETS) + '/')) for path in staged)
    subprocess.run(['git', 'diff', '--cached', '--check'], cwd=REPO, check=True)
    subprocess.run(['git', 'commit', '-m', f'[skip ci] Isolate legendary ownership batch {batch:03d} without redrawing poses'], cwd=REPO, check=True, stdout=subprocess.DEVNULL)
    local_sha = git('rev-parse', 'HEAD')
    receipt = {'status': 'LOCAL_COMMIT_WAITING_REMOTE', 'kind': 'ownership_isolation', 'batch': batch,
               'actors': selection['actors'], 'remote_sha': local_sha,
               'batch_sources': sum(x['status'] == 'INTEGER_TRANSLATION_PROOF_PASS' for x in manifest['source_outcomes']),
               'batch_clips': len(manifest['revisions']), 'cumulative_sources': counts['isolated_sources'],
               'cumulative_clips': counts['revised_configurations'], 'newly_authored_poses_added': 0,
               'final_approved': 0, 'quality_status': 'HOLD', 'semantic_scale_registration': 'PENDING_REVIEWED_INPUT'}
    write_json(pending_path, receipt, immutable=True)
    if local_only:
        print(json.dumps(receipt, ensure_ascii=False), flush=True)
        return receipt
    env = dict(os.environ, GIT_ASKPASS='/workspace/legendary_runtime/git-askpass.py', GIT_TERMINAL_PROMPT='0')
    run(['git', 'push', 'origin', 'HEAD:refs/heads/' + BRANCH], f'isolation-batch{batch:03d}-push.log', env=env)
    remote_sha = subprocess.check_output(['git', 'ls-remote', 'origin', 'refs/heads/' + BRANCH], cwd=REPO, env=env, text=True).split()[0]
    assert remote_sha == local_sha and not git('status', '--porcelain')
    receipt['status'] = 'REMOTE_SAVED'
    write_json(receipt_path, receipt, immutable=True)
    print(json.dumps(receipt, ensure_ascii=False), flush=True)
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('first', type=int)
    parser.add_argument('last', type=int)
    parser.add_argument('--local-only', action='store_true', help='Preserve a normal local commit and pending receipt; do not attempt network')
    args = parser.parse_args()
    assert 1 <= args.first <= args.last <= 20
    LOGS.mkdir(exist_ok=True)
    for batch in range(args.first, args.last + 1):
        deliver(batch, args.local_only)


if __name__ == '__main__':
    main()
