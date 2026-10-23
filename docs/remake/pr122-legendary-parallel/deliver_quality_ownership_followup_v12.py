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

PREFIX = D.DOCS / 'quality-v04'
PLAN = PREFIX / 'new-source-ownership-plan-v12.json'


def drained():
    assert all((D.LOGS / f'quality-batch{n}-delivery.json').exists() for n in range(311, 315)), 'Raw batch sole writer must drain first'


def select():
    drained(); assert not (D.WORK / PLAN).exists()
    safe = []; held = []; indices = []
    for n in range(311, 315):
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
        path = PREFIX / f'ownership-selection-batch{number:03d}-v12.json'
        selection = {'schema': 'legendary-changed-source-safe-ownership-selection-v07', 'batch': number,
                     'version': f'quality-isolation-v12-{number:03d}', 'actors': group,
                     'sources': [item for item in safe if item['finding']['authored_slot'][0] in group],
                     'normal_original_source_regenerations': 0, 'previous_718_proof_mutations': 0, 'final_approved': 0}
        D.write_json(D.WORK / path, selection, immutable=True)
        batches.append({'batch': number, 'selection': I.resource(path), 'selection_sha256': I.sha((D.WORK / path).read_bytes())})
    plan = {'schema': 'legendary-changed-source-ownership-plan-v07', 'indices': indices, 'sources_planned': len(safe),
            'source_HOLD': held, 'batches': batches, 'previous_718_proof_mutations': 0, 'whole_reviews_added': 0, 'final_approved': 0}
    D.write_json(D.WORK / PLAN, plan, immutable=True)
    print(json.dumps({'safe_sources': len(safe), 'unsafe_sources_HOLD': len(held), 'batches': len(batches)}))


