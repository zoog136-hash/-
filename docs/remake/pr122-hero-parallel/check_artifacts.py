#!/usr/bin/env python3
"""Resource and raster review, deliberately separate from Main technical PASS."""
import hashlib
import json
import re
import argparse
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]


def components(image, neighbors):
    points = {i for i, alpha in enumerate(image.getchannel('A').get_flattened_data()) if alpha > 16}
    sizes = []
    while points:
        queue = [points.pop()]
        size = 0
        while queue:
            point = queue.pop()
            size += 1
            for dy, dx in neighbors:
                other = point + dy * 256 + dx
                if other in points and abs(other % 256 - point % 256) <= 1:
                    points.remove(other)
                    queue.append(other)
        if size > 12:
            sizes.append(size)
    return sorted(sizes, reverse=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--actor', default='transform:179')
    args = parser.parse_args()
    staging = json.loads((ROOT / 'data/pr122_hero_parallel_staging.json').read_text())
    entry = staging['actors'][args.actor]
    folder = (ROOT / entry['rig'].removeprefix('res://')).parent
    proof = json.loads((folder / 'rig-proof.json').read_text())
    atlas = Image.open(folder / 'run.png').convert('RGBA')
    assert atlas.size == (1536, 2048) and len(proof['frames']) == 48
    source_frames = ROOT / proof['source'].removeprefix('res://')
    assert hashlib.sha256(source_frames.read_bytes()).hexdigest() == proof['source_sha256']
    registered_action_frames = 0
    registered_unique_hashes = set()
    for relative, expected in proof.get('source_hashes', {}).items():
        assert hashlib.sha256((ROOT / relative.removeprefix('res://')).read_bytes()).hexdigest() == expected
    for track, phases in proof.get('track_sources', {}).items():
        unique = set()
        for phase in phases:
            reference = phase['source_reference']
            source = Image.open(ROOT / reference['atlas'].removeprefix('res://')).convert('RGBA')
            x, y, w, h = map(int, reference['region'])
            canvas = Image.new('RGBA', (256, 256))
            canvas.paste(source.crop((x, y, x + w, y + h)), tuple(map(int, reference['margin_position'])))
            sha = hashlib.sha256(canvas.tobytes()).hexdigest()
            assert sha == phase['canvas_rgba_sha256'] and sha not in unique, track
            unique.add(sha)
            registered_unique_hashes.add(sha)
            registered_action_frames += 1
    text = source_frames.read_text() if source_frames.suffix == '.tres' else ''
    matrices = []
    for direction in range(8):
        reference = proof['frames'][direction * 6].get('source_reference')
        if reference:
            source = Image.open(ROOT / reference['atlas'].removeprefix('res://')).convert('RGBA')
            x, y, w, h = map(int, reference['region'])
            neutral = Image.new('RGBA', tuple(reference.get('virtual_canvas_size', [256, 256])))
            neutral.paste(source.crop((x, y, x + w, y + h)), tuple(map(int, reference['margin_position'])))
            if neutral.size != (256, 256):
                neutral = neutral.resize((256, 256), Image.Resampling.NEAREST)
            if reference.get("mirrored_x", False):
                neutral = neutral.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            matrices.append(neutral)
            continue
        block = re.search(r'\[sub_resource type="AtlasTexture" id="pose_' + str(direction) + r'"\](.*?)(?=\[)', text, re.S)[1]
        texture = int(re.search(r'ExtResource\("(\d+)"\)', block)[1]) - 1
        region = list(map(int, re.search(r'region = Rect2\(([^)]+)', block)[1].split(', ')))
        margin = list(map(int, re.search(r'margin = Rect2\(([^)]+)', block)[1].split(', ')))
        source = Image.open(source_frames.parent / f'poses-{texture}.png').convert('RGBA')
        neutral = Image.new('RGBA', (256, 256))
        neutral.paste(source.crop((region[0], region[1], region[0] + region[2], region[1] + region[3])), margin[:2])
        matrices.append(neutral)
    records = []
    four = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    eight = [(y, x) for y in (-1, 0, 1) for x in (-1, 0, 1) if (x, y) != (0, 0)]
    for direction in range(8):
        unique = set()
        for phase in range(6):
            row = proof['frames'][direction * 6 + phase]
            image = atlas.crop((phase * 256, direction * 256, phase * 256 + 256, direction * 256 + 256))
            sha = hashlib.sha256(image.tobytes()).hexdigest()
            assert sha == row['rgba_sha256'] and sha not in unique
            unique.add(sha)
            bbox = image.getbbox()
            assert bbox and bbox[0] > 0 and bbox[1] > 0 and bbox[2] < 256 and bbox[3] < 256
            # The whole head/torso/spear material stays byte exact above the
            # declared leg boundary; no width fitting, recolouring or loss.
            hip = int(row['source_partition']['hip_y'])
            drop = int(row['root_down'])
            neutral = matrices[direction]
            if row.get('source_reference'):
                reference = row['source_reference']
                src = Image.open(ROOT / reference['atlas'].removeprefix('res://')).convert('RGBA')
                x, y, w, h = map(int, reference['region'])
                neutral = Image.new('RGBA', tuple(reference.get('virtual_canvas_size', [256, 256])))
                neutral.paste(src.crop((x, y, x + w, y + h)), tuple(map(int, reference['margin_position'])))
                if neutral.size != (256, 256):
                    neutral = neutral.resize((256, 256), Image.Resampling.NEAREST)
                if reference.get("mirrored_x", False):
                    neutral = neutral.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            assert image.crop((0, drop, 256, hip + drop)).tobytes() == neutral.crop((0, 0, 256, hip)).tobytes()
            c4, c8 = components(image, four), components(image, eight)
            records.append({'direction': direction, 'phase': phase, 'rgba_sha256': sha,
                            'bbox': bbox, 'components_4': c4, 'components_8': c8,
                            'head_torso_weapon_exact': True})
    detached = [r for r in records if len(r['components_8']) > 1]
    result = {
        'schema': 'hero-parallel-raster-review-v1', 'revision': folder.name,
        'integrity': 'PASS', 'unique_run_poses': 48,
        'exact_registered_action_frames': registered_action_frames,
        'unique_registered_source_poses': len(registered_unique_hashes),
        'new_death_authored_directions': proof.get('death_policy', {}).get('new_source_directions', 0),
        'source_body_and_weapon_above_hip_exact': True,
        'alpha_threshold': 16, 'component_pixels_threshold': 12,
        'connectivity_checks': ['4-neighbor', '8-neighbor'],
        'frames_with_major_detached_components_8_neighbor': len(detached),
        'quality': 'HOLD', 'raster_connectivity': 'HOLD' if detached else 'PASS',
        'anatomical_and_original_identity_approval': False,
        'reason': ('Detached source-material components require repair. ' if detached else 'Source-material connectivity passed. ')
                  + 'Joint-model support labels are not measured shoe contact; original hero identity still requires review.',
        'new_final_approvals': 0, 'frames': records,
    }
    group = folder.parent.name
    evidence_key = folder.name if group == 'lance_shared' else group + '-' + folder.name
    output = ROOT / 'docs/remake/pr122-hero-parallel/evidence' / evidence_key / 'raster-review.json'
    if entry.get('final_approved'):
        receipt = json.loads((ROOT / entry['approval_receipt'].removeprefix('res://')).read_text())
        assert receipt['frames_sha256'] == hashlib.sha256((ROOT / entry['frames'].removeprefix('res://')).read_bytes()).hexdigest()
        assert receipt['rig_sha256'] == hashlib.sha256((folder / 'rig-proof.json').read_bytes()).hexdigest()
        assert not detached
        print('HERO_APPROVED_RESOURCE_RECHECK_PASS source_and_approval_unchanged=true writes=0')
        return 0
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    for target in [k for k, v in staging['actors'].items() if v.get('frames') == entry['frames']]:
        actor = staging['actors'][target]
        retained_holds = [hold for hold in actor.get('quality_holds', []) if not hold.startswith('RASTER_LIMB_CONNECTIONS_')]
        actor['quality_holds'] = list(dict.fromkeys(retained_holds + ['ORIGINAL_CHARACTER_IDENTITY',
             'ACTUAL_SHOE_CONTACT_AND_CADENCE_NOT_APPROVED', 'PALETTE_WEAPON_IDENTITY_REVIEW']
             ))
        if detached:
            actor['quality_holds'].append(f'RASTER_LIMB_CONNECTIONS_{len(detached)}_OF_48_FRAMES')
        main = (ROOT / actor['main_validation_report'].removeprefix('res://') if actor.get('main_validation_report') else
                ROOT / 'docs/remake/pr122-hero-parallel/evidence' / (group + '-' + folder.name + '-visible-main') / 'validation-opengl.json')
        valid_main = False
        if main.exists():
            main_data = json.loads(main.read_text())
            valid_main = (any(row.get('id') == target for row in main_data.get('actors', []))
                          and main_data.get('frames_sha256') == hashlib.sha256((ROOT / actor['frames'].removeprefix('res://')).read_bytes()).hexdigest()
                          and main_data.get('run_png_sha256') == hashlib.sha256((folder / 'run.png').read_bytes()).hexdigest())
        actor['independent_validation'] = 'TECHNICAL_MAIN_PASS_QUALITY_HOLD' if valid_main else 'RESOURCE_PASS_MAIN_NOT_RUN'
        actor['raster_review'] = 'res://' + output.relative_to(ROOT).as_posix()
    (ROOT / 'data/pr122_hero_parallel_staging.json').write_text(json.dumps(staging, ensure_ascii=False, indent=2) + '\n')
    print(f'HERO_RESOURCE_INTEGRITY_PASS unique=48 torso_weapon_exact=true quality=HOLD detached_frames={len(detached)} approvals=0')
    return 2


if __name__ == '__main__':
    raise SystemExit(main())
