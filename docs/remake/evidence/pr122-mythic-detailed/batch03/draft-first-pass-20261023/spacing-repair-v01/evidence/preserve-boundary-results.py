import sys,json,hashlib,shutil,collections
from pathlib import Path
import numpy as np
from PIL import Image
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import import_original_based_motion as imp
import pr122_reviewed_source_regions as regions
s=Path('/workspace/scratch/pr122-spacing-repair-20261023');out=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/spacing-repair-v01/boundary-source-v02';out.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
results=[]
for path in sorted(s.glob('boundary-request-*.result.json')):
 service=json.loads(path.read_text());job=json.loads(Path(service['request']).read_text());key,direction,role=job['key'],job['direction'],job['role'];name=key.replace(':','_')+'-'+direction+'-'+role;receipt=out/(name+'.qc.json')
 if receipt.exists():results.append(json.loads(receipt.read_text()));continue
 for p,pin in job['reference_sha256'].items():assert sha(Path(p))==pin
 result=dict(key=key,direction=direction,role=role,original_source=job['original_source'],original_source_sha256=job['original_source_sha256'],generation_request=job['generation_request'],generation_request_sha256=job['generation_request_sha256'],reference_sha256=job['reference_sha256'],generated_original_path=service['path'],final_approvals_added=0,retried=False,source_visual_quality='NOT_REVIEWED')
 if not service['path']:result.update(status='HOLD_SERVICE_OUTPUT_UNAVAILABLE',cause=service['error']);write(receipt,result);results.append(result);continue
 p=out/(name+'.png');assert not p.exists();shutil.copyfile(service['path'],p);assert sha(p)==sha(Path(service['path']));result.update(source=str(p.relative_to(r)),sha256=sha(p),bytes=p.stat().st_size)
 try:
  im=Image.open(p);assert im.mode=='RGBA' and im.size==(1536,1024),'Source requires exact RGBA1536x1024 six-cell grid'
  geometry=imp.analyze(p,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid3',canvas_size=1024,directions=[direction]);alpha=np.asarray(im)[:,:,3];covered=np.zeros(alpha.shape,np.uint8)
  for f in geometry['frames']:
   x,y,w,h=f['region'];covered[y:y+h,x:x+w]+=1
  if np.any((alpha>16)&(covered!=1)):
   owners,op=regions._foreground_owners(alpha,geometry['frames']);rects=[]
   for i,f in enumerate(geometry['frames']):
    ys,xs=np.where((alpha>16)&(owners==i));x,y,w,h=f['region'];x0,y0,x1,y1=min(x,int(xs.min())),min(y,int(ys.min())),max(x+w,int(xs.max())+1),max(y+h,int(ys.max())+1);rects.append([x0,y0,x1-x0,y1-y0])
   review=dict(status=regions.STATUS,source_sha256=sha(p),base_geometry_sha256=regions._digest(geometry),direction=direction,review_basis='Same source immutable RGBA; include every topology-owned alpha16 fragment using unchanged minimum32 owner margin and disjoint-region gates',regions=rects,nearest_owner_sha256=op['nearest_owner_sha256'],directions_axis='phase_grid3')
   geometry,proof=regions.apply_reviewed_regions(p,geometry,review);result.update(source_region_review=review,source_region_proof=proof)
  imp.require_complete_pose_regions(p,geometry);write(p.with_suffix('.geometry.json'),geometry);result.update(status='STRICT_GEOMETRY_PASS',poses=6,physical_scale_review='REQUIRED_NOT_VISUALLY_APPROVED')
 except (ValueError,AssertionError) as e:result.update(status='HOLD_SOURCE_QC',cause=str(e))
 write(receipt,result);results.append(result)
write(s/'boundary-source-results.json',results);print(json.dumps({'saved':sum('source' in x for x in results),'pass':sum(x['status']=='STRICT_GEOMETRY_PASS' for x in results),'hold':sum(x['status']!='STRICT_GEOMETRY_PASS' for x in results)}))
