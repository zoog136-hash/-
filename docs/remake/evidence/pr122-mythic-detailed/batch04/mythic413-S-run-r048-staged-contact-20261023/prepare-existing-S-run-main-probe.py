from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
T=Path(__file__).parent;L=Path('/workspace/scratch/pr122-death-s-only-20261022-v01');cp=Path('/workspace/scratch/mythic413-S-run-author-fresh-20261020-v01/actual-S-RUN6-native-full-actor-v06-exact-latest-cape-root-20261022/S-RUN6-own-actual-new-native-full-actor-source-contract-v01.json');c=json.loads(cp.read_text());lc=json.loads(Path(c['leg_controls']['path']).read_text());P=np.array(c['projection']);root=np.array(c['common_unpadded_root']);pad=np.array(c['storage_translation']);points={};pairs=[];visible=[]
def image(rec):
 p=Path(rec['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==rec['sha256'];return np.array(Image.open(p).convert('RGBA'))
for side,phases in [('L',[0,1]),('R',[3,4])]:
 b=c['frames'][phases[0]]['bones'][side];a=image(b['source']);y,x=np.where((a[:,:,3]>200)&(np.indices(a.shape[:2])[0]>=1100));native=np.stack([x,y],1);xyz=np.array(b['heel'])+(native-np.array(b['heel_source']))@np.array(b['foot_UV']).T;order=np.argsort(xyz[:,2]);chosen=None
 for idx in order[:80]:
  if xyz[idx,2]<0:continue
  samples=[]
  for i in phases:
   bone=c['frames'][i]['bones'][side];world=np.array(bone['heel'])+(native[idx]-np.array(bone['heel_source']))@np.array(bone['foot_UV']).T;screen=P@world;pixel=np.rint(root+screen+pad).astype(int);xx,yy=pixel;leg=image(lc['frames'][i]['legs'][side]);alpha=int(leg[yy,xx,3]);later=max(int(image(n)[yy,xx,3]) for n in c['frames'][i]['actual_native_nodes'] if n['name']!='complete-original-cloak-two-coattails')
   samples.append((i,world,screen,pixel,alpha,later))
  if all(q[4]>100 and q[5]<=16 for q in samples):chosen=(int(idx),samples);break
 assert chosen is not None,side
 idx,samples=chosen
 for i,world,screen,pixel,alpha,later in samples:
  points[str(i)]={'side':side,'native_original_texel':native[idx].tolist(),'local':[float(screen[0]),float(c['C']/8+screen[1])]}
  visible.append(dict(phase=i,side=side,physical_height_above_sole=float(world[2]),source_pixel=pixel.tolist(),support_alpha=alpha,max_later_alpha=later))
 pairs.append(dict(side=side,phases=phases))
(T/'S-contact-points-existing-v06.json').write_text(json.dumps(dict(scope='ACTUAL_MAIN_PLAYER_SPRITE_TRANSFORM_WITH_PRESCRIBED_WORLD_TRANSLATION_NO_COLLISION_PHYSICS',source_contract=str(cp),points=points,pairs=pairs),indent=2)+'\n')
(T/'S-v06-measured-contact-visibility.json').write_text(json.dumps(dict(status='SOURCE_SAMPLE_PRESENT_UNOCCLUDED_RUNTIME_NOT_YET_RUN',points=visible,final_visual_approval=False),indent=2)+'\n')
s=(L/'W_413_own_native_run_main_player_test.gd').read_text().replace('run_4','run_2').replace('idle_4','idle_2').replace('Vector2.LEFT','Vector2.DOWN').replace('W input','S input').replace('W run','S run').replace('W source','S source').replace('W idle','S idle').replace('W-own','S-own').replace('"direction":"W"','"direction":"S"').replace('MYTHIC413_W_OWN_NATIVE_RUN_CANDIDATE','MYTHIC413_S_OWN_NATIVE_RUN_CANDIDATE');(L/'S_413_own_native_run_main_player_test.gd').write_text(s)
print('Prepared existing S source contact probe with original opaque sole pixels; no new frames rendered.')
