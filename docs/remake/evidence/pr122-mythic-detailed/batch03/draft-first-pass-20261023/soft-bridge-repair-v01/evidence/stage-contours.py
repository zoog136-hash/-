import sys,json,hashlib,copy,shutil,subprocess,collections
from pathlib import Path
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-soft-bridge-repair-20261023');sys.path.insert(0,str(r/'tools'))
import stage_pr122_native_locomotion as stage
import bind_pr122_native_locomotion_profiles as binder
out=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/soft-bridge-repair-v01';ev=out/'evidence';ev.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
rows=[x for x in json.loads((s/'contour-assembly-results.json').read_text()) if x['status'].startswith('CONTOUR_ASSEMBLY_GEOMETRY_PASS')];assert len(rows)==27; m=json.loads((r/stage.SOURCE_MANIFEST).read_text());previous=json.loads((r/stage.REGISTER).read_text());keys=sorted({x['key'] for x in rows});reuse={k:stage.capture_geometry_reuse(r,k) for k in keys};fresh=collections.defaultdict(dict);paths=[]
code=ev/'assemble-contours.py';assert not code.exists();shutil.copyfile(s/'assemble-contours.py',code)
for item in rows:
 key,direction,role=item['key'],item['direction'],item['role'];p=r/item['source'];assert sha(p)==item['sha256'];g=json.loads(p.with_suffix('.geometry.json').read_text());manifest=json.loads((r/item['material_manifest']).read_text());review=json.loads((r/item['source_region_review']).read_text());proof=json.loads((r/item['source_region_proof']).read_text());layout=json.loads((r/item['runtime_layout']).read_text())
 dependencies=[dict(path=str(p.with_name('pose-map.json').relative_to(r)),sha256=sha(p.with_name('pose-map.json'))),dict(path=str(p.with_suffix('.assembly.json').relative_to(r)),sha256=sha(p.with_suffix('.assembly.json'))),dict(path=str((r/item['original_source']).with_suffix('.json').relative_to(r)),sha256=sha((r/item['original_source']).with_suffix('.json'))),dict(path=item['original_source'],sha256=item['original_source_sha256']),dict(path=item['material_manifest'],sha256=sha(r/item['material_manifest'])),dict(path=str(code.relative_to(r)),sha256=sha(code))]+[dict(path=x['path'],sha256=x['sha256']) for x in manifest['parts']]
 for dep in dependencies:assert sha(r/dep['path'])==dep['sha256']
 record=dict(key=key,direction=direction,role=role,version='source-alpha-soft-bridge-v01',source=item['source'],sha256=sha(p),bytes=p.stat().st_size,requested_poses=6,geometry=dict(status='GEOMETRY_PASS',frames=6,distinct_pixel_frames=6,canvas=2048),source_region_review=review,source_region_proof=proof,source_canvas_review=dict(status='REVIEWED_SOURCE_CANVAS_PROPOSAL',source_sha256=sha(p),canvas_size=2048,review_basis='Exact contour materials through existing reviewed-pose assembler, canonical2048/game1024, no source-raster scaling'),original_source=item['original_source'],original_source_sha256=item['original_source_sha256'],authoring_dependencies=dependencies,source_material_RGBA_ownership=item['original_RGBA_ownership'],rendered_contour_nonzero_coverage='exactly_once',unclassified_soft_residue_pixels=item['unclassified_soft_residue_pixels'],unclassified_soft_residue_max_alpha=item['unclassified_soft_residue_max_alpha'],residue_status='SEPARATE_SOURCE_LAYER_HOLD_NOT_RENDERED',source_visual_quality='NOT_REVIEWED',production_connected=False,detailed_completed=False)
 m['raw_images'].append(record);m['selected_locomotion_sheets' if role=='run' else 'selected_detailed_action_sheets'][f'{key}:{direction}:{role}']=item['source'];m['reviewed_runtime_layouts'][item['source']]=layout;fresh[key][item['source']]=stage.preserved_source_analysis(r,record,g);paths.extend([item['source'],str(p.with_suffix('.geometry.json').relative_to(r))])
m['selected_locomotion_native_poses']=len(m['selected_locomotion_sheets'])*6;m['selected_detailed_action_native_poses']=len(m['selected_detailed_action_sheets'])*6;write(r/stage.SOURCE_MANIFEST,m);subprocess.run(['git','add','-f','--',*paths],cwd=r,check=True,stdout=subprocess.DEVNULL)
results=[]
for key in keys:
 before={x['animation']:x for x in previous['actors'].get(key,{}).get('tracks',[])};stage.stage(r,key,'native007',reuse_context=reuse[key],analyzed_sources=fresh[key]);entry=json.loads((r/stage.REGISTER).read_text())['actors'][key];kept=0
 for track in entry['tracks']:
  if track['animation'] in before:assert all(track[f]==before[track['animation']][f] for f in ('source','source_sha256','texture','geometry'));kept+=1
 if any(x['role']=='run' for x in entry['tracks']):binder.bind(r,key)
 results.append(dict(key=key,clips=entry['native_track_count'],prior_clips_preserved=kept,reuse_context_entries=len((reuse[key] or {}).get('entries',{})),added_contour_clips=len(fresh[key])))
reg=json.loads((r/stage.REGISTER).read_text())
for k,old in previous['actors'].items():
 if k not in keys:assert reg['actors'][k]==old
write(s/'staging-summary.json',dict(keys=keys,actors=results,added_contour_clips=len(rows),old_source_tracks_preserved=True,final_approvals_added=0));print(json.dumps({'actors':len(keys),'new_contour_clips':len(rows),'reusable_prior_tracks':sum(x['reuse_context_entries'] for x in results)}))
