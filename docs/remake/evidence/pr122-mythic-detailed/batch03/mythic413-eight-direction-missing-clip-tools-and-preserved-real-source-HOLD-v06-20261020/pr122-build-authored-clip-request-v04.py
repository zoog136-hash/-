"""Prepare an unapproved, exact-pixel clip request from a completed packing proof.

Uses unchanged repository geometry/layout validators. No Git, game, image tools,
approval changes, resampling, or source writes. An independent final review is
still required before the separate root-only integration command.
"""
from pathlib import Path
import argparse, hashlib, json, math, re, sys
import numpy as np
from PIL import Image

sys.dont_write_bytecode = True
ROOT = Path('/workspace/twilight')
sys.path.insert(0, str(ROOT/'tools'))
import advance_pr122_native_locomotion as advance
import pr122_reviewed_source_regions as regions
from pr122_reviewed_runtime_layout import apply_reviewed_layout

def require(ok, message):
    if not ok:
        raise ValueError(message)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def load(data):
    def pairs(items):
        out = {}
        for k, v in items:
            require(k not in out, 'Duplicate JSON key')
            out[k] = v
        return out
    def finite(v):
        if isinstance(v, float):
            require(math.isfinite(v), 'Nonfinite JSON')
        elif isinstance(v, dict):
            for x in v.values(): finite(x)
        elif isinstance(v, list):
            for x in v: finite(x)
        return v
    return finite(json.loads(data, object_pairs_hook=pairs,
        parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x))))

def read(path):
    require(path.is_absolute() and '..' not in path.parts and
        not any(p.is_symlink() for p in (path, *path.parents)), 'Unsafe path')
    require(path.is_file() and path.stat().st_size <= 10*1024*1024, 'Missing/oversized input')
    return path.read_bytes()

