"""Losslessly preserve every generated source; unchanged strict geometry only."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[5]
BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core


def immutable(path, blob):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        assert path.read_bytes() == blob, 'Never overwrite original: ' + str(path)
    else:
        path.write_bytes(blob)


def record(name, image_path):
    req = json.loads((BASE / 'requests' / (name + '.json')).read_text())
    source = Path(image_path)
    dest = BASE / 'raw' / (name + '.png')
    immutable(dest, source.read_bytes())
    result = dict(name=name, direction=req['direction'], path=dest.relative_to(ROOT).as_posix(),
                  generated_path=str(source), sha256=core.sha(dest), rows=req['rows'],
                  axis=req['axis'], canvas_size=req['canvas_size'], reference_rows=req['reference_rows'],
                  new_approvals=0, production_connected=False)
    try:
        geometry = core.analyze(dest, req['rows'], req['reference_rows'],
                                directions_axis=req['axis'], canvas_size=req['canvas_size'],
                                directions=[req['direction']])
        core.require_complete_pose_regions(dest, geometry)
        result.update(status='GEOMETRY_PASS_ONLY', geometry=geometry)
    except Exception as exc:
        result.update(status='SOURCE_HOLD', reason=str(exc))
    immutable(BASE / 'checks' / (name + '.json'), (json.dumps(result, ensure_ascii=False, indent=2) + '\n').encode())
    print(json.dumps({k:v for k,v in result.items() if k != 'geometry'}, ensure_ascii=False))


if __name__ == '__main__':
    record(sys.argv[1], sys.argv[2])
