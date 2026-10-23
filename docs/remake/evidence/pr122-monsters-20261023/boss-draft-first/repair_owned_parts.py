#!/usr/bin/env python3
"""Losslessly isolate six topology-owned poses when their rectangles overlap.

Only the frozen error cohort is changed. The original importer stays strict.
No inpainting, silhouette guessing, fixed-cell cutting or original PNG edits.
Every source texel with alpha>0 must have exactly one identical RGBA owner.
Six disconnected strong bodies and unambiguous alpha16 topology are required.
"""
import hashlib,json,sys
from pathlib import Path
from collections import Counter
import numpy as np
from scipy import ndimage
from PIL import Image,ImageDraw

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'tools'))
import import_original_based_motion as core
import pr122_reviewed_source_regions as ownership

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')

def repair(row,out):
    source=ROOT/row['source'];assert sha(source)==row['source_sha256']
    pixels=np.array(Image.open(source).convert('RGBA'));alpha=pixels[:,:,3]
    assert not any(np.any(e>100) for e in (alpha[0],alpha[-1],alpha[:,0],alpha[:,-1])),'Source boundary truncation'
    labels,_=ndimage.label(alpha>100);areas=np.bincount(labels.ravel())
    bodies=[int(v) for v in np.flatnonzero(areas>=200) if v]
    assert len(bodies)==6,'Six original separated strong bodies required'
    h,w=alpha.shape;slots={};seedframes=[]
    for body in bodies:
        ys,xs=np.where(labels==body)
        slot=int((ys.min()+ys.max()+1)/2/h*2)*3+int((xs.min()+xs.max()+1)/2/w*3)
        assert 0<=slot<6 and slot not in slots,'Explicit phase_grid3 assignment is ambiguous'
        slots[slot]=body
    assert len(slots)==6
    # Narrow interior seeds identify bodies without including a neighbour whose
    # bbox happens to interleave; the foreground topology decides all ownership.
    for i in range(6):
        ys,xs=np.where(labels==slots[i]);n=len(xs)//2
        seedframes.append(dict(region=[int(xs[n]),int(ys[n]),1,1]))
    owners,topology=ownership._foreground_owners(alpha,seedframes)
    # Alpha1..16 fringes keep their exact RGBA. Assign only this sub-threshold
    # fringe to the nearest already-proven foreground; alpha>16 is never guessed.
    fringe=(alpha>0)&(owners==255)
    if fringe.any():
        _,near=ndimage.distance_transform_edt(owners==255,return_indices=True)
        owners[fringe]=owners[near[0][fringe],near[1][fringe]]
    assert np.all(owners[alpha>0]<6)
    parts={}
    for i in range(6):
        part=np.zeros_like(pixels);mask=(owners==i)&(alpha>0)
        part[mask]=pixels[mask];parts[str(i)]=part
    proof=ownership.require_native_source_part_ownership(pixels,parts)
    boxes=[]
    for i in range(6):
        ys,xs=np.where(parts[str(i)][:,:,3]>0)
        boxes.append([int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)])
    tile=((max(max(b[2]-b[0],b[3]-b[1]) for b in boxes)+6+7)//8)*8
    packed=np.zeros((tile*2,tile*3,4),np.uint8)
    frames=[];neutral=float(np.median([boxes[i][3]-boxes[i][1] for i in [0,3]]))
    canvas=max(64,round(neutral*256/96/8)*8)
    for i,b in enumerate(boxes):
        x,y,x2,y2=b;bw,bh=x2-x,y2-y
        dx,dy=tile*(i%3)+3,tile*(i//3)+3
        packed[dy:dy+bh,dx:dx+bw]=parts[str(i)][y:y2,x:x2]
        anchor=[round(w/3*(i%3+.5)),int(np.max(np.where(labels==slots[i])[0]))]
        # Registration is translated with its whole source pose, never a bbox
        # centre for a long weapon. Exact source origin survives in the proof.
        ax,ay=anchor[0]-x,anchor[1]-y
        mx,my=canvas//2-ax,canvas*5//8-ay
        assert min(mx,my)>=0 and mx+bw<=canvas and my+bh<=canvas,'Full owned pose cannot fit its unchanged registration'
        crop=packed[dy:dy+bh,dx:dx+bw]
        frames.append(dict(row=i,direction=row['direction'],region=[dx,dy,bw,bh],margin=[mx,my,canvas-bw,canvas-bh],source_anchor=[dx+ax,dy+ay],rgba_sha256=hashlib.sha256(crop.tobytes()).hexdigest(),original_source_region=[x,y,bw,bh],original_source_anchor=anchor))
    assert len({core._visible_pose_fingerprint(packed[f['region'][1]:f['region'][1]+f['region'][3],f['region'][0]:f['region'][0]+f['region'][2]]) for f in frames})==6
    dest=ROOT/'assets/actors/eight_direction/boss_draft_first'/row['slug']/'owned_parts_v01'/(row['clip']+'.png')
    dest.parent.mkdir(parents=True,exist_ok=True);assert not dest.exists()
    Image.fromarray(packed).save(dest)
    g=dict(image_size=[tile*3,tile*2],frames=frames,distinct_pixel_frames=6,neutral_height=neutral,canvas_size=[canvas,canvas],foot=[canvas//2,canvas*5//8])
    core.require_complete_pose_regions(dest,g)
    return dict(status='LOSSLESS_OWNED_PARTS_PASS',source=row['source'],source_sha256=row['source_sha256'],texture=dest.relative_to(ROOT).as_posix(),texture_sha256=sha(dest),geometry=g,proof=dict(**proof,**topology,subthreshold_fringe_texels=int(fringe.sum()),rule='alpha16 topology; alpha1..16 nearest proven foreground only',pose_regions_may_interleave_in_source=True,original_png_unchanged=sha(source)==row['source_sha256'],pose_pixels_invented=0))

def main():
    rows=json.loads((HERE/'whole-review-v01/structural-inventory.json').read_text())['clips']
    out=HERE/'whole-review-v01/owned-parts-repair';out.mkdir(exist_ok=True)
    candidates=[r for r in rows if r.get('cause') in ('foreign_body_rectangle','omitted_foreground','foreground_ownership')]
    results=[]
    for r in candidates:
        p=out/r['slug']/(r['clip']+'.json')
        if p.exists():result=json.loads(p.read_text());assert result['source_sha256']==r['source_sha256']
        else:
            try:result=repair(r,out)
            except (ValueError,AssertionError) as e:result=dict(status='HOLD',reason=str(e),source=r['source'],source_sha256=r['source_sha256'])
            result.update(actor=r['actor'],slug=r['slug'],clip=r['clip'],role=r['role'],direction=r['direction'],original_cause=r['cause']);write(p,result)
        results.append(result)
    summary=dict(checked_error_clips=len(results),repaired=sum(r['status']!='HOLD' for r in results),remaining_holds=[dict(actor=r['actor'],clip=r['clip'],reason=r['reason']) for r in results if r['status']=='HOLD'],normal_clips_regenerated=0,original_pngs_regenerated=0,passing_cohort_reprocessed=0,repair_results=results)
    write(out/'summary.json',summary)
    print(json.dumps({k:v for k,v in summary.items() if k!='repair_results'},ensure_ascii=False))

if __name__=='__main__':main()
