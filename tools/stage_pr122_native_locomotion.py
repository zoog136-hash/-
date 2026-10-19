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


SOURCE_MANIFEST = Path('docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json')
REGISTER = Path('data/pr122_native_locomotion_staging.json')
ACTORS = {'transform:393': 'halpas_393', 'transform:267': 'girtas_267'}


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
        animations.append('{"frames": [%s], "loop": true, "name": &"%s", "speed": 12.5}' %
                          (poses, track['animation']))
    lines += ['', '[resource]', 'animations = [\n' + ',\n'.join(animations) + '\n]',
              'metadata/twilight_canvas_size = Vector2(1024, 1024)',
              'metadata/twilight_native_locomotion_staging = true',
              'metadata/twilight_detailed_completed = false', '']
    return '\n'.join(lines).encode()


def stage(root, key):
    manifest = json.loads((root / SOURCE_MANIFEST).read_text())
    assert manifest['mythic_detail_complete'] == 0
    assert manifest['approved_history_preserved'] == 405
    records = {(row['key'], row['source']): row for row in manifest['raw_images']}
    selected = manifest['selected_locomotion_sheets']
    folder = Path('assets/actors/eight_direction/native_locomotion_staging') / ACTORS[key]
    tracks = []
    # Validate the whole unit before writing any outputs.
    for identity, source in sorted(selected.items()):
        actor_key, direction, role = identity.rsplit(':', 2)
        if actor_key != key:
            continue
        assert role in ('walk', 'run') and direction in importer.DIRECTIONS
        record = records[(key, source)]
        assert record['direction'] == direction and record['role'] == role
        assert record['geometry']['status'] == 'GEOMETRY_PASS'
        assert record['requested_poses'] == 6
        path = root / source
        subprocess.run(['git', 'ls-files', '--error-unmatch', source], cwd=root,
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        assert path.stat().st_size == record['bytes'] and digest(path) == record['sha256']
        geometry = importer.analyze(path, rows_count=6, reference_rows=[0, 3],
                                    directions_axis='phase_grid2', canvas_size=1024,
                                    directions=[direction])
        importer.require_complete_pose_regions(path, geometry)
        saved = json.loads(path.with_suffix('.geometry.json').read_text())
        assert json.loads(json.dumps(geometry)) == saved, f'Saved source geometry changed: {source}'
        assert len(geometry['frames']) == geometry['distinct_pixel_frames'] == 6
        assert geometry['canvas_size'] == [1024, 1024] and geometry['foot'] == [512, 640]
        assert [frame['row'] for frame in geometry['frames']] == list(range(6))
        assert all(frame['direction'] == direction for frame in geometry['frames'])
        tracks.append(dict(direction=direction, role=role,
                           animation=f'{role}_{importer.DIRECTIONS.index(direction)}',
                           source=source, source_sha256=record['sha256'],
                           texture=(folder / f'{direction}-{role}.png').as_posix(), geometry=geometry))
    assert len(tracks) == (5 if key == 'transform:393' else 4)
    fingerprints = [frame['rgba_sha256'] for track in tracks for frame in track['geometry']['frames']]
    assert len(set(fingerprints)) == len(fingerprints), 'No duplicated native poses across tracks'
    for track in tracks:
        preserve_write(root / track['texture'], (root / track['source']).read_bytes())
        assert digest(root / track['texture']) == track['source_sha256']
    frames_path = folder / 'SpriteFrames.tres'
    preserve_write(root / frames_path, build_frames(tracks))
    register_path = root / REGISTER
    register = json.loads(register_path.read_text()) if register_path.exists() else dict(
        schema='pr122-native-locomotion-staging-v1', approved_history_preserved=405,
        detailed_complete=0, detailed_total=31, actors={})
    missing = [f'{role}_{index}' for role in ('walk', 'run') for index in range(8)
               if f'{role}_{index}' not in {track['animation'] for track in tracks}]
    entry = dict(
        grade='유일', frames='res://' + frames_path.as_posix(), frames_sha256=digest(root / frames_path),
        native_track_count=len(tracks), native_pose_count=len(fingerprints),
        canvas_size=[1024, 1024], foot=[512, 640], tracks=tracks,
        missing_locomotion=missing, missing_dedicated_roles=['idle', 'attack', 'hit', 'death'],
        production_connected=False, detailed_completed=False, completed_added=0,
        status='NATIVE_TRACKS_STAGED; incomplete character HOLD',
        visual_review='NOT_RUN; image generation and preview tools forbidden',
        timing_review='HOLD; 12.5fps staging baseline from existing 0.48s six-pose walk; run cadence unapproved',
        integration='Godot SpriteFrames contract only; production catalogs and profiles unchanged')
    previous = dict(register['actors'].get(key, {}))
    verification = previous.pop('verification', None)
    if previous and previous != entry:
        raise ValueError('Existing actor record differs; preserve it instead of replacing history')
    if verification is not None:
        entry['verification'] = verification
    register['actors'][key] = entry
    register_path.write_text(json.dumps(register, ensure_ascii=False, indent=2) + '\n')
    print(f'NATIVE_TRACKS_STAGED {key} tracks={len(tracks)} poses={len(fingerprints)} approvals_added=0')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--key', choices=ACTORS, required=True)
    args = parser.parse_args()
    stage(args.root.resolve(), args.key)


if __name__ == '__main__':
    main()
