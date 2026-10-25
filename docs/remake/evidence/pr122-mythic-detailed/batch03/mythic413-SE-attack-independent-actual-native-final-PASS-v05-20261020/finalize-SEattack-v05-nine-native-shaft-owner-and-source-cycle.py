from pathlib import Path
import json,hashlib,math
import numpy as np
from PIL import Image
from scipy.ndimage import label
B=Path(__file__).parent;A=Path('/workspace/scratch/mythic413-SE-attack-author-20261020-v01')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def check(s):
 p=Path(s['path']);assert pin(p)['sha256']==s['sha256'];return p
def load(s):return json.loads(check(s).read_text())
def rgba(s):return np.array(Image.open(check(s)).convert('RGBA'))
cp=A/'actual-SE-ATTACK6-native-articulated-rig-v05/SE-ATTACK6-actual-native-final-specific-owner-and-PASS-cape-candidate-contract-v07.json';assert pin(cp)['sha256']=='f7f9b8475a5dce8995b4a12d52f772bac1aca777178239f2cd63b4400c17b43c';c=json.loads(cp.read_text());m=load(c['shared_materials']);owner=load(m['final_nine_original_shaft_edge_AA_owner']);old=load(owner['prior_material']);src=rgba(c['source']);mm=np.array(Image.open(check(owner['source_owner_mask'])))>0;assert mm.sum()==9
prevp=A/'actual-SE-ATTACK6-native-articulated-rig-v04/SE-ATTACK6-actual-native-final-specific-owner-and-PASS-cape-candidate-contract-v06.json';prev=json.loads(prevp.read_text());priorbinding=B/'SEattack-v04-independent-exact36-current-owner-native-node-sole-and-grip-binding-v01.json';pb=json.loads(priorbinding.read_text());assert pin(prevp)==pb['source_contract']
RF='RIGHT-near-complete-forearm-grip-hand';POLE='complete-rigid-RIGHT-near-staff';newRF=rgba(m['parts'][RF]);oldRF=rgba(old['parts'][RF]);newP=rgba(m['parts'][POLE]);oldP=rgba(old['parts'][POLE])
assert np.array_equal(oldRF[mm],src[mm]) and np.array_equal(newP[mm],src[mm]) and not np.any(newRF[mm]);assert np.array_equal(newRF[~mm],oldRF[~mm]) and np.array_equal(newP[~mm],oldP[~mm]);assert np.array_equal(newRF[438:],oldRF[438:])
for k,v in m['parts'].items():
 if k not in [RF,POLE]:assert v==old['parts'][k]
assert m['fullCORE']==old['fullCORE'] and m['actual_native_controls']==old['actual_native_controls'] and m['actual_local_cape_retouch']==old['actual_local_cape_retouch']
assert np.array_equal(src[newRF[:,:,3]>0],newRF[newRF[:,:,3]>0])
W=1792
def transform(a,M,O):
 im=Image.new('RGBA',(W,W));im.paste(Image.fromarray(a),(0,0));inv=np.linalg.inv(M);q=-inv@O;v=np.array(im.transform((W,W),Image.Transform.AFFINE,tuple(inv[0])+(q[0],)+tuple(inv[1])+(q[1],),Image.Resampling.BICUBIC));out=np.zeros_like(v);out[128:,128:]=v[:-128,:-128];return out
def fmap(p):
 a=np.array([552.,459.]);b=np.array([417.,482.]);c=np.array(p['re'],float);d=np.array(p['rw'],float);u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);M=np.column_stack([v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]])@np.column_stack([u,[-u[1],u[0]]]).T;return M,c-M@a
