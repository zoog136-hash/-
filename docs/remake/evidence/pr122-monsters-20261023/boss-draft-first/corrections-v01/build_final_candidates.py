#!/usr/bin/env python3
"""Select reviewed sources once per direction/role; unresolved clips stay HOLD."""
from collections import defaultdict
import json,subprocess,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
B=HERE.parent
ROOT=B.parents[4]
def read(p):return json.loads(p.read_text())
def write(p,d):p.parent.mkdir(exist_ok=True,parents=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def main():
    review=read(HERE/'visual-review.json');pages=read(HERE/'visual-pages/manifest.json')
    assert set(review['pages'])=={str(p['number']) for p in pages},'Inspect changed sources before final selection'
    inspected={(c['slug'],c['clip']) for p in pages for c in p['clips']}
    visual_bad={(f['slug'],f['clip']) for f in review['findings']}
    rows={(x['slug'],x['clip']):x for x in read(HERE/'combined-reviewed-v01/structural-inventory.json')['clips']}
    changes=read(HERE/'affected-review-v01/structural-inventory.json')['clips']
    for x in changes:
        proof=HERE/'affected-review-v01/owned-parts-repair'/x['slug']/(x['clip']+'.json')
        if proof.exists() and (rep:=read(proof))['status']=='LOSSLESS_OWNED_PARTS_PASS':
            x.update(geometry=rep['geometry'],ownership_proof=proof.relative_to(ROOT).as_posix(),texture=rep['texture'],repaired_geometry=True)
        rows[(x['slug'],x['clip'])]=x
    corrections=read(HERE/'queue.json')['jobs'];bad_old={(j['slug'],j['corrects']) for j in corrections}
    chosen={};holds=[]
    for key,x in rows.items():
        if key in bad_old:continue
        is_v02=x['clip'].endswith('-v02')
        safe=x['status']=='STRUCTURAL_PASS' or x.get('repaired_geometry',False)
        if not safe or key in visual_bad or (is_v02 and key not in inspected):
            if is_v02 or key in visual_bad:holds.append(dict(slug=x['slug'],clip=x['clip'],reason=x.get('reason','Confirmed visual or missing-output HOLD'),cause=x.get('cause','visual_review')))
            continue
        slot=(x['slug'],x['direction'],x['role']);assert slot not in chosen
        chosen[slot]=x
    out=HERE/'final-reviewed-v01';out.mkdir(exist_ok=True)
    write(out/'structural-inventory.json',dict(clips=list(chosen.values())))
    adjustments=read(HERE/'combined-reviewed-v01/frame-adjustments-v01.json')
    for x in chosen.values():
        if x['role']=='death' and x['clip'].endswith('-v02'):
            g=x['geometry'];h=g['frames'][0]['region'][3];canvas=max(64,round(h*256/96/8)*8)
            if abs(canvas/g['canvas_size'][0]-1)>.05:adjustments.setdefault(x['slug'],{})[x['clip']]=dict(source_sha256=x['source_sha256'],canvas_size=canvas,neutral_height=h,reason='Reviewed upright death phase0 reference',original_rgba_changed=False)
    write(out/'frame-adjustments-v01.json',adjustments)
    groups=defaultdict(list)
    for x in chosen.values():groups[x['slug']].append(x['clip'])
    results=[]
    for slug,clips in sorted(groups.items()):
        selection=out/(slug+'-clips.json');write(selection,sorted(clips))
        command=['python3',str(B/'stage_structural_batch.py'),slug,'--revision','reviewed-final-v01','--reviewed-inventory','--inventory-root',str(out),'--frame-adjustments',str(out/'frame-adjustments-v01.json'),'--receipt-list',str(selection)]
        subprocess.run(command,cwd=ROOT,text=True,capture_output=True,check=True)
        candidate=B/slug/'reviewed-final-v01/candidate.json';d=read(candidate);actor,profile=next(iter(d['actors'].items()));assert not d['source_holds']
        profile['quality_review']='Single whole495 visual pass followed by bounded affected-source corrections; normal art unchanged'
        results.append(dict(key=actor,slug=slug,candidate=candidate.relative_to(ROOT).as_posix(),native_profile=profile['native_profile'],frames=profile['frames'],tracks=profile['native_track_count'],poses=profile['native_pose_count'],missing=profile['missing_required_tracks'],eligible_complete=not profile['missing_required_tracks']))
    write(out/'summary.json',dict(first_draft_slots=495,actors=results,selected_clips=len(chosen),holds=holds,normal_art_changed=0,source_versions_preserved=True))
    print(json.dumps(dict(selected_clips=len(chosen),complete_bosses=sum(x['eligible_complete'] for x in results),holds=len(holds))))
if __name__=='__main__':main()
