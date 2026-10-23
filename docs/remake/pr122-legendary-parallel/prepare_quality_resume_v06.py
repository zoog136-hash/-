#!/usr/bin/env python3
"""Prepare/resume only the 106 never-called corrections; no image-generation API.

All old plans/requests/checkpoints are immutable. --dry-run writes nothing;
--prepare writes only new dedicated documentation/request files. The --claim
operation is reserved for the separately authorized future image producer.
This is an internal root execution guard; the user's existing authorization
already covers the work and no new user approval is required.
"""
from __future__ import annotations

import argparse
import collections
import copy
import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess

WORK = Path('/workspace/legendary_work')
REPO = Path('/workspace/legendary_repo')
DOCS = Path('docs/remake/pr122-legendary-parallel')
QUALITY = DOCS / 'quality-v02'
FROZEN_SHA = 'bce7e7260712a27515627806a88690158f47bf8ddf4cd172dba5b5ba3eee00c6'
CHECKPOINT_SHA = 'ebac8b962830b51860ac1441c5f0378e9dc74035323d47560b900bb6c8c853ca'
ORIGINAL_PLAN_SHA = '36e60c9ff6e78da08e593d837188d92f7678e006a385635571965aafca68cea0'
HEX = re.compile(r'^[0-9a-f]{64}$')
COMMIT = re.compile(r'^[0-9a-f]{40}$')
NEVER = 'PENDING_TOOL_QUOTA_NOT_CALLED'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def normalized(value):
    return str(value).removeprefix('res://')


def raw_json(path, expected=None):
    path = Path(path)
    if path.suffix != '.json':
        raise ValueError('Only JSON metadata may be decoded')
    raw = path.read_bytes()
    actual = digest(raw)
    if expected is not None and actual != expected:
        raise ValueError('Immutable JSON SHA mismatch: ' + str(path))
    return json.loads(raw), actual


