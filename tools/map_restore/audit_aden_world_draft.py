"""Audit the complete emitted geographic draft, not production playability."""
from pathlib import Path
import json,hashlib
from PIL import Image
import numpy as np
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'assets/maps/aden_world_draft';Image.MAX_IMAGE_PIXELS=None
m=json.loads((BASE/'manifest.json').read_text());assert m['status']=='FULL_EXTENT_RENDERED_GEOGRAPHIC_ART_DRAFT_NOT_PRODUCTION'
labels=np.asarray(Image.open(BASE/'semantic_labels.png'));holes=int(np.sum(ndimage.binary_fill_holes(labels>0)&(labels==0)));assert holes==0,holes
ox,oy,width,height=m['world_bounds'];seen=set();area=0;painted=0;bytes_=0;max_file=0;transparent_only=0
for row in m['panels']:
 p=BASE/'panels'/row['file'];data=p.read_bytes();assert hashlib.sha256(data).hexdigest()==row['sha256'],p
 x,y,w,h=row['world_bounds'];key=((x-ox)//4096,(y-oy)//4096);assert key not in seen;seen.add(key)
 assert x==ox+key[0]*4096 and y==oy+key[1]*4096
 assert w==min(4096,width-key[0]*4096) and h==min(4096,height-key[1]*4096)
 with Image.open(p) as im:
  assert im.size==(w,h);hist=im.getchannel('A').histogram();actual=w*h-hist[0];assert actual==row['nonvoid_pixels'],(p,actual,row['nonvoid_pixels'])
 area+=w*h;painted+=actual;bytes_+=len(data);max_file=max(max_file,len(data));transparent_only+=int(actual==0)
for row in m['void_panels']:
 key=tuple(row['grid']);assert key not in seen;seen.add(key);area+=row['world_bounds'][2]*row['world_bounds'][3]
assert len(seen)==216 and area==width*height,(len(seen),area)
assert painted==int((labels>0).sum())*144,(painted,int((labels>0).sum())*144)
for rel,digest in json.loads((BASE/'source_sha256.json').read_text()).items():assert hashlib.sha256((BASE/rel).read_bytes()).hexdigest()==digest,rel
report={'grid_cells_accounted':len(seen),'png_panels':len(m['panels']),'fully_void_cells':len(m['void_panels']),'transparent_only_pngs':transparent_only,'world_rectangle_area':area,'new_art_nonvoid_pixels':painted,'original_exterior_void_pixels':area-painted,'png_bytes':bytes_,'max_single_png_bytes':max_file,'interior_transparent_holes':holes,'all_sha_and_dimensions_match':True,'all_alpha_coverage_matches_geography':True,'production_enabled':False,'foreground_flattened':True,'not_proof_of_geographic_or_collision_fidelity':True}
(BASE/'audit.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report),flush=True)
