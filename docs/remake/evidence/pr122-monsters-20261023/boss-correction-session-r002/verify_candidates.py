#!/usr/bin/env python3
"""Verify current boss selections and unchanged normal/approved resources."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
COMPASS = ('E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE')
LEDGER = Path('data/pr122_monster_boss_repair_staging.json')


def read(path):
    return json.loads((ROOT / path).read_text())


def pin(path):
    path = Path(str(path).removeprefix('res://'))
    data = (ROOT / path).read_bytes()
    return dict(path=path.as_posix(), bytes=len(data), sha256=hashlib.sha256(data).hexdigest())


def old(path, commit):
    return subprocess.check_output(['git', 'show', commit + ':' + str(path)], cwd=ROOT)


def verify(select=False):
    baseline = read(HERE.relative_to(ROOT) / 'baseline.json')
    inputs = read(HERE.relative_to(ROOT) / 'inputs.json')
    required = {(direction, role) for direction in COMPASS for role in ('idle', 'run', 'attack', 'hit')} | {('S', 'death')}
    actors, pins, images, all_poses = {}, [], {}, set()
    for key, path in inputs.items():
        actor = deepcopy(read(path)['actors'][key])
        assert key in baseline['boss_ids'] and actor['kind'] == 'boss', key
        assert actor['quality_tier'] == 'mythic_transform', key
        assert not actor['production_connected'] and not actor['detailed_completed'], key
        assert pin(actor['frames'])['sha256'] == actor['frames_sha256'], key
        assert pin(actor['native_profile'])['sha256'] == actor['native_profile_sha256'], key
        identities = [(t['direction'], t['role']) for t in actor['tracks']]
        assert len(set(identities)) == len(identities) == actor['native_track_count'], key
        missing = sorted(f'{role}_{COMPASS.index(direction)}' for direction, role in required - set(identities))
        assert missing == sorted(actor['missing_required_tracks']), key
        poses = []
        for track in actor['tracks']:
            assert pin(track['source'])['sha256'] == track['source_sha256'], track['source']
            for frame in track['geometry']['frames']:
                texture = str(frame.get('texture', track['texture'])).removeprefix('res://')
                if 'source' in frame:
                    assert pin(frame['source'])['sha256'] == frame['source_sha256'], frame['source']
                if texture not in images:
                    images[texture] = Image.open(ROOT / texture).convert('RGBA')
                im = images[texture]
                x, y, w, h = frame['region']
                assert min(x, y) >= 0 and min(w, h) > 0 and x + w <= im.width and y + h <= im.height, texture
                pose = im.crop((x, y, x + w, y + h))
                assert pose.getchannel('A').getbbox(), texture
                digest = hashlib.sha256(pose.tobytes()).hexdigest()
                assert digest == frame['rgba_sha256'], (key, track['animation'], frame['region'])
                poses.append(digest)
        assert len(poses) == actor['native_pose_count'], key
        assert len(set(poses)) == actor.get('distinct_source_pose_count', actor['native_pose_count']), key
        all_poses.update(poses)
        actor['replaces_previous_staging_selection'] = True
        actor['source_candidate'] = pin(path)
        actors[key] = actor
        pins.append(pin(path))

    commit = baseline['source_commit']
    scope = read('data/pr122_monster_production_scope.json')
    prior_scope = json.loads(old('data/pr122_monster_production_scope.json', commit))
    normal = [row for row in scope['monsters'] if row['kind'] == 'normal']
    assert normal == [row for row in prior_scope['monsters'] if row['kind'] == 'normal']
    assert len(normal) == 258
    assert scope['summary'] == baseline['historical_approval_counts']
    for path in ['data/combat_animation_profiles.json',
                 'data/pr122_monster_review_scope.json',
                 'docs/remake/evidence/pr122-remaining106/batch17/all498-production-status.json',
                 'data/pr122_native_production_approvals.json']:
        assert (ROOT / path).read_bytes() == old(path, commit), path

    # All previously delivered art, clips, sources and QA captures remain exact.
    prior_manifest = json.loads(old('docs/remake/evidence/pr122-monsters-20261023/boss-repair-session/delivery-manifest.json', commit))
    mutable = {'data/pr122_monster_boss_repair_staging.json',
               'data/pr122_monster_production_scope.json',
               'data/pr122_monster_production_batches.json',
               'docs/remake/TWILIGHT_PR122_RESUME_20261019.md'}
    preserved = 0
    for expected in prior_manifest['files']:
        if expected['path'] in mutable:
            continue
        actual = pin(expected['path'])
        assert actual['bytes'] == expected['bytes'] and actual['sha256'] == expected['sha256'], expected['path']
        preserved += 1

    if select:
        ledger = dict(schema='pr122-monster-boss-repair-staging-v1', date='2026-10-23',
                      reviewed_source_commit=commit, actors=actors, new_approvals=0,
                      default_catalog_switches=0, source_inputs=pins,
                      selection_policy='Latest verified source selection replaces prior drafts; existing art and approvals remain preserved. Technical playback does not grant visual approval.')
        (ROOT / LEDGER).write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + '\n')

    result = dict(schema='pr122-boss-correction-selection-verification-v1', source_commit=commit,
                  normal_scope_rows_exactly_preserved=len(normal), normal_runtime_missing_frames=0,
                  normal_frame_audit_carried_forward_by_exact_asset_and_profile_preservation=True,
                  prior_delivered_files_preserved=preserved, approval_changes=0,
                  default_catalog_switches=0, selected_unique_RGBA_poses=len(all_poses),
                  actors={key: dict(clips=row['native_track_count'], poses=row['native_pose_count'],
                                    missing=row['missing_required_tracks'], native_profile=row['native_profile'],
                                    quality_review=row['quality_review']) for key, row in actors.items()},
                  source_inputs=pins)
    (HERE / 'selection-verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: {k: v for k, v in row.items() if k in ('clips', 'poses', 'missing')} for key, row in result['actors'].items()}, ensure_ascii=False))


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--select', action='store_true', help='Write verified selection to the existing staging ledger')
    verify(parser.parse_args().select)
