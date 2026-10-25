from pathlib import Path
import json,hashlib,math,sys
import numpy as np
from PIL import Image
from scipy.ndimage import label
B=Path(__file__).parent;A=Path('/workspace/scratch/mythic413-E-attack-author-20261020-v01')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def check(s):
 p=Path(s['path']);assert pin(p)['sha256']==s['sha256'];return p
def rgba(s):return np.array(Image.open(check(s)).convert('RGBA'))
assert len(sys.argv)==3
cp=Path(sys.argv[1]);assert pin(cp)['sha256']==sys.argv[2];c=json.loads(cp.read_text());material=json.loads(check(c['shared_materials']).read_text());reg=json.loads(check(c['shared_once_registration_exact_JSON']).read_text());original=rgba(c['source'])
assert c['C']==2816 and c['bodyunit']==2.75 and c['common_rig_root_in_unpadded_frame']==reg['common_rig_root_in_unpadded_frame'] and c['storage_translation']==[128,128] and c['native_canvas']==[1792,1792]
assert not c['whole_actor_mirrored'] and not c['source_or_fixed_boot_resampling_or_perpose_fit'] and c['one_shot'] and c['role_seconds_preserved']==.42 and c['fps']==6/.42 and c['intended_contact_frame']==3
priorpath=A/'actual-E-ATTACK6-native-articulated-rig-v03/E-ATTACK6-actual-native-articulated-six-rig-and-local-cape-contract-v03.json';prior=json.loads(priorpath.read_text());oldmaterial=json.loads(check(prior['shared_materials']).read_text())
# Independently check original source protection for the cape-only derivative.
cape=c['actual_local_cape_retouch'];mask=np.array(Image.open(check(cape['expanded_local_actual_cape_mask'])))>0;plate=rgba(cape['source_masked_only_plate']);assert mask.shape==original.shape[:2] and int(mask.sum())==23295
assert np.array_equal(plate[~mask],original[~mask])
# Alpha of original visible cloth is fixed. The old foreground pole-occluded
# 5113-pixel region receives the newly painted actual cape, including alpha.
handoff=json.loads(check(cape['service_handoff']).read_text());localocc=np.array(Image.open(check(handoff['replacement_mask_source'])))>0;occ=np.zeros(mask.shape,bool);occ[770:1020,260:510]=localocc;assert int(occ.sum())==5113 and not np.any(occ&~mask);assert np.array_equal(plate[:,:,3][~occ],original[:,:,3][~occ])
capeMaterial=json.loads(check(cape['prior_strict5113_candidate']).read_text());oldcore=rgba(capeMaterial['body_inputs']['attack-final-CORE-actual-local-cape-retouch']['body']);newcore=rgba(oldmaterial['body_inputs']['attack-final-CORE-actual-local-cape-retouch']['body']);assert np.array_equal(oldcore[~mask],newcore[~mask])
assert material['body_inputs']==oldmaterial['body_inputs'] and material['actual_local_cape_retouch']==oldmaterial['actual_local_cape_retouch']
# Source ownership: pale highlights and dark shaft edge are original metal,
# moved intact from foregrip input into the complete rigid pole input.
ownerpath=A/'actual-own-E-ATTACK-native-complete-pole-shaft-ownership-v07/E-original-visible-shaft-actual-RGBA-owner-transfer-proof-v07.json';op=json.loads(ownerpath.read_text());mp=check(op['transfer']['transfer_mask']);m=np.array(Image.open(mp))>0
oldRF=rgba(oldmaterial['parts']['RIGHT-near-complete-forearm-grip-hand']);newRF=rgba(material['parts']['RIGHT-near-complete-forearm-grip-hand']);oldPole=rgba(oldmaterial['parts']['complete-rigid-RIGHT-near-staff']);newPole=rgba(material['parts']['complete-rigid-RIGHT-near-staff'])
assert np.array_equal(oldRF[~m],newRF[~m]) and np.array_equal(oldPole[~m],newPole[~m]);assert not np.any(newRF[m]);assert np.array_equal(newPole[m],original[m]) and np.array_equal(oldRF[m],original[m]);x0,y0,x1,y1=op['transfer']['native_actual_fist_protected_roi'];assert np.array_equal(oldRF[y0:y1,x0:x1],newRF[y0:y1,x0:x1])
for key,s in oldmaterial['parts'].items():
 if key not in ['RIGHT-near-complete-forearm-grip-hand','complete-rigid-RIGHT-near-staff']:assert s['sha256']==material['parts'][key]['sha256']
