"""Compile a complete geographic ART DRAFT from new paintings and class IDs.

No original RGB pixels are read here. This does not produce collision data or
claim landmark/road fidelity. PNG panels are flattened; production occlusion
integration remains separate. Global material phase and halo prevent tile seams.
"""
from pathlib import Path
import argparse,json,hashlib,math,time
from PIL import Image,ImageOps,ImageFilter
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/maps/aden_world_draft'
TILE=4096
HALO=32
Image.MAX_IMAGE_PIXELS=None

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def periodic(im,seed=7):
 # Overlapping, independently oriented patches of NEW painted texture.
 # A periodic weighted blend avoids mirrored motifs and hard patch seams.
 src=np.asarray(im.convert('RGB'),dtype=np.float32);n=src.shape[0];assert n==src.shape[1]
 size=2048;stride=n//2;rng=np.random.default_rng(seed)
 acc=np.zeros((size,size,3),np.float32);weights=np.zeros((size,size),np.float32)
 window=np.maximum(np.outer(np.hanning(n),np.hanning(n)),.001).astype(np.float32)
 for y in range(0,size,stride):
  for x in range(0,size,stride):
   patch=np.rot90(src,int(rng.integers(4)))
   if rng.integers(2):patch=patch[:,::-1]
   ix=np.ix_((np.arange(n)+y)%size,(np.arange(n)+x)%size)
   acc[ix]+=patch*window[:,:,None];weights[ix]+=window
 rgb=np.clip(acc/weights[:,:,None],0,255).astype('uint8')
 return Image.fromarray(rgb).convert('RGBA')

def material_at(pattern,box):
 x,y,w,h=box;pw,ph=pattern.size;out=Image.new('RGBA',(w,h))
 for py in range(-(y%ph),h,ph):
  for px in range(-(x%pw),w,pw):out.paste(pattern,(px,py))
 return out

