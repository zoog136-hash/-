from pathlib import Path
from PIL import Image,ImageDraw
import json
B=Path(__file__).parent;D=B/'actual-S-RUN6-native-full-actor-v01';P=D/'S-RUN6-own-actual-new-native-full-actor-source-contract-v01.json';d=json.loads(P.read_text());board=Image.new('RGB',(960,1020),'#405265');dr=ImageDraw.Draw(board)
for f in d['frames']:
 im=Image.open(f['path']).crop((380,280,1260,1630));im.thumbnail((310,480));x=f['phase']%3*320;y=f['phase']//3*510;board.paste(im,(x,y+24),im);dr.text((x+5,y+5),str(f['phase'])+' '+f['name'],fill='white')
p=D/'private-S-RUN6-new-body-controller-study-v01.jpg';board.save(p,quality=74);assert p.stat().st_size<=150000
l=B/'image-ledger-v01.json';ld=json.loads(l.read_text());ld['entries'].append(dict(path=str(p),bytes=p.stat().st_size,kind='private-new-S-fullbody-study-input-leg-material-HOLD'));ld['actual_cumulative_bytes']+=p.stat().st_size;l.write_text(json.dumps(ld,indent=2)+'\n');print({'path':str(p),'bytes':p.stat().st_size,'cumulative':ld['actual_cumulative_bytes'],'full_source_accepted':False})
