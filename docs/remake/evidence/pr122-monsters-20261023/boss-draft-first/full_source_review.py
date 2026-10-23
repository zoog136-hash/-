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

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'tools'))
import import_original_based_motion as core

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def category(reason):
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
    pending=[]
    for j in jobs:
        f=HERE/j['slug']
        if not (f/(j['clip']+'-receipt.json')).exists() and not (f/(j['clip']+'-generation-hold.json')).exists():pending.append(dict(actor=j['actor'],clip=j['clip']))
    assert not pending,'Whole first pass not finished: '+str(len(pending))+' unattempted clips; do not start full review or polish'
    out=HERE/'whole-review-v01';assert not out.exists(),'One frozen inventory only; use targeted followups for changed/affected clips'
    out.mkdir()
    importer_sha=sha(ROOT/'tools/import_original_based_motion.py')
    rows=[]
    for j in jobs:
        folder=HERE/j['slug'];receipt=folder/(j['clip']+'-receipt.json')
        row=dict(actor=j['actor'],slug=j['slug'],clip=j['clip'],role=j['role'],direction=j['direction'])
        if not receipt.exists():
            row.update(status='HOLD',cause='generation_output_missing',evidence=json.loads((folder/(j['clip']+'-generation-hold.json')).read_text()));rows.append(row);continue
        rec=json.loads(receipt.read_text());source=ROOT/rec['source'];row.update(source=rec['source'],source_sha256=rec['sha256'])
        try:
            assert sha(source)==rec['sha256'],'Source SHA256 mismatch'
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
            row.update(status='STRUCTURAL_PASS',geometry=g,visual_review='AWAITING_SINGLE_WHOLE_SCOPE_VISUAL_PASS')
        except (ValueError,AssertionError,FileNotFoundError) as e:
            reason=str(e);row.update(status='HOLD',cause=category(reason),reason=reason)
        rows.append(row)
    summary=dict(planned_clips=len(jobs),source_drafts=sum('source' in r for r in rows),structural_pass=sum(r['status']=='STRUCTURAL_PASS' for r in rows),holds_by_common_cause=dict(Counter(r['cause'] for r in rows if r['status']=='HOLD')),original_PNGs_regenerated=0,normal_art_changed=0,new_approvals=0,full_visual_review='NOT_YET_PERFORMED; structural inventory is not visual approval',importer_sha256=importer_sha)
    (out/'structural-inventory.json').write_text(json.dumps(dict(summary=summary,clips=rows),ensure_ascii=False,indent=2)+'\n')
    (out/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__':main()
