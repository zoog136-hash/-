"""Stage the new SW run; preserve every existing monk source and profile."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/batch07-monk')
FOLDER = Path('assets/actors/eight_direction/monster_staging/monk_batch07/r001')


def put(path, content):
    path = ROOT / path
    if path.exists() and path.read_bytes() != content:
        raise ValueError('Preserve previous output: ' + str(path))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(content)


def js(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def build():
    historical = 'docs/remake/evidence/pr122-remaining106/batch17/staged-metadata/albino_monk_batch17_authored/provenance.json'
    blob = subprocess.check_output(['git', 'show', 'HEAD:' + historical], cwd=ROOT)
    baseline = json.loads(blob)
    assert baseline['distinct_pixel_frames'] == 128 and baseline['display_reference_height'] == 139.5
    # Match the existing SW idle whole-source neutral convention. Derive one
    # source-wide canvas; never rescale or rearrange individual generated poses.
    idle = [f for f in baseline['frames'] if f['direction'] == 'SW' and f['sheet'] == 7]
    assert len(idle) == 2
    neutral = sum(f['region'][3] - 6 for f in idle) / 2 * 256 / 1304
    source = ROOT / BATCH / 'raw/albino-monk-SW-run6-v01.png'
    initial = core.analyze(source, 6, [0, 3], directions_axis='phase_grid3', canvas_size=1024, directions=['SW'])
    core.require_complete_pose_regions(source, initial)
    canvas = max(64, round(initial['neutral_height'] * 256 / neutral / 8) * 8)
    geometry = core.analyze(source, 6, [0, 3], directions_axis='phase_grid3', canvas_size=canvas, directions=['SW'])
    core.require_complete_pose_regions(source, geometry)
    texture = FOLDER / 'SW-run.png'
    put(texture, source.read_bytes())
    lines = ['[gd_resource type="SpriteFrames" load_steps=8 format=3]', '',
             f'[ext_resource type="Texture2D" path="res://{texture.as_posix()}" id="1"]']
    for i, frame in enumerate(geometry['frames']):
        lines += ['', f'[sub_resource type="AtlasTexture" id="pose_{i}"]', 'atlas = ExtResource("1")',
                  'region = Rect2(%s)' % ', '.join(map(str, frame['region'])),
                  'margin = Rect2(%s)' % ', '.join(map(str, frame['margin'])), 'filter_clip = true']
    poses = ',\n'.join('{"duration": 1.0, "texture": SubResource("pose_%d")}' % i for i in range(6))
    lines += ['', '[resource]', 'animations = [{"frames": [' + poses + '], "loop": true, "name": &"run_3", "speed": 12.5}]',
              'metadata/twilight_canvas_size = Vector2(256, 256)',
              'metadata/twilight_native_locomotion_staging = true',
              'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', '']
    frames = FOLDER / 'SpriteFrames.tres'
    put(frames, '\n'.join(lines).encode())
    scale = 86 / baseline['display_reference_height']
    profile = FOLDER / 'NativeMotionProfile.tres'
    put(profile, '\n'.join([
        '[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]', '',
        '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]', '',
        '[resource]', 'script = ExtResource("1")', 'profile_id = "monster:알비노 몽크"',
        f'frames_path = "res://{frames.as_posix()}"', 'layout = "directional8"',
        'movement_fps = 12.5', 'reference_speed = 210.0', f'pixel_scale = {scale:.12f}',
        f'sprite_offset = Vector2(0, {-32 * scale:.12f})', 'authored_motion_weight = 0.0',
        'hit_recoil = 0.0', 'embedded_shadow = false', 'body_kind = "ape"',
        'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false', '']).encode())
    track = dict(role='run', direction='SW', animation='run_3', source=source.relative_to(ROOT).as_posix(),
                 texture=texture.as_posix(), source_sha256=core.sha(source), geometry=geometry)
    actor = dict(kind='normal', quality_tier='hero_transform', frames='res://' + frames.as_posix(),
                 frames_sha256=core.sha(ROOT / frames), native_profile='res://' + profile.as_posix(),
                 native_profile_sha256=core.sha(ROOT / profile), native_track_count=1, native_pose_count=6,
                 production_connected=False, detailed_completed=False, tracks=[track],
                 quality_review='HOLD: documented model and SW heading requested; actual opposite hind support, source-plane anchors, cross-role identity and Main review remain unapproved')
    put(Path('data/pr122_monster_monk_staging.json'), js(dict(schema='pr122-monster-staging-v1', batch=BATCH.as_posix(),
        actors={'monster:알비노 몽크': actor}, new_approvals=0, default_catalog_switches=0)))
    evidence = dict(source=historical, source_sha256=hashlib.sha256(blob).hexdigest(),
                    preserved_existing_poses=128, preserved_existing_walk=True, preserved_existing_multiview_death=True,
                    old_SW_neutral_height_in_256_canvas=neutral, old_display_reference_height=139.5,
                    new_source_canvas=canvas, new_source_sha256=core.sha(source),
                    transform='One source-wide proportional virtual canvas only; original pixels untouched',
                    new_poses=6, new_approvals=0, production_catalog_changed=False)
    put(BATCH / 'baseline-and-normalization.json', js(evidence))
    put(BATCH / 'selected-geometry.json', js(geometry))
    print('MONK_SW_RUN_STAGED clips=1 poses=6 old128_preserved=true approvals=0')


if __name__ == '__main__':
    build()
