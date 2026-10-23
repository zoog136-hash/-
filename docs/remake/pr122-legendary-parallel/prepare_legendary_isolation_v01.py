#!/usr/bin/env python3
"""Prepare selected, versioned isolation revisions; never edit the raw drafts.

Default is a plan. --apply is deliberately required to write derivative atlases.
This is a repair of already recorded errors, never another corpus review.
"""
import argparse
import copy
import functools
import hashlib
import io
import json
import math
from pathlib import Path
import re

import numpy as np
from PIL import Image
from scipy import ndimage

BASELINE = '6bcd94f5a0868426ac4b5ae0ebffd93916fad1ba'
ASSETS = Path('assets/actors/eight_direction/legendary_parallel')
DOCS = Path('docs/remake/pr122-legendary-parallel')
DIRECTIONS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']
REPAIRABLE_CODES = {'FOREIGN_POSE_FOREGROUND_INSIDE_FRAME',
                    'ALPHA_BRIDGE_BETWEEN_TEMPORAL_POSES',
                    'CONNECTED_OR_OPAQUE_POSE_LAYOUT',
                    'DETACHED_FOREGROUND_OWNER_AMBIGUOUS',
                    'VISIBLE_FOREGROUND_TOUCHES_SOURCE_EDGE'}


class Hold(ValueError):
    pass


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text())


def safe_path(root, relative):
    relative = str(relative).removeprefix('res://')
    path = root / relative
    assert path.resolve().is_relative_to(root.resolve()) and not path.is_symlink()
    return path


def resource(relative):
    return 'res://' + str(relative).removeprefix('res://')


