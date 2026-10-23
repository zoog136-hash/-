"""Private exact-region registration preview; no output images in user chat."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
actor = json.loads((OUT/"candidate.json").read_text())["actors"]["monster:얼음 여왕"]
width, height = 290, 230
sheet = Image.new("RGB", (width*len(actor["tracks"]), height*6+40), "#353a40")
draw = ImageDraw.Draw(sheet)
for col, track in enumerate(actor["tracks"]):
    source = Image.open(ROOT/track["texture"]).convert("RGBA")
    canvas = track["geometry"]["canvas_size"][0]
    scale = 86.0/140.0*256.0/canvas*2.0
    draw.text((col*width+8, 8), track["direction"]+" RUN | normalized86px x2", fill="white")
    for phase, frame in enumerate(track["geometry"]["frames"]):
        x,y,w,h = frame["region"]
        anchor_x, anchor_y = frame["source_anchor"]
        crop = source.crop((x,y,x+w,y+h))
        crop = crop.resize((round(w*scale), round(h*scale)), Image.Resampling.NEAREST)
        ground_y = 40+(phase+1)*height-12
        actor_x = col*width+width//2
        sheet.paste(crop, (round(actor_x+(x-anchor_x)*scale), round(ground_y+(y-anchor_y)*scale)), crop)
        draw.line((col*width,ground_y,(col+1)*width-1,ground_y), fill="#7a8795")
        draw.text((col*width+5,ground_y-height+18), f'phase{phase} sourceSlot{frame["source_slot"]}', fill="white")
(OUT/"private").mkdir(exist_ok=True)
sheet.save(OUT/"private/normalized-run7-contactsheet.png")

# Full source contact cells with explicitly selected anatomical landmarks.
measure = Image.new("RGB",(1100,330*len(actor["tracks"])),"#353a40")
md = ImageDraw.Draw(measure)
for row, track in enumerate(actor["tracks"]):
    source=Image.open(ROOT/track["texture"]).convert("RGBA")
    cw,ch=source.width/2,source.height/3
    for slot, landmark in enumerate(track["body_scale_measurement"]["contacts"]):
        cell = source.crop((round(cw*slot),0,round(cw*(slot+1)),round(ch)))
        factor = min(530/cell.width,300/cell.height)
        cell=cell.resize((round(cell.width*factor),round(cell.height*factor)),Image.Resampling.NEAREST)
        ox,oy=slot*550,row*330+25
        measure.paste(cell,(ox,oy),cell)
        for key,color in [("crown_apex_xy","#ff9e36"),("contact_sole_xy","#6affb1")]:
            px,py=landmark[key];px=ox+(px-slot*cw)*factor;py=oy+py*factor
            md.ellipse((px-4,py-4,px+4,py+4),outline=color,width=2)
            md.line((ox,py,ox+cell.width,py),fill=color,width=1)
        md.text((ox+5,row*330+3),track['direction']+f' contactSourceSlot{slot} bodyHeight='+str(landmark['crown_to_sole_height']),fill='white')
measure.save(OUT/"private/crown-sole-landmarks.png")
print("Private normalized RUN7 and manual crown/sole registration evidence saved")
