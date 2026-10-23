#!/usr/bin/env python3
"""Isolate only explicit safe findings in new changed-source review indices.

Original PNGs, frozen review and all previous ownership proofs are immutable.
"""
import argparse
import copy
import io
from pathlib import Path
import json

import numpy as np
from PIL import Image

import deliver_legendary_isolation_batches_v01 as D
import prepare_legendary_isolation_v01 as I
import prepare_legendary_ownership_delta_v02 as P


def revised_clip(slot, active, substitutions, version, selection_path):
    parent, record, parsed, entry = P.context(slot, active)
    if entry and entry.get('registration'):
        path = I.safe_path(D.REPO, entry['registration'])
        assert I.sha(path.read_bytes()) == entry['registration_sha256']
        metadata = D.read(path)
    else:
        metadata = {'schema': 'legendary-frame-registration-v1', 'baseline_sha': I.BASELINE,
                    'status': 'RASTER_COORDINATE_PRESERVATION',
                    'frames': [{'index': i, 'scale': [1.0, 1.0],
                                'anchor_in_texture': [(f['region'][2] + f['margin'][2]) / 2, (f['region'][3] + f['margin'][3]) / 2],
                                'target_anchor': [0.0, 0.0]} for i, f in enumerate(parsed['frames'])]}
    metadata = copy.deepcopy(metadata)
    used = []
    for phase, frame in enumerate(parsed['frames']):
        key = frame['source'].removeprefix('res://')
        if key not in substitutions:
            continue
        sub = substitutions[key]
        poses = [pose for pose in sub['proof']['poses'] if pose['original_region'] == frame['region']]
        assert len(poses) == 1
        pose = poses[0]; reg = metadata['frames'][phase]
        if 'original_virtual_canvas' not in reg and 'baseline_center' not in reg:
            reg['original_virtual_canvas'] = [frame['region'][2] + frame['margin'][2], frame['region'][3] + frame['margin'][3]]
        anchor = np.array(reg['anchor_in_texture'])
        reg['anchor_in_texture'] = (anchor - np.array(frame['margin'][:2]) + np.array(frame['region'][:2])
                                    + np.array(pose['translation']) - np.array(pose['region'][:2])
                                    + np.array(pose['margin'][:2])).tolist()
        frame.update(source=I.resource(sub['atlas']), region=pose['region'], margin=pose['margin'])
        used.append(sub)
    assert used, 'No revision for an unaffected clip'
    folder = I.ASSETS / ('transform_' + slot[0].split(':')[1]) / 'corrections' / version
    stem = slot[1] + '-' + slot[2]
    tres_path = folder / (stem + '-SpriteFrames.tres')
    record_path = folder / (stem + '-record.json')
    reg_path = folder / (stem + '-registration.json')
    tres_raw = I.render_tres(parsed)
    revised = copy.deepcopy(record)
    revised.update(schema='legendary-changed-source-ownership-revision-v07', status='OWNERSHIP_REPAIRED_OTHER_QUALITY_HOLD',
                   revision_parent=I.resource(parent), revision_parent_sha256=I.sha((D.REPO / parent).read_bytes()),
                   output_spriteframes=I.resource(tres_path), output_spriteframes_sha256=I.sha(tres_raw),
                   frame_registration=I.resource(reg_path), frame_registration_status=metadata['status'],
                   quality_ownership_selection=I.resource(selection_path), newly_authored_correction_poses_added=0, final_approved=False)
    revised['isolation_proofs'] = sorted(set(record.get('isolation_proofs', []) + [I.resource(s['proof_path']) for s in used]))
    main = record['source'].removeprefix('res://')
    if main in substitutions:
        sub = substitutions[main]; proof = sub['proof']
        revised.setdefault('raw_authored_source', record['source'])
        revised.setdefault('raw_authored_source_sha256', record['source_sha256'])
        cell = [proof['output_canvas'][0] // proof['grid'][0], proof['output_canvas'][1] // proof['grid'][1]]
        revised.update(source=str(sub['atlas']), source_resource_path=I.resource(sub['atlas']),
                       source_sha256=sub['atlas_sha256'], source_bytes=(D.WORK / sub['atlas']).stat().st_size, cell_size=cell,
                       partition_edges={'x': [i * cell[0] for i in range(proof['grid'][0] + 1)],
                                        'y': [i * cell[1] for i in range(proof['grid'][1] + 1)]})
    declared = {I.resource(source['path']): source['sha256'] for source in record.get('source_files', [])}
    declared[I.resource(record['source'])] = record['source_sha256']
    revised['source_files'] = []
    for uri in dict.fromkeys(frame['source'] for frame in parsed['frames']):
        path = I.safe_path(D.WORK, uri)
        if not path.exists():
            path = I.safe_path(D.REPO, uri)
        digest = I.sha(path.read_bytes())
        if not any(uri == I.resource(s['atlas']) for s in substitutions.values()):
            assert declared[uri] == digest
        revised['source_files'].append({'path': uri, 'sha256': digest, 'bytes': path.stat().st_size})
    revised['automatic_checks'] = []
    for phase, frame in enumerate(parsed['frames']):
        path = I.safe_path(D.WORK, frame['source'])
        if not path.exists():
            path = I.safe_path(D.REPO, frame['source'])
        pixels = I.frame_source_pixels(str(path)); x, y, w, h = frame['region']
        revised['automatic_checks'].append({'index': phase, 'region': frame['region'], 'margin': frame['margin'],
                                            'rgba_sha256': I.sha(pixels[y:y+h, x:x+w].tobytes())})
    revised['revision_source_pose_sequence'] = [dict(frame, phase=i) for i, frame in enumerate(parsed['frames'])]
    record_raw = I.json_bytes(revised)
    metadata.update(record_sha256=I.sha(record_raw), SpriteFrames_sha256=I.sha(tres_raw),
                    quality_ownership_selection=I.resource(selection_path), quality_status='HOLD', final_approved=0)
    metadata_raw = I.json_bytes(metadata)
    for path, raw in [(tres_path, tres_raw), (record_path, record_raw), (reg_path, metadata_raw)]:
        I.immutable_write(D.WORK / path, raw)
    result = {'slot': slot, 'record': I.resource(record_path), 'record_sha256': I.sha(record_raw),
              'SpriteFrames': I.resource(tres_path), 'SpriteFrames_sha256': I.sha(tres_raw),
              'registration': I.resource(reg_path), 'registration_sha256': I.sha(metadata_raw), 'registration_status': metadata['status']}
    if entry and entry.get('inherited_guard_checks'):
        result['inherited_guard_checks'] = copy.deepcopy(entry['inherited_guard_checks'])
    if entry and 'expected_terminal_source' in entry:
        result.update(expected_terminal_baseline_phase=entry.get('expected_terminal_baseline_phase'),
                      expected_terminal_source=parsed['frames'][-1]['source'], expected_terminal_region=parsed['frames'][-1]['region'])
    return result


def apply(selection_path):
    selection = D.read(D.WORK / selection_path)
    version = selection['version']; number = selection['batch']
    assert version == f'quality-isolation-v12-{number:03d}'
    assert 1 <= len(selection['actors']) <= 5
    manifest_path = D.DOCS / 'quality-v04' / f'ownership-batch{number:03d}-library-v12.json'
    assert not (D.WORK / manifest_path).exists(), 'Reuse existing manifest; do not recreate derivatives'
    _, _, active = P.active_library()
    substitutions = {}; outcomes = []; slots = set()
    for selected in selection['sources']:
        entry = selected['finding']; index_path = I.safe_path(D.WORK, selected['index'])
        try:
            assert I.sha(index_path.read_bytes()) == selected['index_sha256']
            index = D.read(index_path)
            assert entry in index['source_findings'] and P.safe(entry)
            assert entry['batch'] in [311, 312, 313, 314]
            source = I.safe_path(D.REPO, entry['source']); raw = source.read_bytes()
            assert I.sha(raw) == entry['sha256']
            _, _, parsed, _ = P.context(entry['authored_slot'], active)
            own = [dict(frame, phase=i) for i, frame in enumerate(parsed['frames']) if frame['source'] == I.resource(entry['source'])]
            own.sort(key=lambda frame: (frame['region'][1], frame['region'][0]))
            assert len(own) == entry['grid'][0] * entry['grid'][1]
            with Image.open(io.BytesIO(raw)) as opened:
                assert opened.mode == 'RGBA'
                pixels = np.asarray(opened).copy()
            atlas, proof = I.isolate_rgba(pixels, own, entry['grid'])
            target = I.ASSETS / ('transform_' + entry['authored_slot'][0].split(':')[1]) / 'corrections' / version / (source.stem + '-isolated.png')
            proof_path = target.with_suffix('.proof.json')
            buffer = io.BytesIO(); Image.fromarray(atlas).save(buffer, format='PNG'); atlas_raw = buffer.getvalue()
            proof.update(schema='legendary-original-rgba-isolation-proof-v1', baseline_sha=I.BASELINE,
                         source=entry['source'], source_sha256=entry['sha256'], output=str(target), output_sha256=I.sha(atlas_raw),
                         source_review_path=selected['index'], source_review_sha256=selected['index_sha256'],
                         selection_sha256=I.sha((D.WORK / selection_path).read_bytes()),
                         visible_source_coverage='EXACTLY_ONCE', integer_translation_verification='PASS',
                         original_source_mutations=0, quality_status='HOLD', final_approved=0)
            proof_raw = I.json_bytes(proof)
            I.immutable_write(D.WORK / target, atlas_raw); I.immutable_write(D.WORK / proof_path, proof_raw)
            substitutions[entry['source'].removeprefix('res://')] = {'atlas': target, 'atlas_sha256': I.sha(atlas_raw),
                'proof': proof, 'proof_path': proof_path}
            slots.add(tuple(entry['authored_slot'])); slots.update(tuple(dep['slot']) for dep in entry['dependents'])
            outcomes.append({'source': entry['source'], 'source_sha256': entry['sha256'], 'status': 'INTEGER_TRANSLATION_PROOF_PASS',
                             'proof': I.resource(proof_path), 'proof_sha256': I.sha(proof_raw), 'atlas_sha256': I.sha(atlas_raw)})
            assert I.sha(source.read_bytes()) == entry['sha256']
        except Exception as exc:
            outcomes.append({'source': entry['source'], 'status': 'HOLD', 'error': repr(exc), 'automatic_retries': 0})
    revisions = []; held = []
    for slot in sorted(slots):
        try:
            _, _, parsed, _ = P.context(list(slot), active)
            if any(frame['source'].removeprefix('res://') in substitutions for frame in parsed['frames']):
                revisions.append(revised_clip(list(slot), active, substitutions, version, selection_path))
        except Exception as exc:
            held.append({'slot': list(slot), 'status': 'HOLD', 'error': repr(exc)})
    if selection.get('extra_guard_manifest'):
        extra_path = I.safe_path(D.WORK, selection['extra_guard_manifest'])
        assert I.sha(extra_path.read_bytes()) == selection['extra_guard_manifest_sha256']
        extra = D.read(extra_path)
        for entry in extra['revisions']:
            assert entry['slot'][0] in selection['actors']
            assert not any(r['slot'] == entry['slot'] for r in revisions)
            revisions.append(entry)
    manifest = {'schema': 'legendary-isolation-revision-library-v1', 'baseline_sha': I.BASELINE, 'batch': number,
                'actors': selection['actors'], 'revisions': revisions, 'dependency_required_slots': [entry['slot'] for entry in revisions],
                'excluded_slots': [], 'source_outcomes': outcomes, 'held_dependencies': held,
                'selection': I.resource(selection_path), 'selection_sha256': I.sha((D.WORK / selection_path).read_bytes()),
                'newly_authored_poses_added': 0, 'final_approved': 0, 'quality_status': 'HOLD'}
    D.write_json(D.WORK / manifest_path, manifest, immutable=True)
    print(json.dumps({'batch': number, 'isolated_sources': len(substitutions), 'revised_clips': len(revisions), 'held_dependencies': len(held)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('selection', type=Path)
    apply(parser.parse_args().selection)
