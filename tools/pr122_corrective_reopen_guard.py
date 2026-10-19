"""Authorize a new, evidence-pinned HOLD without discarding earlier PASS history.

This module does not write files, select art, run tests, or alter approvals. The
corrective integrator remains responsible for its existing geometry and Player
checks. A caller may register the result of ``build_reopened_source_hold`` in the
matching visual HOLD; only ``resolve_reopened_source_hold`` changes that entry.
"""
import copy
import hashlib
import json
from pathlib import Path, PurePosixPath
import re


SCHEMA = 'pr122-reopened-source-hold-v1'
EVIDENCE_PREFIX = PurePosixPath('docs/remake/evidence/pr122-mythic-detailed')
CONFIRMED_STATUSES = frozenset({
    'CONFIRMED_NEW_SOURCE_CAMERA_HOLD_REOPEN_PRIOR_PASS_HISTORY_PRESERVED',
    'CONFIRMED_NEW_SOURCE_QUALITY_HOLD_REOPEN_PRIOR_PASS_HISTORY_PRESERVED',
})
IDENTITY_FIELDS = ('key', 'direction', 'role')
PIN_FIELDS = ('id', 'source_sha256', 'evidence_sha256', 'prior_corrections_sha256')
DIRECTIONS = frozenset(('N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'))
ROLES = frozenset(('idle', 'walk', 'run', 'attack', 'hit', 'death'))


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_sha256(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                     separators=(',', ':')).encode()).hexdigest()


def slot_for(request):
    require(all(isinstance(request.get(k), str) and request[k] for k in IDENTITY_FIELDS),
            'Require an explicit corrective source identity')
    return ':'.join(request[k] for k in IDENTITY_FIELDS)


def repo_file(root, value, *, evidence=False):
    require(isinstance(value, str) and bool(value), 'Require a repository-relative file')
    relative = PurePosixPath(value)
    require(not relative.is_absolute() and '..' not in relative.parts
            and relative.as_posix() == value and '\\' not in value,
            'Require a normalized repository-relative file')
    if evidence:
        require(relative.is_relative_to(EVIDENCE_PREFIX) and relative.suffix == '.json',
                'New HOLD evidence must be a durable JSON under the PR122 evidence directory')
    root = root.resolve()
    path = root / value
    require(not any(part.is_symlink() for part in (path, *path.parents) if part != root.parent),
            'Never follow evidence or source symlinks')
    require(path.is_file() and path.resolve().is_relative_to(root), 'Require an existing repository file')
    return path


def selected_source(manifest, request):
    slot = slot_for(request)
    values = [manifest.get(table, {}).get(slot) for table in
              ('selected_locomotion_sheets', 'selected_detailed_action_sheets')]
    values = [value for value in values if value is not None]
    require(len(values) == 1, 'Require exactly one current selected source')
    return values[0]


def matching_hold(manifest, request, source):
    holds = [hold for hold in manifest.get('visual_quality_holds', [])
             if hold.get('key') == request['key'] and hold.get('status') == 'HOLD'
             and (hold.get('scope') == 'all_native_clips' or source in hold.get('sources', []))]
    require(len(holds) == 1, 'Require one unresolved visual HOLD for this actor/source')
    return holds[0]


def _prior_pass(hold, slot, source):
    return [record for record in hold.get('corrections', [])
            if isinstance(record, dict) and record.get('slot') == slot and record.get('replacement_source') == source
            and record.get('source_visual_status') == 'PASS'
            and record.get('geometry_and_actual_Player') == 'PASS']


