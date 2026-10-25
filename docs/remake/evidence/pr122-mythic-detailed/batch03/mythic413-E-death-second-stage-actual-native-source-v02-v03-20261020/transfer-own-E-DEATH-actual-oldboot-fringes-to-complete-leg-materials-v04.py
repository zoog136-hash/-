from pathlib import Path
import json,hashlib,copy,numpy as np
from PIL import Image
from scipy.ndimage import label,distance_transform_edt
B=Path(__file__).parent;D=B/'actual-own-E-DEATH-native-parts-v04';D.mkdir();old=B/'actual-own-E-DEATH-native-parts-v03/own-E-DEATH-complete-native-materials-and-fixed-registration-handoff-v03.json';j=json.loads(old.read_text());coatname='complete-original-blue-gold-cape-and-both-coattails';coat=np.array(Image.open(j['materials'][coatname]['path']).convert('RGBA'));labs,n=label(coat[:,:,3]>100);dist,nearest=distance_transform_edt(labs==0,return_indices=True);owner=labs[tuple(nearest)];aa=(coat[:,:,3]>0)&(dist<=3);updates={};transfers=[]
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
for side,seed,expected in [('L',[835,1140],1486),('L',[795,940],1343),('R',[600,980],416),('R',[534,958],44)]:
 idx=labs[seed[1],seed[0]]
 if idx==0 or int((labs==idx).sum())!=expected:
  matches=[i for i in range(1,n+1)if int((labs==i).sum())==expected];assert len(matches)==1;idx=matches[0]
 key=side+'-complete-native-skin-thigh-shaft-counter-stiletto';leg=updates.get(key,Image.open(j['materials'][key]['path']).convert('RGBA'));take=aa&(owner==idx);extra=coat.copy();extra[~take]=0;coat[take]=0;leg.alpha_composite(Image.fromarray(extra));updates[key]=leg;mp=D/f'actual-source-{side}-oldboot-component{expected}-complete-semantic-transfer-matte-v04.png';Image.fromarray((take*255).astype('uint8')).save(mp);ep=D/f'actual-source-{side}-oldboot-component{expected}-original-RGBA-preserved-v04.png';Image.fromarray(extra).save(ep);transfers.append(dict(side=side,original_strong_source_pixels=expected,semantic_matte=pin(mp),original_RGBA=pin(ep),source_pixels_recolored=False,actual_owner=key,old_wrong_owner=coatname))
updates[coatname]=Image.fromarray(coat)
for name,im in updates.items():
 p=D/(name+'-complete-semantic-owner-v04.png');im.save(p);j['materials'][name]=pin(p)
j.update(status='ACTUAL_OWN_E_NATIVE_SOURCE_MATERIALS_COMPLETE_OLD_BOOT_OWNERSHIP_CORRECTED_PENDING_NEW_POSE_QC',prior_actual_source_parts=pin(old),original_boot_edge_owner_transfers=transfers,source_recolored_or_deleted=False);out=D/'own-E-DEATH-complete-native-materials-and-fixed-registration-handoff-v04.json';out.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(manifest=pin(out),transfers=len(transfers))))
