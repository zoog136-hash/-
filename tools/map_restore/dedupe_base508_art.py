"""Hardlink byte-identical verified derived art, preserving every logical map path."""
import argparse,hashlib,json,os
from pathlib import Path

def dedupe(root):
 root=root.resolve();state=json.loads((root/'universe-progress.json').read_text());known={};saved=links=0
 for row in state['assets'].values():
  if row.get('status') not in ('VERIFIED_VISUAL','VERIFIED_EMPTY'):continue
  directory=Path(row['pack_root'])
  if directory.is_symlink() or not directory.resolve().is_relative_to(root/'assets'):continue
  metadata=directory/('map.json' if row['land_ids'] else 'asset.json');pack=json.loads(metadata.read_text())
  for member in pack['art']['chunks']:
   path=directory/member['file'];digest=member['sha256'];first=known.setdefault(digest,path)
   if first==path or first.stat().st_ino==path.stat().st_ino:continue
   if hashlib.sha256(first.read_bytes()).hexdigest()!=digest or hashlib.sha256(path.read_bytes()).hexdigest()!=digest:raise ValueError('Verified derived art changed; no deduplication')
   temporary=path.with_name(path.name+'.dedupe-link')
   if temporary.exists():raise ValueError('Existing dedupe staging file preserved')
   size=path.stat().st_size;os.link(first,temporary);os.replace(temporary,path)
   assert path.stat().st_ino==first.stat().st_ino
   saved+=size;links+=1
 return {'identical_derived_chunks_linked':links,'duplicate_bytes_released':saved,'original_source_files_changed':0,'map_paths_and_bytes':'PRESERVED'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);a=p.parse_args();print(json.dumps(dedupe(a.root)))
