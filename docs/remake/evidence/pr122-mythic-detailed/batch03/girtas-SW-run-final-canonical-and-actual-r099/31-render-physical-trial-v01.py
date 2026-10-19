from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw
p=Path(__file__).parent;raw=p/'girtas-SW-run-v03six.png';source=Image.open(raw).convert('RGBA');g=json.loads((p/'runtime-geometry.trial-v01.json').read_text());m=json.loads((p/'common-groundprojection-hypothesis.v01.DRAFT.json').read_text());r=Path('/workspace/twilight');reg=json.loads((r/'data/pr122_native_locomotion_staging.json').read_text());idle=next(t for t in reg['actors']['transform:267']['tracks'] if (t['direction'],t['role'])==('SW','idle'));ip=r/idle['texture'];im=Image.open(ip).convert('RGBA');ig=idle['geometry'];ifr=ig['frames'][0];x,y,w,h=ifr['region'];ic=ifr.get('canvas_size',ig['canvas_size'])[0];mx,my=ifr['margin'][:2];can=Image.new('RGBA',(ic,ic));can.paste(im.crop((x,y,x+w,y+h)),(mx,my));imgs=[can.resize((1024,1024),Image.Resampling.LANCZOS)];labels=['CURRENT actual SWidle C'+str(ic)]
for i,f in enumerate(g['frames']):
 x,y,w,h=f['region'];c=f.get('canvas_size',g['canvas_size'])[0];mx,my=f['margin'][:2];can=Image.new('RGBA',(c,c));can.paste(source.crop((x,y,x+w,y+h)),(mx,my));imgs.append(can.resize((1024,1024),Image.Resampling.LANCZOS));labels.append('DRAFT RUN'+str(i)+' C'+str(c))
panel=Image.new('RGB',(2048,1096),'#30363a')
for i,im in enumerate(imgs):
 bg=Image.new('RGBA',(1024,1024),'#777b7d');bg.alpha_composite(im);d=ImageDraw.Draw(bg);d.line((0,640,1024,640),fill='#7effff',width=1);d.line((512,0,512,1024),fill='#7effff',width=1);L=m['standing_near_far_lane_halfwidth_canonical'] if i==0 else m['running_near_far_lane_halfwidth_canonical'];s=m['camera_forward_slope_y_per_x'];I=m['ground_origin_intercept_canonical']
 for sign in [-1,1]:d.line((0,round(I-s*512+sign*L),1024,round(I+s*512+sign*L)),fill='#83ff88' if sign==1 else '#51b95c',width=2)
 ox=i%4*512;oy=i//4*548;panel.paste(bg.convert('RGB').resize((512,512),Image.Resampling.LANCZOS),(ox,oy+24));ImageDraw.Draw(panel).text((ox+5,oy+6),labels[i],fill='white')
out=p/'physical-trial-v01-seven-private.jpg';assert not out.exists()
for quality in range(88,7,-4):
 panel.save(out,quality=quality)
 if out.stat().st_size<=150000:break
assert out.stat().st_size<=150000
proof={'status':'PRIVATE_FIRST_PHYSICAL_TRIAL_ONLY_NOT_APPROVED','preview':str(out),'bytes':out.stat().st_size,'preview_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'raw_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'runtime_geometry':str(p/'runtime-geometry.trial-v01.json'),'runtime_geometry_sha256':hashlib.sha256((p/'runtime-geometry.trial-v01.json').read_bytes()).hexdigest(),'ground_model':str(p/'common-groundprojection-hypothesis.v01.DRAFT.json'),'actual_idle_texture':str(ip),'actual_idle_texture_sha256':hashlib.sha256(ip.read_bytes()).hexdigest(),'actual_idle_geometry':ig,'note':'All source/game PNGs unchanged. Uniform2304 FIRSTtrial, approximate surfaceaxis and narrower-runlane fit need independent actual anatomy/C/ground review, especially both LOAD body compression. Trial is not approval.'};out.with_suffix('.proof.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'preview':str(out),'bytes':out.stat().st_size,'idle_texture':str(ip)}))
