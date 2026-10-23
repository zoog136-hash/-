#!/usr/bin/env python3
"""Synthetic invariant checks only: no production PNG is read or modified."""
import importlib.util
from pathlib import Path

import numpy as np

path = Path(__file__).with_name('prepare_legendary_isolation_v01.py')
spec = importlib.util.spec_from_file_location('isolation', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def fixture(grid):
    columns, rows = grid
    rgba = np.zeros((rows * 100, columns * 80, 4), dtype=np.uint8)
    frames = []
    for i in range(columns * rows):
        row, column = divmod(i, columns)
        x, y = column * 80, row * 100
        left, right = (50, 100) if column < columns - 1 else (35, 65)
        rgba[y+30:y+50, x+left:x+right] = [30+i*20, 100, 200, 255]
        rgba[y+29, x+left] = [30+i*20, 100, 200, 8]
        frames.append({'phase': i, 'region': [x, y, 80, 100]})
    return rgba, frames


def main():
    for grid in [[3, 2], [2, 2], [3, 1]]:
        rgba, frames = fixture(grid)
        before = rgba.copy()
        result, proof = module.isolate_rgba(rgba, frames, grid)
        assert np.array_equal(rgba, before)
        assert proof['resampled'] is False
        assert (result[:, :, 3] > 16).sum() == (rgba[:, :, 3] > 16).sum()
        assert (result[:, :, 3] > 0).sum() == (rgba[:, :, 3] > 0).sum()
        module.verify_translation_proof(before, result, proof)
    rgba, frames = fixture([2, 2])
    rgba[35, 107] = [70, 80, 90, 255]
    try:
        module.isolate_rgba(rgba, frames, [2, 2])
    except module.Hold as exc:
        assert str(exc) == 'DETACHED_FOREGROUND_OWNER_AMBIGUOUS'
    else:
        raise AssertionError('Ambiguous detached pixel must HOLD')
    rgba, frames = fixture([2, 2])
    rgba[35, 100:115] = [70, 80, 90, 32]
    try:
        module.isolate_rgba(rgba, frames, [2, 2])
    except module.Hold as exc:
        assert str(exc) == 'ALPHA_BRIDGE_BETWEEN_TEMPORAL_POSES'
    else:
        raise AssertionError('A bridge between temporal poses must HOLD')
    rgba, frames = fixture([3, 1])
    rgba[0, 60] = [70, 80, 90, 255]
    try:
        module.isolate_rgba(rgba, frames, [3, 1])
    except module.Hold as exc:
        assert str(exc).startswith('SOURCE_EDGE_REQUIRES_REVIEW')
    else:
        raise AssertionError('Padding must not claim to restore a clipped source')
    print('SYNTHETIC_ONLY_PASS: 3x2/2x2/3x1, exact RGBA+coverage, ambiguity/bridge/clipping HOLD')


if __name__ == '__main__':
    main()
