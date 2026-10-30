import sys,json,hashlib,copy
from pathlib import Path
import numpy as np
from PIL import Image
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import assemble_pr122_reviewed_poses as asm
import import_original_based_motion as imp
import pr122_reviewed_source_regions as regions
s=Path('/workspace/scratch/pr122-spacing-repair-20261023');out=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/spacing-repair-v01';out.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
results=[]
for item in json.loads((s/'tight-region-preflight.json').read_text()):
 if item['status']!='REVIEWED_CROP_PREFLIGHT_PASS':continue
 key,role,direction=item['key'],item['role'],item['direction'];src=r/item['source'];assert sha(src)==item['source_sha256'];im=Image.open(src).convert('RGBA');poses=[]
 for i,(x,y,w,h) in enumerate(item['regions']):
  poses.append(dict(path=str(src),source_sha256=sha(src),region=[x,y,w,h],rgba_sha256=asm._rgba_sha(im.crop((x,y,x+w,y+h))),source_pose=i,newly_authored=False,review_basis='Unchanged whole physical pose; exact source frame order, six-body, complete alpha16 foreground, no foreign body, no component cuts and detached ownership margin >32 preflight PASS. Low-alpha residuals remain preserved in original source; no final visual approval.'))
 spec=dict(schema=asm.SCHEMA,key=key,role=role,direction=direction,poses=poses)
 folder=out/key.replace(':','_');folder.mkdir(exist_ok=True);prefix=folder/f'{direction}-{role}';specpath=prefix.with_suffix('.pose-map.json');write(specpath,spec);atlas=prefix.with_suffix('.png')
 try:
  try:proof=asm.assemble_pose_map(specpath,atlas)
  except ValueError:
   if not atlas.is_file():raise
   # Finalize this same immutable atlas with an explicit complete-foreground
   # review; do not re-render or overwrite the error receipt/source PNG.
   g=imp.analyze(atlas,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid2',canvas_size=2048,directions=[direction]);alpha=np.asarray(Image.open(atlas))[:,:,3];owners,op=regions._foreground_owners(alpha,g['frames']);rects=[]
   for i,f in enumerate(g['frames']):
    ys,xs=np.where((alpha>16)&(owners==i));x,y,w,h=f['region'];x0,y0,x1,y1=min(x,int(xs.min())),min(y,int(ys.min())),max(x+w,int(xs.max())+1),max(y+h,int(ys.max())+1);rects.append([x0,y0,x1-x0,y1-y0])
   rr=dict(status=regions.STATUS,source_sha256=sha(atlas),base_geometry_sha256=regions._digest(g),direction=direction,review_basis='Explicit topology-owned full alpha16 regions on the same immutable spaced atlas; importer and ownership thresholds unchanged',regions=rects,nearest_owner_sha256=op['nearest_owner_sha256'])
   write(prefix.with_suffix('.output-region-review.json'),rr);proof=asm.finalize_preserved_pose_map(specpath,atlas,rr)
  results.append(dict(key=key,direction=direction,role=role,status='ASSEMBLED_STRICT_PASS',source=str(atlas.relative_to(r)),source_sha256=sha(atlas),original_source=item['source'],original_source_sha256=item['source_sha256'],pose_map=str(specpath.relative_to(r)),pose_map_sha256=sha(specpath),low_alpha_residual_pixels=item['low_alpha_residual_pixels'],low_alpha_residual_max=item['low_alpha_residual_max'],pixels_modified=False,source_assembly_proof=str(atlas.with_suffix('.assembly.json').relative_to(r))))
 except ValueError as e:results.append(dict(key=key,direction=direction,role=role,status='HOLD',cause=str(e),original_source=item['source']))
write(s/'assembly-results.json',results);print(json.dumps([{'key':x['key'],'role':x['role'],'status':x['status']} for x in results]))
