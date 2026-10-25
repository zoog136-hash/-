from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw
p=Path(__file__).parent;r=Path('/workspace/scratch');j=json.loads((p/'candidate-source-pins.pending.json').read_text());spec=[('CURRENT SWidle',r/'girtas-SW-run-production-reference-v01/current-SW-idle0-exactRGBA.png',[0,260,486,239],1)]+[(f'NEW SWrun{s["phase"]}',Path(s['path']),[100,600,1050,654],.5) for s in j['sources']]
panel=Image.new('RGB',(2200,760),'#30363a');pins=[]
for i,(label,raw,rect,scale) in enumerate(spec):
 x,y,w,h=rect;im=Image.open(raw).convert('RGBA').crop((x,y,x+w,y+h));bg=Image.new('RGBA',im.size,'#777b7d');bg.alpha_composite(im);d=ImageDraw.Draw(bg)
 for xx in range(((x+99)//100)*100,x+w,100):
  d.line((xx-x,0,xx-x,h),fill=(120,150,150,100),width=1);d.text((xx-x+2,2),str(xx),fill='white')
 for yy in range(((y+49)//50)*50,y+h,50):
  d.line((0,yy-y,w,yy-y),fill=(120,150,150,100),width=1);d.text((2,yy-y+2),str(yy),fill='white')
 bg=bg.convert('RGB').resize((round(w*scale),round(h*scale)),Image.Resampling.LANCZOS);ox=(i%4)*550;oy=(i//4)*380;panel.paste(bg,(ox,oy+30));ImageDraw.Draw(panel).text((ox+5,oy+6),label+f' nativeXY scale{scale}',fill='white');pins.append({'phase':'idle' if i==0 else i-1,'source':str(raw),'source_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'crop_native_XYWH':rect,'panel_origin':[ox,oy+30],'preview_scale':scale})
out=p/'native-boot-support-AIR-grid-private.jpg';assert not out.exists()
for quality in range(88,7,-4):
 panel.save(out,quality=quality)
 if out.stat().st_size<=150000:break
assert out.stat().st_size<=150000
proof={'status':'PRIVATE_NATIVE_BOOT_ROI_SEARCH_GRID_ONLY_NO_GROUND_OR_RUNTIME_APPROVAL','preview':str(out),'preview_bytes':out.stat().st_size,'preview_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'sources':pins,'note':'Measure real heel/flatsole/boot regions and distinguish robe/blade. Original source PNGs unchanged. Root must preserve true flight, not follow AIR min-y.'};(p/'native-boot-support-grid-proof.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'private_preview':str(out),'bytes':out.stat().st_size,'sources':len(pins)}))
