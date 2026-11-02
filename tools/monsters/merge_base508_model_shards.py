"""Merge independently built source model shards, preserving reviewed host contexts."""
import argparse,hashlib,json
from pathlib import Path
def merge(root,shards,reviewed):
 result=None
 for i in range(shards):
  row=json.loads((root/f'manifest-{i}.json').read_text())
  if result is None:result={**row,'records':{},'models':{},'source_files':{},'model_failures':{}}
  for field in('records','models','source_files','model_failures'):
   for key,value in row[field].items():
    if key in result[field] and result[field][key]!=value:raise ValueError(('Shard conflict',field,key))
    result[field][key]=value
 used_paths=set()
 # Compact repeated provenance; exact original hashes/CRCs remain in source_files.
 for sid,reference in result['models'].items():
  path=root/reference['tracks_ref'];model=json.loads(path.read_text())
  for track in model['tracks'].values():
   for frames in track['directions']:
    for frame in frames:
     for layer in frame['layers']:
      used_paths.add(layer['path'])
      for field in('original_sha256','original_bytes','source_archive','source_crc32'):layer.pop(field,None)
  b=(json.dumps(model,ensure_ascii=False,separators=(',',':'))+'\n').encode();path.write_bytes(b);reference['tracks_sha256']=hashlib.sha256(b).hexdigest()
 for record in result['records'].values():record.update(result['models'][str(record['sprite_id'])])
 for row in json.loads(reviewed.read_text())['source_id_records']:
  record=result['records'].get(str(row['npc_id']))
  if record is not None:
   for key in('spawn_view_id','territory_link_id','land_id'):record[key]=row[key]
 result['source_files']={key:value for key,value in result['source_files'].items()if value['path']in used_paths}
 result['counts']={'npc_records':len(result['records']),'unique_sprite_models':len(result['models']),'original_sp2_files_used':len(result['source_files']),'failed_models':len(result['model_failures']),'native_geographic_spawns':0}
 (root/'manifest.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n');print(json.dumps(result['counts']))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--shards',type=int,required=True);p.add_argument('--reviewed',type=Path,required=True);a=p.parse_args();merge(a.root,a.shards,a.reviewed)
