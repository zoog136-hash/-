#!/usr/bin/env python3
"""Preserve one actually generated attack pose and its complete RGBA region."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('direction', choices=core.DIRECTIONS)
    parser.add_argument('phase', type=int, choices=range(4))
    parser.add_argument('generated_image', type=Path)
    args = parser.parse_args()
    folder = HERE / ('single' if args.direction == 'E' else 'single-' + args.direction)
    raw = folder / 'raw' / f'{args.direction}-attack-phase{args.phase}.png'
    raw.parent.mkdir(parents=True, exist_ok=True)
    if raw.exists():
        assert raw.read_bytes() == args.generated_image.read_bytes(), 'Choose a new revision; do not overwrite art.'
    else:
        shutil.copyfile(args.generated_image, raw)
    data = raw.read_bytes()
    row = dict(direction=args.direction, phase=args.phase, source=raw.relative_to(ROOT).as_posix(),
               sha256=hashlib.sha256(data).hexdigest(), bytes=len(data),
               imagegen_output=str(args.generated_image), visual_review='PENDING_BATCH_REVIEW')
    try:
        geometry = core.analyze(raw, 1, [0], directions_axis='columns', canvas_size=2048, directions=[args.direction])
        core.require_complete_pose_regions(raw, geometry)
        canvas = max(64, round(geometry['neutral_height'] * 256 / 96 / 8) * 8)
        if canvas <= 2048:
            geometry = core.analyze(raw, 1, [0], directions_axis='columns', canvas_size=canvas, directions=[args.direction])
        else:
            # The strict source analyzer above remains bounded at 2048. A
            # virtual AtlasTexture margin is not a larger PNG/GPU texture.
            # Explicit source-density registration preserves every source
            # pixel while avoiding a change to the actor's world scale.
            for frame in geometry['frames']:
                core._rebase_mixed_frame_canvas(frame, canvas)
            geometry.update(canvas_size=[canvas, canvas], foot=[canvas // 2, canvas * 5 // 8],
                            strict_source_analysis_canvas=2048,
                            canvas_registration='Virtual margin only; PNG unchanged; all source-body and final bounds guards retained.')
        core.require_complete_pose_regions(raw, geometry)
        row.update(status='STRICT_GEOMETRY_PASS', geometry=geometry)
    except ValueError as error:
        row.update(status='SOURCE_HOLD', reason=str(error))
    path = folder / f'phase{args.phase}-checks.json'
    path.write_text(json.dumps(row, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in row.items() if k != 'geometry'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
