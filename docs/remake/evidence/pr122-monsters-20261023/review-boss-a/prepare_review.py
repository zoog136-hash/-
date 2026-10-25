"""Read existing boss resources and build private, foot-anchored inspection sheets."""
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
DIRECTIONS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']
IMAGE_CACHE = {}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads((ROOT / path).read_text())


def attrs(text):
    return dict(re.findall(r'(\w+)="([^"]*)"', text))


def parse(path):
    text = path.read_text()
    ext = {attrs(line)['id']: attrs(line)['path'] for line in re.findall(r'\[ext_resource[^\]]*\]', text)}
    subs = {}
    for key, body in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', text, re.S):
        atlas = re.search(r'atlas = ExtResource\("([^"]+)"\)', body)
        rect = re.search(r'region = Rect2\(([^)]*)\)', body)
        margin = re.search(r'margin = Rect2\(([^)]*)\)', body)
        if atlas and rect:
            subs[key] = {'path': ext[atlas[1]], 'region': [round(float(x.strip())) for x in rect[1].split(',')],
                         'margin': [round(float(x.strip())) for x in margin[1].split(',')] if margin else [0, 0, 0, 0]}
    tracks = {}
    for body, name in re.findall(r'\{"frames"\s*:\s*\[(.*?)\],\s*"loop"\s*:\s*(?:true|false),\s*"name"\s*:\s*&"([^"]+)"', text, re.S):
        tracks[name] = [subs[key] for key in re.findall(r'SubResource\("([^"]+)"\)', body)]
    return tracks, ext


def pin(path):
    relative = str(path.relative_to(ROOT))
    return {'path': relative, 'present': path.is_file(), 'sha256': digest(path) if path.is_file() else None}


def tint_value(value):
    if isinstance(value, list):
        return np.array(value[:4] if len(value) == 4 else value[:3] + [1.0])
    value = str(value or 'ffffff').lstrip('#')
    return np.array([int(value[i:i + 2], 16) / 255 for i in range(0, 6, 2)] + [1.0])


def make_pose(frame, profile, viewport, reference_canvas=256):
    path = frame['path']
    if path not in IMAGE_CACHE:
        IMAGE_CACHE[path] = Image.open(ROOT / path.removeprefix('res://')).convert('RGBA')
    source = IMAGE_CACHE[path]
    x, y, w, h = frame['region']
    crop = source.crop((x, y, x + w, y + h))
    pixels = np.array(crop).astype(float)
    pixels *= tint_value(profile.get('color_tint'))
    crop = Image.fromarray(np.clip(pixels, 0, 255).astype('uint8'), 'RGBA')
    mx, my, mw, mh = frame['margin']
    canvas = Image.new('RGBA', (w + mw, h + mh))
    canvas.alpha_composite(crop, (mx, my))
    scale = float(profile.get('pixel_scale', 1.0)) * reference_canvas / canvas.height
    if float(profile.get('pixel_scale', 1.0)) == 0:
        scale = 1.0
    width_ratio = float(profile.get('native_width_ratio', 1.0))
    size = (max(1, round(canvas.width * scale * width_ratio)), max(1, round(canvas.height * scale)))
    canvas = canvas.resize(size, Image.Resampling.NEAREST)
    xmin, ymin, xmax, ymax = viewport
    result = Image.new('RGBA', (xmax - xmin, ymax - ymin), '#34393fff')
    draw = ImageDraw.Draw(result)
    draw.line((0, -ymin, result.width, -ymin), fill='#667078', width=1)
    offset = profile.get('sprite_offset', [0, -32])
    result.alpha_composite(canvas, (round(-xmin + offset[0] - canvas.width / 2), round(-ymin + offset[1] - canvas.height / 2)))
    return result.resize((result.width * 2, result.height * 2), Image.Resampling.NEAREST)


def viewport_for(tracks, profile):
    # This envelope includes every source region in the inspected living roles.
    # A wing/weapon cannot be clipped merely by the private sheet's viewport.
    bounds = []
    offset = profile.get('sprite_offset', [0, -32])
    for key, values in tracks.items():
        if key.rsplit('_', 1)[0] not in ('idle', 'run', 'walk', 'attack', 'hit'):
            continue
        for frame in values:
            x, y, w, h = frame['region']
            mx, my, mw, mh = frame['margin']
            sy = float(profile.get('pixel_scale', 1.0)) * 256 / (h + mh)
            sx = sy * float(profile.get('native_width_ratio', 1.0))
            left = offset[0] + (mx - (w + mw) / 2) * sx
            top = offset[1] + (my - (h + mh) / 2) * sy
            bounds.append((left, top, left + w * sx, top + h * sy))
    return (int(min(b[0] for b in bounds)) - 8, int(min(b[1] for b in bounds)) - 8,
            int(max(b[2] for b in bounds)) + 9, max(12, int(max(b[3] for b in bounds)) + 9))


