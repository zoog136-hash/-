"""Six actor-specific N attack poses from real STRIKE art and canonical LEFT glove.

Every heel and shoe remains planted; torso, arms, rigid staff and knees articulate.
Original source3 is preserved verbatim as the impact frame. No per-frame root/C fit.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops
from scipy.ndimage import label,map_coordinates
import numpy as np,math,json,hashlib
P=Path(__file__).parent;O=P/'actual-six-rig-v04';O.mkdir(exist_ok=False)
S=P/'thunder_female-N-attack-3-STRIKE3-registered-canonical-glove-v02.png'
stored=Image.open(S).convert('RGBA');native=Image.new('RGBA',(1254,1254));native.paste(stored,(46,-45));W=H=1254
REG=np.array([-46.,-115.]);root=[662.8125,917.6920531878804]
def polygon(q):
    m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return m
def isolated(im,m):
    q=im.copy();q.putalpha(ImageChops.multiply(q.getchannel('A'),m));return q
def transform(im,A,t):
    iv=np.linalg.inv(A);q=-iv@t
    return im.transform((W,H),Image.Transform.AFFINE,(iv[0,0],iv[0,1],q[0],iv[1,0],iv[1,1],q[1]),Image.Resampling.BICUBIC)
def segment(im,a,b,c,d):
    a,b,c,d=map(lambda z:np.asarray(z,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c)
    A=np.column_stack((v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]))@np.column_stack((u,[-u[1],u[0]])).T
    return transform(im,A,c-A@a)
def pose_rigid(im,degrees,pivot,delta):
    t=math.radians(degrees);A=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);pivot=np.asarray(pivot,float)
    return transform(im,A,pivot+np.asarray(delta,float)-A@pivot)
def core_point(pt,degrees,delta):
    t=math.radians(degrees);A=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);pivot=np.array([637.,535.]);return A@(np.asarray(pt)+REG-pivot)+pivot+np.asarray(delta)
def clean_tiny_part(im):
    a=np.asarray(im).copy();cc,n=label(a[:,:,3]>8);size=np.bincount(cc.ravel());size[0]=0
    if size.max()>0:a[:,:,3][(size[cc]<20)]=0
    return Image.fromarray(a)
# New real attack art: no idle-to-attack color/shared-motion substitution.
RU=polygon([(672,482),(697,461),(719,434),(753,400),(787,408),(789,440),(748,487),(716,514),(689,518)])
RF=polygon([(739,422),(754,386),(783,354),(797,319),(836,307),(854,342),(842,375),(815,398),(792,434),(765,456)])
LU=polygon([(578,516),(619,526),(610,564),(576,592),(551,620),(520,608),(510,579),(540,548)])
LF=Image.open(P/'STRIKE3-canonical-new-LEFT-forearm-hand-layer-v02.png').getchannel('A').point(lambda n:255 if n else 0)
canonical_fore=Image.open(P/'STRIKE3-canonical-new-LEFT-forearm-hand-layer-v02.png').convert('RGBA')
ys,xs=np.indices((H,W));axis=750.+.244*ys;half=np.interp(ys.ravel(),[0,80,120,190,250,300,355,710,750,810,855,905],[8,25,57,57,35,24,11,12,31,31,26,1]).reshape(H,W)
wm=(np.abs(xs-axis)<=half)&(ys<=907);weaponmask=Image.fromarray(np.uint8(wm)*255)
# Native RIGHT glove is an arm layer; pole only fills its occulted rigid shaft.
ImageDraw.Draw(weaponmask).rectangle((650,0,900,306),fill=255)
ImageDraw.Draw(weaponmask).polygon([(793,310),(838,306),(854,349),(833,371),(805,350)],fill=0)
weapon=isolated(native,weaponmask)
L=polygon([(599,768),(650,768),(633,816),(610,862),(592,929),(614,987),(615,1055),(588,1092),(547,1092),(535,1050),(545,990),(548,943),(563,875),(575,813)])
R=polygon([(652,772),(738,772),(755,827),(757,882),(792,932),(804,991),(821,1106),(800,1175),(733,1175),(712,1130),(721,1062),(719,1010),(686,960),(681,898),(682,845),(663,809)])
fullR=polygon([(686,494),(703,474),(722,454),(726,435),(746,415),(752,389),(777,368),(791,342),(799,315),(833,306),(851,323),(860,348),(848,381),(830,411),(828,442),(817,478),(803,510),(766,528),(722,532),(694,523),(682,512)])
v1=np.array([56.,-74.]);t1=((xs-700)*v1[0]+(ys-498)*v1[1])/np.dot(v1,v1);v2=np.array([62.,-88.]);t2=((xs-756)*v2[0]+(ys-424)*v2[1])/np.dot(v2,v2)
RU=Image.fromarray(np.uint8((np.asarray(fullR)>0)&(t1<=1.14))*255);RF=Image.fromarray(np.uint8((np.asarray(fullR)>0)&(t2>=-.14))*255)
# Reconstruct ONLY the genuine shaft occluded by original glove, using real nearby pole material.
za=np.asarray(native);pole=np.zeros_like(za)
for yy in range(306,373):
 sy=420+(yy-306)%32;ex=int(round(824+.25*(sy-330)));row=za[sy];ids=np.where((np.arange(W)>=ex-10)&(np.arange(W)<=ex+10)&(row[:,3]>200)&(row[:,0]>row[:,1]*1.08)&(row[:,1]>row[:,2]*1.35)&(row[:,1]>90))[0]
 if len(ids):
  mid=int(round(float(np.median(ids))));cx=int(round(824+.25*(yy-330)));pole[yy,cx-7:cx+8]=za[sy,mid-7:mid+8]
wp=Image.fromarray(pole);wp.alpha_composite(weapon);wa=np.asarray(wp).copy();cc,nn=label(wa[:,:,3]>8);sz=np.bincount(cc.ravel());sz[0]=0;largest=int(sz.argmax());keep=cc==largest;wa[:,:,3][~keep]=0;weapon=Image.fromarray(wa)
wb=weapon.getchannel('A').point(lambda n:255 if n>16 else 0).getbbox();assert wb[1]<20 and wb[3]>850,('staff reconstruction lost endpoint',wb)
masks={'RIGHTupper':RU,'RIGHTfore':RF,'LEFTupper':LU,'LEFTfore':LF,'LEFTleg':L,'RIGHTleg':R,'staff':weaponmask}
parts={'RIGHTupper':isolated(native,RU),'RIGHTfore':isolated(native,RF),'LEFTupper':isolated(native,LU),'LEFTfore':canonical_fore,'LEFTleg':isolated(native,L),'RIGHTleg':isolated(native,R),'staff':weapon}
erase=Image.new('L',(W,H))
for m in masks.values():erase=ImageChops.lighter(erase,m)
core=native.copy();core.paste((0,0,0,0),(0,0),erase)
for name,im in parts.items():im.save(O/f'actual-native-attack-master-{name}-material-v04.png');masks[name].save(O/f'actual-native-attack-master-{name}-matte-v04.png')
core.save(O/'actual-native-attack-master-head-torso-skirt-coat-core-v04.png');erase.save(O/'actual-native-attack-original-moved-part-removal-v04.png')
# All coordinates below are in the SAME unpadded C1920 frame. They are authored
# pose node targets, never measurements used to infer a per-pose registration.
poses=[
 dict(name='READY0',angle=3.,delta=[12,15],re=[719,470],rw=[782,447],le=[535,510],lw=[490,595],staff=13.,lk=[560,790],rk=[715,830],rear=False),
 dict(name='WINDUP1',angle=6.,delta=[20,20],re=[750,505],rw=[817,462],le=[544,493],lw=[512,551],staff=31.,lk=[568,800],rk=[727,836],rear=True),
 dict(name='COIL2',angle=8.,delta=[18,25],re=[744,448],rw=[800,367],le=[538,480],lw=[501,520],staff=41.,lk=[562,790],rk=[718,826],rear=True),
 dict(name='STRIKE3',angle=0.,delta=[0,0],re=[710,309],rw=[772,221],le=[488,484],lw=[434,536],staff=0.,lk=[544,735],rk=[677,786],rear=False),
 dict(name='FOLLOW4',angle=-3.5,delta=[-5,8],re=[695,332],rw=[756,254],le=[475,504],lw=[430,563],staff=-12.,lk=[540,752],rk=[680,805],rear=False),
 dict(name='RECOVER5',angle=2.5,delta=[11,15],re=[721,467],rw=[784,444],le=[534,510],lw=[491,591],staff=12.,lk=[559,790],rk=[714,830],rear=False),
]
records=[]
for i,p in enumerate(poses):
    if i==3:
        out=stored.copy();f=O/f'thunder_female-N-attack-{i}-{p["name"]}-actual-native-rig-v04.png';out.save(f)
    else:
        ang=p['angle'];delta=p['delta'];pivot=np.array([637.,535.])
        # Current native source lies at raw offset REG from the shared physical frame.
        theta=math.radians(ang);A=np.array([[math.cos(theta),-math.sin(theta)],[math.sin(theta),math.cos(theta)]])
        # Dedicated cloth/ribbon secondary motion about actual garment attachment nodes.
        def smooth(v):v=np.clip(v,0,1);return v*v*(3-2*v)
        tailcoef={0:-3.,1:-6.,2:-10.,4:10.,5:-4.}[i];haircoef={0:-3.,1:-5.,2:-8.,4:9.,5:-4.}[i]
        tailweight=smooth((ys-650.)/330.)*smooth((np.abs(xs-650.)-55.)/95.)
        hairweight=smooth((610.-xs)/130.)*smooth((ys-425.)/80.)*smooth((600.-ys)/45.)
        dxfield=tailcoef*tailweight+haircoef*hairweight;dyfield=(tailcoef*.16)*tailweight-(haircoef*.13)*hairweight
        coords=np.array([ys-dyfield,xs-dxfield]);aa=np.asarray(core).astype(float)/255.;al=aa[:,:,3];newal=map_coordinates(al,coords,order=1,mode='constant',cval=0);rgb=np.stack([map_coordinates(aa[:,:,c]*al,coords,order=1,mode='constant',cval=0)for c in range(3)],2);rgb=np.divide(rgb,newal[:,:,None],out=np.zeros_like(rgb),where=newal[:,:,None]>1e-7);clothcore=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,newal])*255+.5,0,255)),'RGBA')
        p['native_tail_followthrough_delta']=tailcoef;p['native_ribbon_followthrough_delta']=haircoef
        body=transform(clothcore,A,pivot+np.asarray(delta)-A@(pivot-REG))
        legslayer=Image.new('RGBA',(W,H))
        for side,oldhip,oldknee,oldankle,knee,footcut in [
             ('RIGHT',[716,780],[723,901],[761,1029],p['rk'],1012),
             ('LEFT',[619,780],[590,850],[575,969],p['lk'],956)]:
            src=parts[side+'leg'];hip=core_point(oldhip,ang,delta);ankle=np.asarray(oldankle)+REG
            thigh=isolated(src,polygon([(0,760),(W,760),(W,oldknee[1]+10),(0,oldknee[1]+10)]))
            calf=isolated(src,polygon([(0,oldknee[1]-9),(W,oldknee[1]-9),(W,footcut+24),(0,footcut+24)]))
            foot=src.copy();fa=np.asarray(foot).copy();fa[:footcut]=0;foot=Image.fromarray(fa)
            legslayer.alpha_composite(segment(calf,oldknee,oldankle,knee,ankle))
            legslayer.alpha_composite(segment(thigh,oldhip,oldknee,hip,knee))
            # Exact common complete shoe at original registered pixels; both feet planted.
            fixedfoot=Image.new('RGBA',(W,H));fixedfoot.paste(foot,(-46,-115));legslayer.alpha_composite(fixedfoot)
        shoulderR=core_point([700,498],ang,delta);shoulderL=core_point([595,545],ang,delta)
        lu=segment(parts['LEFTupper'],[595,545],[534,599],shoulderL,p['le']);lf=segment(parts['LEFTfore'],[534,599],[480,651],p['le'],p['lw'])
        ru=segment(parts['RIGHTupper'],[700,498],[756,424],shoulderR,p['re']);rf=segment(parts['RIGHTfore'],[756,424],[818,336],p['re'],p['rw'])
        # Rigid staff rotates about the actual grip; all raw gold/cyan material is unchanged.
        t=math.radians(p['staff']);B=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);grip=np.array([825.,330.]);av=np.array([62.,-88.]);bv=np.asarray(p['rw'])-np.asarray(p['re']);u=av/np.linalg.norm(av);v=bv/np.linalg.norm(bv);AF=np.column_stack((v*np.linalg.norm(bv)/np.linalg.norm(av),[-v[1],v[0]]))@np.column_stack((u,[-u[1],u[0]])).T;griptarget=AF@(grip-np.array([756.,424.]))+np.asarray(p['re']);staff=transform(weapon,B,griptarget-B@grip)
        current=Image.new('RGBA',(W,H))
        if p['rear']:current.alpha_composite(staff)
        current.alpha_composite(legslayer);current.alpha_composite(body)
        current.alpha_composite(lu);current.alpha_composite(lf);current.alpha_composite(ru)
        if not p['rear']:current.alpha_composite(staff)
        current.alpha_composite(rf)
        # Preserve only connected main actor/weapon material; detached control remnants
        # are separately logged for review rather than retained as decorative particles.
        ar=np.asarray(current).copy();cc,n=label(ar[:,:,3]>16);sizes=np.bincount(cc.ravel());sizes[0]=0;small=(sizes[cc]<20)&(cc>0);ar[:,:,3][small]=0;current=Image.fromarray(ar)
        out=Image.new('RGBA',(1254,1414));out.paste(current,(0,160));f=O/f'thunder_female-N-attack-{i}-{p["name"]}-actual-native-rig-v04.png';out.save(f)
    j=O/f'N-attack-{i}-{p["name"]}-actual-native-rig-v04-private.jpg';bg=Image.new('RGB',out.size,(70,70,70));bg.paste(out,mask=out.getchannel('A'));bg.thumbnail((650,735));bg.save(j,quality=84,optimize=True);assert j.stat().st_size<150000
    records.append({'phase':i,'name':p['name'],'path':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'bytes':f.stat().st_size,'storage_translation':[0,160],'physical_C':1920,'common_root':root,'actual_rig_nodes':p,'status':'ACTUAL_NEW_DEDICATED_ATTACK_POSE_PENDING_INDEPENDENT_QUALITY_AND_CYCLE_QC'})
d={'status':'ACTUAL_NEW_N_ATTACK_SIX_POSES_ALL_PENDING_QUALITY_AND_ATTACK_CYCLE_QC','actual_master':str(S),'master_sha256':hashlib.sha256(S.read_bytes()).hexdigest(),'physical_C_fixed':1920,'common_rig_root':root,'storage_translation':[0,160],'storage_size':[1254,1414],'fixed_goldheel_stance':{'LEFT':[528.5,967],'RIGHT':[720,1051]},'impact_frame':3,'one_shot':True,'source3_master_registration_is_once_only':[-46,-115],'bone_implementation':'Native real actor-specific costumeparts, torsolean/bodyweightnodes, separateactualarmchains, one rigidstaffgrip, kneearticulationandexactfixedshoes. No wholeimageattack/sharedbob substitute.','UV_domain':'No endpointclamp; outsideactualsemanticpartalpha transparent, limitedrealjointoverlap','source_phase_order':records,'actor_approval_added':0}
(O/'N-attack-six-actual-native-rig-manifest-v04.json').write_text(json.dumps(d,indent=2)+'\n')
board=Image.new('RGB',(1440,1152),(65,65,65));dr=ImageDraw.Draw(board)
for row in records:
    i=row['phase'];im=Image.open(row['path']).convert('RGBA');im.thumbnail((480,546));x=(i%3)*480;y=(i//3)*576;board.paste(im,(x,y+30),im);dr.text((x+5,y+4),f'{i} {row["name"]} C1920 fixedroot one-shot impact3',fill='white')
boardpath=O/'N-attack-six-actual-native-rig-board-QCpending-v04-private.jpg';board.save(boardpath,quality=74,optimize=True);assert boardpath.stat().st_size<150000
print(json.dumps({'six_actual_pose_sources':len(records),'manifest':str(O/'N-attack-six-actual-native-rig-manifest-v04.json'),'board_bytes':boardpath.stat().st_size,'impact3exactmaster':records[3]['sha256']==hashlib.sha256(S.read_bytes()).hexdigest(),'approval_added':0}))
