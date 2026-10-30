from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import binary_dilation
import numpy as np,json,hashlib,importlib.util
B=Path(__file__).parent;D=B/'actual-opposite3-load4-local-finish-v02';D.mkdir()
sp=importlib.util.spec_from_file_location('nativecap',B/'finish-new-N-poses-native-skin-v03.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
P=json.loads((B/'actual-N-skin-joint-finish-v05/native-anatomical-skin-column-finish-proof-v05.json').read_text())
results=[]
for phase,bob,key in [(3,(27,0),'source0'),(4,(34,-12),'LOAD1')]:
 inp=B/f'actual-opposite3-load4-rig-v01/N-walk-phase{phase}-actual-native-part-rig-v01.png';before=np.array(Image.open(inp).convert('RGBA'));a=before.copy();leg=np.array(Image.open(B/f'actual-opposite3-load4-rig-v01/actual-bilateral-legs-phase{phase}.png'));arm=np.array(Image.open(B/f'actual-opposite3-load4-rig-v01/actual-LEFT-counterphase-arm-phase{phase}.png'));H,W=a.shape[:2];allcap=np.zeros((H,W),np.uint8);caps=[]
 spans=P[key]['skin_column_intervals'];sourcebob=P[key]['body_bob'];source_ranges=[(665+sourcebob[0],723+sourcebob[0]),(579+sourcebob[0],646+sourcebob[0])]
 for side,(lo,hi) in enumerate(source_ranges):
  edge=sorted((1325-x,ty-1) for x,top,sy,ty in spans if lo<=x<hi)
  assert len(edge)>35
  tl,tr=((578+bob[0],654+bob[0]) if side==0 else (658+bob[0],739+bob[0]))
  toppts=[(x,m.hem_top(x-bob[0])+bob[1]) for x in range(tl,tr+1)]
  poly=toppts+list(reversed(edge));hires=Image.new('L',(W*4,H*4));ImageDraw.Draw(hires).polygon([(x*4,y*4)for x,y in poly],fill=255);ca=np.array(hires.resize((W,H),Image.Resampling.LANCZOS));ca[ca<8]=0
  # Original hem remains the foreground occluder, even where the upper thigh
  # inclines toward the new support rather than following a rectangular ROI.
  for x in range(max(0,tl),min(W,tr+1)):ca[:m.hem_top(x-bob[0])+bob[1],x]=0
  caps.append((side,ca,edge,toppts));allcap=np.maximum(allcap,ca)
 h,s,v=m.hsv(a);skinlike=(h<30)&(s>.1)&(v>.13)&(a[:,:,3]>0)
 removedold=np.zeros((H,W),bool)
 for x in range(570+bob[0],746+bob[0]):
  y0=m.hem_top(int(np.clip(x-bob[0],577,739)))+bob[1]
  for y in range(y0,735):
   if allcap[y,x]==0 and leg[y,x,3]==0 and skinlike[y,x]:a[y,x]=0;removedold[y,x]=True
 for side,ca,edge,toppts in caps:
  dc=m.donors[side];xs=np.array([c[0]for c in dc]);yy,xx=np.nonzero(ca)
  for x in np.unique(xx):
   rows=np.flatnonzero(ca[:,x]);top=int(rows.min());bot=int(rows.max());sx,st,sb=dc[int(np.argmin(abs(xs-(x-bob[0]))))];extent=min(sb-st-1,max(3,bot-top))
   for y in rows:
    fy=st+(y-top)/max(bot-top,1)*extent;ya=int(np.floor(fy));f=fy-ya;rgb=np.rint(m.source[ya,sx,:3]*(1-f)+m.source[ya+1,sx,:3]*f).astype('uint8');opacity=float(ca[y,x])/255
    if opacity>.97:a[y,x,:3]=rgb;a[y,x,3]=253
    else:
     olda=a[y,x,3]/255;newa=253/255*opacity;oa=newa+olda*(1-newa)
     if oa>0:a[y,x,:3]=np.rint((rgb*newa+a[y,x,:3]*olda*(1-newa))/oa).astype('uint8');a[y,x,3]=round(oa*255)
 # Clear only obsolete original-finger space; an authored current hand node
 # has priority and is protected with its one-pixel AA margin.
 safe=binary_dilation(arm[:,:,3]>0,iterations=1);fm=np.zeros((H,W),bool);fm[610+bob[1]:647+bob[1],486+bob[0]:511+bob[0]]=True;fm&=~safe;oldfinger_count=int(((a[:,:,3]>0)&fm).sum());a[fm]=0
 changed=np.any(a!=before,2);allowed=(allcap>0)|removedold|fm;assert not(changed&~allowed).any();assert np.array_equal(a[800:],before[800:]);out=D/f'N-walk-phase{phase}-actual-native-local-finish-v02.png';Image.fromarray(a).save(out);Image.fromarray(allowed.astype('uint8')*255).save(D/f'phase{phase}-actual-cap-and-oldfinger-finish-mask-v02.png')
 note={'phase':phase,'path':str(out),'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'prior_sha256':hashlib.sha256(inp.read_bytes()).hexdigest(),'body_node_bob':list(bob),'C':1920,'common_rig_root_in_unpadded_frame':[662.8125,917.6920531878804],'storage_translation':[0,0],'changed_pixels':int(changed.sum()),'below_y800_RGBA_changed':0,'RIGHT_staff_and_blue_coat_preserved':True,'oldfinger_alpha_pixels_removed':oldfinger_count,'cap_edges':[c[2]for c in caps],'actor_approval_added':0};(D/f'phase{phase}-local-finish-proof-v02.json').write_text(json.dumps(note,indent=2)+'\n');results.append(note)
 preview=Image.fromarray(a);preview.thumbnail((560,560));bg=Image.new('RGBA',preview.size,(192,198,204,255));bg.alpha_composite(preview);bg.convert('RGB').save(D/f'private-actual-phase{phase}-whole-v02.jpg',quality=91,optimize=True)
 crop=Image.fromarray(a).crop((570+bob[0],610+bob[1],745+bob[0],725+bob[1]));bg=Image.new('RGBA',crop.size,(192,198,204,255));bg.alpha_composite(crop);bg.convert('RGB').resize((700,460)).save(D/f'private-actual-phase{phase}-native-caps-v02.jpg',quality=93,optimize=True)
print(json.dumps([dict(phase=n['phase'],sha256=n['sha256'],changed=n['changed_pixels'],oldfinger_removed=n['oldfinger_alpha_pixels_removed'])for n in results]))
