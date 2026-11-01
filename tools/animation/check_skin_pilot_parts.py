"""Verify cutouts preserve source pixels and were not silently replaced."""
import hashlib
import json
import statistics
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

root = Path(__file__).resolve().parents[2]
manifest = json.loads((root / 'data/animation/shared_skin_pilot.json').read_text())
count = 0
for skin in manifest['skins'].values():
    source = root / skin['source']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == skin['source_sha256']
    x, y, w, h = skin['source_cell']
    original = Image.open(source).convert('RGBA').crop((x, y, x+w, y+h))
    for name, part in skin['parts'].items():
        path = root / part['texture'].removeprefix('res://')
        assert hashlib.sha256(path.read_bytes()).hexdigest() == part['sha256']
        if 'derived_from' in part:
            body = Image.open(root / skin['parts']['body']['texture'].removeprefix('res://')).convert('RGBA')
            mask = Image.new('L', body.size)
            ImageDraw.Draw(mask).rectangle(tuple(part['partition_rect']), fill=255)
            body.putalpha(ImageChops.multiply(body.getchannel('A'), mask))
            actual = Image.open(path).convert('RGBA')
            assert body.tobytes() == actual.tobytes(), path
            count += 1
            continue
        mask = Image.new('L', original.size)
        ImageDraw.Draw(mask).polygon([tuple(p) for p in part['polygon']], fill=255)
        expected = original.copy()
        expected.putalpha(ImageChops.multiply(original.getchannel('A'), mask))
        if 'subtract_polygon' in part:
            arm_mask = Image.new('L', original.size)
            ImageDraw.Draw(arm_mask).polygon([tuple(p) for p in part['subtract_polygon']], fill=255)
            expected.putalpha(ImageChops.subtract(expected.getchannel('A'), arm_mask))
            underlay = part['authored_underlay']
            fill_mask = Image.new('L', original.size)
            ImageDraw.Draw(fill_mask).polygon([tuple(p) for p in underlay['polygon']], fill=255)
            fill_mask = ImageChops.multiply(fill_mask, original.getchannel('A').point(lambda a: 255 if a >= 240 else 0))
            fill_mask = ImageChops.multiply(fill_mask, arm_mask)
            sample = list(original.crop(tuple(underlay['source_rect'])).getdata())
            color = tuple(int(statistics.median(p[c] for p in sample)) for c in range(3)) + (255,)
            fill = Image.new('RGBA', original.size, color)
            fill.putalpha(fill_mask)
            expected = Image.alpha_composite(expected, fill)
        if 'subtract_cape' in part:
            cape = part['subtract_cape']
            cape_mask = Image.new('L', original.size)
            ImageDraw.Draw(cape_mask).polygon([tuple(p) for p in cape['polygon']], fill=255)
            ImageDraw.Draw(cape_mask).rectangle((0, 0, original.width, cape['keep_y']), fill=0)
            expected.putalpha(ImageChops.subtract(expected.getchannel('A'), cape_mask))
        if 'additional_cut' in part:
            upper = Image.new('L', original.size)
            ImageDraw.Draw(upper).polygon([tuple(p) for p in part['additional_cut']], fill=255)
            expected.putalpha(ImageChops.subtract(expected.getchannel('A'), upper))
            patch = Image.new('L', original.size)
            ImageDraw.Draw(patch).polygon([tuple(p) for p in part['additional_underlay']], fill=255)
            patch = ImageChops.multiply(patch, upper)
            patch = ImageChops.multiply(patch, original.getchannel('A').point(lambda a: 255 if a >= 240 else 0))
            fill = Image.new('RGBA', original.size, color)
            fill.putalpha(patch)
            expected = Image.alpha_composite(expected, fill)
            if part['blade_cut']:
                cut = Image.new('L', original.size)
                ImageDraw.Draw(cut).polygon([tuple(p) for p in part['blade_cut']], fill=255)
                expected.putalpha(ImageChops.subtract(expected.getchannel('A'), cut))
        actual = Image.open(path).convert('RGBA')
        assert actual.tobytes() == expected.tobytes(), path
        assert actual.getchannel('A').getbbox(), path
        if name.startswith('foot_'):
            assert part['sole_y'] == actual.getchannel('A').getbbox()[3] - 1
        count += 1
print(f'SKIN_PARTS_OK skins={len(manifest["skins"])} parts={count} source_cutouts_and_declared_underlays_verified=true')
