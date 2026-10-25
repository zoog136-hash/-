#!/usr/bin/env python3
"""One structural pass over changed v02 sources, then bounded lossless packing."""
import json,subprocess,time
from pathlib import Path
HERE=Path(__file__).resolve().parent
B=HERE.parent
ROOT=B.parents[4]
def run(args):
    r=subprocess.run(args,cwd=ROOT,text=True,capture_output=True,check=True)
    print(r.stdout.strip(),flush=True)
def main():
    jobs=json.loads((HERE/'queue.json').read_text())['jobs']
    for _ in range(240):
        if all((B/j['slug']/(j['clip']+'-receipt.json')).exists() or (HERE/'attempts'/(j['slug']+'__'+j['clip']+'.json')).exists() for j in jobs):break
        time.sleep(10)
    else:raise RuntimeError('Bounded queue wait expired; do not retry source generation')
    review=HERE/'affected-review-v01'
    assert not (review/'summary.json').exists(),'Changed-source pass already frozen'
    run(['python3',str(B/'full_source_review.py'),'--queue',str(HERE/'queue.json'),'--output',str(review)])
    run(['python3',str(B/'repair_owned_parts.py'),'--review-root',str(review)])
    run(['python3',str(B/'resume210-v01/verify_owned_roundtrip.py'),'--review-root',str(review)])
    run(['python3',str(HERE/'visual_pages.py'),'--final'])
    print('TARGETED_SOURCE_GEOMETRY_COMPLETE; visual assessment still required',flush=True)
if __name__=='__main__':main()
