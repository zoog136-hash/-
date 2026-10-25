#!/usr/bin/env python3
"""Assemble a dedicated, unapproved Albino Demon boss repair candidate."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[5]
BASE = Path(__file__).resolve().parent
BATCH = BASE.relative_to(ROOT)
REVISION = sys.argv[1] if len(sys.argv) > 1 else 'r002'
assert REVISION == 'r002', 'The first r001 candidate is immutable; assemble the explicit repaired revision'
FOLDER = Path('assets/actors/eight_direction/monster_boss_repair/albino_demon') / REVISION
KEY = 'monster:알비노 데몬'
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import frames_bytes, preserve, json_bytes
from PIL import Image
import numpy as np

COMBAT = {
    'E': 'albino_combat_E_v02', 'SE': 'albino_combat_SE_v01',
    'S': 'albino_combat_S_v01', 'SW': 'albino_combat_SW_v02',
    'W': 'albino_combat_W_v01', 'NW': 'albino_combat_NW_v02',
    'N': 'albino_combat_N_v01', 'NE': 'albino_combat_NE_v01',
}


def assemble():
    target = next(row for row in json.loads((ROOT / 'data/animation_authoring_sources.json').read_text())['targets'] if row['key'] == KEY)
    reference = target['reference']
    assert target['group'] == 'boss' and target['presentation_to_preserve']['visual_height'] == 128
    assert core.sha(ROOT / reference['path'].removeprefix('res://')) == reference['sha256']
    with Image.open(ROOT / reference['path'].removeprefix('res://')) as image:
        x, y, w, h = reference['region']
        crop = image.convert('RGBA').crop((x, y, x + w, y + h))
        assert hashlib.sha256(crop.tobytes()).hexdigest() == reference['region_rgba_sha256']
    selected = [json.loads((BASE / 'checks' / (COMBAT[d] + '.json')).read_text()) for d in core.DIRECTIONS]
    # Retain NW v02 idle/hit whose near LEFT claw is empty. Its contact pose
    # still changed weapon arms, so replace all three NW attack poses with a
    # focused newly authored RIGHT-arm source rather than claiming approval.
    next(r for r in selected if r['directions'] == ['NW'])['selected_roles'] = {'idle':[0,1], 'hit':[5,6]}
    nw_attack = json.loads((BASE / 'checks' / 'albino_attack_NW_v01.json').read_text())
    nw_attack['selected_roles'] = {'attack':[0,1,2]}
    nw_attack['reference_rows'] = [2]
    selected.append(nw_attack)
    run_sources = json.loads((BASE / 'run-production' / 'source-checks.json').read_text())
    if isinstance(run_sources, dict):
        run_sources = run_sources['sources']
    selected_runs = run_sources if len(run_sources) == 8 else [r for r in run_sources if r.get('selected', False)]
    assert len(selected_runs) == 8, 'Require an explicit final selected RUN source per direction'
    assert {tuple(r['directions']) for r in selected_runs} == {(d,) for d in core.DIRECTIONS}
    selected += selected_runs
    selected.append(json.loads((BASE / 'checks' / 'albino_death_S_v02.json').read_text()))
    tracks, pixel_hashes, visible_hashes, sources = [], set(), set(), []
    for source in selected:
        assert source['status'] == 'GEOMETRY_PASS_ONLY'
        path = ROOT / source['path']
        assert core.sha(path) == source['sha256']
        rows, refs, axis, directions = source['rows'], source['reference_rows'], source['axis'], source['directions']
        roles = source.get('selected_roles') or ({'idle': [0, 1], 'attack': [2, 3, 4], 'hit': [5, 6]} if rows == 7 else {'run': list(range(6))} if rows == 6 else {'death': [0, 1, 2]})
        initial = core.analyze(path, rows, refs, directions_axis=axis, canvas_size=2048, directions=directions)
        core.require_complete_pose_regions(path, initial)
        # Native standing height 64 px, actual boss visual_height 128.  The
        # dying knee-buckle source is intentionally shorter than standing.
        native_height = 58 if 'death' in roles else 64
        canvas = max(64, round(initial['neutral_height'] * 256 / native_height / 8) * 8)
        assert canvas <= 2048
        geometry = core.analyze(path, rows, refs, directions_axis=axis, canvas_size=canvas, directions=directions)
        core.require_complete_pose_regions(path, geometry)
        texture = FOLDER / path.name
        preserve(ROOT / texture, path.read_bytes())
        with Image.open(path) as image:
            pixels = np.asarray(image.convert('RGBA'))
            for frame in geometry['frames']:
                if frame['row'] not in {phase for phases in roles.values() for phase in phases}:
                    continue
                assert frame['rgba_sha256'] not in pixel_hashes
                pixel_hashes.add(frame['rgba_sha256'])
                x, y, w, h = frame['region']
                visible = core._visible_pose_fingerprint(pixels[y:y+h, x:x+w])
                assert visible not in visible_hashes
                visible_hashes.add(visible)
        sources.append({'name':source['name'], 'path':source['path'], 'sha256':source['sha256'],
                        'rows':rows, 'axis':axis, 'reference_rows':refs, 'directions':directions,
                        'canvas_size':canvas, 'neutral_height':initial['neutral_height'],
                        'native_reference_height':native_height, 'selected_roles':roles, 'status':'GEOMETRY_PASS_ONLY'})
        for role, phases in roles.items():
            for direction in directions:
                part = deepcopy(geometry)
                part['frames'] = [f for f in geometry['frames'] if f['direction'] == direction and f['row'] in phases]
                assert len(part['frames']) == len(phases)
                part['distinct_pixel_frames'] = len(phases)
                tracks.append({'direction':direction, 'role':role,
                               'animation':role + '_' + str(core.DIRECTIONS.index(direction)),
                               'source':source['path'], 'source_sha256':source['sha256'],
                               'texture':texture.as_posix(), 'geometry':part})
    expected = {(d, role) for role in ('idle','run','attack','hit') for d in core.DIRECTIONS} | {('S','death')}
    assert len(tracks) == 33 and {(t['direction'],t['role']) for t in tracks} == expected
    assert sum(len(t['geometry']['frames']) for t in tracks) == len(pixel_hashes) == len(visible_hashes) == 107
    frames = FOLDER / 'SpriteFrames.tres'
    text = frames_bytes(tracks).decode().replace('metadata/twilight_native_locomotion_staging = true', 'metadata/twilight_native_locomotion_staging = true\nmetadata/twilight_dedicated_boss_repair = true')
    text = text.replace('"speed": 1.666666667', '"speed": 1.250000000').replace('"speed": 7.142857143', '"speed": 4.687500000').replace('"speed": 9.090909091', '"speed": 6.666666667').replace('"speed": 4.615384615', '"speed": 3.000000000')
    preserve(ROOT / frames, text.encode())
    profile = FOLDER / 'NativeMotionProfile.tres'
    preserve(ROOT / profile, ('\n'.join([
        '[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', '',
        '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', '',
        '[resource]', 'script = ExtResource("1")', f'profile_id = "{KEY}"',
        f'frames_path = "res://{frames.as_posix()}"', 'layout = "directional8"',
        'motion_style = "slash"', 'movement_fps = 12.5', 'reference_speed = 210.0',
        'pixel_scale = 2.0', 'sprite_offset = Vector2(0, -64)',
        'authored_motion_weight = 0.0', 'hit_recoil = 0.0', 'embedded_shadow = false',
        'body_kind = "humanoid"', 'attack_hit_frame = 1', 'action_hit_frames = {"attack": 1}',
        'death_duration = 1.0', 'dedicated_attack = true',
        'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false',
        'metadata/twilight_dedicated_boss_repair = true', ''])).encode())
    actor = {'kind':'boss','quality_tier':'mythic_transform',
             'frames':'res://' + frames.as_posix(),'frames_sha256':core.sha(ROOT / frames),
             'native_profile':'res://' + profile.as_posix(),'native_profile_sha256':core.sha(ROOT / profile),
             'production_connected':False,'detailed_completed':False,'newly_approved':False,
             'native_track_count':33,'native_pose_count':107,'missing_required_tracks':[],
             'quality_review':'HOLD: dedicated identity restored and selected static fixes observed; remaining anatomical hand/camera/support/contact and Main review are explicit in visual-review.json',
             'original_presentation':target['presentation_to_preserve'],'tracks':tracks}
    register = {'schema':'pr122-boss-repair-staging-v1','batch':BATCH.as_posix(),'actors':{KEY:actor},
                'reference':reference,'selected_sources':sources,'new_source_poses':107,
                'newly_approved':0,'default_catalog_switches':0,
                'source_approval':'HOLD; successful geometry/playback is not a boss quality approval',
                'metadata_conflict':'Existing visual.weapon says sword, but pinned source visibly carries an axe. New art follows actual axe reference; shared DB unchanged.',
                'scale_basis':'Standing source normalized to native64 and pixel_scale2.0 preserves original visual_height128; phase0 dying source normalized to58 (display116). Source pixels are never rescaled or retouched.'}
    register['revision'] = REVISION
    register['preserved_previous_candidate'] = {'path':(BATCH / 'candidate.json').as_posix(), 'sha256':core.sha(BASE / 'candidate.json'), 'note':'Initial r001 is preserved; NW weapon ownership is repaired further in r002, and no revision is approved.'}
    preserve(BASE / ('candidate-' + REVISION + '.json'), json_bytes(register))
    preserve(BASE / ('source-selection-' + REVISION + '.json'), json_bytes(sources))
    print('ALBINO_DEMON_STAGED clips=33 unique_poses=107 approvals_added=0 default_switches=0')


if __name__ == '__main__':
    assemble()
