from pathlib import Path
import hashlib, json, math
import numpy as np
from PIL import Image

OUT = Path(__file__).parent
CONTRACT = Path('/workspace/scratch/mythic413-NW-idle-author-20261020-v01/actual-NW-IDLE6-native-thorax-v02/NW-IDLE-six-actual-native-source-common-root-and-loop-contract-v02.json')
EXPECTED = '4d08f9c6353405137dfc17755a36c7121bc3a65a436c46ad652242d1ae2c4bf8'
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
assert sha(CONTRACT) == EXPECTED
d = json.loads(CONTRACT.read_text())
assert (d['actor_id'],d['direction'],d['action'],d['loop'],d['loop_seconds']) == (413,'NW','idle',True,1.2)
assert d['physical_canvas_fixed']==2048 and d['body_unit_fixed']==2
assert d['common_rig_root_in_unpadded_frame']==[641,1058.3] and d['storage_translation']==[0,0]
def rgba(p):
    im=Image.open(p).convert('RGBA'); canvas=Image.new('RGBA',(1536,1536));canvas.paste(im,(0,0));return np.asarray(canvas)
assert sha(d['base_native_source']['path'])==d['base_native_source']['sha256']
base=rgba(d['base_native_source']['path'])
lp=Path('/workspace/scratch/mythic413-NW-hit-author-20261020-v01/actual-braced-stance-v03/NW-HIT-articulated-braced-legs-and-complete-shoes.png')
sp=Path('/workspace/scratch/mythic413-NW-attack-author-20261020-v01/actual-NW-ATTACK6-native-rig-v03/actual-original-NW-complete-rigid-RIGHT-staff-material.png')
legs=rgba(lp);staff=rgba(sp); yy=np.arange(1536)[:,None]
lm=(legs[:,:,3]>16)&(yy>=730); sm=staff[:,:,3]>100
assert int(lm.sum())==32843 and int(sm.sum())==23241
frames=[]; arrays=[]; endpoint_error=0.; periodic_node_error=0.
def volume(x,y):
    return math.sin(math.pi*(x-510)/230)**2*math.sin(math.pi*(y-425)/180)**2
coefficient=((690-630)*volume(690,510)-(594-630)*volume(594,510))/70
for i,f in enumerate(d['frames']):
    assert f['phase']==i and sha(f['path'])==f['sha256'] and Path(f['path']).stat().st_size==f['bytes']
    with Image.open(f['path']) as im: assert im.size==(1536,1536)
    a=rgba(f['path']); arrays.append(a); diff=np.any(a!=base,axis=2)
    assert not np.any(a[[0,-1],:,3]) and not np.any(a[:,[0,-1],3])
    assert not np.any(diff&lm) and not np.any(diff&sm)
    for name in ['LEFT_upper','LEFT_forearm']:
        b=f[name];src=np.asarray(b['source_joint_pair']);target=np.asarray(b['target_joint_pair'])
        projected=src@np.asarray(b['matrix']).T+np.asarray(b['offset'])
        endpoint_error=max(endpoint_error,float(np.max(np.abs(projected-target))))
    th=2*math.pi*i/6
    p=f['pose_nodes']; expected=[2.5*(1-math.cos(th)),.6*math.sin(th-math.pi/3),2.5*math.sin(th-math.pi/3),-1.2*math.cos(th)]
    observed=[p['thorax_amplitude'],p['neck_angle_deg'],*p['cloth_delta']]
    periodic_node_error=max(periodic_node_error,max(abs(x-y) for x,y in zip(expected,observed)))
    frames.append({'phase':i,'path':f['path'],'sha256':f['sha256'],'bytes':f['bytes'],
       'fixed_leg_mask_RGBA_changes':int((diff&lm).sum()),'fixed_complete_staff_mask_RGBA_changes':int((diff&sm).sum()),
       'intrinsic_rib_span_native':96+coefficient*p['thorax_amplitude'],
       'actual_corset_pixel_changes_vs_phase0':int(np.any(a[480:550,590:700]!=arrays[0][480:550,590:700],axis=2).sum()),
       'alpha_canvas_edge_pixels':0})
assert len(frames)==6 and len({f['sha256'] for f in frames})==6
assert endpoint_error<1e-10 and periodic_node_error<1e-10
span_change=max(f['intrinsic_rib_span_native'] for f in frames)-min(f['intrinsic_rib_span_native'] for f in frames)
assert 3.8<span_change<3.83 and frames[3]['actual_corset_pixel_changes_vs_phase0']>100
edges=[{'from':i,'to':(i+1)%6,'actual_changed_RGBA_pixels':int(np.any(arrays[i]!=arrays[(i+1)%6],axis=2).sum())} for i in range(6)]
assert all(e['actual_changed_RGBA_pixels']>0 for e in edges)
result={'status':'INDEPENDENT_READ_ONLY_MATERIAL_NODE_AND_LOOP_NUMERIC_PASS','contract':str(CONTRACT),'contract_sha256':EXPECTED,
 'actor_id':413,'direction':'NW','role':'idle','physical_canvas':2048,'unit':2,'root':[641,1058.3],'storage':[0,0],
 'six_unique_exact_sources':True,'fixed_leg_mask_pixels':int(lm.sum()),'fixed_staff_mask_pixels':int(sm.sum()),
 'mask_inputs':[{'path':str(p),'sha256':sha(p)} for p in [lp,sp]],
 'frames':frames,'adjacent_edges_including_5_to_0':edges,
 'actual_forearm_upperarm_endpoint_max_error_native':endpoint_error,'analytic_periodic_body_node_max_error':periodic_node_error,
 'intrinsic_rib_span_change_native':span_change,'requested_equal_weight_loop_seconds':1.2,'required_resource_fps':5.0,
 'loop_evaluation':'Six equally spaced samples of periodic body/head/cloth inputs; no extra duplicated endpoint. Visible full6 and5-to-0 reviewed separately.',
 'root_field_displacement_native':[0,0],'root_field_reason':'641,1058.3 outside thorax/head/coat support; same authored source root, no per-pose fit.',
 'limits':['The semantic leg mask uses alpha>16 below y730 and whole-staff mask alpha>100; visual full gear review is separate.','Numeric checks do not assert game binding or actor approval.'],
 'repository_changes':0,'game_validation':False,'actor_approval_added':0,'image_views_added':0}
p=OUT/'NW-IDLE-v02-independent-exact-material-nodes-and-loop-numeric-PASS-v01.json'
assert not p.exists();p.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'proof':str(p),'sha256':sha(p),'leg_and_staff_RGBA_changes':0,'ribspan_change':span_change,'endpoint_error':endpoint_error,'loop_fps':5.0}))
