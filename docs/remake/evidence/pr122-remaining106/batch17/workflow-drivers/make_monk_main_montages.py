from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw

root=Path('/workspace/runtime/batch17');case=root/'Monk-QA-v01/temporal/report-cases/albino-monk.json'
data=json.loads(case.read_text());rows={r['compass']:r for r in data['roles'] if any('-walk-' in c['path'] for c in r['captures'])}
manifest=[]
for group,dirs in [('front',['E','SE','S','SW']),('rear',['W','NW','N','NE'])]:
    canvas=Image.new('RGB',(1800,1040),(24,25,28));draw=ImageDraw.Draw(canvas)
    for y,d in enumerate(dirs):
        captures=sorted(rows[d]['captures'],key=lambda c:c['frame'])
        for x,c in enumerate(captures):
            path=Path(c['path']);assert hashlib.sha256(path.read_bytes()).hexdigest()==c['sha256']
            image=Image.open(path).convert('RGB');vx,vy,_,_=c['viewport_crop'];sx,sy=c['screen_body_root'];rx,ry=sx-vx,sy-vy
            box=[round(rx-180),round(ry-250),round(rx+180),round(ry+30)]
            preview=image.crop(box).resize((300,234),Image.Resampling.NEAREST)
            canvas.paste(preview,(x*300,y*260+26));draw.text((x*300+8,y*260+6),d+' WALK '+str(c['frame']),fill='white')
            manifest.append({'source':str(path),'sha256':c['sha256'],'preview_crop':box,'new_authored_pose':False})
    canvas.save(root/('monk-walk-'+group+'-actual-Main.png'))
(root/'monk-main-montage-inputs.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Created QA-only actual Main walk montages, source captures unchanged')
