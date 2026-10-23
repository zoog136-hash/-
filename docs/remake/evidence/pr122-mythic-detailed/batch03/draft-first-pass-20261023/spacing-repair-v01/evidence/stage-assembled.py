import sys,json,hashlib,copy,subprocess
from pathlib import Path
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import stage_pr122_native_locomotion as stage
import bind_pr122_native_locomotion_profiles as binder
s=Path('/workspace/scratch/pr122-spacing-repair-20261023');mp=r/stage.SOURCE_MANIFEST;m=json.loads(mp.read_text());oldreg=json.loads((r/stage.REGISTER).read_text());fresh={};changes=[];add=[]
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for result in json.loads((s/'assembly-results.json').read_text()):
 if result['status']!='ASSEMBLED_STRICT_PASS':continue
 key,direction,role=result['key'],result['direction'],result['role'];source=result['source'];p=r/source;proof=json.loads((r/result['source_assembly_proof']).read_text());g=proof['geometry'];assert proof['preserved_region_rgba_exact'] and not proof['resampled'];anchors=[];rects=[]
 for i,pose in enumerate(proof['poses']):
  x,y,w,h=pose['source_region'];rects.append((x-512*(i%3),y-512*(i//3),x+w-512*(i%3),y+h-512*(i//3)))
 left=max(q[0] for q in rects);top=max(q[1] for q in rects);right=min(q[2] for q in rects);bottom=min(q[3] for q in rects);assert left<right and top<bottom;cx=max(left,min(256,right-1));cy=bottom-1
 for i,pose in enumerate(proof['poses']):
  dx,dy=pose['translation'];anchors.append([512*(i%3)+cx+dx,512*(i//3)+cy+dy])
 layout=dict(status='REVIEWED_LAYOUT_PROPOSAL',source_sha256=sha(p),direction=direction,canvas_size=1024,source_anchors=anchors,review_basis='Existing reviewed-pose assembler: source physical bodies/whole alpha16 foreground validated, exact crop RGBA retained, no resampling, translation pinned. Map the same source artboard root through each exact assembly translation. Physical scale, anatomy and final visual quality NOT_REVIEWED.')
 rr=proof.get('source_region_review');derived,_=stage.reviewed_layout.apply_reviewed_layout(p,g,layout,source_region_review=rr)
 write(p.with_suffix('.geometry.json'),g)
 rec=dict(key=key,direction=direction,role=role,version='spacing-repair-v01',source=source,sha256=sha(p),bytes=p.stat().st_size,requested_poses=6,geometry=dict(status='GEOMETRY_PASS',frames=6,distinct_pixel_frames=6,canvas=2048),source_canvas_review=dict(status='REVIEWED_SOURCE_CANVAS_PROPOSAL',source_sha256=sha(p),canvas_size=2048,review_basis='Existing exact reviewed-pose assembly uses 2048 canonical virtual canvas; game layout retains 1024 reference without raster resampling. Technical proposal only.'),original_source=result['original_source'],original_source_sha256=result['original_source_sha256'],source_assembly_proof=result['source_assembly_proof'],source_assembly_proof_sha256=sha(r/result['source_assembly_proof']),unselected_original_alpha_le16_pixels=result['low_alpha_residual_pixels'],low_alpha_residual_preserved_in_original_source=True,visual_quality='NOT_REVIEWED',production_connected=False,detailed_completed=False)
 if rr:rec.update(source_region_review=rr,source_region_proof=proof['source_region_proof'])
 m['raw_images'].append(rec);m['selected_locomotion_sheets' if role=='run' else 'selected_detailed_action_sheets'][f'{key}:{direction}:{role}']=source;m['reviewed_runtime_layouts'][source]=layout;fresh.setdefault(key,{})[source]=stage.preserved_source_analysis(r,rec,g);changes.append(result);add.extend([source,str(p.with_suffix('.geometry.json').relative_to(r))])
write(mp,m);subprocess.run(['git','add','-f','--',*add],cwd=r,check=True,stdout=subprocess.DEVNULL)
for key in sorted(fresh):
 previous={t['animation']:t for t in oldreg['actors'][key]['tracks']};stage.stage(r,key,'native005',analyzed_sources=fresh[key]);entry=json.loads((r/stage.REGISTER).read_text())['actors'][key]
 for t in entry['tracks']:
  if t['animation'] in previous:assert all(t[f]==previous[t['animation']][f] for f in ('source','source_sha256','texture','geometry'))
 binder.bind(r,key)
write(s/'assembled-staging-summary.json',dict(repaired=changes,keys=sorted(fresh),clips_added=len(changes),old_normal_clips_preserved=True,final_approval_added=0))
print('STAGED_ASSEMBLY_REPAIRS',len(changes))
