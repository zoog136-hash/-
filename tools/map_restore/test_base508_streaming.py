"""Streaming pixel-order test using original Tile7339 pixels in synthetic layouts.

These fixtures never count as restored original maps. --large crosses the old
160-million-pixel canvas limit without allocating that canvas.
"""
import argparse,base64,json,struct,hashlib
from pathlib import Path
from base508_ti2 import read_ti2,render
from base508_tile_cache import TileCache
from compose_base508 import compose
from compose_base508_streamed import compose_streamed
from base508_raster import pixel_digest
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source',type=Path,required=True);parser.add_argument('--inventory',type=Path,required=True);parser.add_argument('--out',type=Path,required=True);parser.add_argument('--large',action='store_true');parser.add_argument('--empty-only',action='store_true');args=parser.parse_args()
source=args.source;inventory=json.load(open(args.inventory/'tile_id_to_archive.json'))
if args.empty_only:
 if args.out.exists():raise ValueError('Use a new private fixture directory')
 args.out.mkdir(parents=True)
 ref=(7404<<8)|117
 chunk={'origin':[0,0],'floor_u32le':base64.b64encode(struct.pack('<8192I',*([ref]*8192))).decode(),'covers':[],'objects':[]}
 cache=TileCache(args.out/'cache.sqlite')
 art,metadata=compose_streamed([chunk],source,inventory,args.out/'empty',cache)
 assert art['status']=='EMPTY_ORIGINAL_SOURCE_RASTER' and art['chunks']==[] and metadata['statistics']['visual_source_tiles_restored']==0
 digest=hashlib.sha256()
 for _ in range(art['size'][1]):digest.update(bytes(art['size'][0]*4))
 assert art['pixel_sha256']==digest.hexdigest()==pixel_digest(args.out/'empty',art)
 cache.close()
 print('EMPTY_ORIGINAL_RASTER_OK: original alpha-empty frame; decoded source retained, visible-map count remains zero')
 raise SystemExit(0)

path=source/'Tile/7339.ti2';tid=int(path.stem);tile=read_ti2(path.read_bytes());index=0;ref=(tid<<8)|index;alternate=(tid<<8)|1
floor=base64.b64encode(struct.pack('<8192I',*([ref]*8192))).decode()
def chunk(origin):return {'origin':origin,'floor_u32le':floor,'covers':[[42,30,alternate]],'objects':[{'group':1,'parts':[[42,30,7,ref],[42,30,0,alternate]]}]}
root=args.out
if root.exists():raise ValueError('Use a new private test directory; existing outputs are preserved')
root.mkdir(parents=True);cache=TileCache(root/'cache.sqlite')
small=[chunk([0,0])];(root/'reference-order').mkdir(exist_ok=True)
image,meta=compose(small,source,inventory,root/'reference-order',cache)
art,meta=compose_streamed(small,source,inventory,root/'small-stream-order',cache,257)
assert art['size']==list(image.size)
assert art['pixel_sha256']==hashlib.sha256(image.tobytes()).hexdigest()==pixel_digest(root/'small-stream-order',art,257)
print('STREAMED_PIXEL_EQUAL: direct whole-raster and chunked row digest match; edge=257, overlapping layers',flush=True)
if not args.large:
 cache.close();raise SystemExit(0)
art,meta=compose_streamed([chunk([0,0]),chunk([1024,0])],source,inventory,root/'large-stream-order',cache)
assert art['size'][0]*art['size'][1]>160_000_000
assert not meta['full_canvas_allocated'] and all(max(r['size'])<=1024 for r in art['chunks'])
assert pixel_digest(root/'large-stream-order',art)==art['pixel_sha256']
print(json.dumps({'synthetic_layout_using_original_tile_pixels':True,'additional_original_maps_completed':0,'large_size':art['size'],'pixels':art['size'][0]*art['size'][1],'emitted_chunks':len(art['chunks']),'maximum_texture_edge':1024,'pixel_sha256':art['pixel_sha256'],'cache_new_source_decodes':cache.decodes}),flush=True)
cache.close()