def immutable_json(path, value):
    path = Path(path)
    raw = (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()
    if path.exists():
        if path.read_bytes() != raw:
            raise ValueError('Existing metadata differs; use a new version: ' + str(path))
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as handle:
        handle.write(raw)


def parse_frames(raw):
    """Unchanged parser logic from prepare_legendary_isolation_v01.parse_frames.

    This parses resource text only, without loading/decoding/cropping any PNG.
    """
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
    if len(frames) != 6:
        raise ValueError('Guard resource must have six existing frames')
    return frames


def bind_guard_request(request, revision, idle, frames):
    """Use exact selected guard metadata, with no resampling or invented pose."""
    q = copy.deepcopy(request)
    if [idle['key'], idle['direction'], idle['role']] != [q['key'], q['direction'], 'idle']:
        raise ValueError('Guard actor/direction mismatch')
    checks = {x['index']: x for x in idle['automatic_checks']}
    if len(frames) != 6 or set(checks) != set(range(6)):
        raise ValueError('Expected six actual selected guard frames')
    files = {normalized(x['path']): copy.deepcopy(x) for x in idle.get('source_files', [])}
    if normalized(idle['source']) in files and files[normalized(idle['source'])]['sha256'] != idle['source_sha256']:
        raise ValueError('Active primary source SHA conflicts with selected source metadata')
    files[normalized(idle['source'])] = {'path': 'res://' + normalized(idle['source']),
                                        'sha256': idle['source_sha256'], 'bytes': idle.get('source_bytes')}
    guards = []
    selected_files = {}
    for phase in (0, 5):
        frame = frames[phase]
        source = normalized(frame['source'])
        if source not in files or not HEX.fullmatch(files[source]['sha256']):
            raise ValueError('Guard texture has no exact active source SHA')
        if frame['region'] != checks[phase]['region'] or not HEX.fullmatch(checks[phase]['rgba_sha256']):
            raise ValueError('Guard resource/check region or RGBA metadata mismatch')
        selected_files[source] = files[source]
        guards.append({'idle_phase': phase, 'action_phase': phase, 'original_pose_id': phase,
                       'source_path': frame['source'], 'region': frame['region'], 'margin': frame['margin'],
                       'rgba_sha256': checks[phase]['rgba_sha256']})
    previous = q.get('draft_guard_reuse')
    q['draft_guard_reuse'] = {
        'key': q['key'], 'direction': q['direction'], 'idle_record': revision['record'],
        'idle_record_sha256': revision['record_sha256'], 'idle_SpriteFrames': revision['SpriteFrames'],
        'idle_SpriteFrames_sha256': revision['SpriteFrames_sha256'],
        'source_visual_status': idle.get('source_visual_status', 'HOLD'),
        'reference': q['reference'], 'reference_sha256': q['reference_sha256'],
        'source_files': list(selected_files.values()), 'guards': guards,
        'reused_poses': 2, 'newly_authored_poses': 4, 'source_quality_approval_inherited': False,
    }
    q.update(correction_representation='mixed_draft_guard_reuse_v1',
             correction_source_grid=[2, 2], newly_authored_poses_requested=4, reused_poses=2)
    q['resume_guard_binding'] = {'schema': 'legendary-exact-active-guard-rebinding-v06',
        'previous_guard_binding': previous, 'selected_record': revision['record'],
        'selected_record_sha256': revision['record_sha256'], 'guard_frames_preserved': [0, 5],
        'new_middle_poses_only': 4, 'resampled': False, 'recolored': False,
        'intermediate_pose_inference': False, 'final_approvals_added': 0}
    return q


def append_guard_reference(q, idle):
    """Reference an explicitly accepted current camera/guard, never the bad IDLE."""
    generation = q['generation_request']
    current = str(REPO / normalized(idle['source']))
    if current not in generation['referenced_image_paths']:
        generation['referenced_image_paths'].append(current)
    q.setdefault('generation_reference_sha256', {})[current] = idle['source_sha256']
    prompt = generation['prompt']
    prompt = re.sub(r'Output ONE transparent RGBA PNG, exactly \d+x\d+, \d+ equal columns by \d+ equal rows, \d+ new full-body poses',
                    'Output ONE transparent RGBA PNG, exactly 1024x1024, 2 equal columns by 2 equal rows, 4 new full-body poses', prompt)
    prompt += (' Preserved current healthy IDLE guards are frames0 and5 of the assembled action; do not redraw either. '
               'Generate ONLY four middle articulated action poses, in a 2x2 sheet. The appended current guard source is '
               'the accepted facing/identity reference. Preserve its exact camera, costume, equipment and body proportions. '
               'The old erroneous IDLE source is not a camera authority. No new guard, crop inference or middle-pose copying.')
    generation['prompt'] = prompt
    q['resume_camera_reference'] = {'path': current, 'sha256': idle['source_sha256'],
                                    'scope': 'Exact current healthy guard camera; no final approval inherited'}


def actual_evidence_paths(request):
    stem = Path(request).stem
    return {'claim': QUALITY / 'generation-claims' / (stem + '.json'),
            'receipt': QUALITY / 'generation-receipts' / (stem + '.json'),
            'tool_result': QUALITY / 'generation-tool-results' / (stem + '-result.json')}


def valid_parent_review(review, slot, record_sha256):
    rows = [x for x in review.get('records', []) if tuple(x['slot']) == tuple(slot)
            and x.get('record_sha256') == record_sha256]
    return bool(rows and rows[-1].get('camera_result') == 'RESOLVED_STATIC'
                and rows[-1].get('idle_guard_result') == 'HEALTHY_STATIC'
                and set(rows[-1].get('reviewed_guard_phases', [])) == {0, 5})


def partition_jobs(jobs, first_batch):
    """READY groups are independent of WAIT rows and contain 2..5 actors."""
    next_batch = first_batch
    rows = [x for x in jobs if x['state'] == 'READY']
    groups = [rows[i:i + 5] for i in range(0, len(rows), 5)]
    if len(groups) > 1 and len(groups[-1]) == 1:
        tail = groups[-2] + groups[-1]
        groups[-2:] = [tail[:3], tail[3:]]
    # Correction batches may span roles. Rebalance a same-actor tail rather
    # than stopping unrelated READY work or inventing a singleton commit.
    for group in groups:
        if len(group) >= 2 and len({x['id'] for x in group}) == 1:
            actor = group[0]['id']
            exchanged = False
            for donor in groups:
                if donor is group:
                    continue
                for i, row in enumerate(donor):
                    if row['id'] != actor and len({x['id'] for j, x in enumerate(donor) if j != i} | {actor}) >= 2:
                        group[-1], donor[i] = row, group[-1]
                        exchanged = True
                        break
                if exchanged:
                    break
        if len(group) < 2 or len({x['id'] for x in group}) < 2:
            for row in group:
                row.update(state='WAIT', wait_reason='WAIT_FOR_2_TO_5_ACTOR_DELIVERY_GROUP')
            continue
        for row in group:
            row['batch'] = next_batch
        next_batch += 1
    return next_batch


class Preparation:
    def __init__(self, dependency_evidence=None):
        self.old, _ = raw_json(WORK / QUALITY / 'correction-plan-v05.json', ORIGINAL_PLAN_SHA)
        self.checkpoint, _ = raw_json(WORK / QUALITY / 'tool-quota-checkpoint-v01.json', CHECKPOINT_SHA)
        self.frozen, _ = raw_json(WORK / DOCS / 'whole-review-frozen-v01.json', FROZEN_SHA)
        self.states = {x['correction_candidate_id']: x for x in self.checkpoint['candidates']}
        self.allowed = {key for key, row in self.states.items() if row['status'] == NEVER and row['generation_attempts'] == 0}
        if len(self.allowed) != 106:
            raise ValueError('Pinned never-called allowlist must contain exactly106 candidates')
        self.old_by_slot = {(x['id'], x['direction'], x['role']): x for x in self.old['jobs']}
        self.staging, self.staging_sha = raw_json(REPO / 'data/pr122_legendary_parallel_staging.json')
        manifest_path = normalized(self.staging['corrections']['active_revision_library'])
        manifest, self.manifest_sha = raw_json(REPO / manifest_path, self.staging['corrections']['active_revision_library_sha256'])
        self.manifest_path = manifest_path
        self.active = {tuple(x['slot']): x for x in manifest['revisions']}
        for actor in self.staging['actors']:
            for draft in actor['drafts']:
                key = (draft['key'], draft['direction'], draft['role'])
                self.active.setdefault(key, draft)
        self.parent_evidence = {}
        self.dependency_evidence_ref = None
        if dependency_evidence:
            evidence, sha = raw_json(dependency_evidence)
            if evidence.get('frozen_review_sha256') != FROZEN_SHA:
                raise ValueError('Dependency evidence frozen SHA mismatch')
            self.parent_evidence = {tuple(x['slot']): x for x in evidence['parents']}
            self.dependency_evidence_ref = {'path': str(dependency_evidence), 'sha256': sha}

    def artifact(self, reference):
        relative = normalized(reference['path'])
        local = Path(relative) if relative.startswith('/') else WORK / relative
        return raw_json(local, reference['sha256'])

    def active_idle(self, actor, direction):
        revision = copy.deepcopy(self.active[('transform:' + actor, direction, 'idle')])
        idle, sha = raw_json(REPO / normalized(revision['record']), revision.get('record_sha256'))
        revision['record_sha256'] = sha
        resource = (REPO / normalized(revision['SpriteFrames'])).read_bytes()
        if digest(resource) != revision['SpriteFrames_sha256'] or idle['output_spriteframes_sha256'] != digest(resource):
            raise ValueError('Active idle resource SHA mismatch')
        return revision, idle, parse_frames(resource)

    def accepted_parent(self, job):
        parent = self.old_by_slot[(job['id'], job['direction'], 'idle')]
        parent_state = self.states[parent['correction_candidate_id']]
        if parent_state['status'] != NEVER or parent_state['generation_attempts'] != 0:
            return None, 'WAIT_PREVIOUSLY_ATTEMPTED_OR_HOLD_PARENT_NO_RETRY'
        slot = ('transform:' + job['id'], job['direction'], 'idle')
        proof = self.parent_evidence.get(slot)
        if not proof:
            return None, 'WAIT_NEW_PARENT_CAMERA_AND_HEALTHY_GUARD_EVIDENCE'
        revision, idle, frames = self.active_idle(job['id'], job['direction'])
        if normalized(proof['record']['path']) != normalized(revision['record']) or proof['record']['sha256'] != revision['record_sha256']:
            return None, 'WAIT_PARENT_NOT_EXACT_ACTIVE_RECORD'
        if normalized(proof['SpriteFrames']['path']) != normalized(revision['SpriteFrames']) or proof['SpriteFrames']['sha256'] != revision['SpriteFrames_sha256']:
            return None, 'WAIT_PARENT_RESOURCE_SHA_MISMATCH'
        review, _ = self.artifact(proof['quality_review'])
        if not valid_parent_review(review, slot, revision['record_sha256']):
            return None, 'WAIT_PARENT_REVIEW_DOES_NOT_CONFIRM_CAMERA_AND_BOTH_GUARDS'
        validation, _ = self.artifact(proof['validation'])
        matches = [x for x in validation.get('records', []) if tuple(x.get('slot', [])) == slot
                   and normalized(x.get('record', '')) == normalized(revision['record'])]
        if not matches or matches[-1].get('status') != 'PASS' or matches[-1].get('frames_reached') != 6:
            return None, 'WAIT_PARENT_GODOT_SIX_FRAME_PASS'
        remote, _ = self.artifact(proof['remote_receipt'])
        commit = remote.get('commit_sha') or remote.get('remote_sha')
        if remote.get('status') != 'REMOTE_SAVED' or not COMMIT.fullmatch(commit or ''):
            return None, 'WAIT_PARENT_REMOTE_SAVED'
        ancestor = subprocess.run(['git', '-C', str(REPO), 'merge-base', '--is-ancestor', commit, 'HEAD'], capture_output=True)
        if ancestor.returncode:
            return None, 'WAIT_PARENT_REMOTE_COMMIT_NOT_IN_ACTIVE_BRANCH'
        for reference in (proof['record'], proof['SpriteFrames'], proof['quality_review'], proof['validation']):
            relative = normalized(reference['path'])
            if Path(relative).is_absolute():
                absolute = Path(relative).resolve()
                if absolute.is_relative_to(WORK):
                    relative = absolute.relative_to(WORK).as_posix()
                elif absolute.is_relative_to(REPO):
                    relative = absolute.relative_to(REPO).as_posix()
                else:
                    return None, 'WAIT_PARENT_EVIDENCE_OUTSIDE_REPO'
            output = subprocess.run(['git', '-C', str(REPO), 'show', commit + ':' + relative], capture_output=True)
            if output.returncode or digest(output.stdout) != reference['sha256']:
                return None, 'WAIT_PARENT_EXACT_REMOTE_ARTIFACT_SHA'
        return (revision, idle, frames, proof), None

    def build(self, request_revision='v04', first_batch=294):
        if not re.fullmatch(r'v\d{2}', request_revision):
            raise ValueError('Use a new explicit request revision vNN')
        jobs, writes = [], {}
        for index, original in enumerate(self.old['jobs']):
            candidate = original['correction_candidate_id']
            if candidate not in self.allowed:
                continue
            if (original['id'], original['direction'], original['role']) == ('274', 'NE', 'attack'):
                raise ValueError('Moderation-blocked missing source can never be resumed')
            job = {k: original[k] for k in ('id', 'direction', 'role', 'correction_candidate_id', 'previous_source_sha256', 'representation')}
            job.update(original_plan_index=index, original_batch=original['batch'], original_representation=original['representation'],
                       state='READY', request=original['request'], corrected_idle_dependency=original['corrected_idle_dependency'])
            stem = 'transform_' + job['id'] + '-' + job['direction'] + '-' + job['role'] + '-correction-'
            prior_claims = list((WORK / QUALITY / 'generation-claims').glob(stem + 'v*.json'))
            prior_receipts = list((WORK / QUALITY / 'generation-receipts').glob(stem + 'v*.json'))
            prior_once_lock = WORK / QUALITY / 'generation-claims' / (stem + 'once.lock')
            if prior_claims or prior_receipts or prior_once_lock.exists():
                job.update(state='WAIT', wait_reason='WAIT_ALREADY_ATTEMPTED_NO_DUPLICATE_CALL',
                           existing_claims=[str(x) for x in prior_claims], existing_receipts=[str(x) for x in prior_receipts],
                           existing_once_lock=str(prior_once_lock) if prior_once_lock.exists() else None)
            elif original['corrected_idle_dependency']:
                accepted, reason = self.accepted_parent(original)
                if not accepted:
                    job.update(state='WAIT', wait_reason=reason)
                else:
                    revision, idle, frames, proof = accepted
                    q = bind_guard_request(original['config'], revision, idle, frames)
                    append_guard_reference(q, idle)
                    q['resume_parent_evidence'] = proof
                    job['request'] = str(QUALITY / 'requests' / (stem + request_revision + '.json'))
                    job['representation'] = q['correction_representation']
                    job['corrected_idle_dependency'] = False
                    writes[WORK / job['request']] = q
            elif (job['id'], job['direction'], job['role']) == ('113', 'W', 'attack'):
                q, _ = raw_json(WORK / original['request'])
                revision, idle, frames = self.active_idle('113', 'W')
                q = bind_guard_request(q, revision, idle, frames)
                append_guard_reference(q, idle)
                job['request'] = str(QUALITY / 'requests' / (stem + request_revision + '.json'))
                writes[WORK / job['request']] = q
            if job['state'] == 'READY':
                q = writes.get(WORK / job['request'])
                if q is None:
                    q, _ = raw_json(WORK / job['request'])
                raw = (json.dumps(q, ensure_ascii=False, indent=2) + '\n').encode() if WORK / job['request'] in writes else (WORK / job['request']).read_bytes()
                job['request_sha256'] = digest(raw)
                job['request_stem'] = Path(job['request']).stem
                job['newly_authored_poses_requested'] = q['newly_authored_poses_requested']
                job['reused_poses'] = q['reused_poses']
                if job['original_representation'] == 'mixed_draft_guard_reuse_v1' and (job['newly_authored_poses_requested'], job['reused_poses']) != (4, 2):
                    raise ValueError('An existing mixed action must preserve both guards')
                if job['original_representation'] == 'mixed_legacy_supplement_v1' and q.get('six_pose_config') != original['config']['six_pose_config']:
                    raise ValueError('Native sequence/timing must remain unchanged')
            jobs.append(job)
        next_batch = partition_jobs(jobs, first_batch)
        plan = {'schema': 'legendary-never-called-correction-resume-plan-v06',
                'original_plan_sha256': ORIGINAL_PLAN_SHA, 'checkpoint_sha256': CHECKPOINT_SHA,
                'frozen_review_sha256': FROZEN_SHA, 'allowed_candidate_ids': sorted(self.allowed),
                'excluded_prior_attempts': 20, 'moderation_blocked_source_excluded': ['transform:274', 'NE', 'attack'],
                'quota_not_before_utc': max(self.checkpoint['tool_reset_utc_range']),
                'generation_calls_authorized': False, 'generation_calls_started': 0,
                'active_staging_sha256': self.staging_sha, 'active_manifest': self.manifest_path,
                'active_manifest_sha256': self.manifest_sha, 'dependency_evidence': self.dependency_evidence_ref,
                'first_resume_batch': first_batch, 'next_unused_batch': next_batch,
                'counts': dict(collections.Counter(x['state'] for x in jobs)),
                'wait_reasons': dict(collections.Counter(x['wait_reason'] for x in jobs if x['state'] == 'WAIT')),
                'jobs': jobs, 'rules': {'request_actual_stem_is_claim_receipt_delivery_stem': True,
                                      'all_prior_versions_checked_before_claim': True,
                                      'healthy_guards_only_no_middle_pose_inference': True,
                                      'maximum_total_image_calls_per_candidate': 1}}
        return plan, writes


def authorize_claim(plan, job, now_utc, authorized):
    """Pure guard, tested without creating any real production claim."""
    if authorized is not True:
        return 'WAIT_ROOT_IMAGE_CALL_AUTHORIZATION'
    if now_utc < datetime.datetime.fromisoformat(plan['quota_not_before_utc']):
        return 'WAIT_QUOTA_RESET'
    if job['correction_candidate_id'] not in plan['allowed_candidate_ids'] or job['state'] != 'READY':
        return 'WAIT_NOT_NEVER_CALLED_READY_CANDIDATE'
    if (job['id'], job['direction'], job['role']) == ('274', 'NE', 'attack'):
        return 'WAIT_MODERATION_EXCLUDED'
    return None


def claim(plan_path, candidate, authorized):
    plan, plan_sha = raw_json(plan_path)
    if plan['checkpoint_sha256'] != CHECKPOINT_SHA or plan['original_plan_sha256'] != ORIGINAL_PLAN_SHA or plan['frozen_review_sha256'] != FROZEN_SHA:
        raise ValueError('Resume plan immutable source pins mismatch')
    checkpoint, _ = raw_json(WORK / QUALITY / 'tool-quota-checkpoint-v01.json', CHECKPOINT_SHA)
    never = {x['correction_candidate_id'] for x in checkpoint['candidates'] if x['status'] == NEVER and x['generation_attempts'] == 0}
    if set(plan['allowed_candidate_ids']) != never:
        raise ValueError('Resume plan may not add any previously attempted candidate')
    job = next(x for x in plan['jobs'] if x['correction_candidate_id'] == candidate)
    previous = next(x for x in checkpoint['candidates'] if x['correction_candidate_id'] == candidate)
    if any(job[key] != previous[key] for key in ('id', 'direction', 'role', 'previous_source_sha256')):
        raise ValueError('Resume job actor/direction/action/source differs from the immutable checkpoint')
    reason = authorize_claim(plan, job, datetime.datetime.now(datetime.timezone.utc), authorized)
    if reason:
        return {'status': 'WAIT', 'reason': reason, 'candidate': candidate}
    q, _ = raw_json(WORK / job['request'], job['request_sha256'])
    if q['correction_candidate_id'] != candidate or q['previous_source_sha256'] != job['previous_source_sha256']:
        raise ValueError('Request source/candidate differs from never-called plan')
    if [q['key'], q['direction'], q['role']] != ['transform:' + job['id'], job['direction'], job['role']] or q.get('maximum_generation_calls') != 1:
        raise ValueError('Request actor/direction/action or once-only limit mismatch')
    generation = q['generation_request']
    if set(generation) - {'prompt', 'referenced_image_paths', 'transparent_background'}:
        raise ValueError('Unsupported image-generation request parameter')
    stem = 'transform_' + job['id'] + '-' + job['direction'] + '-' + job['role'] + '-correction-'
    receipts = sorted((WORK / QUALITY / 'generation-receipts').glob(stem + 'v*.json'))
    claims = sorted((WORK / QUALITY / 'generation-claims').glob(stem + 'v*.json'))
    if receipts:
        return {'status': 'WAIT', 'reason': 'WAIT_PRIOR_RESULT_NO_DUPLICATE_CALL', 'receipts': [str(x) for x in receipts]}
    if claims:
        return {'status': 'WAIT', 'reason': 'WAIT_PRIOR_CLAIM_NO_DUPLICATE_CALL', 'claims': [str(x) for x in claims]}
    # A single canonical lock covers all request revisions and concurrent callers.
    lock = WORK / QUALITY / 'generation-claims' / (stem + 'once.lock')
    lock.parent.mkdir(parents=True, exist_ok=True)
    try:
        with lock.open('x') as handle:
            handle.write(candidate + '\n')
    except FileExistsError:
        return {'status': 'WAIT', 'reason': 'WAIT_CANONICAL_ONCE_LOCK_NO_DUPLICATE_CALL'}
    paths = actual_evidence_paths(job['request'])
    claim_path = WORK / paths['claim']
    metadata = {'candidate': candidate, 'id': job['id'], 'direction': job['direction'], 'role': job['role'],
                'request': job['request'], 'request_sha256': job['request_sha256'],
                'previous_source_sha256': job['previous_source_sha256'], 'plan': str(plan_path),
                'plan_sha256': plan_sha, 'maximum_generation_calls': 1,
                'status': 'IMAGE_CALL_ONCE_AUTHORIZED_NO_RETRY', 'started_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
    immutable_json(claim_path, metadata)
    return {'status': 'CLAIMED_ONCE', 'job': job, 'generation_request': generation,
            'claim': str(claim_path), 'receipt': str(WORK / paths['receipt']),
            'tool_result': str(WORK / paths['tool_result'])}


def write_maps(plan_path):
    plan, _ = raw_json(plan_path)
    ready = []
    batches = sorted({x['batch'] for x in plan['jobs'] if x['state'] == 'READY' and 'batch' in x})
    for batch in batches:
        members = [x for x in plan['jobs'] if x.get('batch') == batch]
        rows = []
        for job in members:
            receipt = WORK / QUALITY / 'generation-receipts' / (Path(job['request']).stem + '.json')
            if not receipt.exists():
                break
            row, _ = raw_json(receipt)
            if row.get('correction_candidate_id') != job['correction_candidate_id'] or row.get('request') != job['request'] or row.get('request_sha256') != job['request_sha256'] or row.get('batch') != batch:
                raise ValueError('Receipt/map request stem, candidate or batch mismatch')
            rows.append(row)
        if len(rows) == len(members):
            if not 2 <= len(rows) <= 5 or len({x['id'] for x in rows}) < 2:
                raise ValueError('Delivery map needs2..5 actors')
            target = WORK / f'quality-correction-batch{batch}-map.json'
            immutable_json(target, rows)
            ready.append({'batch': batch, 'rows': len(rows), 'ids': [x['id'] for x in rows], 'path': str(target)})
    return ready


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--dry-run', action='store_true')
    mode.add_argument('--prepare', action='store_true')
    mode.add_argument('--claim', metavar='CANDIDATE')
    mode.add_argument('--write-maps', action='store_true')
    parser.add_argument('--plan', type=Path)
    parser.add_argument('--dependency-evidence', type=Path)
    parser.add_argument('--request-revision', default='v04')
    parser.add_argument('--first-batch', type=int, default=294)
    parser.add_argument('--output-plan', default='correction-plan-v06.json')
    parser.add_argument('--root-authorized-image-call', action='store_true')
    args = parser.parse_args()
    if args.claim:
        if not args.plan:
            parser.error('--claim requires --plan')
        print(json.dumps(claim(args.plan, args.claim, args.root_authorized_image_call), ensure_ascii=False))
    elif args.write_maps:
        if not args.plan:
            parser.error('--write-maps requires --plan')
        print(json.dumps(write_maps(args.plan), ensure_ascii=False))
    else:
        preparation = Preparation(args.dependency_evidence)
        plan, writes = preparation.build(args.request_revision, args.first_batch)
        if args.prepare:
            if not re.fullmatch(r'correction-plan-v\d{2}\.json', args.output_plan):
                raise ValueError('Output must use a new versioned correction-plan-vNN.json name')
            for path, value in writes.items():
                immutable_json(path, value)
            immutable_json(WORK / QUALITY / args.output_plan, plan)
        print(json.dumps({'status': 'PREPARED_NO_GENERATION' if args.prepare else 'DRY_RUN_NO_WRITES',
                          'counts': plan['counts'], 'wait_reasons': plan['wait_reasons'],
                          'new_request_files': [str(x) for x in writes],
                          'first_batch': plan['first_resume_batch'], 'next_unused_batch': plan['next_unused_batch'],
                          'image_calls': 0, 'claims_reserved': 0, 'asset_or_ledger_mutations': 0}, ensure_ascii=False))


if __name__ == '__main__':
    main()
