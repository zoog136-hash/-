#!/usr/bin/env python3
"""Prepare the saved PR122 native tracks, without approving or switching actors.

The complete-character importer keeps its full eight-view/five-role gate. This
separate staging operation emits only existing, hash-pinned native tracks; it
cannot manufacture missing views, roles, aliases, or approvals.
"""
import argparse
import ast
from copy import deepcopy
from contextlib import contextmanager
from contextvars import ContextVar
import hashlib
import json
from pathlib import Path
import subprocess

import import_original_based_motion as importer
from pr122_reviewed_source_regions import apply_reviewed_regions
import pr122_reviewed_runtime_layout as reviewed_layout
import pr122_transform_motion_scope as motion_scope
import pr122_native_production_approvals as production_approvals


SOURCE_MANIFEST = Path('docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json')
REGISTER = Path('data/pr122_native_locomotion_staging.json')
ACTORS = {'transform:393': 'halpas_393', 'transform:267': 'girtas_267',
          'transform:413': 'thunder_female_413', 'transform:412': 'transform_412',
          'transform:130': 'transform_130', 'transform:133': 'transform_133', 'transform:135': 'transform_135', 'transform:137': 'transform_137', 'transform:139': 'transform_139', 'transform:141': 'transform_141', 'transform:174': 'transform_174', 'transform:189': 'transform_189', 'transform:212': 'transform_212', 'transform:224': 'transform_224', 'transform:242': 'transform_242', 'transform:346': 'transform_346', 'transform:367': 'transform_367', 'transform:399': 'transform_399', 'transform:411': 'transform_411'}
CORE_ROLES = ('idle', 'attack', 'hit', 'death')
NATIVE_ROLES = ('walk', 'run', *CORE_ROLES)
ROLE_SECONDS = dict(idle=1.2, walk=.48, run=.48, attack=.42, hit=.22, death=.65)
_SOURCE_ANALYSIS_CONTEXT = ContextVar('pr122_source_analysis_context', default=None)


@contextmanager
def source_analysis_context(root, key, reuse_context, analyzed_sources):
    """Keep the existing three-argument guarded staging wrappers compatible."""
    token = _SOURCE_ANALYSIS_CONTEXT.set({'root': root.resolve(), 'key': key,
        'reuse': reuse_context, 'fresh': analyzed_sources})
    try:
        yield
    finally:
        _SOURCE_ANALYSIS_CONTEXT.reset(token)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def preserve_write(path, content):
    """A staged resource is immutable: refuse conflicting existing bytes."""
    if path.exists():
        if path.read_bytes() != content:
            raise ValueError(f'Existing output differs; preserve and investigate: {path}')
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def _json_sha(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'),
                                     ensure_ascii=False).encode()).hexdigest()


def _region_analysis_ast(data):
    # This optional pre-render part guard never participates in PNG analysis.
    tree = ast.parse(data)
    tree.body = [node for node in tree.body if not isinstance(node, ast.FunctionDef)
                 or node.name != 'require_native_source_part_ownership']
    return ast.dump(tree, include_attributes=False)


def _analysis_nodes(data):
    tree = ast.parse(data)
    helper = next((node for node in tree.body if isinstance(node, ast.FunctionDef)
                   and node.name == '_analyze_source_geometry'), None)
    if helper is not None:
        return helper.body[:-1]  # The return only transports the unchanged result.
    stage_function = next(node for node in tree.body if isinstance(node, ast.FunctionDef)
                          and node.name == 'stage')
    loop = next(node for node in stage_function.body if isinstance(node, ast.For)
                and isinstance(node.target, ast.Tuple)
                and [part.id for part in node.target.elts] == ['identity', 'source'])
    result = []
    started = False
    for node in loop.body:
        if isinstance(node, ast.Assign) and any(isinstance(part, ast.Name) and part.id == 'canvas'
                                                for part in node.targets):
            started = True
        if (isinstance(node, ast.Expr) and isinstance(node.value, ast.Call)
                and isinstance(node.value.func, ast.Attribute)
                and isinstance(node.value.func.value, ast.Name)
                and node.value.func.value.id == 'tracks'):
            break
        if started:
            result.append(node)
    return result


