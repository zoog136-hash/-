"""Dedicated RIGHT loading/LEFT passing source control; fixed actor root/unit."""
from pathlib import Path
import json,hashlib,math,numpy as np
from PIL import Image,ImageDraw,ImageChops,ImageFilter
from scipy.ndimage import map_coordinates,label,binary_closing,binary_fill_holes,binary_dilation
P=Path(__file__).parent;O=Path('/workspace/scratch/mythic413-NW-walk-Rload4-author-20261020-v03');O.mkdir(exist_ok=False)
S=P/'thunder_female-NW-walk-Rcontact3-finished-hip-join-v05.png';R=Image.open(S).convert('RGBA');Lpath=Path('/workspace/scratch/mythic413-NW-walk-LOAD1-author-20261020-v01/thunder_female-NW-walk-LOAD1-rigged-retouched-v04.png');L=Image.open(Lpath).convert('RGBA');Bpath=Path('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/thunder_female-NW-walk-contact0-v01-service.png');body=Image.open(Bpath).convert('RGBA');W,H=body.size
def poly(q):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return m
def part(source,q):
 a=source.copy();a.putalpha(ImageChops.multiply(a.getchannel('A'),poly(q).filter(ImageFilter.GaussianBlur(.6))));z=np.array(a);cc,n=label(z[:,:,3]>8);sizes=np.bincount(cc.ravel());sizes[0]=0;z[:,:,3][cc!=np.argmax(sizes)]=0;return Image.fromarray(z)
def move(a,A,t):
 inv=np.linalg.inv(A);b=-inv@t;return a.transform((W,H),Image.Transform.AFFINE,(inv[0,0],inv[0,1],b[0],inv[1,0],inv[1,1],b[1]),Image.Resampling.BICUBIC)
def joint(a,b,c,d):
 a,b,c,d=map(np.asarray,(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);A=np.column_stack([v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]])@np.column_stack([u,[-u[1],u[0]]]).T;return A,c-A@a
old=Image.open('/workspace/scratch/mythic413-NW-walk-LOAD1-author-20261020-v01/old-legs-erasure-mask.png').convert('L').filter(ImageFilter.MaxFilter(25));old=ImageChops.lighter(old,poly([(520,714),(715,714),(749,835),(788,966),(850,1145),(711,1155),(650,975),(570,954),(440,938),(446,848),(495,786)]));origbody=body.copy();zz=np.asarray(origbody);YY,XX=np.indices((H,W));blue=(zz[:,:,2]>zz[:,:,0]*1.30)&(zz[:,:,2]>50)&(zz[:,:,3]>16)&(XX>680)&(YY>640);cape=binary_fill_holes(binary_closing(blue,iterations=4));cape=binary_dilation(cape,iterations=6)
fullpoly=Image.open('/workspace/scratch/mythic413-NW-walk-terminal2-author-20261020-v02/terminal2-original-rigid-staff-mask-v01.png').convert('L');gold=(zz[:,:,0]>80)&(zz[:,:,1]>45)&(zz[:,:,0]>zz[:,:,1]*1.04)&(zz[:,:,1]>zz[:,:,2]*1.10);cyan=(zz[:,:,2]>zz[:,:,0]*1.4)&(zz[:,:,1]>zz[:,:,0]*1.3);weapon=binary_dilation((gold|cyan)&(np.asarray(fullpoly)>0)&(zz[:,:,3]>16),iterations=2)&(np.asarray(fullpoly)>0)&(zz[:,:,3]>0)
staffsemantic=Image.fromarray(np.uint8(weapon)*255);upper=YY<714;protect=Image.fromarray(np.uint8(cape|weapon|upper)*255);old=ImageChops.subtract(old,protect);body.paste((0,0,0,0),(0,0),old)
# Exact integer body-bone bob includes rigid staff and its gripping hand.
bodybob=Image.new('RGBA',(W,H));bodybob.paste(body,(0,4));body=bodybob
fx=-.5399492471560389;fy=.841697576624542;e=math.radians(35.264389682754654)
def basis(t):return np.array([[fx*math.cos(t),-fx*math.sin(t)],[-(fy*math.sin(e)*math.cos(t)+math.cos(e)*math.sin(t)),fy*math.sin(e)*math.sin(t)-math.cos(e)*math.cos(t)]])
heel=np.array([594.13,914.32]);fore=np.array([565.,877.5]);v=fore-heel;pitch=math.atan((v[1]-.9*v[0])*(-fx)/(v[0]*math.cos(e)));BT=basis(0)@np.linalg.inv(basis(pitch));target=heel+np.array([111.35431880224218,100.21888692201796]);Bt=target-BT@heel;RA=BT@np.array([587.,858.])+Bt
Lshift=np.array([-170.,-170.]);LA=np.array([800.,1048.])+Lshift
ops=[('RIGHTfar_support_thigh',[(540,713),(638,713),(627,813),(615,863),(552,882),(528,800)],(590,728),(579,850),(670.13,702.32),(659.13,820.32)),('RIGHTfar_support_shin',[(550,838),(612,834),(649,923),(656,977),(600,990),(568,937)],(579,850),(631,972),(659.13,820.32),RA),('LEFTnear_swing_thigh',[(638,713),(713,713),(710,786),(682,853),(634,875),(611,830)],(670,731),(652,844),(612,735),(605,815)),('LEFTnear_swing_shin',[(626,825),(675,820),(723,924),(746,957),(720,991),(687,964),(654,916)],(652,844),(721,960),(605,815),LA)]
layer=Image.new('RGBA',(W,H));meta=[]
for n,q,a,b,c,d in ops:
 A,t=joint(a,b,c,d);layer.alpha_composite(move(part(L,q),A,t));meta.append({'part':n,'target':[np.asarray(c).tolist(),np.asarray(d).tolist()]})
