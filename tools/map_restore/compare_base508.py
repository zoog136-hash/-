"""Compare the restored raster with a pinned original PNG in display space only.

Both visible alpha bounds are normalized for inspection. These thumbnails and
their metrics never become source coordinates or terrain collision data.
"""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont


def thumbnail(image):
    bounds = image.getchannel('A').getbbox()
    visible = image.crop(bounds)
    image.close()
    size = visible.size
    visible = visible.resize((1600, 800), Image.Resampling.LANCZOS)
    return visible, bounds, size


def compare(pack_root, reference, expected_sha, output):
    actual_sha = hashlib.sha256(reference.read_bytes()).hexdigest()
    if actual_sha != expected_sha:
        raise ValueError('Original PNG reference SHA mismatch')
    pack = json.loads((pack_root/'map.json').read_text())
    if pack['art']['status'] != 'S32_TI2_RENDERABLE':
        raise ValueError('Comparison requires actual S32/TI2 rendering')
    Image.MAX_IMAGE_PIXELS = 160_000_000
    image = Image.new('RGBA', tuple(pack['art']['size']))
    for row in pack['art']['chunks']:
        path = pack_root / row['file']
        if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
            raise ValueError('Restored chunk SHA mismatch')
        with Image.open(path) as piece:
            image.paste(piece, tuple(row['position']))
    if hashlib.sha256(image.tobytes()).hexdigest() != pack['art']['pixel_sha256']:
        raise ValueError('Restored raster SHA mismatch')
    restored, restored_bounds, restored_size = thumbnail(image)
    original, original_bounds, original_size = thumbnail(Image.open(reference))
    a, b = np.array(restored), np.array(original)
    mask_a, mask_b = a[:, :, 3] >= 128, b[:, :, 3] >= 128
    shared = mask_a & mask_b
    union = mask_a | mask_b
    result = {'visual_comparison_only': True, 'collision_mapping_changed': False,
              'reference_sha256': actual_sha, 'restored_pixel_sha256': pack['art']['pixel_sha256'],
              'restored_visible_bounds': restored_bounds, 'reference_visible_bounds': original_bounds,
              'restored_visible_size': restored_size, 'reference_visible_size': original_size,
              'normalized_alpha_iou': float(shared.sum()/union.sum()),
              'normalized_rgb_mean_absolute_error': float(np.abs(a[:, :, :3].astype(np.int16)-b[:, :, :3].astype(np.int16))[shared].mean())}
    canvas = Image.new('RGB', (3200, 890), '#101617')
    canvas.paste(restored, (0, 75), restored)
    canvas.paste(original, (1600, 75), original)
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype('DejaVuSans.ttf', 22)
    except OSError:
        font = ImageFont.load_default()
    draw.text((20, 12), 'Restored base508 S32 + TI2 (original source placements)', font=font, fill='white')
    draw.text((1620, 12), 'Existing original 13474.png reference (visible bounds normalized)', font=font, fill='white')
    draw.text((20, 45), 'Visual comparison only; source coordinates and collision remain unchanged.', font=font, fill='#ffdc65')
    canvas.save(output)
    output.with_suffix('.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pack', type=Path)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--reference-sha256', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    compare(args.pack, args.reference, args.reference_sha256, args.output)
