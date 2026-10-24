"""Remove the selected 111 PNG's baked white viewer placeholder for RENDERING.
No navigation file is read, written, classified, or corrected by this utility.
Output stays private; mask/edge inspection remains part of visual review.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

from aden_png import ROOT, sha, write

Image.MAX_IMAGE_PIXELS = 180_000_000
EXPECTED = 'f5c4549298e586d3839246d736b61b6106851af07cde8c5a21522d046ff38f87'


def make(png, output):
    if sha(png) != EXPECTED:
        raise ValueError('This mask recipe is specific to the verified original 111.png')
    if output.resolve().is_relative_to(ROOT):
        raise ValueError('Keep third-party image derivatives outside the public repository')
    image = Image.open(png).convert('RGBA')
    a = np.asarray(image)
    white = (a[:, :, :3] == 255).all(2) & (a[:, :, 3] == 255)
    # The source viewer also uses quantized whites (247,251,247 and
    # 247,247,247). Keep isolated bright stone highlights; only the large
    # contiguous placeholder surfaces join the render-only background.
    near_white = (a[:, :, :3].min(2) >= 247) & (a[:, :, 3] == 255)
    background_labels, _ = ndi.label(near_white)
    background_sizes = np.bincount(background_labels.ravel())
    large = background_sizes >= 4096;large[0] = False
    white |= large[background_labels]
    labels, _ = ndi.label(~white)
    counts = np.bincount(labels.ravel())
    small = counts < 1024;small[0] = False
    mask = white | small[labels]
    # Only light neutral antialias pixels immediately beside the placeholder.
    gray = a[:, :, :3].max(2).astype(int)-a[:, :, :3].min(2).astype(int) <= 3
    mask |= gray & (a[:, :, :3].min(2) >= 190) & ndi.binary_dilation(mask, iterations=3)
    mask &= a[:, :, 3] > 0
    landmarks = [(8000, 4700), (6500, 2700), (6600, 2200), (7500, 3650), (4300, 3600)]
    for x, y in landmarks:
        if mask[y, x]:
            raise ValueError('Known floor landmark covered by visual mask')
    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray((mask*255).astype('uint8')).save(output)
    write(output.with_suffix('.json'), dict(purpose='VIEWER_PLACEHOLDER_RENDER_ALPHA_ONLY',
        not_collision=True, original_png_sha256=EXPECTED, original_png_unchanged=True,
        mask_sha256=sha(output), removed_pixels=int(mask.sum()),
        quantized_white_component_min_pixels=4096,
        floor_landmarks_preserved=[list(p) for p in landmarks], status='EDGE_REVIEW_REQUIRED'))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--png', type=Path, required=True);p.add_argument('--output', type=Path, required=True)
    a = p.parse_args();make(a.png, a.output)
