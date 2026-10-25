from pathlib import Path
import json,math,numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import label
from native_run_surface_v03 import *
B=Path(__file__).parent;D=B/'actual-S-RUN6-native-full-actor-v06-exact-latest-cape-root-20261022';D.mkdir(exist_ok=False);LP=B/'actual-S-RUN6-native-leg-controls-v05/S-RUN6-new-native-leg-controls-and-exact-clock-v01.json';lc=json.loads(LP.read_text());MP=Path('/workspace/scratch/mythic413-S-run-author-fresh-20261020-v01/actual-S-RUN6-exact-original-cape-root-strip-material-v06-20261022/own-S-native-cape-original-root-strip-material-handoff-v06.json');mat=json.loads(MP.read_text());assert pin(MP)['sha256']=='8f8a4b2ec7a94c208266a54359e868e7099463eb9e089a33ca41e3b3f444dbca'
ROOT=np.array(lc['common_unpadded_root']);P=np.array(lc['projection']);N=lc['storage_canvas'][0];PAD=lc['storage_translation'][0];U=np.array([.9,0,0]);V=np.array([0,.16,-.84]);BODY=np.column_stack([U,V]);src={}
for k,v in mat['materials'].items():assert pin(v['path'])['sha256']==v['sha256'];src[k]=Image.open(v['path']).convert('RGBA')
def Rx(d):
 t=math.radians(d);c,s=math.cos(t),math.sin(t);return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def Rz(d):
 t=math.radians(d);c,s=math.cos(t),math.sin(t);return np.array([[c,-s,0],[s,c,0],[0,0,1]])
rows=[]
for f in lc['frames']:
 ph=f['phase'];H=np.array(f['pelvis']);lean=[-5,-7,-9,-5,-7,-9][ph];roll=[-1.5,-.5,1.5,1.5,.5,-1.5][ph];Rb=Rx(lean)@Rz(roll);PB=Rz(roll*.4)@BODY;waist=H+PB@(np.array([636,565])-[636,645]);TB=Rb@BODY;attorso=lambda x:waist+TB@(np.array(x)-[636,565]);nodes=[]
 def node(name,im,meta):
  p=D/f'phase{ph}-actual-{name}-native.png';im.save(p);nodes.append(dict(name=name,**pin(p),surface=meta));return im
 pelvis,pmeta=planar(src['pelvis-white-pleated-miniskirt-original-waist-and-thigh-roots'],[636,645],H,PB,ROOT,P,N,PAD);pelvis=node('pelvis-pleated-hem',pelvis,pmeta)
 torso,tmeta=planar(src['torso-original-blue-gold-bodice'],[636,565],waist,TB,ROOT,P,N,PAD);torso=node('torso-blue-gold-bodice',torso,tmeta)
 neck=attorso([635,320]);HB=Rx([1,0,-2,1,0,-2][ph])@Rb@Rz([-1,0,1,1,0,-1][ph])@BODY;head,hmeta=planar(src['head-face-bun-hair-complete-blue-ribbons'],[635,320],neck,HB,ROOT,P,N,PAD);head=node('head-bun-curls-blue-ribbons',head,hmeta)
 lag=[-13,-7,11,13,7,-11][ph]
 def capeworld(uv):
  uv=np.asarray(uv);q=H+(uv-[636,645])@PB.T;g=np.clip((uv[:,1]-690)/300,0,1);q[:,0]+=lag*g;q[:,1]+=[4,9,5,-4,-9,-5][ph]*g;q[:,2]+=[2,0,9,2,0,9][ph]*g;return q
 cape,cmeta=render_surface(src['complete-original-blue-gold-cape-and-both-coattails'],capeworld,ROOT,P,N,PAD);cmeta['all_source_texel_quad_floor']=exact_source_quad_floor(src['complete-original-blue-gold-cape-and-both-coattails'],capeworld);cape=node('complete-original-cloak-two-coattails',cape,cmeta)
 arms={};ainfo={}
 for side,upname,forename,S0,E0,swing in [('R','RIGHT-near-upper-arm','RIGHT-actual-complete-forearm-grip-and-entire-pole-both-ends',[553,343],[511,473],[12,4,-14,-12,-4,14][ph]),('L','LEFT-far-upper-arm','LEFT-far-complete-curved-cuff-forearm-free-hand',[711,345],[772,521],[-22,-8,25,22,8,-25][ph])]:
  S=attorso(S0);Ru=Rx(lean+swing)@Rz(roll);UB=Ru@BODY;E=S+UB@(np.array(E0)-S0);Rf=Rx(lean+swing*.55)@Rz(roll+[2,1,-2,-2,-1,2][ph]);FB=Rf@BODY
  # Actual proximal skin stays fixed to the parent torso at the shoulder then
  # continuously enters its own moving upper-arm surface. No recolor/fill cap.
  def upperworld(uv):
   uv=np.asarray(uv);t=np.clip((uv[:,1]-S0[1]-8)/50,0,1);g=t*t*(3-2*t);return S+(uv-S0)@TB.T*(1-g[:,None])+(uv-S0)@UB.T*g[:,None]
  upper,umeta=render_surface(src[upname],upperworld,ROOT,P,N,PAD);umeta['all_source_texel_quad_floor']=exact_source_quad_floor(src[upname],upperworld);fore,fmeta=planar(src[forename],E0,E,FB,ROOT,P,N,PAD);upper=node(side+'-upper-arm-proximal-native-skin',upper,umeta);fore=node(side+'-complete-forearm-hand'+('-entire-rigidstaff'if side=='R'else '-curved-cuff'),fore,fmeta);lay=Image.new('RGBA',(N,N));lay.alpha_composite(upper);lay.alpha_composite(fore);arms[side]=lay;ainfo[side]=dict(shoulder=S.tolist(),elbow=E.tolist(),upper_UV=UB.tolist(),fore_UV=FB.tolist(),sagittal_counter_degrees=swing,complete_foregrip_and_full_original_staff_rigid=side=='R',same_source_material_original_RGBA=True)
 out=Image.new('RGBA',(N,N));out.alpha_composite(cape)
 # Depth order changes with which genuine leg is currently forward. Each side
 # keeps its original complete gold greave/boot; no painted material swapping.
 order=['R','L']if ph in(0,1,5)else['L','R']
 for side in order:out.alpha_composite(Image.open(f['legs'][side]['path']).convert('RGBA'))
 out.alpha_composite(pelvis);out.alpha_composite(arms['L']);out.alpha_composite(torso);out.alpha_composite(head);out.alpha_composite(arms['R']);op=D/f'S-RUN-phase{ph}-{f["name"]}-actual-native-v01.png';out.save(op)
 ar=np.asarray(out);labs,num=label(ar[:,:,3]>100);cnt=np.bincount(labs.ravel());yy,xx=np.where(ar[:,:,3]>0);rows.append(dict(phase=ph,name=f['name'],**pin(op),C=lc['C'],bodyunit=lc['bodyunit'],common_unpadded_root=ROOT.tolist(),storage_translation=[PAD,PAD],pelvis=H.tolist(),torso_forward_lean_degrees=lean,torso_roll_degrees=roll,original_cloak_lag_native=lag,actual_native_nodes=nodes,arms=ainfo,bones=f['bones'],strong_components_ge200=[int(v)for v in cnt[1:]if v>=200],stored_alpha_bbox=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],storage_border_alpha_contact=bool(xx.min()==0 or yy.min()==0 or xx.max()==N-1 or yy.max()==N-1)))
