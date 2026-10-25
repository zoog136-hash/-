#!/usr/bin/env python3
"""Combine already-reviewed inventories; measure only affected death calibration."""
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
B=HERE.parent
R=B/'resume210-v01/whole-review-v01'
ROOT=B.parents[4]
def read(p):return json.loads(p.read_text())
def write(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def main():
    rows={}
    for review in [B/'whole-review-v01',R]:
        for row in read(review/'structural-inventory.json')['clips']:
            x=dict(row);proof=review/'owned-parts-repair'/x['slug']/(x['clip']+'.json')
            if proof.exists():
                rep=read(proof)
                if rep['status']=='LOSSLESS_OWNED_PARTS_PASS':
                    x.update(geometry=rep['geometry'],ownership_proof=proof.relative_to(ROOT).as_posix(),texture=rep['texture'],repaired_geometry=True)
            rows[(x['slug'],x['clip'])]=x
    assert len(rows)==495
    combined=HERE/'combined-reviewed-v01';combined.mkdir(exist_ok=True)
    write(combined/'structural-inventory.json',dict(clips=list(rows.values())))
    adjustments={};measurements=[]
    for x in rows.values():
        if x['role']!='death' or 'geometry' not in x:continue
        g=x['geometry'];h=g['frames'][0]['region'][3];canvas=max(64,round(h*256/96/8)*8);before=g['canvas_size'][0];ratio=canvas/before
        changed=abs(ratio-1)>.05
        measurements.append(dict(slug=x['slug'],old_canvas=before,upright_canvas=canvas,ratio=ratio,changed=changed))
        if changed:adjustments.setdefault(x['slug'],{})[x['clip']]=dict(source_sha256=x['source_sha256'],canvas_size=canvas,neutral_height=h,reason='Reviewed upright death phase0; do not mix upright and collapsed phases for scale',original_rgba_changed=False)
    for slug,clip,select in [('prince_deus','NW-attack-v01',[0,1,3,4,5]),('prince_deus','N-attack-v01',[0,1,2,4,5]),('grim_reaper','N-attack-v01',[0,1,2,4,5])]:
        x=rows[(slug,clip)]
        adjustments.setdefault(slug,{})[clip]=dict(source_sha256=x['source_sha256'],selected_phases=select,contact_native_index=2,original_duration_seconds=.6,reason='Omit confirmed duplicate-weapon/hand-swap pose; five complete authored poses, unchanged attack duration',original_rgba_changed=False)
    write(combined/'frame-adjustments-v01.json',adjustments)
    write(combined/'death-calibration-measurement.json',measurements)
    print(json.dumps(dict(measurements=measurements,pose_selection_clips=3)))
if __name__=='__main__':main()
