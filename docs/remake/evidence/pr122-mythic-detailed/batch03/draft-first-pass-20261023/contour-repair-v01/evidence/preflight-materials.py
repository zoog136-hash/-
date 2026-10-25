import sys,json,hashlib,collections
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-contour-repair-20261023');sys.path.insert(0,str(r/'tools'))
import pr122_reviewed_source_regions as guard
rows=json.loads((s/'exact-contour-preflight.json').read_text());results=[]
for row in rows:
 result={k:row[k] for k in ('key','direction','role','source','source_sha256')}
 try:
  p=r/row['source'];rgba=np.asarray(Image.open(p).convert('RGBA'));alpha=rgba[:,:,3];strong,_=ndimage.label(alpha>100);areas=np.bincount(strong.ravel());boxes=ndimage.find_objects(strong);seeds=[None]*6
  for label in np.flatnonzero(areas[1:]>=200)+1:
   ys,xs=boxes[label-1];slot=int((ys.start+ys.stop)/1024)*3+int((xs.start+xs.stop)/1024);sy,sx=np.argwhere(strong==label)[0];assert seeds[slot] is None;seeds[slot]=dict(region=[int(sx),int(sy),1,1],phase=slot,body_label=int(label),body_area=int(areas[label]))
  foreground,proof=guard._foreground_owners(alpha,seeds)
  components,count=ndimage.label(alpha>0,np.ones((3,3)));material_owners=np.full(count+1,255,np.uint8)
  # A connected original-alpha contour may include its faint AA fringe, but
  # cannot inherit two foreground owners. Unclassified alpha<=16 detached
  # residue is retained as a separate source layer, never guessed or erased.
  active=alpha>16
  assert np.all(foreground[active]<6)
  bits=np.zeros(count+1,np.uint8)
  np.bitwise_or.at(bits,components[active],np.left_shift(np.uint8(1),foreground[active]))
  if np.any((bits!=0)&((bits&(bits-1))!=0)):raise ValueError('Nonzero contour contains multiple physical foreground owners')
  for i in range(6):material_owners[bits==(1<<i)]=i
  owners=material_owners[components]
  if np.any((alpha>16)&(owners>=6)):raise ValueError('Unowned original foreground')
  materials={f'phase_{i}':np.where(((owners==i)&(alpha>0))[:,:,None],rgba,0).astype(np.uint8) for i in range(6)}
  residual=np.where(((owners==255)&(alpha>0))[:,:,None],rgba,0).astype(np.uint8);materials['unclassified_soft_residue']=residual
  assert not np.any(residual[:,:,3]>16)
  exact=guard.require_native_source_part_ownership(rgba,materials)
  result.update(status='CONTOUR_MATERIALS_PASS_FINAL_VISUAL_HOLD',seeds=seeds,ownership_proof=proof,material_owner_sha256=hashlib.sha256(owners.tobytes()).hexdigest(),source_RGBA_ownership=exact,unclassified_soft_residue_pixels=int(np.count_nonzero(residual[:,:,3])),unclassified_soft_residue_max_alpha=int(residual[:,:,3].max()),source_visual_quality='HOLD: unclassified low-alpha source layer remains separate, not a claimed intentional part')
 except (ValueError,AssertionError) as e:result.update(status='HOLD',cause=str(e))
 results.append(result)
(s/'material-preflight.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps({'checked':len(results),'material_pass':sum(x['status'].startswith('CONTOUR_MATERIALS_PASS') for x in results),'causes':dict(collections.Counter(x.get('cause','PASS') for x in results))}))
