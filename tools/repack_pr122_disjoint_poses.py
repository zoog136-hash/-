#!/usr/bin/env python3
"""Separate disjoint authored bodies without resampling or losing foreground.

The original image is never changed. Only alpha <= 16 pixels further than two
pixels from a foreground body may be removed as transparent background noise.
Ambiguous ownership, missing parts, clipping, and importer failures remain HOLD.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import import_original_based_motion as importer


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repack(source, output, direction):
    assert source.is_file() and not output.exists()
    rgba = np.array(Image.open(source).convert('RGBA'))
    height, width = rgba.shape[:2]
    assert width % 2 == 0 and height % 3 == 0
    labels, _ = ndimage.label(rgba[:, :, 3] > 16, np.ones((3, 3)))
    sizes = np.bincount(labels.ravel())
    bodies = [int(i) for i in np.flatnonzero(sizes >= 200) if i]
    assert len(bodies) == 6, 'Require exactly six separate foreground bodies'
    large = np.isin(labels, bodies)
    distance, nearest = ndimage.distance_transform_edt(~large, return_indices=True)
    owners = labels[nearest[0], nearest[1]]
    foreground = rgba[:, :, 3] > 16
    assert np.all(distance[foreground] <= 2), 'Detached foreground needs review'
    kept = (rgba[:, :, 3] > 0) & (distance <= 2)
    removed = (rgba[:, :, 3] > 0) & ~kept
    assert not removed.any() or int(rgba[:, :, 3][removed].max()) <= 16
    cell_width, cell_height = 768, height // 3
    result = np.zeros((height, cell_width * 2, 4), dtype=np.uint8)
    slots, proof = set(), []
    for body in bodies:
        cy, cx = ndimage.center_of_mass(large, labels, body)
        column, row = int(cx // (width // 2)), int(cy // cell_height)
        assert 0 <= column < 2 and 0 <= row < 3
        slot = row * 2 + column
        assert slot not in slots, 'Multiple bodies in one temporal slot'
        slots.add(slot)
        mask = kept & (owners == body)
        ys, xs = np.where(mask)
        dx = column * cell_width + cell_width // 2 - (column * (width // 2) + width // 4)
        dy = row * cell_height + cell_height // 2 - (int(ys.min()) + int(ys.max())) // 2
        target_x = xs + dx
        target_y = ys + dy
        assert target_x.min() >= column * cell_width + 8
        assert target_x.max() < (column + 1) * cell_width - 8
        assert target_y.min() >= row * cell_height + 8
        assert target_y.max() < (row + 1) * cell_height - 8
        assert not result[target_y, target_x, 3].any(), 'Never merge two bodies'
        result[target_y, target_x] = rgba[ys, xs]
        assert np.array_equal(result[target_y, target_x], rgba[ys, xs])
        proof.append(dict(phase=slot, translation=[int(dx), int(dy)], pixels=int(mask.sum()),
                          foreground_pixels=int((mask & foreground).sum()),
                          rgba_sha256=hashlib.sha256(rgba[ys, xs].tobytes()).hexdigest()))
    assert slots == set(range(6))
    assert sum(p['foreground_pixels'] for p in proof) == int(foreground.sum())
    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(result).save(output)
    geometry = importer.analyze(output, rows_count=6, reference_rows=[0, 3],
                                directions_axis='phase_grid2', canvas_size=1024,
                                directions=[direction])
    importer.require_complete_pose_regions(output, geometry)
    assert geometry['distinct_pixel_frames'] == 6
    audit = dict(source_sha256=digest(source), output_sha256=digest(output),
                 source=str(source), output=str(output), preserved_foreground_rgba=True,
                 resampled=False, recolored=False, newly_authored_poses=0,
                 foreground_alpha_threshold=16, retained_fringe_distance=2,
                 removed_background_pixels=int(removed.sum()),
                 maximum_removed_alpha=int(rgba[:, :, 3][removed].max()) if removed.any() else 0,
                 foreground_pixels=int(foreground.sum()), poses=sorted(proof, key=lambda p: p['phase']),
                 strict_importer='PASS', visual_approval='NOT_RUN')
    output.with_suffix('.repack.json').write_text(json.dumps(audit, indent=2) + '\n')
    return audit


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--direction', required=True, choices=importer.DIRECTIONS)
    args = parser.parse_args()
    audit = repack(args.source, args.output, args.direction)
    print(json.dumps({k: audit[k] for k in ('foreground_pixels', 'maximum_removed_alpha', 'strict_importer')}))
