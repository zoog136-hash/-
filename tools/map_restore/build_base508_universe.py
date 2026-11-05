"""Index every original map directory and Land context without activating maps.

No network requests. A single global request per original member/container lets
an authorized shared DAT cache satisfy all maps without duplicate downloads.
"""
import argparse,gzip,hashlib,json,zlib
from collections import Counter,defaultdict
from pathlib import Path

def build(analysis,structure,outer_path,source_roots,rendered_roots,png_roots=(),host_receipt=None):
 lands=json.loads((analysis/'land_catalog.json').read_text());portals=json.loads((analysis/'portal_links.json').read_text())
 maps=json.loads((structure/'inventory/map_id_to_archive.json').read_text());tiles=json.loads((structure/'inventory/tile_id_to_archive.json').read_text());inventory=json.loads((structure/'inventory/map_tile_catalog_summary.json').read_text());outer=json.loads(outer_path.read_text())
 host_entries=json.loads(host_receipt.read_text()).get("map_integrations",[]) if host_receipt else []
 host_by_id={row["land_id"]:row for row in host_entries}
 for row in host_entries:
  if not any(l["ID"]==row["land_id"] and l["AssetPath"]==row["asset_path"] for l in lands):raise ValueError("Host receipt Land/AssetPath mismatch")
 contexts=defaultdict(list)
 for land in lands:contexts[land['AssetPath'].strip('/')].append(land)
 core_tiles=defaultdict(set)
 with gzip.open(structure/'maps/chunks.jsonl.gz','rt') as f:
  for line in f:
   row=json.loads(line);group=row['member'].split('/')[1];core_tiles[group].update(row.get('floor_tile_ids',[]));core_tiles[group].update(row.get('foreground_tile_ids',[]))
 local={}
 def locate(spec):
  member=spec['member']
  if member in local:return local[member]
  local[member]={'state':'MISSING_LOCAL','valid_paths':[],'rejected_paths':[]}
  for root in source_roots:
   path=root/member
   if path.is_file():
    data=path.read_bytes();valid=len(data)==spec['bytes'] and f'{zlib.crc32(data):08x}'==spec['crc32'];local[member]['valid_paths' if valid else 'rejected_paths'].append(str(path))
  if local[member]['valid_paths']:local[member]['state']='LOCAL_CRC_VERIFIED'
  return local[member]
 rendered={}
 for root in rendered_roots:
  path=root/'map.json'
  if not path.is_file():continue
  m=json.loads(path.read_text());group=m['land']['AssetPath'].strip('/')
  # A claimed report is a checkpoint, not a fresh GPU render certificate.
  rendered[group]={'status':m['art']['status'],'pack_root':str(root),'pixel_sha256':m['art'].get('pixel_sha256'),'checkpoint_report':m.get('report',{}),'host_connection':'UNASSESSED_BY_SOURCE_INDEXER; receipt required'}
 groups=[]
 for group,specs in sorted(maps.items(),key=lambda x:(not x[0].isdigit(),int(x[0]) if x[0].isdigit() else x[0])):
  counts=Counter(Path(s['member']).suffix.lower() for s in specs);found=Counter(Path(s['member']).suffix.lower() for s in specs if locate(s)['state']=='LOCAL_CRC_VERIFIED')
  png_files=[root/(group+'.png') for root in png_roots if (root/(group+'.png')).is_file()]
  png_references=[{'path':str(p),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'base508_equivalence':'UNVERIFIED_REFERENCE_ONLY'} for p in png_files]
  ids=sorted(core_tiles[group]);required=[r for tid in ids for r in tiles.get(str(tid),[]) if r['member'].endswith('.ti2')]
  land_ids=[r['ID'] for r in contexts[group]]
  groups.append({'asset_path':group+'/','classification':'LAND_REFERENCED' if land_ids else 'UNREFERENCED_PRESERVE_NOT_EXPOSED','land_ids':land_ids,'shared_art_key':'base508_asset_'+group,'source_expected':dict(counts),'source_local_crc_verified':dict(found),'core_tile_ids':ids,'tile_requirements_status':'AUDITED_CORE_ONLY; UNKNOWN_TAIL_DEPENDENCIES_NOT_INVENTED','ti2_expected_known_core':len(required),'ti2_local_crc_verified':sum(locate(r)['state']=='LOCAL_CRC_VERIFIED' for r in required),'required_dat':sorted({s['archive'] for s in specs+required}),'png':{'base508_original_member':'NOT_PROVEN_BY_THIS_MAP_TILE_INDEX','local_reference_present':bool(png_references),'local_reference_files':png_references,'reference_is_source_tile_completion':False},'visual':rendered.get(group,{'status':'NOT_RENDERED','host_connection':'NOT_CONNECTED'}),'collision':{'M_terrain':'UNKNOWN','height':'UNKNOWN','legacy_registered_collision':group=='13474'},'host_integrations':[host_by_id[lid] for lid in land_ids if lid in host_by_id],'playable_default':False,'unprovided_chunks':'BLOCKED','portal_context_ids':[p['ID'] for p in portals if p['SourceLandID'] in land_ids]})
 land_contexts=[]
 for land in lands:
  links=[p for p in portals if p['SourceLandID']==land['ID']]
  land_contexts.append({'map_key':f"base508_land_{land['ID']}",'land':land,'shared_art_key':'base508_asset_'+land['AssetPath'].strip('/'),'portal_ids':[p['ID'] for p in links],'portal_point_destinations':sum(p['TargetIsPoint'] for p in links),'portal_region_destinations':sum(not p['TargetIsPoint'] for p in links),'portal_runtime_connections':0,'portal_trigger':'UNVERIFIED','host_integration':host_by_id.get(land['ID'],{'status':'UNASSESSED_NO_HOST_RECEIPT'})})
 members={s['member']:dict(s,local=locate(s)) for specs in maps.values() for s in specs}
 for specs in tiles.values():
  for s in specs:members[s['member']]=dict(s,local=locate(s))
 for s in inventory.get('other_members',[]):members[s['member']]=dict(s,local=locate(s))
 requests=defaultdict(list)
 for member,s in sorted(members.items()):
  if s['local']['state']!='LOCAL_CRC_VERIFIED':requests[s['archive']].append([member,s['bytes'],s['crc32']])
 containers=[dict(outer[name],requested_members=rows,cache_policy='CHECK_PARENT_SHARED_DAT_CACHE_FIRST; DO_NOT_REDOWNLOAD_IF_VALID; LOCAL_EXTRACT_SUCCESS_IS_NOT_A_DAT_CACHE') for name,rows in sorted(requests.items())]
 universe={'schema':1,'source_edition':'LineageM_base508','summary':{'lands':len(lands),'referenced_asset_paths':len({land['AssetPath'].strip('/') for land in lands}),'all_source_directories':len(maps),'unreferenced_directories':sum(not g['land_ids'] for g in groups),'source_members':len(members),'locally_verified_members':sum(s['local']['state']=='LOCAL_CRC_VERIFIED' for s in members.values()),'actual_s32_ti2_visual_maps':len(rendered),'main_game_connected_maps':len(host_by_id) if host_receipt else None,'host_evidence_scope':'EXPLICIT_RECEIPT; not inferred from bytes or render counts'},'land_contexts':land_contexts,'asset_groups':groups,'activation_policy':'No historical deletion list; unreferenced preserved; default game maps unchanged; readiness never equals rendered or playable.'}
 request={'schema':1,'source':'https://archive.org/download/lineage-m-game-client-patches/20260909_508.zip','source_bytes':10368600847,'columns':['member','bytes','crc32'],'deduplication':'ONE MEMBER/CONTAINER GLOBALLY; route through existing parent shared DAT cache; no acquisition performed by this planner','container_count':len(containers),'requested_members':sum(len(r['requested_members']) for r in containers),'already_present_members':len(members)-sum(len(r['requested_members']) for r in containers),'containers':containers,'unreferenced_policy':'Preserve all 57 source groups; do not expose as playable maps','all_member_locations':members}
 return universe,request

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for key in ['analysis','structure','outer','out']:p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--host-receipt',type=Path);p.add_argument('--png-root',type=Path,action='append',default=[]);p.add_argument('--source-root',type=Path,action='append',required=True);p.add_argument('--rendered-root',type=Path,action='append',default=[]);a=p.parse_args();u,r=build(a.analysis,a.structure,a.outer,a.source_root,a.rendered_root,a.png_root,a.host_receipt);a.out.mkdir(parents=True,exist_ok=True)
 for name,data in [('base508-all-map-manifest.json',u),('base508-all-map-requirements.json',r)]: (a.out/name).write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n')
 print(json.dumps(u['summary']));print(json.dumps({k:r[k] for k in ['container_count','requested_members','already_present_members']}))
