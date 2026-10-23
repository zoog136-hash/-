#!/usr/bin/env python3
"""One resumable, read-only review of the frozen legendary draft baseline.

Only a findings JSON and append-only review journal are written. No PNG, request,
record, SpriteFrames, game file, approval, Git index or branch is changed.
"""
import collections
import functools
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import traceback

import numpy as np
from PIL import Image
from scipy import ndimage

REPO = Path('/workspace/legendary_repo')
WORK = Path('/workspace/legendary_work')
PREFIX = Path('docs/remake/pr122-legendary-parallel')
ASSETS = Path('assets/actors/eight_direction/legendary_parallel')
BASELINE = '6bcd94f5a0868426ac4b5ae0ebffd93916fad1ba'
RUNTIME = Path('/workspace/legendary_runtime/static-review-once-v01')
OUTPUT = WORK / PREFIX / 'technical-single-review-v01.json'
DIRS = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']
JOURNAL = RUNTIME / 'units.jsonl'


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def canonical(value):
    return digest(json.dumps(value, ensure_ascii=False, sort_keys=True,
                             separators=(',', ':')).encode())


def resource_path(value):
    path = REPO / str(value).removeprefix('res://')
    assert path.resolve().is_relative_to(REPO) and not path.is_symlink()
    return path


def git(*args):
    return subprocess.check_output(['git', *args], cwd=REPO, text=True).strip()


@functools.lru_cache(maxsize=8)
def image_data(path_string):
    path = Path(path_string)
    raw = path.read_bytes()
    with Image.open(path) as im:
        assert im.format == 'PNG' and im.mode == 'RGBA'
        rgba = np.asarray(im).copy()
    alpha = rgba[:, :, 3]
    labels, _ = ndimage.label(alpha > 100)
    sizes = np.bincount(labels.ravel())
    return rgba, alpha, labels, sizes, digest(raw)


def rect(text, label):
    match = re.search(label + r' = Rect2\(([^)]+)\)', text)
    assert match, 'Missing AtlasTexture ' + label
    values = [float(x.strip()) for x in match.group(1).split(',')]
    assert len(values) == 4 and all(math.isfinite(x) and x.is_integer() for x in values)
    return [int(x) for x in values]


