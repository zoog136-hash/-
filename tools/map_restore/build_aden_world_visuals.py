#!/usr/bin/env python3
"""Separate reference-guided Aden visual layer. NEVER writes navigation or old art.

S32 coordinates/IDs are observed; material and object identities are hypotheses,
because the uploaded A3 does not contain the corresponding TIL image archive.
The approved Giran layout and its original binary/art remain immutable inputs.
"""
from __future__ import annotations
import argparse, base64, hashlib, json, re, struct, zipfile, zlib
from collections import Counter, defaultdict
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from formats import origin, read_s32, write_s32

ARCHIVE_SHA='2d25c6d5408aaf29443167c4c82c30b32d1a83b16039d988471ba0c832eb7d20'
GRID_SHA='c22aa61ed083a3680230c659202503d7afaef30cb41b86d4655e9f843c81a7c4'
GIRAN=(928,672,128,192)
TOWNS=[('gludin','글루딘',180,743,16),('kent','켄트',601,716,17),
 ('giran','기란',981,750,0),('heine','하이네',1156,1173,18),
 ('aden','아덴',1514,1190,20),('oren','오렌',1605,220,19),
 ('silver_knight','은기사',634,1325,26),('fire_village','화전마을',297,381,21),
 ('elf_forest','요정 숲',603,279,23),('woodbec','우드벡',164,1124,22),
 ('weldern','웰던',1274,432,21),('rune_pc','루운 (PC 자료)',1967,122,20)]

def sha(b):return hashlib.sha256(b).hexdigest()
def scalar(value):
 if isinstance(value,np.generic):return value.item()
 raise TypeError('Unsupported visual data value: '+type(value).__name__)
def write(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,ensure_ascii=False,separators=(',',':'),default=scalar)+'\n')
def giran(x,y):return GIRAN[0]<=x<GIRAN[0]+GIRAN[2] and GIRAN[1]<=y<GIRAN[1]+GIRAN[3]
def pixel(x,y):return [round(float(24*(x+y+1)),2),round(float(12*(y-x+2048)),2)]

def navigation(root):
 d=json.loads((root/'data/map_remake/private/aden/definitions/aden_world.json').read_text())
 grid=np.zeros((1536,2048),dtype='uint8');masks=grid.copy()
 pack=root/'data/map_remake/private/aden'
 for x,y,w,h,shard,offset,length,digest in d['navigation']['chunks']:
  with (pack/f'navigation-{shard:02}.bin').open('rb') as f:f.seek(offset);b=zlib.decompress(f.read(length))
  if sha(b)!=digest:raise ValueError('Immutable navigation chunk SHA mismatch')
  grid[y*64:y*64+h,x*64:x*64+w]=np.frombuffer(b[:w*h],dtype='uint8').reshape(h,w)
  masks[y*64:y*64+h,x*64:x*64+w]=np.frombuffer(b[w*h:2*w*h],dtype='uint8').reshape(h,w)
 if sha(grid.tobytes())!=GRID_SHA:raise ValueError('Full source grid changed')
 return grid,masks,d

