from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import numpy as np,json,hashlib,ast,math
B=Path(__file__).parent;D=B/'actual-opposite3-load4-rig-v01';D.mkdir();S=B/'actual-N-skin-joint-finish-v05';src0=Image.open(S/'N-contact0-native-skin-joint-finished-v05.png').convert('RGBA');src1=Image.open(S/'N-LOAD1-native-skin-joint-finished-v05.png').convert('RGBA');W,H=src0.size
polys={'right':[(663,640),(720,640),(721,681),(704,740),(707,790),(695,850),(694,929),(708,956),(714,1021),(701,1050),(657,1050),(642,1022),(646,984),(658,945),(658,902),(652,844),(647,791),(649,745),(650,701),(653,670)],'left':[(588,640),(655,640),(652,695),(647,750),(648,790),(644,827),(644,865),(585,865),(584,822),(598,777),(593,733),(583,695)]};s0mask=Image.new('L',src0.size)
for poly in polys.values():ImageDraw.Draw(s0mask).polygon(poly,fill=255)
s0alpha=np.asarray(src0)[:,:,3];m0=(np.asarray(s0mask)>0)&(s0alpha>0)
L1=np.asarray(Image.open(B/'actual-LOAD1-rig-v03/new-left-support-native-part-rig.png').convert('RGBA'));R1=np.asarray(Image.open(B/'actual-LOAD1-rig-v03/new-right-passing-native-part-rig.png').convert('RGBA'));m1=(L1[:,:,3]>0)|(R1[:,:,3]>0)
basehem=[(577,637),(592,641),(609,645),(626,647),(643,647),(653,646),(669,644),(687,640),(707,636),(727,633),(739,632)];arm_poly=[(539,501),(563,511),(556,542),(531,575),(506,610),(500,629),(484,647),(467,647),(452,635),(456,616),(471,598),(498,570),(517,536),(523,513)];armmask=Image.new('L',src0.size);ImageDraw.Draw(armmask).polygon(arm_poly,fill=255);ap=np.asarray(src0).copy();ap[:,:,3]=np.minimum(ap[:,:,3],np.asarray(armmask));nativearm=Image.fromarray(ap)
# Complete material domains only. Mirroring is a bilateral rig node, not a full-actor flip.
def mirror_native_leg_layers(image,mask):
 a=np.asarray(image).copy();a[~mask]=0;part=Image.fromarray(a).transpose(Image.Transpose.FLIP_LEFT_RIGHT);out=Image.new('RGBA',image.size);out.paste(part,(1325-(W-1),0));return out

def forearm_node(master,bob,wrist_rest):
 A=np.array([543.,517.]);C=A+np.array(bob);u0=np.array([-56.,85.]);ut0=np.array(wrist_rest)-A;u=u0/np.linalg.norm(u0);n=np.array([-u[1],u[0]]);ut=ut0/np.linalg.norm(ut0);nt=np.array([-ut[1],ut[0]]);M=np.column_stack((ut,nt))@np.diag([np.linalg.norm(ut0)/np.linalg.norm(u0),1.])@np.column_stack((u,n)).T;off=C-M@A;inv=np.linalg.inv(M);io=-inv@off;newarm=nativearm.transform(src0.size,Image.Transform.AFFINE,tuple(inv[0])+(io[0],)+tuple(inv[1])+(io[1],),resample=Image.Resampling.BICUBIC);old=Image.new('L',src0.size);old.paste(Image.fromarray((ap[:,:,3]>0).astype(np.uint8)*255),bob);a=np.asarray(master).copy();a[np.asarray(old)>0]=0;out=Image.fromarray(a);out.alpha_composite(newarm)
 # Preserve the original upper-arm cuff through the elbow's fixed cap.
 cap=np.asarray(old)>0;yy=np.indices(cap.shape)[0];cap&=yy<=518+bob[1];orig=Image.new('RGBA',src0.size);orig.paste(src0,bob);r=np.asarray(out).copy();r[cap]=np.asarray(orig)[cap];return Image.fromarray(r),newarm

