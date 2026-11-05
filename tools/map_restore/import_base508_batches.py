"""Import immutable Library batch bytes into one deduplicated original source cache."""
import argparse,hashlib,json,zipfile,zlib
from pathlib import Path

def import_batch(batch,path,inventory,out):
 payload=path.read_bytes()
 if len(payload)!=batch['bytes'] or hashlib.sha256(payload).hexdigest()!=batch['sha256']:raise ValueError('Batch ZIP size/SHA mismatch: '+path.name)
 out.mkdir(parents=True,exist_ok=True);added=existing=0
 with zipfile.ZipFile(path) as archive:
  if archive.testzip() is not None:raise ValueError('Batch ZIP CRC failure')
  manifest=json.loads(archive.read('input_manifest.json'));assets=manifest['assets']
  if manifest['batch_number']!=batch['batch_number'] or len(assets)!=batch['original_files']:raise ValueError('Batch manifest identity/count mismatch')
  for row in assets:
   name=row['name'];relative=Path(name)
   if relative.is_absolute() or '..' in relative.parts or name not in inventory:raise ValueError('Unexpected original member')
   spec=inventory[name];data=archive.read(name)
   if len(data)!=spec['bytes'] or f'{zlib.crc32(data):08x}'!=spec['crc32'] or hashlib.sha256(data).hexdigest()!=row['sha256']:raise ValueError('Original inventory/manifest mismatch: '+name)
   target=out/name
   if target.exists():
    if hashlib.sha256(target.read_bytes()).hexdigest()!=row['sha256']:raise ValueError('Conflicting original already present: '+name)
    existing+=1;continue
   target.parent.mkdir(parents=True,exist_ok=True)
   with target.open('xb') as handle:handle.write(data)
   added+=1
 receipt={'batch':batch['batch_number'],'batch_library_id':batch['library_file_id'],'zip_sha256':batch['sha256'],'original_members':len(assets),'new_unique_members':added,'already_identical':existing,'visual_maps_completed':0}
 receipts=out/'import-receipts';receipts.mkdir(exist_ok=True);(receipts/f"batch-{batch['batch_number']:03}.json").write_text(json.dumps(receipt,indent=2)+'\n');return receipt

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for key in ['index','downloads','inventory','out']:p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--after-batch',type=int,default=0)
 a=p.parse_args();index=json.loads(a.index.read_text());maps=json.loads((a.inventory/'map_id_to_archive.json').read_text());tiles=json.loads((a.inventory/'tile_id_to_archive.json').read_text());specs={s['member']:s for rows in list(maps.values())+list(tiles.values()) for s in rows}
 for batch in index['files']:
  if batch['batch_number']<=a.after_batch:continue
  path=a.downloads/batch['file_name']
  if path.is_file():print(json.dumps(import_batch(batch,path,specs,a.out)),flush=True)
