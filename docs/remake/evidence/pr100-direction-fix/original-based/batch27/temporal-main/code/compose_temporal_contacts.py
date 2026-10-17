#!/usr/bin/env python3
"""Compose diagnostic storyboards ONLY from atomic rendered Main crops.

No source atlas is opened, no animation is selected, and no source art is changed.
Every source crop is validated against the capture's SHA recorded by Godot.
The same 1/2 resize is used for every pose in all contact sheets.
"""
from pathlib import Path
import argparse,hashlib,json
from PIL import Image,ImageDraw,ImageFont

p=argparse.ArgumentParser();p.add_argument('report');p.add_argument('--output',required=True);a=p.parse_args()
summary=json.loads(Path(a.report).read_text());assert summary['rendered'], 'Rendered Main evidence is required'
assert not summary['failures'], summary['failures']
out=Path(a.output);out.mkdir(parents=True,exist_ok=True);records=[]
roles=['idle','walk','attack','hit','death'];directions=['E','SE','S','SW','W','NW','N','NE']
font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',13)
for case in summary['cases']:
 report=json.loads(Path(case['report']).read_text());directory=out/case['slug'];directory.mkdir(exist_ok=True)
 for di in directions:
  entries={r['role']:r for r in report['roles'] if r['compass']==di};assert set(entries)==set(roles)
  rows=max(r['native_frames'] for r in entries.values());w,h=288,240;header,caption=54,42
  sheet=Image.new('RGB',(w*5,header+rows*(h+caption)),'#202630');draw=ImageDraw.Draw(sheet)
  draw.text((9,7),f"{case['slug']} | {di} | Actual Main / QA-clocked production MotionController",fill='white',font=font)
  draw.text((9,27),'Rows: native phases. Columns: idle / walk / attack / hit / death. Fixed viewport scale. Sim timestamps, not wall-time performance.',fill='#bfc9d5',font=font)
  sources=[]
  for col,role in enumerate(roles):
   entry=entries[role];captures={int(x['frame']):x for x in entry['captures']};assert len(captures)==entry['native_frames'], (di,role,captures)
   for phase,cap in captures.items():
    source=Path(cap['path']);digest=hashlib.sha256(source.read_bytes()).hexdigest();assert digest==cap['sha256'],source
    im=Image.open(source).convert('RGB');assert im.size==(576,480);im=im.resize((w,h),Image.Resampling.LANCZOS)
    y=header+phase*(h+caption);sheet.paste(im,(w*col,y+caption))
    draw.text((w*col+6,y+3),f'{role} phase {phase} | sim {cap["simulation_seconds"]:.4f}s',font=font,fill='white')
    draw.text((w*col+6,y+21),f'{cap["resolved_key"]} | draw {cap["render_frame"]}',font=font,fill='#c3cdda')
    sources.append({'role':role,'phase':phase,'capture':str(source),'sha256':digest,'simulation_seconds':cap['simulation_seconds'],'wall_microseconds':cap['wall_microseconds'],'render_frame':cap['render_frame'],'frame_token':cap['frame_token']})
  dest=directory/f'{di}-temporal-contact.png';assert not dest.exists(),f'Refuse overwrite: {dest}';sheet.save(dest)
  records.append({'case':case['slug'],'direction':di,'path':str(dest),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'sources':sources})
manifest={'source_summary':str(Path(a.report).resolve()),'source_summary_sha256':hashlib.sha256(Path(a.report).read_bytes()).hexdigest(),'scope':'Diagnostic contacts from actual Main frame_post_draw readbacks, production controller selected textures; QA-clocked sim timestamps; no AI/combat/performance claim','uniform_resize':'576x480 actual viewport crop to288x240; exact uniform1/2 eachpose; no alpha extraction, atlas assembly or perpose scaling','contacts':records}
(out/'temporal-contact-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps({'contacts':len(records),'manifest':str(out/'temporal-contact-manifest.json')}))
