from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
from scipy.ndimage import label
B=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020');A=Path('/workspace/scratch/mythic413-N-idle-author-20261020-v01');D=A/'actual-N-IDLE-six-native-v03';cp=D/'actual-N-IDLE-six-source-contract-v03.json';fp=A/'N-IDLE-v03-whole-actual-native-source-raster-floor-and-loop-binding-v02.json';c=json.loads(cp.read_text());f=json.loads(fp.read_text());P=128.;CAM=.45;RY=917.6920531878804
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def save(n,d):
 p=B/n;assert not p.exists();p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');return pin(p)
def read(p):return Image.open(p).convert('RGBA')
def rawsource(im):return im.crop((128,128,1382,1382))if im.size==(1536,1536)else im
def project(w):return np.array([w[0],RY+CAM*w[1]-w[2]])
def render(src,q):
 src=rawsource(src);U=np.array(q['U']);V=np.array(q['V']);wa=np.array(q['world_anchor']);sa=np.array(q['source_anchor']);M=np.array([[U[0],V[0]],[CAM*U[1]-U[2],CAM*V[1]-V[2]]]);iv=np.linalg.inv(M);off=sa+P-iv@(project(wa)+P);im=Image.new('RGBA',(1536,1536));im.paste(src,(128,128));return im.transform((1536,1536),Image.Transform.AFFINE,(iv[0,0],iv[0,1],off[0],iv[1,0],iv[1,1],off[1]),resample=Image.Resampling.BICUBIC)
def bounds(q,ras,src=None):
 U=np.array(q['U']);V=np.array(q['V']);wa=np.array(q['world_anchor']);sa=np.array(q['source_anchor']);guard=q['guard'];M=np.array([[U[0],V[0]],[CAM*U[1]-U[2],CAM*V[1]-V[2]]]);grad=np.array([U[2],V[2]])@np.linalg.inv(M);a=np.array(ras);yy,xx=np.where(a[:,:,3]>0);z=wa[2]+grad@np.stack((xx-P-project(wa)[0],yy-P-project(wa)[1]));mn=float(z.min()-.5*np.abs(grad).sum()-guard);out=dict(actual_raster_alpha_positive_pixels=len(xx),actual_raster_quad_guard_minZ=mn)
 if src is not None:
  a=np.array(rawsource(src));yy,xx=np.where(a[:,:,3]>0);out['source_quad_guard_minZ']=float((wa[2]+U[2]*(xx-sa[0])+V[2]*(yy-sa[1])).min()-.5*(abs(U[2])+abs(V[2]))-guard)
 return out
assert pin(cp)['sha256']=='1d2ec97c3822332fc906645c8c2afc542486c21fe3caed933f496eb40f0dc20e'
assert pin(fp)['sha256']=='39cf86e4efa5c16f740dfa506cfd36732d8ce056bf188b6786a7fa9c82c02234'
assert c['fixed_C']==1920 and c['bodyunit']==1.875 and c['common_unpadded_root']==[662.8125,RY] and c['storage_translation']==[128,128] and c['storage_canvas']==[1536,1536]
assert c['cycle_seconds']==1.2 and c['phase_seconds']==.2 and c['resource_fps']==5 and c['loop'] and not c['profile_modified']
mp=c['input_manifest'];assert pin(mp['path'])['sha256']==mp['sha256'];images={}
for x in json.loads(Path(mp['path']).read_text())['files']:
 assert pin(x['path'])['sha256']==x['sha256'];images[Path(x['path']).name]=read(x['path'])
files={Path(x['path']).name:x for x in f['editable_actual_bound_raster_parts']};assert len(files)==39
for x in files.values():assert pin(x['path'])['sha256']==x['sha256']
def boundfile(n):return read(files[n]['path'])
static=[]
for q in f['static_parts']:
 part=q['part'];side=q.get('side')
 if side:
  if part=='complete-original-rounded-frontshoe':src=read(D/'native-original-complete-front-shoe-and-rounded-native-ankle.png');rs=boundfile(f'fixed-{side}-actual-complete-frontshoe-bound-raster.png')
  else:src=images[part];rs=boundfile(f'fixed-{side}-{Path(part).stem}-bound-raster.png')
 elif part=='RIGHT-full-grip-staff':src=images['native-RIGHT-complete-forearm-grip-full-restored-staff.png'];rs=boundfile('fixed-entire-RIGHT-grip-restored-shaft-both-staff-ends-bound-raster.png')
 else:src=images['native-RIGHT-upperarm.png'];rs=render(src,q)
 r=bounds(q,rs,src);assert r['actual_raster_quad_guard_minZ']>=-1e-9 and r['source_quad_guard_minZ']>=-1e-9
 assert abs(r['actual_raster_quad_guard_minZ']-q['raster_texel_quad_guard_min_Z'])<1e-8 and abs(r['source_quad_guard_minZ']-q['source_texel_quad_guard_min_Z'])<1e-8;static.append(dict(part=part,side=side,**r))