def _evidence(root, hold, entry, request):
    path = repo_file(root, entry.get('evidence'), evidence=True)
    require(path.stat().st_size <= 128 * 1024, 'New HOLD evidence metadata is unexpectedly large')
    require(re.fullmatch('[0-9a-f]{64}', entry.get('evidence_sha256', '')) is not None
            and digest(path) == entry['evidence_sha256'], 'New HOLD evidence bytes/hash changed')
    evidence = json.loads(path.read_text())
    require(evidence.get('status') in CONFIRMED_STATUSES
            and evidence.get('no_actor_approval') is True
            and evidence.get('no_prior_pass_deleted') is True,
            'Evidence must explicitly confirm a NEW HOLD and preserve approval/PASS history')
    require(all(evidence.get(k) == request[k] for k in IDENTITY_FIELDS)
            and evidence.get('source') == entry['source']
            and evidence.get('source_sha256') == entry['source_sha256'],
            'New HOLD evidence identity/source pins differ')
    require(type(evidence.get('phase')) is int and 0 <= evidence['phase'] < 6,
            'New HOLD evidence must identify an actual native phase')
    findings = evidence.get('visual_findings')
    require(isinstance(findings, list) and findings
            and all(isinstance(text, str) and text.strip() for text in findings),
            'New HOLD evidence requires explicit private text findings')
    old_review_hashes = {record.get('source_review_sha256') for record in hold.get('corrections', [])}
    require(entry['evidence_sha256'] not in old_review_hashes,
            'A previous PASS review cannot be reused as new HOLD evidence')
    return evidence


def _validate_entry(root, hold, entry, request, source):
    slot = slot_for(request)
    require(hold.get('key') == request['key'] and hold.get('status') == 'HOLD',
            'Reopened HOLD belongs to another actor or resolved HOLD')
    require(entry.get('schema') == SCHEMA and entry.get('status') == 'HOLD'
            and entry.get('slot') == slot and entry.get('source') == source
            and all(entry.get(k) == request[k] for k in IDENTITY_FIELDS),
            'Reopened HOLD does not pin this exact selected source/slot')
    require(isinstance(entry.get('reason'), str) and entry['reason'].strip(),
            'Reopened HOLD needs a concrete reason')
    require(_prior_pass(hold, slot, source), 'A reopened HOLD requires retained earlier source/Player PASS')
    source_path = repo_file(root, source)
    require(digest(source_path) == entry.get('source_sha256'), 'Reopened selected source bytes/hash changed')
    history = hold.get('corrections', [])
    count = entry.get('prior_corrections_count')
    require(isinstance(history, list) and type(count) is int and count > 0 and count <= len(history)
            and canonical_sha256(history[:count]) == entry.get('prior_corrections_sha256'),
            'Earlier correction history was changed or removed')
    suffix = history[count:]
    require(all(isinstance(record, dict) and isinstance(record.get('slot'), str)
                and len(parts := record['slot'].rsplit(':', 2)) == 3
                and parts[0] == request['key'] and parts[1] in DIRECTIONS and parts[2] in ROLES
                for record in suffix), 'Appended correction history has an invalid actor/slot')
    require(not any(record['slot'] == slot for record in suffix),
            'This reopened slot has already advanced; do not reuse its authorization')
    _evidence(root, hold, entry, request)
    expected_id = canonical_sha256({key: entry[key] for key in
                                   ('slot', 'source', 'source_sha256', 'evidence', 'evidence_sha256',
                                    'prior_corrections_sha256')})
    require(entry.get('id') == expected_id, 'Reopened HOLD authorization identity changed')
    return entry


def build_reopened_source_hold(root, manifest, request, *, evidence, evidence_sha256, reason):
    """Return a validated additive entry; leave the manifest and files untouched."""
    source = selected_source(manifest, request)
    hold = matching_hold(manifest, request, source)
    slot = slot_for(request)
    require(not any(item.get('status') == 'HOLD' and item.get('slot') == slot
                    for item in hold.get('reopened_source_holds', [])),
            'This slot already has an active reopened HOLD')
    require(not any(item.get('evidence_sha256') == evidence_sha256
                    for item in hold.get('reopened_source_holds', [])),
            'Do not reuse previously consumed HOLD evidence')
    entry = dict(schema=SCHEMA, status='HOLD', slot=slot, source=source,
                 source_sha256=digest(repo_file(root, source)), evidence=evidence,
                 evidence_sha256=evidence_sha256, reason=reason,
                 prior_corrections_count=len(hold.get('corrections', [])),
                 prior_corrections_sha256=canonical_sha256(hold.get('corrections', [])),
                 **{key: request[key] for key in IDENTITY_FIELDS})
    entry['id'] = canonical_sha256({key: entry[key] for key in
                                   ('slot', 'source', 'source_sha256', 'evidence', 'evidence_sha256',
                                    'prior_corrections_sha256')})
    _validate_entry(root, hold, entry, request, source)
    return entry


