from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib,ast,math
B=Path(__file__).parent;D=B/'actual-NE-LOAD1-rig-v01';D.mkdir();P=B/'NE-contact0-actual-native-background-AA-clean-r002.png';src=Image.open(P).convert('RGBA');s=np.array(src);H,W=s.shape[:2];bob=(9,11)
# Complete original near RIGHT boot including the real heel, outsole and toe.
# The far LEFT upper thigh is already hidden by the retained original coat.
rpoly=[(752,715),(793,700),(807,723),(815,754),(819,795),(832,841),(838,889),(843,935),(866,960),(881,976),(881,1002),(856,1015),(825,1011),(809,1035),(780,1035),(775,997),(770,971),(755,943),(738,913),(724,878),(720,840),(726,803),(735,774),(744,749)]
rm=Image.new('L',src.size);ImageDraw.Draw(rm).polygon(rpoly,fill=255);rmat=np.array(rm)>0
# Genuine saturated blue cloth is a separate semantic foreground, not boot
# material. Cool gray/black boot highlights remain selected.
rgb=s[:,:,:3].astype(float);mx=rgb.max(2);mn=rgb.min(2);sat=np.divide(mx-mn,mx,out=np.zeros_like(mx),where=mx>0);trueblue=(rgb[:,:,2]>rgb[:,:,0]*1.35)&(rgb[:,:,2]>rgb[:,:,1]*1.14)&(sat>.32)&(mx>45);rmat&=~trueblue;rmat&=s[:,:,3]>0
# Native cloth edge above the visible far calf. All gold/blue coat pixels on
# its foreground side are retained; old boot material below it is removed.
cloth_edge=[(480,922),(500,915),(520,911),(540,913),(560,916),(580,919),(600,925),(620,934),(640,949),(660,972),(680,993),(690,991)];lmat=np.zeros((H,W),bool)
for x in range(505,651):
 y0=int(math.ceil(np.interp(x,[p[0]for p in cloth_edge],[p[1]for p in cloth_edge])))+3;lmat[y0:1196,x]=s[y0:1196,x,3]>0
parts={};files=[]
for side,mask in [('RIGHT',rmat),('LEFT',lmat)]:
 a=s.copy();a[~mask]=0;parts[side]=Image.fromarray(a);q=D/f'original-native-complete-{side}-visible-boot-material.png';parts[side].save(q);files.append(q);Image.fromarray(mask.astype('uint8')*255).save(D/f'original-native-{side}-boot-semantic-matte.png')
def project_bone(part,A,B,C,F,cap=6):
 a=np.array(part);yy,xx=np.indices(a.shape[:2]);A=np.array(A,float);B=np.array(B,float);C=np.array(C,float);F=np.array(F,float);V=B-A;T=F-C;vl=np.linalg.norm(V);tl=np.linalg.norm(T);u=V/vl;n=np.array([-u[1],u[0]]);ut=T/tl;nt=np.array([-ut[1],ut[0]]);long=(xx-A[0])*u[0]+(yy-A[1])*u[1];a[(long < -cap)|(long>vl+cap)]=0;im=Image.fromarray(a);M=np.column_stack((ut,nt))@np.diag([tl/vl,1.])@np.column_stack((u,n)).T;off=C-M@A;inv=np.linalg.inv(M);io=-inv@off
 return im.transform(part.size,Image.Transform.AFFINE,tuple(inv[0])+(io[0],)+tuple(inv[1])+(io[1],),resample=Image.Resampling.BICUBIC)
