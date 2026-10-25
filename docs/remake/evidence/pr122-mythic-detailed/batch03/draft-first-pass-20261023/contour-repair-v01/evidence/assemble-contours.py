import sys,json,hashlib,shutil,argparse
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-contour-repair-20261023');sys.path.insert(0,str(r/'tools'))
import pr122_reviewed_source_regions as guard
import assemble_pr122_reviewed_poses as asm
import import_original_based_motion as imp
import pr122_reviewed_runtime_layout as runtime
out=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/contour-repair-v01';out.mkdir(exist_ok=True)
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
parser=argparse.ArgumentParser();parser.add_argument('--limit',type=int,default=2);args=parser.parse_args()
queue=json.loads((r/'docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json').read_text());order={x['id']:i for i,x in enumerate(queue)}
rows=sorted([x for x in json.loads((s/'material-preflight.json').read_text()) if x['status'].startswith('CONTOUR_MATERIALS_PASS')],key=lambda x:(order[x['key']],x['direction'],x['role']))
new=0;results=[]
for row in rows:
 key,direction,role=row['key'],row['direction'],row['role'];folder=out/key.replace(':','_')/(direction+'-'+role);receipt=folder/'result.json'
 if receipt.exists():results.append(json.loads(receipt.read_text()));continue
 if new>=args.limit:continue
 new+=1;folder.mkdir(parents=True,exist_ok=True);parts=folder/'parts';parts.mkdir(exist_ok=True)
 result=dict(key=key,direction=direction,role=role,original_source=row['source'],original_source_sha256=row['source_sha256'],final_quality_approval=0)
 try:
  src=r/row['source'];assert sha(src)==row['source_sha256'];rgba=np.asarray(Image.open(src).convert('RGBA'));alpha=rgba[:,:,3];foreground,op=guard._foreground_owners(alpha,row['seeds']);assert op==row['ownership_proof']
  comp,count=ndimage.label(alpha>0,np.ones((3,3)));owners_by_comp=np.full(count+1,255,np.uint8);bits=np.zeros(count+1,np.uint8);active=alpha>16;np.bitwise_or.at(bits,comp[active],np.left_shift(np.uint8(1),foreground[active]));assert not np.any((bits!=0)&((bits&(bits-1))!=0))
  for i in range(6):owners_by_comp[bits==(1<<i)]=i
  owners=owners_by_comp[comp];assert hashlib.sha256(owners.tobytes()).hexdigest()==row['material_owner_sha256']
  materials={f'phase_{i}':np.where(((owners==i)&(alpha>0))[:,:,None],rgba,0).astype(np.uint8) for i in range(6)};materials['unclassified_soft_residue']=np.where(((owners==255)&(alpha>0))[:,:,None],rgba,0).astype(np.uint8)
  exact=guard.require_native_source_part_ownership(rgba,materials);assert exact==row['source_RGBA_ownership'];poses=[];source_parts=[];source_rects=[]
  for name,material in materials.items():
   p=parts/(name+'.png');assert not p.exists();Image.fromarray(material).save(p);assert np.array_equal(np.asarray(Image.open(p)),material);source_parts.append(dict(name=name,path=str(p.relative_to(r)),sha256=sha(p)))
   if name=='unclassified_soft_residue':continue
   i=int(name.split('_')[1]);ys,xs=np.where(material[:,:,3]>0);x,y,x1,y1=int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1;rect=[x,y,x1-x,y1-y];source_rects.append(rect)
   poses.append(dict(path='parts/'+name+'.png',source_sha256=sha(p),region=rect,rgba_sha256=asm._rgba_sha(Image.open(p).crop((x,y,x1,y1))),source_pose=i,newly_authored=False,review_basis='Exact source-alpha contour material. Original positions/RGBA retained, all alpha>16 parts topology-owned with unchanged >32 margin. Complete original RGBA storage ownership includes separate unclassified alpha<=16 residue; visual approval remains HOLD.'))
  manifest=dict(source=row['source'],source_sha256=row['source_sha256'],body_seeds=row['seeds'],foreground_ownership_proof=op,RGBA_ownership=exact,parts=source_parts,unclassified_soft_residue_pixels=row['unclassified_soft_residue_pixels'],unclassified_soft_residue_max_alpha=row['unclassified_soft_residue_max_alpha'],residue_status='PRESERVED_SEPARATE_NOT_RENDERED_FINAL_REVIEW_HOLD',motion='Original whole-pose coordinates retained; contour extraction and rigid translation only',no_resampling=True)
  write(folder/'material-manifest.json',manifest);spec=dict(schema=asm.SCHEMA,key=key,role=role,direction=direction,poses=poses);write(folder/'pose-map.json',spec);atlas=folder/'poses.png';assembly_error=None
  try:proof=asm.assemble_pose_map(folder/'pose-map.json',atlas)
  except ValueError as e:
   if not atlas.is_file():raise
   assembly_error=str(e);proof=None
  canonical=imp.analyze(atlas,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid2',canvas_size=2048,directions=[direction]);atlas_rgba=np.asarray(Image.open(atlas));owners16,ownerproof=guard._foreground_owners(atlas_rgba[:,:,3],canonical['frames']);rects=[];translations=[]
  for i,(rect,f) in enumerate(zip(source_rects,canonical['frames'])):
   sx,sy,w,h=rect;dx=i%2*1280+(1280-w)//2;dy=i//2*1280+(1280-h)//2;translations.append([dx-sx,dy-sy]);x,y,fw,fh=f['region'];x0,y0,x1,y1=min(x,dx),min(y,dy),max(x+fw,dx+w),max(y+fh,dy+h);rects.append([x0,y0,x1-x0,y1-y0])
  review=dict(status=guard.STATUS,source_sha256=sha(atlas),base_geometry_sha256=guard._digest(canonical),direction=direction,review_basis='Expanded exact source-contour material output rectangles preserve every selected nonzero-alpha RGBA texel; old importer and ownership gates unchanged',regions=rects,nearest_owner_sha256=ownerproof['nearest_owner_sha256'])
  geometry,region_proof=guard.apply_reviewed_regions(atlas,canonical,review);coverage=np.zeros(atlas_rgba.shape[:2],np.uint8)
  for x,y,w,h in rects:coverage[y:y+h,x:x+w]+=1
  assert not np.any((atlas_rgba[:,:,3]>0)&(coverage!=1))
  if proof is None:proof=asm.finalize_preserved_pose_map(folder/'pose-map.json',atlas,review)
  boxes=[(x-512*(i%3),y-512*(i//3),x+w-512*(i%3),y+h-512*(i//3)) for i,(x,y,w,h) in enumerate(source_rects)];left=max(q[0] for q in boxes);top=max(q[1] for q in boxes);right=min(q[2] for q in boxes);bottom=min(q[3] for q in boxes);assert left<right and top<bottom,'No common source-artboard anchor';cx=max(left,min(256,right-1));cy=bottom-1;anchors=[[512*(i%3)+cx+dx,512*(i//3)+cy+dy] for i,(dx,dy) in enumerate(translations)]
  layout=dict(status='REVIEWED_LAYOUT_PROPOSAL',source_sha256=sha(atlas),direction=direction,canvas_size=1024,source_anchors=anchors,review_basis='Original source artboard anchor mapped through exact per-pose contour translation. Preserve full selected RGBA and authored relative motion; anatomy/size/soft residual final quality HOLD.')
  derived,_=runtime.apply_reviewed_layout(atlas,geometry,layout,source_region_review=review)
  write(atlas.with_suffix('.geometry.json'),geometry);write(folder/'source-region-review.json',review);write(folder/'runtime-layout.json',layout);write(folder/'source-region-proof.json',region_proof)
  result.update(status='CONTOUR_ASSEMBLY_GEOMETRY_PASS_VISUAL_HOLD',source=str(atlas.relative_to(r)),sha256=sha(atlas),material_manifest=str((folder/'material-manifest.json').relative_to(r)),source_region_review=str((folder/'source-region-review.json').relative_to(r)),source_region_proof=str((folder/'source-region-proof.json').relative_to(r)),runtime_layout=str((folder/'runtime-layout.json').relative_to(r)),original_RGBA_ownership=exact,rendered_contour_nonzero_coverage='exactly_once',unclassified_soft_residue_pixels=row['unclassified_soft_residue_pixels'],unclassified_soft_residue_max_alpha=row['unclassified_soft_residue_max_alpha'],assembly_source_png_unchanged=True,frames_regenerated=0)
 except (ValueError,AssertionError) as e:result.update(status='HOLD',cause=str(e))
 write(receipt,result);results.append(result)
write(s/'contour-assembly-results.json',results);print(json.dumps({'new_processed':new,'results':len(results),'pass':sum(x['status'].startswith('CONTOUR_ASSEMBLY_GEOMETRY_PASS') for x in results),'holds':sum(x['status']=='HOLD' for x in results)}))
