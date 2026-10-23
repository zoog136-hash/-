import sys,json,hashlib,copy,subprocess,collections,contextlib
from pathlib import Path
from PIL import Image
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import stage_pr122_native_locomotion as st
import import_original_based_motion as imp
import bind_pr122_native_locomotion_profiles as binder
out=Path('/workspace/scratch/pr122-batch-review-20261023');base=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/native-reviewed-batch-v01';base.mkdir(exist_ok=True)
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=[json.loads(x) for x in (out/'audit-results.jsonl').read_text().splitlines()];safe=[x for x in rows if not x['errors']]
mp=r/st.SOURCE_MANIFEST;m=json.loads(mp.read_text());old=copy.deepcopy(m)
actors=sorted({x['key'] for x in rows});code=r/'tools/stage_pr122_native_locomotion.py';text=code.read_text();before=st._analysis_versions(r);needle="'transform:412': 'transform_412'}";replacement="'transform:412': 'transform_412',\n          "+', '.join(repr(k)+': '+repr(k.replace(':','_')) for k in actors if k!='transform:412')+'}';assert needle in text;code.write_text(text.replace(needle,replacement,1));assert before==st._analysis_versions(r)
st.ACTORS.update({k:k.replace(':','_') for k in actors})
fresh=collections.defaultdict(dict);tracks=collections.Counter();errors=[];newpaths=[];removed=[]
allowed={(x['key'],x['direction'],x['role']) for x in safe}
# Newly established evidence: retain the old unapproved files but remove unsafe
# first-pass candidates from active selection. Frozen approved actors untouched.
for field in ('selected_locomotion_sheets','selected_detailed_action_sheets'):
 for identity,source in list(m[field].items()):
  if '/native-412/' in source and tuple(identity.rsplit(':',2)) not in allowed:removed.append({'identity':identity,'source':source});del m[field][identity]
for item in safe:
 key,direction,role=item['key'],item['direction'],item['role'];identity=f'{key}:{direction}:{role}';field='selected_locomotion_sheets' if role=='run' else 'selected_detailed_action_sheets'
 existing=m[field].get(identity)
 if existing and '/native-412/' in existing:
  rec=next(x for x in m['raw_images'] if x['source']==existing);g=json.loads((r/existing).with_suffix('.geometry.json').read_text());fresh[key][existing]=st.preserved_source_analysis(r,rec,g);tracks[key]+=1;continue
 src=r/item['source'];assert sha(src)==item['sha256'];folder=base/key.replace(':','_');folder.mkdir(exist_ok=True);dst=folder/f'{direction}-{role}.png';assert not dst.exists()
 with Image.open(src) as image:
  image=image.convert('RGBA');packed=Image.new('RGBA',(1024,1536))
  for i in range(6):packed.paste(image.crop(((i%3)*512,(i//3)*512,(i%3+1)*512,(i//3+1)*512)),((i%2)*512,(i//2)*512))
  packed.save(dst)
 with Image.open(dst) as image:
  got=[hashlib.sha256(image.crop(((i%2)*512,(i//2)*512,(i%2+1)*512,(i//2+1)*512)).tobytes()).hexdigest() for i in range(6)]
 assert got==item['cell_rgba_sha256']
 try:
  g=imp.analyze(dst,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid2',canvas_size=1024,directions=[direction]);imp.require_complete_pose_regions(dst,g)
 except Exception as e:errors.append(dict(source=str(dst.relative_to(r)),reason=str(e)));continue
 write(dst.with_suffix('.geometry.json'),g);source=str(dst.relative_to(r));rec=dict(key=key,direction=direction,role=role,version='native-reviewed-batch-v01',source=source,bytes=dst.stat().st_size,sha256=sha(dst),requested_poses=6,geometry=dict(status='GEOMETRY_PASS',frames=6,distinct_pixel_frames=6,canvas=1024),production_connected=False,detailed_completed=False,original_source=item['source'],original_source_sha256=item['sha256'],lossless_cell_sha256=got,packing='3x2 to 2x3 unchanged 512 RGBA cells and phase order',source_cell_boundary_visible_pixels=[0]*6)
 boxes=[]
 for i,f in enumerate(g['frames']):
  x,y,w,h=f['region'];boxes.append((x-512*(i%2),y-512*(i//2),x+w-512*(i%2),y+h-512*(i//2)))
 left=max(b[0] for b in boxes);top=max(b[1] for b in boxes);right=min(b[2] for b in boxes);bottom=min(b[3] for b in boxes);assert left<right and top<bottom
 x=max(left,min(256,right-1));y=bottom-1
 layout=dict(status='REVIEWED_LAYOUT_PROPOSAL',review_basis='Technical common cell-relative anchor within all six rectangles preserves authored displacement. Source cell boundary preflight has zero visible pixels. Anatomy, contact, direction appearance and scale remain visually NOT_REVIEWED.',canvas_size=1024,source_sha256=sha(dst),direction=direction,source_anchors=[[x+512*(i%2),y+512*(i//2)] for i in range(6)])
 # Exercise the unchanged reviewed-layout gate before accepting the unit.
 try:st.reviewed_layout.apply_reviewed_layout(dst,g,layout)
 except Exception as e:errors.append(dict(source=source,reason=str(e)));continue
 m['raw_images'].append(rec);m[field][identity]=source;m['reviewed_runtime_layouts'][source]=layout;fresh[key][source]=st.preserved_source_analysis(r,rec,g);tracks[key]+=1;newpaths.extend([source,str(dst.with_suffix('.geometry.json').relative_to(r))])
for field in ('selected_locomotion_sheets','selected_detailed_action_sheets','reviewed_runtime_layouts'):
 for k,v in old[field].items():
  if k.startswith(('transform:393:','transform:267:','transform:413:')) or any(t in v for t in ('halpas','girtas','thunder_female')):assert m[field].get(k)==v
write(mp,m)
if newpaths:subprocess.run(['git','add','-f','--',*newpaths],cwd=r,check=True,stdout=subprocess.DEVNULL)
results=[]
for key in sorted(fresh):
 try:
  st.stage(r,key,'native002' if key=='transform:412' else 'native001',analyzed_sources=fresh[key])
  reg=json.loads((r/st.REGISTER).read_text())['actors'][key]
  if any(t['role']=='run' for t in reg['tracks']):binder.bind(r,key);profile='BOUND_UNAPPROVED_CANDIDATE'
  else:profile='HOLD_NO_AUTHORED_LOCOMOTION_REFERENCE'
  results.append(dict(key=key,clips=tracks[key],profile=profile))
 except Exception as e:errors.append(dict(key=key,reason=str(e)));break
summary=dict(eligible_clips=len(safe),staged_clips=sum(x['clips'] for x in results),actors=results,removed_unsafe_selections=removed,new_packed_clips=len(newpaths)//2,packing_failures=errors,final_approvals_added=0,actual_Main_Player='NOT_RUN',approved_actor_analysis_versions_unchanged=True)
write(out/'stage-summary.json',summary);print(json.dumps({'actors':len(results),'staged_clips':summary['staged_clips'],'failures':len(errors)}))
