"""Package a private source monster directory for the game's bounded ZIP installer."""
import argparse,hashlib,json,zipfile
from pathlib import Path
def digest(b):return hashlib.sha256(b).hexdigest()
def encode(v):return json.dumps(v,ensure_ascii=False,separators=(',',':')).encode()
def build(root,output,release):
 manifest=json.loads((root/'manifest.json').read_text());rows=[];payload=bytearray();chunks=[];count=0;size=0
 paths={'manifest.json'}
 for record in list(manifest['records'].values())+list(manifest.get('models',{}).values()):paths.add(record['tracks_ref'])
 for model_path in list(paths-{'manifest.json'}):
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
 print(json.dumps({'path':str(output),'zip_bytes':output.stat().st_size,'sha256':digest(output.read_bytes()),'files':count,'bytes':size,'npc_ids':len(header['npc_ids'])}))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--release',required=True);a=p.parse_args();build(a.root,a.output,a.release)
