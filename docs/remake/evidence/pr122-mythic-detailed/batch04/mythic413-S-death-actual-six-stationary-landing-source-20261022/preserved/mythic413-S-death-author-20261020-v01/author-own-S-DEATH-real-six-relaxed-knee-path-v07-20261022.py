from pathlib import Path
import ast, copy, json, hashlib, numpy as np
from PIL import Image

B=Path(__file__).parent
D=B/'actual-own-S-DEATH-six-native-v07-S-only-20261022'
D.mkdir()
CACHEP=B/'actual-own-S-DEATH-six-native-v01/own-S-DEATH-six-actual-native-source-contract-v01.json'
cache=json.loads(CACHEP.read_text())
old={(r['phase'],r['name']):r for r in cache['records']}
RP=B/'author-own-S-DEATH-six-native-relaxed-knee-path-v07-20261022.py'
code=RP.read_text(); prefix,rest=code.split('rows=[]\n',1)
prefix=prefix.replace("D=B/'actual-own-S-DEATH-six-native-v07-S-only-20261022';D.mkdir()",'D=OUTPUT')

class NoWrites(ast.NodeTransformer):
 def visit_Expr(self,n):
  if isinstance(n.value,ast.Call) and isinstance(n.value.func,ast.Attribute) and n.value.func.attr=='save':return ast.copy_location(ast.Pass(),n)
  return self.generic_visit(n)

ns=dict(__file__=str(RP),OUTPUT=D)
t=NoWrites().visit(ast.parse(prefix));ast.fix_missing_locations(t);exec(compile(t,str(RP),'exec'),ns)
ns['states'][4]['cloth']=72
ns['states'][5]['cloth']=76
P=ns['Pr'];ROOT=ns['ROOT'];PAD=ns['PAD'];N=ns['N']
FP=Path('/workspace/scratch/mythic413-SE-death-author-20261020-v01/author-own-SE-DEATH-exact-original-skin-float-bicubic-parent-edge-v08.py')
f=next(n for n in ast.parse(FP.read_text()).body if isinstance(n,ast.FunctionDef) and n.name=='float_color_edge')
fg=dict(np=np,Image=Image,P=P,ROOT=ROOT,PAD=PAD,N=N)
exec(compile(ast.Module(body=[f],type_ignores=[]),str(FP),'exec'),fg)
names={id(im):name for name,im in ns['source'].items()}
pins=dict(ns['mat']['materials'])

def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)

for side,q in ns['legs'].items():
 for part in ['thigh','calf','kneestrip','anklestrip','foot']:
  name=side+'-'+part;names[id(q[part])]=name;nativep=D/(name+'-actual-original-native-source-v03.png');q[part].save(nativep);pins[name]=pin(nativep)

records=[];reuse=[];new=[];serial={}
baseplane=ns['plane'];basejoint=ns['JF']['native_joint_strip'];basecloth=ns['CF']['root_bound_cloth']
def save(im,name):
 ph=ns['ph'];serial[ph]=serial.get(ph,0)+1;p=D/f'phase{ph}-{serial[ph]:02}-{name}-actual-native-v01.png';im.save(p);return pin(p)
def identical_source(im,r):
 return np.array_equal(np.array(im),np.array(Image.open(r['source']['path']).convert('RGBA')))
def plane(source,sa,A,U,V):
 ph=ns['ph'];name=names[id(source)];r=old.get((ph,name));sa=np.array(sa);A=np.array(A);U=np.array(U);V=np.array(V)

 im=baseplane(source,sa,A,U,V);im,edge,af,support=fg['float_color_edge'](source,sa,A,np.column_stack([U,V]),im)
 a=np.array(source);guard=8. if name=='RIGHT-actual-complete-forearm-grip-and-entire-pole-both-ends' else 2.
 y,x=np.where(a[:,:,3]>0);z=A[2]+U[2]*(x-sa[0])+V[2]*(y-sa[1]);smin=float(z.min()-.5*(abs(U[2])+abs(V[2]))-guard)
 yy,xx=np.where(np.array(im)[:,:,3]>0);grad=np.array([U[2],V[2]])@np.linalg.inv(P@np.column_stack([U,V]));delta=np.stack([xx-PAD-(ROOT+P@A)[0],yy-PAD-(ROOT+P@A)[1]]);z=A[2]+grad@delta;rmin=float(z.min()-.5*abs(grad).sum()-guard)
 records.append(dict(phase=ph,name=name,kind='ACTUAL_ORIGINAL_NATIVE_AFFINE_MATERIAL_FLOAT_RGBA_EDGE',source=pins[name],source_anchor=sa.tolist(),world_anchor=A.tolist(),source_world_U=U.tolist(),source_world_V=V.tolist(),guard_native=guard,source_texel_quad_plus_guard_min_Z=smin,raster_texel_quad_plus_guard_min_Z=rmin,above_floor=min(smin,rmin)>=0,raster=save(im,name),float_premultiplied_edge_sampler=pin(FP),float_color_edge_pixels=int(edge.sum()),alpha_unchanged_from_original_affine=True))
 new.append(dict(phase=ph,name=name));return im
def joint(source,*args,**kwargs):
 ph=ns['ph'];name=names[id(source)]
 result=basejoint(source,*args,**kwargs);im,m=result[:2]
 records.append(dict(phase=ph,name=name,kind='ACTUAL_NATIVE_CONTINUOUS_FIXED_PARENT_JOINT',source=pins[name],operator=m,defining_UV_code=pin(ns['JPATH']),source_texel_quad_plus_guard_min_Z=min(m['source_quad_min_Z'],m['complete_continuous_surface_quartic_min_Z'])-m['conservative_surface_and_raster_guard'],raster_texel_quad_plus_guard_min_Z=m['raster_texel_quad_min_Z']-m['conservative_surface_and_raster_guard'],above_floor=bool(m['above_floor']),raster=save(im,name)))
 new.append(dict(phase=ph,name=name));return result
