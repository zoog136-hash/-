from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label
import json,hashlib,math,numpy as np
B=Path(__file__).parent;P=B/'actual-S-ATTACK6-own-native-articulated-rig-v03/S-ATTACK6-own-actual-native-front-six-rig-and-local-cape-HOLD-contract-v03.json';O=B/'actual-S-ATTACK6-own-native-articulated-rig-v02/S-ATTACK6-own-actual-native-front-six-rig-and-local-cape-HOLD-contract-v02.json';j=json.loads(P.read_text());old=json.loads(O.read_text());D=P.parent

def pin(p):p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
rows=[]
for f,of in zip(j['frames'],old['frames']):
 assert f['actual_rig_nodes_unpadded_native']==of['actual_rig_nodes_unpadded_native'];out=Image.new('RGBA',tuple(j['native_canvas']));changes=[]
 for i,(n,on) in enumerate(zip(f['actual_composition_nodes'],of['actual_composition_nodes'])):
  a=np.array(Image.open(n['path']));o=np.array(Image.open(on['path']));nn=int(np.any(a!=o,2).sum());assert i==2 or nn==0;changes.append(nn);out.alpha_composite(Image.fromarray(a))
 a=np.array(Image.open(f['path']));o=np.array(Image.open(of['path']));assert np.array_equal(a,np.array(out));st=j['storage_translation'];probe=[500+st[0],690+st[1],910+st[0],1240+st[1]];x0,y0,x1,y1=probe;boot=int(np.any(a[y0:y1,x0:x1]!=o[y0:y1,x0:x1],2).sum());assert boot==0;cc,n=label(a[:,:,3]>100);ss=np.bincount(cc.ravel());ss[0]=0;assert (ss>=200).sum()==1
 rows.append(dict(phase=f['phase'],frame=pin(f['path']),node_RGBA_changes=changes,all_5_arm_pole_nodes_RGBA_changes=0,recomposition_RGBA_changes=0,fixed_actual_lowerbody_and_boot_probe=probe,fixed_actual_lowerbody_and_boot_RGBA_changes=boot,strong_body_count=1,rig_C_unit_commonroot_storage_grip_changes=0))
proof={'schema':'PR122-own-S-actual6-core-only-local-cape-and-real-ribbon-exact-transfer-v1','contract':pin(P),'prior_contract':pin(O),'checks':rows,'native_material':j['shared_materials'],'source_status':'PENDING_LOCAL_GOLDHEM_SOURCE_AND_ACTUAL6_POSE_JOINT_ONE_SHOT_QC','new_image_view_service_receipt':0,'actual_author_image_ledger_bytes':6017817,'actor_approvals_added':0};q=D/'S-ATTACK6-real-ribbon-and-strict-native-cape-exact-core-only-36node-and-boots-proof-v03.json';q.write_text(json.dumps(proof,indent=2)+'\n')
board=Image.new('RGB',(1320,960),(68,68,72));dr=ImageDraw.Draw(board)
for i,f in enumerate(j['frames']):
 im=Image.open(f['path']);im.thumbnail((430,450));xy=((i%3)*440,(i//3)*480+25);board.paste(im,xy,im);dr.text(((i%3)*440+3,(i//3)*480+3),f['name'],fill='white')
bp=D/'private-own-S-ATTACK6-real-ribbon-and-local-cape-whole-six-board-v03.jpg';board.save(bp,quality=83)
ribbon=Image.new('RGB',(290,180),(68,68,72));rd=ImageDraw.Draw(ribbon)
for i,k in enumerate([3,4]):
 f=j['frames'][k];p=f['actual_rig_nodes_unpadded_native'];r=math.radians(p['ang']);M=np.array([[math.cos(r),-math.sin(r)],[math.sin(r),math.cos(r)]]);pv=np.array([j['common_rig_root_in_unpadded_frame'][0],670.]);off=pv+np.array(p['delta'])-M@pv;corn=np.array([[435,320],[535,320],[535,435],[435,435]])@M.T+off+np.array(j['storage_translation']);x0,y0=np.floor(corn.min(0)-5).astype(int);x1,y1=np.ceil(corn.max(0)+5).astype(int);im=Image.open(f['path']).crop((x0,y0,x1,y1));ribbon.paste(im,(i*145,22),im);rd.text((i*145+3,3),f['name'],fill='white')
rp=D/'private-own-S-ATTACK3-4-short-ribbon-actual-posed-native-crops-v03.jpg';ribbon.save(rp,quality=90);print(json.dumps({'contract':pin(P),'proof':pin(q),'whole6_QA_file_stat_only':pin(bp),'posed_ribbon_QA_stat_only':pin(rp)}))
