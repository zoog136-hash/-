"""Verify cutouts preserve source pixels and were not silently replaced."""
import hashlib
import json
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
        mask = Image.new('L', original.size)
        ImageDraw.Draw(mask).polygon([tuple(p) for p in part['polygon']], fill=255)
        expected = original.copy()
        expected.putalpha(ImageChops.multiply(original.getchannel('A'), mask))
        actual = Image.open(path).convert('RGBA')
        assert actual.tobytes() == expected.tobytes(), path
        assert actual.getchannel('A').getbbox(), path
        if name.startswith('foot_'):
            assert part['sole_y'] == actual.getchannel('A').getbbox()[3] - 1
        count += 1
print(f'SKIN_PARTS_OK skins={len(manifest["skins"])} parts={count} source_pixels_preserved=true')