def cloth_node(frame,bob,amp):
 roi=(350+bob[0],715+bob[1],577+bob[0],957+bob[1]);c=frame.crop(roi);cw,ch=c.size;mesh=[]
 def shift(x,y):return amp*math.sin(math.pi*max(0,min(1,x/(cw-1))))**2*math.sin(math.pi*max(0,min(1,y/(ch-1))))**2
 for y0 in range(0,ch,12):
  for x0 in range(0,cw,12):
   x1=min(cw,x0+12);y1=min(ch,y0+12);mesh.append(((x0,y0,x1,y1),(x0-shift(x0,y0),y0,x0-shift(x0,y1),y1,x1-shift(x1,y1),y1,x1-shift(x1,y0),y0)))
 frame.paste(c.transform(c.size,Image.Transform.MESH,mesh,resample=Image.Resampling.BICUBIC),roi[:2]);return frame
# Same completed native-skin material finish, only allowing the actual longer terminal thigh interval.
a4=Image.open('/workspace/scratch/mythic413-N-walk-author-20261020-r001/contact0-r001/N-contact0-service-raw1024.png').convert('RGBA');ft=ast.parse((B/'finish-N-source0-and-LOAD1-geometric-native-skin-v05.py').read_text().replace('702+bob[1]','780+bob[1]').replace('changed[700+bob[1]:]','changed[800+bob[1]:]'));defs=[n for n in ft.body if isinstance(n,ast.FunctionDef)and n.name in('hsv','finish')];ns=dict(Image=Image,np=np,hashlib=hashlib,D=D,a4=a4,W=W,H=H,basehem=basehem);exec(compile(ast.Module(body=defs,type_ignores=[]),'<actual-opposite-skin-material-finish>','exec'),ns)
results=[]
for phase,image,mask,bob,wrist,amp in [(3,src0,m0,(27,0),(515,568),-3),(4,src1,m1,(34,-12),(504,582),4)]:
 master=Image.new('RGBA',src0.size);master.paste(src0,bob);old=Image.new('L',src0.size);old.paste(Image.fromarray(m0.astype(np.uint8)*255),bob);a=np.asarray(master).copy();a[np.asarray(old.filter(ImageFilter.MaxFilter(3)))>0]=0;out=Image.fromarray(a);legs=mirror_native_leg_layers(image,mask);out.alpha_composite(legs)
 hem=np.interp(np.arange(W),[p[0]+bob[0]for p in basehem],[p[1]+bob[1]for p in basehem]);restore=np.arange(H)[:,None]<=hem[None,:]+1;ar=np.asarray(out).copy();ar[restore]=np.asarray(master)[restore];out=Image.fromarray(ar);out,arm=forearm_node(out,bob,wrist);out=cloth_node(out,bob,amp);out,note=ns['finish'](a4,out,bob,f'N-walk-phase{phase}-actual-native-part-rig-v01');final=Path(note['path']);legs.save(D/f'actual-bilateral-legs-phase{phase}.png');arm.save(D/f'actual-LEFT-counterphase-arm-phase{phase}.png');p0=Image.open(final).convert('RGBA');preview=p0.copy();preview.thumbnail((500,500));bg=Image.new('RGBA',preview.size,(204,208,211,255));bg.alpha_composite(preview);bg.convert('RGB').save(D/f'private-actual-phase{phase}-whole.jpg',quality=91,optimize=True)
 results.append(dict(phase=phase,path=str(final),sha256=hashlib.sha256(final.read_bytes()).hexdigest(),bytes=final.stat().st_size,bob=list(bob),free_LEFT_wrist_rest=list(wrist),LEFT_distal_panel_bend=amp,RIGHT_contact_goldheel=[708.5,850 if phase==3 else 983],LEFT_swing_goldheel=[645,1032]if phase==3 else[612.5,845],single_source_quality='PENDING_INDEPENDENT',C=1920,commonrigroot=[662.8125,917.6920531878804],storage_translation=[0,0],bilateral_leg_rig_center_x=662.5,not_full_actor_mirror=True,RIGHTstaff_retains_anatomicalRIGHT=True))
(D/'actual-opposite3-load4-articulation-contract.json').write_text(json.dumps(dict(status='ACTUAL_TWO_OPPOSITE_POSES_PENDING_INDEPENDENT_QC',frames=results,approved_source0_and1_unchanged=True,wholeframe_resample_or_alphaheightfit=False,actor_approval_added=0),indent=2)+'\n');print(json.dumps(dict(status='ACTUAL_PHASE3_AND4_AUTHORED',frames=[dict(phase=x['phase'],sha256=x['sha256'],bytes=x['bytes'])for x in results])))
