#!/usr/bin/env python3
"""After raw delivery drains, group new safe findings and preserve exact proofs."""
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

PREFIX = D.DOCS / 'quality-v03'
PLAN = PREFIX / 'new-source-ownership-plan-v07.json'


def drained():
    assert all((D.LOGS / f'quality-batch{n}-delivery.json').exists() for n in range(294, 309)), 'Raw batch sole writer must drain first'


def select():
    drained(); assert not (D.WORK / PLAN).exists()
    safe = []; held = []; indices = []
    for n in range(294, 309):
        path = PREFIX / f'batch{n}-changed-source-technical-index-v01.json'
        index = D.read(D.WORK / path)
        digest = I.sha((D.WORK / path).read_bytes())
        indices.append({'path': I.resource(path), 'sha256': digest})
        for entry in index['source_findings']:
            item = {'index': I.resource(path), 'index_sha256': digest, 'finding': entry}
            if P.safe(entry):
                safe.append(item)
            elif entry['findings']:
                held.append(item)
    actors = sorted({item['finding']['authored_slot'][0] for item in safe})
    batches = []
    while actors:
        count = 3 if len(actors) == 3 else min(2, len(actors))
        group, actors = actors[:count], actors[count:]
        number = len(batches) + 1
        path = PREFIX / f'ownership-selection-batch{number:03d}-v07.json'
        selection = {'schema': 'legendary-changed-source-safe-ownership-selection-v07', 'batch': number,
                     'version': f'quality-isolation-v07-{number:03d}', 'actors': group,
                     'sources': [item for item in safe if item['finding']['authored_slot'][0] in group],
                     'normal_original_source_regenerations': 0, 'previous_682_proof_mutations': 0, 'final_approved': 0}
        if 'transform:178' in group:
            extra = PREFIX / 'guard-only-rebinding-library-v07.json'
            assert (D.WORK / extra).exists()
            selection['extra_guard_manifest'] = I.resource(extra)
            selection['extra_guard_manifest_sha256'] = I.sha((D.WORK / extra).read_bytes())
        D.write_json(D.WORK / path, selection, immutable=True)
        batches.append({'batch': number, 'selection': I.resource(path), 'selection_sha256': I.sha((D.WORK / path).read_bytes())})
    plan = {'schema': 'legendary-changed-source-ownership-plan-v07', 'indices': indices, 'sources_planned': len(safe),
            'source_HOLD': held, 'batches': batches, 'previous_682_proof_mutations': 0, 'whole_reviews_added': 0, 'final_approved': 0}
    D.write_json(D.WORK / PLAN, plan, immutable=True)
    print(json.dumps({'safe_sources': len(safe), 'unsafe_sources_HOLD': len(held), 'batches': len(batches)}))


