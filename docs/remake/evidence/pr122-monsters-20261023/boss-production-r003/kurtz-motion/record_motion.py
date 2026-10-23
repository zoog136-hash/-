#!/usr/bin/env python3
"""Preserve each authored motion pose and check its entire source body."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core


def main():
    p = argparse.ArgumentParser()
    p.add_argument('direction', choices=['SW', 'W', 'NW'])
    p.add_argument('role', choices=['idle', 'run', 'hit'])
    p.add_argument('phase', type=int)
    p.add_argument('generated_image', type=Path)
    a = p.parse_args()
    assert 0 <= a.phase < (6 if a.role == 'run' else 2)
    folder = HERE / a.direction / a.role
    raw = folder / 'raw'
    raw.mkdir(parents=True, exist_ok=True)
    data = a.generated_image.read_bytes()
    version = 1
    while (raw / f'phase{a.phase}-v{version:02}.png').exists():
        version += 1
    path = raw / f'phase{a.phase}-v{version:02}.png'
    path.write_bytes(data)
    record = dict(direction=a.direction, role=a.role, phase=a.phase, version=version,
                  source=path.relative_to(ROOT).as_posix(), source_imagegen=str(a.generated_image),
                  bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), visual_review='PENDING_ACCUMULATED_BATCH_REVIEW')
    try:
        geometry = core.analyze(path, 1, [0], directions_axis='columns', canvas_size=2048, directions=[a.direction])
        core.require_complete_pose_regions(path, geometry)
        canvas = max(64, round(geometry['neutral_height'] * 256 / 96 / 8) * 8)
        for frame in geometry['frames']:
            core._rebase_mixed_frame_canvas(frame, canvas)
        geometry.update(canvas_size=[canvas, canvas], foot=[canvas // 2, canvas * 5 // 8],
                        strict_source_analysis_canvas=2048,
                        canvas_registration='Only virtual margin changes; source RGBA unchanged; complete-body and final-bounds guards retained.')
        core.require_complete_pose_regions(path, geometry)
        record.update(status='STRICT_GEOMETRY_PASS', geometry=geometry)
    except ValueError as error:
        record.update(status='SOURCE_HOLD', reason=str(error))
    text = json.dumps(record, ensure_ascii=False, indent=2) + '\n'
    (folder / f'phase{a.phase}-v{version:02}-checks.json').write_text(text)
    if record['status'] == 'STRICT_GEOMETRY_PASS':
        (folder / f'phase{a.phase}-checks.json').write_text(text)
    print(json.dumps({k: v for k, v in record.items() if k not in ('geometry', 'source_imagegen')}, ensure_ascii=False))


if __name__ == '__main__':
    main()
