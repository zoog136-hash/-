from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib,argparse
parser=argparse.ArgumentParser();parser.add_argument('--run',type=Path,required=True);args=parser.parse_args();BASE=args.run.resolve()
OUT=BASE/'review-matrices';OUT.mkdir(exist_ok=True)
REPORT=BASE/'report-cases/black-rabbit-girl-transform328.json'
r=json.loads(REPORT.read_text());temporal=r['transform_temporal'];assert temporal['native_phases']==112==temporal['rendered_native_phases'];assert not r.get('failures',[])
roles=['idle','walk','attack','hit','death'];compass=['E','SE','S','SW','W','NW','N','NE'];font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16);title=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',19);records=[];observed=set()
for direction,name in enumerate(compass):
 entries=[]
 for role in roles:
  row=next(v for v in temporal['roles'] if v['direction']==direction and v['role']==role)
  native=sorted(row['captures'],key=lambda v:v['frame']);assert len(native)==row['native_frames']
  for e in native:
   p=Path(e['path']);assert p.exists() and hashlib.sha256(p.read_bytes()).hexdigest()==e['sha256'];assert e['animation']==row['expected_key'];assert (name,role,e['frame']) not in observed;observed.add((name,role,e['frame']));entries.append((role,e))
 assert len(entries)==14
 output=OUT/f'actual-Main-temporal-{name}-14poses.png';assert not output.exists()
 sheet=Image.new('RGB',(1408,1442),'#17212b');d=ImageDraw.Draw(sheet);d.text((12,9),f'ACTUAL MAIN / {name} / 14 native phases selected only by production controller advance/apply',font=title,fill='white');d.text((12,37),'120Hz QA simulation; whole Main paused. Each entire704x640 capture shown uniformly352x320. Original PNGs unchanged.',font=font,fill='#d2d9e0')
 evidence=[]
 for index,(role,e) in enumerate(entries):
  x=(index%4)*352;y=70+(index//4)*343
  with Image.open(e['path']) as raw:
   assert raw.size==(704,640);sheet.paste(raw.convert('RGB').resize((352,320),Image.Resampling.NEAREST),(x,y+23))
  d.text((x+8,y+2),f'{role} {e["frame"]}  sim{e["simulation_seconds"]:.4f}s / draw{e["render_frame"]}',font=font,fill='white');evidence.append({'cell':index,'role':role,'phase':e['frame'],'capture_path':e['path'],'capture_sha256':e['sha256'],'animation':e['animation'],'simulation_seconds':e['simulation_seconds'],'render_frame':e['render_frame'],'whole_crop_uniform_scale':0.5})
 d.text((716,1392),'Derived review contact sheet only; no source artwork/frame changes.',font=font,fill='#d2d9e0');sheet.save(output);records.append({'direction':name,'matrix':str(output),'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'poses':evidence})
assert len(observed)==112
out={'source_report':str(REPORT),'source_report_sha256':hashlib.sha256(REPORT.read_bytes()).hexdigest(),'actual_captures':112,'derived_matrices':8,'source_images_changed':False,'single_uniform_whole_capture_scale':0.5,'matrices':records};(OUT/'matrix-index.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps({'matrices':8,'native_actual_Main_captures':112,'output':str(OUT)}))
