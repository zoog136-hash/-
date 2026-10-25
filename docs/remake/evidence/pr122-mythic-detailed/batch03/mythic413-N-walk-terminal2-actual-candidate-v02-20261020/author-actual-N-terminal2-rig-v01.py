from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import numpy as np,hashlib,json,math,ast
B=Path(__file__).parent;D=B/'actual-terminal2-rig-v01';D.mkdir();P=B/'actual-N-skin-joint-finish-v05/N-contact0-native-skin-joint-finished-v05.png';src=Image.open(P).convert('RGBA');W,H=src.size;bob=(7,-6)
ns=dict(Image=Image,np=np,math=math,W=W,H=H)
t=ast.parse((B/'author-actual-N-LOAD1-rig-v03.py').read_text());defs=[n for n in t.body if isinstance(n,ast.FunctionDef)and n.name in('warp_segment','attach_complete_native_foot')];exec(compile(ast.Module(body=defs,type_ignores=[]),'<retained-native-articulation-functions>','exec'),ns);warp=ns['warp_segment'];attach=ns['attach_complete_native_foot']
polys={'right':[(663,640),(720,640),(721,681),(704,740),(707,790),(695,850),(694,929),(708,956),(714,1021),(701,1050),(657,1050),(642,1022),(646,984),(658,945),(658,902),(652,844),(647,791),(649,745),(650,701),(653,670)],'left':[(588,640),(655,640),(652,695),(647,750),(648,790),(644,827),(644,865),(585,865),(584,822),(598,777),(593,733),(583,695)]};parts={};oldmask=Image.new('L',src.size)
for side,poly in polys.items():
 m=Image.new('L',src.size);ImageDraw.Draw(m).polygon(poly,fill=255);a=np.asarray(src).copy();a[:,:,3]=np.minimum(a[:,:,3],np.asarray(m));im=Image.fromarray(a);parts[side]=im;im.save(D/f'original-native-complete-{side}-leg.png');mm=Image.new('L',src.size);mm.paste(Image.fromarray((a[:,:,3]>0).astype(np.uint8)*255),bob);oldmask=Image.fromarray(np.maximum(np.asarray(oldmask),np.asarray(mm)))
master=Image.new('RGBA',src.size);master.paste(src,bob);clear=np.asarray(master).copy();old=np.asarray(oldmask.filter(ImageFilter.MaxFilter(3)))>0;clear[old]=0;frame=Image.fromarray(clear)
L=Image.new('RGBA',src.size);L.alpha_composite(warp(parts['right'],646,787,687,679,640,843,626,623,True));L.alpha_composite(warp(parts['right'],787,923,679,678,843,1023,623,619,True))
R=Image.new('RGBA',src.size);R.alpha_composite(warp(parts['left'],646,703,619,623,640,670,694,708,True));R.alpha_composite(warp(parts['left'],703,792,623,625,670,742,708,704,True))
# Complete view-dependent heel/sole material from original long boot, articulated by a monotone foot mesh.
# The toe node is authored/occluded, not falsely called a measured bitmap toe.
sy=[880.,923.,983.,1032.,1053.];ty=[981.6,1023.,1066.38200653,1081.61730959,1088.146];LF=Image.new('RGBA',src.size)
for y in range(980,1091):
 sy0=float(np.interp(y,ty,sy));sy1=float(np.interp(y+1,ty,sy));x0,x1=575,665
 quad=(1297-x0,sy0,1297-x0,sy1,1297-x1,sy1,1297-x1,sy0)
 strip=parts['right'].transform((x1-x0,1),Image.Transform.QUAD,quad,resample=Image.Resampling.BICUBIC);LF.paste(strip,(x0,y))
L=attach(L,LF,990,1009)
foot=parts['left'].copy();fa=np.asarray(foot).copy();fa[:730]=0;foot=Image.fromarray(fa);RF=Image.new('RGBA',src.size);RF.paste(foot.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(1329-(W-1),-50));R=attach(R,RF,690,710)
frame.alpha_composite(R);frame.alpha_composite(L)
# Original skirt/gold hem is the foreground occluder of all authored thigh joints.
basehem=[(577,637),(592,641),(609,645),(626,647),(643,647),(653,646),(669,644),(687,640),(707,636),(727,633),(739,632)];xx=np.arange(W);hem=np.interp(xx,[p[0]+bob[0]for p in basehem],[p[1]+bob[1]for p in basehem]);a=np.asarray(frame).copy();ma=np.asarray(master);yy=np.arange(H)[:,None];restore=yy<=hem[None,:]+1;a[restore]=ma[restore];frame=Image.fromarray(a)
# Actual free LEFT forearm counterphase, with the original sleeve/bracer/glove pixels.
arm_poly=[(539,501),(563,511),(556,542),(531,575),(506,610),(485,625),(462,618),(471,598),(498,570),(517,536),(523,513)];am=Image.new('L',src.size);ImageDraw.Draw(am).polygon(arm_poly,fill=255);aa=np.asarray(src).copy();aa[:,:,3]=np.minimum(aa[:,:,3],np.asarray(am));arm=Image.fromarray(aa)
A=np.array([543.,517.]);C=np.array([550.,511.]);V=np.array([-56.,85.]);T=np.array([-36.,60.]);u=V/np.linalg.norm(V);v=np.array([-u[1],u[0]]);ut=T/np.linalg.norm(T);vt=np.array([-ut[1],ut[0]]);M=np.column_stack((ut,vt))@np.diag([np.linalg.norm(T)/np.linalg.norm(V),1.])@np.column_stack((u,v)).T;off=C-M@A;inv=np.linalg.inv(M);io=-inv@off;newarm=arm.transform(src.size,Image.Transform.AFFINE,tuple(inv[0])+(io[0],)+tuple(inv[1])+(io[1],),resample=Image.Resampling.BICUBIC)
armold=Image.new('L',src.size);armold.paste(Image.fromarray((aa[:,:,3]>0).astype(np.uint8)*255),bob);ar=np.asarray(frame).copy();ar[np.asarray(armold)>0]=0;frame=Image.fromarray(ar);frame.alpha_composite(newarm)
# Distal LEFT coat panel has a small, attached cloth bend. No staff/legs lie in this mesh region.
cloth_roi=(350+bob[0],715+bob[1],577+bob[0],957+bob[1]);c=frame.crop(cloth_roi);cw,ch=c.size;mesh=[]
def dx(x,y):
 wx=math.sin(math.pi*max(0,min(1,x/(cw-1))))**2;wy=math.sin(math.pi*max(0,min(1,y/(ch-1))))**2
 return -5.*wx*wy
