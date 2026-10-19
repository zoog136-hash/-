import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

parser = argparse.ArgumentParser()
for name in ['source', 'key', 'direction', 'role', 'version']:
    parser.add_argument('--' + name, required=True)
args = parser.parse_args()
root = Path('/workspace/twilight')
out = root / 'docs/remake/evidence/pr122-mythic-detailed/batch01'
names = {'transform:393': 'halpas', 'transform:267': 'girtas'}
name = names[args.key]
assert args.direction in ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']
assert args.role in ['walk', 'run', 'combat']
assert args.version.isalnum()
source = Path(args.source)
dest = out / f'{name}-{args.direction}-{args.role}-{args.version}.png'
assert source.is_file() and not dest.exists()
shutil.copy2(source, dest)
assert hashlib.sha256(source.read_bytes()).digest() == hashlib.sha256(dest.read_bytes()).digest()
sys.path.insert(0, str(root / 'tools'))
import import_original_based_motion as importer
geometry = {'status': 'HOLD'}
count = 6 if args.role in ['walk', 'run'] else 12
try:
    result = importer.analyze(dest, rows_count=count, reference_rows=[0, 3],
                              directions_axis='phase_grid2', canvas_size=1024,
                              directions=[args.direction])
    importer.require_complete_pose_regions(dest, result)
    geometry = {'status': 'GEOMETRY_PASS', 'frames': len(result['frames']),
                'distinct_pixel_frames': result['distinct_pixel_frames'], 'canvas': 1024}
    (dest.with_suffix('.geometry.json')).write_text(json.dumps(result, indent=2) + '\n')
except Exception as exc:
    geometry['reason'] = str(exc)
record = {'key': args.key, 'direction': args.direction, 'role': args.role,
          'version': args.version, 'source': str(dest.relative_to(root)),
          'original_generated_file': str(source), 'bytes': dest.stat().st_size,
          'sha256': hashlib.sha256(dest.read_bytes()).hexdigest(),
          'requested_poses': count, 'geometry': geometry,
          'production_connected': False, 'detailed_completed': False}
manifest_path = out / 'source-manifest.json'
manifest = json.loads(manifest_path.read_text())
manifest['raw_images'].append(record)
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'key': args.key, 'direction': args.direction,
                  'role': args.role, 'geometry': geometry}))