rows=[]
for i,(f,pf) in enumerate(zip(c['frames'],prev['frames'])):
 for k in ['physical_C','bodyunit','common_rig_root_in_unpadded_frame','storage_translation','actual_rig_nodes_unpadded_native','RIGHT_exact_same_forearm_affine_grip_target','RIGHT_rigid_staff_matrix','native_original_full_staff_top_tip_target','native_original_full_staff_bottom_tip_target']:assert f[k]==pf[k]
 nodes=[rgba(z) for z in f['actual_composition_nodes']];oldnodes=[rgba(z) for z in pf['actual_composition_nodes']];changes=[]
 for k in range(6):
  d=int(np.count_nonzero(np.any(nodes[k]!=oldnodes[k],2)));changes.append(d)
  if k not in [4,5]:assert d==0
 FM,FO=fmap(f['actual_rig_nodes_unpadded_native']);G=np.array([382.,466.]);grip=FM@G+FO;SM=np.array(f['RIGHT_rigid_staff_matrix']);SO=grip-SM@G
 assert np.array_equal(transform(newRF,FM,FO),nodes[5]) and np.array_equal(transform(newP,SM,SO),nodes[4])
 out=Image.new('RGBA',(W,W))
 for a in nodes:out.alpha_composite(Image.fromarray(a))
 actual=rgba(dict(path=f['path'],sha256=f['sha256']));assert np.array_equal(actual,np.array(out));lab,n=label(actual[:,:,3]>100);counts=np.bincount(lab.ravel())[1:];assert np.count_nonzero(counts>=200)==1 and not np.any((counts>=3)&(counts<200));assert not np.any(actual[[0,-1],:,3]>16) and not np.any(actual[:,[0,-1],3]>16)
 rows.append(dict(phase=i,name=f['name'],source=pin(f['path']),RGBA_sha256=hashlib.sha256(actual.tobytes()).hexdigest(),node_RGBA_changes=changes,exact36node_recomposition_mismatch=0,independently_rerasterized_current_RF_and_rigid_pole_mismatch=0,prior_other_four_node_RGBA_mismatch=0,true_original_fingers_y438plus_native_RGBA_mismatch=0,previous_fixed_original_lowerboot_sole_and_cape_binding_transferred_unchanged=True,strong_bodies=1,small_alpha100_components_ge3=[]))
assert len(rows)==6 and len({x['RGBA_sha256']for x in rows})==6
outp=B/'SEattack-v05-independent-final-nine-shaft-owner-and-exact36-source-binding-v01.json';assert not outp.exists();result=dict(status='PASS_FINAL_NINE_ORIGINAL_SHAFT_EDGE_OWNER_EXACT36_SOURCE_BINDING',source_contract=pin(cp),prior_binding=pin(priorbinding),original_shaft_native_RGBA_owner=owner['source_owner_mask'],owner_source_bbox=[369,433,371,438],original_RGBA_transferred=9,original_fist_y438plus_RGBA_mismatch=0,all_other_native_parts_CORE_cape_boots_controls_mismatch=0,independently_rerasterized_current_RF_and_pole_count=12,checks=rows,images_viewed=0,repository_changes=0,game_tests_run=0,actor_approvals_added=0);outp.write_text(json.dumps(result,indent=2)+'\n')
# Complete the already successful one private native view, preserving all history.
lp=B/'private-image-ledger-working-v01.json';ledger=json.loads(lp.read_text());last=ledger['entries'][-1]
if last['view']==100 and last['status']=='RESERVED_NOT_YET_VIEWED':
 assert ledger['context_total_viewed_bytes']==5800492;last['status']='PRIVATELY_VIEWED';last['actual_view_payload_bytes']=last['bytes'];ledger['new_viewed_bytes']+=last['bytes'];ledger['context_total_viewed_bytes']+=last['bytes'];assert ledger['context_total_viewed_bytes']==5897950;lp.write_text(json.dumps(ledger,indent=2)+'\n')
