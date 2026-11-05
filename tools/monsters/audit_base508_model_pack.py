"""Audit all native model metadata and original hashes without visual inspection."""
import argparse,gzip,hashlib,json
from pathlib import Path
def main(a):
 pack=json.loads((a.root/'manifest.json').read_text());catalog=json.load(gzip.open(a.catalog));source={r['npc_id']:r for r in catalog['rows']};verified={};contexts=0;actions=0;layers=0
 def verify(path,sha):
  if path not in verified:
   h=hashlib.sha256();f=(a.root/path).open('rb')
   with f:
    for b in iter(lambda:f.read(4*1024**2),b''):h.update(b)
   verified[path]=h.hexdigest()
  assert verified[path]==sha,(path,'SHA mismatch')
 for sid,ref in pack['models'].items():
  verify(ref['tracks_ref'],ref['tracks_sha256']);m=json.loads((a.root/ref['tracks_ref']).read_text());assert m['source_sprite_id']==int(sid)
  assert m['tracks']if m.get('source_capability_contract')==1 else all(role in m['tracks']for role in('idle','walk','attack','hit','death'))
  for role,track in m['tracks'].items():
   assert len(track['directions'])==8,(sid,role);actions+=1
   for frames in track['directions']:
    assert frames and (sum(f['source_ticks']for f in frames)>0 or track.get('source_static_zero_duration')and len(frames)==1)
    for f in frames:
     assert f['layers'] and f['source_ticks']>=0
     for layer in f['layers']:
      verify(layer['path'],layer['sha256']);assert layer['codec']=='base508_sp2_v1'and 0<=layer['source_direction_bit']<8 and 0<=layer['source_frame_index']<256
      assert len(layer['offset'])==2 and all(0<x<4096 for x in layer['pixel_size']);layers+=1
 for nid,record in pack['records'].items():
  row=source[int(nid)];assert row['sprite_id']==record['sprite_id']and not row['source_TestNPC']and row['source_kind']in('source_ui_boss_npc','source_attackable_monster_actor')
  permitted={tuple(map(int,pair))for pair in catalog['world_context_index'][nid]}
  for pair in record['source_contexts']:
   assert (int(pair['spawn_view_id']),int(pair['territory_link_id']))in permitted;contexts+=1
 result={'source_npc_records':len(pack['records']),'source_models':len(pack['models']),'exact_source_context_pairs':contexts,'source_action_tracks':actions,'verified_files':len(verified),'layer_addresses':layers,'native_geographic_spawns':0,'failed_models':len(pack['model_failures'])};print(json.dumps(result,sort_keys=True));return result
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--catalog',type=Path,required=True);main(p.parse_args())