def _analysis_versions(root):
    return {
        'analysis': _json_sha([ast.dump(node, include_attributes=False)
                               for node in _analysis_nodes(Path(__file__).read_text())]),
        'importer': digest(root / 'tools/import_original_based_motion.py'),
        'reviewed_regions': hashlib.sha256(_region_analysis_ast(
            (root / 'tools/pr122_reviewed_source_regions.py').read_text()).encode()).hexdigest(),
        'runtime_layout': digest(root / 'tools/pr122_reviewed_runtime_layout.py'),
        'clip_preserver': digest(root / 'tools/advance_pr122_native_locomotion.py'),
    }


def _source_input_sha(root, record, layout, versions):
    dependencies = []
    for pin in record.get('authoring_dependencies', []):
        path = Path(pin['path'])
        if not path.is_absolute():
            path = root / path
        if (not path.resolve().is_relative_to(root.resolve())
                or not path.is_file() or path.is_symlink()):
            raise ValueError('Missing preserved authoring dependency: ' + str(path))
        dependencies.append({'path': str(path), 'expected': pin['sha256'], 'actual': digest(path)})
    # Whole metadata includes frame order, authored roots/joints, part settings,
    # generation/request versions and any preserved authoring dependency pins.
    return _json_sha({'record': record, 'layout': layout, 'versions': versions,
                      'geometry_file': digest((root / record['source']).with_suffix('.geometry.json')),
                      'authoring_dependencies': dependencies})


def capture_geometry_reuse(root, key):
    """Pin previously verified tracked inputs; never decode or approve a PNG."""
    manifest = json.loads((root / SOURCE_MANIFEST).read_text())
    register = json.loads((root / REGISTER).read_text())
    actor = register.get('actors', {}).get(key, {})
    if actor.get('detailed_completed') or actor.get('verification', {}).get(
            'source_sha256_and_saved_geometry') != 'PASS':
        return None
    def git_bytes(*args):
        return subprocess.check_output(['git', *args], cwd=root, stderr=subprocess.PIPE)
    try:
        tracked = json.loads(git_bytes('show', 'HEAD:' + REGISTER.as_posix()))
        tracked_manifest = json.loads(git_bytes('show', 'HEAD:' + SOURCE_MANIFEST.as_posix()))
        if tracked['actors'].get(key) != actor:
            return None  # Preserve an in-flight writer; do not trust its partial state.
        baseline = git_bytes('log', '-1', '--format=%H', '--', REGISTER.as_posix()).decode().strip()
        before = git_bytes('show', baseline + ':tools/stage_pr122_native_locomotion.py').decode()
        current_nodes = [ast.dump(node, include_attributes=False)
                         for node in _analysis_nodes(Path(__file__).read_text())]
        if current_nodes != [ast.dump(node, include_attributes=False) for node in _analysis_nodes(before)]:
            return None
        for name in ('import_original_based_motion.py', 'pr122_reviewed_runtime_layout.py'):
            if git_bytes('show', baseline + ':tools/' + name) != (root / 'tools' / name).read_bytes():
                return None
        old_regions = git_bytes('show', baseline + ':tools/pr122_reviewed_source_regions.py').decode()
        if _region_analysis_ast(old_regions) != _region_analysis_ast(
                (root / 'tools/pr122_reviewed_source_regions.py').read_text()):
            return None
    except (subprocess.CalledProcessError, KeyError, StopIteration, ValueError):
        return None
    records = {(row['key'], row['source']): row for row in manifest['raw_images']}
    tracked_records = {(row['key'], row['source']): row for row in tracked_manifest['raw_images']}
    versions = _analysis_versions(root)
    entries = {}
    for track in actor['tracks']:
        source = track['source']
        record = records[(key, source)]
        layout = manifest.get('reviewed_runtime_layouts', {}).get(source)
        if (record != tracked_records.get((key, source)) or layout !=
                tracked_manifest.get('reviewed_runtime_layouts', {}).get(source)):
            continue
        sidecar = Path(source).with_suffix('.geometry.json')
        try:
            if git_bytes('show', 'HEAD:' + sidecar.as_posix()) != (root / sidecar).read_bytes():
                continue
        except subprocess.CalledProcessError:
            continue
        if digest(root / source) != record['sha256'] or track['source_sha256'] != record['sha256']:
            raise ValueError('Previously verified source changed: ' + source)
        entries[source] = {'input_sha256': _source_input_sha(root, record,
            layout, versions),
            'track_sha256': _json_sha(track), 'track': deepcopy(track)}
    return {'key': key, 'baseline_commit': baseline, 'versions': versions, 'entries': entries}


