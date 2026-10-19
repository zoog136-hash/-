#!/usr/bin/env python3
"""Prepare the saved PR122 native tracks, without approving or switching actors.

The complete-character importer keeps its full eight-view/five-role gate. This
separate staging operation emits only existing, hash-pinned native tracks; it
cannot manufacture missing views, roles, aliases, or approvals.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

import import_original_based_motion as importer
from pr122_reviewed_source_regions import apply_reviewed_regions
import pr122_reviewed_runtime_layout as reviewed_layout


SOURCE_MANIFEST = Path('docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json')
REGISTER = Path('data/pr122_native_locomotion_staging.json')
ACTORS = {'transform:393': 'halpas_393', 'transform:267': 'girtas_267',
          'transform:413': 'thunder_female_413'}
CORE_ROLES = ('idle', 'attack', 'hit', 'death')
NATIVE_ROLES = ('walk', 'run', *CORE_ROLES)
ROLE_SECONDS = dict(idle=1.2, walk=.48, run=.48, attack=.42, hit=.22, death=.65)


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


def stage(root, key, revision=None):
    manifest = json.loads((root / SOURCE_MANIFEST).read_text())
    assert manifest['mythic_detail_complete'] == 0
    assert manifest['approved_history_preserved'] == 405
    records = {(row['key'], row['source']): row for row in manifest['raw_images']}
    selected = {**manifest['selected_locomotion_sheets'], **manifest.get('selected_detailed_action_sheets', {})}
    register_path = root / REGISTER
    register = json.loads(register_path.read_text()) if register_path.exists() else dict(
        schema='pr122-native-locomotion-staging-v1', approved_history_preserved=405,
        detailed_complete=0, detailed_total=31, actors={})
    previous_actor = register['actors'].get(key, {})
    previous_textures = {(t['source'], t['source_sha256']): t['texture']
                         for t in previous_actor.get('tracks', [])}
    folder = Path('assets/actors/eight_direction/native_locomotion_staging') / ACTORS[key]
    if revision is not None:
        if not revision or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in revision):
            raise ValueError('Use a bounded ASCII revision directory')
        folder /= revision
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
        canvas = record['geometry'].get('canvas', 1024)
        assert type(canvas) is int and 64 <= canvas <= 2048 and canvas % 8 == 0
        if canvas != 1024:
            review = record.get('source_canvas_review', {})
            assert review.get('status') == 'REVIEWED_SOURCE_CANVAS_PROPOSAL'
            assert review.get('source_sha256') == record['sha256'] and review.get('canvas_size') == canvas
            assert isinstance(review.get('review_basis'), str) and review['review_basis'].strip()
        geometry = importer.analyze(path, rows_count=6, reference_rows=[0, 3],
                                    directions_axis='phase_grid2', canvas_size=canvas,
                                    directions=[direction])
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
        tracks.append(dict(direction=direction, role=role,
                           animation=f'{role}_{importer.DIRECTIONS.index(direction)}',
                           source=source, source_sha256=record['sha256'],
                           texture=previous_textures.get((source, record['sha256']),
                                       (folder / f'{direction}-{role}.png').as_posix()), geometry=geometry))
        if layout_proof is not None:
            tracks[-1]['runtime_layout_proof'] = layout_proof
    assert 1 <= len(tracks) <= len(NATIVE_ROLES) * 8
    fingerprints = [frame['rgba_sha256'] for track in tracks for frame in track['geometry']['frames']]
    assert len(set(fingerprints)) == len(fingerprints), 'No duplicated native poses across tracks'
    for track in tracks:
        preserve_write(root / track['texture'], (root / track['source']).read_bytes())
        assert digest(root / track['texture']) == track['source_sha256']
    frames_path = folder / 'SpriteFrames.tres'
    preserve_write(root / frames_path, build_frames(tracks))
    missing = [f'{role}_{index}' for role in ('walk', 'run') for index in range(8)
               if f'{role}_{index}' not in {track['animation'] for track in tracks}]
    available = {track['animation'] for track in tracks}
    missing_core = {role: [f'{role}_{direction}' for direction in range(8)
                          if f'{role}_{direction}' not in available] for role in CORE_ROLES}
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
    register_path.write_text(json.dumps(register, ensure_ascii=False, indent=2) + '\n')
    print(f'NATIVE_TRACKS_STAGED {key} tracks={len(tracks)} poses={len(fingerprints)} approvals_added=0')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--key', choices=ACTORS, required=True)
    parser.add_argument('--revision', help='New immutable revision; existing source textures are reused')
    args = parser.parse_args()
    stage(args.root.resolve(), args.key, args.revision)


if __name__ == '__main__':
    main()
