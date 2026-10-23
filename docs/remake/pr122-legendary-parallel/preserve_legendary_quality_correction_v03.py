#!/usr/bin/env python3
"""Compile one bounded erroneous-source replacement into NEW quality-v02 paths.

Reuse the production compiler's real frame checks/legacy bindings. Original
drafts, requests, PNG bytes and native geometry are immutable. No generation.
"""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import re
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
import preserve_mixed_legacy_clip as mixed
import preserve_generated_clip as common
import prepare_legendary_isolation_v01 as I


def preserve(root, output_root, request_path, generated, frozen_path):
    request_raw = request_path.read_bytes()
    q = json.loads(request_raw)
    frozen_raw = frozen_path.read_bytes()
    frozen = json.loads(frozen_raw)
    assert q['quality_version'] == 'quality-v02' and q['maximum_generation_calls'] == 1
    assert q['frozen_review_sha256'] == I.sha(frozen_raw) and frozen['baseline_sha'] == I.BASELINE
    slot = [q['key'], q['direction'], q['role']]
    matching = [candidate for candidate in frozen['bounded_source_correction_candidates']
                if [f"transform:{candidate['actor']}", candidate['direction'], candidate['role']] == slot]
    assert len(matching) == 1 and matching[0]['source_sha256'] == q['previous_source_sha256']
    assert I.sha(I.safe_path(root, q['previous_source']).read_bytes()) == q['previous_source_sha256']
    assert I.sha(I.safe_path(root, q['previous_record']).read_bytes()) == q['previous_record_sha256']
    actor = next(a for a in I.read_json(root / 'data/catalog_v19.json')['변신'] if str(a['sourceId']) == q['key'].split(':')[1])
    assert actor['grade'] == q['grade'] == '전설' and actor['name'] == q['name']
    assert I.sha(I.safe_path(root, q['reference']).read_bytes()) == q['reference_sha256']
    raw = generated.read_bytes()
    with Image.open(generated) as opened:
        assert opened.format == 'PNG' and opened.mode == 'RGBA'
        image = opened.copy()
    folder = I.ASSETS / ('transform_' + q['key'].split(':')[1]) / 'quality-v02'
    stem = q['direction'] + '-' + q['role']
    source_relative = folder / (stem + '-source-v02.png')
    record_relative = folder / (stem + '-record-v02.json')
    frames_relative = folder / (stem + '-SpriteFrames.tres')
    registration_relative = folder / (stem + '-raster-registration-v02.json')
    paths = [source_relative, record_relative, frames_relative, registration_relative]
    assert all(not (output_root / path).exists() for path in paths), 'A correction candidate is attempted only once; never overwrite'
    writes = {source_relative: raw}
    sources = {I.resource(source_relative): {'path': I.resource(source_relative), 'sha256': I.sha(raw), 'bytes': len(raw), 'source_kind': 'new_bounded_correction'}}
    frames, checks, sequence = [], [], []
    legacy = None
    if q.get('six_pose_config'):
        legacy = mixed.read_legacy_track(root, q['key'], q['role'], q['direction'], q['legacy_frames_path'])
        config = mixed.six_pose_config(legacy)
        assert config == q['six_pose_config'] and legacy['legacy_frames_sha256'] == q['legacy_frames_sha256']
        grid = config['new_source_grid']
        source_map = {}
        for index, source in enumerate(legacy['source_files']):
            relative = folder / (stem + ('-reused' if len(legacy['source_files']) == 1 else '-reused-' + str(index)) + '-source-v02.png')
            source_raw = I.safe_path(root, source['original_path']).read_bytes()
            assert I.sha(source_raw) == source['sha256']
            assert not (output_root / relative).exists()
            writes[relative] = source_raw
            source_map[source['original_path']] = I.resource(relative)
            sources[I.resource(relative)] = {'path': I.resource(relative), 'sha256': source['sha256'], 'bytes': len(source_raw), 'source_kind': 'preserved_native'}
        bindings = config['sequence']
        weights = config['duration_weights']
        speed = config['speed']
    elif q.get('draft_guard_reuse'):
        plan = q['draft_guard_reuse']
        idle_path = I.safe_path(root, plan['idle_record'])
        idle_raw = idle_path.read_bytes()
        idle = json.loads(idle_raw)
        assert I.sha(idle_raw) == plan['idle_record_sha256']
        assert [idle['key'], idle['direction'], idle['role']] == [q['key'], q['direction'], 'idle']
        idle_tres = I.safe_path(root, plan['idle_SpriteFrames']).read_bytes()
        assert I.sha(idle_tres) == plan['idle_SpriteFrames_sha256']
        idle_frames = I.parse_frames(idle_tres)['frames']
        for guard in plan['guards']:
            old = idle_frames[guard['idle_phase']]
            assert old['source'] == guard['source_path'] and old['region'] == guard['region'] and old['margin'] == guard['margin']
        for source in plan['source_files']:
            assert I.sha(I.safe_path(root, source['path']).read_bytes()) == source['sha256']
            sources[source['path']] = dict(source, source_kind='reused_idle_guard')
        grid, bindings, weights, speed = [2, 2], [{'kind': 'guard', 'ordinal': 0}] + [{'kind': 'new', 'ordinal': i} for i in range(4)] + [{'kind': 'guard', 'ordinal': 1}], [1.0] * 6, 6.0 / common.SECONDS[q['role']]
    else:
        grid, bindings, weights, speed = [3, 2], [{'kind': 'new', 'ordinal': i} for i in range(6)], [1.0] * 6, 6.0 / common.SECONDS[q['role']]
    columns, rows = grid
    edges_x, edges_y = [i * image.width // columns for i in range(columns + 1)], [i * image.height // rows for i in range(rows + 1)]
    for phase, binding in enumerate(bindings):
        kind, ordinal = binding['kind'], binding['ordinal']
        if kind == 'new':
            column, row = ordinal % columns, ordinal // columns
            region = [edges_x[column], edges_y[row], edges_x[column+1] - edges_x[column], edges_y[row+1] - edges_y[row]]
            margin, path, selected_image = [0, 0, 0, 0], I.resource(source_relative), image
            pose = {'phase': phase, 'source_kind': 'new', 'new_sheet_cell': ordinal, 'region': region}
        elif kind == 'reused':
            native = legacy['frames'][ordinal]
            region, margin, path = native['region'], native['margin'], source_map[native['source_path']]
            selected_image = Image.open(I.safe_path(root, native['source_path']))
            pose = {'phase': phase, 'source_kind': 'reused', 'original_pose_id': native['original_pose_id'],
                    'original_region': region, 'original_margin': margin, 'original_source_anchor': native['source_anchor'], 'rgba_sha256': native['rgba_sha256']}
        else:
            guard = q['draft_guard_reuse']['guards'][ordinal]
            region, margin, path = guard['region'], guard['margin'], guard['source_path']
            selected_image = Image.open(I.safe_path(root, path))
            pose = dict(guard, phase=phase, source_kind='reused_idle_guard')
        check = mixed.frame_check(selected_image, region, phase, kind)
        check['margin'] = margin
        if kind == 'reused':
            assert check['rgba_sha256'] == native['rgba_sha256']
        elif kind == 'guard':
            assert check['rgba_sha256'] == guard['rgba_sha256']
        frames.append({'source': path, 'region': region, 'margin': margin, 'duration': weights[phase]})
        checks.append(check)
        sequence.append(pose)
    assert len(frames) == 6 and len({c['rgba_sha256'] for c in checks}) == len({c['normalized_visible_sha256'] for c in checks}) == 6
    parsed = {'frames': frames, 'name': q['role'] + '_' + str(I.DIRECTIONS.index(q['direction'])), 'loop': q['role'] in ['idle', 'run'], 'speed': speed}
    frames_raw = I.render_tres(parsed) + b'metadata/twilight_canvas_size = Vector2(256, 256)\n'
    record = copy.deepcopy(q)
    new_count = sum(binding['kind'] == 'new' for binding in bindings)
    record.update(schema='pr122-legendary-bounded-quality-correction-v2', status='CORRECTED_SOURCE_DRAFT_HOLD',
                  source=str(source_relative), source_resource_path=I.resource(source_relative), source_sha256=I.sha(raw), source_bytes=len(raw),
                  source_files=list(sources.values()), source_grid=grid, partition_edges={'x': edges_x, 'y': edges_y},
                  source_pose_sequence=sequence, automatic_checks=checks, cell_size=[image.width // columns, image.height // rows],
                  output_spriteframes=I.resource(frames_relative), output_spriteframes_sha256=I.sha(frames_raw),
                  animation=parsed['name'], loop=parsed['loop'], poses=6, new_poses=new_count, newly_authored_poses=new_count,
                  reused_poses=6-new_count, reused_legacy_poses=(6-new_count if legacy else 0), reused_prior_draft_poses=(6-new_count if q.get('draft_guard_reuse') else 0),
                  source_visual_status='HOLD_CHANGED_SOURCE_REVIEW_REQUIRED',
                  frame_registration_status='RASTER_COORDINATE_PRESERVATION', frame_registration=I.resource(registration_relative),
                  request_file_sha256=I.sha(request_raw), generation_request_sha256=I.canonical(q['generation_request']) if hasattr(I, 'canonical') else I.sha(json.dumps(q['generation_request'],ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()),
                  generation_service='image_gen.imagegen', raw_generated_file=str(generated),
                  quality_compiler={'path': Path(__file__).name, 'sha256': I.sha(Path(__file__).read_bytes()), 'reused_checks': 'preserve_mixed_legacy_clip.frame_check/read_legacy_track/six_pose_config'},
                  final_motion_approvals_added=0, actor_approvals_added=0, actual_Main_Player='NOT_RUN', full_CI='NOT_RUN',
                  scale_registration_status='HOLD_SEMANTIC_SOURCE_CONSTANT_SCALE_REQUIRED')
    record_raw = I.json_bytes(record)
    metadata = {'schema':'legendary-frame-registration-v1','baseline_sha':I.BASELINE,'status':'RASTER_COORDINATE_PRESERVATION',
                'record_sha256':I.sha(record_raw),'SpriteFrames_sha256':I.sha(frames_raw),'semantic_registration_approved':False,
                'frames':[{'index':i,'scale':[1.0,1.0],'anchor_in_texture':[(f['region'][2]+f['margin'][2])/2,(f['region'][3]+f['margin'][3])/2],
                           'target_anchor':[0.0,0.0],'basis':'Raw corrected-source centered raster only; semantic scale/feet unapproved'} for i,f in enumerate(frames)],
                'quality_status':'HOLD','final_approved':0}
    inherited_checks = []
    if q.get('resume_parent_registration'):
        evidence = q['resume_parent_registration']; plan = q['draft_guard_reuse']
        assert slot[0] != 'transform:176', 'Native fixed-scale registration remains separately reviewed'
        parent_path = I.safe_path(root, evidence['metadata']['path'])
        parent_raw = parent_path.read_bytes(); assert I.sha(parent_raw) == evidence['metadata']['sha256']
        parent = json.loads(parent_raw)
        assert parent['record_sha256'] == plan['idle_record_sha256'] == evidence['record_sha256']
        assert parent['SpriteFrames_sha256'] == plan['idle_SpriteFrames_sha256'] == evidence['SpriteFrames_sha256']
        assert parent.get('scale_policy', 'EXISTING_RUNTIME_CANVAS_NORMALIZATION') == 'EXISTING_RUNTIME_CANVAS_NORMALIZATION'
        metadata['scale_policy'] = 'EXISTING_RUNTIME_CANVAS_NORMALIZATION'
        for guard in plan['guards']:
            phase = guard['action_phase']; idle_phase = guard['idle_phase']
            inherited = copy.deepcopy(parent['frames'][idle_phase]); inherited['index'] = phase
            assert any(original == parent['frames'][idle_phase] for original in evidence['frames'])
            # Texture virtual canvas belongs to the reviewed parent, not its physical repacked atlas.
            if 'original_virtual_canvas' not in inherited and 'baseline_center' not in inherited:
                inherited['original_virtual_canvas'] = [guard['region'][2]+guard['margin'][2], guard['region'][3]+guard['margin'][3]]
            metadata['frames'][phase] = inherited
            inherited_checks.append({'action_phase':phase,'idle_phase':idle_phase,'parent_record':plan['idle_record'],
                'parent_record_sha256':plan['idle_record_sha256'],'parent_SpriteFrames':plan['idle_SpriteFrames'],
                'parent_SpriteFrames_sha256':plan['idle_SpriteFrames_sha256'],'parent_registration':evidence['metadata']['path'],
                'parent_registration_sha256':evidence['metadata']['sha256'],'source':guard['source_path'],
                'region':guard['region'],'margin':guard['margin']})
        record['guard_registration_inheritance'] = inherited_checks
        record_raw = I.json_bytes(record); metadata['record_sha256'] = I.sha(record_raw)
    metadata_raw = I.json_bytes(metadata)
    writes.update({record_relative:record_raw,frames_relative:frames_raw,registration_relative:metadata_raw})
    assert all(not (output_root / relative).exists() for relative in writes)
    for relative, content in writes.items():
        I.immutable_write(output_root / relative, content)
    assert I.sha((output_root / source_relative).read_bytes()) == I.sha(raw)
    result = {'slot':slot,'record':I.resource(record_relative),'record_sha256':I.sha(record_raw),
            'SpriteFrames':I.resource(frames_relative),'SpriteFrames_sha256':I.sha(frames_raw),
            'registration':I.resource(registration_relative),'registration_sha256':I.sha(metadata_raw),'registration_status':'RASTER_COORDINATE_PRESERVATION',
            'correction_candidate_id':q['correction_candidate_id'],'newly_authored_correction_poses':new_count,'reused_poses':6-new_count,'generated_source_sha256':I.sha(raw)}
    if inherited_checks:result['inherited_guard_checks']=inherited_checks
    return result


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,required=True);parser.add_argument('--output-root',type=Path,required=True)
    parser.add_argument('--request',type=Path,required=True);parser.add_argument('--generated',type=Path,required=True)
    parser.add_argument('--frozen',type=Path,required=True)
    args=parser.parse_args()
    print(json.dumps(preserve(args.root,args.output_root,args.request,args.generated,args.frozen),ensure_ascii=False))