def build_frames(tracks):
    lines = [f'[gd_resource type="SpriteFrames" load_steps={len(tracks) * 7 + 1} format=3]']
    for n, track in enumerate(tracks):
        lines += ['', f'[ext_resource type="Texture2D" path="res://{track["texture"]}" id="{n + 1}"]']
    animations = []
    for n, track in enumerate(tracks):
        for phase, frame in enumerate(track['geometry']['frames']):
            lines += ['', f'[sub_resource type="AtlasTexture" id="track_{n}_{phase}"]',
                      f'atlas = ExtResource("{n + 1}")',
                      'region = Rect2(%s)' % ', '.join(map(str, frame['region'])),
                      'margin = Rect2(%s)' % ', '.join(map(str, frame['margin'])),
                      'filter_clip = true']
        poses = ',\n'.join('{"duration": 1.0, "texture": SubResource("track_%d_%d")}' % (n, phase)
                             for phase in range(6))
        loop = str(track['role'] in ('idle', 'walk', 'run')).lower()
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.9f}' %
                          (poses, loop, track['animation'], 6 / ROLE_SECONDS[track['role']]))
    lines += ['', '[resource]', 'animations = [\n' + ',\n'.join(animations) + '\n]',
              'metadata/twilight_canvas_size = Vector2(1024, 1024)',
              'metadata/twilight_native_locomotion_staging = true',
              'metadata/twilight_detailed_completed = false', '']
    return '\n'.join(lines).encode()