RF=[(557,817),(592,816),(609,844),(616,867),(606,908),(600,925),(578,923),(538,905),(530,876),(528,849),(538,827)];LF=[(785,1010),(834,1018),(850,1050),(861,1149),(840,1168),(817,1165),(778,1168),(748,1154),(749,1120),(774,1090)]
layer.alpha_composite(move(part(R,RF),BT,Bt));layer.alpha_composite(move(part(R,LF),np.eye(2),Lshift));la=layer.getchannel('A');ImageDraw.Draw(la).rectangle((0,0,W-1,717),fill=0);layer.putalpha(la);body.alpha_composite(layer)
staffsemantic.save(O/'Rload4-original-staff-semantic-matte.png');Image.fromarray(np.uint8(cape)*255).save(O/'Rload4-original-cape-semantic-matte.png')
f=O/'DERIVED-Rload4-native1254-actual-costume-control.png';body.save(f);layer.save(O/'Rload4-actual-new-leg-control-layer.png')
d={'status':'ACTUAL_COSTUME_RLOAD4_CONTROL_NOT_FINAL','input_sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'physical_canvas_fixed':2048,'rig_root':[641,1058.3],'storage_translation':[0,0],'source_Rcontact3':str(S),'source_Rcontact3_sha256':hashlib.sha256(S.read_bytes()).hexdigest(),'source_LOAD1_material':str(Lpath),'source_LOAD1_sha256':hashlib.sha256(Lpath.read_bytes()).hexdigest(),'RIGHT_heel_target':target.tolist(),'RIGHT_actual_forefoot3_used':fore.tolist(),'RIGHT_roll_to_flat_degrees':math.degrees(pitch),'RIGHT_forefoot4_target':(BT@fore+Bt).tolist(),'RIGHT_ankle4':RA.tolist(),'LEFT_complete_departing_shoe_translation':Lshift.tolist(),'LEFT_ankle4':LA.tolist(),'upperbody_bob':[0,4],'coat_followthrough':[0,0],'rigid_staff_body_translation':[0,4],'upperbody_RGBA_method':'Exact integer nodebob body4, including whole rigidstaff/grip; no warpedweapon or sampledmaterialoutsidepartmattes','nearLEFTarm':'Forward hold fromactualsource, opposite RIGHTloading/LEFTpassing','limb_targets':meta,'approval_added':0};(O/'Rload4-actual-control-contract-v01.json').write_text(json.dumps(d,indent=2)+'\n')
for n,img in [('Rload4-control-whole-private.jpg',body),('Rload4-control-legs-private.jpg',body.crop((460,640,920,1190)))]:
 bg=Image.new('RGB',img.size,(80,80,80));bg.paste(img,mask=img.getchannel('A'));bg.thumbnail((750,750));bg.save(O/n,quality=85,optimize=True);assert(O/n).stat().st_size<150000
print(json.dumps({'actual_control_sha':d['input_sha256'],'Rheel4':target.tolist(),'Rforefoot4':d['RIGHT_forefoot4_target'],'Rankle4':RA.tolist()}))
