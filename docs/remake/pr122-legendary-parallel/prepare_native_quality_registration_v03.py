#!/usr/bin/env python3
"""Register only the three new native hybrids from fresh semantic evidence."""
import argparse
import copy
import json
from pathlib import Path

import deliver_legendary_isolation_batches_v01 as D
import prepare_legendary_isolation_v01 as I
import prepare_legendary_ownership_delta_v02 as P
import prepare_legendary_registration_v01 as R

ALLOWED = {('transform:176', 'W', 'idle'), ('transform:176', 'NW', 'idle'), ('transform:176', 'NW', 'hit')}


def prepare(input_path):
    raw = input_path.read_bytes(); review = json.loads(raw)
    assert review['actor'] == 'transform:176' and review['baseline_sha'] == I.BASELINE
    assert review['scale_policy'] == 'EXPLICIT_RAW_PIXEL_SCALE'
    scales = {key: R.constant_scale(value) for key, value in review['scale_by_source_sha256'].items()}
    _, _, active = P.active_library(); entries = []; preserved = 0; seen = set()
    for clip in review['clips']:
        slot = tuple(clip['slot']); assert slot in ALLOWED and slot not in seen; seen.add(slot)
        base_path = I.safe_path(D.REPO, clip['baseline_record']); base_raw = base_path.read_bytes()
        assert I.sha(base_raw) == clip['baseline_record_sha256']
        base = json.loads(base_raw); assert '/quality-v02/' in clip['baseline_record']
        original = I.parse_frames(I.safe_path(D.REPO, base['output_spriteframes']).read_bytes())['frames']
        parent, current, parsed, current_entry = P.context(list(slot), active)
        proofs = [D.read(I.safe_path(D.REPO, uri)) for uri in current.get('isolation_proofs', [])]
        evidence = {frame['index']: frame for frame in clip['frames']}; assert set(evidence) == set(range(6))
        native = {pose['phase']: pose for pose in base['source_pose_sequence'] if pose['source_kind'] == 'reused'}
        frames = []
        for phase, (before, after) in enumerate(zip(original, parsed['frames'])):
            checked = evidence[phase]; assert checked['evidence_type'] == 'static_semantic_anchor_review'
            assert 'anchor_in_baseline_texture' in checked
            anchor, base_anchor = R.reviewed_anchor(checked, before, after, proofs)
            digest = I.sha(I.safe_path(D.REPO, before['source']).read_bytes()); factor = scales[digest]
            assert abs(factor - checked['review_scale']) <= 1e-12
            if digest in R.NATIVE_SHAS:
                assert after['region'] == before['region'] and after['margin'] == before['margin']
                assert I.sha(I.safe_path(D.REPO, after['source']).read_bytes()) == digest
                assert phase in native
                established = [(native[phase]['original_source_anchor'][i] - before['region'][i] + before['margin'][i]) for i in range(2)]
                assert base_anchor == established, 'Native established anchor remains immutable'
                preserved += 1
            frames.append({'index': phase, 'scale': [factor, factor], 'anchor_in_texture': anchor,
                           'target_anchor': checked.get('target_anchor', [0.0, 0.0]),
                           'raw_source_sha256': digest, 'baseline_anchor': base_anchor,
                           'original_virtual_canvas': [before['region'][2] + before['margin'][2], before['region'][3] + before['margin'][3]],
                           'scale_basis': 'CONSTANT_PER_REVIEWED_RAW_SOURCE_SHA', 'evidence_type': checked['evidence_type'],
                           'anchor_kind': checked.get('anchor_kind', checked.get('semantic_anchor_kind', 'projected_ground_origin'))})
        folder = I.ASSETS / 'transform_176/corrections/registration-v03'
        stem = slot[1] + '-' + slot[2]; record_path = folder / (stem + '-record.json'); reg_path = folder / (stem + '-registration.json')
        record = copy.deepcopy(current)
        record.update(schema='legendary-new-quality-native-registration-v03',
                      revision_parent=I.resource(parent), revision_parent_sha256=I.sha((D.REPO / parent).read_bytes()),
                      frame_registration=I.resource(reg_path), frame_registration_status='REVIEWED_ANCHORS_AND_SCALE',
                      semantic_review_input_sha256=I.sha(raw), camera_style_action_quality='HOLD', final_approved=False)
        record_raw = I.json_bytes(record)
        metadata = {'schema': 'legendary-frame-registration-v1', 'baseline_sha': I.BASELINE,
                    'status': 'REVIEWED_ANCHORS_AND_SCALE', 'scale_policy': 'EXPLICIT_RAW_PIXEL_SCALE',
                    'record_sha256': I.sha(record_raw), 'SpriteFrames_sha256': record['output_spriteframes_sha256'],
                    'frames': frames, 'review_input_sha256': I.sha(raw), 'quality_status': 'HOLD', 'final_approved': 0}
        metadata_raw = I.json_bytes(metadata)
        I.immutable_write(D.WORK / record_path, record_raw); I.immutable_write(D.WORK / reg_path, metadata_raw)
        entry = copy.deepcopy(current_entry)
        entry.update(record=I.resource(record_path), record_sha256=I.sha(record_raw), registration=I.resource(reg_path),
                     registration_sha256=I.sha(metadata_raw), registration_status='REVIEWED_ANCHORS_AND_SCALE')
        entries.append(entry)
    assert seen == ALLOWED and preserved == 6
    manifest = {'schema': 'legendary-isolation-revision-library-v1', 'baseline_sha': I.BASELINE, 'revisions': entries,
                'dependency_required_slots': [entry['slot'] for entry in entries], 'excluded_slots': [],
                'new_native_quality_clips': 3, 'native_frames_in_affected_clips_preserved': preserved,
                'other_30_registered_clips': 'UNCHANGED_NOT_RECHECKED', 'old_native_59_source_mutations': 0,
                'review_input': str(input_path), 'review_input_sha256': I.sha(raw), 'quality_status': 'HOLD', 'final_approved': 0}
    path = D.DOCS / 'transform_176-registration-v03-library.json'
    D.write_json(D.WORK / path, manifest, immutable=True)
    print(json.dumps({'new_native_clips': 3, 'native_poses_preserved_in_scope': 6, 'new_PNGs': 0, 'manifest': I.resource(path)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('input', type=Path)
    prepare(parser.parse_args().input)
