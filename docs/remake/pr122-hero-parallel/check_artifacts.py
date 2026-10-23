#!/usr/bin/env python3
"""Resource and raster review, deliberately separate from Main technical PASS."""
import hashlib
import json
import re
import argparse
from functools import lru_cache
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
DIRECTIONS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']


@lru_cache(maxsize=16)
def rgba(path):
    return Image.open(path).convert('RGBA')


def run_rows(frames):
    rows = [[] for _ in DIRECTIONS]
    for frame in frames:
        direction = frame['direction']
        direction = DIRECTIONS.index(direction) if direction in DIRECTIONS else int(direction)
        rows[direction].append(frame)
    for group in rows:
        group.sort(key=lambda frame: int(frame['phase']))
        assert 4 <= len(group) <= 8
        assert [int(frame['phase']) for frame in group] == list(range(len(group)))
    return rows


def require_reviewed_isolated_artifacts(detached, accepted, actor, atlas_sha):
    """Specific reviewed tiny fragments; never a global connectivity relaxation."""
    assert accepted['status'] == 'APPROVED_ISOLATED_PIXEL_ARTIFACTS'
    assert accepted['atlas_sha256_by_actor'][actor] == atlas_sha
    findings = [row for row in accepted['findings'] if row['id'] == actor]
    by_pose = {(int(row['direction']),int(row['phase'])):row for row in findings}
    assert len(by_pose) == len(findings) == len(detached)
    for row in detached:
        finding = by_pose[(int(row['direction']),int(row['phase']))]
        assert finding['rgba_sha256'] == row['rgba_sha256']
        assert finding['components_8'] == row['components_8']
        assert finding['visually_reviewed'] and finding['accepted_by_latest_user_policy']
        assert all(0 < size <= 24 and size <= row['components_8'][0]*.01
                   for size in row['components_8'][1:])


def require_approved_connectivity(detached, accepted=None):
    """Raw findings stay strict; accept only individually reviewed pixel bytes."""
    if not detached:
        return
    assert accepted and accepted.get('status') == 'APPROVED_MINOR_PIXEL_GAPS'
    findings = accepted['findings']
    assert len(findings) == len(detached)
    by_pose = {(int(r['direction']), int(r['phase'])): r for r in findings}
    assert len(by_pose) == len(findings)
    for row in detached:
        finding = by_pose[(int(row['direction']), int(row['phase']))]
        assert finding['rgba_sha256'] == row['rgba_sha256']
        assert finding['component_sizes'] == row['components_8']
        assert 0 < finding['empty_grid_gap_pixels'] <= 2
        assert finding['accepted_by_latest_user_policy'] is True


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
    actors = staging['actors'] | staging.get('remediation_18', {}).get('actors', {})
    entry = actors[args.actor]
    folder = (ROOT / entry['rig'].removeprefix('res://')).parent
    proof = json.loads((folder / 'rig-proof.json').read_text())
    atlas = rgba(folder / 'run.png')
    rows = run_rows(proof['frames'])
    pose_count = sum(map(len, rows))
    assert atlas.size == (1536, 2048)
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
            source = rgba(ROOT / reference['atlas'].removeprefix('res://'))
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
        reference = rows[direction][0].get('source_reference')
        if reference:
            source = rgba(ROOT / reference['atlas'].removeprefix('res://'))
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
        source = rgba(source_frames.parent / f'poses-{texture}.png')
        neutral = Image.new('RGBA', (256, 256))
        neutral.paste(source.crop((region[0], region[1], region[0] + region[2], region[1] + region[3])), margin[:2])
        matrices.append(neutral)
    records = []
    four = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    eight = [(y, x) for y in (-1, 0, 1) for x in (-1, 0, 1) if (x, y) != (0, 0)]
    for direction in range(8):
        unique = set()
        for phase, row in enumerate(rows[direction]):
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
                src = rgba(ROOT / reference['atlas'].removeprefix('res://'))
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
        'integrity': 'PASS', 'unique_run_poses': pose_count,
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
        assert receipt['native_profile_sha256'] == hashlib.sha256((ROOT / entry['native_profile'].removeprefix('res://')).read_bytes()).hexdigest()
        assert receipt['rig_sha256'] == hashlib.sha256((folder / 'rig-proof.json').read_bytes()).hexdigest()
        acceptance = None
        if detached:
            reviewed = staging.get('audit_once_20261023', {}).get('isolated_pixel_review')
            if reviewed:
                review_path = ROOT / reviewed['report'].removeprefix('res://')
                assert hashlib.sha256(review_path.read_bytes()).hexdigest() == reviewed['sha256']
                data = json.loads(review_path.read_text())
                if args.actor in data['atlas_sha256_by_actor']:
                    require_reviewed_isolated_artifacts(detached,data,args.actor,
                        hashlib.sha256((folder/'run.png').read_bytes()).hexdigest())
                    print('HERO_APPROVED_RESOURCE_RECHECK_PASS reviewed_isolated_pixels=true writes=0')
                    return 0
            seal = receipt['accepted_minor_pixels']
            path = ROOT / seal['report'].removeprefix('res://')
            assert hashlib.sha256(path.read_bytes()).hexdigest() == seal['sha256']
            acceptance = json.loads(path.read_text())
            assert acceptance['source_atlas_sha256'] == hashlib.sha256((folder / 'run.png').read_bytes()).hexdigest()
        require_approved_connectivity(detached, acceptance)
        print('HERO_APPROVED_RESOURCE_RECHECK_PASS source_and_approval_unchanged=true writes=0')
        return 0
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + '\n')
    for target in [k for k, v in actors.items() if v.get('frames') == entry['frames']]:
        actor = actors[target]
        retained_holds = [hold for hold in actor.get('quality_holds', []) if not hold.startswith('RASTER_LIMB_CONNECTIONS_')]
        actor['quality_holds'] = list(dict.fromkeys(retained_holds + ['ORIGINAL_CHARACTER_IDENTITY',
             'ACTUAL_SHOE_CONTACT_AND_CADENCE_NOT_APPROVED', 'PALETTE_WEAPON_IDENTITY_REVIEW']
             ))
        if detached:
            actor['quality_holds'].append(f'RASTER_LIMB_CONNECTIONS_{len(detached)}_OF_{pose_count}_FRAMES')
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
    print(f'HERO_RESOURCE_INTEGRITY_PASS unique={pose_count} torso_weapon_exact=true quality=HOLD detached_frames={len(detached)} approvals=0')
    return 2


if __name__ == '__main__':
    raise SystemExit(main())