def sheet(path, tracks, profile, mode):
    viewport = viewport_for(tracks, profile)
    cw, ch = (viewport[2] - viewport[0]) * 2, (viewport[3] - viewport[1]) * 2
    if mode == 'overview':
        selected = [('idle', 0), ('idle', 1), ('move', 0), ('attack', 'contact'), ('hit', 0), ('hit', -1)]
    elif mode == 'move':
        count = max(len(tracks.get(f'run_{i}', tracks.get(f'walk_{i}', []))) for i in range(8))
        selected = [('move', j) for j in range(count)]
    else:
        count = max(len(tracks.get(f'attack_{i}', [])) for i in range(8))
        selected = [('attack', j) for j in range(count)]
    image = Image.new('RGB', (cw * len(selected) + 44, (ch + 24) * 8 + 48), '#191d22')
    draw = ImageDraw.Draw(image)
    draw.text((8, 8), path.parent.name + ' | ' + mode, fill='white')
    examined = []
    for i, direction in enumerate(DIRECTIONS):
        draw.text((4, i * (ch + 24) + 48 + ch // 2), direction, fill='#ffffff')
        for col, (role, phase) in enumerate(selected):
            resolved = 'run' if f'run_{i}' in tracks else 'walk' if role == 'move' else role
            if role != 'move':
                resolved = role
            values = tracks.get(f'{resolved}_{i}', [])
            frame_phase = int(profile.get('action_hit_frames', {}).get('attack', profile.get('attack_hit_frame', 0))) if phase == 'contact' else phase
            frame_phase = min(len(values) - 1, frame_phase) if values else -1
            cell_x, cell_y = 44 + col * cw, 40 + i * (ch + 24)
            draw.text((cell_x + 6, cell_y), f'{resolved} {frame_phase}', fill='#cbd1db')
            if values:
                pose = make_pose(values[frame_phase], profile, viewport)
                image.paste(pose.convert('RGB'), (cell_x, cell_y + 20))
                examined.append({'direction': direction, 'role': resolved, 'phase': frame_phase})
    destination = OUT / 'sheets' / f'{path.parent.name}-{mode}.png'
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination)
    return {'path': destination.relative_to(ROOT).as_posix(), 'sha256': digest(destination), 'planned_samples': examined}


def main():
    scope = read('data/pr122_monster_production_scope.json')
    bosses = sorted([row for row in scope['monsters'] if row['kind'] == 'boss'], key=lambda row: row['id'])[:20]
    profiles = read('data/combat_animation_profiles.json')['profiles']
    sources = {row['key']: row for row in read('data/animation_authoring_sources.json')['targets']}
    db = read('data/monsters/monster_world_catalog.json')
    records = dict(db['overlays'])
    records.update({row['name']: row for row in db['additions']})
    atlases = read('data/monsters/art_atlases.json')
    unique_sets = {}
    result = []
    refsheet = Image.new('RGB', (5 * 240, 4 * 282), '#20242a')
    draw = ImageDraw.Draw(refsheet)
    for index, boss in enumerate(bosses):
        key = boss['id']
        profile = profiles[key]
        frames_path = ROOT / profile['frames_path'].removeprefix('res://')
        tracks, ext = parse(frames_path)
        source = sources.get(key, {}).get('reference')
        source_kind = 'animation_authoring_sources'
        if source is None:
            visual = records[boss['name']]['visual']
            plate = atlases[visual['atlas']]
            source = {'path': plate['path'], 'region': plate['rects'][visual['cell']],
                      'kind': 'canonical_project_atlas_fallback_from_DB',
                      'limitation': 'No dedicated original-source record for this previously approved identity'}
            source_kind = 'monster_world_catalog_visual_atlas_cell'
        raw_ref = ROOT / source['path'].removeprefix('res://')
        ref = Image.open(raw_ref).convert('RGBA')
        region = source.get('region')
        if region:
            x, y, w, h = region
            ref = ref.crop((x, y, x + w, y + h))
        ref.thumbnail((220, 235), Image.Resampling.LANCZOS)
        sx, sy = (index % 5) * 240, (index // 5) * 282
        draw.text((sx + 4, sy + 4), str(index) + ' ' + boss['name'], fill='white')
        refsheet.paste(ref, (sx + (240 - ref.width) // 2, sy + 30), ref)
        ref_path = OUT / 'references' / f'{index:02d}-reference.png'
        ref_path.parent.mkdir(parents=True, exist_ok=True)
        ref.save(ref_path)
        sets_key = profile['frames_path']
        if sets_key not in unique_sets:
            missing = [path for path in ext.values() if not (ROOT / path.removeprefix('res://')).is_file()]
            group = {'frames_path': sets_key, 'runtime_species': [], 'missing_PNGs': missing,
                     'source_pins': [pin(ROOT / path.removeprefix('res://')) for path in ext.values()],
                     'track_counts': {name: len(frames) for name, frames in tracks.items()}, 'sheets': {}}
            if not missing:
                group['sheets'] = {mode: sheet(frames_path, tracks, profile, mode) for mode in ['overview', 'move', 'attack']}
            unique_sets[sets_key] = group
        unique_sets[sets_key]['runtime_species'].append(key)
        result.append({'id': key, 'approval_preserved': boss['preserved_status'] == 'VERIFIED_COMPLETED',
                       'preserved_production_status': boss['preserved_status'], 'profile': profile,
                       'frames_pin': pin(frames_path), 'reference': source, 'reference_resolution': source_kind,
                       'reference_pin': pin(raw_ref), 'reference_crop_pin': pin(ref_path),
                       'actual_examined_views': [], 'actual_examined_roles': [], 'visual_findings': [],
                       'status': 'NOT_REVIEWED', 'reasons': ['Private visual inspection has not yet been recorded'],
                       'unseen_not_reviewed': ['Animation timing and actual Main rendering are not proved by static sheets']})
    ref_path = OUT / 'references-overview.png'
    refsheet.save(ref_path)
    report = {'schema': 'pr122-boss-visual-review-preparation-v1', 'read_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'scope': 'boss sorted ids [0:20], including17 preserved completions', 'approval_mutations': 0,
              'reference_overview_pin': pin(ref_path), 'bosses': result, 'runtime_sets': unique_sets}
    (OUT / 'prepared.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'bosses': len(result), 'unique_runtime_sets': len(unique_sets),
                      'ready_sets': sum(not row['missing_PNGs'] for row in unique_sets.values()),
                      'missing_PNGs': sum(len(row['missing_PNGs']) for row in unique_sets.values())}))


if __name__ == '__main__':
    main()