def cloth(source,*args,**kwargs):
 im,m=basecloth(source,*args,**kwargs);ph=ns['ph'];name=names[id(source)]
 records.append(dict(phase=ph,name=name,kind='ACTUAL_ORIGINAL_NATIVE_PELVIS_BOUND_CLOTH',source=pins[name],operator=m,defining_UV_code=pin(ns['CPATH']),source_texel_quad_plus_guard_min_Z=min(m['source_complete_surface_min_Z'],m['source_all_quad_corner_min_Z'])-m['guard_native'],raster_texel_quad_plus_guard_min_Z=m['raster_all_texel_quad_min_Z']-m['guard_native'],above_floor=bool(m['above_floor']),raster=save(im,name)))
 new.append(dict(phase=ph,name=name));return im,m
ns['plane']=plane;ns['JF']['native_joint_strip']=joint;ns['CF']['root_bound_cloth']=cloth
ns['rows']=[]
loop=rest.split('\ncontract=dict',1)[0]
exec(compile(ast.parse(loop),str(RP),'exec'),ns)
rows=ns['rows'];bad=[dict(phase=r['phase'],name=r['name']) for r in records if not r['above_floor']]
out=dict(status='ACTUAL_OWN_S_DEDICATED_TRUE_GROUND_DIAGONAL_COLLAPSE_SIX_ORIGINAL_BOOT_AND_LEFT_CUFF_OWNED_PENDING_INDEPENDENT_SOURCE_CYCLE_QC',actor='transform:413',direction='S',motion='death',fixed_C=ns['C'],bodyunit=ns['UNIT'],common_unpadded_root=ROOT.tolist(),storage_canvas=[N,N],storage_translation=[PAD,PAD],logical_canvas=1024,source_RGBA_scaled=False,wholeactor_mirror=False,perpose_root_or_C_fit=False,fixed_femur_tibia=ns['BONE'],runtime_death_seconds=.8,resource_role_seconds=.65,phase_seconds=.8/6,loop=False,held_dead_terminal=True,frames=rows,actual_parts_manifest=pin(ns['MP']),once_registration=pin(ns['REG']),canonical_original_sole_capture=pin(ns['SOLE']),projection_matrix=P.tolist(),rig_renderer=pin(RP),assembly_renderer=pin(Path(__file__)),actual_part_count=len(records),records=records,prior_preserved_HOLD_actual_six_contract=pin(CACHEP),actual_heel_to_socket_flat_SO3_rule="One proper3D rotation per entire original shoe/counter source; actual heel-to-source-distal-socket vector maps towards the negative declared target ground longitudinal axis [sin40,cos40,0], transverse axis is the orthogonalized original sourceU. No source scaling/repainting or side mirroring.",native_source_boot_owner_gate="PASS770d303e exact boot-only calf-AA ownership3ec2f3fb; tinycape-tab12 PASSabf16473",native_source_LEFT_cuff_owner_gate="Native original smallblue wall489texels transferred HEAD/CORE to LEFTupper by independent source owner PASS1e34ddd3; posedjoint verification remains",body_and_pose_design="Stagger820 -> forwardknee buckle700 -> fall470 -> asymmetricimpact200 -> ground65 -> helddead60; Source target ground yaw -40degrees is a proper3D direction choice for visible heldsupine. Sourcebodyunit/root/fixed289.75 bones remain immutable. Storageonly3072+384 preserves full original staff/feet without fitting.",source_capture_body_U=ns['U'].tolist(),source_capture_body_V=ns['V'].tolist(),exact_reused_part_count=len(reuse),exact_reused_parts=reuse,new_or_changed_part_count=len(new),new_or_changed_parts=new,minimum_guarded_Z=min(r[k] for r in records for k in ['source_texel_quad_plus_guard_min_Z','raster_texel_quad_plus_guard_min_Z']),floor_HOLD=bad,terminal_cloth_only_unmade_node_change={'phase4':{'prior_unrendered_angle':80,'actual_angle':72},'phase5':{'prior_unrendered_angle':85,'actual_angle':76},'reason':'Original long cloth physically drapes to declared floor Z10 rather than remaining suspended. This is a newly authored real S collapse using the unchanged fixed bone lengths, body registration and native source RGBA. Sourcefoot properSO3 maps actual heel-to-distal-socket direction along the body longitudinal ground plane, avoiding the prior transverse foot-plane convention. Prior90 and both actualsix sourceHOLD versions remain preserved.'},limits=['One declared finite capture/fall model, not a unique hidden3D solution.','Native original boot-only calf edges and small LEFT blue uppercuff ownership are independently source-confirmed; this dedicated DEATH source and new posed joints still require independent actual quality review.','Visible terminal torso front plane Z60 with fixed unseen back support thickness60 to floor0.','Original source and actual raster alpha>0 texelquad plus declared guards are separate witnesses; complete nonlinear source audit still requires independent verification.'],actor_approvals_added=0,game_clips_adopted=0)
assert len(records)==108 and len(rows)==6
p=D/'own-S-DEATH-six-actual-native-source-contract-v07.json';p.write_text(json.dumps(out,indent=2,default=lambda x:x.item() if isinstance(x,np.generic) else str(x))+'\n')
print(json.dumps(dict(contract=pin(p),actual_parts=len(records),exact_reused=len(reuse),new_or_changed=len(new),minZ=out['minimum_guarded_Z'],floor_HOLD=bad,strong=[x['strong_components'] for x in rows],border=[x['storage_boundary_alpha_contact'] for x in rows])))
