#!/usr/bin/env python3
"""Frozen guard-only corrections: preserve current middle four pixels/bindings."""
import argparse
import copy
import json
from pathlib import Path

import deliver_legendary_isolation_batches_v01 as D
import prepare_legendary_isolation_v01 as I
import prepare_legendary_ownership_delta_v02 as P


def pinned(spec):
    uri = spec['path']; path = Path(uri)
    if not path.is_absolute():
        path = I.safe_path(D.REPO, uri)
    assert path.is_relative_to(D.REPO) or path.is_relative_to(D.WORK) or path.is_relative_to(D.LOGS)
    raw = path.read_bytes(); assert I.sha(raw) == spec['sha256']
    return json.loads(raw)


def prepare(selection_path):
    raw = selection_path.read_bytes(); selection = json.loads(raw)
    assert selection['frozen_review_sha256'] == I.sha((D.REPO / D.DOCS / 'whole-review-frozen-v01.json').read_bytes())
    _, _, active = P.active_library(); outputs = []
    for chosen in selection['selections']:
        assert chosen['state'] == 'READY_EXACT_GUARD_ONLY_REBIND_NO_NEW_IMAGE' and chosen['new_image_calls_allowed'] == 0
        slot = chosen['slot']; parent, record, parsed, entry = P.context(slot, active)
        assert I.resource(parent) == I.resource(chosen['current_record']) and I.sha((D.REPO / parent).read_bytes()) == chosen['current_record_sha256']
        assert record['output_spriteframes_sha256'] == chosen['current_SpriteFrames_sha256']
        healthy = chosen['healthy_parent']; idle = pinned(healthy['record']); idle_meta = pinned(healthy['registration'])
        receipt = pinned(healthy['remote_receipt']); assert receipt['status'] == 'REMOTE_SAVED'
        assert idle_meta['record_sha256'] == healthy['record']['sha256']
        assert I.sha(I.safe_path(D.REPO, idle['output_spriteframes']).read_bytes()) == healthy['SpriteFrames']['sha256']
        idle_frames = I.parse_frames(I.safe_path(D.REPO, idle['output_spriteframes']).read_bytes())['frames']
        if entry and entry.get('registration'):
            metadata = D.read(I.safe_path(D.REPO, entry['registration']))
            assert I.sha(I.safe_path(D.REPO, entry['registration']).read_bytes()) == entry['registration_sha256']
        else:
            # The untouched draft uses ActorMotion's existing per-texture canvas normalization.
            metadata = {'schema':'legendary-frame-registration-v1','status':'RASTER_COORDINATE_PRESERVATION',
                'scale_policy':'EXISTING_RUNTIME_CANVAS_NORMALIZATION','frames':[
                  {'index':i,'scale':[1.0,1.0],'anchor_in_texture':[(f['region'][2]+f['margin'][2])/2,(f['region'][3]+f['margin'][3])/2],
                   'original_virtual_canvas':[f['region'][2]+f['margin'][2],f['region'][3]+f['margin'][3]],'target_anchor':[0.0,0.0]}
                  for i,f in enumerate(parsed['frames'])]}
        assert metadata.get('scale_policy', 'EXISTING_RUNTIME_CANVAS_NORMALIZATION') == idle_meta.get('scale_policy', 'EXISTING_RUNTIME_CANVAS_NORMALIZATION') == 'EXISTING_RUNTIME_CANVAS_NORMALIZATION'
        revised_meta = copy.deepcopy(metadata); checks = []
        for middle in chosen['middle_frames_preserve_exact']:
            phase = middle['index']; assert phase in [1, 2, 3, 4]
            frame = parsed['frames'][phase]
            assert all(frame[key] == middle[key] for key in ['source', 'region', 'margin', 'duration'])
            pixels = I.frame_source_pixels(str(I.safe_path(D.REPO, frame['source']))); x, y, w, h = frame['region']
            assert I.sha(pixels[y:y+h, x:x+w].tobytes()) == middle['rgba_sha256']
        for guard in chosen['guard_frames_preserve_exact']:
            phase = guard['index']; assert phase in [0, 5]
            source = idle_frames[phase]
            assert all(source[key] == guard[key] for key in ['source', 'region', 'margin'])
            for key in ['source', 'region', 'margin']:
                parsed['frames'][phase][key] = copy.deepcopy(source[key])
            revised_meta['frames'][phase] = copy.deepcopy(idle_meta['frames'][phase])
            checks.append({'action_phase': phase, 'idle_phase': phase, 'parent_record': healthy['record']['path'],
                           'parent_record_sha256': healthy['record']['sha256'], 'parent_SpriteFrames': healthy['SpriteFrames']['path'],
                           'parent_SpriteFrames_sha256': healthy['SpriteFrames']['sha256'],
                           'parent_registration': healthy['registration']['path'], 'parent_registration_sha256': healthy['registration']['sha256']})
        assert len(checks) == 2 and len(chosen['middle_frames_preserve_exact']) == 4
        folder = I.ASSETS / ('transform_' + slot[0].split(':')[1]) / 'corrections/guard-only-v09'
        stem = slot[1] + '-' + slot[2]; tres_path = folder / (stem + '-SpriteFrames.tres')
        record_path = folder / (stem + '-record.json'); reg_path = folder / (stem + '-registration.json')
        tres_raw = I.render_tres(parsed) + b'metadata/twilight_canvas_size = Vector2(256, 256)\n'
        revised = copy.deepcopy(record)
        revised.update(schema='legendary-frozen-guard-only-rebinding-v07', revision_parent=I.resource(parent),
                       revision_parent_sha256=I.sha((D.REPO / parent).read_bytes()), output_spriteframes=I.resource(tres_path),
                       output_spriteframes_sha256=I.sha(tres_raw), frame_registration=I.resource(reg_path),
                       guard_only_selection_sha256=I.sha(raw), frozen_guard_issue=chosen['frozen_issue_id'],
                       middle_four_RGBA_bindings_preserved=True, new_image_calls=0, final_approved=False)
        revised['source_files'] = [{'path': uri, 'sha256': I.sha(I.safe_path(D.REPO, uri).read_bytes()),
                                    'bytes': I.safe_path(D.REPO, uri).stat().st_size} for uri in dict.fromkeys(f['source'] for f in parsed['frames'])]
        revised['automatic_checks'] = []
        for phase, frame in enumerate(parsed['frames']):
            pixels = I.frame_source_pixels(str(I.safe_path(D.REPO, frame['source']))); x, y, w, h = frame['region']
            digest = I.sha(pixels[y:y+h, x:x+w].tobytes())
            expected = next(item['rgba_sha256'] for item in (chosen['middle_frames_preserve_exact'] if phase in [1, 2, 3, 4] else chosen['guard_frames_preserve_exact']) if item['index'] == phase)
            assert digest == expected
            revised['automatic_checks'].append({'index': phase, 'region': frame['region'], 'margin': frame['margin'], 'rgba_sha256': digest})
        revised['revision_source_pose_sequence'] = [dict(frame, phase=i) for i, frame in enumerate(parsed['frames'])]
        record_raw = I.json_bytes(revised)
        revised_meta.update(record_sha256=I.sha(record_raw), SpriteFrames_sha256=I.sha(tres_raw),
                            guard_only_selection_sha256=I.sha(raw), inherited_guard_checks=checks, final_approved=0)
        meta_raw = I.json_bytes(revised_meta)
        for path, content in [(tres_path, tres_raw), (record_path, record_raw), (reg_path, meta_raw)]:
            I.immutable_write(D.WORK / path, content)
        outputs.append({'slot': slot, 'record': I.resource(record_path), 'record_sha256': I.sha(record_raw),
                        'SpriteFrames': I.resource(tres_path), 'SpriteFrames_sha256': I.sha(tres_raw),
                        'registration': I.resource(reg_path), 'registration_sha256': I.sha(meta_raw),
                        'registration_status': metadata['status'], 'inherited_guard_checks': checks})
    manifest = {'schema': 'legendary-isolation-revision-library-v1', 'revisions': outputs,
                'dependency_required_slots': [entry['slot'] for entry in outputs], 'excluded_slots': [],
                'selection': str(selection_path), 'selection_sha256': I.sha(raw), 'newly_authored_poses': 0,
                'middle_four_RGBA_bindings_preserved': True, 'final_approved': 0, 'quality_status': 'HOLD'}
    path = D.DOCS / 'quality-v03/guard-only-rebinding-library-v09.json'
    D.write_json(D.WORK / path, manifest, immutable=True)
    print(json.dumps({'guard_only_clips': len(outputs), 'new_images': 0, 'middle_frames_preserved': len(outputs) * 4}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('selection', type=Path)
    prepare(parser.parse_args().selection)
