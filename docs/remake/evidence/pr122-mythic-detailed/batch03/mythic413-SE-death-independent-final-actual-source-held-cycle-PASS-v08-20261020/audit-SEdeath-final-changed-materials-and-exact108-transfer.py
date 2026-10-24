"""Incremental numeric witness; argv: contract SHA physical-model SHA.
No source or image writes. Reuse independently checked unchanged surfaces.
"""
from pathlib import Path
import ast,json,hashlib,sys,math
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates,label
B=Path(__file__).parent
assert len(sys.argv)==5
CP=Path(sys.argv[1]);PP=Path(sys.argv[3])
assert hashlib.sha256(CP.read_bytes()).hexdigest()==sys.argv[2] and hashlib.sha256(PP.read_bytes()).hexdigest()==sys.argv[4]
C=json.loads(CP.read_text());D=json.loads(PP.read_text());ROOT=np.array(C['common_unpadded_root']);PAD=np.array(C['storage_translation']);P=np.array(C['projection_matrix']);seen={};cache={}
# Reuse only our independently authored mathematical functions, not the
# producer renderer or the previous audit's top-level pipeline.
basecode=B/'audit-own-SEdeath-v05-exact108-finite-source-raster-floor.py'
for node in ast.parse(basecode.read_text()).body:
 if isinstance(node,ast.FunctionDef):exec(compile(ast.Module(body=[node],type_ignores=[]),str(basecode),'exec'),globals())
baseproof=B/'SEdeath-v05-independent-exact108-native-source-and-raster-floor-companion-v01.json';base=json.loads(baseproof.read_text());oldC=json.loads(check(base['source_contract']).read_text());oldD=json.loads(check(base['physical_model']).read_text())
# Retain our independently reconstructed selected triangle depth for each new
# proximal surface. The final contract need not serialize this implementation
# detail in the same place as its older producer version.
original_mesh_bound=mesh_bound
last_selected=None
independent_proximal_depth={}
def mesh_bound(*args):
 global last_selected
 result=original_mesh_bound(*args);last_selected=result[2];return result
for key in ['fixed_C','bodyunit','common_unpadded_root','storage_canvas','storage_translation','fixed_femur_tibia','projection_matrix','source_capture_body_U','source_capture_body_V','runtime_death_seconds','resource_role_seconds','phase_seconds','loop','held_dead_terminal']:assert C[key]==oldC[key]
for key in ['renderer','binder','source_native_manifest','canonical_original_sole_model','once_registration','defining_joint_UV','defining_rootcloth_UV']:check(D[key])
assert len(D['records'])==len(D['parts'])==108
rows=[];changed=[];unchanged=[]
for i,(r,old) in enumerate(zip(D['records'],oldD['records'])):
 assert r['phase']==old['phase'] and r['name']==old['name'] and r['kind']==old['kind'] and r['raster']==D['parts'][i]
 same=r['source']['sha256']==old['source']['sha256'] and r['raster']['sha256']==old['raster']['sha256']
 if same:
  for key in ['source_anchor','world_anchor','source_world_U','source_world_V','guard_native','operator','source_texel_quad_plus_guard_min_Z','raster_texel_quad_plus_guard_min_Z']:
   if key in r and key!='operator':assert r[key]==old[key]
  if 'operator' in r:
   lhs={k:v for k,v in r['operator'].items() if k!='selected_actual_raster_raydepth'};rhs={k:v for k,v in old['operator'].items() if k!='selected_actual_raster_raydepth'};assert lhs==rhs
  check(r['source']);check(r['raster']);q=dict(base['records'][i]);q['independent_prior_surface_transferred_unchanged']=True;unchanged.append(dict(phase=r['phase'],name=r['name'],source_SHA=r['source']['sha256'],raster_SHA=r['raster']['sha256']))
 else:
  assert i%18 in [0,5,10,14],(i,r['name'])
  s=rgba(r['source'],True);a=rgba(r['raster'])
  if r['kind'].startswith('EXACT_PINNED'):sm,rm,detail=affine(r,s,a)
  elif r['kind']=='ORIGINAL_COMPLETE_DIRECTIONAL_NATIVE_JOINT_CONTINUOUS_UV':
   sm,rm,detail=joint(r,s,a)
   if i%18 in [0,5]:independent_proximal_depth[(r['phase'],'R' if i%18==0 else 'L')]=last_selected
  else:raise AssertionError(r['kind'])
  close(sm,r['source_texel_quad_plus_guard_min_Z']);close(rm,r['raster_texel_quad_plus_guard_min_Z']);assert min(sm,rm)>0;q=dict(phase=r['phase'],name=r['name'],kind=r['kind'],source_min_Z=sm,actual_raster_min_Z=rm,detail=detail,independent_prior_surface_transferred_unchanged=False);changed.append(dict(phase=r['phase'],name=r['name'],source=r['source'],raster=r['raster']))
 rows.append(q)
 assert r['above_floor']
