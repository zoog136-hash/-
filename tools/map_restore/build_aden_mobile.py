"""Build layered, full-density WebP streaming data. Original PNGs stay immutable."""
from pathlib import Path
import json,hashlib,math,time,io
from PIL import Image,ImageDraw,ImageFilter,ImageOps
import numpy as np
from scipy import ndimage
from compile_aden_world_draft import load_sources,material_at
ROOT=Path(__file__).resolve().parents[2];DRAFT=ROOT/'assets/maps/aden_world_draft';OUT=ROOT/'assets/maps/aden_world_mobile';REVIEW=ROOT/'tools/map_restore/aden_mobile_review';Image.MAX_IMAGE_PIXELS=None

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save_webp(im,path,lossless=False):
 im.save(path,format='WEBP',quality=90 if not lossless else 100,lossless=lossless,method=2,exact=True)
 return {'file':str(path.relative_to(OUT)),'size':list(im.size),'sha256':sha(path),'bytes':path.stat().st_size}

def raw_blocker_sprite(name):
 if name in ('oak','cliff','basalt'):
  im=Image.open(DRAFT/'source/biome_objects.png').convert('RGBA');box={'oak':(0,0,512,512),'cliff':(1024,0,1536,512),'basalt':(512,512,1024,1024)}[name]
 else:
  im=Image.open(DRAFT/'source/landmarks.png').convert('RGBA');box={'hut':(810,0,1536,520),'ruin_fort':(0,556,805,1024)}[name]
 im=im.crop(box);return im.crop(im.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox())

