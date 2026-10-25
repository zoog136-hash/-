from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image

O=Path(__file__).parent
C=Path('/workspace/scratch/mythic413-NE-hit-author-20261020-v01/actual-NE-HIT6-own-native-settled-guard-v04/NE-HIT6-exact-final-source-roster-v04.json')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert sha(C)=='1b6ddc5589d59f66a284e1484e9dca4d7e111608cf46c7e6155a02e806341306'
d=json.loads(C.read_text())
assert d['C']==2432 and d['bodyunit']==2.375 and d['storage_translation']==[128,128]
assert np.max(np.abs(np.asarray(d['common_rig_root_unpadded'])-[716.2291666666666,1054.2766007046484]))<1e-10
assert d['role_seconds']==.22 and abs(d['phase_seconds']*6-.22)<1e-12
assert not d['perpose_C_root_or_foot_fit'] and not d['method_pixels_reused_from_N']
oldr=d['prior_immutable_source_contract'];assert sha(oldr['path'])==oldr['sha256'];old=json.loads(Path(oldr['path']).read_text())
sr=d['source_identity'];assert sha(sr['path'])==sr['sha256']=='99ffa7da2332144f3d449e9e23881bbaa130ace3027e837518148b705d92c127'
src=np.asarray(Image.open(sr['path']).convert('RGBA'));h,w=src.shape[:2]
registration=d['stationary_brace_once_registration'];assert sha(registration['path'])==registration['sha256']
reg=json.loads(Path(registration['path']).read_text());lm=np.zeros((h,w),bool)
for f in reg['fixed_legs_source']:
    assert sha(f['path'])==f['sha256'];a=np.asarray(Image.open(f['path']).convert('RGBA'));assert a.shape==src.shape;lm|=a[:,:,3]>0
sm=np.broadcast_to(np.arange(w)[None,:]>=850,(h,w))
rows=[];arrays=[]
for i,f in enumerate(d['frames']):
    assert f['phase']==i and f['C']==2432 and f['bodyunit']==2.375 and f['storage_translation']==[128,128]
    s=f['source'];assert sha(s['path'])==s['sha256'] and Path(s['path']).stat().st_size==s['bytes']
    a=np.asarray(Image.open(s['path']).convert('RGBA'));assert a.shape==(1536,1536,4)
    assert not np.any(a[[0,-1],:,3]) and not np.any(a[:,[0,-1],3]);arrays.append(a)
    native=a[128:128+h,128:128+w];diff=np.any(native!=src,axis=2)
    assert int((diff&lm).sum())==0 and int((diff&sm).sum())==0
    if i<5: assert s==old['frames'][i]['source']
    mr=f['actual_LEFT_guard_mesh'];assert sha(mr['path'])==mr['sha256'];m=json.loads(Path(mr['path']).read_text())
    assert m['storage_translation']==[128,128]
    assert np.max(np.abs(np.asarray(m['target_knots_unpadded'])-f['LEFT_actual_guard_knots_unpadded']))<1e-10
    vertices=np.asarray([v['target']for v in m['mesh']]);assert np.isfinite(vertices).all() and m['triangles']>0
    rows.append({'phase':i,'role':f['role'],'source':s,'complete_boot_and_leg_RGBA_changes':0,'full_RIGHT_staff_region_RGBA_changes':0,'actual_guard_mesh':mr,'guard_mesh_vertices':len(vertices),'old_0_through4_unchanged':i<5})
assert len(rows)==6 and len({r['source']['sha256']for r in rows})==6
edges=[{'from':i,'to':i+1,'actual_RGBA_changed_pixels':int(np.any(arrays[i]!=arrays[i+1],axis=2).sum())}for i in range(5)]
assert all(e['actual_RGBA_changed_pixels']>0 for e in edges)
settle_changes=int(np.any(arrays[5]!=arrays[0],axis=2).sum());assert settle_changes>1000
P=O/'NE-HIT-v04-independent-six-source-exact-gear-and-genuine-settle-PASS-v01.json'
record={'status':'INDEPENDENT_EXACT_SOURCE_AND_GEAR_NUMERIC_PASS','source_roster':str(C),'source_roster_sha256':sha(C),'direction':'NE','role':'hit','C':2432,'unit':2.375,'root':d['common_rig_root_unpadded'],'storage':[128,128],'complete_actual_leg_mask_pixels':int(lm.sum()),'full_RIGHTstaff_native_region_pixels':int(sm.sum()),'rows':rows,'six_unique_exact_source_SHA256':True,'unchanged_0_through4':True,'adjacent_motion_edges':edges,'genuine_settled5_vs_initial0_changed_RGBA_pixels':settle_changes,'phase_seconds':.22/6,'role_seconds':.22,'separate_source_camera_or_3D_reconstruction_claim':False,'extra_image_views':0,'game_validation':False,'actor_approvals_added':0}
assert not P.exists();P.write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'proof':str(P),'sha256':sha(P),'six_unique':True,'preserved_gear_RGBA_changes':0,'settle_vs_initial_changed':settle_changes,'source0_through4_unchanged':True}))