frames=[]
for ph,(f,of) in enumerate(zip(C['frames'],oldC['frames'])):
 for k in ['state','pelvis_world','pelvis_SO3','torso_waist','torso_SO3','head_neck','head_SO3','arms','cloth_actual_surface','clock_seconds']:assert f[k]==of[k]
 for side in ['R','L']:
  for k,v in f['bones'][side].items():
   if k!='actual_proximal_thigh_root':assert v==of['bones'][side][k]
 actual=rgba(f);layers=[Image.open(check(z)).convert('RGBA') for z in D['parts'][ph*18:(ph+1)*18]];out=Image.new('RGBA',(2304,2304));out.alpha_composite(layers[17])
 for side,start in [('R',0),('L',5)]:
  aa=np.array(layers[start]);bb=np.array(layers[start+1]);ys,xs=np.where((aa[:,:,3]>0)|(bb[:,:,3]>0));lo=np.array([xs.min(),ys.min()]);hi=np.array([xs.max(),ys.max()])+1;gy,gx=np.mgrid[lo[1]:hi[1],lo[0]:hi[0]];bone=f['bones'][side];K=np.array(bone['knee']);MC=np.array(bone['calf_source_world_UV']);grad=(MC[1]+MC[2])@np.linalg.inv(P@MC);calfdepth=K[1]+K[2]+(np.stack([gx,gy],-1)-ROOT-PAD-P@K)@grad
  if (ph,side) in independent_proximal_depth:z=independent_proximal_depth[(ph,side)]
  else:z=np.load(check(of['bones'][side]['actual_proximal_thigh_root']['selected_actual_raster_raydepth']),allow_pickle=False)
  dl=z['lo'];dh,dw=z['depth'].shape;left=np.maximum(lo,dl);right=np.minimum(hi,dl+[dw,dh]);td=np.full(calfdepth.shape,-np.inf);td[left[1]-lo[1]:right[1]-lo[1],left[0]-lo[0]:right[0]-lo[0]]=z['depth'][left[1]-dl[1]:right[1]-dl[1],left[0]-dl[0]:right[0]-dl[0]]
  both=(aa[lo[1]:hi[1],lo[0]:hi[0],3]>0)&(bb[lo[1]:hi[1],lo[0]:hi[0],3]>0);front=both&(td>calfdepth+1e-8);temp=Image.new('RGBA',(2304,2304));temp.alpha_composite(layers[start]);temp.alpha_composite(layers[start+1]);rev=Image.new('RGBA',(2304,2304));rev.alpha_composite(layers[start+1]);rev.alpha_composite(layers[start]);ta=np.array(temp);ra=np.array(rev);ta[lo[1]:hi[1],lo[0]:hi[0]][front]=ra[lo[1]:hi[1],lo[0]:hi[0]][front];temp=Image.fromarray(ta)
  for j in [2,3,4]:temp.alpha_composite(layers[start+j])
  out.alpha_composite(temp)
 for group in [[10],[11],[12],[15,16],[13,14]]:
  temp=Image.new('RGBA',(2304,2304))
  for j in group:temp.alpha_composite(layers[j])
  out.alpha_composite(temp)
 assert np.array_equal(actual,np.array(out));lab,n=label(actual[:,:,3]>100);counts=np.bincount(lab.ravel())[1:];assert np.count_nonzero(counts>=200)==1 and not actual[[0,-1],:,3].any() and not actual[:,[0,-1],3].any();frames.append(dict(phase=ph,source=pin(f['path']),RGBA_recomposition_mismatch=0,strong_bodies=1,storage_edge_contact=False))
assert len(unchanged)>=84 and len(changed)<=24
target=B/'SEdeath-final-independent-changed-material-exact108-floor-binding-v01.json';assert not target.exists();target.write_text(json.dumps(dict(status='PASS_EXACT_FINAL_CHANGED_MATERIAL_FINITE_MODEL_AND_108_RGBA_BINDING',source_contract=pin(CP),final_physical_model=pin(PP),prior_independent108=pin(baseproof),independent_mathematical_functions=pin(basecode),unchanged_prior_surfaces=unchanged,new_independently_recomputed_surfaces=changed,records=rows,actual_final_six=frames,minimum_guarded_Z=min(min(x['source_min_Z'],x['actual_raster_min_Z'])for x in rows),same_fixed318725_bones_SO3_RIGHTrigidpole_Gram_bodyunit_root_and_terminal_model=True,limits=['One explicit compatible material/depth/support witness, not unique recovered anatomy or actual source/cycle/game approval.','Only changed proximal skin/pelvis and latest original shaft-edge material are independently recomputed; all other source/raster geometry and RGBA are cryptographically identical to the prior independently checked surfaces.','Every final108-part depth-ordered composition is compared against the final actual sixRGBA sources. Whole-source visual QA is retained from first6 and any final small skin review, with no repeated whole6 view.'],images_viewed=0,source_images_written=0,repo_writes=0,tests_run=0,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(proof=pin(target),changed=len(changed),unchanged=len(unchanged))))