for y0 in range(0,ch,12):
 for x0 in range(0,cw,12):
  x1=min(cw,x0+12);y1=min(ch,y0+12);mesh.append(((x0,y0,x1,y1),(x0-dx(x0,y0),y0,x0-dx(x0,y1),y1,x1-dx(x1,y1),y1,x1-dx(x1,y0),y0)))
cloth=c.transform(c.size,Image.Transform.MESH,mesh,resample=Image.Resampling.BICUBIC);frame.paste(cloth,cloth_roi[:2]);prepath=D/'N-terminal2-actual-native-rig-before-skinfinish.png';frame.save(prepath);L.save(D/'actual-left-terminal-leg-and-heel-rise.png');R.save(D/'actual-right-late-swing-leg.png');arm.save(D/'actual-native-free-forearm-material.png');newarm.save(D/'actual-left-free-forearm-forward-counterphase.png');LF.save(D/'actual-left-heel-rise-view-dependent-foot-material.png');oldmask.save(D/'old-leg-material-removal-mask.png')
# Use the completed native a4 skin-column technique, retaining the actual white/gold hem.
a4=Image.open('/workspace/scratch/mythic413-N-walk-author-20261020-r001/contact0-r001/N-contact0-service-raw1024.png').convert('RGBA');ftext=(B/'finish-N-source0-and-LOAD1-geometric-native-skin-v05.py').read_text().replace('702+bob[1]','780+bob[1]');ft=ast.parse(ftext);defs=[n for n in ft.body if isinstance(n,ast.FunctionDef)and n.name in('hsv','finish')];gn=dict(Image=Image,np=np,hashlib=hashlib,D=D,a4=a4,W=W,H=H,basehem=basehem);exec(compile(ast.Module(body=defs,type_ignores=[]),'<completed-native-skin-column-technique>','exec'),gn);out,note=gn['finish'](a4,frame,bob,'N-terminal2-actual-native-part-rig-v01');outp=Path(note['path'])
proof=dict(status='ACTUAL_TERMINAL2_NEW_ARTWORK_PENDING_INDEPENDENT_QC',source0_sha256=hashlib.sha256(P.read_bytes()).hexdigest(),final_sha256=hashlib.sha256(outp.read_bytes()).hexdigest(),fixed_C=1920,common_rig_root_in_unpadded_frame=[662.8125,917.6920531878804],storage_translation=[0,0],body_node_bob=list(bob),wholeframe_resize_or_alphaheightfit=False,free_LEFT_forearm_node=dict(source_elbow=[543,517],new_elbow=[550,511],source_wrist=[487,602],new_wrist=[514,571],actual_material=True),LEFT_distal_panel_bend_pixels=-5,RIGHT_staff_and_grip_carried_with_body=True,foot_rig=dict(source_native_long_boot_heel=[680,1032],terminal_projected_heel=[617,1081.61730959],authored_occluded_toe_control=[617,1066.38200653],old_flat_toe_control=[616.5,933.509279257],source_toe_foot_point_is_authored_rig_not_observed_bitmap_claim=True,existing_phase_ground_delta=[0,132.8727273],foot_mesh_source_y=sy,foot_mesh_terminal_y=ty,source_bones_or_hidden_3D_not_uniquely_reconstructed=True),RIGHT_airborne_heel=[712.5,800],skin_note={k:v for k,v in note.items()if k!='skin_column_intervals'},actor_approval_added=0,fullcycle_approved=False);(D/'actual-terminal2-articulation-contract.json').write_text(json.dumps(proof,indent=2)+'\n')
im=Image.fromarray(out);pr=im.copy();pr.thumbnail((560,560));bg=Image.new('RGBA',pr.size,(204,208,211,255));bg.alpha_composite(pr);bg.convert('RGB').save(D/'private-actual-terminal2-full.jpg',quality=91,optimize=True);assert(D/'private-actual-terminal2-full.jpg').stat().st_size<150000;print(json.dumps(dict(final=str(outp),sha256=proof['final_sha256'],bytes=outp.stat().st_size,preview_bytes=(D/'private-actual-terminal2-full.jpg').stat().st_size,bob=list(bob),C=1920)))
