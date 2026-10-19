#!/usr/bin/env python3
"""Prepare one proven, pixel-preserving derivative of a saved action HOLD.

This command never runs generation, staging, tests, Git, or approval changes.
The caller must separately pass the returned paths to the existing advance and
checkpoint tools. Original requests, images, manifests and registers stay intact.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

import repack_pr122_disjoint_poses as repacker
import stage_pr122_native_locomotion as staging


BATCH = Path('docs/remake/evidence/pr122-mythic-detailed/batch03')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path):
    require(path.is_file() and not path.is_symlink(), f'Require a regular file: {path}')
    require(path.stat().st_size <= 16 * 1024 * 1024, 'Refuse unexpectedly large metadata')
    return json.loads(path.read_text())


def repo_file(root, value):
    path = Path(value)
    path = path if path.is_absolute() else root / path
    require(not path.is_symlink(), 'Never follow a source/request symlink')
    path = path.resolve()
    require(path.is_relative_to(root) and path.is_file(), 'Require an existing repository file')
    return path


def validate_proof(proof, source, output):
    require(isinstance(proof, dict), 'Require a complete repack proof')
    require(proof.get('source') == str(source) and proof.get('output') == str(output),
            'Repack proof paths do not match')
    require(proof.get('source_sha256') == digest(source), 'Repack source digest changed')
    require(proof.get('output_sha256') == digest(output), 'Repack output digest changed')
    require(proof.get('strict_importer') == 'PASS'
            and proof.get('preserved_foreground_rgba') is True
            and proof.get('resampled') is False and proof.get('recolored') is False
            and proof.get('newly_authored_poses') == 0,
            'Require a passing lossless-foreground proof')
    require(proof.get('foreground_alpha_threshold') == 16
            and 0 <= proof.get('maximum_removed_alpha', 256) <= 16
            and proof.get('retained_fringe_distance') == 2,
            'Repack proof exceeds the permitted background-noise removal')
    poses = proof.get('poses', [])
    require(len(poses) == 6 and [p.get('phase') for p in poses] == list(range(6)),
            'Require exactly six separately preserved temporal poses')
    require(all(isinstance(p.get('translation'), list) and len(p['translation']) == 2
                and all(isinstance(v, int) for v in p['translation'])
                and p.get('pixels', 0) >= p.get('foreground_pixels', 0) > 0
                and re.fullmatch(r'[0-9a-f]{64}', p.get('rgba_sha256', ''))
                for p in poses), 'Incomplete per-pose preservation proof')
    require(sum(p['foreground_pixels'] for p in poses) == proof.get('foreground_pixels'),
            'Foreground accounting is incomplete')


def unselected_manifest(root, request, source):
    manifest = read_json(root / staging.SOURCE_MANIFEST)
    slot = ':'.join(request[field] for field in ('key', 'direction', 'role'))
    selected = [manifest.get(table, {}).get(slot) for table in
                ('selected_locomotion_sheets', 'selected_detailed_action_sheets')]
    selected = [value for value in selected if value is not None]
    if selected:
        require(len(selected) == 1 and bool(request.get('corrective_reason'))
                and request.get('replaces_selected_source') == selected[0],
                'Selected source requires an explicit pinned corrective replacement')
        require(any(hold.get('status') == 'HOLD' and hold.get('key') == request['key']
                    and (hold.get('scope') == 'all_native_clips'
                         or selected[0] in hold.get('sources', []))
                    for hold in manifest.get('visual_quality_holds', [])),
                'Corrective replacement requires an unresolved visual HOLD for the previous source')
    relative = source.relative_to(root).as_posix()
    records = [r for r in manifest.get('raw_images', [])
               if r.get('source') == relative and r.get('key') == request['key']
               and r.get('direction') == request['direction'] and r.get('role') == request['role']]
    require(len(records) == 1 and records[0].get('geometry', {}).get('status') == 'HOLD',
            'Require one matching raw geometry HOLD in the manifest')
    require(records[0].get('sha256') == digest(source), 'Manifest source digest differs')


def next_request(root, request, version, relative_batch=BATCH):
    batch = root / relative_batch
    ordinals = []
    for path in batch.glob('request-*.json'):
        match = re.fullmatch(r'request-(\d+)-.+\.json', path.name)
        require(match is not None, 'Unexpected authoring request filename')
        ordinals.append(int(match.group(1)))
        other = read_json(path)
        require(not all(other.get(k) == request[k] for k in ('key', 'direction', 'role'))
                or other.get('version') != version,
                'Derivative request already exists; do not repeat recovery')
    name = staging.ACTORS[request['key']].rsplit('_', 1)[0]
    output = batch / f'{name}-{request["direction"]}-{request["role"]}-{version}.png'
    require(not output.exists(), 'Derived production image already exists; preserve it')
    ordinal = max(ordinals, default=0) + 1
    return batch / f'request-{ordinal:03d}-{name}-{request["direction"]}-{request["role"]}-{version}.json'


def next_revision(root, key):
    register = read_json(root / staging.REGISTER)
    if key not in register['actors']:
        first = root / 'assets/actors/eight_direction/native_locomotion_staging' / staging.ACTORS[key] / 'r001'
        require(not first.exists(), 'First revision already exists; preserve it')
        return 'r001'
    frames = register['actors'][key]['frames']
    require(frames.startswith('res://'), 'Require a native resource path')
    path = repo_file(root, frames.removeprefix('res://'))
    match = re.fullmatch(r'r(\d{3,})', path.parent.name)
    require(match is not None, 'Require an immutable numbered current revision')
    require(path.parent.parent.name == staging.ACTORS[key], 'Actor revision directory differs')
    revision = f'r{int(match.group(1)) + 1:03d}'
    require(not (path.parent.parent / revision).exists(), 'Next revision already exists; preserve it')
    return revision


def prepare(root, request_path, scratch=Path('/workspace/scratch')):
    root = root.resolve()
    request_path = repo_file(root, request_path)
    batch = request_path.parent.relative_to(root)
    require(batch in (BATCH, BATCH.with_name('batch04')), 'Require a preserved native authoring batch')
    parent_digest = digest(request_path)
    request = read_json(request_path)
    require(request.get('status') == 'GENERATED_HOLD_NOT_APPROVED', 'Require an unapproved raw HOLD')
    require(request.get('kind') != 'pixel_preserving_derived_source', 'Never derive a repeated derivative')
    require(request.get('key') in staging.ACTORS
            and request.get('direction') in staging.importer.DIRECTIONS
            and request.get('role') in staging.NATIVE_ROLES, 'Require a supported authored role')
    version = request.get('version', '')
    require(re.fullmatch(r'[a-zA-Z0-9_-]+', version) is not None, 'Unsafe source version')
    version += 'iso01'
    source = repo_file(root, request['output_source'])
    require(digest(source) == request.get('output_sha256'), 'Saved source digest changed')
    require(source.stat().st_size == request.get('output_bytes'), 'Saved source byte count changed')
    unselected_manifest(root, request, source)
    next_request(root, request, version, batch)
    next_revision(root, request['key'])
    scratch = scratch.resolve()
    scratch.mkdir(parents=True, exist_ok=True)
    output = scratch / f'{source.stem}iso01.png'
    proof_path = output.with_suffix('.repack.json')
    require(not output.is_symlink() and not proof_path.is_symlink(), 'Never follow scratch symlinks')
    if output.exists() or proof_path.exists():
        require(output.is_file() and proof_path.is_file(),
                'Incomplete scratch recovery exists; preserve it and investigate')
        proof = read_json(proof_path)
    else:
        proof = repacker.repack(source, output, request['direction'])
        require(proof == read_json(proof_path), 'Persisted repack proof differs')
    validate_proof(proof, source, output)
    # Recheck after the pixel operation: another unit may have advanced the queue.
    require(digest(request_path) == parent_digest, 'Parent request changed during recovery')
    unselected_manifest(root, request, source)
    path = next_request(root, request, version, batch)
    revision = next_revision(root, request['key'])
    derivative = {k: v for k, v in request.items()
                  if not k.startswith(('output', 'original_generated'))}
    derivative.update(version=version, kind='pixel_preserving_derived_source',
                      parent_request=request_path.relative_to(root).as_posix(),
                      parent_request_sha256=parent_digest, processing_proof=proof,
                      status='REQUESTED_NOT_APPROVED')
    with path.open('x') as stream:
        stream.write(json.dumps(derivative, ensure_ascii=False, indent=2) + '\n')
    return dict(path=path.relative_to(root).as_posix(), generated=str(output), revision=revision,
                **{k: request[k] for k in ('key', 'direction', 'role')})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--request', type=Path, required=True)
    args = parser.parse_args()
    result = prepare(Path(__file__).resolve().parents[1], args.request)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
