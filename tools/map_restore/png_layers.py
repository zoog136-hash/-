"""Manually reviewed masks from a composite PNG, never terrain classification.

Each original pixel belongs to ground OR one foreground cut. No floor is painted
behind a cut; the scene reconstructs the unchanged composite around its actors.
"""
import re

import numpy as np
from PIL import Image, ImageChops, ImageDraw


def split_foreground(image, mapping, cuts):
    occupied = Image.new('L', image.size)
    alpha = image.getchannel('A')
    matrix = np.asarray(mapping, dtype=float).reshape(2, 3)
    inverse = np.linalg.inv(matrix[:, :2])
    result = []
    identities = set()
    for cut in cuts:
        ident = cut['id']
        if not re.fullmatch(r'[a-z0-9_-]+', ident) or ident in identities:
            raise ValueError('Unique safe foreground ID required')
        identities.add(ident)
        points = np.asarray(cut['polygon_image'], dtype=float)
        foot = np.asarray(cut['foot_image'], dtype=float)
        if (points.ndim != 2 or points.shape[1] != 2 or len(points) < 3 or
                foot.shape != (2,) or not np.isfinite(points).all() or not np.isfinite(foot).all() or
                np.any(points < 0) or np.any(points >= image.size)):
            raise ValueError('Foreground coordinates outside original image')
        mask = Image.new('L', image.size)
        ImageDraw.Draw(mask).polygon([tuple(p) for p in points], fill=255)
        selected = ImageChops.multiply(mask, alpha)
        bounds = selected.getbbox()
        if bounds is None:
            raise ValueError('Empty foreground mask')
        # Original RGB padding also supplies the correct neighbour colour to
        # a linear sampler at the manually cut edge. Alpha ownership is binary.
        bounds = (max(0,bounds[0]-1),max(0,bounds[1]-1),
                  min(image.width,bounds[2]+1),min(image.height,bounds[3]+1))
        if ImageChops.multiply(mask, occupied).getbbox():
            raise ValueError('Foreground masks overlap; original pixels need one owner')
        occupied = ImageChops.lighter(occupied, mask)
        layer = image.crop(bounds)
        layer.putalpha(selected.crop(bounds))
        world = inverse @ (foot-matrix[:, 2])
        result.append(dict(id=ident, image=layer, image_origin=list(bounds[:2]),
            foot_world=world.tolist(), foot_image=foot.tolist(),
            provenance='MANUAL_MASK_FROM_SINGLE_COMPOSITE',
            collision_correspondence=cut.get('collision_correspondence', 'REVIEW_REQUIRED')))
    ground = image.copy()
    ground.putalpha(ImageChops.multiply(alpha, ImageChops.invert(occupied)))
    return ground, result
