"""Verify every converted cell and layer against the recovered source bytes."""
import json,zlib,hashlib,csv
from pathlib import Path
import numpy as np
from formats import sha,move_masks,write_s32
from test_formats import oracle
root=Path(__file__).resolve().parents[2]
out=root/'data/original_maps'; docs=root/'docs/map-runtime-20261011';base=root/'data/l1j/recovered_maps'
source={r['map_id']:r for r in json.loads((base/'source_maps.json').read_text())['maps']}
packs={};seen=set();rows=[];samples=0;cells=0
for p in sorted((out/'definitions').glob('*.json'),key=lambda p:int(p.stem)):
 d=json.loads(p.read_text());w,h=d['dimensions'];attr=np.zeros((h,w),np.uint8);mask=np.zeros_like(attr)
 for cx,cy,cw,ch,shard,offset,length,digest in d['navigation']['chunks']:
  pack=packs.setdefault(('navigation',shard),(out/f'navigation-{shard:02}.bin').read_bytes())
  raw=zlib.decompress(pack[offset:offset+length]);assert len(raw)==cw*ch*2 and sha(raw)==digest
  attr[cy*64:cy*64+ch,cx*64:cx*64+cw]=np.frombuffer(raw[:cw*ch],np.uint8).reshape(ch,cw)
  mask[cy*64:cy*64+ch,cx*64:cx*64+cw]=np.frombuffer(raw[cw*ch:],np.uint8).reshape(ch,cw)
 original=(base/source[d['source_map_id']]['raw_file']).read_bytes()
 assert attr.tobytes()==original and sha(original)==d['source_sha256']
 verified=d['navigation']['profile']=='A3_STATIC_EDGES' and d['origin'] is not None
 expected=move_masks(attr) if verified else np.zeros_like(attr)
 assert np.array_equal(mask,expected) and sha(mask.tobytes())==d['navigation']['mask_sha256']
 if verified:
  for y,x in [(0,0),(h-1,w-1)]+list(zip(np.random.default_rng(w).integers(0,h,32),np.random.default_rng(h).integers(0,w,32))):
   for heading in range(8):assert bool(mask[y,x]&(1<<heading))==oracle(attr,x,y,heading);samples+=1
 cells+=w*h
 for ref in d['terrain_variants']:
  shard,offset,length,digest=ref['pack'];key=(shard,offset)
  if key in seen:continue
  pack=packs.setdefault(('terrain',shard),(out/f'terrain-{shard:02}.bin').read_bytes());raw=zlib.decompress(pack[offset:offset+length]);assert sha(raw)==digest
  layer=json.loads(raw);assert sha(write_s32(layer))==ref['source_sha256'];seen.add(key)
 rows.append({'source_map_id':d['source_map_id'],'source_name':d['map_name'],'source_version':'A3' if verified else 'other_unverified',
  'source_path':d['source_path'],'grid_sha256':d['source_sha256'],'origin':d['origin'],'width':w,'height':h,'twilight_map_id':d['map_id'],
  'original_graphics':'MISSING','terrain_chunks':len(d['terrain_chunks']),'grid_byte_validation':'PASS','static_navigation_validation':'PASS' if verified else 'RULES_UNVERIFIED',
  'runtime_enabled':d['playable'],'actual_play_test':'NOT_RUN'})
for refs in json.loads((docs/'S32_CHUNK_MAPPING.json').read_text()).values():
 for ref in refs:
  shard,offset,length,digest=ref['pack'];pack=packs.setdefault(('terrain',shard),(out/f'terrain-{shard:02}.bin').read_bytes())
  raw=zlib.decompress(pack[offset:offset+length]);assert sha(raw)==digest and sha(write_s32(json.loads(raw)))==ref['source_sha256'];seen.add((shard,offset))
with (docs/'MAP_SOURCE_INVENTORY.csv').open('w',newline='',encoding='utf-8') as f:
 writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
(docs/'MAP_SOURCE_MAPPING.json').write_text(json.dumps({'schema':2,'all_source_versions':'../map-recovery-20261011/MAP_SOURCE_MAPPING.json','maps':rows},ensure_ascii=False,indent=2))
summary={'maps':len(rows),'cells':cells,'source_bytes_match':len(rows),'verified_static_navigation':sum(r['static_navigation_validation']=='PASS' for r in rows),
 'independent_edge_assertions':samples,'unique_s32_roundtrip_payloads':len(seen),'errors':[]}
(docs/'batch_validation.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary))
