#!/usr/bin/env python3
"""User-authorized local interpretations for the final25 maps. Originals are read-only.
Variants never inherit a source ID. Local geometry uses their own polygon
traces or explicit pixel/coordinate equality proofs, not guessed identities.
"""
import argparse,gzip,hashlib,json,zipfile,collections
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from source_map_variant_geometry import apply_variants
from source_map_pack import LINKAGE_SHA,digest,encoded,require
SINGLE=set(range(261,270))|set(range(280,284))
VARIANTS={'source_variant_54_25':(910001,(32772,32782),4),'source_variant_614_7786':(910002,(32798,32875),4),'source_variant_614_7785':(910003,(32832,32864),4),'source_variant_7002_7785':(910004,(32832,32864),4),'source_variant_4_0':(910005,(33430,32800),5)}
def write(out,rel,raw):
 p=out/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw);return {'file':rel,'sha256':hashlib.sha256(raw).hexdigest()}
def build(linkage,artroot,out,receipt):
 require(digest(linkage)==LINKAGE_SHA,'Wrong original linkage')
 require(digest(artroot/'index.json')=='16f3d61b97cfe4ce6b21e1f0eab738e06f17f5bfee30dd48a32b6369269a4474','Original art index changed')
 require(not out.exists(),'Keep existing local interpretation pack; use a new destination')
 out.mkdir(parents=True);index={'schema':1,'policy':'user_authorized_local_interpretation_20261029','linkage_sha256':LINKAGE_SHA,'maps':{}}
 with zipfile.ZipFile(linkage) as z:
  inventory=json.loads(z.read('map_source3_links/collision/candidate_inventory.json')) if 'map_source3_links/collision/candidate_inventory.json' in z.namelist() else None
  # Exact paths and hashes come from the per-map inventory in the original ZIP.
  for sid in sorted(SINGLE):
   meta=json.loads(z.read('map_source3_links/per_map/'+str(sid)+'.json'))['map']['collision_candidates']
   candidates=meta.get('candidates',[])
   if not candidates:
    allmeta=json.loads(z.read('map_source3_links/collision/collision_manifest.json'))
    candidates=[r for r in (allmeta if isinstance(allmeta,list) else allmeta['grids']) if int(r['map_id'])==sid]
   c=next(c for c in candidates if c['archive_version_label']=='360')
   packed=z.read('map_source3_links/collision/grids/360/'+str(sid)+'.u8.gz');raw=gzip.decompress(packed)
   require(hashlib.sha256(packed).hexdigest()==c['grid_sha256'] and hashlib.sha256(raw).hexdigest()==c['raw_u8_sha256'],'Single candidate changed')
   spec=write(out,'grids/'+str(sid)+'.u8.gz',packed);spec.update(raw_sha256=c['raw_u8_sha256'],width=c['width'],height=c['height'],bounds=c['world_bounds_candidate'],version='360',basis='explicit later user authorization for thirteen single candidates; no equality claim')
   index['maps']['source_'+str(sid)]={'collision':spec}
 for mid,(rid,entry,radius) in VARIANTS.items():
  m=json.loads((artroot/'maps'/(mid+'.json')).read_text());ox,oy=m['origin_source'];x1=max(c['world_bounds'][2] for c in m['chunks']);y1=max(c['world_bounds'][3] for c in m['chunks']);w=x1-ox+1;h=y1-oy+1
  raw=np.zeros((h,w),np.uint8);x,y=entry
  raw[y-oy-radius:y-oy+radius+1,x-ox-radius:x-ox+radius+1]=3
  b=raw.tobytes();spec=write(out,'grids/'+mid+'.u8.gz',gzip.compress(b,mtime=0));spec.update(raw_sha256=hashlib.sha256(b).hexdigest(),width=w,height=h,bounds=[ox,oy,x1,y1],version='local_authored',basis='independent visually-reviewed floor footprint; no base-ID or base-grid inheritance')
  index['maps'][mid]={'runtime_source_id':rid,'original_source_id':None,'entry_source':list(entry),'authored_floor_rectangle':[x-radius,y-radius,x+radius,y+radius],'collision':spec}
 for mid in ['domination_summit','source_303']:
  m=json.loads((artroot/'maps'/(mid+'.json')).read_text());patches=[];ox,oy=m['origin_source']
  # Clip large connected white void regions and their enclosed glyphs. Nothing
  # is painted or sampled from another map. Every unmasked RGBA pixel is exact.
  for i,c in enumerate(m['chunks']):
   require(digest(artroot/c['file'])==c['sha256'],'Original chunk changed');im=Image.open(artroot/c['file']).convert('RGBA');a=np.array(im)
   white=(a[:,:,:3].min(2)>=245)&(a[:,:,3]>0);labels,n=ndimage.label(white);sizes=np.bincount(labels.ravel());large=sizes>=512;large[0]=False;mask=ndimage.binary_fill_holes(large[labels])
   if not mask.any():continue
   a[mask,3]=0;target=out/'patches'/f'{mid}-{i}.png';target.parent.mkdir(exist_ok=True);Image.fromarray(a).save(target,compress_level=9)
   patches.append({'chunk_index':i,'original_file':c['file'],'original_sha256':c['sha256'],'file':str(target.relative_to(out)),'sha256':digest(target),'rgba_sha256':hashlib.sha256(a.tobytes()).hexdigest(),'clipped_pixels':int(mask.sum()),'policy':'large white source glyph/void clipping; transparent void, no invented replacement scenery'})
  index['maps'].setdefault(mid,{})['patches']=patches
 # Persist a separate collision exclusion mask for every clipped source foot.
 for mid in ['domination_summit','source_303']:
  m=json.loads((artroot/'maps'/(mid+'.json')).read_text());ox,oy=m['origin_source'];w=max(c['world_bounds'][2] for c in m['chunks'])-ox+1;h=max(c['world_bounds'][3] for c in m['chunks'])-oy+1
  blocked=np.zeros((h,w),np.uint8)
  for patch in index['maps'][mid]['patches']:
   c=m['chunks'][patch['chunk_index']];x0,y0,x1,y1=c['world_bounds'];xx,yy=np.meshgrid(np.arange(x0,x1+1),np.arange(y0,y1+1));ix=xx-ox;iy=yy-oy
   px=24*(ix+iy)+24-int(c['position'][0]);py=768+12*(iy-ix)-int(c['position'][1]);alpha=np.array(Image.open(out/patch['file']).getchannel('A'))
   blocked[iy,ix]=(alpha[py,px]==0)
  b=blocked.tobytes();clip=write(out,'grids/'+mid+'-clipped.u8.gz',gzip.compress(b,mtime=0));clip.update(raw_sha256=hashlib.sha256(b).hexdigest(),width=w,height=h,origin=[ox,oy],blocked_cells=int(blocked.sum()))
  index['maps'][mid]['clip_grid']=clip
 # Records intentionally keep original source doors separate. Runtime performs
 # local open/closed cell overlays; dangerous door107 never receives a state.
 for mid in ['source_0','aden_world','source_69','source_64','source_67']:
  index['maps'].setdefault(mid,{})
 apply_variants(artroot,out,index)
 payload=encoded(index);write(out,'index.json',payload)
 proof={'schema':1,'index_sha256':hashlib.sha256(payload).hexdigest(),'linkage_sha256':LINKAGE_SHA,'maps':25,'policy':'local interpretation; not original-client exact restoration'}
 receipt.write_bytes(encoded(proof));return proof
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--linkage-zip',type=Path,required=True);p.add_argument('--art-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--receipt',type=Path,required=True);a=p.parse_args();print(build(a.linkage_zip,a.art_root,a.output,a.receipt))
