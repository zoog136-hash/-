"""Compile generated object revision, preserving every world foot anchor."""
from pathlib import Path
import json,hashlib
from PIL import Image
from build_aden_mobile import ROOT,OUT,save_webp
BASE=ROOT/'tools/map_restore/aden_object_style'
def build():
 m=json.loads((OUT/'manifest.json').read_text());atlas=Image.open(BASE/'objects.png').convert('RGBA');report=[]
 specs={'oak':(0,0,768,551),'tree':(768,0,1536,552),'city_tree-210':(768,0,1536,552),'city_house-300':(0,552,768,1024),'city_merchant-360':(768,550,1536,1024)}
 for key,box in specs.items():
  old=json.loads((BASE/'baseline-assets.json').read_text())[key];im=atlas.crop(box);bounds=im.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox();assert bounds;im=im.crop(bounds)
  # Uniform fit, never stretch; use the former texture rectangle as a budget cap.
  factor=min(old['size'][0]/im.width,old['size'][1]/im.height,1);im=im.resize((round(im.width*factor),round(im.height*factor)),Image.Resampling.LANCZOS)
  asset=save_webp(im,OUT/old['file'],True);count=0
  for r in m['placements']:
   if r['asset']!=key:continue
   fx=.5;fy={'oak':200/212,'tree':202/214,'city_tree-210':201/214,'city_house-300':295/314,'city_merchant-360':294/313}[key]
   r['position']=[r['foot'][0]-round(im.width*fx),r['foot'][1]-round(im.height*fy)];r['size']=list(im.size);count+=1
  m['assets'][key]=asset;report.append({'asset':key,'instances':count,'before_size':old['size'],'after_size':asset['size'],'before_bytes':old['bytes'],'after_bytes':asset['bytes']})
 # One legacy tree sits against an existing walking boundary; keep its proven art.
 original=json.loads((ROOT/'assets/maps/aden_city_region/compiled/manifest.json').read_text())
 original=next(r for r in original['foreground'] if r['id']=='forest_tree_146')
 legacy=Image.open(BASE/'legacy-route-tree.webp.bin').convert('RGBA');key='city_tree_route_clearance';m['assets'][key]=save_webp(legacy,OUT/'objects'/('city_tree_route_clearance.webp.bin'),True)
 row=next(r for r in m['placements'] if r['id']=='city_forest_tree_146');row['asset']=key;row['position']=[66000+original['position'][0],14400+original['position'][1]];row['size']=original['size']
 for result in report:result['instances']=sum(r['asset']==result['asset'] for r in m['placements'])
 m['object_style_revision']='human-scaled-buildings-and-airy-trees-20261024';m['encoded_asset_bytes']=sum(r['bytes'] for r in m['ground'])+sum(r['bytes'] for r in m['assets'].values())+m['overview']['bytes'];(OUT/'manifest.json').write_text(json.dumps(m,separators=(',',':'))+'\n')
 receipt={'schema':1,'map_id':'aden_world','manifest_sha256':hashlib.sha256((OUT/'manifest.json').read_bytes()).hexdigest(),'encoded_asset_bytes':m['encoded_asset_bytes'],'navigation_changed':False};(ROOT/'data/maps/aden_mobile_pack.json').write_text(json.dumps(receipt,indent=2)+'\n');(BASE/'build-report.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
if __name__=='__main__':build()
