"""Package a private source monster directory for the game's bounded ZIP installer."""
import argparse,hashlib,json,zipfile,re
from pathlib import Path
def digest(b):return hashlib.sha256(b).hexdigest()
def file_digest(path):
 h=hashlib.sha256()
 with path.open('rb')as f:
  for b in iter(lambda:f.read(4*1024**2),b''):h.update(b)
 return h.hexdigest()
def encode(v):return json.dumps(v,ensure_ascii=False,separators=(',',':')).encode()
def boss_vfx_files(root,manifest):
 """Optional private effect payload. Paths inside its manifest stay relative."""
 if 'boss_vfx' not in manifest:return set()
 def checked(relative,sha,prefix):
  if not isinstance(relative,str)or not relative.startswith(prefix)or relative.startswith('/')or any(p in ('','..','.')for p in relative.split('/'))or ':'in relative or '\\'in relative:raise ValueError(('Unsafe boss VFX path',relative))
  if not isinstance(sha,str)or not re.fullmatch('[0-9a-f]{64}',sha):raise ValueError(('Invalid boss VFX SHA',relative))
  path=root/relative
  if not path.resolve().is_relative_to(root.resolve())or not path.is_file()or file_digest(path)!=sha:raise ValueError(('Boss VFX missing/hash mismatch',relative))
  return path
 ref=manifest['boss_vfx']
 if not isinstance(ref,dict)or ref.get('path')!='boss_vfx/boss_vfx.json':raise ValueError('Invalid boss VFX manifest reference')
 path=checked(ref['path'],ref.get('sha256'),'boss_vfx/');data=json.loads(path.read_text())
 if data.get('kind')!='base508_boss_literal_sp2_effects'or data.get('source_snapshot')!='base508':raise ValueError('Invalid boss VFX source kind')
 models=data.get('models');sources=data.get('source_files')
 if not isinstance(models,dict)or not models or len(models)>9470 or not isinstance(sources,dict)or not sources or len(sources)>50000:raise ValueError('Invalid boss VFX inventory')
 paths={ref['path']};packets={}
 for source in sources.values():
  if not isinstance(source,dict):raise ValueError('Invalid boss VFX packet reference')
  relative=source.get('path');sha=source.get('sha256')
  if not isinstance(relative,str)or not relative.endswith('.bin'):raise ValueError('Invalid boss VFX packet path')
  checked('boss_vfx/'+relative,sha,'boss_vfx/sp2/')
  if relative in packets and packets[relative]!=sha:raise ValueError('Conflicting boss VFX packet SHA')
  packets[relative]=sha;paths.add('boss_vfx/'+relative)
 for key,model in models.items():
  if not str(key).isdigit()or int(key)<=0 or str(int(key))!=key or not isinstance(model,dict):raise ValueError('Invalid boss VFX sprite ID')
  relative=model.get('path');sha=model.get('sha256')
  if not isinstance(relative,str)or not relative.endswith('.json'):raise ValueError('Invalid boss VFX model path')
  p=checked('boss_vfx/'+relative,sha,'boss_vfx/effects/');value=json.loads(p.read_text());paths.add('boss_vfx/'+relative)
  if value.get('source_snapshot')!='base508'or value.get('source_sprite_id')!=int(key)or not isinstance(value.get('tracks'),dict)or not value['tracks']:raise ValueError('Invalid boss VFX model identity')
  for track in value['tracks'].values():
   if not isinstance(track,dict)or track.get('source_sprite_id')!=int(key)or track.get('source_action_id')!=0:raise ValueError('Invalid boss VFX source action')
   directions=track.get('directions')
   if not isinstance(directions,list)or len(directions)!=8 or not any(directions):raise ValueError('Invalid boss VFX source directions')
   for frames in directions:
    if not isinstance(frames,list)or len(frames)>4096:raise ValueError('Invalid boss VFX frame list')
    for frame in frames:
     if not isinstance(frame,dict)or not isinstance(frame.get('layers'),list)or not 0<len(frame['layers'])<=8:raise ValueError('Invalid boss VFX layers')
     for layer in frame['layers']:
      if not isinstance(layer,dict)or layer.get('codec')!='base508_sp2_v1'or packets.get(layer.get('path'))!=layer.get('sha256')or layer.get('path')not in packets:raise ValueError('Undeclared boss VFX packet layer')
 return paths
def build(root,output,release):
 manifest=json.loads((root/'manifest.json').read_text());rows=[];payload=bytearray();chunks=[];count=0;size=0
 paths={'manifest.json'}
 paths.update(boss_vfx_files(root,manifest))
 for name,sha in manifest.get('private_metadata',{}).items():
  if name not in('boss_combat.bin','monster_drops.bin'):raise ValueError(('Unknown private metadata',name))
  if file_digest(root/name)!=sha:raise ValueError(('Private metadata SHA mismatch',name))
  paths.add(name)
 for record in list(manifest['records'].values())+list(manifest.get('models',{}).values()):paths.add(record['tracks_ref'])
 for model_path in list(p for p in paths if p.startswith('actors/')and p.endswith('.json')):
  model=json.loads((root/model_path).read_text())
  for track in model['tracks'].values():
   for frames in track['directions']:
    for frame in frames:
     for layer in frame['layers']:paths.add(layer['path'])
 def flush(z):
  if not rows:return
  name=f'inventory/{len(chunks):04d}.json';p=f'payload/{len(chunks):04d}.bin';b=encode(rows)
  z.writestr(name,b);z.writestr(p,payload)
  chunks.append({'path':name,'sha256':digest(b),'bytes':len(b),'count':len(rows),'payload':p,'payload_bytes':len(payload),'payload_sha256':digest(payload)});rows.clear();payload.clear()
 with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=1,allowZip64=True)as z:
  for name in sorted(paths):
   if name.startswith('/')or'..'in name.split('/')or':'in name or'\\'in name:raise ValueError(name)
   b=(root/name).read_bytes()
   if len(b)>64*1024**2:raise ValueError(('Installer entry too large',name))
   if rows and(len(rows)>=1024 or len(payload)+len(b)>32*1024**2):flush(z)
   rows.append({'path':name,'bytes':len(b),'offset':len(payload),'sha256':digest(b)});payload.extend(b);count+=1;size+=len(b)
  flush(z)
  header={'schema':2,'kind':'twilight-lineagem-offline-monsters','source_snapshot':'base508','release_id':release,'files':count,'bytes':size,'npc_ids':sorted(map(int,manifest['records'])),'chunks':chunks,'limitations':'Source pixels/actions retained; unknown native timing and blend remain explicitly compatible or strict. No verified native geographic placements.'}
  z.writestr('pack.json',encode(header))
 print(json.dumps({'path':str(output),'zip_bytes':output.stat().st_size,'sha256':file_digest(output),'files':count,'bytes':size,'npc_ids':len(header['npc_ids'])}))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--release',required=True);a=p.parse_args();build(a.root,a.output,a.release)
