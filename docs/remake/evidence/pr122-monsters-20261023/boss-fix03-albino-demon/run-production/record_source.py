#!/usr/bin/env python3
"""Losslessly preserve generated boss RUN sources and strictly inspect geometry."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[5]
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core


def write_immutable(path, data):
    if path.exists():
        assert path.read_bytes() == data, str(path)
    else:
        path.write_bytes(data)


def record(name, image_path, axis='phase_grid2'):
    request_path = BASE / 'requests' / (name + '-request.json')
    request = json.loads(request_path.read_text())
    source = Path(image_path)
    raw = BASE / 'raw' / (name + '.png')
    write_immutable(raw, source.read_bytes())
    request.update(image_path=str(source), preserved_path=raw.relative_to(ROOT).as_posix(), sha256=core.sha(raw))
    write_immutable(BASE / 'requests' / (name + '.json'), (json.dumps(request, ensure_ascii=False, indent=2) + '\n').encode())
    direction = request.get('direction', name.split('-')[2])
    result = dict(name=name, path=raw.relative_to(ROOT).as_posix(), sha256=core.sha(raw), directions=[direction], rows=6, axis=axis, reference_rows=[0, 3])
    try:
        geometry = core.analyze(raw, 6, [0, 3], directions_axis=axis, canvas_size=1024, directions=[direction])
        core.require_complete_pose_regions(raw, geometry)
        result.update(status='GEOMETRY_PASS_ONLY', geometry=geometry)
    except Exception as error:
        result.update(status='SOURCE_HOLD', reason=str(error))
    (BASE / 'checks' / (name + '.json')).write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'geometry'}, ensure_ascii=False))


if __name__ == '__main__':
    record(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'phase_grid2')