def authorize_selected_replacement(root, manifest, request, hold, source):
    """Return a pin token only for an exact independently reopened prior PASS."""
    require(selected_source(manifest, request) == source
            and matching_hold(manifest, request, source) is hold,
            'Selected source or visual HOLD changed')
    previously_corrected = any(isinstance(record, dict) and record.get('replacement_source') == source
                               for record in hold.get('corrections', []))
    entries = [entry for entry in hold.get('reopened_source_holds', [])
               if entry.get('status') == 'HOLD' and entry.get('slot') == slot_for(request)
               and entry.get('source') == source]
    if not previously_corrected and not entries:
        require('reopened_source_hold' not in request, 'Unexpected reopened authorization on an original source')
        return None
    require(len(entries) == 1, 'Selected corrective source already passed; require one NEW evidence-pinned HOLD')
    entry = _validate_entry(root, hold, entries[0], request, source)
    token = {key: entry[key] for key in PIN_FIELDS}
    require(request.get('reopened_source_hold', token) == token,
            'Corrective request reopened authorization differs')
    return token


def resolve_reopened_source_hold(root, manifest, hold, request, actor, correction):
    """Resolve the exact entry after strict geometry and actual Player pass.

    Call before appending ``correction``. All validation precedes mutation; prior
    history and the actor's approval/connection fields are never changed here.
    """
    previous = request['replaces_selected_source']
    previously_corrected = any(isinstance(record, dict) and record.get('replacement_source') == previous
                               for record in hold.get('corrections', []))
    if not previously_corrected:
        require('reopened_source_hold' not in request, 'Unexpected reopened authorization')
        return None
    token = request.get('reopened_source_hold')
    require(isinstance(token, dict) and set(token) == set(PIN_FIELDS),
            'Previously corrected source requires its pinned reopened authorization')
    entries = [entry for entry in hold.get('reopened_source_holds', []) if entry.get('id') == token['id']]
    require(len(entries) == 1, 'Reopened authorization is missing or duplicated')
    entry = _validate_entry(root, hold, entries[0], request, previous)
    require(token == {key: entry[key] for key in PIN_FIELDS}, 'Reopened request pins changed')
    require(selected_source(manifest, request) == request.get('output_source')
            and request.get('output_source') != previous,
            'Require the newly selected replacement source')
    output = repo_file(root, request['output_source'])
    require(digest(output) == request.get('output_sha256'), 'Replacement source bytes/hash changed')
    verification = actor.get('verification', {})
    require(request.get('status') == 'GENERATED_GEOMETRY_PASS_NOT_APPROVED'
            and all(verification.get(key) == 'PASS' for key in
                    ('source_sha256_and_saved_geometry', 'spriteframes_parse_and_all_frame_cycles',
                     'required_engine_4_7_2', 'actual_Player_scene_form_api')),
            'Resolve only after strict geometry, engine, frame cycles and actual Player PASS')
    tracks = [track for track in actor.get('tracks', [])
              if track.get('direction') == request['direction'] and track.get('role') == request['role']]
    require(len(tracks) == 1 and tracks[0].get('source') == request['output_source']
            and tracks[0].get('source_sha256') == request['output_sha256'],
            'Player track does not pin this replacement')
    geometry = tracks[0].get('geometry', {})
    rows = [frame.get('row') for frame in geometry.get('frames', [])]
    require(geometry.get('distinct_pixel_frames') == 6
            and len(rows) == 6 and all(type(row) is int for row in rows)
            and set(rows) == set(range(6)),
            'Require six distinct strict native poses')
    require(correction.get('slot') == slot_for(request)
            and correction.get('previous_source') == previous
            and correction.get('replacement_source') == request['output_source']
            and correction.get('source_visual_status') == 'PASS'
            and correction.get('geometry_and_actual_Player') == 'PASS'
            and type(correction.get('actor_approval_added')) is int
            and correction['actor_approval_added'] == 0,
            'Resolution must preserve the exact new correction and add no actor approval')
    resolution = dict(replacement_source=request['output_source'], replacement_sha256=request['output_sha256'],
                      correction_sha256=canonical_sha256(correction),
                      source_review_sha256=correction.get('source_review_sha256'),
                      geometry_and_actual_Player='PASS', actor_approval_added=0)
    entry.update(status='RESOLVED', resolution=copy.deepcopy(resolution))
    return resolution
