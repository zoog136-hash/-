"""Disk-indexed source composition: bounded textures and full-raster pixel SHA.

No full map allocation. Stable original layer/sequence order is preserved even
where a 24px source half-tile overlaps a 1024px output chunk boundary.
"""
import base64,hashlib,json,math,shutil,sqlite3,struct,tempfile,zlib
from collections import Counter,OrderedDict
from pathlib import Path
from PIL import Image
from base508_original_store import retain_original
from compose_base508 import project

def iter_placements(chunks,origin):
 for chunk in chunks:
  for i,ref in enumerate(struct.unpack('<8192I',base64.b64decode(chunk['floor_u32le']))):
   x,y=project(chunk['origin'],i%128,i//128,origin);yield -2,x,y,ref
  for hx,ly,ref in chunk['covers']:
   x,y=project(chunk['origin'],hx,ly,origin);yield -1,x,y,ref
  for group in chunk['objects']:
   for hx,ly,layer,ref in group['parts']:
    x,y=project(chunk['origin'],hx,ly,origin);yield layer,x,y,ref

def compose_streamed(chunks,source,inventory,out,cache,chunk_edge=1024):
 if not chunks or cache is None:raise ValueError('Streaming requires source geometry and shared tile cache')
 if not 24<=chunk_edge<=1024:raise ValueError('Bounded output chunk edge')
 source,out=Path(source),Path(out);out.mkdir(parents=True,exist_ok=True)
 origin=[min(c['origin'][i] for c in chunks) for i in range(2)];used=Counter();layers=Counter();provenance=[];specs={};frames=OrderedDict();payloads=OrderedDict()
 def frame(ref):
  if ref in frames:frames.move_to_end(ref);return frames[ref]
  tid,index=ref>>8,ref&255;spec,key=specs[tid];image=cache.cached_frame(key,index)
  if image is None:
   if tid not in payloads:payloads[tid]=(source/spec['member']).read_bytes()
   payloads.move_to_end(tid)
   while len(payloads)>32:payloads.popitem(last=False)
   _,tile=cache.read(payloads[tid]);image=cache.frame(key,tile,index)
  frames[ref]=image
  while len(frames)>4096:frames.popitem(last=False)
  return image
 with tempfile.TemporaryDirectory(prefix='base508-compose-',dir=out.parent) as work:
  work=Path(work);db=sqlite3.connect(work/'placements.sqlite');db.execute('CREATE TABLE p (seq INTEGER PRIMARY KEY,layer INTEGER,x INTEGER,y INTEGER,ref INTEGER)')
  left=top=2**63-1;right=bottom=-2**63;count=0;format_counts={'S32':Counter(),'SEG':Counter()}
  tagged=((row,chunk.get('source_format','S32')) for chunk in chunks for row in iter_placements([chunk],origin))
  for seq,((layer,x,y,ref),kind) in enumerate(tagged):
   db.execute('INSERT INTO p VALUES (?,?,?,?,?)',(seq,layer,x,y,ref));used[ref]+=1;format_counts.setdefault(kind,Counter())[ref]+=1;layers[layer]+=1;count+=1;left=min(left,x);top=min(top,y);right=max(right,x+24);bottom=max(bottom,y+24)
  width,height=right-left,bottom-top
  if width>1048576:raise ValueError('Streaming raster row exceeds 4MiB bound')
  nx,ny=math.ceil(width/chunk_edge),math.ceil(height/chunk_edge)
  db.execute('CREATE TABLE bucket (bx INTEGER,by INTEGER,seq INTEGER)')
  for seq,x,y in db.execute('SELECT seq,x,y FROM p'):
   for by in range((y-top)//chunk_edge,(y-top+23)//chunk_edge+1):
    for bx in range((x-left)//chunk_edge,(x-left+23)//chunk_edge+1):db.execute('INSERT INTO bucket VALUES (?,?,?)',(bx,by,seq))
  db.execute('CREATE INDEX spatial ON bucket(bx,by,seq)');db.commit()
  for tid in sorted({r>>8 for r in used}):
   spec=next(s for s in inventory[str(tid)] if s['member'].endswith('.ti2'));path=source/spec['member'];data=path.read_bytes()
   if len(data)!=spec['bytes'] or f'{zlib.crc32(data):08x}'!=spec['crc32']:raise ValueError('Original TI2 CRC/size mismatch: '+str(path))
   key,tile=cache.read(data);specs[tid]=(spec,key)
   target=out/'source'/spec['member'];target.parent.mkdir(parents=True,exist_ok=True);retain_original(path,target)
   provenance.append({'tile_id':tid,'source':'source/'+spec['member'],'bytes':len(data),'sha256':key,'crc32':spec['crc32'],'header':tile['header'],'block_count':len(tile['blocks']),'flags':dict(Counter(b['flags'] for b in tile['blocks']))})
  empty_refs={ref for ref in used if frame(ref).getchannel('A').getbbox() is None};empty=sum(used[r] for r in empty_refs)
  factor=min(1800/width,900/height,1);overview=Image.new('RGBA',(max(1,round(width*factor)),max(1,round(height*factor))))
  output=[];visible=None;pixel_hash=hashlib.sha256();(out/'art').mkdir(exist_ok=True)
  for by in range(ny):
   h=min(chunk_edge,height-by*chunk_edge);raw_files={}
   for bx in range(nx):
    w=min(chunk_edge,width-bx*chunk_edge);image=Image.new('RGBA',(w,h))
    for layer,seq,x,y,ref in db.execute('SELECT p.layer,p.seq,p.x,p.y,p.ref FROM bucket JOIN p USING(seq) WHERE bx=? AND by=? ORDER BY p.layer,p.seq',(bx,by)):
     if ref in empty_refs:continue
     image.alpha_composite(frame(ref),(x-left-bx*chunk_edge,y-top-by*chunk_edge))
    bbox=image.getchannel('A').getbbox()
    if bbox is None:continue
    px,py=bx*chunk_edge,by*chunk_edge;box=[px+bbox[0],py+bbox[1],px+bbox[2],py+bbox[3]]
    visible=box if visible is None else [min(visible[0],box[0]),min(visible[1],box[1]),max(visible[2],box[2]),max(visible[3],box[3])]
    relative=f'art/{bx}-{by}.webp';path=out/relative;image.save(path,lossless=True,exact=True,method=1);output.append({'file':relative,'position':[px,py],'size':[w,h],'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    raw_path=work/f'{bx}.raw';raw_path.write_bytes(image.tobytes());raw_files[bx]=raw_path.open('rb')
    x0,y0=round(px*factor),round(py*factor);x1,y1=round((px+w)*factor),round((py+h)*factor)
    if x1>x0 and y1>y0:overview.paste(image.resize((x1-x0,y1-y0),Image.Resampling.LANCZOS),(x0,y0))
   # Hash exact row-major RGBA, including transparent omitted chunks, with only
   # one chunk and at most one raster row resident; raw band files stay on disk.
   for _ in range(h):
    for bx in range(nx):
     size=min(chunk_edge,width-bx*chunk_edge)*4;pixel_hash.update(raw_files[bx].read(size) if bx in raw_files else bytes(size))
   for bx,handle in raw_files.items():handle.close();(work/f'{bx}.raw').unlink()
  db.close()
  if visible is None:visible=[0,0,0,0]
  overview.save(out/'overview.png',compress_level=1)
  stats={'s32_composed_chunks':sum(c.get('source_format','S32')=='S32' for c in chunks),'seg_composed_chunks':sum(c.get('source_format')=='SEG' for c in chunks),'ti2_decoded_files':len(specs),'decoded_used_tile_pairs':len(used),'floor_half_tiles_composed':layers[-2],'cover_tiles_composed':layers[-1],'object_parts_composed':sum(v for k,v in layers.items() if k>=0),'decoded_source_tile_placements':count,'visual_source_tiles_restored':count-empty,'visual_s32_tiles_restored':sum(n for ref,n in format_counts['S32'].items() if ref not in empty_refs),'visual_seg_tiles_restored':sum(n for ref,n in format_counts['SEG'].items() if ref not in empty_refs),'empty_source_tile_placements':empty,'missing_tile_pairs':0,'fallback_tiles':0}
  composition={'schema':1,'source_origin':origin,'pixel_translation':[-left,-top],'half_tile_pixels':[24,24],'source_cell_basis_x':[24,-12],'source_cell_basis_y':[24,12],'statistics':stats,'tile_provenance':provenance,'composition_mode':'DISK_INDEXED_CHUNKS','maximum_output_texture_edge':chunk_edge,'full_canvas_allocated':False,'depth_status':'Original layers preserved; engine tails/occlusion unverified','terrain_collision':'UNKNOWN'}
  (out/'composition.json').write_text(json.dumps(composition,separators=(',',':'))+'\n')
  art={'status':('SEG_SOURCE_LAYOUT_REVIEW_ONLY' if any(c.get('source_format')=='SEG' for c in chunks) else 'S32_TI2_RENDERABLE') if output else 'EMPTY_ORIGINAL_SOURCE_RASTER','coordinate_space':'SOURCE_DERIVED_DISPLAY_ONLY','size':[width,height],'visible_bounds':visible,'chunks':output,'pixel_sha256':pixel_hash.hexdigest(),'overview':'overview.png','overview_sha256':hashlib.sha256((out/'overview.png').read_bytes()).hexdigest(),'source_to_png_transform':{'anchor':'source_cell_half_tile_origin','source_origin':origin,'basis_x':[24,-12],'basis_y':[24,12],'translation':[-left,-top]},'composition_file':'composition.json','composition_sha256':hashlib.sha256((out/'composition.json').read_bytes()).hexdigest(),'provenance':'Original source placements and TI2 pixels; streamed output, unknown collision'}
  return art,composition
