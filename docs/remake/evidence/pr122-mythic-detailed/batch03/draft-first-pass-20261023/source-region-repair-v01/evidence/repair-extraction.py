import sys,json,hashlib,copy,shutil,subprocess,collections
from pathlib import Path
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import import_original_based_motion as imp
import stage_pr122_native_locomotion as st
import bind_pr122_native_locomotion_profiles as bind
s=Path('/workspace/scratch/pr122-region-repair-20261023');out=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/source-region-repair-v01';out.mkdir(exist_ok=True)
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rows=[json.loads(x) for x in Path('/workspace/scratch/pr122-batch-review-20261023/audit-results.jsonl').read_text().splitlines()]
selected=[x for x in rows if x['strict_geometry']=='PASS' and x['errors']];assert len(selected)==97
mp=r/st.SOURCE_MANIFEST;m=json.loads(mp.read_text());baseline=copy.deepcopy(m);fresh=collections.defaultdict(dict);fixes=[];holds=[];newpaths=[]
for item in selected:
 key,direction,role=item['key'],item['direction'],item['role'];src=r/item['source'];assert sha(src)==item['sha256']
 folder=out/key.replace(':','_');folder.mkdir(exist_ok=True);dst=folder/f'{direction}-{role}-whole-source.png';assert not dst.exists();shutil.copyfile(src,dst);assert sha(dst)==item['sha256']
 # Revalidate under the updated checker once; no frame pixels are regenerated.
 g=imp.analyze(dst,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid3',canvas_size=1024,directions=[direction]);imp.require_complete_pose_regions(dst,g)
 old=json.loads((Path('/workspace/scratch/pr122-batch-review-20261023/geometry')/src.with_suffix('.geometry.json').name).read_text());assert g==old
 boxes=[]
 for i,f in enumerate(g['frames']):
  x,y,w,h=f['region'];boxes.append((x-512*(i%3),y-512*(i//3),x+w-512*(i%3),y+h-512*(i//3)))
 left=max(b[0] for b in boxes);top=max(b[1] for b in boxes);right=min(b[2] for b in boxes);bottom=min(b[3] for b in boxes)
 if not(left<right and top<bottom):holds.append(dict(key=key,direction=direction,role=role,cause='No common source-relative anchor within all six full poses'));continue
 x=max(left,min(256,right-1));y=bottom-1
 review=dict(status='REVIEWED_LAYOUT_PROPOSAL',review_basis='Use unchanged three-column source and exact strict connected-body rectangles, not nominal 512 cell crops. Six original full RGBA pose hashes retained; common cell-relative anchor preserves authored displacement. Visual anatomy, facing, contact and scale NOT_REVIEWED.',directions_axis='phase_grid3',canvas_size=1024,source_sha256=sha(dst),direction=direction,source_anchors=[[x+512*(i%3),y+512*(i//3)] for i in range(6)])
 try:derived,proof=st.reviewed_layout.apply_reviewed_layout(dst,g,review)
 except ValueError as e:holds.append(dict(key=key,direction=direction,role=role,cause=str(e)));continue
 assert [f['rgba_sha256'] for f in derived['frames']]==[f['rgba_sha256'] for f in g['frames']]
 write(dst.with_suffix('.geometry.json'),g);source=str(dst.relative_to(r));meta=json.loads(src.with_suffix('.json').read_text())
 record=dict(key=key,direction=direction,role=role,version='whole-source-region-v01',source=source,sha256=sha(dst),bytes=dst.stat().st_size,requested_poses=6,directions_axis='phase_grid3',geometry=dict(status='GEOMETRY_PASS',frames=6,distinct_pixel_frames=6,canvas=1024),production_connected=False,detailed_completed=False,original_source=item['source'],original_source_sha256=item['sha256'],original_request_sha256=meta['generation_request_sha256'],repair='Metadata only: whole connected pose regions replace rigid cell crops. No source raster modified.',original_poses_rgba_sha256=[f['rgba_sha256'] for f in g['frames']])
 m['raw_images'].append(record);field='selected_locomotion_sheets' if role=='run' else 'selected_detailed_action_sheets';m[field][f'{key}:{direction}:{role}']=source;m['reviewed_runtime_layouts'][source]=review;fresh[key][source]=st.preserved_source_analysis(r,record,g);newpaths.extend([source,str(dst.with_suffix('.geometry.json').relative_to(r))]);fixes.append(dict(key=key,direction=direction,role=role,original_source=item['source'],source=source,source_sha256=sha(dst),whole_pose_region_hashes_preserved=True,visual_quality='NOT_REVIEWED'))
write(mp,m)
subprocess.run(['git','add','-f','--',*newpaths],cwd=r,check=True,stdout=subprocess.DEVNULL)
original_register=json.loads((r/st.REGISTER).read_text());results=[]
for key in sorted(fresh):
 before=original_register['actors'].get(key,{});oldtracks={t['animation']:t for t in before.get('tracks',[])}
 # Checker code changed: revalidate all affected existing tracks, never reuse
 # a result solely by filename or ignore the checker-version change.
 st.stage(r,key,'native003',analyzed_sources=fresh[key])
 entry=json.loads((r/st.REGISTER).read_text())['actors'][key]
 retained=0
 for track in entry['tracks']:
  if track['animation'] in oldtracks:
   old=oldtracks[track['animation']]
   assert all(track[f]==old[f] for f in ('source','source_sha256','texture','geometry'))
   retained+=1
 if any(t['role']=='run' for t in entry['tracks']):bind.bind(r,key);profile='BOUND_UNAPPROVED_CANDIDATE'
 else:profile='HOLD_NO_AUTHORED_LOCOMOTION_REFERENCE'
 results.append(dict(key=key,clips=entry['native_track_count'],preserved_existing_clips=retained,profile=profile))
# Every unrelated actor record, especially approved 393/267 and existing413,
# remains byte-equivalent as structured data.
reg=json.loads((r/st.REGISTER).read_text());changed={x['key'] for x in results}
for key,entry in original_register['actors'].items():
 if key not in changed:assert reg['actors'][key]==entry
summary=dict(candidate_clips=97,repaired_extraction_clips=len(fixes),new_source_frames_rendered=0,source_pngs_byte_identical=True,remaining_source_holds=442-len(fixes),repair_holds=holds,actors=results,repaired_clips=fixes,all_previous_normal_clips_preserved=True,actual_Main_Player='NOT_RUN_AFTER_THIS_REPAIR',final_approvals_added=0)
write(s/'repair-summary.json',summary);print(json.dumps({'fixed':len(fixes),'remaining':summary['remaining_source_holds'],'actors':len(results),'anchor_holds':len(holds)}))