def deliver(number):
    drained(); assert not D.git('status', '--porcelain')
    pending = D.LOGS / f'quality-ownership-v12-batch{number:03d}-pending-remote.json'
    assert not pending.exists(), 'Push the preserved existing commit, never repeat it'
    plan = D.read(D.WORK / PLAN); batch = plan['batches'][number - 1]
    selection_path = Path(batch['selection'].removeprefix('res://'))
    assert I.sha((D.WORK / selection_path).read_bytes()) == batch['selection_sha256']
    selection = D.read(D.WORK / selection_path)
    version = selection['version']
    manifest_path = PREFIX / f'ownership-batch{number:03d}-library-v12.json'
    if not (D.WORK / manifest_path).exists():
        D.run(['python3', str(D.WORK / D.DOCS / 'prepare_quality_ownership_followup_v12.py'), str(selection_path)],
              f'quality-ownership-v12-batch{number:03d}-apply.log')
    manifest = D.read(D.WORK / manifest_path)
    validation_path = PREFIX / f'ownership-batch{number:03d}-affected-validation-v12.json'
    if not (D.WORK / validation_path).exists():
        env = dict(os.environ, XDG_DATA_HOME='/workspace/legendary_runtime/data',
                   XDG_CACHE_HOME='/workspace/legendary_runtime/cache', XDG_CONFIG_HOME='/workspace/legendary_runtime/config')
        D.run([D.GODOT, '--headless', '--fixed-fps', '60', '--path', str(D.WORK), '--script',
               I.resource(D.DOCS / 'validate_guard_parent_inheritance_v08.gd'), '--',
               I.resource(manifest_path), I.resource(validation_path)], f'quality-ownership-v12-batch{number:03d}-validation.log', env=env)
    validation = D.read(D.WORK / validation_path)
    assert validation['failures'] == 0 and len(validation['records']) == len(manifest['revisions'])
    paths = {PLAN, selection_path, manifest_path, validation_path}
    for actor in selection['actors']:
        folder = D.ASSETS / ('transform_' + actor.split(':')[1]) / 'corrections' / version
        paths.update(p.relative_to(D.WORK) for p in (D.WORK / folder).glob('*') if p.is_file())
    for entry in manifest['revisions']:
        for field in ['record', 'SpriteFrames', 'registration']:
            paths.add(Path(entry[field].removeprefix('res://')))
    paths.update(p.relative_to(D.WORK) for p in (D.WORK / PREFIX).rglob('*.json') if p.is_file() and not p.name.endswith('-v11.json'))
    paths.update(p.relative_to(D.WORK) for p in (D.WORK / D.DOCS / 'quality-v03').rglob('*.json') if p.is_file())
    paths.update(p.relative_to(D.WORK) for p in (D.WORK / D.DOCS / 'quality-v02/generation-claims').glob('*.json'))
    paths.update(p.relative_to(D.WORK) for p in (D.WORK / D.DOCS / 'quality-v02').glob('batch*-new-idle-guard-closure-v06.json'))
    for name in ['prepare_quality_ownership_followup_v12.py', 'deliver_quality_ownership_followup_v12.py', 'record_quality_idle_guard_closure_v06.py', 'prepare_guard_only_rebinding_v09.py', 'validate_guard_parent_inheritance_v08.gd']:
        paths.add(D.DOCS / name)
    ledger, previous, _ = P.active_library(); counts = copy.deepcopy(ledger['counts'])
    merged = {tuple(entry['slot']): entry for entry in previous['revisions']}
    for entry in manifest['revisions']:
        merged[tuple(entry['slot'])] = entry
    aggregate = copy.deepcopy(previous); aggregate['revisions'] = [merged[key] for key in sorted(merged)]
    aggregate['dependency_required_slots'] = [list(slot) for slot in sorted(merged)]
    aggregate_path = PREFIX / f'revision-library-ownership-through-batch{number:03d}-v12.json'
    D.write_json(D.WORK / aggregate_path, aggregate, immutable=True); paths.add(aggregate_path)
    corrections = ledger['corrections']
    section = corrections.setdefault('changed_source_ownership_v12', {'planned_sources': plan['sources_planned'], 'batches': [],
        'plan': I.resource(PLAN), 'plan_sha256': I.sha((D.WORK / PLAN).read_bytes()), 'previous_718_proof_mutations': 0})
    assert all(entry['batch'] != number for entry in section['batches'])
    success = sum(item['status'] == 'INTEGER_TRANSLATION_PROOF_PASS' for item in manifest['source_outcomes'])
    section['batches'].append({'batch': number, 'manifest': I.resource(manifest_path), 'manifest_sha256': I.sha((D.WORK / manifest_path).read_bytes()),
        'validation': I.resource(validation_path), 'validation_sha256': I.sha((D.WORK / validation_path).read_bytes()),
        'isolated_sources': success, 'revised_clips': len(manifest['revisions']), 'guard_only_rebindings': sum(D.read(I.safe_path(D.WORK,r['record'])).get('schema','').startswith('legendary-frozen-guard-only-rebinding') for r in manifest['revisions']), 'held_dependencies': manifest['held_dependencies']})
    section.update(isolated_sources=sum(item['isolated_sources'] for item in section['batches']),
                   new_poses_authored=0, quality_status='HOLD', final_approved=0)
    corrections.update(active_revision_library=I.resource(aggregate_path), active_revision_library_sha256=I.sha((D.WORK / aggregate_path).read_bytes()))
    slots = {tuple(entry['slot']): entry for entry in manifest['revisions']}
    for actor in ledger['actors']:
        for draft in actor['drafts']:
            key = (actor['key'], draft['direction'], draft['role'])
            if key in slots:
                draft.setdefault('correction_revisions', []).append(dict(slots[key], kind='changed_source_ownership_v12', quality_status='HOLD'))
    if number == len(plan['batches']):
        qa_path=D.DOCS/'final-github-ci-receipt-v02-completed-v01.json'
        qa_raw=(D.REPO/qa_path).read_bytes()
        ledger['whole_game_and_Godot_4_7_2_QA']='COMPLETED_WITH_FAILURES_216_PASS_12_FAIL_5_SKIP_GODOT_4_7_2_CI_40014699342'
        ledger['whole_game_and_Godot_4_7_2_QA_evidence']={'receipt':I.resource(qa_path),'receipt_sha256':I.sha(qa_raw),
            'run_id':40014699342,'tested_head':'a2dbbb01659e562980653c8d33898d3b7d761e58',
            'PASS':216,'FAIL':12,'SKIP':5,'new_CI_runs_started':0,'later_staging_assets_validated_by_targeted_minimum_checks':True}
        prior=corrections['changed_source_ownership_v10']
        for old_batch in prior['batches']:
            old_manifest=D.read(I.safe_path(D.REPO,old_batch['manifest']))
            guard_only=0;inherited=0
            for revised in old_manifest['revisions']:
                old_record=D.read(I.safe_path(D.REPO,revised['record']))
                if old_record.get('schema','').startswith('legendary-frozen-guard-only-rebinding'):
                    guard_only+=1
                elif revised.get('inherited_guard_checks'):
                    inherited+=1
            old_batch['guard_only_rebindings']=guard_only
            old_batch['mixed_parent_registration_preserved']=inherited
        prior['guard_only_rebindings']=sum(b['guard_only_rebindings'] for b in prior['batches'])
        prior['mixed_parent_registration_preserved']=sum(b['mixed_parent_registration_preserved'] for b in prior['batches'])
        assert prior['guard_only_rebindings']==1 and prior['mixed_parent_registration_preserved']==7
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
               'new_poses_authored': 0, 'previous_718_proof_mutations': 0, 'final_approved': 0}
    D.write_json(pending, receipt, immutable=True); print(json.dumps(receipt))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('mode', choices=['select', 'deliver']); parser.add_argument('--batch', type=int)
    args = parser.parse_args(); select() if args.mode == 'select' else deliver(args.batch)
