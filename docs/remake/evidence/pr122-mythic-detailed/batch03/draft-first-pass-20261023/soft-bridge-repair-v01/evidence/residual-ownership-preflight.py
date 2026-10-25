import sys,json,hashlib,collections
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-residual-ownership-20261023');sys.path.insert(0,str(r/'tools'));import pr122_reviewed_source_regions as guard
rows=[dict(x,source_sha256=x['sha256']) for x in json.loads((r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/contour-repair-v01/remaining-errors.json').read_text())['source_holds'] if 'outside pose regions' in x.get('geometry_error','') or x.get('geometry_error','').startswith('Each phase_grid3')];results=[]
for row in rows:
 result={k:row[k] for k in ('key','direction','role','source','source_sha256')}
 try:
  p=r/row['source'];assert hashlib.sha256(p.read_bytes()).hexdigest()==row['source_sha256'];rgba=np.asarray(Image.open(p).convert('RGBA'));alpha=rgba[:,:,3];strong,_=ndimage.label(alpha>100);areas=np.bincount(strong.ravel());boxes=ndimage.find_objects(strong);seeds=[None]*6
  for label in np.flatnonzero(areas[1:]>=200)+1:
   ys,xs=boxes[label-1];slot=int((ys.start+ys.stop)/1024)*3+int((xs.start+xs.stop)/1024);sy,sx=np.argwhere(strong==label)[0];assert slot<6 and seeds[slot] is None;seeds[slot]=dict(region=[int(sx),int(sy),1,1],phase=slot,body_label=int(label),body_area=int(areas[label]))
  assert all(x is not None for x in seeds)
  foreground,proof=guard._foreground_owners(alpha,seeds)
  comp,count=ndimage.label(alpha>0,np.ones((3,3)));bits=np.zeros(count+1,np.uint8);active=alpha>16;np.bitwise_or.at(bits,comp[active],np.left_shift(np.uint8(1),foreground[active]));bycomp=np.full(count+1,255,np.uint8)
  for i in range(6):bycomp[bits==(1<<i)]=i
  owners=bycomp[comp];owners[active]=foreground[active]
  multi=(bits!=0)&((bits&(bits-1))!=0);soft=(alpha>0)&(alpha<=16)&multi[comp];ys,xs=np.where(soft);distances=np.empty((6,len(xs)),np.float64)
  for i in range(6):distances[i]=ndimage.distance_transform_edt(~((foreground==i)&active))[ys,xs]
  ordered=np.sort(distances,axis=0);margin=ordered[1]-ordered[0];nearest=np.argmin(distances,axis=0).astype(np.uint8);confident=margin>guard.MINIMUM_OWNER_MARGIN;owners[ys[confident],xs[confident]]=nearest[confident]
  assert np.all(owners[active]<6)
  materials={f'phase_{i}':np.where(((owners==i)&(alpha>0))[:,:,None],rgba,0).astype(np.uint8) for i in range(6)};residual=np.where(((owners==255)&(alpha>0))[:,:,None],rgba,0).astype(np.uint8);materials['unclassified_soft_residue']=residual
  assert not np.any(residual[:,:,3]>16);exact=guard.require_native_source_part_ownership(rgba,materials)
  # Reject any selected contour whose alpha100 physical body has been cut/duplicated.
  for i in range(6):assert np.count_nonzero((strong==seeds[i]['body_label'])&(owners!=i))==0
  result.update(status='CONTOUR_MATERIALS_PASS_FINAL_VISUAL_HOLD',seeds=seeds,ownership_proof=proof,material_owner_sha256=hashlib.sha256(owners.tobytes()).hexdigest(),source_RGBA_ownership=exact,unclassified_soft_residue_pixels=int(np.count_nonzero(residual[:,:,3])),unclassified_soft_residue_max_alpha=int(residual[:,:,3].max()),soft_bridge_pixels=len(xs),soft_bridge_assigned_with_margin_gt32=int(confident.sum()),soft_bridge_unclassified=int((~confident).sum()),source_visual_quality='HOLD: source alpha<=16 ambiguous bridges preserved separately; no foreground thresholds changed')
 except (ValueError,AssertionError) as e:result.update(status='HOLD',cause=str(e))
 results.append(result)
(s/'material-preflight.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(dict(checked=len(results),pass_count=sum(x['status'].startswith('CONTOUR_MATERIALS_PASS') for x in results),causes=dict(collections.Counter(x.get('cause','PASS') for x in results)))))
