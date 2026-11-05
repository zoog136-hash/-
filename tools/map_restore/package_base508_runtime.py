"""Prepare private review packages/catalog; never activate maps or overwrite saves."""
import argparse,hashlib,json,zipfile
from pathlib import Path

def members(root):
 for path in sorted(root.rglob('*')):
  relative=path.relative_to(root)
  if path.is_file() and 'source' not in relative.parts and path.suffix not in ('.log','.sqlite','.raw'):yield path,relative

def catalog(root):
 state=json.loads((root/'universe-progress.json').read_text());entries=[]
 for key,row in state['assets'].items():
  if row['status'] not in ('VERIFIED_VISUAL','REUSED_VERIFIED_VISUAL','VERIFIED_EMPTY'):continue
  directory=Path(row['pack_root']);pack=json.loads((directory/('map.json' if row['land_ids'] else 'asset.json')).read_text())
  for lid in row['land_ids']:
   entries.append({'land_id':lid,'asset_path':row['asset_path'],'shared_art_key':key,'pack_root':str(directory),'requested_land_context':lid,'visual_status':pack['art']['status'],'terrain_collision':'UNKNOWN_BLOCKED','runtime_activation':'EXPLICIT_TEST_MODE_ONLY; NO_AUTOMATIC_REGISTRATION','portal_runtime_connections':0})
 return {'schema':'base508_private_review_catalog_v1','entries':sorted(entries,key=lambda x:x['land_id']),'unreferenced_excluded_from_game_catalog':True,'default_stable_maps_and_saves':'PRESERVE','raw_originals':'Separately retained; runtime packages omit duplicate source/ files','completion':'SNAPSHOT; missing entries are not implicitly ready'}

def package(root,key,out):
 if out.exists():raise ValueError('Existing private archive preserved')
 directory=root/'assets'/key
 if not directory.is_dir():raise ValueError('Missing asset artifact')
 record=json.loads((root/'universe-progress.json').read_text())['assets'][key]
 if record['status'] not in ('VERIFIED_VISUAL','REUSED_VERIFIED_VISUAL','VERIFIED_EMPTY'):raise ValueError('Only independently verified outputs may be packaged as runtime review')
 receipt=[]
 with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED,compresslevel=1) as archive:
  for path,relative in members(directory):
   name=key+'/'+relative.as_posix();archive.write(path,name);receipt.append({'file':name,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
  archive.writestr('PRIVATE_RUNTIME_REVIEW.json',json.dumps({'asset':key,'land_ids':record['land_ids'],'terrain_collision':'UNKNOWN_BLOCKED','activation':'NO_AUTOMATIC_REGISTRATION','raw_originals':'Original source files retained separately; runtime-required derived geometry/art and raw-source provenance included','files':receipt},ensure_ascii=False,indent=2))
 with zipfile.ZipFile(out) as archive:
  if archive.testzip() is not None:raise ValueError('Private ZIP CRC mismatch')
  for row in receipt:
   if hashlib.sha256(archive.read(row['file'])).hexdigest()!=row['sha256']:raise ValueError('Private ZIP member SHA mismatch')
 return {'file':str(out),'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'runtime_files':len(receipt),'delivery':'LOCAL_ONLY_UNTIL_CONFIRMED_PRIVATE_TRANSFER'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--catalog',type=Path);p.add_argument('--asset');p.add_argument('--out',type=Path);a=p.parse_args()
 if a.catalog:a.catalog.write_text(json.dumps(catalog(a.root),ensure_ascii=False,indent=2)+'\n')
 if a.asset:
  if not a.out:p.error('--asset requires new --out path')
  print(json.dumps(package(a.root,a.asset,a.out)))
