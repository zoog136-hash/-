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
    folder = ROOT / entry['frames'].removeprefix('res://')
    folder = folder.parent
    proof = json.loads((folder / 'rig-proof.json').read_text())
    atlas = Image.open(folder / 'run.png').convert('RGBA')
    assert atlas.size == (1536, 2048) and len(proof['frames']) == 48
    source_frames = ROOT / proof['source'].removeprefix('res://')
    assert hashlib.sha256(source_frames.read_bytes()).hexdigest() == proof['source_sha256']
    text = source_frames.read_text()
    matrices = []
    for direction in range(8):
        reference = proof['frames'][direction * 6].get('source_reference')
        if reference:
            source = Image.open(ROOT / reference['atlas'].removeprefix('res://')).convert('RGBA')
            x, y, w, h = map(int, reference['region'])
            neutral = Image.new('RGBA', (256, 256))
            neutral.paste(source.crop((x, y, x + w, y + h)), tuple(map(int, reference['margin_position'])))
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
                neutral = Image.new('RGBA', (256, 256))
                neutral.paste(src.crop((x, y, x + w, y + h)), tuple(map(int, reference['margin_position'])))
            assert image.crop((0, drop, 256, hip + drop)).tobytes() == neutral.crop((0, 0, 256, hip)).tobytes()
            c4, c8 = components(image, four), components(image, eight)
            records.append({'direction': direction, 'phase': phase, 'rgba_sha256': sha,
                            'bbox': bbox, 'components_4': c4, 'components_8': c8,
                            'head_torso_weapon_exact': True})
    detached = [r for r in records if len(r['components_8']) > 1]
    result = {
        'schema': 'hero-parallel-raster-review-v1', 'revision': folder.name,
        'integrity': 'PASS', 'unique_run_poses': 48,
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
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    for target in [k for k, v in staging['actors'].items() if v.get('frames') == entry['frames']]:
        actor = staging['actors'][target]
        actor['quality_holds'] = ['ORIGINAL_CHARACTER_IDENTITY',
             'ACTUAL_SHOE_CONTACT_AND_CADENCE_NOT_APPROVED', 'PALETTE_WEAPON_IDENTITY_REVIEW']
        if detached:
            actor['quality_holds'].append(f'RASTER_LIMB_CONNECTIONS_{len(detached)}_OF_48_FRAMES')
        main = ROOT / 'docs/remake/pr122-hero-parallel/evidence' / (group + '-' + folder.name + '-visible-main') / 'validation-opengl.json'
        valid_main = False
        if main.exists():
            main_data = json.loads(main.read_text())
            valid_main = (main_data.get('frames_sha256') == hashlib.sha256((folder / 'SpriteFrames.tres').read_bytes()).hexdigest()
                          and main_data.get('run_png_sha256') == hashlib.sha256((folder / 'run.png').read_bytes()).hexdigest())
        actor['independent_validation'] = 'TECHNICAL_MAIN_PASS_QUALITY_HOLD' if valid_main else 'RESOURCE_PASS_MAIN_NOT_RUN'
        actor['raster_review'] = 'res://' + output.relative_to(ROOT).as_posix()
    (ROOT / 'data/pr122_hero_parallel_staging.json').write_text(json.dumps(staging, ensure_ascii=False, indent=2) + '\n')
    print(f'HERO_RESOURCE_INTEGRITY_PASS unique=48 torso_weapon_exact=true quality=HOLD detached_frames={len(detached)} approvals=0')
    return 2


if __name__ == '__main__':
    raise SystemExit(main())
