from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-NE-ATTACK6-native-rig-v06';P=D/'NE-ATTACK6-exact-final-actual-native-source-provenance-contract-v07.json';j=json.loads(P.read_text())
def pin(p):r=Path(p).read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
checks=[];ref=None;ras=[];las=[];rgba=[]
for z in j['frames']:
 out=Image.new('RGBA',(1536,1536))
 for q in z['actual_composition_nodes']:
  assert pin(q['path'])==q;out.alpha_composite(Image.open(q['path']).convert('RGBA'))
 a=np.array(Image.open(z['path']).convert('RGBA'));assert not np.any(a!=np.array(out));assert pin(z['path'])['sha256']==z['sha256'];rgba.append(hashlib.sha256(a.tobytes()).hexdigest())
 rn=np.array(Image.open(z['actual_composition_nodes'][1]['path']));ln=np.array(Image.open(z['actual_composition_nodes'][0]['path']))
 if ref is None:ref=a.copy();rref=rn.copy();lref=ln.copy()
 rc=int(np.any(rn[944:]!=rref[944:],2).sum());lc=int(np.any(ln[1090:]!=lref[1090:],2).sum());assert rc==lc==0
 points=[(799,1028),(800,1028),(841,1011),(842,1011),(527,1187)];pc=sum(int(np.any(a[y,x]!=ref[y,x]))for x,y in points);assert pc==0
 c,n=label(a[:,:,3]>100);s=np.bincount(c.ravel());s[0]=0;main=int((s>=200).sum());small=int(((s>=3)&(s<200)).sum());assert main==1 and small==0
 edge=int((a[:3,:,3]>16).sum()+(a[-3:,:,3]>16).sum()+(a[:,:3,3]>16).sum()+(a[:,-3:,3]>16).sum());assert edge==0
 checks.append({'phase':z['phase'],'actual_source':pin(z['path']),'rgba_sha256':rgba[-1],'actual_nodes_recomposition_RGBA_changed':0,'RIGHT_complete_boot_node_RGBA_changed':rc,'LEFT_complete_boot_node_RGBA_changed':lc,'observed_actual_support_RGBA_points':[[x,y,a[y,x].tolist()]for x,y in points],'observed_support_RGBA_changed':pc,'alpha100_strong_bodies':main,'alpha100_detached_components_ge3':small,'alpha16_near_canvas_edge_pixels':edge})
assert len(set(rgba))==6
q={'schema':'PR122-final-NE-attack-v06-native-node-and-fixedsupport-verification-v1','status':'PASS_FINITE_NATIVE_RECOMPOSITION_FIXED_BOOT_MATERIAL_AND_SUPPORT_REFERENCE_ONLY','source_contract':pin(P),'six_actual_RGBA_unique':6,'checks':checks,'independent_visual_source_cycle_or_game_approval_added':0};p=D/'NE-ATTACK6-v06-exact-native-final-node-and-fixed-support-proof-v02.json';assert not p.exists();p.write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({'proof':pin(p),'six_native_nodes_sole_support_checks':'PASS','visual_or_game_approval_added':0}))
# Additive freeze for final v06 source after the existing v01..05 immutable set.
paths={p for p in D.rglob('*')if p.is_file()and p.suffix.lower()in('.png','.json')and not any(v in p.name.lower()for v in('private','preview','ledger'))}
paths.update([B/'finish-NE-ATTACK6-actual-far-LEFT-original-hair-cuff-rim-completeness-v06.py',Path(__file__),B/'NE-ATTACK6-v01-v05-actual-native-inputs-parts-masks-renderers-full-immutable-frozen-allowlist-v01.json'])
rows=[pin(p)for p in sorted(paths)];m={'schema':'PR122-final-actual-source-additive-immutable-allowlist-v1','status':'NE_ATTACK6_ACTUAL_FINAL_V06_PENDING_INDEPENDENT_QC','source_contract':pin(P),'finite_proof':pin(p),'files':rows,'file_count':len(rows),'total_bytes':sum(z['bytes']for z in rows),'prior_intermediates_preserved':True,'actor_approvals_added':0};mp=B/'NE-ATTACK6-final-v06-actual-source-nodes-proofs-additive-frozen-allowlist-v02.json';assert not mp.exists();mp.write_text(json.dumps(m,indent=2)+'\n');print(json.dumps({'additive_freeze':pin(mp),'files':len(rows),'bytes':m['total_bytes']}))
