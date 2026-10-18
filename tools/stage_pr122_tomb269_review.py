#!/usr/bin/env python3
"""Restore an immutable, unapproved Tomb269 trial into a separate Main copy.

This is deliberately not a production importer or a visual-approval gate.
Every original PNG, complete source region and all 112 unique poses are checked.
"""
import argparse
import copy
import json
from pathlib import Path
import shutil

import import_original_based_motion as core

GROUND02 = {
    ('hit', 'E', 0): [260, 497], ('hit', 'E', 1): [723, 666],
    ('hit', 'W', 0): [284, 517], ('hit', 'W', 1): [767, 706],
    ('hit', 'S', 0): [309, 530], ('hit', 'S', 1): [725, 695],
    ('hit', 'N', 0): [292, 536], ('hit', 'N', 1): [775, 701],
    ('death', 'E', 0): [250, 1018], ('death', 'W', 0): [250, 1058],
    ('death', 'S', 0): [299, 1064], ('death', 'N', 0): [300, 1080],
}


def stage(project, bundle, source_roots, trial, receipt):
    repository = Path(__file__).resolve().parents[1]
    if project == repository or (project / '.git').exists():
        raise ValueError('Only a separate, non-Git Main copy may receive an unapproved trial')
    if not (project / 'Main.tscn').is_file() or not (project / 'project.godot').is_file():
        raise ValueError('An actual complete Main project is required')
    if receipt.exists():
        raise ValueError('Use a fresh receipt path')
    name = 'tomb_guardian269_source_trial01' if trial == 'source01' else 'tomb_guardian269_ground_trial02'
    destination = project / 'assets/actors/eight_direction/original_based' / name
    if destination.exists():
        raise ValueError('Never overwrite an earlier trial')
    metadata = bundle / 'staged-metadata/tomb_guardian269_source_trial01'
    original = json.loads((metadata / 'provenance.json').read_text())
    manifest = json.loads((repository / 'docs/remake/evidence/pr122-remaining106/batch03/lossless-evidence/manifest.json').read_text())
    by_path = {m['path']: m['sha256'] for m in manifest['members']}
    for file in ['provenance.json', 'SpriteFrames.tres']:
        relative = 'staged-metadata/tomb_guardian269_source_trial01/' + file
        if core.sha(metadata / file) != by_path[relative]:
            raise ValueError('Archived trial metadata SHA mismatch: ' + file)
    assert original['distinct_pixel_frames'] == 112 and len(original['source_files']) == 51
    assert all(original['visual_review'][k] is False for k in
               ['identity_preserved', 'eight_views', 'motion_roles', 'no_clipping'])
    raw = {}
    for directory in source_roots:
        for path in sorted(directory.rglob('*.png')):
            raw.setdefault(core.sha(path), path)
    missing = [s['sha256'] for s in original['source_files'] if s['sha256'] not in raw]
    if missing:
        raise ValueError('Selected PNG bodies not recovered: ' + str(missing))
    proof = copy.deepcopy(original)
    changes = []
    global_raw, global_visible = set(), set()
    for index, source in enumerate(proof['source_files']):
        path = raw[source['sha256']]
        frames = [f for f in proof['frames'] if f['sheet'] == index]
        directions = [d for d in core.DIRECTIONS if any(f['direction'] == d for f in frames)]
        ordered = sorted(frames, key=lambda f: (f['row'], directions.index(f['direction'])))
        anchors = []
        for frame in ordered:
            key = frame['role'], frame['direction'], frame['phase']
            anchor = GROUND02.get(key, frame['source_anchor']) if trial == 'ground02' else frame['source_anchor']
            anchors.append(anchor)
            if anchor != frame['source_anchor']:
                changes.append({'role': key[0], 'direction': key[1], 'phase': key[2],
                                'source_sha256': source['sha256'], 'region': frame['region'],
                                'before': frame['source_anchor'], 'proposed': anchor})
        geometry = None
        failures = []
        row_count = max(f['row'] for f in frames) + 1
        for axis in ['columns', 'rows']:
            try:
                candidate = core.analyze(path, rows_count=row_count,
                                         reference_rows=list(range(min(2, row_count))),
                                         directions=directions, directions_axis=axis,
                                         canvas_size=source['canvas_size'][0], source_anchors=anchors)
                assert all(a['region'] == b['region'] and a['rgba_sha256'] == b['rgba_sha256']
                           and a['direction'] == b['direction'] and a['row'] == b['row']
                           for a, b in zip(candidate['frames'], ordered))
                assert len(candidate['frames']) == len(ordered)
                core.require_complete_pose_regions(path, candidate)
                geometry = candidate
                break
            except (ValueError, AssertionError) as error:
                failures.append(str(error))
        if geometry is None:
            raise ValueError('Unchanged strict whole-source validation refused ' + str(path) + ': ' + str(failures))
        with core.Image.open(path) as image:
            pixels = core.np.asarray(image)
            for analyzed, frame in zip(geometry['frames'], ordered):
                retained = {k: v for k, v in frame.items() if k not in {'source_anchor', 'margin'}}
                frame.update(source_anchor=analyzed['source_anchor'], margin=analyzed['margin'])
                assert retained == {k: v for k, v in frame.items() if k not in {'source_anchor', 'margin'}}
                assert frame['rgba_sha256'] not in global_raw
                global_raw.add(frame['rgba_sha256'])
                x, y, width, height = frame['region']
                fingerprint = core._visible_pose_fingerprint(pixels[y:y + height, x:x + width])
                assert fingerprint not in global_visible
                global_visible.add(fingerprint)
    assert len(global_raw) == len(global_visible) == 112
    if trial == 'ground02':
        assert len(changes) == 12
    else:
        assert not changes and proof == original

    old_prefix = 'res://assets/actors/eight_direction/original_based/tomb_guardian269_source_trial01/'
    new_prefix = 'res://assets/actors/eight_direction/original_based/' + name + '/'

    def remap(value):
        if isinstance(value, str) and value.startswith(old_prefix):
            return new_prefix + value.removeprefix(old_prefix)
        if isinstance(value, list):
            return [remap(v) for v in value]
        if isinstance(value, dict):
            return {k: remap(v) for k, v in value.items()}
        return value

    proof = remap(proof)
    for pose in proof['source_poses']:
        frame = next(f for f in proof['frames'] if f['pose_id'] == pose['id'])
        pose['source_anchor'] = frame['source_anchor']
    role_frames = {role: [[next(i for i, f in enumerate(proof['frames'])
                                  if (f['role'], f['direction'], f['phase']) == (role, direction, phase))
                          for phase in range(count)] for direction in core.DIRECTIONS]
                   for role, count in proof['phase_counts'].items()}
    targets = {t['key']: t for t in json.loads((project / 'data/animation_authoring_sources.json').read_text())['targets']}
    target = targets['transform:269']
    assert core.sha(project / target['reference']['path'].removeprefix('res://')) == target['reference']['sha256']
    profile_path, document, _, prior_sha = core._pose_file_profiles(
        project, targets, ['transform:269'], target, destination, proof['display_reference_height'], 4, {})
    before = json.loads(profile_path.read_text())
    assert [k for k in document['profiles'] if document['profiles'][k] != before['profiles'].get(k)] == ['transform:269']
    destination.mkdir()
    for source in proof['source_files']:
        path = project / source['path'].removeprefix('res://')
        shutil.copyfile(raw[source['sha256']], path)
        assert core.sha(path) == source['sha256']
    (destination / 'provenance.json').write_text(json.dumps(proof, ensure_ascii=False, indent=2) + '\n')
    (destination / 'SpriteFrames.tres').write_text(core.spriteframes(
        [s['path'] for s in proof['source_files']], {'frames': proof['frames']}, role_frames))
    assert core.sha(profile_path) == prior_sha
    profile_path.write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n')
    fixture = {'scope': 'Unapproved restored Tomb269 ' + trial + '; full actual Main QA only, completed0',
               'cases': [{'name': target['name'], 'folder': name, 'slug': name.replace('_', '-'),
                          'unobstructed_pose_review': True,
                          'spec': {'job': '기사', 'appearance': 0, 'transform_id': '269',
                                   'name': '훈련용 한손검', 'type': '한손검', 'style': 'slash', 'magic': False}}]}
    fixture_path = project / 'tests/fixtures' / ('pr122_tomb269_' + trial + '.json')
    if fixture_path.exists():
        raise ValueError('Fixture already exists')
    fixture_path.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + '\n')
    result = {'scope': fixture['scope'], 'isolated_project': str(project), 'folder': str(destination),
              'fixture': 'res://' + fixture_path.relative_to(project).as_posix(),
              'source_pngs_sha256_matched': 51, 'strict_complete_source_unique_frames': 112,
              'source_pixel_changes': 0, 'anchor_proposals': changes,
              'other_slots_preserved': 112 - len(changes), 'isolated_profile_change_keys': ['transform:269'],
              'original_profile_sha256': prior_sha, 'profile': document['profiles']['transform:269'],
              'all_final_review_flags': False, 'production_apply': False, 'completed_added': 0}
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, required=True)
    parser.add_argument('--bundle', type=Path, required=True)
    parser.add_argument('--source-root', type=Path, action='append', required=True)
    parser.add_argument('--trial', choices=['source01', 'ground02'], required=True)
    parser.add_argument('--receipt', type=Path, required=True)
    args = parser.parse_args()
    stage(args.project.resolve(), args.bundle.resolve(), [p.resolve() for p in args.source_root],
          args.trial, args.receipt.resolve())