bones=[]
for side,q in c['exact_fixed_supported_leg_bones'].items():
 h,k,a=[np.array(q[z])for z in ['hip','knee','ankle']];err=max(abs(np.linalg.norm(h-k)-187.5),abs(np.linalg.norm(k-a)-187.5));assert err<1e-9;bones.append(dict(side=side,fixed_femur_tibia_max_error=err,structural_heel=q['heel'],hidden_toe=q['toe']))
legs=read(D/'fixed-supported-neutral-both-legs.png');R=read(D/'fixed-RIGHTarm-grip-complete-original-gold-turquoise-staff.png');assert hashlib.sha256(np.array(legs).tobytes()).hexdigest()==f['fixed_leg_RGBA_sha256'];assert hashlib.sha256(np.array(R).tobytes()).hexdigest()==f['fixed_RIGHT_grip_staff_RGBA_sha256'];assert pin(D/'fixed-RIGHTarm-grip-complete-original-gold-turquoise-staff.png')['sha256']==c['RIGHTarm_staff_fixed_raster_sha256']
basea=np.array(read(c['frames'][0]['path']));yy,xx=np.indices((1536,1536));lm=(np.array(legs)[:,:,3]>100)&(yy>=900);fullstaffmask=np.array(boundfile('fixed-entire-RIGHT-grip-restored-shaft-both-staff-ends-bound-raster.png'))[:,:,3]>100
mapping={'body-native-local-breath':'actual-local-breath-chest-bodice','head':'actual-independent-head-bun','ribbon':'actual-free-ribbon-lag','LEFT-coat':'actual-LEFT-coat-continuous-native-UV','RIGHT-coat':'actual-RIGHT-coat-continuous-native-UV'};rows=[];dynamic=[];bodyhip=[]
# Moving cloth and foreground body may legitimately occlude the fixed shaft.
# Require unchanged actual paint wherever that fixed node is visible in every frame.
occlusion=np.zeros((1536,1536),bool)
for i in range(6):
 for name in mapping.values():occlusion|=np.array(boundfile(f'phase{i}-{name}.png'))[:,:,3]>0
 occlusion|=np.array(read(D/f'N-idle-phase{i}-actual-LEFT-cuff-hand-articulated-finger-parts.png'))[:,:,3]>0
staffmask=fullstaffmask&~occlusion;assert int(staffmask.sum())>10000
for i,(s,qf) in enumerate(zip(c['frames'],f['phases'])):
 assert s['phase']==qf['phase']==i and pin(s['path'])['sha256']==s['sha256'];a=np.array(read(s['path']));out=Image.new('RGBA',(1536,1536));out.alpha_composite(legs);out.alpha_composite(R)
 for key in ['LEFT-coat','RIGHT-coat','body-native-local-breath','head','ribbon']:out.alpha_composite(boundfile(f'phase{i}-{mapping[key]}.png'))
 hand=read(D/f'N-idle-phase{i}-actual-LEFT-cuff-hand-articulated-finger-parts.png');out.alpha_composite(hand);result=np.array(out);result[result[:,:,3]==0,:3]=0;assert np.array_equal(result,a)
 for q in qf['parts']:
  part=q['part'];rs=boundfile(f'phase{i}-{mapping[part]}.png')if part in mapping else hand;r=bounds(q,rs)
  assert r['actual_raster_quad_guard_minZ']>0
  if part in mapping:assert abs(r['actual_raster_quad_guard_minZ']-q['raster_texel_quad_guard_min_Z'])<1e-8
  dynamic.append(dict(phase=i,part=part,conservative_combined_hand_bound=(part not in mapping),**r))
 body=np.array(boundfile(f'phase{i}-{mapping["body-native-local-breath"]}.png'));bodyhip.append(hashlib.sha256(body[710:].tobytes()).hexdigest())
 dl=int(np.count_nonzero(np.any(a[lm]!=basea[lm],axis=1)));ds=int(np.count_nonzero(np.any(a[staffmask]!=basea[staffmask],axis=1)));assert dl==ds==0
 labs,n=label(a[:,:,3]>100);areas=np.bincount(labs.ravel())[1:];strong=[int(x)for x in areas if x>=200];assert len(strong)==1
 rows.append(dict(phase=i,source=pin(s['path']),rgba_sha256=hashlib.sha256(a.tobytes()).hexdigest(),exact_RGBA_recomposition_changes=0,fixed_lowerleg_opaque_RGBA_changes=dl,common_visible_grip_staff_opaque_RGBA_changes=ds,common_visible_staff_pixels=int(staffmask.sum()),fixed_staff_pixels_with_actual_foreground_occlusion_changes=int(np.count_nonzero(np.any(a!=basea,axis=2)&fullstaffmask&occlusion)),strong_alpha100_4connected_components=strong,breath_amplitude=[s['actual_chest_transverse_amplitude'],s['actual_chest_lift_amplitude']],head_angle=s['head_node_angle'],hair_tip=s['hair_delayed_tip']))
