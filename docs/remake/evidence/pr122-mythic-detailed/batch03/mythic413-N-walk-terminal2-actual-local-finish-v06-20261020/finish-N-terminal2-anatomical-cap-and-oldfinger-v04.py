from pathlib import Path
from PIL import Image
import numpy as np, json, hashlib, importlib.util
from scipy.ndimage import label, binary_dilation
B=Path(__file__).parent;D=B/'actual-terminal2-local-finish-v04';D.mkdir()
sp=importlib.util.spec_from_file_location('nativecap',B/'finish-new-N-poses-native-skin-v03.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
p=B/'actual-terminal2-local-finish-v03/N-walk-phase2-actual-native-local-finish-v03.png';a=np.array(Image.open(p).convert('RGBA'));before=a.copy();mask=np.zeros(a.shape[:2],bool);bob=(7,-6)
# Visible actual upper edge of the projected short RIGHT boot. The upper cap
# connects this curved garter to the intact original skirt hem, closing the
# narrow clearing gap without moving the leg, heel, root, or blue coat.
edge=[(668,643),(673,645),(679,646),(685,648),(691,649),(700,649),(706,650),(712,648),(718,647),(724,645),(727,644),(746,626)]
cols=m.donors[1];dxs=np.array([c[0] for c in cols]);skin=np.zeros(a.shape[:2],bool)
for x in range(668,747):
 top=m.hem_top(int(np.clip(x-bob[0],577,739)))+bob[1]
 bot=int(np.floor(np.interp(x,[q[0] for q in edge],[q[1] for q in edge])))
 if bot<top:continue
 sx,st,sb=cols[int(np.argmin(abs(dxs-(x-bob[0]))))]
 for y in range(top,bot+1):
  fy=st+max(0,y-top)*min(1.,(sb-st-1)/max(bot-top,1));ya=int(np.floor(fy));f=fy-ya
  a[y,x,:3]=np.rint(m.source[ya,sx,:3]*(1-f)+m.source[ya+1,sx,:3]*f).astype('uint8');a[y,x,3]=253;mask[y,x]=True;skin[y,x]=True
# Old contact-pose skin beyond the new actual cap is not a coat panel.
# Remove only its flesh/brown native material outside the new silhouette.
h,s,v=m.hsv(before)
for x in range(727,747):
 bot=int(np.floor(np.interp(x,[q[0] for q in edge],[q[1] for q in edge])))
 for y in range(max(626,bot+1),665):
  if (h[y,x]<30 and s[y,x]>.1 and v[y,x]>.13 and a[y,x,3]>0):a[y,x]=0;mask[y,x]=True
# The obsolete fingertips are isolated at alpha16. Remove their AA fringe
# only inside this known old-fragment ROI; the valid new hand is above it.
x0,y0,x1,y1=493,619,512,641;roi=a[y0:y1,x0:x1];cc,n=label(roi[:,:,3]>16);removed=[]
for k in range(1,n+1):
 yy,xx=np.where(cc==k)
 if len(yy)<4:continue
 comp=cc==k;aa=binary_dilation(comp,iterations=2)&(roi[:,:,3]>0)
 py,px=np.where(aa);a[y0+py,x0+px]=0;mask[y0+py,x0+px]=True;removed.append({'alpha16_core':int(comp.sum()),'AA_pixels_removed':int(aa.sum()),'bbox':[int(x0+px.min()),int(y0+py.min()),int(x0+px.max()+1),int(y0+py.max()+1)]})
change=np.any(a!=before,2);assert not(change&~mask).any();assert np.array_equal(a[800:],before[800:]);q=D/'N-walk-phase2-actual-native-local-finish-v04.png';Image.fromarray(a).save(q);Image.fromarray(mask.astype('uint8')*255).save(D/'terminal2-local-skin-joint-and-oldfinger-finish-mask-v04.png')
proof={'phase':2,'path':str(q),'sha256':hashlib.sha256(q.read_bytes()).hexdigest(),'prior':str(p),'prior_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'actual_skin_cap_method':'native original skin cap, source hem to actual projected garter; narrow skin joint gap closure and obsolete skin side-piece removal','skin_garter_edge':edge,'changed_pixels':int(change.sum()),'alpha_changes':int((a[:,:,3]!=before[:,:,3]).sum()),'old_fingertips_removed':removed,'native_canvas':[1254,1254],'C':1920,'common_rig_root_in_unpadded_frame':[662.8125,917.6920531878804],'storage_translation':[0,0],'body_node_bob':[7,-6],'below_y800_RGBA_changed':0,'RIGHT_staff_and_blue_inner_coat_unchanged':True,'original_passed_contact0_and_LOAD1_changed':False,'actor_approval_added':0};(D/'terminal2-local-finish-proof-v04.json').write_text(json.dumps(proof,indent=2)+'\n')
for box,name,sz in [((573,614,755,719),'private-terminal2-finished-native-skin-v04.jpg',(728,420)),((470,585,540,655),'private-terminal2-finished-native-hand-v04.jpg',(350,350))]:
 im=Image.fromarray(a).crop(box);bg=Image.new('RGBA',im.size,(192,198,204,255));bg.alpha_composite(im);bg.convert('RGB').resize(sz).save(D/name,quality=93,optimize=True);assert(D/name).stat().st_size<150000
pr=Image.fromarray(a);pr.thumbnail((560,560));bg=Image.new('RGBA',pr.size,(204,208,211,255));bg.alpha_composite(pr);bg.convert('RGB').save(D/'private-terminal2-whole-v04.jpg',quality=91,optimize=True)
print(json.dumps(proof))
