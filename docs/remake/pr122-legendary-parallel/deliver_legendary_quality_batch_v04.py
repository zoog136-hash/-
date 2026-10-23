#!/usr/bin/env python3
"""Locally commit one bounded quality map; network push is a separate command.

This avoids repeating a compile/commit when a normal Git push is unavailable.
Successful and BLOCKED attempts keep separate immutable request evidence.
"""
import argparse
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).parent))
import prepare_legendary_isolation_v01 as I
import deliver_legendary_isolation_batches_v01 as D
from preserve_legendary_quality_correction_v03 import preserve


def deliver(batch):
    assert D.git('branch', '--show-current') == D.BRANCH and not D.git('status', '--porcelain')
    pending = D.LOGS / f'quality-batch{batch}-pending-remote.json'
    assert not pending.exists(), 'Existing local commit must be pushed, never recreated'
    rows_path = D.WORK / f'quality-correction-batch{batch}-map.json'
    rows = D.read(rows_path)
    assert 2 <= len(rows) <= 5 and 2 <= len({row['id'] for row in rows}) <= 5
    prefix = D.DOCS / 'quality-v02'
    manifest_path = prefix / f'batch{batch}-revision-library-v02.json'
    artifacts = set()
    blocked = []
    entries = []
    if (D.WORK / manifest_path).exists():
        entries = D.read(D.WORK / manifest_path)['revisions']
    else:
        for row in rows:
            if not row.get('blocked'):
                entries.append(preserve(D.REPO, D.WORK, D.WORK / row['request'], Path(row['generated']), D.WORK / D.DOCS / 'whole-review-frozen-v01.json'))
        manifest = {'schema':'legendary-isolation-revision-library-v1','baseline_sha':I.BASELINE,'revisions':entries,
                    'dependency_required_slots':[entry['slot'] for entry in entries],'excluded_slots':[], 'quality_status':'HOLD','final_approved':0}
        D.write_json(D.WORK / manifest_path, manifest, immutable=True)
    artifacts.add(manifest_path)
    for row in rows:
        request_relative = Path(row['request'])
        request_raw = (D.WORK / request_relative).read_bytes()
        request = json.loads(request_raw)
        for folder, suffix in [('requests',''), ('generation-receipts',''), ('generation-tool-results','-result')]:
            relative = prefix / folder / (request_relative.stem + suffix + '.json')
            assert (D.WORK / relative).is_file(), 'Preserve exact generation evidence'
            artifacts.add(relative)
        if row.get('blocked'):
            relative = prefix / 'blocked' / (row['correction_candidate_id'] + '-' + request_relative.stem + '-blocked-v04.json')
            evidence = {'schema':'legendary-bounded-correction-blocked-v2','candidate':row['correction_candidate_id'],
                        'slot':[request['key'],request['direction'],request['role']], 'exact_error':row['error'],
                        'request_utf8':request_raw.decode(), 'request_sha256':I.sha(request_raw),
                        'map_row':row,'map_sha256':I.sha(rows_path.read_bytes()),'generation_retries':0,
                        'old_source_preserved':True,'new_frames_added':0,'final_approved':0}
            if not (D.WORK / relative).exists():
                D.write_json(D.WORK / relative, evidence, immutable=True)
            blocked.append(evidence)
            artifacts.add(relative)
        else:
            folder = I.ASSETS / ('transform_' + row['id']) / 'quality-v02'
            stem = row['direction'] + '-' + row['role']
            artifacts.update(path.relative_to(D.WORK) for path in (D.WORK / folder).glob(stem + '-*'))
    validation_path = prefix / f'batch{batch}-affected-validation-v02.json'
    if not (D.WORK / validation_path).exists():
        env = dict(os.environ, XDG_DATA_HOME='/workspace/legendary_runtime/data',XDG_CACHE_HOME='/workspace/legendary_runtime/cache',XDG_CONFIG_HOME='/workspace/legendary_runtime/config')
        D.run([D.GODOT,'--headless','--fixed-fps','60','--path',str(D.WORK),'--script',I.resource(D.DOCS / 'validate_guard_parent_inheritance_v08.gd'),'--',I.resource(manifest_path),I.resource(validation_path)],f'quality-batch{batch}-minimum-v02.log',env=env)
    validation = D.read(D.WORK / validation_path)
    assert validation['failures'] == 0 and len(validation['records']) == len(entries)
    artifacts.add(validation_path)
    source_map_path = prefix / f'batch{batch}-source-map-v02.json'
    if not (D.WORK / source_map_path).exists():
        I.immutable_write(D.WORK / source_map_path, rows_path.read_bytes())
    artifacts.add(source_map_path)
    for path in (D.WORK / prefix).glob('tool-quota-checkpoint-*.json'):
        artifacts.add(path.relative_to(D.WORK))
    ledger = D.read(D.REPO / D.LEDGER)
    old_counts = copy.deepcopy(ledger['counts'])
    corrections = ledger['corrections']
    previous_library = D.read(D.WORK / corrections['active_revision_library'].removeprefix('res://'))
    combined = copy.deepcopy(previous_library)
    by_slot = {tuple(entry['slot']):entry for entry in combined['revisions']}
    for entry in entries:
        by_slot[tuple(entry['slot'])] = entry
    combined['revisions'] = [by_slot[key] for key in sorted(by_slot)]
    required = {tuple(slot) for slot in combined['dependency_required_slots']}
    required.update(tuple(entry['slot']) for entry in entries)
    combined['dependency_required_slots'] = [list(slot) for slot in sorted(required)]
    combined['quality_status'] = 'HOLD'
    aggregate_path = prefix / f'revision-library-through-batch{batch}-v02.json'
    D.write_json(D.WORK / aggregate_path, combined, immutable=True)
    artifacts.add(aggregate_path)
    quality = corrections.setdefault('quality_source_corrections',{'planned_sources':126,'batches':[],'successful_sources':0,'blocked_sources':0,'newly_authored_correction_poses':0})
    assert not any(entry['batch']==batch for entry in quality['batches'])
    quality['batches'].append({'batch':batch,'manifest':I.resource(manifest_path),'validation':I.resource(validation_path),
                               'successful_sources':len(entries),'blocked_sources':len(blocked),'generation_retries':0})
    quality['successful_sources'] += len(entries)
    quality['blocked_sources'] += len(blocked)
    quality['newly_authored_correction_poses'] += sum(entry['newly_authored_correction_poses'] for entry in entries)
    successful_candidates=set(); blocked_candidates=set()
    for delivered in quality['batches']:
        delivered_manifest=D.read(D.WORK / delivered['manifest'].removeprefix('res://'))
        successful_candidates.update(e['correction_candidate_id'] for e in delivered_manifest['revisions'])
        map_path=prefix / f"batch{delivered['batch']}-source-map-v02.json"
        if (D.WORK/map_path).exists():
            blocked_candidates.update(r['correction_candidate_id'] for r in D.read(D.WORK/map_path) if r.get('blocked'))
    current_blocked=blocked_candidates-successful_candidates
    quality.update(successful_unique_candidates=len(successful_candidates),historical_blocked_attempts=quality['blocked_sources'],
       current_blocked_sources=len(current_blocked),recovered_previously_blocked_candidates=sorted(blocked_candidates & successful_candidates),
       unattempted_sources=126-len(successful_candidates | blocked_candidates),counting_policy='Unique correction candidate status; historical blocked attempts preserved separately')
    quality['final_approved'] = 0
    corrections['active_revision_library'] = I.resource(aggregate_path)
    corrections['active_revision_library_sha256'] = I.sha((D.WORK / aggregate_path).read_bytes())
    current_entries = {tuple(entry['slot']):entry for entry in entries}
    for actor in ledger['actors']:
        for draft in actor.get('drafts',[]):
            slot=(actor['key'],draft['direction'],draft['role'])
            if slot in current_entries:
                draft.setdefault('correction_revisions',[]).append(dict(current_entries[slot],kind='bounded_quality_source',quality_status='HOLD'))
    assert ledger['counts'] == old_counts
    D.write_json(D.REPO / D.LEDGER,ledger)
    shutil.copyfile(D.REPO / D.LEDGER,D.WORK / D.LEDGER)
    for relative in sorted(artifacts):
        D.copy_new(relative)
    for name in ['preserve_legendary_quality_correction_v03.py','deliver_legendary_quality_batch_v03.py','deliver_legendary_quality_batch_v04.py','validate_guard_parent_inheritance_v08.gd','prepare_legendary_registration_v01.py','native-176-existing-canvas-convention-v01.json']:
        relative=D.DOCS/name
        assert not (D.REPO/relative).exists() or (D.REPO/relative).read_bytes()==(D.WORK/relative).read_bytes()
        if not (D.REPO/relative).exists():
            shutil.copyfile(D.WORK/relative,D.REPO/relative)
        artifacts.add(relative)
    artifacts.add(D.LEDGER)
    subprocess.run(['git','add','--',*map(str,sorted(artifacts))],cwd=D.REPO,check=True)
    staged=D.git('diff','--cached','--name-only').splitlines()
    assert all(path==str(D.LEDGER) or path.startswith(str(D.DOCS)+'/') or ('/quality-v02/' in path and path.startswith(str(D.ASSETS)+'/')) for path in staged)
    subprocess.run(['git','diff','--cached','--check'],cwd=D.REPO,check=True)
    subprocess.run(['git','commit','-m',f'[skip ci] Preserve bounded legendary correction batch {batch} and exact blocked evidence'],cwd=D.REPO,check=True,stdout=subprocess.DEVNULL)
    receipt={'status':'LOCAL_COMMIT_WAITING_REMOTE','kind':'bounded_quality_correction','batch':batch,'commit_sha':D.git('rev-parse','HEAD'),
             'successful_sources':len(entries),'blocked_sources':len(blocked),'cumulative_successful':quality['successful_sources'],
             'cumulative_blocked':quality['blocked_sources'],'new_correction_poses':sum(entry['newly_authored_correction_poses'] for entry in entries),
             'final_approved':0,'quality_status':'HOLD','manifest':I.resource(manifest_path)}
    D.write_json(pending,receipt,immutable=True)
    print(json.dumps(receipt,ensure_ascii=False))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('batch',type=int);args=parser.parse_args();deliver(args.batch)
