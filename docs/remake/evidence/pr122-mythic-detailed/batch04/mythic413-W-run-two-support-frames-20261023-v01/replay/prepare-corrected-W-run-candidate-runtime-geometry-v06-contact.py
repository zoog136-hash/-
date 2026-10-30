from pathlib import Path
import hashlib,json,re,sys,argparse

R = Path('/workspace/twilight')
L = Path('/workspace/scratch/pr122-death-s-only-20261022-v01')
parser = argparse.ArgumentParser()
parser.add_argument('--version',choices=['06'],default='06')
version = parser.parse_args().version
O = L/f'W-run-own-native-six-exact-packed-candidate-v{version}'
rq = O/f'request-WrunOwnNative{version}.json'
raw = O/f'thunder_female-W-run-own-native-real-six-v{version}.png'
q = json.loads(rq.read_text())
sha = hashlib.sha256(raw.read_bytes()).hexdigest()
sys.path.insert(0,str(R/'tools'))
import import_original_based_motion as importer
from pr122_reviewed_source_regions import apply_reviewed_regions
from pr122_reviewed_runtime_layout import apply_reviewed_layout,declared_canonical_preflight_kwargs
kwargs = declared_canonical_preflight_kwargs(q['source_canvas_review'],q['reviewed_runtime_layout'],sha,'W',2048)
base = importer.analyze(raw,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid2',
                        canvas_size=2048,directions=['W'],**kwargs)
expanded,_ = apply_reviewed_regions(raw,base,q['source_region_review'])
geometry,_ = apply_reviewed_layout(raw,expanded,q['reviewed_runtime_layout'],source_region_review=q['source_region_review'])
assert len(geometry['frames'])==6 and all(f['canvas_size']==[2560,2560] for f in geometry['frames'])
register = json.loads((R/'data/pr122_native_locomotion_staging.json').read_text())
actor = register['actors']['transform:413']
frames_text = (R/actor['frames'].removeprefix('res://')).read_text()
match = re.search(r'"loop": (true|false),\s*"name": &"run_4",\s*"speed": ([0-9.]+)',frames_text)
assert match and match.group(1)=='true'
fps = float(match.group(2))
result = dict(status='SIX_NEW_OWN_NATIVE_W_RUN_POSES_EXACT_MAIN_PLAYER_FIXTURE_SOURCE_QUALITY_HOLD',
              actor='transform:413',direction='W',role='run',source_texture_path=str(raw),
              source_texture_sha256=sha,source_request_sha256=hashlib.sha256(rq.read_bytes()).hexdigest(),
              frames=geometry['frames'],fixed_C=2560,resource_role_seconds=6/fps,
              common_unpadded_root=q['authored_common_root_float'],source_visual_status='HOLD_NOT_REVIEWED',
              actor_approvals_added=0,production_connected=False)
with (L/f'new-W-run-own-native-six-candidate-runtime-geometry-v{version}.json').open('x') as f:
    json.dump(result,f,indent=2)
print(json.dumps(dict(poses=6,fixed_C=2560,resource_fps=fps,source_visual_status='HOLD',production_connected=False)))
