#!/usr/bin/env python3
"""Copy reviewed parent transforms into new mixed guards; no binding/art edits."""
import copy
import json
from pathlib import Path

import deliver_legendary_isolation_batches_v01 as D
import prepare_legendary_isolation_v01 as I
import prepare_legendary_ownership_delta_v02 as P

PREFIX = D.DOCS / 'quality-v03'


def policy(metadata):
    return metadata.get('scale_policy', 'EXISTING_RUNTIME_CANVAS_NORMALIZATION' if metadata['status'] == 'RASTER_COORDINATE_PRESERVATION' else 'EXPLICIT_RAW_PIXEL_SCALE')


def transform(entry, frame):
    canvas = entry.get('original_virtual_canvas')
    if canvas is None and entry.get('baseline_center'):
        canvas = [value * 2 for value in entry['baseline_center']]
    if canvas is None:
        canvas = [frame['region'][2] + frame['margin'][2], frame['region'][3] + frame['margin'][3]]
    return {'anchor': entry['anchor_in_texture'], 'target': entry.get('target_anchor', [0, 0]),
            'effective_scale': [entry['scale'][i] * 256 / canvas[i] for i in range(2)]}


def prepare():
    assert all((D.LOGS / f'quality-batch{n}-delivery.json').exists() for n in range(294, 309))
    plan_path = PREFIX / 'guard-registration-inheritance-plan-v07.json'
    assert not (D.WORK / plan_path).exists()
    ledger, library, active = P.active_library()
    outputs = []; unaffected = []; held = []
    for batch in range(294, 309):
        manifest = D.read(D.REPO / D.DOCS / 'quality-v02' / f'batch{batch}-revision-library-v02.json')
        for original_entry in manifest['revisions']:
            slot = original_entry['slot']
            parent, record, parsed, entry = P.context(slot, active)
            request = record.get('draft_guard_reuse')
            if not request:
                continue
            try:
                assert slot[0] != 'transform:176', 'Native semantic calibration is a separate reviewed input'
                parent_path = I.safe_path(D.REPO, request['idle_record'])
                parent_raw = parent_path.read_bytes(); assert I.sha(parent_raw) == request['idle_record_sha256']
                idle = json.loads(parent_raw)
                idle_tres_path = I.safe_path(D.REPO, request['idle_SpriteFrames'])
                idle_tres = idle_tres_path.read_bytes(); assert I.sha(idle_tres) == request['idle_SpriteFrames_sha256']
                idle_frames = I.parse_frames(idle_tres)['frames']
                idle_registration = idle.get('frame_registration')
                if not idle_registration:
                    unaffected.append({'slot': slot, 'reason': 'Original unpadded parent canvas; existing transform already applies'})
                    continue
                registration_path = I.safe_path(D.REPO, idle_registration)
                registration_raw = registration_path.read_bytes(); idle_meta = json.loads(registration_raw)
                assert idle_meta['record_sha256'] == request['idle_record_sha256']
                assert idle_meta['SpriteFrames_sha256'] == request['idle_SpriteFrames_sha256']
                if request.get('idle_registration_sha256'):
                    assert I.sha(registration_raw) == request['idle_registration_sha256']
                child_reg_path = I.safe_path(D.REPO, entry['registration'])
                child_raw = child_reg_path.read_bytes(); assert I.sha(child_raw) == entry['registration_sha256']
                child = json.loads(child_raw)
                assert policy(child) == policy(idle_meta) == 'EXISTING_RUNTIME_CANVAS_NORMALIZATION'
                replacement = copy.deepcopy(child); checks = []; differs = False
                for guard in request['guards']:
                    phase = guard['action_phase']; idle_phase = guard['idle_phase']
                    action_frame, idle_frame = parsed['frames'][phase], idle_frames[idle_phase]
                    assert all(action_frame[key] == idle_frame[key] == guard[{'source': 'source_path'}.get(key, key)] for key in ['source', 'region', 'margin'])
                    target = copy.deepcopy(idle_meta['frames'][idle_phase]); target['index'] = phase
                    before = transform(child['frames'][phase], action_frame); after = transform(target, idle_frame)
                    differs |= before != after
                    replacement['frames'][phase] = target
                    checks.append({'action_phase': phase, 'idle_phase': idle_phase,
                                   'parent_record': request['idle_record'], 'parent_record_sha256': request['idle_record_sha256'],
                                   'parent_SpriteFrames': request['idle_SpriteFrames'], 'parent_SpriteFrames_sha256': request['idle_SpriteFrames_sha256'],
                                   'parent_registration': idle_registration, 'parent_registration_sha256': I.sha(registration_raw),
                                   'source': action_frame['source'], 'region': action_frame['region'], 'margin': action_frame['margin'],
                                   'before_transform': before, 'inherited_transform': after})
                if not differs:
                    unaffected.append({'slot': slot, 'reason': 'Parent registration transform already identical'})
                    continue
                folder = I.ASSETS / ('transform_' + slot[0].split(':')[1]) / 'corrections/guard-registration-v07'
                stem = slot[1] + '-' + slot[2]
                record_path = folder / (stem + '-record.json'); registration = folder / (stem + '-registration.json')
                revised = copy.deepcopy(record)
                revised.update(schema='legendary-guard-parent-registration-revision-v07',
                               revision_parent=I.resource(parent), revision_parent_sha256=I.sha((D.REPO / parent).read_bytes()),
                               frame_registration=I.resource(registration), guard_registration_inheritance=checks,
                               PNG_mutations=0, frame_binding_mutations=0, final_approved=False)
                record_raw = I.json_bytes(revised)
                replacement.update(record_sha256=I.sha(record_raw), guard_registration_inheritance=checks,
                                   scale_policy=policy(idle_meta), quality_status='HOLD', final_approved=0)
                replacement_raw = I.json_bytes(replacement)
                I.immutable_write(D.WORK / record_path, record_raw); I.immutable_write(D.WORK / registration, replacement_raw)
                result = copy.deepcopy(entry)
                result.update(record=I.resource(record_path), record_sha256=I.sha(record_raw),
                              registration=I.resource(registration), registration_sha256=I.sha(replacement_raw),
                              inherited_guard_checks=checks)
                outputs.append(result)
            except Exception as exc:
                held.append({'slot': slot, 'status': 'REGISTRATION_HOLD', 'error': repr(exc), 'automatic_retries': 0})
    plan = {'schema': 'legendary-new-mixed-guard-parent-registration-v07', 'revisions': outputs,
            'dependency_required_slots': [entry['slot'] for entry in outputs], 'excluded_slots': [],
            'unaffected_new_mixed': unaffected, 'registration_HOLD': held,
            'source_PNG_mutations': 0, 'frame_binding_mutations': 0, 'existing_healthy_action_changes': 0,
            'native_semantic_registration_changes': 0, 'quality_status': 'HOLD', 'final_approved': 0}
    D.write_json(D.WORK / plan_path, plan, immutable=True)
    print(json.dumps({'affected_new_mixed': len(outputs), 'unaffected_new_mixed': len(unaffected), 'registration_HOLD': len(held)}))


if __name__ == '__main__':
    prepare()
