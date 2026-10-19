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


def repack(source, output, direction, *, pose_count=6, canvas_size=1024, cell_width=768):
    """Split a reviewed two-column source; partial sources never imply approval."""
    for name, value, choices in (('pose_count', pose_count, (2, 4, 6)),
                                 ('canvas_size', canvas_size, (1024, 2048)),
                                 ('cell_width', cell_width, (768, 1280))):
        if type(value) is not int or value not in choices:
            raise ValueError(f'{name} must be an integer in {choices}')
    if direction not in importer.DIRECTIONS:
        raise ValueError('Unknown reviewed direction')
    assert source.is_file() and not output.exists()
    assert not output.with_suffix('.repack.json').exists(), 'Never overwrite an existing proof'
    rgba = np.array(Image.open(source).convert('RGBA'))
    height, width = rgba.shape[:2]
    grid_rows = (pose_count + 1) // 2
    if pose_count == 6:
        assert width % 2 == 0 and height % 3 == 0
    visible = rgba[:, :, 3] > 100
    assert not (visible[0].any() or visible[-1].any() or visible[:, 0].any()
                or visible[:, -1].any()), 'Clipped source cannot be repaired by adding padding'
    foreground = rgba[:, :, 3] > 16
    # A faint antialiased bridge can join two otherwise separate bodies. Use
    # a second, still very low alpha seed only when every stronger pixel stays
    # within two pixels of its body and the faint fringe stays within five.
    # Keep ALL alpha > 16 pixels, including that fringe; never cut or recolor it.
    for seed_alpha in (16, 32):
        labels, _ = ndimage.label(rgba[:, :, 3] > seed_alpha, np.ones((3, 3)))
        sizes = np.bincount(labels.ravel())
        bodies = [int(i) for i in np.flatnonzero(sizes >= 200) if i]
        if len(bodies) != pose_count:
            continue
        large = np.isin(labels, bodies)
        distance, nearest = ndimage.distance_transform_edt(~large, return_indices=True)
        if (np.all(distance[rgba[:, :, 3] > seed_alpha] <= 2)
                and np.all(distance[foreground] <= (2 if seed_alpha == 16 else 5))):
            break
    else:
        count_label = 'six' if pose_count == 6 else str(pose_count)
        raise ValueError(f'Require {count_label} separate bodies with only bounded faint edge fringe')
    owners = labels[nearest[0], nearest[1]]
    kept = foreground | ((rgba[:, :, 3] > 0) & (distance <= 2))
    removed = (rgba[:, :, 3] > 0) & ~kept
    assert not removed.any() or int(rgba[:, :, 3][removed].max()) <= 16
    source_row_height = height / grid_rows
    source_cell_height = (height + grid_rows - 1) // grid_rows
    largest_height = max(int(np.ptp(np.where(kept & (owners == body))[0])) + 1 for body in bodies)
    cell_height = max(source_cell_height, ((largest_height + 16 + 63) // 64) * 64)
    result = np.zeros((cell_height * grid_rows, cell_width * 2, 4), dtype=np.uint8)
    slots, proof = set(), []
    for body in bodies:
        cy, cx = ndimage.center_of_mass(large, labels, body)
        column, row = int(cx // (width / 2)), int(cy // source_row_height)
        assert 0 <= column < 2 and 0 <= row < grid_rows
        slot = row * 2 + column
        assert slot not in slots, 'Multiple bodies in one temporal slot'
        slots.add(slot)
        mask = kept & (owners == body)
        ys, xs = np.where(mask)
        dx = column * cell_width + cell_width // 2 - ((2 * column + 1) * width // 4)
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
    assert slots == set(range(pose_count))
    assert sum(p['foreground_pixels'] for p in proof) == int(foreground.sum())
    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(result).save(output)
    geometry = importer.analyze(output, rows_count=pose_count,
                                reference_rows=[0, min(3, pose_count - 1)],
                                directions_axis='phase_grid2', canvas_size=canvas_size,
                                directions=[direction])
    importer.require_complete_pose_regions(output, geometry)
    assert geometry['distinct_pixel_frames'] == pose_count
    audit = dict(source_sha256=digest(source), output_sha256=digest(output),
                 source=str(source), output=str(output), preserved_foreground_rgba=True,
                 source_canvas=[width, height],
                 output_canvas=[cell_width * 2, cell_height * grid_rows],
                 resampled=False, recolored=False, newly_authored_poses=0,
                 foreground_alpha_threshold=16, retained_fringe_distance=2,
                 body_seed_alpha=seed_alpha,
                 maximum_foreground_distance=float(distance[foreground].max()),
                 removed_background_pixels=int(removed.sum()),
                 maximum_removed_alpha=int(rgba[:, :, 3][removed].max()) if removed.any() else 0,
                 foreground_pixels=int(foreground.sum()), poses=sorted(proof, key=lambda p: p['phase']),
                 strict_importer='PASS', visual_approval='NOT_RUN')
    if (pose_count, canvas_size, cell_width) != (6, 1024, 768):
        audit.update(pose_count=pose_count, importer_canvas_size=canvas_size,
                     temporal_rows=grid_rows, temporal_columns=2,
                     partial_source=pose_count != 6, approvals_added=0)
    output.with_suffix('.repack.json').write_text(json.dumps(audit, indent=2) + '\n')
    return audit


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--direction', required=True, choices=importer.DIRECTIONS)
    parser.add_argument('--pose-count', type=int, choices=(2, 4, 6), default=6)
    parser.add_argument('--canvas-size', type=int, choices=(1024, 2048), default=1024)
    parser.add_argument('--cell-width', type=int, choices=(768, 1280), default=768)
    args = parser.parse_args()
    audit = repack(args.source, args.output, args.direction, pose_count=args.pose_count,
                   canvas_size=args.canvas_size, cell_width=args.cell_width)
    print(json.dumps({k: audit[k] for k in ('foreground_pixels', 'maximum_removed_alpha', 'strict_importer')}))
