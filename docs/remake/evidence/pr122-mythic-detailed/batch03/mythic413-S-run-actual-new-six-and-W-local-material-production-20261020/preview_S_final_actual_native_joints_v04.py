from pathlib import Path
from PIL import Image,ImageDraw
import json
B=Path(__file__).parent;D=B/'actual-S-RUN6-native-full-actor-v04';d=json.loads((D/'S-RUN6-own-actual-new-native-full-actor-source-contract-v01.json').read_text());specs=[(2,[710,310,845,510],'p2 LEFT actual bluewall owner'),(3,[710,340,850,560],'p3 LEFT upper/cuff join'),(4,[710,380,855,610],'p4 LEFT upper/cuff join'),(0,[420,385,590,550],'p0 RIGHT full puff/foregrip'),(0,[665,710,835,925],'p0 L planted knee'),(3,[470,690,645,920],'p3 R planted knee')];board=Image.new('RGB',(720,660),'#405265');dr=ImageDraw.Draw(board)
for i,(ph,bx,caption)in enumerate(specs):
 im=Image.open(d['frames'][ph]['path']);box=tuple(v+256 for v in bx);q=im.crop(box);q.thumbnail((230,300));x=i%3*240;y=i//3*330;board.paste(q,(x+(240-q.width)//2,y+25),q);dr.text((x+4,y+5),caption,fill='white')
p=D/'private-S-final-new-actual-native-cuff-and-opposite-contact-knee-joints-v04.jpg';board.save(p,quality=82);assert p.stat().st_size<=150000;l=B/'image-ledger-v01.json';j=json.loads(l.read_text());j['entries'].append(dict(path=str(p),bytes=p.stat().st_size,kind='private-final-corrected-S-new-native-actual-joints-and-opposite-knee-preview'));j['actual_cumulative_bytes']+=p.stat().st_size;l.write_text(json.dumps(j,indent=2)+'\n');print({'path':str(p),'bytes':p.stat().st_size,'cumulative':j['actual_cumulative_bytes']})
