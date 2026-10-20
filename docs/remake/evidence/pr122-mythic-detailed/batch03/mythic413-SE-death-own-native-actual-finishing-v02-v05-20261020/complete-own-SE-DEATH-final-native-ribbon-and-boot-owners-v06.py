from pathlib import Path
import json,hashlib,numpy as np
from PIL import Image
from scipy.ndimage import label,distance_transform_edt
B=Path(__file__).parent;D=B/'actual-own-SE-DEATH-native-parts-v06';D.mkdir();old=B/'actual-own-SE-DEATH-native-parts-v05/own-SE-DEATH-complete-native-materials-and-fixed-registration-handoff-v05.json';j=json.loads(old.read_text());tn='torso-original-blue-gold-bodice';hn='head-face-bun-hair-complete-blue-ribbons';torso=np.array(Image.open(j['materials'][tn]['path']).convert('RGBA'));head=Image.open(j['materials'][hn]['path']).convert('RGBA');labs,n=label(torso[:,:,3]>100);dist,nearest=distance_transform_edt(labs==0,return_indices=True);owner=labs[tuple(nearest)];moves=[]
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
for count in [3624,2877,235]:
 ids=[k for k in range(1,n+1)if int((labs==k).sum())==count];assert len(ids)==1;mask=(owner==ids[0])&(dist<=3)&(torso[:,:,3]>0);extra=torso.copy();extra[~mask]=0;torso[mask]=0;head.alpha_composite(Image.fromarray(extra));mp=D/f'original-native-blue-hair-ribbon-{count}-complete-owner-transfer-matte-v06.png';Image.fromarray((mask*255).astype('uint8')).save(mp);ep=D/f'original-native-blue-hair-ribbon-{count}-RGBA-preserved-v06.png';Image.fromarray(extra).save(ep);moves.append(dict(actual_original_strong_pixels=count,matte=pin(mp),actual_native_RGBA=pin(ep),old_owner=tn,actual_owner=hn))
for name,im in [(tn,Image.fromarray(torso)),(hn,head)]:
 p=D/(name+'-complete-actual-ribbons-owner-v06.png');im.save(p);j['materials'][name]=pin(p)
j.update(status='ACTUAL_OWN_SE_DEATH_COMPLETE_NATIVE_MATERIALS_WITH_TRUE_FULL_HEAD_RIBBONS_SHARED_CAPE_SOURCE_PASS_PENDING_DEDICATED_DEATH_QC',prior_native_input=pin(old),actual_blue_head_ribbon_owner_transfers=moves,source_RGBA_recolored_or_deleted=False);out=D/'own-SE-DEATH-complete-native-materials-and-fixed-registration-handoff-v06.json';out.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(manifest=pin(out),original_ribbon_components_transferred=len(moves))))
