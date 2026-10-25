"""Exact multi-PNG/frame-canvas private preview; does not edit source art."""
from pathlib import Path
from PIL import Image,ImageDraw
import json
ROOT=Path(__file__).resolve().parents[5]
OUT=Path(__file__).resolve().parent
a=json.loads((OUT/'candidate.json').read_text())['actors']['monster:얼음 여왕']
frames=a['tracks'][0]['geometry']['frames']
sheet=Image.new('RGB',(6*300,280),'#535d66');d=ImageDraw.Draw(sheet)
for i,f in enumerate(frames):
    im=Image.open(ROOT/f['texture']).convert('RGBA');x,y,w,h=f['region'];crop=im.crop((x,y,x+w,y+h))
    scale=86/140*256/f['canvas_size'][0]*2
    crop=crop.resize((round(w*scale),round(h*scale)),Image.Resampling.NEAREST)
    ax,ay=f['source_anchor'];ox=i*300+150;gy=260
    sheet.paste(crop,(round(ox+(x-ax)*scale),round(gy+(y-ay)*scale)),crop)
    d.line((i*300,gy,(i+1)*300-1,gy),fill='#a1abb5')
    d.text((i*300+5,5),str(i)+' '+f['pose_label']+(' NEW' if f['newly_generated'] else ' REUSED'),fill='white')
sheet.save(OUT/'private/normalized-N-six-exact-alpha.png')
print('Private six-pose normalized density review saved')
