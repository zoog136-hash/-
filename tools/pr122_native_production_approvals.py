#!/usr/bin/env python3
"""Read-only, proof-backed PR122 completion and approved-actor freeze gate.

Missing/empty approvals means zero completions, never permission to ignore flags
or counters. This module cannot approve, write data, or change a catalog. Paths
and JSON hashes are repository-relative; canonical hashes use ``json_digest``.
See scratch/pr122-completion-guard/schema.md outside the repository for the
integration contract. Callers should pass their already loaded manifest and
register, call require_mutable before writes, and assert_preserved before save.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re

import pr122_transform_motion_scope as motion_scope


MANIFEST = Path('docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json')
REGISTER = Path('data/pr122_native_locomotion_staging.json')
APPROVALS = Path('data/pr122_native_production_approvals.json')
DEFAULT_CATALOG = 'data/catalog_v19.json'
PROFILE_CATALOG = 'data/combat_animation_profiles.json'
DIRECTIONS = frozenset(('E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE'))
ROLES = frozenset(('idle', 'walk', 'run', 'attack', 'hit', 'death'))
TRACK_KEYS = frozenset((d, r) for d in DIRECTIONS for r in ROLES)
QUALITY_CHECKS = ('identity_equipment', 'compass8', 'anatomy_continuity',
                  'motion_specificity', 'loops_transitions', 'attack_contact',
                  'hit_recovery', 'death_irreversibility', 'runtime_scale_footing')
MAIN_CHECKS = ('actual_Main_scene', 'default_catalog_lookup', 'all_48_tracks',
               'animation_playback', 'catalog_record_unchanged')
SHA = re.compile(r'[0-9a-f]{64}\Z')
ACTOR_KEY = re.compile(r'transform:([0-9]+)\Z')


class ApprovalError(ValueError):
    """Unproven completion, changed approved data, or a forbidden mutation."""


def require(condition, message):
    if not condition:
        raise ApprovalError(message)


def json_digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True,
                                    separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def default_main_marker(key, track_count=48):
    return (f'PR122_NATIVE_DEFAULT_MAIN_PASS key={key} tracks={track_count} poses={track_count * 6} '
            'candidate_injection=0')


class _Reader:
    def __init__(self, root):
        self.root = Path(root).resolve()
        self.json_cache = {}
        self.digest_cache = {}

    def file(self, value):
        require(isinstance(value, str) and bool(value), 'Missing repository file path')
        name = value.removeprefix('res://')
        path = Path(name)
        require(not path.is_absolute() and '..' not in path.parts and path.parts,
                'Unsafe repository file path')
        result = self.root / path
        require(result.is_file() and result.resolve().is_relative_to(self.root),
                f'Missing or escaped proof/artifact: {name}')
        require(not any(p.is_symlink() for p in (result, *result.parents)
                        if p != self.root.parent), 'Symlinks cannot authorize production')
        return result

    def digest(self, value):
        path = self.file(value)
        if path not in self.digest_cache:
            digest = hashlib.sha256()
            with path.open('rb') as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(block)
            self.digest_cache[path] = digest.hexdigest()
        return self.digest_cache[path]

    def json(self, value):
        path = self.file(value)
        if path not in self.json_cache:
            raw = path.read_bytes()
            self.digest_cache[path] = hashlib.sha256(raw).hexdigest()
            self.json_cache[path] = json.loads(raw)
        return self.json_cache[path]

    def pin(self, pin):
        require(isinstance(pin, dict) and set(pin) == {'path', 'sha256'}, 'Require an exact file/SHA pin')
        require(isinstance(pin['sha256'], str) and SHA.fullmatch(pin['sha256']), 'Invalid pinned SHA256')
        require(self.digest(pin['path']) == pin['sha256'], f'Changed pinned file: {pin["path"]}')
        return self.file(pin['path'])

    def json_pin(self, pin):
        self.pin(pin)
        value = self.json(pin['path'])
        require(self.digest(pin['path']) == pin['sha256'], 'Pinned JSON changed while being read')
        require(isinstance(value, dict), 'Pinned certificate/evidence must be a JSON object')
        return value


def _selection(reader, key, actor, manifest):
    require(ACTOR_KEY.fullmatch(key) is not None, 'Unsupported approved actor key')
    required_tracks = motion_scope.required_tracks(reader.root, key)
    tracks = actor.get('tracks')
    require(isinstance(tracks, list) and len(required_tracks) <= len(tracks) <= 48
            and type(actor.get('native_track_count')) is int and actor['native_track_count'] == len(tracks)
            and type(actor.get('native_pose_count')) is int and actor['native_pose_count'] == len(tracks) * 6,
            'A completed actor requires every mandatory track and six poses per actual track')
    selected = {}
    for table in ('selected_locomotion_sheets', 'selected_detailed_action_sheets'):
        for slot, source in manifest.get(table, {}).items():
            if slot.startswith(key + ':'):
                require(slot not in selected, 'Duplicate selected identity across source tables')
                selected[slot] = source
    require(len(selected) == len(tracks), 'Completed actor must select every actual source identity')
    raws = {}
    for raw in manifest.get('raw_images', []):
        if raw.get('key') == key:
            identity = (raw.get('direction'), raw.get('role'), raw.get('source'))
            require(identity not in raws, 'Duplicate raw source identity')
            raws[identity] = raw
    seen, rgba_seen, result = set(), set(), []
    for track in tracks:
        identity = (track.get('direction'), track.get('role'))
        require(identity in TRACK_KEYS and identity not in seen, 'Missing/duplicate native track')
        seen.add(identity)
        direction, role = identity
        source, source_sha = track.get('source'), track.get('source_sha256')
        require(selected.get(f'{key}:{direction}:{role}') == source, 'Selected source drift')
        raw = raws.get((direction, role, source), {})
        require(isinstance(source_sha, str) and SHA.fullmatch(source_sha), 'Invalid source hash')
        require(raw.get('sha256') == source_sha and type(raw.get('requested_poses')) is int
                and raw['requested_poses'] == 6
                and raw.get('geometry', {}).get('status') == 'GEOMETRY_PASS',
                'Completed source lacks pinned strict geometry PASS')
        require(type(raw.get('bytes')) is int and reader.file(source).stat().st_size == raw['bytes'],
                'Source byte count drift')
        require(reader.digest(source) == source_sha and reader.digest(track.get('texture')) == source_sha,
                'Source/production texture changed')
        geometry = track.get('geometry', {})
        frames = geometry.get('frames', [])
        require(len(frames) == 6 and type(geometry.get('distinct_pixel_frames')) is int
                and geometry['distinct_pixel_frames'] == 6,
                'Completed track must retain six distinct sourced frames')
        rgba = [frame.get('rgba_sha256') for frame in frames]
        require(all(isinstance(h, str) and SHA.fullmatch(h) for h in rgba)
                and len(set(rgba)) == 6 and not rgba_seen.intersection(rgba),
                f'Completed actor requires {len(tracks) * 6} distinct RGBA frame hashes')
        rgba_seen.update(rgba)
        result.append(dict(direction=direction, role=role, source=source, source_sha256=source_sha,
                           texture=track['texture'], source_geometry_sha256=json_digest(raw['geometry']),
                           geometry_sha256=json_digest(geometry),
                           frame_rgba_sha256=rgba))
    require(required_tracks.issubset(seen) and len(rgba_seen) == len(tracks) * 6,
            'Incomplete detailed animation coverage')
    return sorted(result, key=lambda t: (t['direction'], t['role']))


def _catalog(reader, key):
    for path, constant, expected in (('scripts/world.gd', 'CATALOG_PATH', DEFAULT_CATALOG),
                                      ('scripts/animation/animation_catalog.gd', 'PROFILE_PATH', PROFILE_CATALOG)):
        declaration = re.findall(r'^const\s+' + constant + r'(?:\s*:\s*String)?\s*=\s*"([^"]+)"\s*$',
                                 reader.file(path).read_text(), re.MULTILINE)
        require(declaration == ['res://' + expected], 'Actual runtime catalog source path drift')
    source_id = ACTOR_KEY.fullmatch(key).group(1)
    catalog = reader.json(DEFAULT_CATALOG)
    matches = [r for r in catalog.get('변신', []) if str(r.get('sourceId')) == source_id]
    require(len(matches) == 1, 'Require exactly one actor in the actual default catalog')
    record = matches[0]
    inline = record.get('animation_profile', {})
    require(isinstance(inline, dict), 'Default catalog inline profile must be a dictionary')
    profiles = reader.json(PROFILE_CATALOG).get('profiles', {})
    require(isinstance(profiles.get(key), dict), 'Missing production profile catalog entry')
    effective = dict(profiles[key])
    effective.update(inline)  # animation_catalog.gd uses the same shallow override.
    pins = dict(default_catalog=dict(path=DEFAULT_CATALOG, group='변신', source_id=source_id,
                                     record_sha256=json_digest(record),
                                     inline_profile_sha256=json_digest(inline)),
                profile_catalog=dict(path=PROFILE_CATALOG, key=key,
                                     record_sha256=json_digest(profiles[key])),
                effective_profile_sha256=json_digest(effective))
    return pins, effective


def _actor_description(reader, key, actor, manifest):
    selection = _selection(reader, key, actor, manifest)
    pins, effective = _catalog(reader, key)
    for field, hash_field, output in (('frames', 'frames_sha256', 'production_frames'),
                                     ('native_profile', 'native_profile_sha256', 'production_profile')):
        pin = dict(path=actor.get(field), sha256=actor.get(hash_field))
        reader.pin(pin)
        pins[output] = pin
    require(effective.get('frames_path') == actor['frames'] and effective.get('layout') == 'directional8',
            'Actual default profile does not use these production directional frames')
    profile_text = reader.file(actor['native_profile']).read_text()
    frame_paths = re.findall(r'^frames_path\s*=\s*"([^"]+)"\s*$', profile_text, re.MULTILINE)
    require(frame_paths == [actor['frames']], 'Production NativeMotionProfile targets different frames')
    if len(motion_scope.required_tracks(reader.root, key)) < 48:
        pins['motion_requirements'] = dict(
            policy=dict(path=motion_scope.POLICY.as_posix(), sha256=reader.digest(motion_scope.POLICY.as_posix())),
            required_roles=sorted(motion_scope.required_roles(reader.root, key)),
            required_track_count=len(motion_scope.required_tracks(reader.root, key)),
            required_death_directions=list(motion_scope.required_directions(reader.root, key, 'death')),
            authored_track_count=len(selection), authored_pose_count=len(selection) * 6)
    pins.update(source_selection_sha256=json_digest(selection), actor_record_sha256=json_digest(actor))
    return pins, selection


def describe_actor(root, key, *, manifest=None, register=None):
    """Return pins + all actual source descriptors; read-only helper for a real approval author.

    Does not grant approval or check completion counters. The default catalog must
    already target the exact candidate frames before this helper can describe it.
    """
    reader = _Reader(root)
    manifest = reader.json(str(MANIFEST)) if manifest is None else manifest
    register = reader.json(str(REGISTER)) if register is None else register
    require(key in register.get('actors', {}), 'Unknown actor')
    pins, selection = _actor_description(reader, key, register['actors'][key], manifest)
    return dict(pins=pins, tracks=selection)


def _quality(reader, pin, key, expected, selection):
    evidence = reader.json_pin(pin)
    require(evidence.get('schema') == 'pr122-native-independent-quality-v1'
            and evidence.get('key') == key and evidence.get('status') == 'PASS'
            and evidence.get('independent') is True
            and isinstance(evidence.get('reviewer'), str) and evidence['reviewer'].strip()
            and evidence.get('source_selection_sha256') == expected['source_selection_sha256'],
            'Missing independent full-actor PASS evidence')
    require(all(evidence.get('checks', {}).get(c) == 'PASS' for c in QUALITY_CHECKS),
            'Independent quality review has an incomplete/failed required check')
    require(all(evidence.get(field) == expected[field] for field in
                ('production_frames', 'production_profile', 'effective_profile_sha256')),
            'Quality evidence does not bind the actual production frames/profile/globals')
    tracks = evidence.get('tracks', [])
    require(isinstance(tracks, list) and len(tracks) == len(selection),
            f'Quality evidence must review all {len(selection)} tracks')
    reviewed = {}
    for row in tracks:
        identity = (row.get('direction'), row.get('role'))
        require(identity in TRACK_KEYS and identity not in reviewed and row.get('status') == 'PASS',
                'Quality evidence contains failed/duplicate/missing tracks')
        findings = row.get('visual_findings')
        require(isinstance(findings, list) and findings
                and all(isinstance(f, str) and f.strip() for f in findings),
                'Quality evidence requires actual text findings, not a bare PASS claim')
        reviewed[identity] = row
    require(set(reviewed) == {(s['direction'], s['role']) for s in selection},
            'Quality review must bind every actual track identity')
    for source in selection:
        row = reviewed[(source['direction'], source['role'])]
        require(all(row.get(field) == source[field] for field in
                    ('source_sha256', 'source_geometry_sha256', 'geometry_sha256', 'frame_rgba_sha256')),
                'Quality PASS evidence reviews different pixels/geometry')


def _default_main(reader, pin, key, expected):
    evidence = reader.json_pin(pin)
    require(evidence.get('schema') == 'pr122-native-default-main-v1'
            and evidence.get('key') == key and evidence.get('status') == 'PASS'
            and evidence.get('entrypoint') == 'ACTUAL_MAIN_DEFAULT_CATALOG'
            and evidence.get('scene') == 'res://Main.tscn'
            and evidence.get('candidate_injection') is False
            and evidence.get('runtime_profile_override') is False
            and evidence.get('engine_version') == '4.7.2.stable.official.ed1daf0bf',
            'Require actual Main DEFAULT evidence, never injected candidate evidence')
    require(evidence.get('pins') == expected, 'Default Main evidence pins different production data')
    checks = MAIN_CHECKS if 'motion_requirements' not in expected else tuple(
        'all_required_tracks' if c == 'all_48_tracks' else c for c in MAIN_CHECKS)
    require(all(evidence.get('checks', {}).get(c) == 'PASS' for c in checks),
            'Actual default Main required checks did not all pass')
    path = reader.pin(evidence.get('log'))
    require(path.stat().st_size <= 2 * 1024 * 1024, 'Default Main evidence log exceeds bounded review size')
    log = path.read_text()
    track_count = expected.get('motion_requirements', {}).get('authored_track_count', 48)
    require(default_main_marker(key, track_count) in log.splitlines() and 'PR122_NATIVE_MAIN_PASS' not in log,
            'Pinned log lacks the actual default-catalog PASS marker or is a candidate run')


class ApprovalState:
    """A validated completion snapshot, used to freeze approved actors on writes."""
    def __init__(self, root, manifest, register, approvals, registry_digest=None):
        self.root = Path(root).resolve()
        self.manifest = manifest
        self.completed_count = len(approvals)
        self.approved_keys = frozenset(approvals)
        self._actor_hashes = {}
        self._certificates = dict(approvals)
        self._registry_digest = registry_digest
        self._validate(manifest, register)

    def _validate(self, manifest, register):
        reader = _Reader(self.root)
        for document, field, total in ((manifest, 'mythic_detail_complete', 'mythic_detail_total'),
                                        (register, 'detailed_complete', 'detailed_total')):
            require(type(document.get('approved_history_preserved')) is int
                    and document['approved_history_preserved'] == 405, 'Preserved approval history must remain 405')
            require(type(document.get(field)) is int and document[field] == self.completed_count,
                    'Completion counters must equal the proof-backed approved actor count')
            require(type(document.get(total)) is int and document[total] == 31, 'Detailed target total changed')
        actors = register.get('actors')
        require(isinstance(actors, dict) and self.approved_keys.issubset(actors), 'Approved actor record is missing')
        for key, actor in actors.items():
            approved = key in self.approved_keys
            require(actor.get('production_connected') is approved and actor.get('detailed_completed') is approved,
                    f'Unbacked or missing completion flags: {key}')
            require(type(actor.get('completed_added')) is int and actor['completed_added'] == int(approved),
                    f'Unbacked completed_added: {key}')
            if not approved:
                continue
            require(actor.get('status') == 'APPROVED_DETAILED_PRODUCTION'
                    and actor.get('visual_review') == 'PASS' and actor.get('timing_review') == 'PASS'
                    and actor.get('verification', {}).get('actual_Main_default_catalog') == 'PASS',
                    'Approved actor still has unresolved production/quality status')
            certificate = reader.json_pin(self._certificates[key])
            require(certificate.get('schema') == 'pr122-native-production-certificate-v1'
                    and certificate.get('key') == key and certificate.get('status') == 'APPROVED'
                    and type(certificate.get('approved_history_preserved')) is int
                    and certificate['approved_history_preserved'] == 405,
                    'Invalid approval certificate identity/status/history')
            pins, selection = _actor_description(reader, key, actor, manifest)
            require(certificate.get('pins') == pins, 'Approved production source/catalog/profile/record drift')
            _quality(reader, certificate.get('quality_evidence'), key, pins, selection)
            _default_main(reader, certificate.get('default_main_evidence'), key, pins)
            self._actor_hashes[key] = pins['actor_record_sha256']

    def require_mutable(self, key, operation='stage'):
        require(key not in self.approved_keys, f'Approved actor is frozen; cannot {operation}: {key}')

    def bind_keys(self, register, only_key=None):
        if only_key is not None:
            self.require_mutable(only_key, 'rebind')
            require(only_key in register['actors'], 'Unknown actor requested for binding')
            return (only_key,)
        return tuple(key for key in register['actors'] if key not in self.approved_keys)

    def assert_preserved(self, manifest, register):
        """Recheck live files/pins + in-memory counters before saving another actor."""
        reader = _Reader(self.root)
        current = reader.digest(str(APPROVALS)) if (self.root / APPROVALS).exists() else None
        require(current == self._registry_digest, 'Approval registry changed during this operation')
        for key, digest in self._actor_hashes.items():
            require(json_digest(register.get('actors', {}).get(key)) == digest,
                    f'Approved actor changed while staging another actor: {key}')
        self._validate(manifest, register)  # new reader: detect file edits after the first check.


def load_state(root, *, manifest=None, register=None):
    """Validate once per operation; reuse caller's JSON objects instead of reloading."""
    reader = _Reader(root)
    manifest = reader.json(str(MANIFEST)) if manifest is None else manifest
    register = reader.json(str(REGISTER)) if register is None else register
    path = reader.root / APPROVALS
    value = reader.json(str(APPROVALS)) if path.exists() else {}
    require(isinstance(value, dict), 'Production approvals must be a JSON object')
    if not value:
        approvals = {}
    else:
        require(isinstance(value, dict) and value.get('schema') == 'pr122-native-production-approvals-v1'
                and type(value.get('approved_history_preserved')) is int
                and value['approved_history_preserved'] == 405,
                'Invalid production approval registry/history')
        approvals = value.get('approved_actors')
        require(isinstance(approvals, dict), 'Invalid approved_actors map')
    return ApprovalState(root, manifest, register, approvals,
                         reader.digest(str(APPROVALS)) if path.exists() else None)
