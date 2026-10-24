#!/usr/bin/env python3
"""Read-only r001 source-frame diagnostics for independent first-pass QA."""
import hashlib
import json
from pathlib import Path
import re
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[6]
BASE = Path(__file__).resolve().parent
SOURCE = ROOT / 'docs/remake/evidence/pr122-monsters-20261023/boss-fix02-zombie-lord'
candidate = json.loads((SOURCE / 'candidate.json').read_text())
actor = candidate['actors']['monster:죽음의 좀비 로드']
profile = ROOT / actor['native_profile'].removeprefix('res://')
scale = float(re.search(r'^pixel_scale = ([\d.]+)', profile.read_text(), re.M)[1])
tracks = actor['tracks']
directions = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']
CW, CH, FOOT, ZOOM = 380, 280, 250, 1.5


def page(kind, dirs, roles, columns):
    sheet = Image.new('RGBA', (columns * CW, len(dirs) * CH), (50, 61, 66, 255))
    draw = ImageDraw.Draw(sheet)
    for y, direction in enumerate(dirs):
        column = 0
        for role in roles:
            track = next(t for t in tracks if t['direction'] == direction and t['role'] == role)
            source = ROOT / track['source']
            assert hashlib.sha256(source.read_bytes()).hexdigest() == track['source_sha256']
            pixels = Image.open(source).convert('RGBA')
            geometry = track['geometry']
            factor = 256 / geometry['canvas_size'][0] * scale * ZOOM
            for phase, frame in enumerate(geometry['frames']):
                x0, y0, width, height = frame['region']
                crop = pixels.crop((x0, y0, x0 + width, y0 + height))
                crop = crop.resize((round(width * factor), round(height * factor)), Image.Resampling.LANCZOS)
                anchor = [geometry['foot'][i] - frame['margin'][i] for i in range(2)]
                x = round(column * CW + CW / 2 - anchor[0] * factor)
                yy = round(y * CH + FOOT - anchor[1] * factor)
                sheet.alpha_composite(crop, (x, yy))
                draw.text((column * CW + 5, y * CH + 4), f'{track["animation"]} {direction} {role} {phase}', fill='white')
                column += 1
        draw.line((0, y * CH + FOOT, columns * CW, y * CH + FOOT), fill=(95, 105, 110, 255))
    sheet.convert('RGB').save(BASE / f'{kind}.png')


if __name__ == '__main__':
    for index in (0, 1):
        subset = directions[index * 4:index * 4 + 4]
        page(f'core-{index}', subset, ['idle', 'attack', 'hit'], 8)
        page(f'run-{index}', subset, ['run'], 6)
    page('death', ['S'], ['death'], 4)
    print('ZOMBIE_INDEPENDENT_DIAGNOSTICS tracks=33 poses=116')
