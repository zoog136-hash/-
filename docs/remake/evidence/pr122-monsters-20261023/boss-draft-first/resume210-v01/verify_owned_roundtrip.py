#!/usr/bin/env python3
"""Check actual packed PNGs reconstruct every original visible RGBA texel once."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parents[4]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--review-root',type=Path,default=HERE/'whole-review-v01');parser.add_argument('--proof-list',type=Path);parser.add_argument('--output-name',default='roundtrip-verification.json');a=parser.parse_args()
    folder=a.review_root.resolve()/'owned-parts-repair'
    results=[]
    proofs=[ROOT/p for p in json.loads(a.proof_list.read_text())] if a.proof_list else sorted(folder.glob('*/*.json'))
    for proof in proofs:
        d=json.loads(proof.read_text())
        if d['status']!='LOSSLESS_OWNED_PARTS_PASS':continue
        source=ROOT/d['source'];texture=ROOT/d['texture']
        assert sha(source)==d['source_sha256'] and sha(texture)==d['texture_sha256']
        src=np.array(Image.open(source).convert('RGBA'));packed=np.array(Image.open(texture).convert('RGBA'))
        recovered=np.zeros_like(src);coverage=np.zeros(src.shape[:2],np.uint8)
        for f in d['geometry']['frames']:
            x,y,w,h=f['region'];sx,sy,sw,sh=f['original_source_region'];assert (w,h)==(sw,sh)
            part=packed[y:y+h,x:x+w];assert hashlib.sha256(part.tobytes()).hexdigest()==f['rgba_sha256']
            visible=part[:,:,3]>0
            recovered[sy:sy+h,sx:sx+w][visible]=part[visible]
            coverage[sy:sy+h,sx:sx+w][visible]+=1
        visible=src[:,:,3]>0
        missing=int(np.count_nonzero(visible & (coverage==0)))
        duplicate=int(np.count_nonzero(coverage>1))
        invented=int(np.count_nonzero((~visible)&(coverage>0)))
        altered=int(np.count_nonzero(np.any(src[visible]!=recovered[visible],axis=1)))
        assert missing==duplicate==invented==altered==0
        results.append(dict(slug=d['slug'],clip=d['clip'],status='EXACT_VISIBLE_RGBA_ROUNDTRIP_PASS',source_sha256=d['source_sha256'],texture_sha256=d['texture_sha256'],missing_texels=missing,duplicated_texels=duplicate,invented_texels=invented,altered_texels=altered))
    summary=dict(checked=len(results),all_exact=True,original_pngs_regenerated=0,passing_clips_reprocessed=0,results=results)
    target=folder/a.output_name;assert not target.exists(),'Proof already saved; verify only affected repairs'
    target.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in summary.items() if k!='results'}))
if __name__=='__main__':main()
