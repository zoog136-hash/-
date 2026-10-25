from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
from scipy.ndimage import binary_dilation
import numpy as np,json,hashlib,ast,math,importlib.util
B=Path(__file__).parent;D=B/'actual-opposite-terminal5-rig-v01';D.mkdir();S=B/'actual-N-skin-joint-finish-v05';src0=Image.open(S/'N-contact0-native-skin-joint-finished-v05.png').convert('RGBA');src2=Image.open(B/'actual-terminal2-local-finish-v06/N-walk-phase2-actual-native-local-finish-v06.png').convert('RGBA');W,H=src0.size;bob=(20,-6)
polys={'right':[(663,640),(720,640),(721,681),(704,740),(707,790),(695,850),(694,929),(708,956),(714,1021),(701,1050),(657,1050),(642,1022),(646,984),(658,945),(658,902),(652,844),(647,791),(649,745),(650,701),(653,670)],'left':[(588,640),(655,640),(652,695),(647,750),(648,790),(644,827),(644,865),(585,865),(584,822),(598,777),(593,733),(583,695)]};oldmask=Image.new('L',src0.size)
for poly in polys.values():ImageDraw.Draw(oldmask).polygon(poly,fill=255)
m0=(np.asarray(oldmask)>0)&(np.asarray(src0)[:,:,3]>0)
L=np.array(Image.open(B/'actual-terminal2-rig-v01/actual-left-terminal-leg-and-heel-rise.png'));R=np.array(Image.open(B/'actual-terminal2-rig-v01/actual-right-late-swing-leg.png'));m2=(L[:,:,3]>0)|(R[:,:,3]>0)
arm_poly=[(539,501),(563,511),(556,542),(531,575),(506,610),(500,629),(484,647),(467,647),(452,635),(456,616),(471,598),(498,570),(517,536),(523,513)];armmask=Image.new('L',src0.size);ImageDraw.Draw(armmask).polygon(arm_poly,fill=255);ap=np.array(src0);ap[:,:,3]=np.minimum(ap[:,:,3],np.asarray(armmask));nativearm=Image.fromarray(ap)
ns=dict(Image=Image,np=np,math=math,src0=src0,W=W,H=H,ap=ap,nativearm=nativearm);tree=ast.parse((B/'author-actual-N-opposite-contacts3-load4-v01.py').read_text());defs=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in('mirror_native_leg_layers','forearm_node','cloth_node')];exec(compile(ast.Module(defs,[]),'retained-native-pose-nodes','exec'),ns)
master=Image.new('RGBA',src0.size);master.paste(src0,bob);old=Image.new('L',src0.size);old.paste(Image.fromarray(m0.astype('uint8')*255),bob);a=np.array(master);a[np.asarray(old.filter(ImageFilter.MaxFilter(3)))>0]=0;out=Image.fromarray(a);legs=ns['mirror_native_leg_layers'](src2,m2);out.alpha_composite(legs)
basehem=[(577,637),(592,641),(609,645),(626,647),(643,647),(653,646),(669,644),(687,640),(707,636),(727,633),(739,632)];hem=np.interp(np.arange(W),[p[0]+bob[0]for p in basehem],[p[1]+bob[1]for p in basehem]);restore=np.arange(H)[:,None]<=hem[None,:]+1;a=np.array(out);a[restore]=np.asarray(master)[restore];out=Image.fromarray(a);out,arm=ns['forearm_node'](out,bob,(493,595));out=ns['cloth_node'](out,bob,5);pre=np.array(out);a=pre.copy();leg=np.asarray(legs);ar=np.asarray(arm)
sp=importlib.util.spec_from_file_location('nativecap',B/'finish-new-N-poses-native-skin-v03.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
# Actual mirror of terminal2 short-boot garter, excluding its upper outer
# joint closure. Long-boot edge is read from the same accepted actual node.
shortedge=[(668,643),(673,645),(679,646),(685,648),(691,649),(700,649),(706,650),(712,648),(718,647),(724,645),(727,644)]
edges=[sorted((1325-x,y)for x,y in shortedge),[]];lh,ls,lv=m.hsv(L)
for x in range(589,651):
 ys=np.arange(660,735);gold=(L[ys,x,3]>180)&(lh[ys,x]>20)&(lh[ys,x]<65)&(ls[ys,x]>.28)&(lv[ys,x]>.25)
 if gold.any():edges[1].append((1325-x,int(ys[gold][0])-1))
edges[1].sort();allcap=np.zeros((H,W),np.uint8);caps=[]
for side,edge in enumerate(edges):
 tl,tr=((578+bob[0],654+bob[0])if side==0 else(658+bob[0],739+bob[0]));toppts=[(x,m.hem_top(x-bob[0])+bob[1])for x in range(tl,tr+1)];poly=toppts+list(reversed(edge));hires=Image.new('L',(W*4,H*4));ImageDraw.Draw(hires).polygon([(x*4,y*4)for x,y in poly],fill=255);ca=np.array(hires.resize((W,H),Image.Resampling.LANCZOS));ca[ca<8]=0
 for x in range(tl,tr+1):ca[:m.hem_top(x-bob[0])+bob[1],x]=0
 caps.append((side,ca));allcap=np.maximum(allcap,ca)
h,s,v=m.hsv(a);skinlike=(h<30)&(s>.1)&(v>.13)&(a[:,:,3]>0);removedold=np.zeros((H,W),bool)
for x in range(570+bob[0],746+bob[0]):
 for y in range(m.hem_top(int(np.clip(x-bob[0],577,739)))+bob[1],735):
  if allcap[y,x]==0 and leg[y,x,3]==0 and skinlike[y,x]:a[y,x]=0;removedold[y,x]=True
for side,ca in caps:
 dc=m.donors[side];xs=np.array([c[0]for c in dc]);yy,xx=np.nonzero(ca)
 for x in np.unique(xx):
  rows=np.flatnonzero(ca[:,x]);top=int(rows.min());bot=int(rows.max());sx,st,sb=dc[int(np.argmin(abs(xs-(x-bob[0]))))];extent=min(sb-st-1,max(3,bot-top))
  for y in rows:
   fy=st+(y-top)/max(bot-top,1)*extent;ya=int(np.floor(fy));f=fy-ya;rgb=np.rint(m.source[ya,sx,:3]*(1-f)+m.source[ya+1,sx,:3]*f).astype('uint8');opacity=float(ca[y,x])/255
   if opacity>.97:a[y,x,:3]=rgb;a[y,x,3]=253
   else:
    olda=a[y,x,3]/255;newa=253/255*opacity;oa=newa+olda*(1-newa)
    if oa>0:a[y,x,:3]=np.rint((rgb*newa+a[y,x,:3]*olda*(1-newa))/oa).astype('uint8');a[y,x,3]=round(oa*255)
fm=np.zeros((H,W),bool);fm[610+bob[1]:647+bob[1],486+bob[0]:511+bob[0]]=True;fm&=~binary_dilation(ar[:,:,3]>0,iterations=1);a[fm]=0;changed=np.any(a!=pre,2);assert not(changed&~((allcap>0)|removedold|fm)).any();assert np.array_equal(a[800:],pre[800:]);p=D/'N-walk-phase5-actual-native-part-rig-v01.png';Image.fromarray(a).save(p);legs.save(D/'actual-bilateral-terminal5-complete-leg-nodes.png');arm.save(D/'actual-terminal5-LEFT-counterphase-arm-node.png');Image.fromarray(pre).save(D/'actual-terminal5-before-local-skin-finish.png');Image.fromarray(((allcap>0)|removedold|fm).astype('uint8')*255).save(D/'actual-terminal5-local-skin-and-oldfinger-mask.png')
proof={'status':'ACTUAL_OPPOSITE_TERMINAL5_PENDING_INDEPENDENT_SOURCE_AND_CYCLE_QC','path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'native_canvas':[W,H],'C':1920,'common_rig_root_in_unpadded_frame':[662.8125,917.6920531878804],'storage_translation':[0,0],'body_node_bob':list(bob),'actual_material_lowerlimb_source2_sha256':hashlib.sha256((B/'actual-terminal2-local-finish-v06/N-walk-phase2-actual-native-local-finish-v06.png').read_bytes()).hexdigest(),'bilateral_node_mapping':'x=1325-source_x; no whole-actor flip','RIGHT_staff_preserves_anatomical_RIGHT':True,'free_LEFT_wrist_rest':[493,595],'left_distal_cloth_bend_pixels':5,'RIGHT_terminal_goldheel':[708,1081.61730959],'RIGHT_terminal_authored_occluded_toe_control':[708,1066.38200653],'LEFT_airborne_goldheel':[612.5,800],'toe_control_not_claimed_visible_bitmap_measurement':True,'actual_garter_edges':edges,'local_finish_below_y800_RGBA_changed':0,'wholeframe_resize_perpose_C_or_alphaheightfit':False,'actor_approval_added':0};(D/'actual-terminal5-articulation-contract-v01.json').write_text(json.dumps(proof,indent=2)+'\n')
for box,name,sz in [((570+bob[0],610+bob[1],745+bob[0],725+bob[1]),'private-actual-terminal5-native-caps-v01.jpg',(700,460))]:
 im=Image.fromarray(a).crop(box);bg=Image.new('RGBA',im.size,(192,198,204,255));bg.alpha_composite(im);bg.convert('RGB').resize(sz).save(D/name,quality=93,optimize=True)
im=Image.fromarray(a);im.thumbnail((560,560));bg=Image.new('RGBA',im.size,(192,198,204,255));bg.alpha_composite(im);bg.convert('RGB').save(D/'private-actual-terminal5-whole-v01.jpg',quality=91,optimize=True);print(json.dumps({k:v for k,v in proof.items()if k!='actual_garter_edges'}))