def deliver(number):
    drained(); assert not D.git('status', '--porcelain')
    pending = D.LOGS / f'quality-ownership-v07-batch{number:03d}-pending-remote.json'
    assert not pending.exists(), 'Push the preserved existing commit, never repeat it'
    plan = D.read(D.WORK / PLAN); batch = plan['batches'][number - 1]
    selection_path = Path(batch['selection'].removeprefix('res://'))
    assert I.sha((D.WORK / selection_path).read_bytes()) == batch['selection_sha256']
    selection = D.read(D.WORK / selection_path)
    version = selection['version']
    manifest_path = PREFIX / f'ownership-batch{number:03d}-library-v07.json'
    if not (D.WORK / manifest_path).exists():
        D.run(['python3', str(D.WORK / D.DOCS / 'prepare_quality_ownership_followup_v08.py'), str(selection_path)],
              f'quality-ownership-v07-batch{number:03d}-apply.log')
    manifest = D.read(D.WORK / manifest_path)
    validation_path = PREFIX / f'ownership-batch{number:03d}-affected-validation-v07.json'
    if not (D.WORK / validation_path).exists():
        env = dict(os.environ, XDG_DATA_HOME='/workspace/legendary_runtime/data',
                   XDG_CACHE_HOME='/workspace/legendary_runtime/cache', XDG_CONFIG_HOME='/workspace/legendary_runtime/config')
        D.run([D.GODOT, '--headless', '--fixed-fps', '60', '--path', str(D.WORK), '--script',
               I.resource(D.DOCS / 'validate_guard_parent_inheritance_v08.gd'), '--',
               I.resource(manifest_path), I.resource(validation_path)], f'quality-ownership-v07-batch{number:03d}-validation.log', env=env)
    validation = D.read(D.WORK / validation_path)
    assert validation['failures'] == 0 and len(validation['records']) == len(manifest['revisions'])
    paths = {PLAN, selection_path, manifest_path, validation_path}
    for actor in selection['actors']:
        folder = D.ASSETS / ('transform_' + actor.split(':')[1]) / 'corrections' / version
        paths.update(p.relative_to(D.WORK) for p in (D.WORK / folder).glob('*') if p.is_file())
    for entry in manifest['revisions']:
        for field in ['record', 'SpriteFrames', 'registration']:
            paths.add(Path(entry[field].removeprefix('res://')))
    paths.update(p.relative_to(D.WORK) for p in (D.WORK / PREFIX).rglob('*.json') if p.is_file())
    paths.update(p.relative_to(D.WORK) for p in (D.WORK / D.DOCS / 'quality-v02/generation-claims').glob('*.json'))
    paths.update(p.relative_to(D.WORK) for p in (D.WORK / D.DOCS / 'quality-v02').glob('batch*-new-idle-guard-closure-v06.json'))
    for name in ['prepare_quality_ownership_followup_v08.py', 'deliver_quality_ownership_followup_v09.py', 'record_quality_idle_guard_closure_v06.py', 'prepare_guard_only_rebinding_v07.py', 'validate_guard_parent_inheritance_v08.gd']:
        paths.add(D.DOCS / name)
    ledger, previous, _ = P.active_library(); counts = copy.deepcopy(ledger['counts'])
    merged = {tuple(entry['slot']): entry for entry in previous['revisions']}
    for entry in manifest['revisions']:
        merged[tuple(entry['slot'])] = entry
    aggregate = copy.deepcopy(previous); aggregate['revisions'] = [merged[key] for key in sorted(merged)]
    aggregate['dependency_required_slots'] = [list(slot) for slot in sorted(merged)]
    aggregate_path = PREFIX / f'revision-library-ownership-through-batch{number:03d}-v07.json'
    D.write_json(D.WORK / aggregate_path, aggregate, immutable=True); paths.add(aggregate_path)
    corrections = ledger['corrections']
    reconciliation_path=PREFIX/'new-registration-followups-validation-reconciled-v08.json'
    if (D.WORK/reconciliation_path).exists():
        reconciled=D.read(D.WORK/reconciliation_path);assert reconciled['failures']==0
        for native in corrections.get('new_native_quality_registration',{}).get('versions',[]):
            if native['version']=='registration-v04' and not native.get('primary_validation'):
                native['primary_validation']=native['validation'];native['primary_validation_sha256']=native['validation_sha256']
                native['validation']=I.resource(reconciliation_path);native['validation_sha256']=I.sha((D.WORK/reconciliation_path).read_bytes())
                native['targeted_binding_followup']=reconciled['targeted_binding_only_followup']
        guard=corrections.get('new_mixed_guard_registration_v07')
        if guard and not guard.get('primary_validation'):
            guard['primary_validation']=guard['validation'];guard['primary_validation_sha256']=guard['validation_sha256']
            guard['validation']=I.resource(reconciliation_path);guard['validation_sha256']=I.sha((D.WORK/reconciliation_path).read_bytes())
            guard['targeted_binding_followup']=reconciled['targeted_binding_only_followup']
    section = corrections.setdefault('changed_source_ownership_v07', {'planned_sources': plan['sources_planned'], 'batches': [],
        'plan': I.resource(PLAN), 'plan_sha256': I.sha((D.WORK / PLAN).read_bytes()), 'previous_682_proof_mutations': 0})
    assert all(entry['batch'] != number for entry in section['batches'])
    success = sum(item['status'] == 'INTEGER_TRANSLATION_PROOF_PASS' for item in manifest['source_outcomes'])
    section['batches'].append({'batch': number, 'manifest': I.resource(manifest_path), 'manifest_sha256': I.sha((D.WORK / manifest_path).read_bytes()),
        'validation': I.resource(validation_path), 'validation_sha256': I.sha((D.WORK / validation_path).read_bytes()),
        'isolated_sources': success, 'revised_clips': len(manifest['revisions']), 'guard_only_rebindings': sum('inherited_guard_checks' in r for r in manifest['revisions']), 'held_dependencies': manifest['held_dependencies']})
    section.update(isolated_sources=sum(item['isolated_sources'] for item in section['batches']),
                   new_poses_authored=0, quality_status='HOLD', final_approved=0)
    corrections.update(active_revision_library=I.resource(aggregate_path), active_revision_library_sha256=I.sha((D.WORK / aggregate_path).read_bytes()))
    slots = {tuple(entry['slot']): entry for entry in manifest['revisions']}
    for actor in ledger['actors']:
        for draft in actor['drafts']:
            key = (actor['key'], draft['direction'], draft['role'])
            if key in slots:
                draft.setdefault('correction_revisions', []).append(dict(slots[key], kind='changed_source_ownership_v07', quality_status='HOLD'))
    assert counts == ledger['counts']
    for path in sorted(paths):
        D.copy_new(path)
    D.write_json(D.REPO / D.LEDGER, ledger); shutil.copyfile(D.REPO / D.LEDGER, D.WORK / D.LEDGER); paths.add(D.LEDGER)
    subprocess.run(['git', 'add', '--', *map(str, sorted(paths))], cwd=D.REPO, check=True)
    assert all(p == str(D.LEDGER) or p.startswith(str(D.DOCS) + '/') or p.startswith(str(D.ASSETS) + '/') for p in D.git('diff', '--cached', '--name-only').splitlines())
    subprocess.run(['git', 'diff', '--cached', '--check'], cwd=D.REPO, check=True)
    subprocess.run(['git', 'commit', '-m', f'[skip ci] Isolate newly reviewed legendary ownership {number:03d}'], cwd=D.REPO, check=True, stdout=subprocess.DEVNULL)
    receipt = {'status': 'LOCAL_COMMIT_WAITING_REMOTE', 'batch': number, 'commit_sha': D.git('rev-parse', 'HEAD'),
               'successful_sources': success, 'revised_clips': len(manifest['revisions']), 'manifest': I.resource(manifest_path),
               'new_poses_authored': 0, 'previous_682_proof_mutations': 0, 'final_approved': 0}
    D.write_json(pending, receipt, immutable=True); print(json.dumps(receipt))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('mode', choices=['select', 'deliver']); parser.add_argument('--batch', type=int)
    args = parser.parse_args(); select() if args.mode == 'select' else deliver(args.batch)
