#!/usr/bin/env python3
"""One frozen whole-draft structural inventory, after all planned attempts.

Does not regenerate art, approve visual quality, or change normal monsters.
Minimum batch checks are reused when their exact source/importer pins match.
"""
import hashlib
import json
from pathlib import Path
import sys
from collections import Counter
import numpy as np
from PIL import Image
from scipy import ndimage

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'tools'))
import import_original_based_motion as core
import pr122_reviewed_source_regions as reviewed_regions

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def category(reason):
    if 'foreground ownership' in reason or 'Foreground connects' in reason or 'physical-body ownership' in reason:return 'foreground_ownership'
    if 'separated poses' in reason:return 'physical_component_count'
    if 'another body' in reason:return 'foreign_body_rectangle'
    if 'boundary' in reason:return 'source_outer_boundary'
    if 'outside pose regions' in reason:return 'omitted_foreground'
    if 'overlap' in reason:return 'region_overlap'
    if 'fit' in reason or 'canvas' in reason:return 'source_canvas_registration'
    if 'row' in reason or 'grid' in reason:return 'phase_grid_assignment'
    if 'distinct' in reason:return 'duplicate_source_pose'
    return 'other_source_geometry'

def main():
    plan=json.loads((HERE/'plan.json').read_text());jobs=[]
    for actor in plan['actors']:
        jobs.extend(json.loads((HERE/actor['slug']/'draft-queue.json').read_text()))
    service_file=HERE/'generation-service-hold.json'
    service=json.loads(service_file.read_text()) if service_file.exists() else None
    service_slots={(v['slug'],v['clip']):v for v in service['slots']} if service else {}
    if service:assert service['http_status']==429 and service['service_error_code']=='usage_limit_reached' and service['fully_authored_first_pass'] is False
    pending=[]
    for j in jobs:
        f=HERE/j['slug']
        if not (f/(j['clip']+'-receipt.json')).exists() and not (f/(j['clip']+'-generation-hold.json')).exists() and (j['slug'],j['clip']) not in service_slots:pending.append(dict(actor=j['actor'],clip=j['clip']))
    assert not pending,'Unresolved first-pass queue: '+str(len(pending))+' clips; no source or explicit service HOLD'
    out=HERE/'whole-review-v01';assert not (out/'summary.json').exists(),'Frozen inventory already complete; verify only changed/affected clips'
    out.mkdir(exist_ok=True)
    importer_sha=sha(ROOT/'tools/import_original_based_motion.py')
    rows=[]
    for j in jobs:
        folder=HERE/j['slug'];receipt=folder/(j['clip']+'-receipt.json')
        saved=out/'clips'/j['slug']/(j['clip']+'.json')
        if saved.exists():
            previous=json.loads(saved.read_text())
            assert previous['importer_sha256']==importer_sha,'Importer changed; preserve old pass and inspect affected checks'
            if receipt.exists():assert previous.get('source_sha256')==json.loads(receipt.read_text())['sha256']
            rows.append(previous);continue
        row=dict(actor=j['actor'],slug=j['slug'],clip=j['clip'],role=j['role'],direction=j['direction'])
        row['importer_sha256']=importer_sha
        saved.parent.mkdir(parents=True,exist_ok=True)
        if not receipt.exists():
            hold=folder/(j['clip']+'-generation-hold.json')
            if hold.exists():row.update(status='HOLD',cause='generation_output_missing',evidence=json.loads(hold.read_text()))
            else:row.update(status='HOLD',cause='generation_service_usage_limit',evidence=service_slots[(j['slug'],j['clip'])])
            rows.append(row)
            saved.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n');continue
        rec=json.loads(receipt.read_text());source=ROOT/rec['source'];row.update(source=rec['source'],source_sha256=rec['sha256'])
        try:
            assert sha(source)==rec['sha256'],'Source SHA256 mismatch'
            with Image.open(source) as image:alpha=np.asarray(image.getchannel('A'))
            strong_labels,_=ndimage.label(alpha>100)
            strong_areas=np.bincount(strong_labels.ravel())[1:]
            weak_labels,_=ndimage.label(alpha>16,np.ones((3,3)))
            weak_areas=np.bincount(weak_labels.ravel())[1:]
            row['component_inventory']=dict(strong_alpha100_bodies_ge200=int(np.count_nonzero(strong_areas>=200)),foreground_alpha16_parts_ge200=int(np.count_nonzero(weak_areas>=200)),strong_component_areas=sorted((int(v) for v in strong_areas if v>=200),reverse=True))
            cache=folder/'structural-checks'/(j['clip']+'.json')
            checked=json.loads(cache.read_text()) if cache.exists() else None
            if checked and checked['source_sha256']==rec['sha256'] and checked['importer_sha256']==importer_sha:
                if checked['status']=='SOURCE_HOLD':raise ValueError(checked['reason'])
                g=checked['geometry'];row['reused_pinned_minimum_check']=True
            else:
                g=core.analyze(source,6,[0,3],directions_axis='phase_grid3',canvas_size=2048,directions=[j['direction']])
                core.require_complete_pose_regions(source,g)
                canvas=max(64,round(g['neutral_height']*256/96/8)*8)
                for f in g['frames']:core._rebase_mixed_frame_canvas(f,canvas)
                g.update(canvas_size=[canvas,canvas],foot=[canvas//2,canvas*5//8],strict_source_analysis_canvas=2048)
                core.require_complete_pose_regions(source,g)
            assert len(g['frames'])==6 and len({v['rgba_sha256'] for v in g['frames']})==6,'Six distinct whole poses required'
            row['geometry']=g
            owners,ownership=reviewed_regions._foreground_owners(alpha,g['frames'])
            region_owners=np.full(alpha.shape,255,dtype=np.uint8)
            for index,f in enumerate(g['frames']):
                x,y,w,h=f['region'];region_owners[y:y+h,x:x+w]=index
            visible=alpha>16
            omitted=int(np.count_nonzero(visible & (region_owners==255)))
            foreign=int(np.count_nonzero(visible & (region_owners!=255) & (region_owners!=owners)))
            row['foreground_ownership']=dict(**ownership,omitted_pixels=omitted,foreign_owner_pixels=foreign)
            if foreign:raise ValueError('foreground ownership: source regions contain another pose foreground')
            if omitted:raise ValueError(str(omitted)+' foreground alpha16 pixels outside pose regions')
            row.update(status='STRUCTURAL_PASS',geometry=g,visual_review='AWAITING_SINGLE_WHOLE_SCOPE_VISUAL_PASS')
        except (ValueError,AssertionError,FileNotFoundError) as e:
            reason=str(e);row.update(status='HOLD',cause=category(reason),reason=reason)
        rows.append(row)
        saved.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
    summary=dict(planned_clips=len(jobs),source_drafts=sum('source' in r for r in rows),fully_authored_first_pass=all('source' in r for r in rows),global_service_blocked=bool(service),structural_pass=sum(r['status']=='STRUCTURAL_PASS' for r in rows),holds_by_common_cause=dict(Counter(r['cause'] for r in rows if r['status']=='HOLD')),original_PNGs_regenerated=0,normal_art_changed=0,new_approvals=0,full_visual_review='NOT_YET_PERFORMED; structural inventory is not visual approval',importer_sha256=importer_sha)
    (out/'structural-inventory.json').write_text(json.dumps(dict(summary=summary,clips=rows),ensure_ascii=False,indent=2)+'\n')
    (out/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__':main()
