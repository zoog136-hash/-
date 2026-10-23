#!/usr/bin/env python3
"""One read-only inventory pass; preserve findings separately from approval state."""
import collections
import hashlib
import json
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT/'docs/remake/pr122-hero-parallel/evidence/audit-once-20261023'
DIRECTIONS = ['E','SE','S','SW','W','NW','N','NE']


def local(path):
    return ROOT/path.removeprefix('res://')


@lru_cache(maxsize=2048)
def digest(path):
    return hashlib.sha256(local(path).read_bytes()).hexdigest()


@lru_cache(maxsize=24)
def picture(path):
    return Image.open(local(path)).convert('RGBA')


def canvas(frame):
    x,y,w,h=map(int,frame['region']);left,top=map(int,frame['margin'][:2])
    result=Image.new('RGBA',(int(frame['width']),int(frame['height'])))
    result.paste(picture(frame['path']).crop((x,y,x+w,y+h)),(left,top))
    return result


def scan():
    snapshot=json.loads((OUT/'resource-snapshot.json').read_text())
    stage=json.loads((ROOT/'data/pr122_hero_parallel_staging.json').read_text())
    selected=stage['actors'] | stage['remediation_18']['actors']
    issues=[];connectivity=[];stats=collections.Counter();files=set()
    def issue(code,actor,**details):issues.append(dict(code=code,id=actor,**details))
    for actor in snapshot['heroes']:
        key=actor['id'];stats['heroes']+=1
        for role in ['idle','attack','hit','death']:
            for direction in range(8):
                name=role+'_'+str(direction)
                if name not in actor['tracks']:issue('MISSING_REQUIRED_TRACK',key,track=name)
        if actor['candidate']:
            entry=selected[key];receipt=json.loads(local(entry['approval_receipt']).read_text())
            for field,seal in [('frames','frames_sha256'),('native_profile','native_profile_sha256'),('rig','rig_sha256')]:
                if digest(entry[field])!=receipt[seal]:issue('APPROVAL_SHA_MISMATCH',key,field=field)
            proof=json.loads(local(entry['rig']).read_text())
            for path,seal in proof.get('source_hashes',{}).items():
                if digest(path)!=seal:issue('SOURCE_SHA_MISMATCH',key,path=path)
            report=json.loads(local(entry['main_validation_report']).read_text())
            if report['frames_sha256']!=digest(entry['frames']):issue('STALE_MAIN_RESOURCE_REPORT',key)
            expected={(DIRECTIONS.index(p['direction']) if p['direction'] in DIRECTIONS else int(p['direction']),int(p['phase'])):p['rgba_sha256'] for p in proof['frames']}
            stats['selected_candidates']+=1
        for name,track in actor['tracks'].items():
            stats['tracks']+=1
            if not track['frames'] or track['speed']<=0:issue('INVALID_PLAYBACK',key,track=name)
            if name.startswith(('attack_','hit_','death_')) and track['loop']:issue('ACTION_LOOPS',key,track=name)
            seen=set()
            for phase,frame in enumerate(track['frames']):
                stats['phase_references']+=1
                path=frame['path'];files.add(path)
                if not local(path).is_file():issue('MISSING_TEXTURE',key,path=path,track=name);continue
                if frame['duration']<=0:issue('INVALID_DURATION',key,track=name,phase=phase)
                image=canvas(frame);alpha=np.array(image.getchannel('A'))
                if not (alpha>16).any():issue('EMPTY_VISIBLE_FRAME',key,track=name,phase=phase)
                if actor['candidate'] and name.startswith('run_'):
                    direction=int(name.split('_')[1]);value=hashlib.sha256(image.tobytes()).hexdigest()
                    if value in seen:issue('DUPLICATED_RUN_POSE',key,track=name,phase=phase)
                    seen.add(value)
                    if value!=expected.get((direction,phase)):issue('RUN_PROOF_MISMATCH',key,track=name,phase=phase)
                    if (alpha[[0,-1],:]>16).any() or (alpha[:,[0,-1]]>16).any():issue('CLIPPED_RUN_CANVAS',key,track=name,phase=phase)
                    labels,_=ndimage.label(alpha>16,np.ones((3,3)))
                    areas=np.bincount(labels.ravel());areas[0]=0
                    major=[int(i) for i in np.where(areas>12)[0]]
                    if len(major)>1:
                        largest=max(major,key=lambda i:areas[i]);distance=ndimage.distance_transform_cdt(labels!=largest,metric='chessboard')
                        parts=[dict(pixels=int(areas[i]),empty_grid_gap_pixels=int(distance[labels==i].min())-1) for i in major if i!=largest]
                        connectivity.append(dict(id=key,direction=direction,phase=phase,rgba_sha256=value,components_8=sorted([int(areas[i]) for i in major],reverse=True),parts=parts))
                    stats['run_pose_references']+=1
        if actor['candidate']:
            for field in ['attack_hit_frame','attack_hit_ratio','attack_animation_speed','death_duration','pixel_scale','native_width_ratio','reference_speed']:
                if actor['profile'][field]!=actor['baseline_profile'][field]:issue('GAMEPLAY_PROFILE_CHANGED',key,field=field)
    result=dict(schema='hero-one-pass-audit-v1',stats=dict(stats),unique_texture_files=len(files),confirmed_asset_errors=issues,run_connectivity_findings=connectivity,asset_writes=0)
    (OUT/'asset-findings-before.json').write_text(json.dumps(result,indent=2)+'\n')
    print('HERO_ONE_PASS_AUDIT '+json.dumps(dict(stats=dict(stats),asset_errors=len(issues),connectivity_findings=len(connectivity),actors_with_connectivity=len({x['id'] for x in connectivity}))))


if __name__=='__main__':scan()