floor=json.loads(Path('/workspace/scratch/mythic413-E-hit-author-20261020-v01/E-original-neutral-once-true-sole-and-HIT-six-material-floor-binding-v01.json').read_text());footmasks=[np.array(Image.open(check(z['exact_source_alpha_support'])))>0 for z in floor['source_material_capture_models']]
rows=[];rgbs=[]
for i,(f,old) in enumerate(zip(c['frames'],prior['frames'])):
 assert f['phase']==i and f['actual_rig_nodes_unpadded_native']==old['actual_rig_nodes_unpadded_native'];assert f['common_rig_root_in_unpadded_frame']==c['common_rig_root_in_unpadded_frame'] and f['storage_translation']==[128,128] and f['physical_C']==2816
 a=rgba({'path':f['path'],'sha256':f['sha256']});out=Image.new('RGBA',(1792,1792));nodechanges=[]
 for j,(z,o) in enumerate(zip(f['actual_composition_nodes'],old['actual_composition_nodes'])):
  v=rgba(z);oldv=rgba(o);out.alpha_composite(Image.fromarray(v));diff=int(np.count_nonzero(np.any(v!=oldv,2)));assert j in [4,5] or diff==0;nodechanges.append(dict(node=j,prior_RGBA_changed_pixels=diff,only_declared_metal_owner_nodes_changed=j in [4,5]))
 assert np.array_equal(a,np.array(out));rgbs.append(hashlib.sha256(a.tobytes()).hexdigest());native=a[128:1382,128:1382];feet=[]
 for fm in footmasks:
  assert np.array_equal(native[fm],original[fm]);feet.append(dict(original_stationary_lowerboot_and_sole_RGBA_changes=0,actual_original_painted_texels=int(fm.sum())))
 # The forearm affine preserves transverse width and maps its two actual
 # source control points. Its original grip is transformed by that SAME map.
 ctl=f['actual_rig_nodes_unpadded_native'];a0=np.array([550.,471.]);b0=np.array([428.,505.]);a1=np.array(ctl['re']);b1=np.array(ctl['rw']);u=(b0-a0)/np.linalg.norm(b0-a0);v=(b1-a1)/np.linalg.norm(b1-a1);FM=np.column_stack([v*np.linalg.norm(b1-a1)/np.linalg.norm(b0-a0),[-v[1],v[0]]])@np.column_stack([u,[-u[1],u[0]]]).T;FO=a1-FM@a0;G=np.array([386.,506.]);grip=FM@G+FO
 assert np.allclose(grip,f['RIGHT_exact_same_forearm_affine_grip_target'],atol=1e-10,rtol=0);SM=np.array(f['RIGHT_rigid_staff_matrix']);assert np.allclose(SM.T@SM,np.eye(2),atol=1e-12,rtol=0) and abs(np.linalg.det(SM)-1)<1e-12;assert np.allclose(SM@np.array([386.,8.])+grip-SM@G,f['native_original_full_staff_top_tip_target'],atol=1e-10,rtol=0)
 labs,n=label(a[:,:,3]>100);counts=np.bincount(labs.ravel());assert np.count_nonzero(counts[1:]>=200)==1;small=[]
 for k in range(1,n+1):
  if 3<=counts[k]<200:
   yy,xx=np.where(labs==k);small.append(dict(area=int(counts[k]),stored_bbox=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]))
 assert not np.any(a[[0,-1],:,3]>16) and not np.any(a[:,[0,-1],3]>16)
 rows.append(dict(phase=i,source=pin(f['path']),RGBA_sha256=rgbs[-1],actual6node_recomposition_mismatch=0,prior_v03_node_changes=nodechanges,original_stationary_sole_lowerboot_material=feet,full_rigid_pole_rotation_orthogonality_residual=float(abs(SM.T@SM-np.eye(2)).max()),same_forearm_affine_grip_target=grip.tolist(),strong_bodies=1,small_alpha100_components_ge3=small,storage_edge_contact=False))
assert len(rows)==6 and len(set(rgbs))==6
result=dict(status='PASS_EXACT_CURRENT_SOURCE_NODE_CAPE_BOOT_AND_GRIP_BINDING',source_contract=pin(cp),prior_actual_native_source=pin(priorpath),source_original=c['source'],material=c['shared_materials'],once_body=c['shared_once_registration_exact_JSON'],actual_cape_source_and_CORE_outside_allowed_mask_RGBA_changes=0,actual_cape_mask_pixels=23295,original_fist_RGBA_changes=0,shaft_original_RGBA_transfer=pin(ownerpath),actual_owner_transfer_mask=pin(mp),original_metal_source_pixels=int(m.sum()),current_six_checks=rows,C=2816,bodyunit=2.75,root=c['common_rig_root_in_unpadded_frame'],storage_translation=[128,128],cycle_seconds=.42,contact_frame=3,limitations=['This is exact pixel/node, source ownership, fixed lowerboot/sole patch and 2D rigid pole/grip binding. It is not a recovered unique3D attack skeleton or a full actor/game approval.','The accepted bounded cape repaint is a local native material derivative. Actor/root/bodyunit/original source are unchanged; only the actual cape mask uses the original one service retouch.','Small original cuff edge AA is recorded by the unchanged alpha100/4-connected criterion. No size or topology threshold is weakened. Actual visual joint/cycle judgement uses the separately frozen private ledger.'],images_viewed=0,repository_changes=0,game_tests_run=0,actor_approvals_added=0)
target=B/'Eattack-v04-independent-exact-current-six-native-node-cape-sole-grip-binding-v01.json';assert not target.exists();target.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(proof=pin(target),components=[r['small_alpha100_components_ge3'] for r in rows],actor_approvals_added=0)))
