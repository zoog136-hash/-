#!/usr/bin/env python3
"""Compile reviewed support-foot anchors and source-constant uniform scales.

Default is plan-only. The original PNGs, native regions/margins/anchors and
SpriteFrames are never rewritten. Isolation translations propagate exactly.
"""
import argparse
import copy
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re

import numpy as np

_SPEC = importlib.util.spec_from_file_location('isolation', Path(__file__).with_name('prepare_legendary_isolation_v01.py'))
I = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(I)
NATIVE_SHAS = {'da13e98e7135e215455ab934668cd5d1d7f06d05f553076510f552da7f0f0ba4',
               '01520a092553b0244a582804c1bf064f191d14b555375fe70efff3ce1f1210f7'}


def constant_scale(value):
    assert type(value) in (int, float) and math.isfinite(value) and value > 0
    return float(value)


def reviewed_anchor(review, original, current, proofs):
    spaces = [field for field in ['anchor_in_baseline_texture', 'anchor_in_raw_source', 'anchor_in_current_texture'] if field in review]
    assert len(spaces) == 1, 'Choose exactly one reviewed anchor coordinate space'
    values = review[spaces[0]]
    assert len(values) == 2 and all(type(v) in (int, float) and math.isfinite(v) for v in values)
    anchor = np.array(values, dtype=np.float64)
    if spaces[0] == 'anchor_in_current_texture':
        return anchor.tolist(), None
    if spaces[0] == 'anchor_in_raw_source':
        anchor = anchor - np.array(original['region'][:2]) + np.array(original['margin'][:2])
    baseline_anchor = anchor.copy()
    if current['source'] == original['source']:
        assert current['region'] == original['region'] and current['margin'] == original['margin']
        return anchor.tolist(), baseline_anchor.tolist()
    matching = []
    for proof in proofs:
        if I.resource(proof['source']) != original['source'] or I.resource(proof['output']) != current['source']:
            continue
        for pose in proof['poses']:
            if pose['original_region'] == original['region'] and pose['region'] == current['region']:
                matching.append(pose)
    assert len(matching) == 1, 'Changed artwork needs fresh reviewed current-texture anchor, not an inferred anchor'
    pose = matching[0]
    anchor = (anchor - np.array(original['margin'][:2]) + np.array(original['region'][:2])
              + np.array(pose['translation']) - np.array(current['region'][:2]) + np.array(current['margin'][:2]))
    return anchor.tolist(), baseline_anchor.tolist()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--output-root', type=Path)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--library', type=Path)
    parser.add_argument('--version', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    assert re.fullmatch(r'registration-v[0-9]{2}', args.version)
    review_raw = args.input.read_bytes()
    review = json.loads(review_raw)
    assert review['baseline_sha'] == I.BASELINE
    scales = {key: constant_scale(value) for key, value in review['scale_by_source_sha256'].items()}
    scale_policy = review.get('scale_policy', 'EXPLICIT_RAW_PIXEL_SCALE')
    assert scale_policy in ('EXPLICIT_RAW_PIXEL_SCALE', 'EXISTING_RUNTIME_CANVAS_NORMALIZATION')
    assert all(re.fullmatch('[0-9a-f]{64}', key) for key in scales)
    library = I.read_json(args.library) if args.library else {'revisions': []}
    current_entries = {tuple(entry['slot']): entry for entry in library['revisions']}
    prepared = []
    seen = set()
    native_frames = 0
    for clip in review['clips']:
        slot = clip['slot']
        assert slot[0] == review['actor'] and tuple(slot) not in seen
        seen.add(tuple(slot))
        parent_path, baseline, original = I.original_record(args.root, slot)
        current_entry = current_entries.get(tuple(slot))
        current_path = I.safe_path(args.root, current_entry['record']) if current_entry else args.root / parent_path
        current_raw = current_path.read_bytes()
        current = json.loads(current_raw)
        frames = I.parse_frames(I.safe_path(args.root, current['output_spriteframes']).read_bytes())
        proofs = [I.read_json(I.safe_path(args.root, uri)) for uri in current.get('isolation_proofs', [])]
        reviews = {frame['index']: frame for frame in clip['frames']}
        assert set(reviews) == set(range(6))
        registration = []
        original_native = {pose['phase']: pose for pose in baseline.get('source_pose_sequence', []) if pose.get('source_kind') == 'reused' and 'original_source_anchor' in pose}
        for index, (base_frame, frame) in enumerate(zip(original['frames'], frames['frames'])):
            evidence = reviews[index]
            assert evidence.get('evidence_type') == 'static_semantic_anchor_review', 'Never substitute automatic bbox-height inference for semantic review'
            anchor, baseline_anchor = reviewed_anchor(evidence, base_frame, frame, proofs)
            original_sha = I.sha(I.safe_path(args.root, base_frame['source']).read_bytes())
            source_sha = original_sha
            if 'anchor_in_current_texture' in evidence:
                source_sha = I.sha(I.safe_path(args.root, frame['source']).read_bytes())
            assert source_sha in scales, 'One constant reviewed scale is required per exact raw source SHA'
            factor = scales[source_sha]
            if original_sha in NATIVE_SHAS:
                assert frame['region'] == base_frame['region'] and frame['margin'] == base_frame['margin']
                assert I.sha(I.safe_path(args.root, frame['source']).read_bytes()) == original_sha
                assert index in original_native and baseline_anchor is not None
                native = original_native[index]
                established = (np.array(native['original_source_anchor']) - np.array(base_frame['region'][:2]) + np.array(base_frame['margin'][:2])).tolist()
                assert baseline_anchor == established, 'Native source anchor is immutable; use its established anchor exactly'
                native_frames += 1
            target = evidence.get('target_anchor', [0.0, 0.0])
            assert len(target) == 2 and all(type(v) in (int, float) and math.isfinite(v) for v in target)
            registration.append({'index': index, 'scale': [factor, factor], 'anchor_in_texture': anchor,
                                 'target_anchor': target, 'scale_basis': 'CONSTANT_PER_REVIEWED_SOURCE_SHA',
                                 'raw_source_sha256': source_sha, 'evidence_type': evidence['evidence_type'],
                                 'anchor_kind': evidence.get('anchor_kind', 'support-foot'),
                                 'baseline_anchor': baseline_anchor,
                                 'original_virtual_canvas': [base_frame['region'][2]+base_frame['margin'][2], base_frame['region'][3]+base_frame['margin'][3]] if baseline_anchor is not None else [frame['region'][2]+frame['margin'][2], frame['region'][3]+frame['margin'][3]]})
        relative = I.ASSETS / ('transform_' + slot[0].split(':')[1]) / 'corrections' / args.version
        stem = slot[1] + '-' + slot[2]
        record_path = relative / (stem + '-record.json')
        registration_path = relative / (stem + '-registration.json')
        order = clip.get('frame_order_override', list(range(6)))
        assert sorted(order) == list(range(6)), 'Frame override must preserve every real pose exactly once'
        permutation = order != list(range(6))
        if permutation:
            assert clip.get('targeted_followup_finding'), 'A new order requires explicit targeted follow-up evidence'
        ordered_frames = [copy.deepcopy(frames['frames'][phase]) for phase in order]
        ordered_registration = [dict(registration[phase], index=index, original_phase=phase) for index, phase in enumerate(order)]
        revised = copy.deepcopy(current)
        revised.update(schema='pr122-legendary-semantic-registration-clip-v1',
                       status='REGISTERED_DRAFT_HOLD_NOT_FINAL_APPROVED', revision_parent=I.resource(current_path.relative_to(args.root)),
                       revision_parent_sha256=I.sha(current_raw), frame_registration=I.resource(registration_path),
                       frame_registration_status='REVIEWED_ANCHORS_AND_SCALE',
                       semantic_review_input_sha256=I.sha(review_raw), final_approved=False)
        new_tres = None
        if permutation:
            # Duration weights travel with their bindings. Total presentation
            # duration stays exact; old individual start times intentionally do
            # not apply to this targeted action-order correction.
            new_frames_path = relative / (stem + '-SpriteFrames.tres')
            changed_frames = dict(frames, frames=ordered_frames)
            new_tres = I.render_tres(changed_frames) + b'metadata/twilight_canvas_size = Vector2(256, 256)\n'
            revised.update(output_spriteframes=I.resource(new_frames_path), output_spriteframes_sha256=I.sha(new_tres),
                           frame_order_override=order, duration_policy='BINDING_WEIGHTS_TRAVEL_WITH_PRESERVED_POSES',
                           legacy_individual_start_times_preserved=False, total_duration_preserved=True,
                           targeted_followup_finding=clip['targeted_followup_finding'])
            if 'automatic_checks' in current:
                by_phase = {check['index']:check for check in current['automatic_checks']}
                revised['automatic_checks'] = [dict(by_phase[old],index=index) for index,old in enumerate(order)]
            revised['revision_source_pose_sequence'] = [dict(frame, phase=index, original_phase=old) for index,(old,frame) in enumerate(zip(order,ordered_frames))]
        revised_raw = I.json_bytes(revised)
        metadata = {'schema': 'legendary-frame-registration-v1', 'baseline_sha': I.BASELINE,
                    'status': 'REVIEWED_ANCHORS_AND_SCALE', 'record_sha256': I.sha(revised_raw),
                    'SpriteFrames_sha256': revised['output_spriteframes_sha256'], 'frames': ordered_registration,
                    'scale_policy': scale_policy, 'frame_order_override': order,
                    'evidence_type': 'static_semantic_anchor_review', 'review_input_sha256': I.sha(review_raw),
                    'actual_AnimatedSprite2D_changed_and_affected_validation': 'NOT_RUN', 'quality_status': 'HOLD', 'final_approved': 0}
        metadata_raw = I.json_bytes(metadata)
        entry = {'slot': slot, 'record': I.resource(record_path), 'record_sha256': I.sha(revised_raw),
                 'SpriteFrames': revised['output_spriteframes'], 'SpriteFrames_sha256': revised['output_spriteframes_sha256'],
                 'registration': I.resource(registration_path), 'registration_sha256': I.sha(metadata_raw),
                 'registration_status': 'REVIEWED_ANCHORS_AND_SCALE'}
        if permutation:
            entry.update(expected_terminal_baseline_phase=order[-1], expected_terminal_source=ordered_frames[-1]['source'],
                         expected_terminal_region=ordered_frames[-1]['region'])
        prepared.append((entry, record_path, revised_raw, registration_path, metadata_raw,
                         (new_frames_path,new_tres) if permutation else None))
    manifest = {'schema': 'legendary-isolation-revision-library-v1', 'baseline_sha': I.BASELINE,
                'dependency_required_slots': [entry[0]['slot'] for entry in prepared], 'excluded_slots': [],
                'revisions': [entry[0] for entry in prepared], 'review_input_sha256': I.sha(review_raw),
                'pending_slots': review.get('pending_slots', []), 'immutable_native_frames_preserved': native_frames,
                'source_PNG_mutations': 0, 'quality_status': 'HOLD', 'final_approved': 0}
    if not args.apply:
        print(json.dumps({'status': 'PLAN_ONLY_NO_ARTIFACT_WRITES', 'clips': len(prepared),
                          'native_frames': native_frames, 'source_constant_scales': len(scales)}))
        return
    assert args.output_root is not None
    for entry, record_path, record_raw, metadata_path, metadata_raw, changed_resource in prepared:
        if changed_resource:
            I.immutable_write(args.output_root / changed_resource[0], changed_resource[1])
        I.immutable_write(args.output_root / record_path, record_raw)
        I.immutable_write(args.output_root / metadata_path, metadata_raw)
    target = args.output_root / I.DOCS / (review['actor'].replace(':', '_') + '-' + args.version + '-library.json')
    I.immutable_write(target, I.json_bytes(manifest))
    print(json.dumps({'status': 'SEMANTIC_REGISTRATION_PREPARED_REQUIRES_AFFECTED_RUNTIME_CHECK',
                      'clips': len(prepared), 'native_frames_preserved': native_frames, 'PNG_mutations': 0,
                      'manifest': str(target), 'final_approved': 0}))


if __name__ == '__main__':
    main()
