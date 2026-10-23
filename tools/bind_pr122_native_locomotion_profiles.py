#!/usr/bin/env python3
"""Bind staged native clips to real game profiles without enabling partial actors."""
import hashlib
import json
from pathlib import Path
import statistics
from PIL import Image

from stage_pr122_native_locomotion import preserve_write
import pr122_native_production_approvals as production_approvals


def runtime_walk_reference_height(root, actor):
    """Measure the existing display-height convention in runtime canvas units.

    Raw source resolution and transparent reviewed padding must not resize the
    whole actor. ActorMotion normalizes each texture to the reference canvas;
    use that same ratio while retaining every reviewed per-pose canvas.
    """
    reference = actor['canvas_size'][1]
    if type(reference) is not int or reference <= 0:
        raise ValueError('Require a positive runtime reference canvas')
    # Existing walking references retain their exact sizing. New mythic scope
    # omits walk; use authored run neutral phases only when walk is absent.
    reference_role = "walk" if any(t["role"] == "walk" for t in actor["tracks"]) else "run"
    samples = []
    for track in actor['tracks']:
        if track['role'] != reference_role:
            continue
        geometry = track['geometry']
        frames = [frame for frame in geometry['frames'] if frame['row'] in (0, 3)]
        if sorted(frame['row'] for frame in frames) != [0, 3]:
            raise ValueError('Require distinct authored neutral phases 0 and 3')
        heights = []
        with Image.open(root / track['source']) as image:
            alpha = image.convert('RGBA').getchannel('A')
            for frame in frames:
                x, y, width, height = frame['region']
                canvas = frame.get('canvas_size', geometry['canvas_size'])[1]
                if (type(canvas) is not int or canvas <= 0
                        or any(type(v) is not int for v in (x, y, width, height))
                        or min(x, y) < 0 or min(width, height) <= 0
                        or x + width > image.width or y + height > image.height):
                    raise ValueError('Invalid exact source region or runtime canvas')
                bounds = alpha.crop((x, y, x + width, y + height)).point(
                    lambda value: 255 if value > 16 else 0).getbbox()
                if bounds is None:
                    raise ValueError('Neutral pose has no alpha>16 source pixels')
                heights.append((bounds[3] - bounds[1]) * reference / canvas)
        samples.append(dict(direction=track['direction'],
                            neutral_runtime_heights=heights,
                            reference_height=statistics.median(heights)))
    if not samples:
        raise ValueError('Require an authored walking or running reference')
    return statistics.median(sample['reference_height'] for sample in samples), samples


def bind(root, only_key=None):
    path = root / 'data/pr122_native_locomotion_staging.json'
    register = json.loads(path.read_text())
    approval_state = production_approvals.load_state(root, register=register)
    bind_keys = approval_state.bind_keys(register, only_key)
    catalog = json.loads((root / 'data/combat_animation_profiles.json').read_text())['profiles']
    for key in bind_keys:
        actor = register['actors'][key]
        assert actor['production_connected'] is False and actor['detailed_completed'] is False
        frames = root / actor['frames'].removeprefix('res://')
        assert hashlib.sha256(frames.read_bytes()).hexdigest() == actor['frames_sha256']
        for track in actor['tracks']:
            for field in ('source', 'texture'):
                assert hashlib.sha256((root / track[field]).read_bytes()).hexdigest() == track['source_sha256']
        # Same 110px candidate body-height convention already used by player.gd.
        # The 1024px virtual canvas needs its own -128px foot offset, not the
        # -32px offset of the existing 256px sheets. No source pixels are scaled.
        height, sizing_samples = runtime_walk_reference_height(root, actor)
        scale = 110.0 / height
        foot_offset = (actor['canvas_size'][1] / 2 - actor['foot'][1]) * scale
        prior = catalog[key]
        destination = frames.with_name('NativeMotionProfile.tres')
        lines = [
            '[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]',
            '', '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]',
            '', '[resource]', 'script = ExtResource("1")', f'profile_id = "{key}"',
            f'frames_path = "{actor["frames"]}"', 'layout = "directional8"',
            f'motion_style = "{prior.get("motion_style", "slash")}"',
            'movement_fps = 12.5', 'reference_speed = 210.0',
            f'floating = {str(prior.get("floating", False)).lower()}',
            f'body_kind = "{prior.get("body_kind", "humanoid")}"',
            f'pixel_scale = {scale:.12f}', f'sprite_offset = Vector2(0, {foot_offset:.12f})',
            'authored_motion_weight = 0.0', 'hit_recoil = 0.0', 'embedded_shadow = false',
            'attack_hit_frame = 3', 'action_hit_frames = {"attack": 3}',
            f'attack_animation_speed = {float(prior.get("attack_animation_speed", 1.0)):.9f}',
            f'death_duration = {float(prior.get("death_duration", .65)):.9f}',
            f'attack_hit_ratio = {float(prior.get("attack_hit_ratio", .45)):.9f}',
            f'use_profile_hit_ratio = {str("attack_hit_ratio" in prior).lower()}',
            'metadata/twilight_native_locomotion_staging = true',
            'metadata/twilight_production_connected = false',
            'metadata/twilight_detailed_completed = false', '']
        preserve_write(destination, '\n'.join(lines).encode())
        actor['native_profile'] = 'res://' + destination.relative_to(root).as_posix()
        actor['native_profile_sha256'] = hashlib.sha256(destination.read_bytes()).hexdigest()
        actor['native_profile_basis'] = dict(display_height=110.0, source_reference_height=height,
                                            pixel_scale=scale, foot_offset_y=foot_offset,
                                            runtime_sizing_method='visible_alpha_gt16_in_reference_canvas',
                                            walk_reference_samples=sizing_samples,
                                            sizing_review='HOLD; native staging only',
                                            production_catalog_replaced=False)
    approval_state.assert_preserved(approval_state.manifest, register)
    path.write_text(json.dumps(register, ensure_ascii=False, indent=2) + '\n')
    print(f'PR122_NATIVE_PROFILES_BOUND actors={len(register["actors"])} complete_actors_added=0 production_switches=0')


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--key')
    args = parser.parse_args()
    bind(Path(__file__).resolve().parents[1], args.key)


if __name__ == '__main__':
    main()