def immutable_write(path, raw):
    assert not path.exists(), 'Versioned output already exists: ' + str(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as handle:
        handle.write(raw)


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


@functools.lru_cache(maxsize=16)
def frame_source_pixels(path):
    with Image.open(path) as image:
        return np.asarray(image.convert('RGBA')).copy()


def parse_frames(raw):
    text = raw.decode()
    externals = {identifier: uri for uri, identifier in re.findall(
        r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text)}
    poses = {}
    for identifier, block in re.findall(
            r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]([\s\S]*?)(?=\n\[|\Z)', text):
        source = externals[re.search(r'atlas = ExtResource\("([^"]+)"\)', block).group(1)]
        rectangles = {}
        for field in ['region', 'margin']:
            match = re.search(field + r' = Rect2\(([^)]+)\)', block)
            rectangles[field] = [int(float(v.strip())) for v in match.group(1).split(',')]
        poses[identifier] = dict(source=source, **rectangles)
    animation = text.split('animations = [', 1)[1]
    frames = [dict(poses[name], duration=float(duration)) for duration, name in re.findall(
        r'"duration": ([-+0-9.eE]+), "texture": SubResource\("([^"]+)"\)', animation)]
    assert len(frames) == 6
    return {'frames': frames,
            'name': re.search(r'"name": &"([^"]+)"', animation).group(1),
            'loop': re.search(r'"loop": (true|false)', animation).group(1) == 'true',
            'speed': float(re.search(r'"speed": ([-+0-9.eE]+)', animation).group(1))}


def isolate_rgba(rgba, frames, grid, *, allow_reviewed_source_edge=False, gutter=8):
    """Return an integer-translation derivative and a reversible pixel proof.

    No source alpha>16 pixel may be lost, duplicated, recolored or resampled.
    Ambiguous bodies/bridges/fragments raise HOLD instead of guessing.
    """
    assert rgba.dtype == np.uint8 and rgba.ndim == 3 and rgba.shape[2] == 4
    columns, rows = grid
    assert grid in ([3, 2], [2, 2], [3, 1]) and len(frames) == columns * rows
    alpha = rgba[:, :, 3]
    strong = alpha > 100
    if (strong[0].any() or strong[-1].any() or strong[:, 0].any() or strong[:, -1].any()) and not allow_reviewed_source_edge:
        raise Hold('SOURCE_EDGE_REQUIRES_REVIEW: padding cannot recover missing source pixels')
    labels, _ = ndimage.label(strong)
    sizes = np.bincount(labels.ravel())
    bodies = []
    for frame in frames:
        x, y, w, h = frame['region']
        counts = np.bincount(labels[y:y+h, x:x+w].ravel(), minlength=len(sizes))
        candidates = np.flatnonzero((sizes >= 200) & (counts > 0))
        candidates = candidates[candidates != 0]
        if not len(candidates):
            raise Hold('NO_PHYSICAL_BODY_SEED')
        bodies.append(int(candidates[np.argmax(counts[candidates])]))
    if len(set(bodies)) != len(frames):
        raise Hold('CONNECTED_OR_OPAQUE_POSE_LAYOUT')
    low_labels, count = ndimage.label(alpha > 16, np.ones((3, 3)))
    component_owner = np.full(count + 1, -1, dtype=np.int16)
    component_owner[0] = -2
    for owner, body in enumerate(bodies):
        for component in np.unique(low_labels[labels == body]):
            if component == 0:
                continue
            if component_owner[component] >= 0 and component_owner[component] != owner:
                raise Hold('ALPHA_BRIDGE_BETWEEN_TEMPORAL_POSES')
            component_owner[component] = owner
    unresolved = (low_labels > 0) & (component_owner[low_labels] == -1)
    ys, xs = np.where(unresolved)
    if len(xs):
        distances = np.stack([ndimage.distance_transform_edt(labels != body)[ys, xs] for body in bodies])
        nearest = np.argmin(distances, axis=0)
        ordered = np.sort(distances, axis=0)
        margin = ordered[1] - ordered[0]
        detached_ids = low_labels[ys, xs]
        for component in np.unique(detached_ids):
            chosen = detached_ids == component
            owners = np.unique(nearest[chosen])
            if len(owners) != 1 or float(margin[chosen].min()) <= 32.0:
                raise Hold('DETACHED_FOREGROUND_OWNER_AMBIGUOUS')
            component_owner[component] = int(owners[0])
    owner_map = component_owner[low_labels]
    # Preserve even low-alpha fringe. Its nearest proven foreground owner does
    # not influence the stricter alpha>16 ownership decision above.
    distance, nearest_indices = ndimage.distance_transform_edt(alpha <= 16, return_indices=True)
    fringe = (alpha > 0) & (alpha <= 16)
    owner_map[fringe] = owner_map[nearest_indices[0][fringe], nearest_indices[1][fringe]]
    if np.any(owner_map[alpha > 0] < 0):
        raise Hold('UNASSIGNED_VISIBLE_SOURCE_PIXEL')
    coordinates = []
    minima, maxima = [], []
    for owner, frame in enumerate(frames):
        ys, xs = np.where((alpha > 0) & (owner_map == owner))
        assert len(xs)
        coordinates.append((ys, xs))
        x, y, w, h = frame['region']
        minima.append([int(xs.min()) - x, int(ys.min()) - y])
        maxima.append([int(xs.max()) + 1 - x, int(ys.max()) + 1 - y])
    origin = np.minimum(np.min(minima, axis=0), [0, 0])
    extent = np.maximum(np.max(maxima, axis=0), [max(f['region'][2] for f in frames), max(f['region'][3] for f in frames)])
    cell_width, cell_height = [int(v) for v in extent - origin + 2 * gutter]
    result = np.zeros((rows * cell_height, columns * cell_width, 4), dtype=np.uint8)
    proofs = []
    for owner, (frame, (ys, xs)) in enumerate(zip(frames, coordinates)):
        column, row = owner % columns, owner // columns
        x, y, _, _ = frame['region']
        dx = column * cell_width + gutter - int(origin[0]) - x
        dy = row * cell_height + gutter - int(origin[1]) - y
        tx, ty = xs + dx, ys + dy
        assert tx.min() >= column * cell_width + gutter
        assert tx.max() < (column + 1) * cell_width - gutter
        assert ty.min() >= row * cell_height + gutter
        assert ty.max() < (row + 1) * cell_height - gutter
        assert not result[ty, tx, 3].any()
        result[ty, tx] = rgba[ys, xs]
        proofs.append({'owner_row': owner, 'original_phase': frame['phase'],
                       'original_region': frame['region'], 'translation': [dx, dy],
                       'region': [column * cell_width, row * cell_height, cell_width, cell_height],
                       'margin': [0, 0, 0, 0], 'visible_pixels': int(len(xs)),
                       'foreground_pixels': int((alpha[ys, xs] > 16).sum()),
                       'source_positions_sha256': sha(np.column_stack((ys, xs)).astype('<i4').tobytes()),
                       'source_rgba_sha256': sha(rgba[ys, xs].tobytes())})
    proof = {'grid': grid, 'source_canvas': [rgba.shape[1], rgba.shape[0]],
             'output_canvas': [result.shape[1], result.shape[0]], 'gutter': gutter,
             'source_foreground_pixels': int((alpha > 16).sum()),
             'source_visible_pixels': int((alpha > 0).sum()),
             'resampled': False, 'recolored': False, 'newly_authored_poses': 0,
             'foreground_alpha': 16, 'strong_alpha': 100,
             'detached_runner_up_margin': 32.0, 'poses': proofs}
    verify_translation_proof(rgba, result, proof)
    return result, proof


def verify_translation_proof(source, output, proof):
    coverage = np.zeros(source.shape[:2], dtype=np.uint8)
    for pose in proof['poses']:
        x, y, w, h = pose['region']
        target = output[y:y+h, x:x+w]
        ty, tx = np.where(target[:, :, 3] > 0)
        sy = ty + y - pose['translation'][1]
        sx = tx + x - pose['translation'][0]
        assert sy.min() >= 0 and sx.min() >= 0 and sy.max() < source.shape[0] and sx.max() < source.shape[1]
        assert np.array_equal(target[ty, tx], source[sy, sx]), 'RGBA changed'
        assert sha(np.column_stack((sy, sx)).astype('<i4').tobytes()) == pose['source_positions_sha256']
        coverage[sy, sx] += 1
    assert np.all(coverage[source[:, :, 3] > 0] == 1), 'Visible source pixels lost/duplicated'
    assert not coverage[source[:, :, 3] == 0].any()
    assert int((output[:, :, 3] > 16).sum()) == proof['source_foreground_pixels']


def original_record(root, slot):
    key, direction, role = slot
    path = ASSETS / ('transform_' + key.split(':')[1]) / 'draft001' / (direction + '-' + role + '-record-v01.json')
    record = read_json(root / path)
    assert [record['key'], record['direction'], record['role']] == slot
    parsed = parse_frames(safe_path(root, record['output_spriteframes']).read_bytes())
    return path, record, parsed


def validated_selection(root, selection, review):
    assert selection['baseline_sha'] == review['baseline_sha'] == BASELINE
    indexed = {entry['source']: entry for entry in review['source_findings']}
    chosen = []
    for entry in selection.get('sources', []):
        path = entry['source']
        assert path in indexed, 'Never rescan a normal/unlisted source'
        assert path.startswith(str(ASSETS) + '/')
        known = indexed[path]
        assert {finding['code'] for finding in known['findings']} & REPAIRABLE_CODES
        assert entry['source_sha256'] == known['sha256'] == sha(safe_path(root, path).read_bytes())
        assert entry['decision'] in ('ISOLATE', 'EXCLUDE_CAMERA_IDENTITY', 'HOLD')
        if entry['decision'] != 'ISOLATE':
            assert entry.get('reason')
        chosen.append((entry, known))
    assert len({entry['source'] for entry, _ in chosen}) == len(chosen)
    return chosen


def render_tres(parsed):
    paths = list(dict.fromkeys(frame['source'] for frame in parsed['frames']))
    identifiers = {path: 'texture_' + str(i) for i, path in enumerate(paths)}
    text = ['[gd_resource type="SpriteFrames" load_steps=' + str(len(paths) + 7) + ' format=3]', '']
    for path in paths:
        text.append('[ext_resource type="Texture2D" path="' + path + '" id="' + identifiers[path] + '"]')
    for i, frame in enumerate(parsed['frames']):
        text += ['', '[sub_resource type="AtlasTexture" id="pose_' + str(i) + '"]',
                 'atlas = ExtResource("' + identifiers[frame['source']] + '")',
                 'region = Rect2(' + ', '.join(map(str, frame['region'])) + ')',
                 'margin = Rect2(' + ', '.join(map(str, frame['margin'])) + ')', 'filter_clip = true']
    frames = ['{"duration": ' + repr(frame['duration']) + ', "texture": SubResource("pose_' + str(i) + '")}' for i, frame in enumerate(parsed['frames'])]
    text += ['', '[resource]', 'animations = [{', '"frames": [' + ', '.join(frames) + '],',
             '"loop": ' + str(parsed['loop']).lower() + ',', '"name": &"' + parsed['name'] + '",',
             '"speed": ' + repr(parsed['speed']), '}]', 'metadata/twilight_revision_status = "HOLD"', '']
    return '\n'.join(text).encode()


def write_revisions(root, output_root, version, substitutions, exclusions):
    slots = {tuple(dependent['slot']) for sub in substitutions.values() for dependent in sub['dependents']}
    manifest = {'schema': 'legendary-isolation-revision-library-v1', 'baseline_sha': BASELINE,
                'version': version, 'quality_status': 'HOLD', 'final_approved': 0,
                'revisions': [], 'excluded_slots': exclusions,
                'dependency_required_slots': [list(slot) for slot in sorted(slots)]}
    exclude = {tuple(entry['slot']) for entry in exclusions}
    for slot in sorted(slots):
        if slot in exclude:
            continue
        parent_path, record, parsed = original_record(root, list(slot))
        baseline_frames = copy.deepcopy(parsed['frames'])
        revision = copy.deepcopy(record)
        used_proofs = []
        registration_frames = []
        for index, frame in enumerate(parsed['frames']):
            original = baseline_frames[index]
            original_size = [original['region'][2] + original['margin'][2], original['region'][3] + original['margin'][3]]
            baseline_anchor = np.array(original_size, dtype=np.float64) * 0.5
            anchor = baseline_anchor.copy()
            old = frame['source'].removeprefix('res://')
            if old in substitutions:
                sub = substitutions[old]
                matching = [pose for pose in sub['proof']['poses'] if pose['original_region'] == frame['region']]
                assert len(matching) == 1, 'A borrowed frame must match exactly one proven original region'
                pose = matching[0]
                anchor = (baseline_anchor - np.array(original['margin'][:2]) + np.array(original['region'][:2])
                          + np.array(pose['translation']) - np.array(pose['region'][:2]) + np.array(pose['margin'][:2]))
                frame.update(source=resource(sub['atlas']), region=pose['region'], margin=pose['margin'])
                used_proofs.append(sub['proof_path'])
            registration_frames.append({'index': index, 'scale': [1.0, 1.0],
                                        'anchor_in_texture': anchor.tolist(), 'target_anchor': [0.0, 0.0],
                                        'basis': 'Exact baseline centered-raster origin; no anatomical or scale approval',
                                        'baseline_center': baseline_anchor.tolist()})
        relative = ASSETS / ('transform_' + slot[0].split(':')[1]) / 'corrections' / version
        stem = slot[1] + '-' + slot[2]
        frames_path = relative / (stem + '-SpriteFrames.tres')
        record_path = relative / (stem + '-record.json')
        registration_path = relative / (stem + '-raster-registration.json')
        frame_raw = render_tres(parsed)
        revision.update(schema='pr122-legendary-versioned-isolation-clip-v1', status='CORRECTED_DRAFT_HOLD_NOT_FINAL_APPROVED',
                        revision_parent=resource(parent_path), revision_parent_sha256=sha((root / parent_path).read_bytes()),
                        raw_authored_source=record['source'], raw_authored_source_sha256=record['source_sha256'],
                        isolation_proofs=sorted(set(used_proofs)),
                        output_spriteframes=resource(frames_path), output_spriteframes_sha256=sha(frame_raw),
                        frame_registration_status='RASTER_COORDINATE_PRESERVATION',
                        frame_registration=resource(registration_path), scale_registration_status='HOLD_REVIEWED_SEMANTIC_INPUT_REQUIRED', final_approved=False)
        # Historic generator/guard/pose declarations describe the immutable
        # parent, not the new atlas. Keep them explicitly as provenance.
        for field in ['source_pose_sequence', 'draft_guard_reuse', 'six_pose_config',
                      'original_reused_regions_margins_rgba_unchanged',
                      'minimal_checks', 'cell_size', 'partition_edges']:
            if field in revision:
                revision['raw_parent_' + field] = revision.pop(field)
        revision['revision_source_pose_sequence'] = [dict(frame, phase=i) for i, frame in enumerate(parsed['frames'])]
        revision['minimal_checks'] = {'integer_translation_RGBA_proof': 'PASS',
                                      'SpriteFrames_actual_Godot_playback': 'NOT_RUN'}
        old_main = record['source'].removeprefix('res://')
        if old_main in substitutions:
            revision['source'] = substitutions[old_main]['atlas']
            revision['source_resource_path'] = resource(revision['source'])
            revision['source_sha256'] = substitutions[old_main]['atlas_sha256']
            revision['source_bytes'] = (output_root / revision['source']).stat().st_size
            proof = substitutions[old_main]['proof']
            revision['source_grid'] = proof['grid']
            cw = proof['output_canvas'][0] // proof['grid'][0]
            ch = proof['output_canvas'][1] // proof['grid'][1]
            revision['cell_size'] = [cw, ch]
            revision['partition_edges'] = {'x': [i * cw for i in range(proof['grid'][0] + 1)],
                                            'y': [i * ch for i in range(proof['grid'][1] + 1)]}
        revision['source_files'] = []
        declared_raw = {resource(info['path']): info['sha256'] for info in record.get('source_files', [])}
        declared_raw[resource(record['source'])] = record['source_sha256']
        for path in dict.fromkeys(frame['source'] for frame in parsed['frames']):
            input_path = safe_path(output_root, path)
            if not input_path.exists():
                input_path = safe_path(root, path)
            actual_sha = sha(input_path.read_bytes())
            if not any(path == resource(s['atlas']) for s in substitutions.values()):
                assert actual_sha == declared_raw[path], 'Unchanged raw source must retain its pinned SHA'
            revision['source_files'].append({'path': path, 'sha256': actual_sha, 'bytes': input_path.stat().st_size,
                                             'source_kind': 'integer_translation_derivative' if any(path == resource(s['atlas']) for s in substitutions.values()) else 'preserved_raw'})
        checks = []
        for i, frame in enumerate(parsed['frames']):
            path = safe_path(output_root, frame['source'])
            if not path.exists():
                path = safe_path(root, frame['source'])
            rgba = frame_source_pixels(str(path))
            x, y, w, h = frame['region']
            checks.append({'index': i, 'region': frame['region'], 'rgba_sha256': sha(rgba[y:y+h, x:x+w].tobytes())})
        revision['automatic_checks'] = checks
        revision_raw = json_bytes(revision)
        registration = {'schema': 'legendary-frame-registration-v1', 'baseline_sha': BASELINE,
                        'status': 'RASTER_COORDINATE_PRESERVATION', 'record_sha256': sha(revision_raw),
                        'SpriteFrames_sha256': sha(frame_raw), 'frames': registration_frames,
                        'semantic_registration_approved': False, 'quality_status': 'HOLD', 'final_approved': 0}
        registration_raw = json_bytes(registration)
        immutable_write(output_root / frames_path, frame_raw)
        immutable_write(output_root / record_path, revision_raw)
        immutable_write(output_root / registration_path, registration_raw)
        manifest['revisions'].append({'slot': list(slot), 'record': resource(record_path),
                                     'record_sha256': sha(revision_raw), 'SpriteFrames': resource(frames_path),
                                     'SpriteFrames_sha256': sha(frame_raw), 'registration_status': 'RASTER_COORDINATE_PRESERVATION',
                                     'registration': resource(registration_path), 'registration_sha256': sha(registration_raw)})
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--output-root', type=Path)
    parser.add_argument('--review', type=Path, required=True)
    parser.add_argument('--frozen', type=Path, required=True)
    parser.add_argument('--selection', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    selection = read_json(args.selection)
    review_raw = args.review.read_bytes()
    review = json.loads(review_raw)
    assert sha(review_raw) == selection['technical_review_sha256']
    frozen_raw = args.frozen.read_bytes()
    frozen = json.loads(frozen_raw)
    assert frozen['baseline_sha'] == BASELINE and sha(frozen_raw) == selection['frozen_review_sha256']
    frozen_allowed = {entry['source']: entry['sha256'] for entry in frozen['ownership_repair_candidates']}
    assert all(entry['source'] in frozen_allowed and entry['source_sha256'] == frozen_allowed[entry['source']]
               for entry in selection.get('sources', []) if entry['decision'] == 'ISOLATE'), 'Only frozen safe candidates are authorized'
    chosen = validated_selection(args.root, selection, review)
    if not args.apply:
        print(json.dumps({'status': 'PLAN_ONLY_NO_ARTIFACT_WRITES', 'selected_sources': len(chosen),
                          'isolate_sources': sum(e['decision'] == 'ISOLATE' for e, _ in chosen),
                          'version': selection['version']}, ensure_ascii=False))
        return
    assert args.output_root is not None
    version = selection['version']
    assert re.fullmatch(r'isolation-v[0-9]{2}', version)
    substitutions, outcomes = {}, []
    for entry, known in chosen:
        if entry['decision'] != 'ISOLATE':
            outcomes.append({'source': entry['source'], 'status': entry['decision'], 'reason': entry['reason']})
            continue
        source_path = safe_path(args.root, entry['source'])
        source_raw = source_path.read_bytes()
        _, record, parsed = original_record(args.root, known['authored_slot'])
        own_frames = [dict(frame, phase=i) for i, frame in enumerate(parsed['frames']) if frame['source'].removeprefix('res://') == entry['source']]
        try:
            rgba = np.asarray(Image.open(io.BytesIO(source_raw)).convert('RGBA'))
            result, proof = isolate_rgba(rgba, own_frames, known['grid'],
                allow_reviewed_source_edge=entry.get('source_edge_review') == 'CONFIRMED_NOT_CLIPPED')
        except Hold as exc:
            outcomes.append({'source': entry['source'], 'status': 'HOLD', 'reason': str(exc)})
            continue
        target = Path(entry['source']).parent.parent / 'corrections' / version / (source_path.stem + '-isolated.png')
        proof_path = target.with_suffix('.proof.json')
        buffer = io.BytesIO()
        Image.fromarray(result).save(buffer, format='PNG')
        atlas_raw = buffer.getvalue()
        proof.update(schema='legendary-original-rgba-isolation-proof-v1', baseline_sha=BASELINE,
                     source=entry['source'], source_sha256=sha(source_raw), output=str(target), output_sha256=sha(atlas_raw),
                     source_review_sha256=sha(review_raw), source_edge_review=entry.get('source_edge_review', 'NOT_OVERRIDDEN'),
                     quality_status='HOLD', final_approved=False)
        assert sha(source_path.read_bytes()) == proof['source_sha256']
        immutable_write(args.output_root / target, atlas_raw)
        immutable_write(args.output_root / proof_path, json_bytes(proof))
        substitutions[entry['source']] = {'atlas': str(target), 'atlas_sha256': sha(atlas_raw), 'proof': proof,
                                         'proof_path': resource(proof_path), 'dependents': known['dependents']}
        outcomes.append({'source': entry['source'], 'status': 'INTEGER_TRANSLATION_PROOF_PASS', 'proof': resource(proof_path)})
    manifest = write_revisions(args.root, args.output_root, version, substitutions, selection.get('exclude_slots', []))
    manifest['source_outcomes'] = outcomes
    manifest['selection_sha256'] = sha(args.selection.read_bytes())
    immutable_write(args.output_root / DOCS / ('revision-library-' + version + '.json'), json_bytes(manifest))
    print(json.dumps({'derivative_sources': len(substitutions), 'revised_clips': len(manifest['revisions']),
                      'quality_status': 'HOLD', 'final_approved': 0}, ensure_ascii=False))


if __name__ == '__main__':
    main()