def _analyze_source_geometry(path, record, manifest, source, direction):
    canvas = record['geometry'].get('canvas', 1024)
    assert type(canvas) is int and 64 <= canvas <= 2048 and canvas % 8 == 0
    if canvas != 1024:
        review = record.get('source_canvas_review', {})
        assert review.get('status') == 'REVIEWED_SOURCE_CANVAS_PROPOSAL'
        assert review.get('source_sha256') == record['sha256'] and review.get('canvas_size') == canvas
        assert isinstance(review.get('review_basis'), str) and review['review_basis'].strip()
    canonical_kwargs = reviewed_layout.declared_canonical_preflight_kwargs(
        record.get('source_canvas_review'), manifest.get('reviewed_runtime_layouts', {}).get(source),
        record['sha256'], direction, canvas)
    geometry = importer.analyze(path, rows_count=6, reference_rows=[0, 3],
                                directions_axis='phase_grid2', canvas_size=canvas,
                                directions=[direction], **canonical_kwargs)
    if record.get('source_region_review') is not None:
        geometry, region_proof = apply_reviewed_regions(path, geometry, record['source_region_review'])
        assert region_proof == record['source_region_proof'], 'Reviewed source region proof changed'
    importer.require_complete_pose_regions(path, geometry)
    saved = json.loads(path.with_suffix('.geometry.json').read_text())
    assert json.loads(json.dumps(geometry)) == saved, f'Saved source geometry changed: {source}'
    assert len(geometry['frames']) == geometry['distinct_pixel_frames'] == 6
    assert geometry['canvas_size'] == [canvas, canvas] and geometry['foot'] == [canvas // 2, canvas * 5 // 8]
    assert [frame['row'] for frame in geometry['frames']] == list(range(6))
    assert all(frame['direction'] == direction for frame in geometry['frames'])
    layout_proof = None
    layout = manifest.get('reviewed_runtime_layouts', {}).get(source)
    if layout is not None:
        geometry, layout_proof = reviewed_layout.apply_reviewed_layout(
            path, geometry, layout, source_region_review=record.get('source_region_review'))
    return geometry, layout_proof


def preserved_source_analysis(root, record, geometry):
    """Carry this invocation's verified base result to staging without a second decode."""
    return {'record_sha256': _json_sha(record), 'source_sha256': record['sha256'],
            'geometry_file_sha256': digest((root / record['source']).with_suffix('.geometry.json')),
            'versions': _analysis_versions(root), 'geometry': deepcopy(geometry)}


def _prepare_tracks(root, key, folder, manifest, records, previous_actor, reuse_context=None, analyzed_sources=None):
    previous_textures = {(t['source'], t['source_sha256']): t['texture'] for t in previous_actor.get('tracks', [])}
    selected = {**manifest['selected_locomotion_sheets'], **manifest.get('selected_detailed_action_sheets', {})}
    versions = _analysis_versions(root)
    entries = (reuse_context or {}).get('entries', {}) if (reuse_context or {}).get('versions') == versions and (reuse_context or {}).get('key') == key else {}
    stats = dict(reused=0, fresh=0, analyzed=0)
    tracks = []
    # Validate the whole unit before writing any outputs.
    for identity, source in sorted(selected.items()):
        actor_key, direction, role = identity.rsplit(':', 2)
        if actor_key != key:
            continue
        assert role in NATIVE_ROLES and direction in importer.DIRECTIONS
        record = records[(key, source)]
        assert record['direction'] == direction and record['role'] == role
        assert record['geometry']['status'] == 'GEOMETRY_PASS'
        assert record['requested_poses'] == 6
        path = root / source
        subprocess.run(['git', 'ls-files', '--error-unmatch', source], cwd=root,
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        assert path.stat().st_size == record['bytes'] and digest(path) == record['sha256']
        layout = manifest.get('reviewed_runtime_layouts', {}).get(source)
        cached = entries.get(source)
        fresh = (analyzed_sources or {}).get(source)
        if (cached is not None and cached['input_sha256'] ==
                _source_input_sha(root, record, layout, versions)
                and cached['track_sha256'] == _json_sha(cached['track'])):
            old = cached['track']
            assert (old['source'], old['source_sha256'], old['direction'], old['role']) == (
                source, record['sha256'], direction, role)
            geometry = deepcopy(old['geometry'])
            layout_proof = deepcopy(old.get('runtime_layout_proof'))
            stats['reused'] += 1
        elif (fresh is not None and fresh['versions'] == versions
              and fresh['record_sha256'] == _json_sha(record)
              and fresh['source_sha256'] == record['sha256']
              and fresh['geometry_file_sha256'] == digest(path.with_suffix('.geometry.json'))):
            geometry = deepcopy(fresh['geometry'])
            assert geometry == json.loads(path.with_suffix('.geometry.json').read_text())
            assert len(geometry['frames']) == geometry['distinct_pixel_frames'] == 6
            assert [frame['row'] for frame in geometry['frames']] == list(range(6))
            assert all(frame['direction'] == direction for frame in geometry['frames'])
            layout_proof = None
            if layout is not None:
                geometry, layout_proof = reviewed_layout.apply_reviewed_layout(
                    path, geometry, layout, source_region_review=record.get('source_region_review'))
            stats['fresh'] += 1
        else:
            geometry, layout_proof = _analyze_source_geometry(path, record, manifest, source, direction)
            stats['analyzed'] += 1
        tracks.append(dict(direction=direction, role=role,
                           animation=f'{role}_{importer.DIRECTIONS.index(direction)}',
                           source=source, source_sha256=record['sha256'],
                           texture=previous_textures.get((source, record['sha256']),
                                       (folder / f'{direction}-{role}.png').as_posix()), geometry=geometry))
        if layout_proof is not None:
            tracks[-1]['runtime_layout_proof'] = layout_proof
    return tracks, stats


def stage(root, key, revision=None, *, reuse_context=None, analyzed_sources=None):
    scope = _SOURCE_ANALYSIS_CONTEXT.get()
    if scope and scope['root'] == root.resolve() and scope['key'] == key:
        reuse_context = reuse_context if reuse_context is not None else scope['reuse']
        analyzed_sources = analyzed_sources if analyzed_sources is not None else scope['fresh']
    if reuse_context is None:
        reuse_context = capture_geometry_reuse(root, key)
    manifest = json.loads((root / SOURCE_MANIFEST).read_text())
    records = {(row['key'], row['source']): row for row in manifest['raw_images']}
    selected = {**manifest['selected_locomotion_sheets'], **manifest.get('selected_detailed_action_sheets', {})}
    register_path = root / REGISTER
    register = json.loads(register_path.read_text()) if register_path.exists() else dict(
        schema='pr122-native-locomotion-staging-v1', approved_history_preserved=405,
        detailed_complete=0, detailed_total=31, actors={})
    approval_state = production_approvals.load_state(root, manifest=manifest, register=register)
    approval_state.require_mutable(key, 'restage')
    previous_actor = register['actors'].get(key, {})
    previous_textures = {(t['source'], t['source_sha256']): t['texture']
                         for t in previous_actor.get('tracks', [])}
    folder = Path('assets/actors/eight_direction/native_locomotion_staging') / ACTORS[key]
    if revision is not None:
        if not revision or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in revision):
            raise ValueError('Use a bounded ASCII revision directory')
        folder /= revision
    tracks, analysis_stats = _prepare_tracks(root, key, folder, manifest, records, previous_actor, reuse_context, analyzed_sources)
    assert 1 <= len(tracks) <= len(NATIVE_ROLES) * 8
    fingerprints = [frame['rgba_sha256'] for track in tracks for frame in track['geometry']['frames']]
    assert len(set(fingerprints)) == len(fingerprints), 'No duplicated native poses across tracks'
    for track in tracks:
        preserve_write(root / track['texture'], (root / track['source']).read_bytes())
        assert digest(root / track['texture']) == track['source_sha256']
    frames_path = folder / 'SpriteFrames.tres'
    preserve_write(root / frames_path, build_frames(tracks))
    movement_roles = ('walk', 'run') if motion_scope.requires_walk(root, key) else ('run',)
    missing = [f'{role}_{index}' for role in movement_roles for index in range(8)
               if f'{role}_{index}' not in {track['animation'] for track in tracks}]
    available = {track['animation'] for track in tracks}
    missing_core = {role: [f'{role}_{importer.DIRECTIONS.index(direction)}'
                           for direction in motion_scope.required_directions(root, key, role)
                           if f'{role}_{importer.DIRECTIONS.index(direction)}' not in available]
                    for role in CORE_ROLES}
    entry = dict(
        grade=next(row['grade'] for row in json.loads((root / 'docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json').read_text()) if row['id'] == key),
        frames='res://' + frames_path.as_posix(), frames_sha256=digest(root / frames_path),
        native_track_count=len(tracks), native_pose_count=len(fingerprints),
        canvas_size=[1024, 1024], foot=[512, 640], tracks=tracks,
        missing_locomotion=missing, missing_dedicated_roles=[role for role in CORE_ROLES if missing_core[role]],
        missing_dedicated_by_direction=missing_core,
        production_connected=False, detailed_completed=False, completed_added=0,
        status='NATIVE_TRACKS_STAGED; incomplete character HOLD',
        visual_review='NOT_RUN; image tools authorized for production, no chat image attachments',
        timing_review='HOLD; 12.5fps staging baseline from existing 0.48s six-pose walk; run cadence unapproved',
        integration='Godot SpriteFrames contract only; production catalogs and profiles unchanged')
    if len(motion_scope.required_tracks(root, key)) < 48:
        entry['motion_requirements'] = dict(scope='USER_TRANSFORM_NEW_DEATH_S_AND_WALK_SCOPE',
            required_roles=sorted(motion_scope.required_roles(root, key)),
            required_native_track_count=len(motion_scope.required_tracks(root, key)),
            required_death_directions=list(motion_scope.required_directions(root, key, 'death')),
            retained_death_tracks=sum(track['role'] == 'death' for track in tracks),
            retained_walk_tracks=sum(track['role'] == 'walk' for track in tracks),
            policy_sha256=digest(root / motion_scope.POLICY), omission_grants_approval=False)
    previous = dict(register['actors'].get(key, {}))
    verification = previous.pop('verification', None)
    for field in ('native_profile', 'native_profile_sha256', 'native_profile_basis'):
        previous.pop(field, None)
    if previous and previous != entry and revision is None:
        raise ValueError('Existing actor record differs; preserve it instead of replacing history')
    if previous_actor and previous_actor.get('frames') != entry['frames']:
        history = register.setdefault('history', {}).setdefault(key, [])
        snapshot = {field: previous_actor[field] for field in
                    ('frames', 'frames_sha256', 'native_profile', 'native_profile_sha256',
                     'native_track_count', 'native_pose_count', 'verification') if field in previous_actor}
        if not any(item['frames'] == snapshot['frames'] for item in history):
            history.append(snapshot)
    if previous == entry and verification is not None:
        entry['verification'] = verification
    register['actors'][key] = entry
    approval_state.assert_preserved(manifest, register)
    register_path.write_text(json.dumps(register, ensure_ascii=False, indent=2) + '\n')
    print(f'NATIVE_TRACKS_STAGED {key} tracks={len(tracks)} poses={len(fingerprints)} approvals_added=0 analysis={analysis_stats}')
    return analysis_stats


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--key', choices=ACTORS, required=True)
    parser.add_argument('--revision', help='New immutable revision; existing source textures are reused')
    args = parser.parse_args()
    stage(args.root.resolve(), args.key, args.revision)


if __name__ == '__main__':
    main()
