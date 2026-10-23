import sys,json,hashlib,shutil
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage

r=Path('/workspace/twilight')
s=Path('/workspace/scratch/pr122-visual-repair-20261024')
out=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/visual-repair-v01'
sys.path.insert(0,str(r/'tools'))
import pr122_reviewed_source_regions as guard
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
queue=json.loads((s/'repair-inputs.json').read_text())
results=[]
for item in queue:
    folder=out/item['key'].replace(':','_')/(item['direction']+'-'+item['role'])
    folder.mkdir(parents=True,exist_ok=True)
    src=folder/'source-v02.png'
    if not src.exists(): shutil.copyfile(item['generated_path'],src)
    assert sha(src)==sha(Path(item['generated_path']))
    rgba=np.asarray(Image.open(src).convert('RGBA'));alpha=rgba[:,:,3]
    labels,_=ndimage.label(alpha>100);areas=np.bincount(labels.ravel());boxes=ndimage.find_objects(labels)
    bodies=np.flatnonzero(areas[1:]>=200)+1
    assert len(bodies)==6,'Exactly six unchanged physical-body rules required'
    seeds=[None]*6
    for label in bodies:
        ys,xs=boxes[label-1];slot=((ys.start+ys.stop)//2//512)*3+(xs.start+xs.stop)//2//512
        sy,sx=np.argwhere(labels==label)[0]
        assert slot<6 and seeds[slot] is None
        seeds[slot]=dict(region=[int(sx),int(sy),1,1],phase=slot,body_label=int(label),body_area=int(areas[label]))
    foreground,proof=guard._foreground_owners(alpha,seeds)
    comp,count=ndimage.label(alpha>0,np.ones((3,3)));bits=np.zeros(count+1,np.uint8);active=alpha>16
    np.bitwise_or.at(bits,comp[active],np.left_shift(np.uint8(1),foreground[active]));bycomp=np.full(count+1,255,np.uint8)
    for i in range(6):bycomp[bits==(1<<i)]=i
    owners=bycomp[comp];owners[active]=foreground[active]
    multi=(bits!=0)&((bits&(bits-1))!=0);soft=(alpha>0)&(alpha<=16)&multi[comp];ys,xs=np.where(soft)
    distances=np.empty((6,len(xs)),np.float64)
    for i in range(6):distances[i]=ndimage.distance_transform_edt(~((foreground==i)&active))[ys,xs]
    ordered=np.sort(distances,axis=0);margin=ordered[1]-ordered[0];nearest=np.argmin(distances,axis=0).astype(np.uint8);confident=margin>guard.MINIMUM_OWNER_MARGIN
    owners[ys[confident],xs[confident]]=nearest[confident]
    assert np.all(owners[active]<6)
    materials={f'phase_{i}':np.where(((owners==i)&(alpha>0))[:,:,None],rgba,0).astype(np.uint8) for i in range(6)}
    residue=np.where(((owners==255)&(alpha>0))[:,:,None],rgba,0).astype(np.uint8);materials['unclassified_soft_residue']=residue
    assert not np.any(residue[:,:,3]>16)
    exact=guard.require_native_source_part_ownership(rgba,materials)
    original=r/item['previous_source']
    original_record=json.loads(original.with_suffix('.json').read_text())
    record=dict(key=item['key'],direction=item['direction'],role=item['role'],source=str(src.relative_to(r)),source_sha256=sha(src),previous_source=item['previous_source'],previous_source_sha256=sha(original),reference=original_record['reference'],reference_sha256=original_record['reference_sha256'],generation_request=item['request'],generation_service='image_gen.imagegen',newly_authored_frames=item['newly_authored_frames'],source_visual_review=item['visual_review'],final_approval=False,previous_source_preserved=True)
    write(src.with_suffix('.json'),record)
    result=dict(key=item['key'],direction=item['direction'],role=item['role'],source=str(src.relative_to(r)),source_sha256=sha(src),status='CONTOUR_MATERIALS_PASS_FINAL_VISUAL_HOLD',seeds=seeds,ownership_proof=proof,material_owner_sha256=hashlib.sha256(owners.tobytes()).hexdigest(),source_RGBA_ownership=exact,unclassified_soft_residue_pixels=int(np.count_nonzero(residue[:,:,3])),unclassified_soft_residue_max_alpha=int(residue[:,:,3].max()),soft_bridge_pixels=len(xs),soft_bridge_assigned_with_margin_gt32=int(confident.sum()),soft_bridge_unclassified=int((~confident).sum()))
    results.append(result)
write(s/'material-preflight.json',results)
code=Path('/workspace/scratch/pr122-soft-bridge-repair-20261023/assemble-contours.py').read_text().replace("s=Path('/workspace/scratch/pr122-soft-bridge-repair-20261023')", "s=Path('/workspace/scratch/pr122-visual-repair-20261024')").replace("draft-first-pass-20261023/soft-bridge-repair-v01", "draft-first-pass-20261023/visual-repair-v01")
(s/'assemble-contours.py').write_text(code)
print(json.dumps(dict(checked=len(results),ownership_pass=len(results),missing_RGBA=sum(x['source_RGBA_ownership']['missing'] for x in results),duplicate_RGBA=sum(x['source_RGBA_ownership']['duplicate'] for x in results))))
