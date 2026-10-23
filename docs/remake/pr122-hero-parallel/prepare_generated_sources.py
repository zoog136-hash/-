#!/usr/bin/env python3
"""Detect complete painted poses before rendering; never invent a missing pose.

PNG outputs are ownership-label DATA, not artwork. Godot samples the immutable
original RGBA pixels using these labels and one uniform scale for the actor.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'docs/remake/pr122-hero-parallel/evidence/generation-recovered-20261023'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def analyze(path, role, output, production_draft=False):
    image = np.array(Image.open(path).convert('RGBA'))
    height, width = image.shape[:2]
    rows = 3 if role == 'death' else 8
    nominal = height / rows
    foreground = image[:, :, 3] > 16
    # Some generated technical sheets contain long guide lines. They are not
    # character material and otherwise connect six complete bodies into one.
    guides = (ndimage.binary_opening(foreground, structure=np.ones((1,int(width*.75)))) |
              ndimage.binary_opening(foreground, structure=np.ones((int(height*.75),1))))
    guides = ndimage.binary_dilation(guides,iterations=1)
    foreground &= ~guides
    if role == 'death':
        # Dropped hats, drums and weapons are legitimate disconnected material.
        # Six S-only death cells have a reliable 2x3 layout; preserve all parts.
        labels = np.zeros(foreground.shape,dtype=np.int32)
        for y in range(3):
            for x in range(2):
                box=(slice(round(y*height/3),round((y+1)*height/3)),slice(round(x*width/2),round((x+1)*width/2)))
                labels[box] = np.where(foreground[box],y*2+x+1,0)
    else:
        labels, _ = ndimage.label(foreground, np.ones((3, 3)))
    areas = np.bincount(labels.ravel())
    boxes = ndimage.find_objects(labels)
    buckets = [[] for _ in range(rows)]
    components = []
    for label, box in enumerate(boxes, 1):
        if areas[label] < max(60, width * height * .00010):
            continue
        yy, xx = box
        row = min(rows - 1, int((yy.start + yy.stop) / 2 / nominal))
        components.append((int(areas[label]), label, box))
        if not production_draft or role == 'death':
            buckets[row].append(components[-1])
    if production_draft and role != 'death':
        # Generated rows have uneven heights. Cluster complete painted bodies,
        # retaining their top-to-bottom direction order instead of slicing them.
        major = [c for c in components if c[0] >= max(c[0] for c in components)*.18]
        centers = np.array([(c[2][0].start+c[2][0].stop)/2 for c in major])
        weights = np.array([c[0] for c in major])
        means = np.linspace(centers.min(),centers.max(),8)
        while True:
            for _ in range(24):
                assignments = np.abs(centers[:,None]-means).argmin(axis=1)
                updated = np.array([np.average(centers[assignments==i],weights=weights[assignments==i]) if (assignments==i).any() else means[i] for i in range(len(means))])
                if np.max(np.abs(updated-means)) < .01:break
                means = updated
            means.sort()
            # Some sheets contain E..N (seven rows), omitting NE. Do not split
            # one real row into two imaginary directions; NE may mirror NW.
            if len(means)>7 and np.diff(means).min() < nominal*.60:
                at=int(np.diff(means).argmin())
                means=np.concatenate([means[:at],[(means[at]+means[at+1])/2],means[at+2:]])
                continue
            break
        for component in components:
            box=component[2];center=(box[0].start+box[0].stop)/2
            buckets[int(np.abs(means-center).argmin())].append(component)
    selected = []
    counts = []
    usable = [True]*rows
    for direction, bucket in enumerate(buckets):
        if not bucket:
            counts.append(0);usable[direction]=False;continue
        threshold = max(item[0] for item in bucket) * .28
        major = sorted([item for item in bucket if item[0] >= threshold], reverse=True)
        required = 2 if role == 'death' else 6
        if role == 'attack' or (production_draft and role == 'run'):
            usable[direction] = len(major) >= 4
            required = min(6, len(major))
        else:
            usable[direction] = len(major) >= required
        chosen = sorted(major[:required], key=lambda item: item[2][1].start)
        counts.append(len(chosen))
        for phase, (_, label, box) in enumerate(chosen):
            selected.append(dict(label=label, direction=2 if role == 'death' else direction,
                                 phase=len(selected) if role == 'death' else phase,
                                 source_row=direction))
    owner = np.zeros(labels.shape, dtype=np.uint8)
    for index, pose in enumerate(selected, 1):
        pose['owner'] = index
        owner[labels == pose['label']] = index
    distance, nearest = ndimage.distance_transform_edt(owner == 0, return_indices=True)
    nearest_owner = owner[tuple(nearest)]
    selected_labels = {p['label'] for p in selected}
    fragments = []
    for label, box in enumerate(boxes, 1):
        if label in selected_labels or areas[label] < 12:
            continue
        local = labels[box] == label
        d = float(distance[box][local].min())
        neighbors = nearest_owner[box][local]
        neighbors = neighbors[neighbors > 0]
        if not len(neighbors):
            continue
        target = int(np.bincount(neighbors).argmax())
        owner[box][local] = target
        fragments.append(dict(pixels=int(areas[label]), gap=d, owner=target))
    distance, nearest = ndimage.distance_transform_edt(owner == 0, return_indices=True)
    owner = np.where((image[:, :, 3] > 0) & (distance <= 2), owner[tuple(nearest)], 0).astype(np.uint8)
    owner[guides] = 0
    for pose in selected:
        points = owner == pose['owner']
        ys, xs = np.where(points)
        left, right, top, bottom = int(xs.min()), int(xs.max()) + 1, int(ys.min()), int(ys.max()) + 1
        # The tool leaves faint matte/antialias pixels in the empty gutter.
        # Test actual visible ink, keeping every original pixel in the ROI.
        ink_y, ink_x = np.where(points & (image[:,:,3] > 64))
        clipped = ink_x.min() <= 0 or ink_x.max() >= width-1 or ink_y.min() <= 0 or ink_y.max() >= height-1
        if clipped and not production_draft:
            usable[pose['source_row']] = False
        pose['outer_canvas_ink_clip'] = bool(clipped)
        pose['rect'] = [left, top, right-left, bottom-top]
        local = points[top:bottom, left:right]
        dense = ndimage.distance_transform_edt(local)
        weights = dense * dense
        weights[:int(local.shape[0] * .20)] = 0
        weights[int(local.shape[0] * .85):] = 0
        horizontal = weights.sum(axis=0)
        center = int(np.searchsorted(np.cumsum(horizontal), horizontal.sum() / 2))
        pose['root_x'] = left + center
        near = points[:, max(0,pose['root_x']-int(nominal*.30)):min(width,pose['root_x']+int(nominal*.30))]
        feet = np.where(near)[0]
        pose['measured_ground'] = int(feet.max()) + 1 if len(feet) else bottom
        pose['rgba_sha256'] = hashlib.sha256(image[top:bottom,left:right].tobytes()+local.tobytes()).hexdigest()
        pose.pop('label')
    if role == 'death':
        for pose in selected:
            pose['root_y'] = pose['rect'][1] + pose['rect'][3]
    else:
        for direction in range(8):
            group = [p for p in selected if p['direction'] == direction]
            if not group:
                continue
            samples = [group[i]['measured_ground'] for i in ([0,1,3,4] if role == 'run' else [0,1,2] if role == 'support' else [0,len(group)-1]) if i < len(group)]
            ground = float(np.median(samples))
            for pose in group:
                pose['root_y'] = ground
            # Neutral recovery may legitimately reuse an idle pose. It is a
            # different action; only duplicates within one clip are relevant.
            clips = [group[:3],group[3:]] if role == 'support' else [group]
            if any(len({p['rgba_sha256'] for p in clip}) != len(clip) for clip in clips):usable[direction]=False
    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(owner).save(output)
    return dict(raw='res://'+str(path.relative_to(ROOT)), raw_sha256=sha(path),
                ownership='res://'+str(output.relative_to(ROOT)), ownership_sha256=sha(output),
                nominal=nominal, counts=counts, usable_dirs=usable, poses=selected,
                guides_removed_pixels=int(guides.sum()),fragments=fragments)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--id', required=True)
    parser.add_argument('--reuse-id', help='Validated same-appearance palette variant only')
    parser.add_argument('--production-draft', action='store_true',help='Assemble real poses; retain source warnings for final review, without granting approval')
    args = parser.parse_args()
    sid = args.id
    folder = ROOT / 'assets/actors/eight_direction/hero_parallel' / ('death_155' if sid == '155' else 'hero_generated_'+sid) / 'r001'
    scope = json.loads((ROOT/'data/pr122_hero_parallel_staging.json').read_text())
    assert not scope['actors']['transform:'+sid]['final_approved']
    baseline = json.loads((BASE/'baseline-profiles.json').read_text())[sid]
    if args.reuse_id:
        assert (args.reuse_id,sid) == ('179','182')
        origin = ROOT/'assets/actors/eight_direction/hero_parallel'/('hero_generated_'+args.reuse_id)/'r001/source-layout.json'
        layout = json.loads(origin.read_text())
        assert baseline['height'] == layout['baseline']['height'] and abs(baseline['ground']-layout['baseline']['ground']) < .01
        layout.update(id=sid,baseline=baseline,folder='res://'+str(folder.relative_to(ROOT))+'/',
                      palette_variant={'source_actor':'179','hue_shift':.62,'red_hue_tolerance':.06,'minimum_saturation':.35},
                      fingerprint=hashlib.sha256((sha(origin)+sha(__file__)+sid).encode()).hexdigest())
        folder.mkdir(parents=True,exist_ok=True)
        (folder/'source-layout.json').write_text(json.dumps(layout,indent=2)+'\n')
        print('HERO_PALETTE_SOURCE_REUSED id=182 source=179 new_source_paintings=0')
        return
    fingerprint = sha(__file__) + str(args.production_draft) + ''.join(sha(folder/'raw'/('source-'+r+'.png')) for r in ['run','attack','support','death']) + json.dumps(baseline, sort_keys=True)
    fingerprint = hashlib.sha256(fingerprint.encode()).hexdigest()
    manifest = folder/'source-layout.json'
    if manifest.exists() and json.loads(manifest.read_text()).get('fingerprint') == fingerprint:
        print('HERO_SOURCE_LAYOUT_REUSED id='+sid+' writes=0')
        return
    evidence = BASE/('source-layout-'+sid)/sha(__file__)[:12]
    sources = {role:analyze(folder/'raw'/('source-'+role+'.png'),role,evidence/(role+'-ownership.png'),args.production_draft) for role in ['run','attack','support','death']}
    warnings=[]
    if args.production_draft:
        for role,source in sources.items():
            for pose in source['poses']:
                if pose['outer_canvas_ink_clip']:
                    warnings.append({'issue':'SOURCE_CANVAS_EDGE_REVIEW','role':role,'direction':pose['direction'],'phase':pose['phase']})
            if role != 'death':
                for direction in range(8):
                    count=source['counts'][direction]
                    # Never manufacture repeated frames to fill a nominal grid.
                    if count != 6:warnings.append({'issue':'VARIABLE_REAL_POSE_COUNT','role':role,'direction':direction,'count':count})
                    source['usable_dirs'][direction]=count >= (4 if role in ['run','attack'] else 6)
    # Choose one consistent source for each opposite-view pair across all
    # actions, then mirror naturally. Never replace a missing S or N view.
    motion_roles = ['run','attack','support']
    good = lambda d: all(sources[r]['usable_dirs'][d] for r in motion_roles)
    assert good(2) and good(6), ('MISSING_GENUINE_S_OR_N_SOURCE_VIEW', {r:sources[r]['counts'] for r in motion_roles})
    mapping = {2:(2,False),6:(6,False)}
    for preferred,other in [(4,0),(3,1),(5,7)]:
        assert good(preferred) or good(other), ('MISSING_GENUINE_OPPOSITE_VIEW_PAIR',preferred,other)
        chosen = preferred if good(preferred) else other
        mapping[preferred]=(chosen,chosen!=preferred)
        mapping[other]=(chosen,chosen!=other)
    for role in motion_roles:
        source=sources[role];original=source['poses'];canonical=[];counts=[]
        source['source_counts']=source['counts'];source['heading_reuse']={}
        for direction in range(8):
            selected_direction,mirror=mapping[direction]
            group=[copy.deepcopy(p) for p in original if p['direction']==selected_direction]
            for pose in group:pose.update(direction=direction,mirrored_x=mirror)
            canonical.extend(group);counts.append(len(group))
            source['heading_reuse'][str(direction)]={'source_direction':selected_direction,'mirrored_x':mirror}
        source['poses']=canonical;source['counts']=counts
    assert (args.production_draft or all(sources['death']['usable_dirs'])) and len(sources['death']['poses'])==6, 'INCOMPLETE_S_DEATH_SOURCE'
    nominal = sources['support']['nominal']
    support = [p for p in sources['support']['poses'] if p['direction'] == 2 and p['phase'] < 3]
    body_height = float(np.median([p['rect'][3] for p in support]))
    scale = min(float(baseline['height']) / body_height, 1.0)
    ground = float(baseline['ground']) - 16.0
    assert 20 < ground < 210, baseline
    for role,source in sources.items():
        unit = nominal/source['nominal']
        source['unit_scale'] = unit
        for pose in source['poses']:
            x,y,w,h = pose['rect'];rx,ry = pose['root_x'],pose['root_y']
            for extent,space in [(max(rx-x,x+w-rx)*unit,104),((ry-y)*unit,ground-8),((y+h-ry)*unit,224-ground-8)]:
                if extent > 0: scale = min(scale,space/extent)
    assert scale > .05
    result = dict(schema='hero-detected-source-layout-v1',id=sid,fingerprint=fingerprint,
                  baseline=baseline,folder='res://'+str(folder.relative_to(ROOT))+'/',
                  sources=sources,uniform_scale=scale,cell=224,pad=16,ground=ground,
                  policy='COMPLETE_SOURCE_POSES_UNIFORM_SCALE_ROW_GROUND_NO_RUN_Y_SNAPS',production_draft=args.production_draft,source_warnings=warnings,final_approved=False)
    manifest.write_text(json.dumps(result,indent=2)+'\n')
    print('HERO_SOURCE_LAYOUT_WRITTEN id='+sid+' real_run='+str(sum(sources['run']['counts']))+' attack='+str(sum(sources['attack']['counts']))+' source_paintings=4 draft='+str(args.production_draft))


if __name__ == '__main__':
    main()
