"""Combine a verified source-model delta with its immutable prior pack directory."""
import argparse,hashlib,json,os
from pathlib import Path

def run(base,patch,output):
 b=json.loads((base/'manifest.json').read_text());p=json.loads((patch/'manifest.json').read_text())
 for m in(b,p):assert m['source_snapshot']=='base508'and m['kind']=='base508_monster_pack'
 if output.exists()and any(output.iterdir()):raise ValueError('Output must be a new empty directory')
 output.mkdir(parents=True,exist_ok=True);m={**b};m['records']=dict(b['records']);m['models']=dict(b['models']);m['source_files']=dict(b['source_files']);m['model_failures']=dict(b.get('model_failures',{}));m['model_failures'].update(p.get('model_failures',{}))
 for field in('records','models','source_files'):
  for key,value in p[field].items():
   if key in m[field]:
    if field=='source_files'and m[field][key]['sha256']==value['sha256']:continue
    if m[field][key]!=value:raise ValueError(('Conflicting source identity',field,key))
   m[field][key]=value
 for sid in m['models']:m['model_failures'].pop(sid,None)
 paths={}
 for source in(base,patch):
  manifest=b if source==base else p
  for record in manifest['models'].values():paths[record['tracks_ref']]=(source,record['tracks_sha256'])
  for record in manifest['source_files'].values():paths.setdefault(record['path'],(source,record['sha256']))
 for relative,(source,sha)in paths.items():
  if relative.startswith('/')or'..'in relative.split('/')or':'in relative or'\\'in relative:raise ValueError(relative)
  path=source/relative;dest=output/relative;dest.parent.mkdir(parents=True,exist_ok=True)
  # Inputs are already hash-audited; hard links preserve bytes without copying GBs.
  os.link(path,dest)
 m['counts']={'npc_records':len(m['records']),'unique_sprite_models':len(m['models']),'original_sp2_files_used':len(m['source_files']),'failed_models':len(m['model_failures']),'native_geographic_spawns':0}
 m['source_pack_lineage']=list(b.get('source_pack_lineage',[]))+[{'base_manifest_sha256':hashlib.sha256((base/'manifest.json').read_bytes()).hexdigest(),'patch_manifest_sha256':hashlib.sha256((patch/'manifest.json').read_bytes()).hexdigest(),'added_npc_ids':sorted(map(int,set(p['records'])-set(b['records']))),'added_model_ids':sorted(map(int,set(p['models'])-set(b['models'])))}]
 (output/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,separators=(',',':'))+'\n')
 assert all(m['records'][k]==v for k,v in b['records'].items());assert all(m['models'][k]==v for k,v in b['models'].items());print(json.dumps(m['counts']))
 return m
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for n in('base','patch','output'):p.add_argument('--'+n,type=Path,required=True)
 a=p.parse_args();run(a.base,a.patch,a.output)
