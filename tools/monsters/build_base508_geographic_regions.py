"""Join original region contexts to an explicit source-cell map contract.
Client territory records are never converted into actual NPC positions.
"""
import argparse,collections,gzip,hashlib,json,zipfile
from pathlib import Path

def applied_rows(rows):
 return [row for row in rows if not(type(row.get('is_spawn_raw'))in(int,float) and row.get('is_spawn_raw')==0)]

def main(a):
 with zipfile.ZipFile(a.map_code)as z:contract=json.loads(z.read('handoff/base508-albino-coordinate-contract.json'))
 assert contract['map_key']=='base508_land_48962'and contract['land_id']==48962 and contract['asset_path']=='13474/'and contract['coordinate_space']=='LINEAGEM_WORLD_SOURCE_CELLS_V1'
 tables=json.load(gzip.open(a.contexts))['tables'];lands={r['ID']:r for r in tables['Land']};territories={r['ID']:r for r in tables['Territories']};views=collections.defaultdict(list)
 assert lands[48962]['AssetPath']==contract['asset_path']
 for row in tables['NpcSpawnPackNpcClassView']:views[row['NpcSpawnPackID']].append(row)
 rows=[]
 for link in tables['NpcSpawnPackTerritory']:
  t=territories[link['TerritoriesID']]
  if t['LandID']!=contract['land_id']:continue
  for v in views[link['NpcSpawnPackID']]:
   key=f"lineagem_base508:npc:{v['NpcClassID']}:spawn:{v['ID']}:territory:{link['ID']}"
   rows.append({'edition':'LineageM_base508','map_key':contract['map_key'],'land_id':contract['land_id'],'asset_path':contract['asset_path'],'coordinate_space':contract['coordinate_space'],'source_key':key,'npc_class_id':v['NpcClassID'],'spawn_pack_id':v['NpcSpawnPackID'],'class_view_row_id':v['ID'],'territory_link_row_id':link['ID'],'territory_id':t['ID'],'npc_level_contextual':v['NpcLevel'],'is_spawn_raw':v['IsSpawn'],'server_limit_set_id_raw':v['ServerLimitSetID'],'probability_raw':link['Probability'],'source_bounds':[t['StartX'],t['StartY'],t['EndX'],t['EndY']],'placement_status':'CLIENT_TERRITORY_ONLY','runtime_confirmed_source_cell':None,'movement_enabled':False})
 assert len(rows)==95 and len({r['npc_class_id']for r in rows})==15
 source_count=len(rows);rows=applied_rows(rows)
 result={'schema':1,'source_snapshot':'base508','map_worker_commit':'0224c47','coordinate_contract':contract,'rows':rows,'counts':{'client_region_contexts':len(rows),'source_region_contexts':source_count,'explicit_inactive_contexts_excluded':source_count-len(rows),'npc_classes':len({r['npc_class_id']for r in rows}),'native_placed_instances':0,'movement_enabled_instances':0},'contract':'Explicit IsSpawn0 entries excluded from application; original source tables retained. Exact source IDs/regions only; no random position or region center. Rendering requires explicitly confirmed instances and an explicit compatible display-anchor policy. Movement remains disabled.'};a.output.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n');print(json.dumps(result['counts']))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in('map-code','contexts','output'):p.add_argument('--'+n,type=Path,required=True)
 main(p.parse_args())