assert ledger['context_total_viewed_bytes']==5897950 and all(x['status']=='PRIVATELY_VIEWED'for x in ledger['entries'])
snap=B/'private-image-ledger-through-SEattack-native-and-SEdeath-first-joints-view100-frozen.json';assert not snap.exists();snap.write_text(json.dumps(ledger,indent=2)+'\n')
cape=B/'SEattack-v06-83eaff-independent-bounded-actual-cape-hem-narrow-source-PASS-v01.json'
cert=dict(schema='PR122-independent-actual-SE-attack-source-cycle-review-v1',status='PASS_EXACT_SE_ATTACK_SIX_ACTUAL_SOURCE_AND_ONE_SHOT_CYCLE',source_visual_status='PASS',key='transform:413',direction='SE',role='attack',source_contract=pin(cp),all_six_independent_binding=rows,C_fixed=2816,bodyunit_fixed=2.75,common_rig_root=c['common_rig_root_in_unpadded_frame'],storage_translation=[128,128],source_canvas=[1792,1792],loop=False,cycle_seconds=.42,phase_seconds=.07,resource_fps=6/.42,intended_contact_frame=3,visual_findings=[
 'The actual own-SE six-source sequence reads READY, WINDUP, COIL, extended down-right SE STRIKE3, FOLLOW and RECOVER. Dedicated torso lean, RIGHT near weapon-arm articulation, LEFT far counterarm and delayed blue-gold cloth create a clear one-shot directional attack.',
 'Actual native RIGHT grip, curved white-gold cuff, elbow and LEFT upper/forearm joins were inspected across all six. Fingers and hands remain complete and connected, the original double-ended staff follows the same transformed grip rigidly, and neither weapon end is clipped.',
 'The narrow actual cape finish retains the blue folds, continuous gold motif and curved original visible hem without a strict-mask seam or notch. Its separately frozen local certificate distinguishes 6452 real cape pixels from 131 original pole-over-background pixels outside the actual cloth boundary.',
 'Final material ownership preserves the original finger and cuff rim with the moving foregrip, the actual bright-blue behind-arm ribbon with head/CORE, and the complete measured native shaft with the rigid pole. The last three-pixel STRIKE fragment was traced to nine original shaft-edge AA texels incorrectly assigned to the hand; finalv05 moves those exact RGBA texels to the pole, retaining every true finger at source y438 and below.',
 'All36 saved editable node rasters reproduce the six final source PNGs exactly. The original stationary lowerboot and sole patches are unchanged, the common C2816/bodyunit2.75/root and storage128 remain fixed, and all six distinct sources have one strong body with no detached alpha100 component of three pixels or more.'
 ],visual_limitations=[
 'This approves this exact six-source appearance, natural visible attack progression and intended contact3. It does not add full actor approval, game test evidence or final production request binding.',
 'The forearm/grip and pole rigidity are checked in the authored projection. A unique hidden3D attack skeleton, force or absolute support anatomy is not recovered from these images.',
 'The first actual six-source board and one final native all-six joint crop were reviewed once. Finalv05 is bound by exact nine-original-texel owner transfer and independently rerasterized foregrip/pole nodes, so no duplicate whole-six or joint view was needed.',
 'The fixed original lowerboot/sole capture is exact and compatible with the existing once-neutral stationary model; no movement, running or per-pose foot fitting is approved.',
 'Any later transparent shipping extension must preserve every original1792 RGBA texel, physicalC/root and the same common storage translation for all poses. Source resizing and per-pose packing fits are outside this certificate.'
 ],accepted_narrow_cape_source=pin(cape),initial_exact36_native_binding=pin(priorbinding),final_exact_owner_binding=pin(outp),immutable_private_image_ledger=pin(snap),private_views_used=[96,97,98],current_context_private_image_bytes=5897950,images_forwarded=0,actor_approvals_added=0)
certp=B/'SEattack-v05-f7f9b8-independent-final-actual-source-one-shot-cycle-PASS-v01.json';assert not certp.exists();certp.write_text(json.dumps(cert,indent=2)+'\n')
files=[certp,outp,priorbinding,cape,B/'audit-SEattack-final-native-owner-nodes-boots-and-grip.py',Path(__file__)]
allow=B/'SEattack-independent-final-v05-prepack-proof-allowlist-v01.json';assert not allow.exists();allow.write_text(json.dumps(dict(status='IMMUTABLE_METADATA_ONLY_FINAL_SE_ATTACK_SOURCE_PROOFS',files=[pin(p)for p in files],source_contract=pin(cp),private_previews_or_live_ledgers_copied=False,source_PNG_modified=False,actor_approvals_added=0),indent=2)+'\n')
print(json.dumps(dict(final_source=pin(certp),final_owner=pin(outp),allowlist=pin(allow),context_private_image_bytes=5897950,actor_approvals_added=0)))
