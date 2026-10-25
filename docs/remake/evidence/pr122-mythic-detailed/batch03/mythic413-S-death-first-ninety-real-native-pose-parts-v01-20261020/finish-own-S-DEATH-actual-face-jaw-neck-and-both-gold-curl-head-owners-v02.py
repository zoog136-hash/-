from pathlib import Path
import json,hashlib,numpy as np
from PIL import Image,ImageDraw
B=Path(__file__).parent;D=B/'actual-own-S-DEATH-native-head-and-complete-boot-materials-v02';D.mkdir();old=B/'actual-own-S-DEATH-native-head-and-complete-boot-materials-v01/own-S-DEATH-actual-head-and-complete-boots-readonly-native-handoff-v01.json';j=json.loads(old.read_text());raw=Image.open(j['source']['path']).convert('RGBA');m=Image.new('L',raw.size);d=ImageDraw.Draw(m)
# Face and original scalp/bun/bows retain their true outer contour. The gold
# standing neck collar stays with the torso; only real bare neck is head skin.
d.polygon([(529,76),(738,76),(746,223),(735,277),(715,300),(690,285),(674,281),(659,290),(647,300),(634,305),(622,305),(607,299),(591,285),(580,280),(566,289),(551,270)],fill=255)
d.polygon([(612,300),(644,300),(641,315),(633,322),(623,315)],fill=255)
for p in [[(536,260),(570,282),(459,422),(434,437),(416,416),(468,345)],[(699,266),(729,277),(820,395),(813,435),(769,386),(703,313)],[(578,269),(592,278),(594,290),(600,298),(598,307),(589,315),(587,324),(596,330),(598,340),(593,344),(584,334),(578,327),(578,318),(584,307),(588,301),(582,296),(575,286)],[(675,268),(687,276),(687,288),(693,295),(693,305),(686,312),(684,320),(687,330),(682,338),(672,337),(674,328),(677,320),(677,312),(681,305),(681,298),(675,291),(670,282)]]:d.polygon(p,fill=255)
a=np.array(raw);a[:,:,3]=np.minimum(a[:,:,3],np.array(m));a[a[:,:,3]==0,:3]=0;p=D/'actual-own-S-complete-head-face-bun-bows-longribbons-and-two-goldcurls-native-v02.png';Image.fromarray(a).save(p);mp=D/'actual-own-S-head-jaw-neck-both-goldcurl-and-ribbons-semantic-matte-v02.png';m.save(mp)
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
j['materials']['head-face-bun-and-both-blue-ribbons']=pin(p);j['mattes']['head-face-bun-and-both-blue-ribbons']=pin(mp);j['prior_native_input']=pin(old);j['actual_head_owner_detail']='Original long gold curls and both blue ribbons belong to head; true gold standing collar stays on torso. Original RGBA preserved.';o=D/'own-S-DEATH-actual-complete-head-curls-and-fullboots-readonly-native-handoff-v02.json';o.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(manifest=pin(o),new_native_head_material=True,source_RGBA_recolored=False)))
