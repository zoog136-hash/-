from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np, json, hashlib, ast
from scipy.ndimage import label
B=Path(__file__).parent
D=B/'actual-terminal2-local-finish-v03'
D.mkdir(exist_ok=True)
A4=Path('/workspace/scratch/mythic413-N-walk-author-20261020-r001/contact0-r001/N-contact0-service-raw1024.png')
source=np.array(Image.open(A4).convert('RGBA')); H,W=source.shape[:2]
tree=ast.parse((B/'finish-N-source0-and-LOAD1-geometric-native-skin-v05.py').read_text())
ns={'np':np};exec(compile(ast.Module([n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='hsv'],[]),'native-hsv','exec'),ns)
hsv=ns['hsv']; sh,ss,sv=hsv(source)
HEM=[(577,637),(592,641),(609,645),(626,647),(643,647),(653,646),(669,644),(687,640),(707,636),(727,633),(739,632)]
def hem_top(x):
 p=int(round(np.interp(x,[q[0] for q in HEM],[q[1] for q in HEM])))
 yy=np.arange(p-5,p+6); good=(sh[yy,x]>22)&(sh[yy,x]<65)&(ss[yy,x]>.27)&(sv[yy,x]>.25)
 return int(yy[good][-1])+1 if good.any() else p+1
def boundary(a,h,s,v,x,top,fill_join=False):
 for y in range(top+3,min(top+155,H-3)):
  gold=(h[y:y+3,x]>22)&(h[y:y+3,x]<65)&(s[y:y+3,x]>.30)&(v[y:y+3,x]>.20)
  dark=(v[y:y+3,x]<.32)&(a[y:y+3,x,3]>100)
  empty=(a[y:y+3,x,3]<80) if not fill_join or y>top+24 else np.zeros(3,bool)
  if (gold|dark|empty).sum()>=2:return y-1
 return None
donors=[]
for lo,hi in ((578,663),(665,740)):
 cols=[]
 for x in range(lo,hi):
  top=hem_top(x);bot=boundary(source,sh,ss,sv,x,top)
  if bot is None or bot-top<4:continue
  q=slice(top+1,min(bot+1,top+7)); valid=(source[q,x,3]>200)&(sh[q,x]<24)&(ss[q,x]>.12)&(sv[q,x]>.35)
  if valid.sum()<2:continue
  cols.append((x,top,bot))
 assert len(cols)>20
 donors.append(cols)
def finish(inp,bob,phase,outdir):
 a=np.array(Image.open(inp).convert('RGBA'));before=a.copy(); th,ts,tv=hsv(a);mask=np.zeros((H,W),bool);span=[]
 # A completed articulated thigh may reveal original-material columns that were
 # hidden in the contact pose. Its continuous cap uses nearest valid actual skin
 # donor columns; no white hem, gold trim, or blue clothing is a donor.
 for side,(lo,hi) in enumerate(((578,663),(665,740))):
  dc=donors[side];dxs=np.array([q[0] for q in dc])
  for x in range(lo+bob[0]-2,hi+bob[0]+2):
   rx=x-bob[0];top=hem_top(int(np.clip(rx,577,739)))+bob[1]
   ys=np.arange(top,min(top+26,H)); flesh=(a[ys,x,3]>160)&(th[ys,x]<24)&(ts[ys,x]>.10)&(tv[ys,x]>.35)
   if flesh.sum()<2:continue
   bot=boundary(a,th,ts,tv,x,top,True)
   if bot is None or bot-top<2:continue
   di=int(np.argmin(abs(dxs-rx)));sx,st,sb=dc[di]
   # Compression hides distal thigh rather than squeezing its entire bright
   # highlight into a six-pixel sliver below the hem.
   extent=min(sb-st-1,max(3,bot-top))
   for y in range(top,bot+1):
    fy=st+(y-top)/max(bot-top,1)*extent;ya=int(np.floor(fy));f=fy-ya
    rgb=source[ya,sx,:3]*(1-f)+source[ya+1,sx,:3]*f
    a[y,x,:3]=np.rint(rgb).astype(np.uint8)
    if a[y,x,3]<128:
     # Actual local joint closure only: an opaque lower thigh must exist in
     # this column; its narrow clearing gap is not an outer silhouette edge.
     if (before[y+1:min(bot+1,y+25),x,3]>200).sum()>=3:a[y,x,3]=253
    mask[y,x]=True
   span.append([x,top,bot,sx,st,sb])
 # Isolated old fingertips left outside the full original forearm matte.
 # Boundary-touching components belong to actual hand/coat and are retained.
 x0,y0,x1,y1=(463+bob[0],611+bob[1],528+bob[0],666+bob[1]);roi=a[y0:y1,x0:x1]
 cc,n=label(roi[:,:,3]>0);removed=[]
 for k in range(1,n+1):
  yy,xx=np.where(cc==k)
  if len(yy)>300 or not len(yy) or xx.min()==0 or yy.min()==0 or xx.max()==x1-x0-1 or yy.max()==y1-y0-1:continue
  a[y0+yy,x0+xx]=0;mask[y0+yy,x0+xx]=True
  removed.append({'bbox':[int(x0+xx.min()),int(y0+yy.min()),int(x0+xx.max()+1),int(y0+yy.max()+1)],'pixels':len(yy)})
 changed=np.any(a!=before,2); assert not (changed&~mask).any();assert np.array_equal(a[800:],before[800:])
 outdir.mkdir(exist_ok=True);p=outdir/f'N-walk-phase{phase}-actual-native-local-finish-v03.png';Image.fromarray(a).save(p)
 Image.fromarray(mask.astype('uint8')*255).save(outdir/f'phase{phase}-local-skin-and-oldfinger-mask-v03.png')
 note={'phase':phase,'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'prior':str(inp),'prior_sha256':hashlib.sha256(Path(inp).read_bytes()).hexdigest(),'body_bob':list(bob),'C':1920,'common_rig_root_in_unpadded_frame':[662.8125,917.6920531878804],'storage_translation':[0,0],'changed_pixels':int(changed.sum()),'alpha_changes':int((a[:,:,3]!=before[:,:,3]).sum()),'below_y800_changes':0,'old_isolated_fingertips_removed':removed,'continuous_actual_skin_columns':span,'existing_boot_heel_and_blue_inner_coat_unchanged':True,'original_passed_contact0_and_LOAD1_changed':False,'actor_approval_added':0}
 (outdir/f'phase{phase}-local-finish-proof-v03.json').write_text(json.dumps(note,indent=2)+'\n')
 return a,note
if __name__=='__main__':
 inp=B/'actual-terminal2-rig-v02/N-terminal2-actual-native-part-rig-v02.png';a,n=finish(inp,(7,-6),2,D)
 crop=Image.fromarray(a).crop((573,614,755,719));bg=Image.new('RGBA',crop.size,(192,198,204,255));bg.alpha_composite(crop);bg.convert('RGB').resize((728,420)).save(D/'private-terminal2-finished-native-skin-v03.jpg',quality=93,optimize=True)
 pr=Image.fromarray(a);pr.thumbnail((560,560));bg=Image.new('RGBA',pr.size,(204,208,211,255));bg.alpha_composite(pr);bg.convert('RGB').save(D/'private-terminal2-whole-v03.jpg',quality=91,optimize=True)
 print(json.dumps({k:v for k,v in n.items() if k!='continuous_actual_skin_columns'}))
