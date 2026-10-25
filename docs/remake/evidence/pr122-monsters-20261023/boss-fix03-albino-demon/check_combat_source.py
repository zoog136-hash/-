#!/usr/bin/env python3
"""Preserve/check each immutable newly generated boss source, without approving it."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[5]
BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core


def record(name, direction, rows=7, axis='phase_grid2'):
    request_path = BASE / 'requests' / (name + '.json')
    request = json.loads(request_path.read_text())
    source = Path(request['image_path'])
    output = ROOT / request['preserved_path']
    if output.exists():
        assert output.read_bytes() == source.read_bytes(), 'Never overwrite an existing source'
    else:
        shutil.copyfile(source, output)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    if 'sha256' not in request:
        request['sha256'] = digest
        request_path.write_text(json.dumps(request, ensure_ascii=False, indent=2) + '\n')
    assert request['sha256'] == digest
    refs = [0, 1] if rows == 7 else [0]
    result = dict(name=name, path=output.relative_to(ROOT).as_posix(), sha256=digest,
                  directions=[direction], rows=rows, axis=axis, reference_rows=refs)
    try:
        geometry = core.analyze(output, rows, refs, directions_axis=axis, canvas_size=2048, directions=[direction])
        core.require_complete_pose_regions(output, geometry)
        result.update(status='GEOMETRY_PASS_ONLY', geometry=geometry)
    except ValueError as error:
        result.update(status='SOURCE_HOLD', reason=str(error))
    (BASE / 'checks' / (name + '.json')).write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k != 'geometry'}))


if __name__ == '__main__':
    record(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 7,
           sys.argv[4] if len(sys.argv) > 4 else 'phase_grid2')
