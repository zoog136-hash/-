import argparse
import hashlib
import json
from pathlib import Path
import shutil
import sys

sys.path.insert(0, '/workspace/twilight/tools')
import import_original_based_motion as core

parser = argparse.ArgumentParser()
parser.add_argument('--image', type=Path, required=True)
parser.add_argument('--actor', default='golem')
parser.add_argument('--direction', required=True)
parser.add_argument('--role', default='walk')
parser.add_argument('--frames', type=int, default=8)
parser.add_argument('--canvas', type=int, default=768)
parser.add_argument('--request', type=Path, required=True)
args = parser.parse_args()
root = Path('/workspace/runtime/batch16')
output = root / (args.actor + '-' + args.role + '-' + args.direction + '-v01.png')
if output.exists():
    assert core.sha(output) == core.sha(args.image)
else:
    shutil.copyfile(args.image, output)
row = {'output': str(output), 'original_generation_path': str(args.image),
       'sha256': core.sha(output), 'bytes': output.stat().st_size,
       'request': json.loads(args.request.read_text()), 'actor': args.actor, 'direction': args.direction,
       'role': args.role, 'frames': args.frames, 'source_claim': 'newly_authored_not_SPX_original',
       'production_applied': False, 'visual_approval': 'PENDING'}
try:
    geometry = core.analyze(output, rows_count=args.frames, directions=[args.direction],
        directions_axis='phase_grid4', canvas_size=args.canvas,
        reference_rows=[0, args.frames // 2])
    core.require_complete_pose_regions(output, geometry)
    row.update(geometry_status='PASS', geometry=geometry)
except (ValueError, AssertionError) as error:
    row.update(geometry_status='HOLD', reason=str(error))
path = root / 'new-source-index.json'
index = json.loads(path.read_text()) if path.exists() else {}
index[args.actor + ':' + args.role + ':' + args.direction] = row
path.write_text(json.dumps(index, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k:v for k,v in row.items() if k not in ['request','geometry']}))