def encode(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False)+'\n').encode()

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--packing', required=True, type=Path)
    p.add_argument('--expected-packing-sha256', required=True)
    p.add_argument('--version', required=True)
    p.add_argument('--output', required=True, type=Path)
    a = p.parse_args()
    require(re.fullmatch(r'[A-Za-z0-9_-]{1,48}', a.version), 'Unsafe explicit version')
    require(a.output.is_absolute() and a.output.parent.is_dir() and
        not any(x.is_symlink() for x in (a.output,*a.output.parents)), 'Unsafe output')
    require(not a.output.exists(), 'Preserve existing request')
    packing_bytes = read(a.packing)
    require(sha(packing_bytes) == a.expected_packing_sha256, 'Packing proof changed')
    proof = load(packing_bytes)
    require(proof['status'] == 'PACKED_EXACT_RGBA_NOT_ANIMATION_APPROVAL' and
        proof['key'] == 'transform:413' and proof['logical_canvas'] == 1024 and
        proof['source_resampled'] is False, 'Unexpected packing basis')
    direction, role = proof['direction'], proof['role']
    require(direction in ('S','SW','W','NW','N','NE','E','SE') and role in ('walk','run','idle','attack','hit','death'), 'Unsupported missing clip')
    atlas = Path(proof['output']); raw = read(atlas)
    require(sha(raw) == proof['output_sha256'], 'Atlas bytes changed')
    plan_bytes = read(Path(proof['plan_path']))
    require(sha(plan_bytes) == proof['plan_sha256'], 'Packing plan changed')
    plan = load(plan_bytes)
    require(plan['tile_size'] == [1536,1536] and plan['key'] == proof['key'] and
        plan['direction'] == direction and plan['role'] == role, 'Expected six full tiles')
    root = plan['rig_root_in_unpadded_frame']
    require(len(root) == 2 and all(type(v) in (int,float) for v in root), 'Fixed finite root required')
    root_integer = [math.floor(v+.5) for v in root]
    frames = proof['authored_poses']
    require(len(frames) == 6 and [f['phase'] for f in frames] == list(range(6)), 'Chronological six poses')
    canvas = proof['fixed_physical_canvas']
    require(type(canvas) is int and 256 <= canvas <= 4096 and canvas%8 == 0, 'Fixed physical canvas')
    rects, anchors, hashes = [], [], set()
    with Image.open(atlas) as image:
        require(image.mode == 'RGBA' and list(image.size) == [3072,4608], 'Exact full tile atlas')
        alpha = np.array(image.getchannel('A'))
        for i, f in enumerate(frames):
            require(f['physical_canvas'] == canvas, 'Per-pose body rescaling prohibited')
            native = Path(f['source']); native_bytes = read(native)
            require(sha(native_bytes) == f['source_sha256'], 'Actual source changed')
            with Image.open(native) as pose:
                origin = [1536*(i%2),1536*(i//2)]
                require(f['atlas_origin'] == origin and pose.mode == 'RGBA', 'Chronological full tiles')
                require(sha(pose.tobytes()) == f['source_rgba_sha256'], 'Actual pose pixels changed')
                require(image.crop((*origin,origin[0]+pose.width,origin[1]+pose.height)).tobytes() == pose.tobytes(), 'Atlas changed pose pixels')
            translation = f['storage_translation']
            require(len(translation)==2 and all(type(v) is int for v in translation), 'Integer storage only')
            expected_float = [root[j]+translation[j]+origin[j] for j in (0,1)]
            require(f['atlas_root_anchor']==expected_float, 'Per-pose root fitting prohibited')
            anchors.append([root_integer[j]+translation[j]+origin[j] for j in (0,1)])
            rects.append([*origin,1536,1536]);hashes.add(f['source_rgba_sha256'])
        require(len(hashes)==6, 'Six distinct actual poses')
    base = advance.staging.importer.analyze(atlas, rows_count=6, reference_rows=[0,3],
        directions_axis='phase_grid2', canvas_size=2048, directions=[direction])
    # Keep every alpha-positive source pixel and the fixed rig root.  Expanding
    # to the whole storage tile would falsely require blank padding to fit the
    # canonical reference canvas before the actual authored canvas is applied.
    rects = []
    for i, frame in enumerate(base['frames']):
        ox, oy = 1536*(i%2), 1536*(i//2)
        ys, xs = np.where(alpha[oy:oy+1536, ox:ox+1536] > 0)
        x, y, w, h = frame['region']
        ax, ay = anchors[i]
        left = min(x, ox+int(xs.min()), ax)
        top = min(y, oy+int(ys.min()), ay)
        right = max(x+w, ox+int(xs.max())+1, ax+1)
        bottom = max(y+h, oy+int(ys.max())+1, ay+1)
        require(ox <= left < right <= ox+1536 and oy <= top < bottom <= oy+1536,
            'Actual foreground/root must stay in its own disjoint storage tile')
        rects.append([left, top, right-left, bottom-top])
    _, owner = regions._foreground_owners(alpha, base['frames'])
    source_regions = dict(status='REVIEWED_SOURCE_REGIONS_PROPOSAL',
        source_sha256=sha(raw), base_geometry_sha256=regions._digest(base),
        direction=direction, regions=rects, nearest_owner_sha256=owner['nearest_owner_sha256'],
        review_basis='Minimal disjoint expansions retain every alpha-positive RGBA pixel, canonical source rectangle and fixed rig root; immutable packing proof '+sha(packing_bytes))
    expanded, region_proof = regions.apply_reviewed_regions(atlas, base, source_regions)
    require(region_proof['all_alpha_positive_covered'] is True, 'Never drop even low-alpha source pixels')
    advance.staging.importer.require_complete_pose_regions(atlas, expanded)
    layout = dict(status='REVIEWED_LAYOUT_PROPOSAL', source_sha256=sha(raw),
        direction=direction, role=role, canvas_size=2048, source_anchors=anchors,
        authored_pose_canvas_sizes=[canvas]*6,
        review_basis='One fixed authored body unit/root; one common integer root rounding, storage-only translations; no per-pose foot fitting or resizing.')
    derived, layout_proof = apply_reviewed_layout(atlas, expanded, layout, source_region_review=source_regions)
    require(len(derived['frames'])==6 and derived['distinct_pixel_frames']==6, 'Existing compiler validation failed')
    canonical = ROOT/'assets/catalog/e82707989c7744b45919684b.png'
    canonical_sha = '7f0d692317b0010aa2c890e71d306e600d52d5a84a66668e557d322873782e94'
    require(sha(read(canonical)) == canonical_sha, 'Canonical identity changed')
    request = dict(status='REQUESTED_NOT_APPROVED', key='transform:413',
        direction=direction, role=role, version=a.version, source_batch='batch04',
        references=[str(canonical)], reference_sha256={str(canonical):canonical_sha},
        source_canvas_review=dict(status='REVIEWED_SOURCE_CANVAS_PROPOSAL',source_sha256=sha(raw),
            canvas_size=2048, review_basis='Unchanged nominal compiler basis with explicitly retained per-pose physical body unit.'),
        source_region_review=source_regions, reviewed_runtime_layout=layout,
        authored_packing_proof_sha256=sha(packing_bytes),
        authored_common_root_float=root, common_root_integer=root_integer,
        common_root_rounding_delta=[root_integer[j]-root[j] for j in (0,1)],
        source_visual_status='PENDING_INDEPENDENT_FINAL_CYCLE_REVIEW',
        actor_approvals_added=0)
    # Recheck the exact primary input bytes before creating the exclusive request.
    require(read(a.packing)==packing_bytes and read(atlas)==raw and
        read(Path(proof['plan_path']))==plan_bytes, 'Inputs changed during preparation')
    data = encode(request)
    with a.output.open('xb') as stream: stream.write(data)
    print(json.dumps(dict(status='REQUEST_PREPARED_NOT_APPROVED',request=str(a.output),
        request_sha256=sha(data),raw_sha256=sha(raw),physical_canvas=canvas,
        root_rounding=request['common_root_rounding_delta'],independent_final_review_required=True)))

if __name__ == '__main__': main()
