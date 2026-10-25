#!/usr/bin/env python3
"""Compose a review-only 412 candidate from approved core and 16 new tracks.

This intentionally separate builder never changes catalogs, the staging register,
source images, approvals or Git. Old core blocks remain literal; new source pixels
remain untouched. A candidate record is resolved through the existing Catalog API
so its inherited presentation and combat defaults are not guessed by this tool.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re

import import_original_based_motion as importer
import stage_pr122_native_locomotion as staging


KEY = 'transform:412'
BASE = Path('assets/actors/eight_direction/original_based/reaper_female')
CORE_COUNTS = dict(idle=2, attack=3, hit=2, death=3)
PINNED = {
    'SpriteFrames.tres': '40f5108907d7992ac3c17708615ea22eb4c1e3dd2ca8e150e187d3e8a00e9169',
    'provenance.json': '263ccd03ba923c0a4088bb422665a8930e98ff3963c08fb771642722c6139152',
    'poses-0.png': '6e24057fb07dfd0a09a64e23af379d1546fffa1905760a09b32da143e284263c',
    'poses-1.png': '2e39e48610f3bb67428244b13f3596ddbab28ed2cc42522efad803af85b0fc8c',
}
PROFILE_SHA = 'ec8876b22358a8fb8c1269dd3aca062c7fa1e0651ea73b97a44966530726f977'
NUMBER = r'-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?'
FRAME_RE = re.compile(r'\{"duration": (' + NUMBER + r'), "texture": SubResource\("([^"]+)"\)\}')
ANIMATION_RE = re.compile(r'\{"frames": \[(.*?)\], "loop": (true|false), "name": &"([^"]+)", "speed": (' + NUMBER + r')\}', re.S)


def require(value, message):
    if not value:
        raise ValueError(message)


def digest(content):
    return hashlib.sha256(content).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True).encode()


def read_json(path):
    require(path.is_file() and not path.is_symlink(), f'Require a regular metadata file: {path}')
    require(path.stat().st_size < 32 * 1024 * 1024, 'Unexpectedly large metadata')
    return json.loads(path.read_text())


def existing(root, relative):
    path = root / relative
    require(not path.is_symlink(), 'Source symlinks are not allowed')
    path = path.resolve()
    require(path.is_relative_to(root) and path.is_file(), 'Source must be an existing repository file')
    return path


def parse_frames(text):
    """Read the pinned simple TRES format; reject unknown or malformed blocks."""
    parts = re.split(r'(?=^\[)', text, flags=re.M)
    textures, atlases = {}, {}
    resource = None
    for part in parts:
        part = part.strip()
        if not part:
            continue
        if part.startswith('[gd_resource '):
            require('type="SpriteFrames"' in part, 'Expected SpriteFrames')
        elif part.startswith('[ext_resource '):
            match = re.fullmatch(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', part)
            require(match is not None and match[2] not in textures, 'Unknown or duplicate texture resource')
            textures[match[2]] = dict(path=match[1], literal=part)
        elif part.startswith('[sub_resource '):
            match = re.fullmatch(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n'
                                 r'atlas = ExtResource\("([^"]+)"\)\n'
                                 r'region = Rect2\(([^)]+)\)\nmargin = Rect2\(([^)]+)\)\n'
                                 r'filter_clip = true', part)
            require(match is not None and match[1] not in atlases, 'Unknown or duplicate atlas resource')
            rects = [list(map(int, match[n].split(','))) for n in (3, 4)]
            require(all(len(rect) == 4 for rect in rects), 'Require integer atlas rectangles')
            atlases[match[1]] = dict(texture=match[2], region=rects[0], margin=rects[1], literal=part)
        elif part.startswith('[resource]'):
            require(resource is None, 'Duplicate resource body')
            resource = part
        else:
            raise ValueError('Unknown TRES section')
    require(resource is not None, 'Missing resource body')
    animations = {}
    for match in ANIMATION_RE.finditer(resource):
        frames = list(FRAME_RE.finditer(match[1]))
        require(frames and match[3] not in animations, 'Missing frames or duplicate animation')
        require(FRAME_RE.sub('', match[1]).replace(',', '').strip() == '', 'Unknown frame expression')
        animations[match[3]] = dict(literal=match[0], frames=[(f[1], f[2]) for f in frames],
                                    loop=match[2] == 'true', speed=match[4])
    require(animations, 'No animations parsed')
    for animation in animations.values():
        require(all(atlas in atlases and atlases[atlas]['texture'] in textures
                    for _, atlas in animation['frames']), 'Unresolved atlas/texture reference')
    return textures, atlases, animations


def inherited_core(root):
    for filename, sha in PINNED.items():
        require(digest(existing(root, BASE / filename).read_bytes()) == sha,
                f'Approved source changed; preserve and review: {filename}')
    profile = read_json(existing(root, 'data/combat_animation_profiles.json'))['profiles'][KEY]
    require(digest(canonical(profile)) == PROFILE_SHA, 'Approved profile changed; preserve and review')
    provenance = read_json(existing(root, BASE / 'provenance.json'))
    textures, atlases, all_animations = parse_frames((root / BASE / 'SpriteFrames.tres').read_text())
    animations = {}
    ids = set()
    for role, count in CORE_COUNTS.items():
        for direction in range(8):
            name = f'{role}_{direction}'
            animation = all_animations[name]
            require(len(animation['frames']) == count and animation['loop'] == (role == 'idle'),
                    'Approved core frame count/loop changed')
            for _, atlas_id in animation['frames']:
                original = provenance['frames'][int(atlas_id.removeprefix('pose_'))]
                atlas = atlases[atlas_id]
                require(atlas['region'] == original['region'] and atlas['margin'] == original['margin']
                        and atlas['texture'] == str(original['sheet'] + 1), 'Core geometry differs from provenance')
                canvas = 256 if role in ('idle', 'attack') else 328
                require([atlas['region'][i + 2] + atlas['margin'][i + 2] for i in (0, 1)] == [canvas, canvas],
                        'Approved mixed intrinsic canvas changed')
                ids.add(atlas_id)
            animations[name] = animation
    require(len(ids) == 80 and sum(len(a['frames']) for a in animations.values()) == 80,
            'Require exactly 80 distinct approved core frames')
    return profile, textures, {k: v for k, v in atlases.items() if k in ids}, animations


def canvas_spec(root, path):
    spec = read_json(existing(root, path))
    require(spec.get('key') == KEY and spec.get('schema') == 'pr122-reaper-composite-canvases-v1',
            'Require an explicit reaper canvas specification')
    sizes = spec.get('canvases_by_direction')
    require(isinstance(sizes, dict) and set(sizes) == set(importer.DIRECTIONS), 'Require all eight headings')
    require(all(type(n) is int and 64 <= n <= 2048 and n % 8 == 0 for n in sizes.values()),
            'Each heading canvas must be a bounded multiple of eight')
    return spec, sizes


def movement(root, register_path, sizes):
    register = read_json(existing(root, register_path))
    tracks = register.get('actors', {}).get(KEY, {}).get('tracks', [])
    expected = {(d, role) for d in importer.DIRECTIONS for role in ('walk', 'run')}
    require(len(tracks) == 16 and {(t['direction'], t['role']) for t in tracks} == expected,
            'Require exactly sixteen newly authored movement tracks; never remake core')
    prepared, fingerprints = [], set()
    for track in sorted(tracks, key=lambda t: (t['direction'], t['role'])):
        require(track['animation'] == f'{track["role"]}_{importer.DIRECTIONS.index(track["direction"])}',
                'Movement animation name differs from its heading/role')
        source, texture = (existing(root, track[field]) for field in ('source', 'texture'))
        require(digest(source.read_bytes()) == digest(texture.read_bytes()) == track['source_sha256'],
                'New source/texture digest changed')
        geometry = importer.analyze(source, rows_count=6, reference_rows=[0, 3],
                                    directions_axis='phase_grid2', canvas_size=1024,
                                    directions=[track['direction']])
        importer.require_complete_pose_regions(source, geometry)
        require(json.loads(json.dumps(geometry)) == track['geometry']
                == read_json(source.with_suffix('.geometry.json')), 'New saved geometry changed')
        require(geometry['distinct_pixel_frames'] == len(geometry['frames']) == 6
                and geometry['canvas_size'] == [1024, 1024] and geometry['foot'] == [512, 640],
                'Require genuine six-pose staged movement')
        runtime_frames = []
        for frame in geometry['frames']:
            require(frame['rgba_sha256'] not in fingerprints, 'Repeated new movement pose')
            fingerprints.add(frame['rgba_sha256'])
            compiled = copy.deepcopy(frame)
            importer._rebase_mixed_frame_canvas(compiled, sizes[track['direction']])
            require(all(compiled[key] == frame[key] for key in ('region', 'source_anchor', 'rgba_sha256')),
                    'Rebasing must never alter source pixels, regions or anchors')
            runtime_frames.append(compiled)
        prepared.append(dict(track=track, runtime_frames=runtime_frames))
    require(len(fingerprints) == 96, 'Require 96 distinct new movement poses')
    return prepared


def build(root, register_path, spec_path, output):
    """Pure preflight/build: return bytes and proof; never write any files."""
    root = root.resolve()
    output = output if output.is_absolute() else root / output
    require(not output.exists() and not output.is_symlink(), 'Output must be a new immutable folder')
    output = output.resolve()
    require(output.is_relative_to(root), 'Candidate output must be inside the selected root')
    spec, sizes = canvas_spec(root, spec_path)
    profile, textures, atlases, core_animations = inherited_core(root)
    new = movement(root, register_path, sizes)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(textures) + len(atlases) + 16 + 96} format=3]']
    lines += ['', '\n\n'.join(t['literal'] for t in textures.values())]
    for index, item in enumerate(new):
        path = 'res://' + item['track']['texture']
        lines += ['', f'[ext_resource type="Texture2D" path={json.dumps(path)} id="native_{index}"]']
    lines += ['', '\n\n'.join(a['literal'] for a in atlases.values())]
    animations = [a['literal'] for a in core_animations.values()]
    for index, item in enumerate(new):
        for phase, frame in enumerate(item['runtime_frames']):
            lines += ['', f'[sub_resource type="AtlasTexture" id="native_pose_{index}_{phase}"]',
                      f'atlas = ExtResource("native_{index}")',
                      'region = Rect2(%s)' % ', '.join(map(str, frame['region'])),
                      'margin = Rect2(%s)' % ', '.join(map(str, frame['margin'])), 'filter_clip = true']
        poses = ',\n'.join('{"duration": 1.0, "texture": SubResource("native_pose_%d_%d")}' % (index, phase)
                            for phase in range(6))
        animations.append('{"frames": [%s], "loop": true, "name": &"%s", "speed": 12.5}' %
                          (poses, item['track']['animation']))
    lines += ['', '[resource]', 'animations = [\n' + ',\n'.join(animations) + '\n]',
              'metadata/twilight_canvas_size = Vector2(256, 256)',
              'metadata/twilight_pr122_inherited_core_composite = true',
              'metadata/twilight_detailed_completed = false', '']
    content = '\n'.join(lines)
    parsed_textures, parsed_atlases, parsed_animations = parse_frames(content)
    require(len(parsed_animations) == 48 and sum(len(a['frames']) for a in parsed_animations.values()) == 176,
            'Composite must contain exactly 48 clips and 176 selected poses')
    require(all(parsed_animations[k]['literal'] == v['literal'] for k, v in core_animations.items())
            and all(parsed_atlases[k]['literal'] == v['literal'] for k, v in atlases.items())
            and all(parsed_textures[k]['literal'] == v['literal'] for k, v in textures.items()),
            'Original core blocks must remain literal and unchanged')
    require('twilight_native_locomotion_staging' not in content and 'twilight_source_tracks' not in content,
            'Do not change inherited core timing policy')
    catalog = read_json(existing(root, 'data/catalog_v19.json'))['변신']
    records = [record for record in catalog if str(record.get('sourceId')) == '412']
    require(len(records) == 1, 'Require the exact current 412 catalog identity')
    candidate = copy.deepcopy(records[0])
    settings = copy.deepcopy(profile)
    settings.update(frames_path='res://' + (output / 'SpriteFrames.tres').relative_to(root).as_posix(), movement_fps=12.5)
    require({k for k in set(profile) | set(settings) if profile.get(k) != settings.get(k)}
            == {'frames_path', 'movement_fps'}, 'Only movement cadence and candidate frames may change')
    candidate['animation_profile'] = settings
    files = {'SpriteFrames.tres': content.encode(),
             'CandidateRecord.json': (json.dumps(candidate, ensure_ascii=False, indent=2) + '\n').encode()}
    proof = dict(schema='pr122-inherited-reaper-composite-proof-v1', key=KEY,
                 status='CANDIDATE_SIZING_HOLD', completed_added=0, production_connected=False,
                 visual_approval='NOT_RUN', inherited_core_clips=32, inherited_core_poses=80,
                 newly_authored_movement_clips=16, newly_authored_movement_poses=96,
                 total_clips=48, total_poses=176, reference_canvas=[256, 256],
                 source_images_resampled=False, source_pixels_changed=False,
                 inherited_core_literal_preservation='PASS', inherited_marker=1,
                 canvas_spec=spec, original_core_sha256=PINNED, original_profile_sha256=PROFILE_SHA,
                 candidate_profile_changed_fields=['frames_path', 'movement_fps'],
                 runtime_frames=[dict(direction=item['track']['direction'], role=item['track']['role'],
                                     source=item['track']['source'], texture=item['track']['texture'],
                                     source_sha256=item['track']['source_sha256'], frames=item['runtime_frames']) for item in new],
                 output_sha256={name: digest(data) for name, data in files.items()},
                 integration='Use CandidateRecord.json through existing Catalog.for_record/Main candidate API; no catalog replacement')
    files['provenance.json'] = (json.dumps(proof, ensure_ascii=False, indent=2) + '\n').encode()
    return output, files, proof


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--register', type=Path, default=staging.REGISTER)
    parser.add_argument('--canvases', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--preflight', action='store_true', help='Validate/build in memory without writing')
    args = parser.parse_args()
    output, files, proof = build(args.root, args.register, args.canvases, args.output)
    if not args.preflight:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.mkdir(exist_ok=False)
        for name, data in files.items():
            with (output / name).open('xb') as stream:
                stream.write(data)
    print(json.dumps(dict(status=proof['status'], preflight=args.preflight, output=str(output),
                          clips=48, poses=176, inherited_poses=80, new_poses=96, completed_added=0)))


if __name__ == '__main__':
    main()