def load_sources():
 atlas=Image.open(BASE/'source/biome_materials.png').convert('RGBA')
 assert atlas.size==(1536,1024),atlas.size
 old=Image.open(ROOT/'assets/maps/aden_modular_pilot/source/materials.png').convert('RGBA')
 sources={1:old.crop((0,627,627,1254)).resize((256,256),Image.Resampling.LANCZOS),2:old.crop((627,0,1254,627)).resize((256,256),Image.Resampling.LANCZOS),3:old.crop((627,627,1254,1254)).resize((256,256),Image.Resampling.LANCZOS)}
 for i,code in enumerate([4,5,6,7,8,9]):sources[code]=atlas.crop(((i%3)*512,(i//3)*512,(i%3+1)*512,(i//3+1)*512))
 patterns={k:periodic(v,seed=24000+k) for k,v in sources.items()}
 sprites={};a=Image.open(BASE/'source/biome_objects.png').convert('RGBA')
 def sprite(name,im,width):
  bounds=im.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox();assert bounds,name
  im=im.crop(bounds);assert im.width>=width,(name,im.width,width)
  im=im.resize((width,round(im.height*width/im.width)),Image.Resampling.LANCZOS);sprites[name]=im
 for i,(name,width) in enumerate([('oak',210),('snow_fir',190),('cliff',240),('cactus',120),('basalt',210),('ruins',260)]):sprite(name,a.crop(((i%3)*512,(i//3)*512,(i%3+1)*512,(i//3+1)*512)),width)
 sprites['tree']=Image.open(ROOT/'assets/maps/aden_modular_pilot/compiled/tree-210.png').convert('RGBA')
 arch=BASE/'source/landmarks.png'
 if arch.exists():
  a=Image.open(arch).convert('RGBA')
  for name,rect,width in [('water_sanctuary',(0,0,805,553),640),('hut',(810,0,1536,520),280),('ruin_fort',(0,556,805,1024),600),('stone_bridge',(805,520,1536,1024),420)]:sprite(name,a.crop(rect),width)
 sprite('arena',Image.open(BASE/'source/arena.png').convert('RGBA'),1440)
 if 'ruin_fort' in sprites:
  im=sprites['ruin_fort'];sprites['ruin_house']=im.resize((280,round(im.height*280/im.width)),Image.Resampling.LANCZOS)
 sprites['ruin_wall_a']=Image.open(ROOT/'assets/maps/aden_modular_district_01/compiled/wall-280.png').convert('RGBA')
 sprites['ruin_wall_b']=Image.open(ROOT/'assets/maps/aden_city_region/compiled/retaining-280.png').convert('RGBA')
 return patterns,sprites

def placements(labels,protected,sprites,geo):
 rows=[];ox,oy=geo['world_bounds'][:2];city=(66000,14400,78288,22592)
 def put(name,x,y,tag):
  if name not in sprites:return
  if city[0]<=x<city[2] and city[1]<=y<city[3]:return
  im=sprites[name];rows.append({'asset':name,'foot':[int(x),int(y)],'position':[int(x-im.width*.5),int(y-im.height*.94)],'size':list(im.size),'id':tag})
 # Coordinate-hashed spacing is deterministic across independently rebuilt panels.
 for gy in range(8,labels.shape[0],14):
  for gx in range(8,labels.shape[1],14):
   n=((gx*73856093)^(gy*19349663))&0xffffffff
   px=min(labels.shape[1]-1,max(0,gx+(n%9)-4));py=min(labels.shape[0]-1,max(0,gy+((n>>8)%9)-4));c=int(labels[py,px])
   if protected[py,px]:continue
   x,y=ox+px*12,oy+py*12
   name=None
   if c==2 and n%5!=0:name='oak' if n%3 else 'tree'
   elif c==4 and n%7==0:name='snow_fir'
   elif c==5 and n%5==0:name='snow_fir' if y<12000 and n%2 else 'cliff'
   elif c==6 and n%13==0:name='cactus' if n%3 else 'cliff'
   elif c==7 and n%7==0:name='basalt'
   elif c==9 and n%9==0:name='tree'
   if name:put(name,x,y,f'decor_{gx}_{gy}')
 # Named sites preserve known regional centers; these are draft interpretations.
 sites=[('ruins',8332,3145),('ruin_fort',8247,3403),('hut',8859,4983),('water_sanctuary',10550,4330)]
 for j,(name,sx,sy) in enumerate(sites):
  put(name,sx*6,sy*6,f'landmark_{j}')
  for k in range(4):put('ruins' if name.startswith('ruin') else 'cliff',(sx+(k-2)*35)*6,(sy+45+(k%2)*20)*6,f'landmark_surround_{j}_{k}')
 for row in json.loads((BASE/'landmark_layout.json').read_text())['rows']:
  put(row['asset'],row['source_foot'][0]*6,row['source_foot'][1]*6,row['id'])
 return sorted(rows,key=lambda r:r['foot'][1])

def compile_world(limit=None):
 start=time.time();geo=json.loads((BASE/'geography.json').read_text());ox,oy,width,height=geo['world_bounds'];labels=np.asarray(Image.open(BASE/'semantic_labels.png'));protected=np.asarray(Image.open(BASE/'protected_placement_mask.png'))>0
 patterns,sprites=load_sources();rows=placements(labels,protected,sprites,geo);(BASE/'placements.json').write_text(json.dumps(rows,separators=(',',':'))+'\n')
 out=BASE/'panels';out.mkdir(exist_ok=True);cache=BASE/'sprite_cache';cache.mkdir(exist_ok=True)
 for name,im in sprites.items():im.save(cache/(name+'.png'))
 bins={}
 for row in rows:
  x,y=row['position'];w,h=row['size']
  for ty in range(max(0,(y-oy-HALO)//TILE),min(math.ceil(height/TILE),(y+h-oy+HALO)//TILE+1)):
   for tx in range(max(0,(x-ox-HALO)//TILE),min(math.ceil(width/TILE),(x+w-ox+HALO)//TILE+1)):bins.setdefault((tx,ty),[]).append(row)
 # Already authored city is reused ONCE at its registered world position.
 city_panels=[]
 for cy in range(2):
  for cx in range(2):city_panels.append((66000+cx*6144,14400+cy*4096,ROOT/f'assets/maps/aden_city_region/compiled/city_{cx}_{cy}_6144x4096.png'))
 manifest_path=BASE/'manifest.json';previous=json.loads(manifest_path.read_text()) if manifest_path.exists() else {};done={r['file']:r for r in previous.get('panels',[])}
 signature=hashlib.sha256((sha(Path(__file__))+sha(BASE/'semantic_labels.png')+sha(BASE/'placements.json')+''.join(sha(p) for p in sorted((BASE/'source').glob('*.png')))).encode()).hexdigest()
 if previous and previous.get('build_signature')!=signature:raise RuntimeError('Inputs changed: use a new output folder or explicitly remove stale draft panel outputs before resuming')
 result={'schema':1,'status':'IN_PROGRESS_GEOGRAPHIC_ART_DRAFT','world_bounds':geo['world_bounds'],'panel_size':TILE,'image_pixels_per_world_unit':1,'build_signature':signature,'production_enabled':False,'navigation_modified':False,'original_rgb_used_in_compiler':False,'flattened_foreground':True,'placement_count':len(rows),'panels':list(done.values()),'void_panels':[],'expected_grid_cells':math.ceil(width/TILE)*math.ceil(height/TILE)}
 built=0
 for ty in range(math.ceil(height/TILE)):
  for tx in range(math.ceil(width/TILE)):
   x,y=tx*TILE,ty*TILE;w,h=min(TILE,width-x),min(TILE,height-y);name=f'aden_{tx:02d}_{ty:02d}.png'
   gx=np.clip(np.arange(x-HALO,x+w+HALO)//12,0,labels.shape[1]-1);gy=np.clip(np.arange(y-HALO,y+h+HALO)//12,0,labels.shape[0]-1);classes=labels[gy[:,None],gx[None,:]]
   if not classes.any():result['void_panels'].append({'grid':[tx,ty],'world_bounds':[ox+x,oy+y,w,h]});continue
   if name in done and (out/name).exists():continue
   canvas=material_at(patterns[3],(ox+x-HALO,oy+y-HALO,w+2*HALO,h+2*HALO))
   for c in np.unique(classes):
    if c in (0,3):continue
    mask=Image.fromarray((classes==c).astype('uint8')*255).filter(ImageFilter.GaussianBlur(5))
    canvas.paste(material_at(patterns[int(c)],(ox+x-HALO,oy+y-HALO,w+2*HALO,h+2*HALO)),(0,0),mask)
   for row in bins.get((tx,ty),[]):canvas.alpha_composite(sprites[row['asset']],(row['position'][0]-(ox+x)+HALO,row['position'][1]-(oy+y)+HALO))
   for cx,cy,path in city_panels:
    left,top=max(ox+x-HALO,cx),max(oy+y-HALO,cy);right,bottom=min(ox+x+w+HALO,cx+6144),min(oy+y+h+HALO,cy+4096)
    if right>left and bottom>top:
     with Image.open(path) as im:canvas.paste(im.crop((left-cx,top-cy,right-cx,bottom-cy)),(left-(ox+x)+HALO,top-(oy+y)+HALO))
   # Keep original geographic void empty. This is semantic alpha, not copied RGB.
   valid=Image.fromarray((classes>0).astype('uint8')*255);canvas.putalpha(valid);canvas.paste((0,0,0,0),(0,0),ImageOps.invert(valid))
   canvas=canvas.crop((HALO,HALO,w+HALO,h+HALO));canvas.save(out/name,compress_level=6)
   record={'file':name,'world_bounds':[ox+x,oy+y,w,h],'sha256':sha(out/name),'bytes':(out/name).stat().st_size,'nonvoid_pixels':int((classes[HALO:HALO+h,HALO:HALO+w]>0).sum()),'objects':len(bins.get((tx,ty),[])),'review':'UNREVIEWED_DRAFT'};done[name]=record;result['panels']=list(done.values());manifest_path.write_text(json.dumps(result,indent=2)+'\n');built+=1
   print(json.dumps({'panel':name,'done':len(done),'grid_cells':result['expected_grid_cells'],'bytes':record['bytes'],'elapsed_seconds':round(time.time()-start)}),flush=True)
   if limit and built>=limit:return
 result['status']='FULL_EXTENT_RENDERED_GEOGRAPHIC_ART_DRAFT_NOT_PRODUCTION';result['panels']=list(done.values());result['nonvoid_pixels']=sum(r['nonvoid_pixels'] for r in done.values());result['png_bytes']=sum(r['bytes'] for r in done.values());result['elapsed_seconds']=round(time.time()-start);manifest_path.write_text(json.dumps(result,indent=2)+'\n');print('WORLD_DRAFT_RENDER_COMPLETE',len(done),'panels',len(result['void_panels']),'void cells',flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--limit',type=int);a=p.parse_args();compile_world(a.limit)
