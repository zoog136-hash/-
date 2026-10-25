from pathlib import Path
import sys,json,hashlib
import numpy as np
from PIL import Image
from scipy import ndimage
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-NE-native-contour-20261024')
sys.path.insert(0,str(r/'tools'));import pr122_reviewed_source_regions as guard
p=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/transform_412-NE-attack-draft-v01.png';rgba=np.asarray(Image.open(p).convert('RGBA'));a=rgba[:,:,3]
lab,_=ndimage.label(a>100);area=np.bincount(lab.ravel());boxes=ndimage.find_objects(lab);bodies=[None]*6
for k in np.flatnonzero(area[1:]>=200)+1:
    y,x=boxes[k-1];slot=((y.start+y.stop)//2//512)*3+(x.start+x.stop)//2//512
    assert slot<6 and bodies[slot] is None;bodies[slot]=int(k)
assert all(x is not None for x in bodies) and np.count_nonzero(area[1:]>=200)==6
comp,count=ndimage.label(a>16,np.ones((3,3)));bits=np.zeros(count+1,np.uint8)
for i,k in enumerate(bodies):bits[np.unique(comp[lab==k])]|=1<<i
multi=(bits!=0)&((bits&(bits-1))!=0);ids=np.flatnonzero(multi)
assert len(ids)==1 and int(bits[ids[0]])==25,'Only explicitly reviewed phase0/3/4 interpose junction is authorized'
owners=np.full(a.shape,255,np.uint8)
for i in range(6):owners[(a>16)&(bits[comp]==1<<i)]=i
# Native opaque components stay complete and retain their exact original owner.
# The reviewed context shows non-overlapping body/weapon contours, joined by
# the interpose glow. Repartition only that explicitly reviewed connected group.
mask=(a>16)&multi[comp];ys,xs=np.where(mask);allowed=[0,3,4]
dist=np.array([ndimage.distance_transform_edt(lab!=bodies[i])[ys,xs] for i in allowed]);nearest=np.argmin(dist,axis=0)
owners[ys,xs]=np.asarray(allowed,np.uint8)[nearest]
for i,k in enumerate(bodies):
    assert not np.any((lab==k)&(owners!=i)),'Never divide, omit or reassign an original primary body'
detached=(a>16)&(owners==255);ys,xs=np.where(detached)
if len(xs):
    dist=np.array([ndimage.distance_transform_edt(lab!=k)[ys,xs] for k in bodies]);ordered=np.sort(dist,axis=0);nearest=np.argmin(dist,axis=0)
    for c in np.unique(comp[ys,xs]):
        selected=comp[ys,xs]==c
        assert len(np.unique(nearest[selected]))==1 and np.all(ordered[1,selected]-ordered[0,selected]>guard.MINIMUM_OWNER_MARGIN),'Unreviewed detached component stays HOLD'
        owners[ys[selected],xs[selected]]=nearest[selected]
assert np.all(owners[a>16]<6)
soft_comp,n=ndimage.label(a>0,np.ones((3,3)));soft_bits=np.zeros(n+1,np.uint8);active=a>16;np.bitwise_or.at(soft_bits,soft_comp[active],np.left_shift(np.uint8(1),owners[active]));bycomp=np.full(n+1,255,np.uint8)
for i in range(6):bycomp[soft_bits==1<<i]=i
soft=(a>0)&(a<=16);owners[soft]=bycomp[soft_comp[soft]];ys,xs=np.where(soft&(owners==255));dist=np.array([ndimage.distance_transform_edt(~((owners==i)&active))[ys,xs] for i in range(6)]);ordered=np.sort(dist,axis=0);ok=ordered[1]-ordered[0]>guard.MINIMUM_OWNER_MARGIN;owners[ys[ok],xs[ok]]=np.argmin(dist[:,ok],axis=0)
materials={f'phase_{i}':np.where(((owners==i)&(a>0))[:,:,None],rgba,0).astype(np.uint8) for i in range(6)};materials['unclassified_soft_residue']=np.where(((owners==255)&(a>0))[:,:,None],rgba,0).astype(np.uint8);assert not np.any(materials['unclassified_soft_residue'][:,:,3]>16)
exact=guard.require_native_source_part_ownership(rgba,materials);canvas=np.zeros((2048,3072,4),np.uint8);bounds=[]
for i in range(6):
    ys,xs=np.where(materials[f'phase_{i}'][:,:,3]>0);dx=256+512*(i%3);dy=256+512*(i//3)
    assert np.all((xs+dx>=1024*(i%3))&(xs+dx<1024*(i%3+1))&(ys+dy>=1024*(i//3))&(ys+dy<1024*(i//3+1))), 'Use more space, never cut a contour'
    assert not np.any(canvas[ys+dy,xs+dx,3]);canvas[ys+dy,xs+dx]=rgba[ys,xs];assert np.array_equal(canvas[ys+dy,xs+dx],rgba[ys,xs]);bounds.append(dict(phase=i,original_primary_pixels=int(area[bodies[i]]),translation=[dx,dy]))
dest=s/'412-NE-attack-exact-reviewed-contours.png';Image.fromarray(canvas).save(dest);Image.fromarray(materials['unclassified_soft_residue']).save(s/'original-unclassified-soft-residue.png')
proof=dict(source=str(p.relative_to(r)),source_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),automatic_source_ownership_status='HOLD_FOREGROUND_CONNECTS_MULTIPLE_BODIES_NOT_OVERRIDDEN',manual_review='Full source plus junction context: six distinct opaque body/weapon contours. Only the phase0/3/4 interpose glow group is repartitioned by its intact primary contours. No occluded anatomy is painted or inferred.',reviewed_connected_group_body_bits=25,all_six_original_primary_components_retained_exact_and_undivided=True,original_RGBA_ownership=exact,parts=bounds,unclassified_soft_pixels_preserved=int(np.count_nonzero(materials['unclassified_soft_residue'][:,:,3])),source_cell_before=512,source_cell_after=1024,source_resampling=False,checker_code_or_threshold_changes=0,newly_authored_frames=0,final_approval=False,output_sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
(s/'reviewed-native-contour-proof.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps(dict(status='EXACT_RGBA_NATIVE_CONTOURS_SEPARATED',missing=exact['missing'],duplicate=exact['duplicate'],original_primary_body_components_preserved=6,new_art_frames=0)))