def source_layers(archive):
 if sha(archive.read_bytes())!=ARCHIVE_SHA:raise ValueError('Wrong A3 edition')
 floor=np.zeros((1536,2048),dtype='uint16');present=np.zeros_like(floor,dtype='uint8')
 groups=[];records=[];excluded=[];entrances=[]
 with zipfile.ZipFile(archive) as z:
  for n in sorted(z.namelist()):
   if not n.startswith('data/client_maps/normal/4/') or not n.endswith('.s32'):continue
   if not re.fullmatch('[0-9a-fA-F]{8}\\.s32',n.rsplit('/',1)[-1]):
    excluded.append({'path':n,'reason':'alternate segment or invalid canonical filename; not silently overlaid'});continue
   at=origin(n);ox,oy=at[0]-32448,at[1]-32064
   if not(0<=ox<2048 and 0<=oy<1536):raise ValueError('Out-of-grid S32')
   b=z.read(n);p=read_s32(b,n)
   if write_s32(p)!=b:raise ValueError('S32 lossless roundtrip mismatch: '+n)
   a=np.frombuffer(base64.b64decode(p['floor_bytes']),dtype=[('i','u1'),('t','<u2'),('u','u1')]).reshape(64,128)
   floor[oy:oy+64,ox:ox+64]=a['t'][:,::2];present[oy:oy+64,ox:ox+64]=1
   for g in p['objects']:
    ts=g['tiles']
    if not ts:continue
    xx=[t[0]/2 for t in ts];yy=[t[1] for t in ts];ids=Counter(t[4]&65535 for t in ts)
    groups.append([ox+min(xx),oy+min(yy),ox+max(xx),oy+max(yy),len(ts),ids.most_common(1)[0][0],g['id'],ox,oy])
   for ptl in p['portals']:
    entrances.append({'source_segment':n,'source_cell':[ox+ptl['x']//2,oy+ptl['y']],
      'raw_position':[ptl['x'],ptl['y']],
      'coordinate_status':'INFERRED_HALF_X_GRID_TRIGGER_CALIBRATION_NOT_RUN',
      'target_source_map_id':ptl['target_map_id'],'portal_id':ptl['portal_id'],
      'status':'OBSERVED_S32_RECORD_NOT_ADDED_TO_GAMEPLAY'})
   records.append({'path':n,'sha256':sha(b),'origin':at,'counts':p['counts'],'roundtrip':'PASS'})
 return floor,present,np.asarray(groups,dtype='float32'),records,excluded,entrances

def materials(floor,present,grid):
 # Explicit, reviewable semantic interpretation. No fabricated straight regions.
 families={1:[1173,1174,1211,1213,190,162,184,3237,3238,3239,3610,3611,3612,3613,3614],
  2:[29,51,52,59,87,89,90,1352,1353,1354,1355],
  3:[50,1308,1309,1310,1311,1312,1313,1314,3834,3835,3836],
  0:[313,314,315,3918,3919,3920,3921,3922,3988,3989,3990,4335,4336,3615,3616,3617],
  4:list(range(3430,3437))+[3791,3792,3793],
  5:[813,814,815,816,914,915,918,920,930,931,932,933],
  6:[654,655,656,657,658,659,660,661,662,663,664,665,666,667,3954,3955,3956],
  7:[3528,3529,3530,3531,3532,3533,3534,3599],
  10:[1230,1339,1340,1362,1363,1364]}
 a=np.full(floor.shape,255,dtype='uint8')
 for kind,ids in families.items():a[np.isin(floor,ids)]=kind
 known=a!=255
 nearest=ndi.distance_transform_edt(~known,return_distances=False,return_indices=True)
 a[~known]=a[tuple(nearest[:,~known])]
 # Missing source visuals are recorded; empty grid exterior gets ocean, not a
 # fictional extension of a village. Navigation remains exactly unchanged.
 a[(present==0)&(grid==0)]=15
 # Heine paving family shares older IDs. Only observed connected paving is
 # restyled; no rectangular town outline or terrain polygon is invented.
 yy,xx=np.indices(a.shape)
 heine=((xx-1156)**2+(yy-1173)**2)<150**2
 a[heine&(a==0)]=9
 return a,families,int((~known & (present!=0)).sum())

def build(root,archive,output,report):
 if output.exists():raise ValueError('Output exists: choose a separate destination')
 grid,masks,definition=navigation(root)
 floor,present,groups,segments,excluded,entrances=source_layers(archive)
 mat,families,unknown=materials(floor,present,grid)
 approved=json.loads((root/'data/aden_giran_review/layout.json').read_text())
 old=np.frombuffer((root/'data/aden_giran_review/surfaces.bin').read_bytes(),dtype='uint8').reshape(GIRAN[3],GIRAN[2])
 mat[GIRAN[1]:GIRAN[1]+GIRAN[3],GIRAN[0]:GIRAN[0]+GIRAN[2]]=old
 output.mkdir(parents=True)
 Image.fromarray(mat,'L').save(output/'materials.png')
 water=np.isin(mat,[3,13,15]);blocked=(masks==0)&(present!=0)&~water
 labels,count=ndi.label(blocked);boxes=ndi.find_objects(labels);sizes=np.bincount(labels.ravel())
 covered=np.zeros_like(mat,dtype=bool);occupied=np.zeros_like(mat,dtype=bool)
 props=[];kinds=Counter();group_evidence=Counter()
 def add(slot,x,y,width,kind,box=None,height=0,source_id=-1):
  if giran(x,y):return
  if not(0<=x<2048 and 0<=y<1536):return
  p=pixel(x,y)
  props.append([int(slot),*p,round(float(width),2),round(float(height),2),box or [int(x),int(y),1,1],kind,int(source_id)])
  kinds[kind]+=1;occupied[max(0,int(y)-2):int(y)+3,max(0,int(x)-2):int(x)+3]=True
 # Reuse the approved component-to-building method and its sizes, with regional
 # art. Source component and nearby S32 group evidence are recorded separately.
 for ident,sl in enumerate(boxes,1):
  if sl is None:continue
  by,bx=sl[0].start,sl[1].start;bh,bw=sl[0].stop-by,sl[1].stop-bx;n=int(sizes[ident])
  if giran(bx,by) or bw>30 or bh>30:continue
  cx,cy=bx+(bw-1)/2,by+(bh-1)/2
  town=min(TOWNS,key=lambda t:(cx-t[2])**2+(cy-t[3])**2)
  distance=(cx-town[2])**2+(cy-town[3])**2
  if n>=23 and 5<=bw<=26 and 5<=bh<=26 and n<bw*bh*.90 and distance<190**2:
   support=groups[(groups[:,0]<bx+bw+8)&(groups[:,2]>=bx-8)&(groups[:,1]<by+bh+8)&(groups[:,3]>=by-8)]
   if not len(support):continue
   slot=town[4]
   add(slot,cx,cy+(bw+bh)*.42,24*(bw+bh)*1.02,'building',[bx,by,bw,bh],12*(bw+bh)+140)
   covered[sl]|=labels[sl]==ident;group_evidence['building_with_s32_nearby']+=1
  elif 2<=n<=35 and bw<=8 and bh<=9:
   kind=int(mat[int(cy),int(cx)])
   slot=35 if kind==5 else 37 if kind==4 else 38 if kind==6 else 34 if kind==7 else 36 if distance<180**2 and town[0]=='elf_forest' else 32
   add(slot,cx,cy+(bw+bh)*.22,95+n*1.8,'tree',[bx,by,bw,bh]);covered[sl]|=labels[sl]==ident
 # Real S32 object group bounds locate larger forest/cliff/fort objects along
 # connected blockers. This is not an assertion that a tile ID identifies a tree.
 near_open=ndi.distance_transform_edt(masks==0)
 for x0,y0,x1,y1,n,tile,gid,ox,oy in groups:
  bw,bh=x1-x0+1,y1-y0+1;x,y=(x0+x1)/2,(y0+y1)/2
  ix,iy=int(x),int(y)
  if not(0<=ix<2048 and 0<=iy<1536) or giran(x,y):continue
  if n<28 or bw>28 or bh>28 or water[iy,ix] or occupied[iy,ix] or covered[iy,ix]:continue
  # Anchor on a genuine blocked source foot, rather than decorating a road.
  yy,xx=np.nonzero(blocked[max(0,iy-4):iy+5,max(0,ix-4):ix+5])
  if not len(xx):continue
  xs=xx+max(0,ix-4);ys=yy+max(0,iy-4);best=np.argmin((xs-x)**2+(ys-y)**2)
  ax,ay=int(xs[best]),int(ys[best])
  if occupied[ay,ax] or covered[ay,ax] or near_open[ay,ax]>10:continue
  material=int(mat[ay,ax]);town=min(TOWNS,key=lambda t:(ax-t[2])**2+(ay-t[3])**2)
  if material==5:slot=35;kind='snow_tree'
  elif material==4:slot=37;kind='palm'
  elif material==6:slot=43;kind='volcanic_rock'
  elif material in (7,11):slot=34;kind='swamp_tree'
  elif material in (0,9,10) and n>=150 and 12<=bw<=28:
   slot=25 if town[0]=='heine' else 24;kind='fortified_structure'
  elif material==8:slot=40+int(gid)%2;kind='cliff'
  else:slot=36 if town[0]=='elf_forest' else 32+int(gid)%2;kind='forest_tree'
  width=min(240,max(110,(bw+bh)*12))
  if kind=='fortified_structure':width=min(660,(bw+bh)*18)
  add(slot,ax,ay,width,kind,[ax-2,ay-2,5,5],source_id=int(tile));group_evidence['s32_group_at_source_blocker']+=1
 # Natural shore/cliff silhouettes follow SOURCE contour cells. There is no
 # straight authored boundary and no stone coping around unidentified terrain.
 edge=blocked&ndi.binary_dilation(masks!=0)
 for y,x in zip(*np.nonzero(edge)):
  if giran(x,y) or occupied[y,x] or covered[y,x]:continue
  if (x*17+y*31)%5:continue
  close_water=water[max(0,y-2):y+3,max(0,x-2):x+3].any()
  if close_water:slot=44 if int(mat[y,x])!=4 else 45;kind='shore'
  else:slot=40+int((x+y)%2);kind='cliff_edge'
  add(slot,x,y,95 if close_water else 85,kind)
 # Persist approved props exactly, only their runtime texture transitions change.
 for p in approved['props']:
  props.append([p['slot'],*p['position'],p['width'],p.get('height',0),p['source_box'],p['kind'],-1]);kinds['approved_giran_'+p['kind']]+=1
 chunks=defaultdict(list)
 for p in props:
  # Inverse projection, foot ownership, same 32-cell stream as the engine.
  total=p[1]/24-1;diff=p[2]/12-2048;x=(total-diff)/2;y=(total+diff)/2
  chunks[f'{max(0,min(63,int(x//32)))}_{max(0,min(47,int(y//32)))}'].append(p)
 for key,items in chunks.items():write(output/'props'/f'{key}.json',items)
 # Ground material map is a visual lookup only, not a navigation replacement.
 manifest={'schema':1,'map_id':'aden_world','source_grid_sha256':GRID_SHA,
  'source_definition_sha256':sha((root/'data/map_remake/private/aden/definitions/aden_world.json').read_bytes()),
  'dimensions':[2048,1536],'navigation_chunks':768,'visual_chunks':[64,48],
  'material_sha256':sha((output/'materials.png').read_bytes()),
  'props':len(props),'chunk_props':{k:len(v) for k,v in chunks.items()},'kinds':dict(kinds),
  'giran_approval':'USER_APPROVED_2026-10-16_SESSION','giran_baseline_commit':'8e888fe92a095166676755ae27a88240d32da49d',
  'giran_props_preserved':len(approved['props']),'material_identity':'INTERPRETED_NOT_RECOVERED_TIL',
  'object_identity':'INTERPRETED_S32_GROUPS_AND_SOURCE_BLOCKERS','original_art_recovered':False,
  'towns':[{'id':t[0],'name':t[1],'cell':list(t[2:4]),'source':'A3_GETBACK_SQL' if t[0]!='weldern' else 'A3_VOLCANO_GETBACK_SQL','m_fidelity':'UNVERIFIED'} for t in TOWNS]}
 write(output/'manifest.json',manifest)
 write(report,{'status':'PASS','source_archive_sha256':ARCHIVE_SHA,'selected_s32_crc':'PASS',
  'canonical_segments':len(segments),'unique_source_segments':int(present.sum()//4096),
  'source_coverage_cells':int(present.sum()),'uncovered_cells':int((present==0).sum()),
  'material_unidentified_cells_before_nearest_inference':unknown,'material_families':families,
  's32_groups_observed':len(groups),'placement_evidence':dict(group_evidence),'segments':segments,
  'excluded_variants_or_invalid_names':excluded,'observed_s32_entrances':entrances,
  'props':len(props),'kinds':dict(kinds),'navigation_regenerated':False,
  'source_grid_sha256':GRID_SHA,'original_art_recovered':False,'latest_lineagem_identity':'NOT_VERIFIED'})
 print(json.dumps({'props':len(props),'chunks_with_props':len(chunks),'kinds':dict(kinds)}))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--a3',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--report',type=Path,required=True)
 a=p.parse_args();build(a.root,a.a3,a.output,a.report)
