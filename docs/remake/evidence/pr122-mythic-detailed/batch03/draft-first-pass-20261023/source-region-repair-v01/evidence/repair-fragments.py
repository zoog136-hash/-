import sys,json,hashlib,copy,shutil,subprocess,collections
from pathlib import Path
r=Path('/workspace/twilight');sys.path.insert(0,str(r/'tools'))
import import_original_based_motion as imp
import pr122_reviewed_source_regions as regions
import stage_pr122_native_locomotion as st
import bind_pr122_native_locomotion_profiles as binder
s=Path('/workspace/scratch/pr122-region-repair-20261023');out=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/source-region-repair-v01';out.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
mp=r/st.SOURCE_MANIFEST;m=json.loads(mp.read_text());original=json.loads((r/st.REGISTER).read_text());newfresh=collections.defaultdict(dict);fixes=[];holds=[];added=[]
for item in json.loads((s/'fragment-preflight.json').read_text()):
 if item['status']!='TOPOLOGY_CANDIDATE':holds.append(item);continue
 key,direction,role=item['key'],item['direction'],item['role'];src=r/item['source'];meta=json.loads(src.with_suffix('.json').read_text());assert sha(src)==meta['source_sha256']
 folder=out/key.replace(':','_');folder.mkdir(exist_ok=True);dst=folder/f'{direction}-{role}-expanded-source.png';assert not dst.exists();shutil.copyfile(src,dst);assert sha(src)==sha(dst)
 base=imp.analyze(dst,rows_count=6,reference_rows=[0,3],directions_axis='phase_grid3',canvas_size=1024,directions=[direction])
 rr=dict(status=regions.STATUS,source_sha256=sha(dst),base_geometry_sha256=regions._digest(base),direction=direction,review_basis='Expand strict original pose regions to include topology-owned detached foreground. Existing alpha16/alpha100 ownership, minimum32 owner margin, six-body and disjoint rectangle guards unchanged. No semantic anatomy or actor quality approval.',regions=item['regions'],nearest_owner_sha256=item['nearest_owner_sha256'],directions_axis='phase_grid3')
 try:g,proof=regions.apply_reviewed_regions(dst,base,rr)
 except ValueError as e:holds.append(dict(**item,final_region_hold=str(e)));continue
 boxes=[]
 for i,f in enumerate(g['frames']):
  x,y,w,h=f['region'];boxes.append((x-512*(i%3),y-512*(i//3),x+w-512*(i%3),y+h-512*(i//3)))
 left=max(b[0] for b in boxes);top=max(b[1] for b in boxes);right=min(b[2] for b in boxes);bottom=min(b[3] for b in boxes)
 if not(left<right and top<bottom):holds.append(dict(**item,final_region_hold='No common authored-relative anchor'));continue
 x=max(left,min(256,right-1));y=bottom-1
 layout=dict(status='REVIEWED_LAYOUT_PROPOSAL',source_sha256=sha(dst),canvas_size=1024,direction=direction,directions_axis='phase_grid3',review_basis='Whole original source and explicit topology-owned expanded rectangles; fixed cell-relative anchor retains authored motion. Final visual quality not reviewed.',source_anchors=[[x+512*(i%3),y+512*(i//3)] for i in range(6)])
 try:st.reviewed_layout.apply_reviewed_layout(dst,g,layout,source_region_review=rr)
 except ValueError as e:holds.append(dict(**item,final_region_hold=str(e)));continue
 source=str(dst.relative_to(r));write(dst.with_suffix('.geometry.json'),g)
 rec=dict(key=key,direction=direction,role=role,version='expanded-source-region-v01',source=source,sha256=sha(dst),bytes=dst.stat().st_size,requested_poses=6,directions_axis='phase_grid3',geometry=dict(status='GEOMETRY_PASS',frames=6,distinct_pixel_frames=6,canvas=1024),source_region_review=rr,source_region_proof=proof,production_connected=False,detailed_completed=False,original_source=item['source'],original_source_sha256=sha(src),original_request_sha256=meta['generation_request_sha256'])
 m['raw_images'].append(rec);m['selected_locomotion_sheets' if role=='run' else 'selected_detailed_action_sheets'][f'{key}:{direction}:{role}']=source;m['reviewed_runtime_layouts'][source]=layout;newfresh[key][source]=st.preserved_source_analysis(r,rec,g);added.extend([source,str(dst.with_suffix('.geometry.json').relative_to(r))]);fixes.append(dict(key=key,direction=direction,role=role,original_source=item['source'],source=source,source_sha256=sha(dst),missing_foreground_after=0,foreign_foreground_after=0,visual_quality='NOT_REVIEWED'))
write(mp,m);subprocess.run(['git','add','-f','--',*added],cwd=r,check=True,stdout=subprocess.DEVNULL)
# The source-region checker changed: validate every affected staged candidate,
# retaining existing PNGs and whole-frame geometry byte-for-byte.
records={(x['key'],x['source']):x for x in m['raw_images']};allkeys=[k for k in original['actors'] if k not in ('transform:393','transform:267','transform:413')];validated=0
for key in allkeys:
 for t in original['actors'][key]['tracks']:
  rec=records[(key,t['source'])];path=r/t['source'];assert sha(path)==rec['sha256']
  base=imp.analyze(path,rows_count=6,reference_rows=[0,3],directions_axis=rec.get('directions_axis','phase_grid2'),canvas_size=rec['geometry'].get('canvas',1024),directions=[rec['direction']]);imp.require_complete_pose_regions(path,base);assert base==json.loads(path.with_suffix('.geometry.json').read_text())
  if key in newfresh:newfresh[key][t['source']]=st.preserved_source_analysis(r,rec,base)
  else:
   checked,_=st.reviewed_layout.apply_reviewed_layout(path,base,m['reviewed_runtime_layouts'][t['source']]);assert checked==t['geometry']
  validated+=1
results=[]
for key in sorted(newfresh):
 old=original['actors'].get(key,{});oldtracks={x['animation']:x for x in old.get('tracks',[])}
 st.stage(r,key,'native004',analyzed_sources=newfresh[key]);entry=json.loads((r/st.REGISTER).read_text())['actors'][key];retained=0
 for t in entry['tracks']:
  if t['animation'] in oldtracks:
   assert all(t[f]==oldtracks[t['animation']][f] for f in ('source','source_sha256','texture','geometry'));retained+=1
 if any(t['role']=='run' for t in entry['tracks']):binder.bind(r,key)
 results.append(dict(key=key,clips=entry['native_track_count'],preserved_existing_clips=retained))
reg=json.loads((r/st.REGISTER).read_text());changed=set(newfresh)
for key,entry in original['actors'].items():
 if key not in changed:assert reg['actors'][key]==entry
write(s/'fragment-repair-summary.json',dict(repaired_clips=fixes,hold_candidates=holds,new_source_frames_rendered=0,repaired_extraction_clips=len(fixes),all_existing_tracks_revalidated=validated,actors=results,source_pngs_byte_identical=True,final_approvals_added=0))
print(json.dumps({'repaired':len(fixes),'held':len(holds),'existing_revalidated':validated,'actors':len(results)}))
