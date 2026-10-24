"""Recompile shared generated ground materials; never edit geography or placements."""
from pathlib import Path
import json,time,hashlib
import numpy as np
from PIL import Image,ImageDraw,ImageFilter,ImageOps
from compile_aden_world_draft import load_sources,periodic,material_at
from build_aden_mobile import ROOT,OUT,REVIEW,save_webp

def build():
 start=time.time();m=json.loads((OUT/'manifest.json').read_text());before=json.loads(json.dumps(m));patterns,_=load_sources()
 atlas=Image.open(ROOT/'tools/map_restore/aden_style/materials.png').convert('RGBA');w,h=atlas.size;w//=2;h//=2
 for code,(cx,cy) in {0:(0,0),1:(0,1),2:(1,0),3:(1,1)}.items():
  tile=atlas.crop((cx*w,cy*h,(cx+1)*w,(cy+1)*h)).resize((128,128) if code==0 else (256,256),Image.Resampling.LANCZOS)
  patterns[code]=periodic(tile,seed=24000+code)
 labels=np.asarray(Image.open(REVIEW/'corrected_labels.png'));ox,oy,width,height=m['world_bounds'];city=json.loads((ROOT/'assets/maps/aden_city_region/layout.json').read_text());palette={'stone':0,'water':1,'grass':2,'dirt':3}
 rows={(r['position'][0],r['position'][1]):r for r in m['ground']};changed=0
 panels=json.loads((ROOT/'assets/maps/aden_world_draft/manifest.json').read_text())['panels']
 for panel in panels:
  wx,wy,pw,ph=panel['world_bounds'];halo=32;bx,by=wx-halo,wy-halo;sw,sh=pw+64,ph+64
  gx=np.clip(np.arange(bx-ox,bx-ox+sw)//12,0,labels.shape[1]-1);gy=np.clip(np.arange(by-oy,by-oy+sh)//12,0,labels.shape[0]-1);classes=labels[gy[:,None],gx[None,:]]
  canvas=material_at(patterns[3],(bx,by,sw,sh))
  for c in np.unique(classes):
   if c in (0,3):continue
   mask=Image.fromarray((classes==c).astype('uint8')*255).filter(ImageFilter.GaussianBlur(9 if c==2 else 5))
   canvas.paste(material_at(patterns[int(c)],(bx,by,sw,sh)),(0,0),mask)
  # Use the exact existing city polygons at their registered world coordinates.
  if wx<78288 and wx+pw>66000 and wy<22592 and wy+ph>14400:
   cityground=material_at(patterns[0],(bx,by,sw,sh))
   for terrain in city['terrain']:
    mask=Image.new('L',(sw,sh));ImageDraw.Draw(mask).polygon([(round(p[0]*6-bx),round(p[1]*6-by)) for p in terrain['polygon']],fill=255)
    if terrain['material'] in ('grass','dirt'):mask=mask.filter(ImageFilter.GaussianBlur(7))
    cityground.paste(material_at(patterns[palette[terrain['material']]],(bx,by,sw,sh)),(0,0),mask)
   clip=Image.new('L',(sw,sh));ImageDraw.Draw(clip).rectangle((66000-bx,14400-by,78288-bx-1,22592-by-1),fill=255);canvas.paste(cityground,(0,0),clip)
  valid=Image.fromarray((classes>0).astype('uint8')*255);canvas.putalpha(valid);canvas.paste((0,0,0,0),(0,0),ImageOps.invert(valid));canvas=canvas.crop((halo,halo,pw+halo,ph+halo))
  for cy in range(0,ph,512):
   for cx in range(0,pw,512):
    pos=(wx+cx,wy+cy)
    if pos not in rows:continue
    r=rows[pos];im=canvas.crop((cx,cy,cx+r['size'][0],cy+r['size'][1]));path=OUT/r['file']
    with Image.open(path) as old:assert old.convert('RGBA').getchannel('A').tobytes()==im.getchannel('A').tobytes(),pos
    record=save_webp(im,path);changed+=record['sha256']!=r['sha256'];r.update(record)
  print(panel['file'],round(time.time()-start),flush=True)
 assert m['placements']==before['placements'] and m['assets']==before['assets']
 m['encoded_asset_bytes']=sum(r['bytes'] for r in m['ground'])+sum(r['bytes'] for r in m['assets'].values())+m['overview']['bytes']
 m['style_revision']='restrained-earth-materials-20261024';(OUT/'manifest.json').write_text(json.dumps(m,separators=(',',':'))+'\n')
 receipt={'schema':1,'map_id':'aden_world','manifest_sha256':hashlib.sha256((OUT/'manifest.json').read_bytes()).hexdigest(),'encoded_asset_bytes':m['encoded_asset_bytes'],'navigation_changed':False};(ROOT/'data/maps/aden_mobile_pack.json').write_text(json.dumps(receipt,indent=2)+'\n')
 report={'changed_ground_chunks':changed,'ground_chunks':len(rows),'before_bytes':before['encoded_asset_bytes'],'after_bytes':m['encoded_asset_bytes'],'alpha_exact':True,'placements_exact':True,'object_assets_exact':True,'pixel_density':1,'build_seconds':round(time.time()-start)}
 (ROOT/'tools/map_restore/aden_style/build-report.json').write_text(json.dumps(report,indent=2)+'\n');print(report,flush=True)
if __name__=='__main__':build()
