from pathlib import Path
import json,hashlib,math
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import map_coordinates,label,distance_transform_edt

B=Path(__file__).parent;O=B/'actual-NE-IDLE-six-native-v02';O.mkdir();P=128;N=1536
hp=Path('/workspace/scratch/mythic413-NE-walk-author-20261020-v01/NE-RUN-source-material-handoff-v01.json')
assert hashlib.sha256(hp.read_bytes()).hexdigest()=='69a21811606f0c93b1bf662f7550b9bb723bae35e43d8143a43a6b55e40b285f'
h=json.loads(hp.read_text());sourcep=Path(h['basis_actual_identity_source0']['path']);assert hashlib.sha256(sourcep.read_bytes()).hexdigest()=='99ffa7da2332144f3d449e9e23881bbaa130ace3027e837518148b705d92c127'
source=Image.open(sourcep).convert('RGBA');assert source.size==(1254,1254);sa=np.array(source)
files=[sourcep,hp];protected=np.zeros((1254,1254),bool)
for e in h['original_boot_mattes']:
 p=Path(e['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==e['sha256'];files.append(p);protected|=np.array(Image.open(p).convert('L'))>0
armmattep=Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01/common-complete-NE-native-material-parts-v03/actual-old-complete-LEFT-cuff-forearm-removal-semantic-matte.png');files.append(armmattep);protected|=np.array(Image.open(armmattep).convert('L'))>0
protected[:,790:]=True
def smooth(a):
 z=np.clip(a,0,1);return z*z*(3-2*z)
protection=smooth(distance_transform_edt(~protected)/12.)
Image.fromarray((protected*255).astype('uint8')).save(O/'original-actual-fixed-boots-LEFTforearm-RIGHTgear-protection-semantic-matte.png')
manifest=B/'NE-IDLE-own-native-source-and-static-gear-inputs-frozen-v02.json';assert not manifest.exists()
manifest.write_text(json.dumps(dict(status='FROZEN_ACTUAL_OWN_NE_NATIVE_SOURCE_NOT_N_MIRROR',files=[dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)for p in files]),indent=2)+'\n')
def selected(im,polygon):
 m=Image.new('L',im.size);ImageDraw.Draw(m).polygon(polygon,fill=255);a=np.array(im);a[:,:,3]=np.minimum(a[:,:,3],np.array(m));a[a[:,:,3]==0,:3]=0;return Image.fromarray(a),m
# Real visible curled finger skin only. The wrist/glove and palm remain fixed.
fingers,fmask=selected(source,[(461,674),(466,672),(472,674),(479,671),(483,673),(484,679),(482,684),(479,689),(472,689),(465,685),(461,681)])
fa=np.array(fingers);prox=fa.copy();prox[:,476:,3]=0;prox[prox[:,:,3]==0,:3]=0;dist=fa.copy();dist[:,:472,3]=0;dist[dist[:,:,3]==0,:3]=0
prox=Image.fromarray(prox);dist=Image.fromarray(dist);joint,_=selected(source,[(465,674),(471,674),(474,676),(474,681),(469,683),(465,680)])
base=sa.copy();base[np.array(fmask)>0]=0;base=Image.fromarray(base)
for name,im in [('original-own-NE-fixed-stance-body-with-actual-finger-void',base),('actual-original-proximal-curled-finger-skin',prox),('actual-original-distal-curled-finger-skin',dist),('actual-original-native-finger-joint-skin',joint)]:im.save(O/(name+'.png'))
yy,xx=np.mgrid[:1254,:1254].astype(float)
def field(x,y,ph):
 t=2*math.pi*ph/6;b=.5-.5*math.cos(t)
 chest=smooth((x-585)/35)*(1-smooth((x-735)/55))*smooth((y-385)/55)*smooth((620-y)/30)*np.exp(-((y-505)/86)**4)
 dx=(x-690)/70*4.6*b*chest;dy=-5.6*b*chest
 ribbon=smooth((x-395)/30)*(1-smooth((x-605)/45))*smooth((y-330)/35)*(1-smooth((y-505)/30))
 rdx=4.2*(math.sin(t-1.1)-math.sin(-1.1));rdy=1.8*(math.sin(t-.4)-math.sin(-.4));dx+=rdx*ribbon;dy+=rdy*ribbon
 tail=smooth((y-685)/70)*(1-smooth((y-1000)/30))*smooth((x-245)/30)*(1-smooth((x-480)/60))
 cdx=4.8*(math.sin(t-.75)-math.sin(-.75));cdy=2.3*(math.sin(t-.2)-math.sin(-.2));dx+=cdx*tail;dy+=cdy*tail
 protect=map_coordinates(protection,np.array([y,x]),order=1,mode='constant',cval=0,prefilter=False)
 return dx*protect,dy*protect
def warp(im,ph):
 a=np.array(im);sx=xx.copy();sy=yy.copy()
 for _ in range(6):dx,dy=field(sx,sy,ph);sx=xx-dx;sy=yy-dy
 coords=np.array([sy,sx]);r=np.stack([map_coordinates(a[:,:,k],coords,order=1,mode='constant',cval=0,prefilter=False)for k in range(4)],axis=-1).astype('uint8');r[r[:,:,3]==0,:3]=0;r[protected]=a[protected];return Image.fromarray(r)
rows=[];fixedrows=[]
for ph in range(6):
 pose=warp(base,ph);proxdeg=[0,2,5,7,4,1][ph];distdeg=[0,3,7,9,5,1.5][ph]
 finger=Image.new('RGBA',source.size);finger.alpha_composite(prox.rotate(proxdeg,resample=Image.Resampling.BICUBIC,center=(466,675)));d=dist.rotate(distdeg,resample=Image.Resampling.BICUBIC,center=(475,679));d=d.rotate(proxdeg,resample=Image.Resampling.BICUBIC,center=(466,675));finger.alpha_composite(d);finger.alpha_composite(joint.rotate(proxdeg,resample=Image.Resampling.BICUBIC,center=(466,675)));pose.alpha_composite(finger);finger.save(O/f'NE-idle-phase{ph}-actual-two-joint-curled-finger-parts.png')
 a=np.array(pose);fixedmask=protected.copy();fixedmask[668:704,450:493]=False;assert np.array_equal(a[fixedmask],sa[fixedmask]);fixedrows.append(hashlib.sha256(a[fixedmask].tobytes()).hexdigest())
 canvas=Image.new('RGBA',(N,N));canvas.paste(pose,(P,P));p=O/f'NE-idle-phase{ph}-actual-native-v02.png';canvas.save(p);labs,n=label(np.array(canvas)[:,:,3]>100);ar=np.bincount(labs.ravel());strong=[int(z)for z in ar[1:]if z>=200];assert len(strong)==1
 t=2*math.pi*ph/6;rows.append(dict(phase=ph,path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size,seconds_range=[ph*.2,(ph+1)*.2],inhalation=.5-.5*math.cos(t),true_local_chest_expansion=4.6*(.5-.5*math.cos(t)),true_local_scapular_lift=5.6*(.5-.5*math.cos(t)),LEFT_real_finger_proximal_degrees=proxdeg,LEFT_real_finger_distal_degrees=distdeg,actual_finger_articulation_centres=[[466,675],[475,679]],original_complete_boots_LEFTforearm_and_RIGHTgrip_staff_RGBA_unchanged=True,strong_components=strong,status='ACTUAL_NEW_OWN_NE_IDLE_NATIVE_SOURCE_PENDING_INDEPENDENT_SOURCE_LOOP_QC'))
assert len(set(fixedrows))==1 and len({r['sha256']for r in rows})==6
contract=dict(status='ACTUAL_NEW_DEDICATED_NE_IDLE_SIX_SOURCE_PENDING_SOURCE_LOOP_PHYSICAL_GAME_QC',actor='transform:413',direction='NE',motion='idle',fixed_C=2432,bodyunit=2.375,common_unpadded_root=[716.2291666666666,1054.2766007046484],source_native_canvas=[1254,1254],storage_canvas=[1536,1536],storage_translation=[128,128],logical_canvas=1024,cycle_seconds=1.2,phase_seconds=.2,resource_fps=5.,loop=True,profile_modified=False,frames=rows,input_manifest=dict(path=str(manifest),sha256=hashlib.sha256(manifest.read_bytes()).hexdigest()),source_native_stance_and_bones_reregistered=False,whole_actor_mirror=False,whole_actor_translation=False,whole_actor_rotation=False,pinned_original_boots_LEFTforearm_RIGHTgear_RGBA_sha256=fixedrows[0],actual_motion='Own NE actual chest/corset/scapular expansion with fixed waist and braced limbs; two real visible skin finger-joints curl independently, free blue hair ribbons and far LEFT splitgold coattail have distinct pinned-root continuous native UV lag. Entire original stance and both complete boots, LEFT rigid cuff/forearm, RIGHT grip/fullstaff are preserved. No wholePNG bob, sharedmotion, color relabel or N flip.',limits=['Original own NE first-source stance/C was already independently registered; this idle does not infer unique hidden leg geometry or change its original bone/foot pose.','Native local material bending and actual visible finger joint pivots are explicit authored controls, not uniquely recovered hidden anatomy.','Actual source six and wrap5→0, unchangedgear/support and finite material-floor proof still require independent QC before game adoption.'],actor_approvals_added=0,game_clips_adopted=0)
p=O/'actual-NE-IDLE-six-source-contract-v02.json';p.write_text(json.dumps(contract,indent=2)+'\n');print(json.dumps(dict(contract=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),poses=6,strong=[len(r['strong_components'])for r in rows],unique=6)))
