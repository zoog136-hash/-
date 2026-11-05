"""Report actual per-asset and per-Land evidence, never infer gameplay from input counts."""
import argparse,collections,json
from pathlib import Path

def summarize(root,manifest):
 partial_path=root/'partial-source-review-receipt.json';partials=json.loads(partial_path.read_text()) if partial_path.exists() else {}
 context_path=root/'runtime-context-evidence.json';contexts=json.loads(context_path.read_text()) if context_path.exists() else {}
 state=json.loads((root/'universe-progress.json').read_text());view_path=root/'viewport-evidence.json';views=json.loads(view_path.read_text()) if view_path.exists() else {};assets=[];lands=[]
 for group in manifest['asset_groups']:
  key=group['shared_art_key'];row=state['assets'].get(key,{});status=row.get('status','QUEUED');valid=status in ('VERIFIED_VISUAL','REUSED_VERIFIED_VISUAL','VERIFIED_EMPTY')
  evidence={'asset_path':group['asset_path'],'land_ids':group['land_ids'],'composition_status':status,'viewport_status':views.get(key,{}).get('status','PENDING'),'runtime_context_status':contexts.get(key,{}).get('status','PENDING'),'runtime_verified_land_ids':contexts.get(key,{}).get('land_ids',[]),'terrain_collision':'UNKNOWN_BLOCKED','portal_runtime_connections':0,'reason':row.get('reason'),'pack_root':row.get('pack_root')}
  if key in partials:
   evidence['partial_review']=partials[key]
   evidence['reason']='UNRESOLVED_ORIGINAL_PACKED_REF_0xFFFFFFFF; no matching TI2 in complete original inventory; raw chunks preserved, no fabricated tile'
  if valid:evidence['report']=row['verification']['report']
  assets.append(evidence)
  for lid in group['land_ids']:lands.append({'land_id':lid,**{k:v for k,v in evidence.items() if k not in ('land_ids','report')}})
 return {'source_input_completeness':manifest.get('summary',{}),'asset_status_counts':dict(collections.Counter(r['composition_status'] for r in assets)),'viewport_status_counts':dict(collections.Counter(r['viewport_status'] for r in assets)),'runtime_context_status_counts':dict(collections.Counter(r['runtime_context_status'] for r in assets)),'referenced_asset_paths':sum(bool(r['land_ids']) for r in assets),'unreferenced_asset_paths':sum(not r['land_ids'] for r in assets),'registered_lands':len(lands),'assets':assets,'lands':lands,'host_connections':'SEPARATE_PARENT_RECEIPT; no new host activation inferred','original_terrain_collision':'UNRESOLVED; no fabricated passability','network_requests':0}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--manifest',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();result=summarize(a.root,json.loads(a.manifest.read_text()));a.out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k not in ('assets','lands','source_input_completeness')}))
