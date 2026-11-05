"""CRC-pinned inspection of original SEG/TIL samples; never activates a map."""
import argparse,hashlib,json
from pathlib import Path
import zlib
from base508_seg import read_seg,write_seg
from base508_til import read_til,render_til
from base508_ti2 import read_ti2,render

def inspect(source,inventory,member):
 maps=json.loads((inventory/'map_id_to_archive.json').read_text());tiles=json.loads((inventory/'tile_id_to_archive.json').read_text());specs=[s for group in maps.values() for s in group]+[s for group in tiles.values() for s in group]
 spec=next(s for s in specs if s['member']==member);data=(source/member).read_bytes()
 if len(data)!=spec['bytes'] or f'{zlib.crc32(data):08x}'!=spec['crc32']:raise ValueError('Original sample CRC/size mismatch')
 result={'member':member,'source_sha256':hashlib.sha256(data).hexdigest(),'original_crc_verified':True,'runtime_activated':False,'additional_full_maps_completed':0}
 if member.endswith('.seg'):
  row=read_seg(data,member)
  if write_seg(row)!=data:raise ValueError('SEG byte roundtrip mismatch')
  candidates=[]
  for tid,index in row['tile_pairs']:
   found=[s for s in tiles.get(str(tid),[]) if s['member'].endswith('.ti2')]
   if not found:raise ValueError('SEG candidate TileID absent from inventory')
   entry=found[0]
   if not (source/entry['member']).is_file():candidates.append(entry)
  group=member.split('/')[1];expected=maps[group]
  result.update(format='SEG',byte_roundtrip=True,source_attribute_encoding=row['attribute_encoding'],covers=len(row['covers']),object_parts=sum(len(g['parts']) for g in row['objects']),candidate_tile_pairs=len(row['tile_pairs']),required_missing_ti2=list({s['member']:s for s in candidates}.values()),asset_expected_chunks=len(expected),asset_local_chunks=sum((source/s['member']).is_file() for s in expected),visual_semantics=row['visual_semantics'])
 else:
  tile=read_til(data);digests={};unsupported=[]
  for i,block in enumerate(tile['blocks']):
   try:
    if block not in digests:
     image=render_til(block);digests[block]={'rgba_sha256':hashlib.sha256(image.tobytes()).hexdigest(),'alpha_bbox':image.getchannel('A').getbbox()}
   except ValueError as error:unsupported.append({'index':i,'reason':str(error)})
  ti2=source/Path(member).with_suffix('.ti2');comparisons=[]
  if ti2.is_file():
   paired=next(s for s in specs if s['member']==str(Path(member).with_suffix('.ti2')));payload=ti2.read_bytes()
   if len(payload)!=paired['bytes'] or f'{zlib.crc32(payload):08x}'!=paired['crc32']:raise ValueError('Paired TI2 original CRC mismatch')
   modern=read_ti2(payload)
   for i,block in enumerate(tile['blocks'][:len(modern['blocks'])]):
    if block in digests:
     original=render_til(block);converted=render(modern['blocks'][i],modern['palette'],True)
     comparisons.append({'index':i,'rgba_equal':original.tobytes()==converted.tobytes(),'coverage_equal':original.getchannel('A').tobytes()==converted.getchannel('A').tobytes()})
  result.update(format='TIL',container_encoding=tile['container_encoding'],blocks=len(tile['blocks']),unique_payloads=len(set(tile['blocks'])),unique_rendered_payloads=len(digests),unsupported_blocks=unsupported,paired_ti2_comparisons=comparisons,interpretation='Same numeric ID is compared, never silently substituted; RGB555 and RGB565 precision may differ.')
 return result

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--inventory',type=Path,required=True);p.add_argument('--member',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.write_text(json.dumps(inspect(a.source,a.inventory,a.member),indent=2)+'\n')