def parse_frames(path):
    raw = path.read_bytes()
    text = raw.decode()
    external = {identifier: uri for uri, identifier in re.findall(
        r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text)}
    poses = {}
    for identifier, block in re.findall(
            r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]([\s\S]*?)(?=\n\[|\Z)', text):
        ext = re.search(r'atlas = ExtResource\("([^"]+)"\)', block)
        assert ext and ext.group(1) in external
        poses[identifier] = {'source': external[ext.group(1)],
                             'region': rect(block, 'region'),
                             'margin': rect(block, 'margin'),
                             'filter_clip': 'filter_clip = true' in block}
    animation_text = text.split('animations = [', 1)[1].split('\n]\n', 1)[0]
    names = re.findall(r'"name": &"([^"]+)"', animation_text)
    loops = re.findall(r'"loop": (true|false)', animation_text)
    speeds = re.findall(r'"speed": ([-+0-9.eE]+)', animation_text)
    ordered = re.findall(r'"duration": ([-+0-9.eE]+), "texture": SubResource\("([^"]+)"\)', animation_text)
    assert len(names) == len(loops) == len(speeds) == 1, 'One named animation is required'
    frames = [dict(poses[name], duration=float(duration), pose_id=name)
              for duration, name in ordered]
    return {'sha256': digest(raw), 'animation': names[0], 'loop': loops[0] == 'true',
            'speed': float(speeds[0]), 'frames': frames,
            'metadata_canvas': re.findall(r'metadata/twilight_canvas_size = Vector2\(([^)]+)\)', text)}


def issue(code, severity, **evidence):
    return {'code': code, 'severity': severity, **evidence}


def visible_hash(crop):
    ys, xs = np.nonzero(crop[:, :, 3] > 0)
    if not len(xs):
        return None
    visible = crop[ys.min():ys.max()+1, xs.min():xs.max()+1].copy()
    visible[visible[:, :, 3] == 0] = 0
    return digest(visible.tobytes())


def append_unit(key, result):
    with JOURNAL.open('a') as handle:
        handle.write(json.dumps({'unit': key, 'result': result}, ensure_ascii=False,
                                separators=(',', ':')) + '\n')
        handle.flush()


def scan_clip(slot, record_path, record, parsed, actor, request_index):
    findings = []
    if parsed['animation'] != f"{record['role']}_{DIRS.index(record['direction'])}":
        findings.append(issue('WRONG_ANIMATION_ID', 'ERROR', actual=parsed['animation']))
    if parsed['loop'] != (record['role'] in ('idle', 'run')):
        findings.append(issue('WRONG_LOOP_OR_ONCE_FLAG', 'ERROR', actual=parsed['loop']))
    if len(parsed['frames']) != 6 or record.get('poses') != 6:
        findings.append(issue('SIX_FRAME_REQUIREMENT', 'ERROR', frames=len(parsed['frames']), poses=record.get('poses')))
    if parsed['sha256'] != record.get('output_spriteframes_sha256'):
        findings.append(issue('SPRITEFRAMES_SHA_MISMATCH', 'ERROR'))
    if record.get('name') != actor['name'] or record.get('grade') != '전설':
        findings.append(issue('CATALOG_IDENTITY_MISMATCH', 'ERROR'))
    reference = resource_path(record['reference'])
    if digest(reference.read_bytes()) != record.get('reference_sha256'):
        findings.append(issue('REFERENCE_SHA_MISMATCH', 'ERROR'))
    request_sha = record.get('request_file_sha256')
    if request_sha not in request_index:
        findings.append(issue('REQUEST_SHA_NOT_PRESERVED', 'ERROR', expected=request_sha))
    if canonical(record.get('generation_request')) != record.get('generation_request_sha256'):
        findings.append(issue('GENERATION_REQUEST_SHA_MISMATCH', 'ERROR'))
    declared = {str(resource_path(record['source'])): record['source_sha256']}
    for source in record.get('source_files', []):
        declared[str(resource_path(source['path']))] = source['sha256']
    rgba_hashes, normalized_hashes, extents, feet, heights = [], [], [], [], []
    checks = {x['index']: x for x in record.get('automatic_checks', [])}
    for index, frame in enumerate(parsed['frames']):
        path = resource_path(frame['source'])
        rgba, alpha, _, _, source_sha = image_data(str(path))
        if str(path) not in declared or declared.get(str(path)) != source_sha:
            findings.append(issue('SOURCE_SHA_OR_DECLARATION_MISMATCH', 'ERROR', phase=index, source=str(path.relative_to(REPO))))
        x, y, w, h = frame['region']
        mx, my, mw, mh = frame['margin']
        if min(x, y, mx, my, mw, mh) < 0 or min(w, h) <= 0 or x+w > rgba.shape[1] or y+h > rgba.shape[0]:
            findings.append(issue('INVALID_ATLAS_REGION_MARGIN', 'ERROR', phase=index, region=frame['region'], margin=frame['margin']))
            continue
        crop = rgba[y:y+h, x:x+w]
        value = digest(crop.tobytes())
        rgba_hashes.append(value)
        normalized_hashes.append(visible_hash(crop))
        if checks.get(index, {}).get('region') != frame['region'] or checks.get(index, {}).get('rgba_sha256') != value:
            findings.append(issue('FRAME_RGBA_OR_REGION_PIN_MISMATCH', 'ERROR', phase=index))
        if not frame['filter_clip']:
            findings.append(issue('ATLAS_FILTER_CLIP_DISABLED', 'ERROR', phase=index))
        strong = crop[:, :, 3] > 100
        ys, xs = np.where(strong)
        extents.append([w+mw, h+mh])
        if len(xs):
            border = int(strong[0].sum()+strong[-1].sum()+strong[:, 0].sum()+strong[:, -1].sum())
            if border:
                findings.append(issue('VISIBLE_FOREGROUND_TOUCHES_FRAME_EDGE', 'HOLD', phase=index, strong_border_pixels=border, source=str(path.relative_to(REPO)), region=frame['region']))
            feet.append([float((xs.min()+xs.max())/2+mx), int(ys.max()+my), w+mw, h+mh])
            heights.append(int(ys.max()-ys.min()+1))
        else:
            findings.append(issue('EMPTY_STRONG_FOREGROUND', 'ERROR', phase=index))
    if len(rgba_hashes) == 6 and (len(set(rgba_hashes)) != 6 or len(set(normalized_hashes)) != 6):
        findings.append(issue('DUPLICATE_OR_TRANSLATED_STILL', 'ERROR'))
    for i, left in enumerate(parsed['frames']):
        for j in range(i+1, len(parsed['frames'])):
            right = parsed['frames'][j]
            if left['source'] != right['source']:
                continue
            ax, ay, aw, ah = left['region']; bx, by, bw, bh = right['region']
            x0, y0, x1, y1 = max(ax,bx), max(ay,by), min(ax+aw,bx+bw), min(ay+ah,by+bh)
            if x1 > x0 and y1 > y0:
                alpha = image_data(str(resource_path(left['source'])))[1]
                count = int((alpha[y0:y1, x0:x1] > 16).sum())
                if count:
                    findings.append(issue('DUPLICATED_SOURCE_FOREGROUND_ACROSS_FRAMES', 'ERROR', phases=[i,j], pixels_alpha_gt16=count))
    if extents and (max(x[0] for x in extents)-min(x[0] for x in extents) > 1 or max(x[1] for x in extents)-min(x[1] for x in extents) > 1):
        findings.append(issue('INCONSISTENT_TEXTURE_CANVAS_WITHIN_CLIP', 'HOLD', frame_extents=extents,
                              basis='Bare SpriteFrames texture extents differ; runtime normalization is not verified by this static review'))
    if len(feet) == 6:
        normalized_y = [y/h for _,y,_,h in feet]
        if max(normalized_y)-min(normalized_y) > .12:
            findings.append(issue('FOOT_REGISTRATION_DRIFT', 'HOLD', normalized_bottom_y=normalized_y,
                                  basis='Strong-foreground bounding bottoms, not a semantic anatomy/foot detector'))
    if len(heights) == 6 and min(heights) and max(heights)/min(heights) > 1.4 and record['role'] != 'death':
        findings.append(issue('VISIBLE_HEIGHT_VARIATION', 'HOLD', strong_heights=heights,
                              basis='May be legitimate articulation; visual confirmation required before a correction'))
    speed = parsed['speed']
    if not math.isfinite(speed) or speed <= 0 or any(not math.isfinite(f['duration']) or f['duration'] <= 0 for f in parsed['frames']):
        findings.append(issue('INVALID_ANIMATION_DURATION', 'ERROR'))
    new = record.get('newly_authored_poses', 6); reused = record.get('reused_poses', 0)
    if new+reused != 6:
        findings.append(issue('POSE_ACCOUNTING_MISMATCH', 'ERROR', new=new, reused=reused))
    return findings


def scan_source(path, frames, record):
    rgba, alpha, strong_labels, sizes, sha = image_data(str(path))
    findings = []
    n = len(frames)
    grid = record.get('source_grid', [3,2] if n == 6 else ([2,2] if n == 4 else [3,1]))
    body_labels = []
    for phase, frame in frames:
        x,y,w,h = frame['region']
        counts = np.bincount(strong_labels[y:y+h, x:x+w].ravel(), minlength=len(sizes))
        candidates = np.flatnonzero((sizes >= 200) & (counts > 0))
        candidates = candidates[candidates != 0]
        if not len(candidates):
            findings.append(issue('NO_PHYSICAL_BODY_SEED', 'HOLD', phase=phase, region=frame['region']))
            body_labels.append(0)
        else:
            body_labels.append(int(candidates[np.argmax(counts[candidates])]))
    if 0 in body_labels or len(set(body_labels)) != n:
        findings.append(issue('CONNECTED_OR_OPAQUE_POSE_LAYOUT', 'HOLD', expected_poses=n,
                              distinct_body_seeds=len(set(body_labels)-{0}), body_seed_labels=body_labels,
                              alpha_gt100_fraction=float((alpha>100).mean()), source_grid=grid,
                              basis='The largest alpha>100 connected body seed cannot identify each intended pose independently'))
        return {'sha256':sha, 'grid':grid, 'findings':findings}
    low_labels, count = ndimage.label(alpha > 16, np.ones((3,3)))
    owner = np.full(count+1, -1, dtype=np.int16)
    owner[0] = -2
    bridges = []
    for row, body in enumerate(body_labels):
        components = np.unique(low_labels[strong_labels == body]); components = components[components != 0]
        for component in components:
            if owner[component] >= 0 and owner[component] != row:
                bridges.append(int(component)); owner[component] = -3
            elif owner[component] == -1:
                owner[component] = row
    if bridges:
        bridge_pixels = int(np.isin(low_labels, bridges).sum())
        findings.append(issue('ALPHA_BRIDGE_BETWEEN_TEMPORAL_POSES', 'HOLD', components=sorted(set(bridges)),
                              pixels_alpha_gt16=bridge_pixels, source_grid=grid,
                              basis='One alpha>16 component contains more than one distinct alpha>100 physical-body seed'))
    detached = (low_labels > 0) & (owner[low_labels] == -1)
    ys,xs = np.where(detached)
    ambiguous = 0
    if len(xs):
        distances = np.empty((n,len(xs)),dtype=np.float64)
        for row,body in enumerate(body_labels):
            distances[row] = ndimage.distance_transform_edt(strong_labels != body)[ys,xs]
        nearest = np.argmin(distances,axis=0)
        ordered = np.sort(distances,axis=0)
        margin = ordered[1]-ordered[0] if n > 1 else np.full(len(xs), np.inf)
        detached_ids = low_labels[ys,xs]
        for component in np.unique(detached_ids):
            selected = detached_ids == component
            owners = np.unique(nearest[selected])
            if len(owners) != 1 or float(margin[selected].min()) <= 32.0:
                ambiguous += int(selected.sum())
            else:
                owner[int(component)] = int(owners[0])
    if ambiguous:
        findings.append(issue('DETACHED_FOREGROUND_OWNER_AMBIGUOUS', 'HOLD', pixels_alpha_gt16=ambiguous,
                              minimum_required_runner_up_margin=32.0, source_grid=grid,
                              basis='Apply the mythic ownership rule without guessing or dropping foreground'))
    assigned = owner[low_labels]
    covered = np.zeros(alpha.shape,dtype=bool)
    for row,(phase,frame) in enumerate(frames):
        x,y,w,h = frame['region']; covered[y:y+h,x:x+w] = True
        crop_owner = assigned[y:y+h,x:x+w]; crop_alpha = alpha[y:y+h,x:x+w]
        foreign = (crop_alpha > 16) & (crop_owner >= 0) & (crop_owner != row)
        fy,fx = np.where(foreign)
        if len(fx):
            labels,counts = np.unique(crop_owner[foreign],return_counts=True)
            findings.append(issue('FOREIGN_POSE_FOREGROUND_INSIDE_FRAME', 'ERROR', phase=phase,
                                  pixels_alpha_gt16=int(len(fx)), strong_pixels=int((crop_alpha[foreign]>100).sum()),
                                  bbox_in_frame=[int(fx.min()),int(fy.min()),int(fx.max()+1),int(fy.max()+1)],
                                  physical_owner_rows={str(int(a)):int(b) for a,b in zip(labels,counts)},
                                  source_grid=grid,
                                  basis='Pixels are topology-owned by another pose, or by one unambiguous >32px nearest owner'))
    omitted = int(((alpha>16)&~covered).sum())
    if omitted:
        findings.append(issue('UNASSIGNED_NEW_SOURCE_FOREGROUND', 'ERROR', pixels_alpha_gt16=omitted, source_grid=grid))
    border = int((alpha[0]>100).sum()+(alpha[-1]>100).sum()+(alpha[:,0]>100).sum()+(alpha[:,-1]>100).sum())
    if border:
        findings.append(issue('VISIBLE_FOREGROUND_TOUCHES_SOURCE_EDGE', 'HOLD', strong_border_pixels=border, source_grid=grid,
                              basis='Padding cannot recover missing source pixels; visual confirmation is required'))
    return {'sha256':sha, 'grid':grid, 'findings':findings}


def main():
    assert git('rev-parse','HEAD') == BASELINE and not git('status','--porcelain')
    assert not OUTPUT.exists(), 'Never repeat or overwrite the completed whole review'
    RUNTIME.mkdir(parents=True,exist_ok=True)
    sentinel = RUNTIME/'started.json'
    if not sentinel.exists():
        with sentinel.open('x') as handle:
            json.dump({'baseline_sha':BASELINE,'whole_review_number':1},handle)
    else:
        assert json.loads(sentinel.read_text())['baseline_sha'] == BASELINE
    units = {}
    if JOURNAL.exists():
        for line in JOURNAL.read_text().splitlines():
            value=json.loads(line); assert value['unit'] not in units; units[value['unit']]=value['result']
    catalog=json.loads((REPO/'data/catalog_v19.json').read_text())
    actors={'transform:'+str(x['sourceId']):x for x in catalog['변신'] if x['grade']=='전설'}
    assert len(actors)==40
    request_index={digest(p.read_bytes()):p.relative_to(REPO).as_posix() for p in (REPO/PREFIX/'requests').glob('*.json')}
    clips={}; source_defs={}; dependents=collections.defaultdict(list)
    preload_errors=[]
    for path in sorted((REPO/ASSETS).glob('*/draft001/*-record-v01.json')):
        record=json.loads(path.read_text()); slot=(record['key'],record['direction'],record['role'])
        assert slot not in clips
        try:
            parsed=parse_frames(resource_path(record['output_spriteframes']))
            clips[slot]=(path,record,parsed)
            own=str(resource_path(record['source']))
            own_frames=[(i,f) for i,f in enumerate(parsed['frames']) if str(resource_path(f['source']))==own]
            source_defs[own]=(own_frames,record)
            for i,frame in enumerate(parsed['frames']):
                dependents[str(resource_path(frame['source']))].append({'slot':list(slot),'phase':i,'region':frame['region']})
        except Exception as exc:
            preload_errors.append({'slot':list(slot),'record':path.relative_to(REPO).as_posix(),'findings':[issue('RESOURCE_PARSE_FAILED','ERROR',error=repr(exc))]})
    expected=[(key,direction,role) for key in actors for direction in DIRS for role in ['idle','run','attack','hit']]
    expected += [(key,'S','death') for key in actors]
    assert len(expected)==1320
    errors=list(preload_errors)
    for slot in expected:
        unit='slot:'+':'.join(slot)
        if unit not in units:
            if slot not in clips:
                result={'slot':list(slot),'findings':[issue('MISSING_REQUIRED_SLOT','BLOCKED',
                    known_generation_error='HTTP400 moderation_blocked/output sexual' if slot==('transform:274','NE','attack') else 'Inspect preserved generation evidence') ]}
            else:
                path,record,parsed=clips[slot]
                try:
                    result={'slot':list(slot),'record':path.relative_to(REPO).as_posix(),
                            'findings':scan_clip(slot,path,record,parsed,actors[slot[0]],request_index)}
                except Exception as exc:
                    result={'slot':list(slot),'record':path.relative_to(REPO).as_posix(),
                            'findings':[issue('STATIC_CLIP_REVIEW_EXCEPTION','ERROR',error=repr(exc))]}
            append_unit(unit,result); units[unit]=result
        if units[unit]['findings']: errors.append(units[unit])
    source_errors=[]
    for number,(path_string,(frames,record)) in enumerate(sorted(source_defs.items()),1):
        unit='source:'+path_string
        if unit not in units:
            try:
                result=scan_source(Path(path_string),frames,record)
            except Exception as exc:
                result={'findings':[issue('SOURCE_OWNERSHIP_REVIEW_EXCEPTION','ERROR',error=repr(exc))]}
            result['source']=Path(path_string).relative_to(REPO).as_posix()
            result['authored_slot']=[record['key'],record['direction'],record['role']]
            result['dependents']=dependents[path_string]
            append_unit(unit,result);units[unit]=result
        if units[unit]['findings']:source_errors.append(units[unit])
        if number%100==0:print('SOURCE_REVIEW_PROGRESS',number,len(source_defs),flush=True)
    assert git('rev-parse','HEAD')==BASELINE and not git('status','--porcelain')
    codes=collections.Counter(f['code'] for entry in errors+source_errors for f in entry['findings'])
    result={'schema':'pr122-legendary-single-technical-review-v1','baseline_sha':BASELINE,
        'whole_review_number':1,'required_slots_reviewed':1320,'available_record_slots':len(clips),
        'physical_new_source_reviews':len(source_defs),'source_review_uses':'Each authored physical source once; dependencies identify affected borrowed guards',
        'artifact_mutations':0,'generation_calls':0,'engine_playback_runs':0,'full_CI_runs':0,'approvals_added':0,
        'classification':'ERROR=definite static violation; HOLD=source ownership/registration candidate requiring visual confirmation; BLOCKED=missing slot',
        'mythic_read_only_references':['tools/import_original_based_motion.py:132','tools/pr122_reviewed_source_regions.py:97','tools/repack_pr122_disjoint_poses.py:23'],
        'thresholds':{'strong_alpha':100,'foreground_alpha':16,'body_seed_minimum_pixels':200,'detached_runner_up_margin_pixels':32.0,
                      'foot_bottom_fraction_range_hold':0.12,'visible_height_ratio_hold':1.4,'integer_grid_texture_extent_tolerance_pixels':1},
        'limitations':['This is static technical/source-pixel review, not anatomical/identity/camera visual approval',
                      'Frame edge touch and bounding-box drift are HOLD candidates, not instructions to regenerate normal clips',
                      'Unavailable local Player/actor-motion blobs were not fetched; runtime normalization and final integration remain deferred'],
        'finding_counts_by_code':dict(sorted(codes.items())),'slot_findings':errors,'source_findings':source_errors}
    OUTPUT.parent.mkdir(parents=True,exist_ok=True)
    with OUTPUT.open('x') as handle:json.dump(result,handle,ensure_ascii=False,indent=2);handle.write('\n')
    (RUNTIME/'completed.json').write_text(json.dumps({'baseline_sha':BASELINE,'output':str(OUTPUT),'sha256':digest(OUTPUT.read_bytes()),'whole_review_number':1})+'\n')
    print(json.dumps({'status':'SINGLE_REVIEW_COMPLETE_NO_ASSET_CHANGES','slots':1320,'records':len(clips),
                      'sources':len(source_defs),'output':str(OUTPUT),'finding_counts':dict(sorted(codes.items()))},ensure_ascii=False))


if __name__=='__main__':main()
