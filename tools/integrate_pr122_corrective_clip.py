#!/usr/bin/env python3
"""Integrate one privately reviewed corrective source, with local checkpoints.

No generation, previews, approvals, default catalog changes or push retries.
Every failed stage preserves its files and reports the last local commit.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

import recover_pr122_disjoint_action as recovery
import stage_pr122_native_locomotion as staging

BRANCH = 'feature/twilight-remaining106-20261016'
GODOT = Path('/workspace/scratch/godot472/Godot_v4.7.2-stable_linux.x86_64')


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def absolute_file(path):
    require(path.is_absolute() and path.is_file() and not path.is_symlink(), 'Require an absolute regular input file')
    return path.resolve()


def selected_hold(manifest, request):
    slot = ':'.join(request[k] for k in ('key', 'direction', 'role'))
    values = [manifest.get(t, {}).get(slot) for t in ('selected_locomotion_sheets', 'selected_detailed_action_sheets')]
    values = [v for v in values if v is not None]
    require(len(values) == 1, 'Require exactly one existing selected source')
    holds = [h for h in manifest.get('visual_quality_holds', []) if h.get('key') == request['key']
             and h.get('status') == 'HOLD' and (h.get('scope') == 'all_native_clips' or values[0] in h.get('sources', []))]
    require(len(holds) == 1, 'Selected source requires one unresolved private visual HOLD')
    require(not any(c.get('replacement_source') == values[0] for c in holds[0].get('corrections', [])),
            'Selected corrective source already passed; do not repeat it')
    return slot, values[0], holds[0]


def prepare(root, request_path, generated, review_path):
    request_path, generated, review_path = map(absolute_file, (request_path, generated, review_path))
    require(not request_path.is_relative_to(root), 'Input request must remain in scratch outside the repository')
    request, review = recovery.read_json(request_path), recovery.read_json(review_path)
    require(request.get('status') == 'REQUESTED_NOT_APPROVED' and not any(k.startswith('output_') for k in request),
            'Require an untouched scratch authoring request')
    require(request.get('key') in staging.ACTORS and request.get('direction') in staging.importer.DIRECTIONS
            and request.get('role') in staging.NATIVE_ROLES and isinstance(request.get('corrective_reason'), str)
            and request['corrective_reason'].strip(), 'Invalid corrective identity/reason')
    require(re.fullmatch(r'[A-Za-z0-9_-]{1,48}', request.get('version', '')), 'Unsafe version')
    require(review.get('source_visual_status') == 'PASS' and all(review.get(k) == request[k]
            for k in ('key', 'direction', 'role', 'version')), 'Review must explicitly pass this exact source identity')
    require(review.get('request_sha256') == digest(request_path), 'Review request digest differs')
    require(generated.suffix.lower() == '.png' and review.get('raw_sha256') == digest(generated)
            and review.get('raw_bytes') == generated.stat().st_size, 'Reviewed PNG digest/bytes differ')
    with generated.open('rb') as stream: require(stream.read(8) == b'\x89PNG\r\n\x1a\n', 'Require actual PNG bytes')
    refs = request.get('references', [])
    require(refs and set(refs) == set(request.get('reference_sha256', {})), 'Require all pinned references')
    require(all(digest(absolute_file(Path(p))) == request['reference_sha256'][p] for p in refs), 'Reference digest changed')
    manifest = recovery.read_json(root / staging.SOURCE_MANIFEST)
    require(manifest['approved_history_preserved'] == 405 and manifest['mythic_detail_complete'] == 0, 'Manifest approval baseline changed')
    _, previous, _ = selected_hold(manifest, request)
    require(not any(r.get('sha256') == review['raw_sha256'] for r in manifest.get('raw_images', [])), 'PNG already preserved; do not repeat')
    batch = request.get('source_batch', 'batch03')
    require(batch in ('batch03', 'batch04'), 'Invalid preserved request batch')
    folder = root / recovery.BATCH.with_name(batch)
    ordinals = []
    for path in folder.glob('request-*.json'):
        match = re.fullmatch(r'request-(\d+)-.+\.json', path.name)
        require(match is not None, 'Unexpected request filename')
        ordinals.append(int(match[1]))
        other = recovery.read_json(path)
        require(not all(other.get(k) == request[k] for k in ('key', 'direction', 'role', 'version')), 'Corrective request already exists')
    findings = {k: copy.deepcopy(review[k]) for k in ('visual_findings', 'visual_limitations') if k in review}
    require(findings.get('visual_findings') and all(isinstance(v, list) and all(isinstance(s, str) for s in v)
            for v in findings.values()), 'Require text-only private visual findings')
    require(len(json.dumps(findings)) < 24000, 'Private text review is unexpectedly large')
    findings.update(source_visual_status='PASS', raw_sha256=review['raw_sha256'], raw_bytes=review['raw_bytes'],
                    request_sha256=digest(request_path), review_sha256=digest(review_path))
    request.update(replaces_selected_source=previous, private_source_review=findings)
    name = staging.ACTORS[request['key']].rsplit('_', 1)[0]
    path = folder / f'request-{max(ordinals, default=0) + 1:03d}-{name}-{request["direction"]}-{request["role"]}-{request["version"]}.json'
    source_batch = 'batch01' if request['role'] in ('walk', 'run') and request['key'] in ('transform:393', 'transform:267') else batch
    image = folder.with_name(source_batch) / f'{name}-{request["direction"]}-{request["role"]}-{request["version"]}.png'
    require(not path.exists() and not image.exists(), 'Never overwrite a request or source image')
    return path, request


def record_correction(root, path):
    request = recovery.read_json(path)
    manifest, register = (recovery.read_json(root / p) for p in (staging.SOURCE_MANIFEST, staging.REGISTER))
    require(register['approved_history_preserved'] == 405 and register['detailed_complete'] == 0, 'Approval baseline changed')
    actor = register['actors'][request['key']]
    require(request['status'] == 'GENERATED_GEOMETRY_PASS_NOT_APPROVED'
            and actor['verification']['actual_Player_scene_form_api'] == 'PASS'
            and actor['verification']['required_engine_4_7_2'] == 'PASS', 'Require strict geometry and actual Player PASS')
    proof = request.get('processing_proof', {})
    require((proof.get('source_sha256') == request['private_source_review']['raw_sha256']
             and proof.get('output_sha256') == request['output_sha256'] and proof.get('preserved_foreground_rgba') is True)
            if request.get('kind') == 'pixel_preserving_derived_source'
            else request['output_sha256'] == request['private_source_review']['raw_sha256'], 'Integrated source differs from private review')
    require(digest(root / request['output_source']) == request['output_sha256'], 'Integrated source bytes changed')
    slot = ':'.join(request[k] for k in ('key', 'direction', 'role'))
    require(any(t['source'] == request['output_source'] for t in actor['tracks']), 'Player source is not selected')
    table = 'selected_locomotion_sheets' if request['role'] in ('walk', 'run') else 'selected_detailed_action_sheets'
    require(manifest[table].get(slot) == request['output_source'] and manifest['approved_history_preserved'] == 405
            and manifest['mythic_detail_complete'] == 0, 'Selected source or approval baseline changed')
    holds = [h for h in manifest['visual_quality_holds'] if h['key'] == request['key'] and h['status'] == 'HOLD'
             and (h['scope'] == 'all_native_clips' or request['replaces_selected_source'] in h.get('sources', []))]
    require(len(holds) == 1, 'Original visual HOLD changed during integration')
    correction = dict(slot=slot, previous_source=request['replaces_selected_source'], replacement_source=request['output_source'],
                      source_visual_status='PASS', geometry_and_actual_Player='PASS', actor_approval_added=0,
                      source_visual_findings=request['private_source_review']['visual_findings'],
                      source_review_sha256=request['private_source_review']['review_sha256'])
    holds[0].setdefault('corrections', []).append(correction)
    actor.update(visual_review='HOLD; corrective clip reviewed, final actor quality remains pending',
                 visual_quality_hold=copy.deepcopy(holds[0]), production_connected=False,
                 detailed_completed=False, completed_added=0)
    actor['verification'].update(visual_approval='HOLD_FINAL_ACTOR_QUALITY_REVIEW',
                                 actual_Main_default_catalog='NOT_ENABLED_PENDING_QUALITY_REVIEW')
    for filename, value in ((staging.SOURCE_MANIFEST, manifest), (staging.REGISTER, register)):
        (root / filename).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('request', 'generated', 'review'): parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--local-only', action='store_true', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with tempfile.NamedTemporaryFile(prefix='twilight-corrective-', suffix='.log', delete=False) as stream:
        log = Path(stream.name)
    def git(*parts): return subprocess.check_output(['git', *parts], cwd=root, text=True).strip()
    def run(tool, *parts):
        with log.open('a') as stream:
            subprocess.run([sys.executable, str(root / 'tools' / tool), *map(str, parts)], cwd=root,
                           stdout=stream, stderr=subprocess.STDOUT, check=True)
    try:
        require(git('branch', '--show-current') == BRANCH and not git('diff', '--cached', '--name-only'), 'Wrong branch or unrelated staged changes')
        path, request = prepare(root, args.request, args.generated, args.review)
        version = subprocess.check_output([str(GODOT), '--version'], text=True).strip()
        require(version == '4.7.2.stable.official.ed1daf0bf', 'Require exact Godot4.7.2')
        revision = recovery.next_revision(root, request['key'])
        with path.open('x') as stream: stream.write(json.dumps(request, ensure_ascii=False, indent=2) + '\n')
        run('advance_pr122_native_locomotion.py', '--request', path, '--generated', args.generated, '--revision', revision, '--godot', GODOT)
        if recovery.read_json(path)['status'] == 'GENERATED_HOLD_NOT_APPROVED':
            run('checkpoint_pr122_native_clip.py', '--request', path.relative_to(root), '--local-only')
            recovered = recovery.prepare(root, path)
            path = root / recovered['path']
            run('advance_pr122_native_locomotion.py', '--request', path, '--generated', recovered['generated'], '--revision', recovered['revision'], '--godot', GODOT)
            if recovery.read_json(path)['status'] == 'GENERATED_HOLD_NOT_APPROVED':
                run('checkpoint_pr122_native_clip.py', '--request', path.relative_to(root), '--local-only')
                raise ValueError('Derived source remains HOLD; preserved in a local checkpoint')
        record_correction(root, path)
        run('checkpoint_pr122_native_clip.py', '--request', path.relative_to(root), '--local-only')
        print(json.dumps(dict(status='LOCAL_COMMITTED_NOT_PUSHED', sha=git('rev-parse', 'HEAD'), key=request['key'],
                              direction=request['direction'], role=request['role'], completed_added=0, log=str(log))))
    except Exception as exc:
        print(json.dumps(dict(status='STOP_PRESERVED', error=str(exc)[:500], local_sha=git('rev-parse', 'HEAD'), log=str(log))))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
