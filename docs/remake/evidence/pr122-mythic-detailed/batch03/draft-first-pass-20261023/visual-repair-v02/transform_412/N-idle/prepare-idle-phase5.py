from pathlib import Path
import sys,json,hashlib
import numpy as np
from PIL import Image
from scipy import ndimage
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-visual-repair-20261024')
sys.path.insert(0,str(r/'tools'));import pr122_reviewed_source_regions as guard
src=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/transform_412-N-idle-draft-v01.png'
generated=Path('/workspace/generated_images/exec-adef8437-3361-475f-a2de-1cfb0edbc5a8.png')
rgba=np.asarray(Image.open(src).convert('RGBA'));alpha=rgba[:,:,3];labels,_=ndimage.label(alpha>100);areas=np.bincount(labels.ravel());boxes=ndimage.find_objects(labels);seeds=[None]*6
for label in np.flatnonzero(areas[1:]>=200)+1:
    ys,xs=boxes[label-1];sy,sx=np.argwhere(labels==label)[0];slot=((ys.start+ys.stop)//2//512)*3+(xs.start+xs.stop)//2//512
    assert slot<6 and seeds[slot] is None;seeds[slot]=dict(region=[int(sx),int(sy),1,1],phase=slot,body_label=int(label))
foreground,proof=guard._foreground_owners(alpha,seeds)
comp,count=ndimage.label(alpha>0,np.ones((3,3)));bits=np.zeros(count+1,np.uint8);active=alpha>16;np.bitwise_or.at(bits,comp[active],np.left_shift(np.uint8(1),foreground[active]));bycomp=np.full(count+1,255,np.uint8)
for i in range(6):bycomp[bits==(1<<i)]=i
owners=bycomp[comp];owners[active]=foreground[active]
# Assign only low-alpha pixels with the original unchanged owner-margin rule.
soft=(alpha>0)&(alpha<=16)&(owners==255);ys,xs=np.where(soft);distances=np.array([ndimage.distance_transform_edt(~((foreground==i)&active))[ys,xs] for i in range(6)])
ordered=np.sort(distances,axis=0);confident=ordered[1]-ordered[0]>guard.MINIMUM_OWNER_MARGIN;owners[ys[confident],xs[confident]]=np.argmin(distances[:,confident],axis=0)
assert not np.any((alpha>16)&(owners==255))
new=Image.open(generated).convert('RGBA');na=np.asarray(new)[:,:,3];nl,_=ndimage.label(na>100);ns=np.bincount(nl.ravel());assert np.count_nonzero(ns[1:]>=200)==1
ny,nx=np.where(na>100);strong_height=int(ny.max()-ny.min()+1);bbox=new.getbbox();crop=new.crop(bbox)
oy,ox=np.where(labels==seeds[5]['body_label']);target_height=int(oy.max()-oy.min()+1)
scale=target_height/strong_height
size=(round(crop.width*scale),round(crop.height*scale))
# A newly generated HD frame is normalized once to the existing native sprite
# resolution. Existing five phases are never resampled or rerendered.
normalized=crop.convert('RGBa').resize(size,Image.Resampling.LANCZOS).convert('RGBA')
nda=np.asarray(normalized)[:,:,3];ys,xs=np.where(nda>100);normalized_height=int(ys.max()-ys.min()+1)
assert abs(normalized_height-target_height)/target_height<0.06,'Native body-size match failed; keep HOLD'
assert max(size)<=704,'Preserve native scale and full alpha; require larger cell rather than clipping'
cell=768
composed=np.zeros((cell*2,cell*3,4),np.uint8)
for i in range(5):
    ys,xs=np.where((owners==i)&(alpha>0));dx=(cell-512)//2+(cell-512)*(i%3);dy=(cell-512)//2+(cell-512)*(i//3)
    composed[ys+dy,xs+dx]=rgba[ys,xs]
    assert np.array_equal(composed[ys+dy,xs+dx],rgba[ys,xs]),'Existing phase changed'
x=cell*2+(cell-size[0])//2;y=cell+(cell-size[1])//2;paste=np.asarray(normalized);visible=paste[:,:,3]>0
assert not np.any((composed[y:y+size[1],x:x+size[0],3]>0)&visible),'New pose overlaps another original pose'
composed[y:y+size[1],x:x+size[0]][visible]=paste[visible]
dest=s/'412-N-idle-five-original-one-repaired.png';Image.fromarray(composed).save(dest)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
proof=dict(original_source=str(src.relative_to(r)),original_sha256=sha(src),new_HD_frame=str(generated),new_HD_sha256=sha(generated),HD_size=list(new.size),HD_crop_bbox=list(bbox),normalization='premultiplied-alpha LANCZOS once, newly generated phase5 only',normalized_size=list(size),old_strong_height=target_height,new_strong_height=normalized_height,scale=scale,phase5_translation=[x,y],source_cell=cell,unchanged_original_phases=[0,1,2,3,4],existing_phases_exact_RGBA=True,newly_authored_frames=1,output_sha256=sha(dest),original_source_deleted=False,original_phase5_and_unclassified_soft_source_retained_in_original_PNG=True)
(s/'idle-phase5-normalization-proof.json').write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps(dict(original_phases_preserved=5,newly_authored_frames=1,old_height=target_height,new_height=normalized_height,output=str(dest))))
