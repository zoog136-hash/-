import hashlib,json,os
from pathlib import Path
import numpy as np
from PIL import Image
from scipy.ndimage import label

B=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020')
A=Path('/workspace/scratch/mythic413-N-attack-author-20261020-v01')
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
def save(p,d):
 p=Path(p);assert not p.exists(),str(p);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');return pin(p)
lp=B/'private-image-ledger-working-v01.json';l=json.loads(lp.read_text());v=l['entries'][-1]
assert v['view']==66 and v['status']=='RESERVED_BEFORE_PRIVATE_VIEW'
assert pin(v['path'])['sha256']==v['sha256'] and v['bytes']==20919
v['status']='PRIVATELY_VIEWED';v['actual_view_payload_bytes']=20919
l['new_viewed_bytes']=sum(x.get('actual_view_payload_bytes',0) for x in l['entries'] if x['status']=='PRIVATELY_VIEWED')
l['context_total_viewed_bytes']=l['inherited_context_private_image_bytes']+l['new_viewed_bytes']
assert l['context_total_viewed_bytes']==3468195
lp.write_text(json.dumps(l,ensure_ascii=False,indent=2)+'\n')
ledger=save(B/'private-image-ledger-through-Nattack-final-jointcaps-view66-frozen.json',l)
mp=A/'actual-six-rig-v07/N-attack-six-actual-native-rig-manifest-v07.json'
m=json.loads(mp.read_text());assert pin(mp)['sha256']=='a6203050cd25b15c88d839dbcbbabea7c37b137bcd99bc8e3f0a7a9a64ce5653'
old=json.loads((A/'actual-six-rig-v06/N-attack-six-actual-native-rig-manifest-v06.json').read_text())
master=np.array(Image.open(m['actual_master']).convert('RGBA'))
assert m['physical_C_fixed']==1920 and m['common_rig_root']==[662.8125,917.6920531878804]
assert m['storage_translation']==[0,160] and m['storage_size']==[1254,1414]
rows=[];allowed={2:(588,621,606,640),4:(541,619,563,642)}
heelrects={'LEFT':(510,1080,550,1133),'RIGHT':(700,1150,741,1217)}
for phase,(s,o) in enumerate(zip(m['source_phase_order'],old['source_phase_order'])):
 p=pin(s['path']);assert p['sha256']==s['sha256'] and p['bytes']==s['bytes']
 a=np.array(Image.open(s['path']).convert('RGBA'));z=np.array(Image.open(o['path']).convert('RGBA'))
 assert a.shape==(1414,1254,4)
 assert s['common_root']==m['common_rig_root'] and s['physical_C']==1920 and s['storage_translation']==[0,160]
 nodes={k:v for k,v in s['actual_rig_nodes'].items() if not k.startswith('actual_LEFT_jointcap_') and k!='jointcap_layer_rule'}
 assert nodes==o['actual_rig_nodes']
 diff=np.any(a!=z,axis=2);n=int(diff.sum());assert n=={2:198,4:320}.get(phase,0)
 assert np.count_nonzero(diff&(z[:,:,3]==255))==0
 bbox=None
 if n:
  yy,xx=np.where(diff);bbox=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
  assert bbox==list(allowed[phase])
 labs,num=label(a[:,:,3]>100);areas=np.bincount(labs.ravel())[1:];strong=sorted([int(x) for x in areas if x>=200],reverse=True);assert len(strong)==1
 heel={}
 for side,(x0,y0,x1,y1) in heelrects.items():
  r=master[y0:y1,x0:x1];t=a[y0:y1,x0:x1];mask=r[:,:,3]>240
  changes=int(np.count_nonzero(np.any(t[mask]!=r[mask],axis=1)));assert changes==0
  yy,xx=np.where(t[:,:,3]>100);by=int(yy.max()+y0);assert by=={'LEFT':1127,'RIGHT':1211}[side]
  heel[side]={'rectangle':[x0,y0,x1,y1],'reference_alpha_gt240_pixels':int(mask.sum()),'actual_opaque_RGBA_changes':changes,'alpha100_bottom_y':by,'bottom_xrange':[int(xx[yy==yy.max()].min()+x0),int(xx[yy==yy.max()].max()+x0)]}
 rows.append({'phase':phase,'name':s['name'],'source':p,'rgba_sha256':hashlib.sha256(a.tobytes()).hexdigest(),'v06_changed_RGBA_pixels':n,'v06_change_bbox':bbox,'v06_original_opaque255_changes':0,'alpha100_4connected_components_ge200':strong,'independent_actual_fixed_heel_material':heel})
assert len({r['rgba_sha256'] for r in rows})==6
assert rows[3]['source']['sha256']=='ac4cfa58ee960842ac697f63b1419e8657a7c5ca91b3a06f622819badb4e27aa'
out={'schema':'PR122-independent-actual-attack-six-source-cycle-prepacking-v1','status':'PASS_ACTUAL_N_ATTACK_SIX_SOURCE_AND_ONE_SHOT_CYCLE_PREPACKING','source_visual_status':'PASS','key':'transform:413','direction':'N','role':'attack','source_contract':pin(mp),'all_six_independent_binding':rows,'C_fixed':1920,'common_rig_root':m['common_rig_root'],'storage_translation':[0,160],'source_canvas':[1254,1414],'one_shot':True,'impact_frame':3,'visual_findings':['Six dedicated READY, WINDUP, COIL, STRIKE, FOLLOW and RECOVER phases show real torso weight shift, distinct joint articulation, the RIGHT staff swing and costume/ribbon follow-through.','Actual STRIKE3 remains the independently reviewed ac4cfa source. The five other poses preserve the same rear-N identity, bun/ribbon, blue/gold costume, white skirt and complete high-heeled boots.','The old LEFT sleeve/finger shell and old staff alpha thread are removed; original-material blue/gold overlap caps now join the actual moving LEFT cuff naturally in COIL2 and FOLLOW4. Existing opaque joint/hand pixels are preserved.','The complete anatomical RIGHT-held double-ended staff stays attached to its grip through the attack. Both observed heel cores and actual support tips remain stationary across all six poses.','RECOVER returns close to the dedicated READY guard as a one-shot attack; this is not a relabeled walking sequence or a whole-picture translation.'],'visual_limitations':['This approves the actual six source images and visible one-shot attack cycle. Exact final atlas/request binding and Godot resource, Player and action/impact checks remain pending.','Fixed opaque heel material verifies visible stationary support; hidden anatomical depth and a unique original 3D skeleton are not reconstructed.','The source impact is phase3. Runtime phase durations and combat contact scheduling must be verified on the actual integrated clip; no production approval follows from this source gate alone.','Only this new N ATTACK source is approved here; detailed actor approvals remain unchanged.'],'static_source3_certificate':pin(B/'Nattack-STRIKE3-ac4cfa-independent-static-source-PASS-v01.json'),'author_actual_joint_cap_proof':pin(A/'actual-six-rig-v07/N-attack-two-actual-native-LEFT-joint-cap-proof-v07.json'),'private_ledger_snapshot':ledger,'images_forwarded':0,'actor_approvals_added':0}
p=save(B/'Nattack-v07-a62030-independent-actual-source-cycle-PASS-v01.json',out)
print(json.dumps({'certificate':p,'private_context_bytes':l['context_total_viewed_bytes'],'source_poses':6,'actor_approvals_added':0}))
