from pathlib import Path
import sys,json,hashlib
import numpy as np
from PIL import Image
from scipy import ndimage
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-visual-repair2-20261024')
sys.path.insert(0,str(r/'tools'));import pr122_reviewed_source_regions as guard
p=Path('/workspace/generated_images/exec-63204b2d-9a82-4cdb-b5fa-8a81f2773bef.png');rgba=np.asarray(Image.open(p).convert('RGBA'));a=rgba[:,:,3]
assert rgba.shape==(1024,1536,4) and tuple(rgba[569,342])==(114,160,140,17)
labels,_=ndimage.label(a>100);areas=np.bincount(labels.ravel());boxes=ndimage.find_objects(labels);bodies=[None]*6
for b in np.flatnonzero(areas[1:]>=200)+1:
    ys,xs=boxes[b-1];slot=((ys.start+ys.stop)//2//512)*3+(xs.start+xs.stop)//2//512
    assert slot<6 and bodies[slot] is None;bodies[slot]=int(b)
assert all(b is not None for b in bodies) and np.count_nonzero(areas[1:]>=200)==6
components,count=ndimage.label(a>16,np.ones((3,3)));component_owner=np.full(count+1,255,np.uint8)
for i,b in enumerate(bodies):
    ids=np.unique(components[labels==b]);assert len(ids)==1 and ids[0]>0 and component_owner[ids[0]]==255;component_owner[ids[0]]=i
detached=(components>0)&(component_owner[components]==255);ys,xs=np.where(detached);dist=np.array([ndimage.distance_transform_edt(labels!=b)[ys,xs] for b in bodies]);nearest=np.argmin(dist,axis=0);ordered=np.sort(dist,axis=0);proof=[]
reviewed_component=int(components[569,342]);assert np.count_nonzero(components==reviewed_component)==1
for c in np.unique(components[ys,xs]):
    chosen=components[ys,xs]==c
    if c==reviewed_component:
        component_owner[c]=3;proof.append(dict(bbox=[342,569,1,1],RGBA=[114,160,140,17],owner_phase=3,status='EXPLICIT_INTERNAL_VISUAL_COMPONENT_BINDING',basis='Reviewed context crop shows faint turquoise trail at the top of bottom-left phase3; this is one alpha17 effect texel, no anatomy or equipment. Its entire exact RGBA is retained once. Automatic nearest assignment remains HOLD on the unspaced source.'))
    else:
        assert len(np.unique(nearest[chosen]))==1 and np.all(ordered[1,chosen]-ordered[0,chosen]>guard.MINIMUM_OWNER_MARGIN)
        component_owner[c]=nearest[chosen][0]
foreground=component_owner[components];active=a>16;assert np.all(foreground[active]<6)
soft_comp,n=ndimage.label(a>0,np.ones((3,3)));bits=np.zeros(n+1,np.uint8);np.bitwise_or.at(bits,soft_comp[active],np.left_shift(np.uint8(1),foreground[active]));bycomp=np.full(n+1,255,np.uint8)
for i in range(6):bycomp[bits==(1<<i)]=i
owners=bycomp[soft_comp];owners[active]=foreground[active];soft=(a>0)&(a<=16)&(owners==255);ys,xs=np.where(soft);dist=np.array([ndimage.distance_transform_edt(~((foreground==i)&active))[ys,xs] for i in range(6)]);sort=np.sort(dist,axis=0);ok=sort[1]-sort[0]>guard.MINIMUM_OWNER_MARGIN;owners[ys[ok],xs[ok]]=np.argmin(dist[:,ok],axis=0)
materials={f'phase_{i}':np.where(((owners==i)&(a>0))[:,:,None],rgba,0).astype(np.uint8) for i in range(6)};materials['unclassified_soft_residue']=np.where(((owners==255)&(a>0))[:,:,None],rgba,0).astype(np.uint8)
assert not np.any(materials['unclassified_soft_residue'][:,:,3]>16)
exact=guard.require_native_source_part_ownership(rgba,materials)
canvas=np.zeros((1536,2304,4),np.uint8)
for i in range(6):
    ys,xs=np.where(materials[f'phase_{i}'][:,:,3]>0);dx=128+256*(i%3);dy=128+256*(i//3)
    assert np.all((xs+dx>=768*(i%3))&(xs+dx<768*(i%3+1))&(ys+dy>=768*(i//3))&(ys+dy<768*(i//3+1)))
    assert not np.any(canvas[ys+dy,xs+dx,3]);canvas[ys+dy,xs+dx]=rgba[ys,xs];assert np.array_equal(canvas[ys+dy,xs+dx],rgba[ys,xs])
dest=s/'412-S-attack-reviewed-contour-spacing.png';Image.fromarray(canvas).save(dest)
Image.fromarray(materials['unclassified_soft_residue']).save(s/'412-S-attack-original-soft-residue.png')
receipt=dict(source=str(p),source_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),explicit_bindings=proof,original_RGBA_ownership=exact,source_cell_before=512,source_cell_after=768,no_source_pixel_resampling=True,discarded_foreground_pixels=0,unclassified_soft_pixels_preserved_separately=int(np.count_nonzero(materials['unclassified_soft_residue'][:,:,3])),output_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),checker_implementation_or_threshold_changes=0,final_approval=False)
(s/'S-attack-reviewed-contour-spacing-proof.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(dict(status='EXACT_RGBA_CONTOUR_SPACING_PASS',explicit_reviewed_foreground_texels=1,missing=exact['missing'],duplicate=exact['duplicate'])))