contract={k:v for k,v in lc.items()if k not in ['frames','status','limits']};contract.update(status='ACTUAL_NEW_OWN_S_RUN6_FINAL_SHARED_V08_CORRECT_LEFTUPPER_BLUEBACKING_PENDING_ACTUAL_SOURCE_CONTACT_LOOP_JOINT_QC',source_materials=pin(MP),leg_controls=pin(LP),renderer=pin(Path(__file__)),surface_renderer=pin(B/'native_run_surface_v03.py'),frames=rows,shared_pure_boots_unchanged_from_exact_leg_controls=True,correct_original_bluewall_owner='LEFT-upper-arm-cuff-source-triangle-native750397775435',contact_parity={'phase0':'LEFT_PLANT','phase3':'RIGHT_PLANT'},source_RGBA_recolored=False,whole_actor_mirror=False,perpose_root_or_C_fit=False,limits=['One declared conditional fixedbone native surface model, not unique hidden anatomy.','All actual six source pixels require independent source/joint/cycle review and bounded actual game/operator checks.','Original cuff/puff and continuous proximal actual-skin material overlap must be judged on these exact new poses; shared LEFT shoulder old action HOLD does not constitute RUN acceptance.'])
p=D/'S-RUN6-own-actual-new-native-full-actor-source-contract-v01.json';p.write_text(json.dumps(contract,indent=2)+'\n');board=Image.new('RGB',(960,1020),'#405265');dr=ImageDraw.Draw(board)
for f in rows:
 im=Image.open(f['path']).crop((380,280,1260,1630));im.thumbnail((310,480));x=f['phase']%3*320;y=f['phase']//3*510;board.paste(im,(x,y+30),im);dr.text((x+6,y+6),str(f['phase'])+' '+f['name'],fill='white')
pv=D/'private-S-RUN6-full-new-source-board-v01.jpg';board.save(pv,quality=74);assert pv.stat().st_size<150000
print(json.dumps(dict(contract=pin(p),preview=pin(pv),actual6=6,strong=[len(f['strong_components_ge200'])for f in rows],border=[f['storage_border_alpha_contact']for f in rows])))