def build():
 start=time.time();OUT.mkdir(exist_ok=True);(OUT/'ground').mkdir(exist_ok=True);(OUT/'objects').mkdir(exist_ok=True);REVIEW.mkdir(exist_ok=True);(REVIEW/'.gdignore').touch()
 labels=np.asarray(Image.open(DRAFT/'semantic_labels.png')).copy();original=labels.copy();geo=json.loads((DRAFT/'geography.json').read_text());ox,oy,width,height=geo['world_bounds']
 # Local reviewed edits only. Original draft and original reference stay intact.
 roof=Image.new('L',(labels.shape[1],labels.shape[0]));ImageDraw.Draw(roof).polygon([((x-1967)/2,(y-369)/2) for x,y in [(10350,4228),(10410,4198),(10480,4238),(10423,4275)]],fill=1)
 roof_mask=np.asarray(roof).astype(bool)&(labels==1);labels[roof_mask]=3
 source=Image.open('/workspace/map-originals/Aden.png').convert('RGB').crop((5100,2300,6600,3200)).resize((750,450),Image.Resampling.BOX);rgb=np.asarray(source).astype(float)
 x0,y0=(5100-1967)//2,(2300-369)//2;part=labels[y0:y0+450,x0:x0+750];allowed=np.isin(part,[3,5]);gray=rgb.mean(2);ridge=ndimage.gaussian_filter(gray,1.5)<112
 part[allowed]=3;part[allowed&ridge]=5
 Image.fromarray(labels).save(REVIEW/'corrected_labels.png')
 corrections={'reference_sha256':sha(Path('/workspace/map-originals/Aden.png')),'roof_water_cells_corrected':int(roof_mask.sum()),'mountain_region_source_bounds':[5100,2300,1500,900],'semantic_cells_changed':int((labels!=original).sum()),'landmark_move':{'id':'landmark_3','old_source_foot':[10550,4330],'new_source_foot':[10410,4305]},'collision_changed':False,'reference_rgb_used_as_output':False};(REVIEW/'corrections.json').write_text(json.dumps(corrections,indent=2)+'\n')
 patterns,sprites=load_sources();placements=json.loads((DRAFT/'placements.json').read_text())
 for r in placements:
  if r['id']=='landmark_3':
   delta=[10410*6-r['foot'][0],4305*6-r['foot'][1]];r['foot']=[10410*6,4305*6];r['position']=[r['position'][0]+delta[0],r['position'][1]+delta[1]]
 # Restore visible art for every existing explicit blocker, without new collisions.
 spec=json.loads((ROOT/'data/maps/aden_faith_png_plan.json').read_text())['maps']['aden_world']
 blocker_rows=[]
 for c in spec['collision']:
  if c['id']=='palace_plaza_fountain':continue # Exact matching city fountain already authored.
  pts=c.get('points');center=c.get('center') or [sum(p[i] for p in pts)/len(pts) for i in range(2)]
  name='oak' if 'tree' in c['id'] or 'stump' in c['id'] else ('basalt' if 'lava' in c['id'] or 'basalt' in c['id'] else ('hut' if 'hut' in c['id'] else 'cliff'))
  if pts:name='ruin_fort' if 'ruin' in c['id'] else name
  im=raw_blocker_sprite(name);target=min(im.width,round((max(p[0] for p in pts)-min(p[0] for p in pts))*6) if pts else round(c['radius']*12));target=max(60,target);asset='blocker_'+c['id'];im=im.resize((target,round(im.height*target/im.width)),Image.Resampling.LANCZOS);sprites[asset]=im
  foot=[round(center[0]*6),round(center[1]*6)];r={'asset':asset,'foot':foot,'position':[foot[0]-im.width//2,foot[1]-round(im.height*.85)],'size':list(im.size),'id':'existing_'+c['id'],'existing_collision':c['id']};blocker_rows.append(r)
 placements+=blocker_rows
 # Registered city uses its original separated ground and foreground, not flattened PNGs.
 citybase=ROOT/'assets/maps/aden_city_region/compiled';city=json.loads((citybase/'manifest.json').read_text())
 for r in city['foreground']:
  asset='city_'+r['file'].removesuffix('.png');sprites.setdefault(asset,Image.open(citybase/r['file']).convert('RGBA'))
  placements.append({'asset':asset,'foot':[66000+r['foot'][0],14400+r['foot'][1]],'position':[66000+r['position'][0],14400+r['position'][1]],'size':r['size'],'id':'city_'+r['id']})
 assets={name:save_webp(im,OUT/'objects'/(name+'.webp.bin'),True) for name,im in sprites.items()}
 (REVIEW/'placements_before_review.json').write_text(json.dumps(placements,separators=(',',':'))+'\n')
 rows=[];citygrounds=[]
 for r in city['ground_chunks']:citygrounds.append((66000+r['position'][0],14400+r['position'][1],citybase/'ground'/r['file'],r['size']))
 # One bounded 4096px CPU work area; emitted GPU chunks never exceed 512px.
 panel_manifest=json.loads((DRAFT/'manifest.json').read_text())
 for panel in panel_manifest['panels']:
  wx,wy,w,h=panel['world_bounds'];x,y=wx-ox,wy-oy;halo=32
  gx=np.clip(np.arange(x-halo,x+w+halo)//12,0,labels.shape[1]-1);gy=np.clip(np.arange(y-halo,y+h+halo)//12,0,labels.shape[0]-1);classes=labels[gy[:,None],gx[None,:]]
  canvas=material_at(patterns[3],(wx-halo,wy-halo,w+2*halo,h+2*halo))
  for c in np.unique(classes):
   if c in (0,3):continue
   mask=Image.fromarray((classes==c).astype('uint8')*255).filter(ImageFilter.GaussianBlur(5));canvas.paste(material_at(patterns[int(c)],(wx-halo,wy-halo,w+2*halo,h+2*halo)),(0,0),mask)
  for cx,cy,path,size in citygrounds:
   left,top=max(wx-halo,cx),max(wy-halo,cy);right,bottom=min(wx+w+halo,cx+size[0]),min(wy+h+halo,cy+size[1])
   if right>left and bottom>top:
    with Image.open(path) as im:canvas.paste(im.crop((left-cx,top-cy,right-cx,bottom-cy)),(left-wx+halo,top-wy+halo))
  valid=Image.fromarray((classes>0).astype('uint8')*255);canvas.putalpha(valid);canvas.paste((0,0,0,0),(0,0),ImageOps.invert(valid));canvas=canvas.crop((halo,halo,w+halo,h+halo))
  for cy in range(0,h,512):
   for cx in range(0,w,512):
    im=canvas.crop((cx,cy,min(cx+512,w),min(cy+512,h)))
    if not im.getchannel('A').getbbox():continue
    name=f'{x+cx}_{y+cy}.webp.bin';r=save_webp(im,OUT/'ground'/name);r['position']=[wx+cx,wy+cy];rows.append(r)
  print(json.dumps({'panel':panel['file'],'ground_chunks':len(rows),'elapsed_s':round(time.time()-start)}),flush=True)
 overview=Image.open(ROOT/'docs/aden-world-draft-20261024/evidence/world-overview.png');overview.thumbnail((512,512));ov=save_webp(overview,OUT/'overview.webp.bin',True)
 m={'schema':1,'map_id':'aden_world','world_bounds':geo['world_bounds'],'codec':'webp','ground_quality':90,'image_pixels_per_world_unit':1,'chunk_size':512,'ground':rows,'assets':assets,'placements':placements,'overview':ov,'navigation_modified':False,'raw_draft_bytes_preserved':panel_manifest['png_bytes'],'encoded_asset_bytes':sum(r['bytes'] for r in rows)+sum(r['bytes'] for r in assets.values())+ov['bytes'],'build_seconds':round(time.time()-start),'status':'AWAITING_FOOTPRINT_REVIEW'}
 (OUT/'manifest.json').write_text(json.dumps(m,separators=(',',':'))+'\n');print('MOBILE_COMPILE_COMPLETE',m['encoded_asset_bytes'],len(rows),len(placements),flush=True)
if __name__=='__main__':build()
