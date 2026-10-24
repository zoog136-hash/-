from pathlib import Path
import hashlib,json,shutil
from PIL import Image,ImageDraw

root=Path('/workspace/runtime/batch17');repo=Path('/workspace/twilight');out=repo/'docs/remake/evidence/pr122-remaining106/batch17'
sources={'monk':'Monk-QA-v01','candidates-cast-failure-v1':'Queen-Gnoll-QA-v01','queen-v2':'Queen-QA-v02',
         'candidates-temporal-v2':'Candidates-Temporal-v02','preserved-native-main':'Preserved-Native-Main',
         'preserved-native-temporal':'Preserved-Native-Temporal','preserved-tomb269':'Preserved-Tomb269-Main'}
manifest=[]
for label,name in sources.items():
    base=root/name
    for src in base.rglob('*'):
        if not src.is_file() or src.suffix not in ['.json','.log']:continue
        rel=src.relative_to(base)
        if any(p in ['data','config','cache','platform'] for p in rel.parts):continue
        dest=out/'validation/Main'/label/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dest)
        manifest.append({'path':str(dest.relative_to(repo)),'bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
save=out/'validation/Main/report-file-manifest.json';save.parent.mkdir(parents=True,exist_ok=True);save.write_text(json.dumps(manifest,indent=2)+'\n')
for slug in ['queen-candidate-v2','gnoll-candidate']:
    data=json.loads((root/'Candidates-Temporal-v02/temporal/report-cases'/(slug+'.json')).read_text())
    selected=[]
    for role in data['roles']:
        for c in role['captures']:
            if role['compass'] in ['E','S'] and '-walk-' in c['path']:selected.append((role['compass'],c))
    selected.sort(key=lambda v:(['E','S'].index(v[0]),v[1]['frame']))
    canvas=Image.new('RGB',(1800,520),(24,25,28));draw=ImageDraw.Draw(canvas)
    inputs=[]
    for index,(d,c) in enumerate(selected):
        src=Path(c['path']);assert hashlib.sha256(src.read_bytes()).hexdigest()==c['sha256']
        image=Image.open(src).convert('RGB');vx,vy,_,_=c['viewport_crop'];sx,sy=c['screen_body_root'];rx,ry=sx-vx,sy-vy
        box=[round(rx-180),round(ry-250),round(rx+180),round(ry+30)];preview=image.crop(box).resize((300,234),Image.Resampling.NEAREST)
        x=index%6*300;y=index//6*260;canvas.paste(preview,(x,y+26));draw.text((x+8,y+6),d+' WALK '+str(c['frame']),fill='white')
        inputs.append({'source':str(src),'sha256':c['sha256'],'QA_crop_only':box,'new_authored_pose':False})
    dest=out/'Candidate-Main-visual-rejection';dest.mkdir(exist_ok=True);canvas.save(dest/(slug+'-actual-Main-walk.png'))
    (dest/(slug+'-montage-inputs.json')).write_text(json.dumps(inputs,indent=2)+'\n')
print('Preserved actual Main report/log bytes',len(manifest),'and two QA-only walk montages')
