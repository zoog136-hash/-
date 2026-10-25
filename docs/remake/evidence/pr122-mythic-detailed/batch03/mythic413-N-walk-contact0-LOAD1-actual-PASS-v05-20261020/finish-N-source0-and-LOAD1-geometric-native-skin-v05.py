from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-N-skin-joint-finish-v05';D.mkdir();a4p=Path('/workspace/scratch/mythic413-N-walk-author-20261020-r001/contact0-r001/N-contact0-service-raw1024.png');s0p=Path('/workspace/scratch/mythic413-N-walk-author-20261020-r001/contact0-r002-fixedC1920/N-contact0-r002-left-forward-bounded-v02.png');a4=Image.open(a4p).convert('RGBA');orig0=Image.open(s0p).convert('RGBA');prev1p=B/'actual-LOAD1-rig-v03/N-LOAD1-actual-native-part-rig-v03.png';prev1=Image.open(prev1p).convert('RGBA');W,H=a4.size
basehem=[(577,637),(592,641),(609,645),(626,647),(643,647),(653,646),(669,644),(687,640),(707,636),(727,633),(739,632)]
def hsv(im):
 rgb=im[:,:,:3].astype(float)/255.;r,g,b=rgb[:,:,0],rgb[:,:,1],rgb[:,:,2];mx=rgb.max(2);mn=rgb.min(2);dif=mx-mn;h=np.zeros_like(mx);nz=dif>1e-9
 sel=nz&(mx==r);h[sel]=60*((g[sel]-b[sel])/dif[sel]%6)
 sel=nz&(mx==g);h[sel]=60*((b[sel]-r[sel])/dif[sel]+2)
 sel=nz&(mx==b);h[sel]=60*((r[sel]-g[sel])/dif[sel]+4)
 return h,np.divide(dif,mx,out=np.zeros_like(mx),where=mx>0),mx

def finish(source,target,bob,name):
 si=Image.new('RGBA',a4.size);si.paste(source,bob);s=np.asarray(si);t=np.asarray(target);out=t.copy();sh,ss,sv=hsv(s);th,ts,tv=hsv(t);gold=(sh>22)&(sh<65)&(ss>.27)&(sv>.25);pred=np.interp(np.arange(W),[p[0]+bob[0]for p in basehem],[p[1]+bob[1]for p in basehem]);mask=np.zeros((H,W),bool);count=0;span_rows=[]
 for l0,l1 in ((578,663),(665,740)):
  for x in range(l0+bob[0],l1+bob[0]):
   py=int(round(pred[x]));ys=np.flatnonzero(gold[max(0,py-5):min(H,py+6),x])+max(0,py-5);top=int(ys[-1])+1 if len(ys)else py+1
   if s[top+3,x,3]<200 or(sh[top+3,x]>65 and ss[top+3,x]>.18):continue
   def lower(im,h,sat,val):
    for y in range(top+3,702+bob[1]):
     bad=((22<h[y:y+3,x])&(h[y:y+3,x]<65)&(sat[y:y+3,x]>.30)&(val[y:y+3,x]>.20))|(val[y:y+3,x]<.32)|(im[y:y+3,x,3]<80)
     if bad.sum()>=2:return y-1
    return None
   sy=lower(s,sh,ss,sv);ty=lower(t,th,ts,tv)
   if sy is None or ty is None or sy-top<3 or ty-top<3:continue
   # Complete native skin columns between the actual gold hem and boot garter.
   # No HSV skin-selection holes, no clothing sampled, and no alpha edits.
   for y in range(top,ty+1):
    if t[y,x,3]<128:continue
    fy=top+(y-top)/max(ty-top,1)*max(sy-top-1,1);ya=int(np.floor(fy));yb=ya+1;f=fy-ya
    out[y,x,:3]=np.rint(s[ya,x,:3]*(1-f)+s[yb,x,:3]*f).astype(np.uint8);mask[y,x]=True;count+=1
   span_rows.append([x,top,sy,ty])
 changed=np.any(out!=t,2);assert not(changed&~mask).any();assert np.array_equal(out[:,:,3],t[:,:,3]);assert not changed[700+bob[1]:].any();p=D/(name+'.png');Image.fromarray(out).save(p);Image.fromarray(mask.astype(np.uint8)*255).save(D/(name+'-actual-bare-skin-region.png'))
 return out,dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),changed_pixels=int(changed.sum()),actual_bare_skin_columns=count,body_bob=list(bob),alpha_and_foot_RGBA_changed=0,skin_column_intervals=span_rows)
s0,m0=finish(a4,orig0,(0,0),'N-contact0-native-skin-joint-finished-v05');s1,m1=finish(a4,prev1,(-7,-12),'N-LOAD1-native-skin-joint-finished-v05');proof=dict(status='ACTUAL_TWO_JOINT_SKIN_FINISH_PENDING_INDEPENDENT_QC',source_a4_sha256=hashlib.sha256(a4p.read_bytes()).hexdigest(),source0_prior_sha256=hashlib.sha256(s0p.read_bytes()).hexdigest(),LOAD1_prior_sha256=hashlib.sha256(prev1p.read_bytes()).hexdigest(),fixed_C=1920,common_root=[662.8125,917.6920531878804],source0=m0,LOAD1=m1,full_alpha_or_Cfit=False,foot_and_heel_material_unchanged=True,mask_below_actual_goldhem=True,method='actual native a4 skin columns reprojected continuously between identical native gold hem and authored boot-garter edge, no threshold skin patches or feather',actor_approval_added=0);(D/'native-anatomical-skin-column-finish-proof-v05.json').write_text(json.dumps(proof,indent=2)+'\n')
pre=Image.new('RGB',(1040,265),(204,208,211));dr=ImageDraw.Draw(pre)
for i,(a,bob,title)in enumerate([(s0,(0,0),'corrected actual CONTACT0 skin'),(s1,(-7,-12),'corrected actual LOAD1 skin')]):
 im=Image.fromarray(a).crop((565+bob[0],610+bob[1],735+bob[0],690+bob[1]));bg=Image.new('RGBA',im.size,(204,208,211,255));bg.alpha_composite(im);pre.paste(bg.convert('RGB').resize((510,240)),(520*i,25));dr.text((520*i+5,5),title,fill='black')
p=D/'private-two-finished-native-skin-caps.jpg';pre.save(p,quality=94,optimize=True);assert p.stat().st_size<150000;print(json.dumps(dict(source0={k:v for k,v in m0.items()if k!='skin_column_intervals'},LOAD1={k:v for k,v in m1.items()if k!='skin_column_intervals'},preview_bytes=p.stat().st_size)))
