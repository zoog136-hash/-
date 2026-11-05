"""Private review contact sheets using only completed real Godot viewport captures."""
import argparse,json,math
from pathlib import Path
from PIL import Image,ImageDraw

def generate(root,out):
 records=json.loads((root/'viewport-evidence.json').read_text());rows=[(key,row) for key,row in sorted(records.items()) if row['status']=='VIEWPORT_CAPTURED'];out.mkdir(parents=True,exist_ok=True);pages=[]
 for start in range(0,len(rows),64):
  page=Image.new('RGB',(1600,8*138),(24,24,24));draw=ImageDraw.Draw(page)
  for index,(key,row) in enumerate(rows[start:start+64]):
   x=(index%8)*200;y=(index//8)*138
   with Image.open(row['file']) as original:thumb=original.convert('RGB').resize((196,110),Image.Resampling.LANCZOS)
   page.paste(thumb,(x+2,y+2));draw.text((x+3,y+114),key.replace('base508_asset_','Asset '),fill='white');draw.text((x+3,y+125),'Land' if row['referenced'] else 'Unreferenced',fill=(180,180,180))
  path=out/f'original-map-viewports-{start//64+1:02}.png';page.save(path);pages.append(str(path))
 return {'real_viewport_captures':len(rows),'pages':pages,'scope':'Visual review only; original terrain collision remains unknown'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();print(json.dumps(generate(a.root,a.out)))
