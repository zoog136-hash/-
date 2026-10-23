#!/usr/bin/env python3
"""Metadata/SHA-only guard closure for actually delivered new IDLE replacements.

Trace integer-isolation ancestry; never modify action bindings or read pixels.
"""
import argparse
import json
from pathlib import Path

import deliver_legendary_isolation_batches_v01 as D
import prepare_legendary_isolation_v01 as I
import prepare_legendary_ownership_delta_v02 as P


def load_record(uri, digest=None):
    path = I.safe_path(D.REPO, uri)
    raw = path.read_bytes()
    if digest:
        assert I.sha(raw) == digest
    return json.loads(raw), I.sha(raw)


def record_proofs(record, proofs):
    for uri in record.get('isolation_proofs', []):
        path = I.safe_path(D.REPO, uri)
        proof = D.read(path)
        proofs[I.resource(proof['output'])] = dict(proof, proof_path=uri, proof_sha256=I.sha(path.read_bytes()))
    plan = record.get('draft_guard_reuse')
    if plan:
        parent, _ = load_record(plan['idle_record'], plan['idle_record_sha256'])
        for uri in parent.get('isolation_proofs', []):
            path = I.safe_path(D.REPO, uri); proof = D.read(path)
            proofs[I.resource(proof['output'])] = dict(proof, proof_path=uri, proof_sha256=I.sha(path.read_bytes()))


def origin(frame, proofs):
    source, region = frame['source'], frame['region']
    chain = []
    seen = set()
    while source in proofs:
        assert source not in seen
        seen.add(source)
        proof = proofs[source]
        assert I.sha(I.safe_path(D.REPO, source).read_bytes()) == proof['output_sha256']
        poses = [pose for pose in proof['poses'] if pose['region'] == region]
        assert len(poses) == 1
        chain.append({'proof': proof['proof_path'], 'proof_sha256': proof['proof_sha256'],
                      'output_source_sha256': proof['output_sha256'], 'original_source_sha256': proof['source_sha256'],
                      'current_region': region, 'original_region': poses[0]['original_region']})
        source, region = I.resource(proof['source']), poses[0]['original_region']
    return {'source': source, 'source_sha256': I.sha(I.safe_path(D.REPO, source).read_bytes()),
            'region': region, 'integer_isolation_ancestry': chain}


def create(batch):
    target = D.DOCS / 'quality-v02' / f'batch{batch}-new-idle-guard-closure-v06.json'
    if (D.WORK / target).exists():
        return
    receipt_path = D.LOGS / f'quality-batch{batch}-delivery.json'
    if not receipt_path.exists():
        return
    receipt = D.read(receipt_path); assert receipt['status'] == 'REMOTE_SAVED'
    rows = D.read(D.WORK / f'quality-correction-batch{batch}-map.json')
    idles = [row for row in rows if row['role'] == 'idle' and not row.get('blocked')]
    ledger, library, active = P.active_library()
    sources = []; borrowers = []; unknown = []
    for row in idles:
        request = D.read(D.WORK / row['request'])
        slot = [request['key'], row['direction'], 'idle']
        old, old_sha = load_record(request['previous_record'], request['previous_record_sha256'])
        old_frames = I.parse_frames(I.safe_path(D.REPO, old['output_spriteframes']).read_bytes())['frames']
        current = active[tuple(slot)]
        actor = next(actor for actor in ledger['actors'] if actor['key'] == slot[0])
        idle_draft = next(draft for draft in actor['drafts'] if draft['direction'] == slot[1] and draft['role'] == 'idle')
        proofs = {}
        for revision in idle_draft.get('correction_revisions', []):
            parent, _ = load_record(revision['record'], revision['record_sha256'])
            record_proofs(parent, proofs)
        actions = []
        for role in ['attack', 'hit']:
            action_slot = [slot[0], slot[1], role]
            try:
                relative, record, parsed, entry = P.context(action_slot, active)
                record_proofs(record, proofs)
                bindings = []; affected = []
                for phase, idle_phase in [(0, 0), (5, 5)]:
                    frame = parsed['frames'][phase]
                    original = origin(frame, proofs)
                    expected = old_frames[idle_phase]
                    match = original['source'] == expected['source'] and original['region'] == expected['region']
                    check = next((check for check in record.get('automatic_checks', [])
                                  if check.get('index', check.get('phase')) == phase), {})
                    bindings.append({'phase': phase, 'source': frame['source'],
                                     'source_sha256': I.sha(I.safe_path(D.REPO, frame['source']).read_bytes()),
                                     'region': frame['region'], 'margin': frame['margin'],
                                     'rgba_sha256': check.get('rgba_sha256'), 'resolved_origin': original,
                                     'borrowed_replaced_idle_phase': idle_phase if match else None})
                    if match:
                        affected.append(phase)
                item = {'slot': action_slot, 'record': I.resource(relative),
                        'record_sha256': I.sha((D.REPO / relative).read_bytes()),
                        'SpriteFrames': record['output_spriteframes'], 'SpriteFrames_sha256': record['output_spriteframes_sha256'],
                        'frame_bindings': bindings, 'actual_borrowed_phases': affected,
                        'status': 'DEPENDENCY_HOLD_NO_AUTOMATIC_REBIND' if affected else 'UNRELATED_ACTION_UNCHANGED'}
                if affected:
                    borrowers.append(item)
                actions.append(item)
            except Exception as exc:
                item = {'slot': action_slot, 'status': 'LINEAGE_HOLD', 'error': repr(exc)}
                actions.append(item); unknown.append(item)
        sources.append({'candidate': row['correction_candidate_id'], 'idle_slot': slot,
                        'previous_record': request['previous_record'], 'previous_record_sha256': old_sha,
                        'new_idle_record': current['record'], 'new_idle_record_sha256': current['record_sha256'],
                        'new_idle_SpriteFrames': current['SpriteFrames'], 'new_idle_SpriteFrames_sha256': current['SpriteFrames_sha256'],
                        'actions': actions})
    output = {'schema': 'legendary-new-quality-idle-guard-closure-v06', 'batch': batch,
              'scope': 'Only this new IDLE replacement batch and its two same-direction action metadata bindings',
              'remote_receipt': str(receipt_path), 'remote_receipt_sha256': I.sha(receipt_path.read_bytes()),
              'delivered_remote_sha': receipt['remote_sha'],
              'observed_active_manifest': ledger['corrections']['active_revision_library'],
              'observed_active_manifest_sha256': ledger['corrections']['active_revision_library_sha256'],
              'changed_idle_sources': len(idles), 'sources': sources, 'actual_guard_borrowers': borrowers,
              'lineage_HOLD': unknown, 'action_rebindings': 0, 'new_action_generation_calls': 0,
              'healthy_source_regeneration': 0, 'quality_status': 'HOLD', 'final_approved': 0}
    D.write_json(D.WORK / target, output, immutable=True)
    print(json.dumps({'batch': batch, 'new_idles': len(idles), 'actual_guard_borrowers': len(borrowers),
                      'lineage_HOLD': len(unknown), 'closure': I.resource(target)}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--batch', type=int)
    args = parser.parse_args()
    for batch in [args.batch] if args.batch else range(294, 309):
        create(batch)
