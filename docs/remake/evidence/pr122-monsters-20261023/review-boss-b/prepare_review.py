#!/usr/bin/env python3
"""Read-only visual review sheets for sorted bosses [20:40]; never edit assets."""
from pathlib import Path
import hashlib
import json
import re
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
DIRS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']
FONT = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse(path):
    text = path.read_text()
    external = {id_: value for value, id_ in re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text)}
    poses = {}
    for id_, body in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\s*(.*?)(?=\n\[|\Z)', text, re.S):
        rect = re.search(r'region = Rect2\(([^)]+)\)', body)
        margin = re.search(r'margin = Rect2\(([^)]+)\)', body)
        atlas = re.search(r'atlas = ExtResource\("([^"]+)"\)', body)
        if rect and atlas:
            poses[id_] = dict(path=external[atlas[1]], region=[int(float(x.strip())) for x in rect[1].split(',')],
                              margin=[int(float(x.strip())) for x in margin[1].split(',')] if margin else [0, 0, 0, 0])
    tracks = {}
    for body, loop, name, speed in re.findall(r'\{"frames"\s*:\s*\[(.*?)\],\s*"loop"\s*:\s*(true|false),\s*"name"\s*:\s*&"([^"]+)"\s*,\s*"speed"\s*:\s*([0-9.]+)', text, re.S):
        tracks[name] = dict(poses=[poses[id_] for id_ in re.findall(r'SubResource\("([^"]+)"\)', body)], loop=loop == 'true', fps=float(speed))
    return tracks, sorted(set(external.values()))


def reference(key, target, world, atlases):
    if key in target:
        return target[key]['reference']
    name = key.removeprefix('monster:')
    row = world['overlays'].get(name) or next(row for row in world['additions'] if row['name'] == name)
    visual = row['visual']
    atlas = atlases[visual['atlas']]
    return dict(path=atlas['path'], region=atlas['rects'][visual['cell']], kind='current_world_project_atlas',
                sha256=sha(ROOT / atlas['path'].removeprefix('res://')),
                identity_limit='Existing project appearance; not verified external original game art')


def main():
    scope = json.loads((ROOT / 'data/pr122_monster_production_scope.json').read_text())
    profiles = json.loads((ROOT / 'data/combat_animation_profiles.json').read_text())['profiles']
    target = {row['key']: row for row in json.loads((ROOT / 'data/animation_authoring_sources.json').read_text())['targets']}
    world = json.loads((ROOT / 'data/monsters/monster_world_catalog.json').read_text())
    atlases = json.loads((ROOT / 'data/monsters/art_atlases.json').read_text())
    bosses = sorted((row for row in scope['monsters'] if row['kind'] == 'boss'), key=lambda row: row['id'])[20:40]
    reference_sheet = Image.new('RGB', (1300, 1200), '#30343b')
    draw = ImageDraw.Draw(reference_sheet)
    result, models = [], {}
    images = {}
    for index, row in enumerate(bosses, 20):
        profile = profiles[row['id']]
        ref = reference(row['id'], target, world, atlases)
        source = ROOT / ref['path'].removeprefix('res://')
        with Image.open(source) as image:
            x, y, w, h = ref['region']
            crop = image.convert('RGBA').crop((x, y, x + w, y + h))
        crop_path = OUT / 'references' / f'{index:02}.png'
        crop_path.parent.mkdir(exist_ok=True)
        crop.save(crop_path)
        cx, cy = ((index - 20) % 5) * 260, ((index - 20) // 5) * 300
        preview = crop.copy()
        preview.thumbnail((250, 255))
        reference_sheet.paste(preview, (cx + (260 - preview.width) // 2, cy + 25 + (255 - preview.height) // 2), preview)
        draw.text((cx + 7, cy + 4), f'{index} {Path(profile["frames_path"]).parent.name[:23]}', font=FONT, fill='white')
        path = ROOT / profile['frames_path'].removeprefix('res://')
        tracks, textures = parse(path)
        missing = [texture for texture in textures if not (ROOT / texture.removeprefix('res://')).is_file()]
        model = path.parent.name
        entry = dict(index=index, id=row['id'], preserved_status=row['preserved_status'], approval_preserved=row['preserved_status'] == 'VERIFIED_COMPLETED',
                     profile=profile, profile_sha256=hashlib.sha256(json.dumps(profile, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest(),
                     frames_path=profile['frames_path'], frames_sha256=sha(path), reference=ref,
                     reference_crop=crop_path.relative_to(ROOT).as_posix(), reference_crop_sha256=sha(crop_path),
                     reference_rgba_sha256=hashlib.sha256(crop.tobytes()).hexdigest(),
                     texture_pins=[dict(path=texture, present=(ROOT / texture.removeprefix('res://')).is_file(),
                                        sha256=sha(ROOT / texture.removeprefix('res://')) if (ROOT / texture.removeprefix('res://')).is_file() else None) for texture in textures],
                     missing_textures=missing, model=model, tracks={name:dict(count=len(track['poses']), fps=track['fps'], loop=track['loop']) for name, track in tracks.items()})
        result.append(entry)
        if missing or model in models:
            continue
        rows = [(role, phase) for role in ('idle', 'walk', 'run', 'attack', 'hit', 'death', 'cast')
                for phase in range(max((len(track['poses']) for name, track in tracks.items() if name.startswith(role + '_')), default=0))]
        sheet = Image.new('RGB', (1670, 65 + len(rows) * 155), '#30343b')
        pen = ImageDraw.Draw(sheet)
        pen.text((10, 6), model + ' | actual frame canvas -> 256 normalization + profile scale; fixed foot plane', font=FONT, fill='white')
        profile_scale = float(profile.get('pixel_scale') or 1.0)
        width_ratio = float(profile.get('native_width_ratio') or 1.0)
        all_poses = [pose for track in tracks.values() for pose in track['poses']]
        max_height = max(pose['region'][3] * 256 / (pose['region'][3] + pose['margin'][3]) * profile_scale for pose in all_poses)
        max_width = max(pose['region'][2] * 256 / (pose['region'][2] + pose['margin'][2]) * profile_scale * width_ratio for pose in all_poses)
        diagnostic_scale = min(1.6, 140 / max_height, 185 / max_width)
        for direction in range(8):
            pen.text((75 + direction * 198, 34), DIRS[direction], font=FONT, fill='#f6e0a7')
        for row_index, (role, phase) in enumerate(rows):
            py = 65 + row_index * 155
            pen.text((4, py + 6), role[:4] + str(phase), font=FONT, fill='#eeeeee')
            for direction in range(8):
                track = tracks.get(role + '_' + str(direction))
                if not track or phase >= len(track['poses']):
                    continue
                pose = track['poses'][phase]
                key = pose['path']
                if key not in images:
                    images[key] = Image.open(ROOT / key.removeprefix('res://')).convert('RGBA')
                x, y, w, h = pose['region']
                figure = images[key].crop((x, y, x + w, y + h))
                # Follow ActorMotion's canvas normalization rather than
                # mistaking 512px sources for a larger actor than 256px ones.
                canvas_x, canvas_y = w + pose['margin'][2], h + pose['margin'][3]
                scale_x = 256 / canvas_x * profile_scale * width_ratio * diagnostic_scale
                scale_y = 256 / canvas_y * profile_scale * diagnostic_scale
                figure = figure.resize((max(1, round(figure.width * scale_x)), max(1, round(figure.height * scale_y))))
                px = 64 + direction * 198
                position_x = px + 95 + round((pose['margin'][0] - canvas_x / 2) * scale_x)
                position_y = py + 148 + round((pose['margin'][1] - canvas_y * 5 / 8) * scale_y)
                sheet.paste(figure, (position_x, position_y), figure)
                pen.line((px, py + 148, px + 190, py + 148), fill='#747474')
        destination = OUT / 'sheets' / (model + '.png')
        destination.parent.mkdir(exist_ok=True)
        sheet.save(destination)
        models[model] = dict(path=destination.relative_to(ROOT).as_posix(), sha256=sha(destination), rows=rows,
                             note='Runtime canvas normalization and profile pixel scale; fixed reviewed foot plane. No source edits. Timed playback/physics not inferred from the static sheet.')
    reference_sheet.save(OUT / 'reference-montage.png')
    (OUT / 'prepared.json').write_text(json.dumps(dict(bosses=result, model_sheets=models), ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(dict(bosses=len(result), models=len(models), missing_textures=sum(len(row['missing_textures']) for row in result))))


if __name__ == '__main__':
    main()