N=Path('/workspace/scratch/mythic413-N-walk-load-author-fresh-20261020-v01');tree=ast.parse((N/'author-actual-N-LOAD1-rig-v03.py').read_text());ns=dict(Image=Image,np=np,W=W,H=H);exec(compile(ast.Module([n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name=='attach_complete_native_foot'],[]),'native-complete-foot-joint','exec'),ns);attach=ns['attach_complete_native_foot']
R=project_bone(parts['RIGHT'],[774,724],[793,849],[783,735],[737,920],cap=8);R.alpha_composite(project_bone(parts['RIGHT'],[793,849],[811,944],[737,920],[679,1063],cap=8))
rf=np.array(parts['RIGHT']);rf[:900]=0;RF=Image.new('RGBA',src.size);RF.paste(Image.fromarray(rf),(-132,119));R=attach(R,RF,1028,1048)
L=project_bone(parts['LEFT'],[595,950],[554,1074],[619,865],[666,934],cap=8);lf=np.array(parts['LEFT']);lf[:1040]=0;LF=Image.new('RGBA',src.size);LF.paste(Image.fromarray(lf),(112,-140));L=attach(L,LF,908,925)
body=s.copy();body[rmat|lmat]=0;master=Image.new('RGBA',src.size);master.paste(Image.fromarray(body),bob);frame=Image.new('RGBA',src.size);frame.alpha_composite(L);frame.alpha_composite(master);frame.alpha_composite(R)
# Original white/gold skirt, torso and RIGHT grip remain the real foreground
# occluder of the near hip. The new leg is not pasted over the skirt.
hem=[(600,704),(620,714),(650,718),(675,714),(700,710),(725,706),(750,699),(775,689),(798,680)];fullmaster=Image.new('RGBA',src.size);fullmaster.paste(src,bob);out=np.array(frame);orig=np.array(fullmaster);hy=np.interp(np.arange(W),[p[0]+bob[0]for p in hem],[p[1]+bob[1]for p in hem]);foreground=np.arange(H)[:,None]<=hy[None,:];out[foreground]=orig[foreground];frame=Image.fromarray(out)
# Real free far LEFT forearm counterphase; no staff or whole-actor flip.
arm_poly=[(567,520),(594,540),(579,572),(551,608),(514,645),(496,668),(478,680),(455,676),(446,661),(453,641),(473,621),(507,585),(539,550)];am=Image.new('L',src.size);ImageDraw.Draw(am).polygon(arm_poly,fill=255);aa=s.copy();aa[np.array(am)==0]=0;arm=Image.fromarray(aa);newarm=project_bone(arm,[559,550],[481,645],[568,561],[506,633],cap=35);old=Image.new('L',src.size);old.paste(Image.fromarray((aa[:,:,3]>0).astype('uint8')*255),bob);out=np.array(frame);out[np.array(old)>0]=0;frame=Image.fromarray(out);frame.alpha_composite(newarm)
q=D/'NE-LOAD1-actual-native-part-rig-v01.png';frame.save(q);R.save(D/'actual-near-RIGHT-support-leg-and-complete-native-shoe.png');L.save(D/'actual-far-LEFT-passing-calf-and-complete-native-shoe.png');RF.save(D/'actual-native-RIGHT-full-foot-translated-minus132-plus119.png');LF.save(D/'actual-native-LEFT-full-foot-in-AIR.png');arm.save(D/'original-native-LEFT-free-forearm-and-hand-material.png');newarm.save(D/'actual-LEFT-free-forearm-forward-counterphase.png');Image.fromarray(body).save(D/'original-native-body-coat-RIGHTstaff-with-old-visible-boots-removed-INPUT.png')
note={'status':'ACTUAL_NEW_NE_LOAD1_PRODUCTION_PENDING_INDEPENDENT_SOURCE_AND_HEEL_PAIR_QC','path':str(q),'sha256':hashlib.sha256(q.read_bytes()).hexdigest(),'source0_sha256':hashlib.sha256(P.read_bytes()).hexdigest(),'native_canvas':[W,H],'C':2432,'bodyunit':2.375,'common_rig_root_in_unpadded_frame':[716.2291666666666,1054.2766007046484],'storage_translation':[0,0],'body_node_bob':list(bob),'native_NE_ground_delta':[-132.23325357766257,119.00992821989632],'actual_complete_RIGHT_foot_integer_translation':[-132,119],'visible_RIGHT_goldheel_0':[799,1027],'visible_RIGHT_goldheel_1':[667,1146],'visible_RIGHT_actual_outsole_stiletto_tip_0':[799.5,1028],'visible_RIGHT_actual_forefoot_outsole_0':[841,1011],'LEFT_airborne_goldheel_1':[639.5,1047],'same_original_body_and_anatomical_RIGHT_staff':True,'whole_actor_flip_or_perpose_C_rootfit_or_alphaheight_normalization':False,'actual_source_bone_controls_not_claimed_unique_hidden3D_reconstruction':True,'declared_bone_endpoint_cap_native_pixels':8,'declared_freeforearm_material_hand_endpoint_cap':35,'actor_approval_added':0};(D/'NE-LOAD1-actual-articulation-and-native-foot-contract-v01.json').write_text(json.dumps(note,indent=2)+'\n')
im=frame.copy();im.thumbnail((650,650));bg=Image.new('RGBA',im.size,(196,202,208,255));bg.alpha_composite(im);p=D/'private-NE-LOAD1-actual-whole-v01.jpg';bg.convert('RGB').save(p,quality=92,optimize=True);assert p.stat().st_size<150000;print(json.dumps({k:v for k,v in note.items()if k not in ['actual_source_bone_controls_not_claimed_unique_hidden3D_reconstruction']}))