assert len({r['rgba_sha256']for r in rows})==6 and len(set(bodyhip))==1
assert np.max(abs(np.array([x['inhalation']for x in c['frames']])-[0,.25,.75,1,.75,.25]))<1e-12
assert f['loop']['actual_finger_keyframe_sequence_proximal']==[0,2,5,7,4,1,0] and f['loop']['actual_finger_keyframe_sequence_distal']==[0,3,8,10,5,1.5,0]
numeric=save('Nidle-v03-independent-actual-raster-source-floor-fixed-material-loop-binding-v01.json',dict(status='PASS_ACTUAL_RECOMPOSITION_FIXED_MATERIAL_AND_DECLARED_SURFACE_FLOOR_LOOP_BINDING',source_contract=pin(cp),author_full_source_raster_model=pin(fp),all39_bound_part_SHA_verified=True,static_source_and_actual_raster_bounds=static,dynamic_actual_raster_bounds=dynamic,fixed_leg_bones=bones,all_six_exact_final_RGBA_recomposition=True,pinned_lower_bodice_raster_below710_same_all6=True,loop_seconds=1.2,phase_seconds=.2,phase6_equals0_analytic_controls_reviewed=True,phase5_to0_actual_source_reviewed=True,limits=['The10 static source/raster surfaces and all actual dynamic rendered paint are independently bounded with their explicit model planes. For LEFTarm the complete combined upper/forearm raster is conservatively checked under each respective chart.','The author full-source dynamic UV proof is retained; source warp/capture planes and guards are explicit constructive assumptions, not a unique hidden anatomy/sole-volume recovery.','All39 actual bound rasters are rehashed and exactly recomposed to the final six source PNGs; runtime/game binding remains pending.'],actor_approvals_added=0,images_viewed_for_numeric_binding=0))
lp=B/'private-image-ledger-working-v01.json';ledger=json.loads(lp.read_text());e=ledger['entries'][-1];assert e['view']==79 and e['status']=='RESERVED_BEFORE_PRIVATE_VIEW';e['status']='PRIVATELY_VIEWED';e['actual_view_payload_bytes']=e['bytes'];ledger['new_viewed_bytes']=sum(x.get('actual_view_payload_bytes',0)for x in ledger['entries']if x['status']=='PRIVATELY_VIEWED');ledger['context_total_viewed_bytes']=ledger['inherited_context_private_image_bytes']+ledger['new_viewed_bytes'];lp.write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+'\n');snap=save('private-image-ledger-through-Nidle-final-source-view79-frozen.json',ledger)
cert=save('Nidle-v03-1d2ec9-independent-actual-source-loop-PASS-v01.json',dict(schema='PR122-independent-actual-N-idle-six-source-loop-prepacking-v1',status='PASS_ACTUAL_N_IDLE_SIX_LOCAL_BREATH_RELAX_AND_CONTINUOUS_LOOP_PREPACKING',source_visual_status='PASS',key='transform:413',direction='N',role='idle',source_contract=pin(cp),all_six_independent_binding=rows,C_fixed=1920,bodyunit_fixed=1.875,common_rig_root=c['common_unpadded_root'],storage_translation=[128,128],source_canvas=[1536,1536],loop=True,cycle_seconds=1.2,phase_seconds=.2,resource_fps=5,visual_findings=['Six dedicated idle phases show subtle local rib/corset expansion and scapular lift into inhalation and exhalation, with a stable pelvis and planted complete boots. This is actual local material articulation rather than whole-picture bobbing or a color change.','The LEFT curved cuff, white/gold sleeve, complete fingerless hand and authored proximal/distal finger relaxation remain connected at native inspection; the complete rounded ankle/counter/stiletto joins are clean.','Independent neck/bun/ribbon and pinned-root coat lag accompany the breathing while the anatomicalRIGHT grip and full double-ended staff remain fixed and complete.','The actual5→0 transition returns smoothly toward the starting breath, hand and lag phase; analytic phase6 controls close to0 and finger sequences explicitly return to their starting state.','The six distinct sources exactly recompose from the39 hashed actual bound parts; lower leg/support and complete grip/staff material remain unchanged across all six.'],visual_limitations=['This approves actual source appearance, visible idle loop and the explicit source/raster surface binding. Final atlas/request binding and actual scoped Godot/Player loop checks remain pending.','Hidden anatomy and volumetric support are not uniquely reconstructed. The explicit capture planes and uncertainty guards remain stated authoring assumptions.','Breathing and finger movement are intentionally small at retained native density; C/root/bodyunit are constant across all six frames.','Only this new N IDLE source loop is approved here; detailed actor completion count is unchanged.'],finite_surface_and_material_binding=numeric,private_ledger_snapshot=snap,images_forwarded=0,actor_approvals_added=0))
print(json.dumps(dict(certificate=cert,numeric=numeric,private_context_bytes=ledger['context_total_viewed_bytes'],source_poses=6,actor_approvals_added=0)))
