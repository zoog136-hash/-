from pathlib import Path
import json,hashlib,ast,sys,math
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates
D=Path(__file__).parent;Q=D/'actual-W-local-IDLE2-HIT2-underarm-quality-candidates-v05';Q.mkdir(exist_ok=False)
HAND=D/'common-own-W-native-LEFT-materials-v05/W-own-native-complete-LEFT-and-repaired-hidden-coat-BODY-readonly-handoff-v05.json';h=json.loads(HAND.read_text())
def rec(p):
 p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
# One HIT2 candidate with exactly the frozen actual flow and controls.
C=D/'actual-W-HIT6-own-native-articulated-v02/W-HIT6-actual-own-native-body-head-LEFTguard-source-contract-v01.json';c=json.loads(C.read_text());f=c['frames'][2];src=np.asarray(Image.open(c['source_identity']['path']).convert('RGBA'));H,W=src.shape[:2];yy,xx=np.indices((H,W));SIZE=1536;PAD=np.array([128.,128.]);r=Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01/author-NE-run-contact0-actual-parts-v01.py');tree=ast.parse(r.read_text());ns=dict(np=np,Image=Image,json=json,hashlib=hashlib,SIZE=SIZE,PAD=PAD,W=W,H=H,Q=Q);nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name in {'bone_affine','forward_material'}];exec(compile(ast.Module(nodes,[]),'frozen-actual-mesh-method','exec'),ns)
tree=ast.parse((D/'author-W-HIT6-native-left-profile-own-recoil-and-complete-near-LEFTguard-v02.py').read_text());nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name in {'inverse','sample'}];ns.update(xx=xx,yy=yy,map_coordinates=map_coordinates);exec(compile(ast.Module(nodes,[]),'frozen-actual-body-inverse','exec'),ns)
z=np.load(f['actual_body_forward_flow']['path']);sx,sy,err=ns['inverse'](z['dX'].astype(float),z['dY'].astype(float));assert err<1e-6
body=np.asarray(Image.open(h['body_inputs']['LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots']['body']['path']).convert('RGBA'));out=Image.new('RGBA',(SIZE,SIZE));out.alpha_composite(Image.fromarray(ns['sample'](body,sx,sy)),(128,128));arm=Image.open(h['parts']['LEFT-far-complete-curved-cuff-forearm-free-hand']['path']).convert('RGBA');node=ns['forward_material'](arm,f['LEFT_actual_source_knots'],f['LEFT_actual_guard_knots_unpadded'],'W-local-HIT2-complete-LEFT-v05');out.alpha_composite(node);a=np.array(out);n=a[128:1382,128:1382];protect=np.asarray(Image.open(h['fixed_original_RIGHTgear_conservative_native_support']['path']))>0;oldmask=Path(c['once_body_registration']['path']).parent/'actual-W-HIT6-own-native-articulated-v02/original-W-two-leg-boot-fixed-native-conservative-region.png';protected=protect|(np.asarray(Image.open(oldmask))>0);n[protected]=src[protected];a[128:1382,128:1382]=n;hit=Q/'W-HIT2-own-cloth-v05-local-quality-only.png';Image.fromarray(a).save(hit)
# One IDLE2 material candidate through the owner's exact original operators.
I=Path('/workspace/scratch/mythic413-W-idle-author-20261020-v01');IC=I/'actual-W-IDLE6-native-breath-relax-v02/W-IDLE-six-actual-native-source-fixed-basis-and-loop-contract-v02.json';ic=json.loads(IC.read_text());p=ic['frames'][2]['pose_nodes'];code=(I/'author-W-IDLE6-own-native-breath-cuff-neck-and-cloth-v03.py').read_text().split('frames=[]')[0];code=code.replace('P=Path(__file__).parent','P=Path('+repr(str(I))+')').replace("D=P/'actual-W-IDLE6-native-breath-relax-v02'","D=Path("+repr(str(Q/'IDLE2-original-operator-local'))+")")
saved=sys.argv;sys.argv=['local-quality',str(c['once_body_registration']['path']),str(HAND),ic['shared_basis_independent_SOURCE_PASS']['path'],ic['shared_basis_independent_numeric_PASS']['path'],ic['explicit_actual_native_motion_controls']['path']];idle={};exec(compile(code,'exact-IDLE-owner-operators-local-only','exec'),idle);sys.argv=saved
nx,ny=idle['nx'],idle['ny'];sx=nx.copy();sy=ny.copy()
for _ in range(8):dx,dy=idle['field'](sx,sy,p);sx=nx-dx;sy=ny-dy
out=idle['sample_rgba'](idle['bodyinput'],sx+128,sy+128);ax=nx.copy();ay=ny.copy()
for _ in range(10):qx,qy=idle['arm_forward'](ax,ay,p);ax=nx-(qx-ax);ay=ny-(qy-ay)
node=idle['sample_rgba'](idle['arm'],ax+128,ay+128);out.alpha_composite(node);a=np.array(out);a[idle['protected']]=idle['original'][idle['protected']];ip=Q/'W-IDLE2-own-cloth-v05-local-quality-only.png';Image.fromarray(a).save(ip)
# Native lossless candidate crop and a bounded PRIVATE board, not a new clip.
b=(790,610,965,980);rows=[];board=Image.new('RGB',(350,390),(82,85,89))
for i,path in enumerate([ip,hit]):
 crop=Image.open(path).crop(b);cp=Q/(path.stem+'-native-seam-crop.png');crop.save(cp);bg=Image.new('RGBA',crop.size,(82,85,89,255));bg.alpha_composite(crop);board.paste(bg.convert('RGB'),(i*175,20));rows.append(dict(role=['IDLE2','HIT2'][i],full=rec(path),lossless_crop=rec(cp),storage_crop=list(b)))
board.save(Q/'private-W-IDLE2-HIT2-own-navy-cloth-seam-candidates-v05.jpg',quality=86,optimize=True)
p=Q/'W-IDLE2-HIT2-local-cloth-source-quality-candidates-v05.json';p.write_text(json.dumps(dict(status='TWO_LOCAL_SOURCE_QUALITY_CANDIDATES_NOT_FINAL_ANIMATIONS_OR_APPROVAL',shared=rec(HAND),frozen_HIT_contract=rec(C),frozen_IDLE_contract=rec(IC),outputs=rows,rig_C_root_fixed=True,full_six_rerendered=False,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(rec(p)))
