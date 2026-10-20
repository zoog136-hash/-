from pathlib import Path
import ast,json,hashlib,math
import numpy as np
from PIL import Image

B=Path(__file__).parent;D=B/'actual-NE-DEATH-six-native-v05';O=B/'NE-DEATH-v05-exact-bound-editable-parts-and-floor-v01';O.mkdir()
cp=D/'actual-NE-DEATH-six-source-contract-v05.json';c=json.loads(cp.read_text());rp=B/'author-NE-DEATH-dedicated-native-six-v05.py'
for f in json.loads(Path(c['input_manifest']['path']).read_text())['files']:
 assert hashlib.sha256(Path(f['path']).read_bytes()).hexdigest()==f['sha256']
class NoSourceWrites(ast.NodeTransformer):
 def visit_Expr(self,n):
  if isinstance(n.value,ast.Call) and isinstance(n.value.func,ast.Attribute) and n.value.func.attr=='save':return ast.copy_location(ast.Pass(),n)
  return self.generic_visit(n)
source=rp.read_text();prefix,rest=source.split('rows=[]\n',1)
prefix=prefix.replace("D=B/'actual-NE-DEATH-six-native-v05';D.mkdir()",'D=O')
prefix='\n'.join("manifest=Path(c['input_manifest']['path'])" if line.startswith('manifest=B/') else line for line in prefix.splitlines())
ns=dict(__file__=str(rp),O=O,c=c,OriginalD=D)
tree=NoSourceWrites().visit(ast.parse(prefix));ast.fix_missing_locations(tree);exec(compile(tree,str(rp),'exec'),ns)
PX=ns['PX'];P=ns['P'];ROOT=ns['ROOT'];N=ns['N'];proj=ns['proj'];original={k:ns[k]for k in ['plane','bone','cloth']};records=[];files=[];serial={}
names={id(im):name for name,im in ns['parts'].items()}
for name,im in ns['coats']:names[id(im)]=name
def stamp(p):return dict(path=str(p),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
def savepart(im,kind,name):
 phase=ns['ph'];serial[phase]=serial.get(phase,0)+1;p=O/f'phase{phase}-{serial[phase]:02}-{kind}-{name}.png';im.save(p);row=stamp(p);files.append(row);return row
def audit(source,sa,A,U,V,raster,guard):
 sa=np.array(sa);A=np.array(A);U=np.array(U);V=np.array(V);src=np.array(source);y,x=np.where(src[:,:,3]>0)
 sz=A[2]+U[2]*(x-sa[0])+V[2]*(y-sa[1]);smin=float(sz.min()-.5*(abs(U[2])+abs(V[2]))-guard)
 C=np.array([[PX*U[0],PX*V[0]],[U[1]-U[2],V[1]-V[2]]]);iv=np.linalg.inv(C);grad=np.array([U[2],V[2]])@iv;ra=np.array(raster);ry,rx=np.where(ra[:,:,3]>0);delta=np.stack([rx-P-proj(A)[0],ry-P-proj(A)[1]]);rz=A[2]+grad@delta;rmin=float(rz.min()-.5*(abs(grad[0])+abs(grad[1]))-guard)
 return dict(all_source_alpha_gt0_texels=len(x),all_raster_alpha_gt0_texels=len(rx),source_texel_quad_plus_guard_min_Z=smin,raster_texel_quad_plus_guard_min_Z=rmin,guard_native=guard,source_anchor=sa.tolist(),world_anchor=A.tolist(),source_U=U.tolist(),source_V=V.tolist(),above_floor=bool(min(smin,rmin)>=-1e-8))
def plane(source,sa,A,U,V):
 raster=original['plane'](source,sa,A,U,V);name=names[id(source)];guard=8. if name=='RIGHT-complete-forearm-grip-staff-both-ends-native'else 2.;q=audit(source,sa,A,U,V,raster,guard);q.update(phase=ns['ph'],name=name,kind='exact_3D_material_plane',raster=savepart(raster,'plane',name));records.append(q);return raster
def bone(source,sa,sb,A,Z,parity=1):
 raster=original['bone'](source,sa,sb,A,Z,parity);sa=np.array(sa);sb=np.array(sb);A=np.array(A);Z=np.array(Z);sv=sb-sa;sl=np.linalg.norm(sv);sn=np.array([-sv[1],sv[0]])/sl;pv=proj(Z)-proj(A);tn=np.array([-pv[1],pv[0]])/np.linalg.norm(pv);bv=Z-A
 W=np.linalg.solve(np.array([[PX,0,0],[0,1,-1],bv/np.linalg.norm(bv)]),np.r_[tn/parity,0.]);U=bv*sv[0]/sl**2+W*sn[0];V=bv*sv[1]/sl**2+W*sn[1];name=names[id(source)];q=audit(source,sa,A,U,V,raster,2.);q.update(phase=ns['ph'],name=name,kind='exact_fixed_bone_flexible_native_material_surface',source_bone_end=sb.tolist(),world_bone_end=Z.tolist(),source_normal_world=W.tolist(),source_normal_world_dot_bone=float(np.dot(W,bv)),raster=savepart(raster,'bone',name));records.append(q);return raster
def cloth(source,sa,A,angle,transverse):
 raster=original['cloth'](source,sa,A,angle,transverse);theta=math.radians(angle);co=math.cos(theta);si=math.sin(theta);sa=np.array(sa);A=np.array(A);T=np.array(transverse);src=np.array(source);sy,sx=np.where(src[:,:,3]>0);uu=sx-sa[0];length=sy-sa[1];baseZ=A[2]+T[2]*uu;z=np.maximum(10.,baseZ-co*length)
 # Every source texel's four corners use the same actual piecewise arclength
 # surface. The floor branch itself is exactly Z10, including texel edges.
 corner_min=math.inf
 for dx in [-.5,.5]:
  for dy in [-.5,.5]:corner_min=min(corner_min,float(np.maximum(10.,A[2]+T[2]*(uu+dx)-co*(length+dy)).min()))
 ra=np.array(raster);ry,rx=np.where(ra[:,:,3]>0);rmin=math.inf
 for dx in [-.5,.5]:
  for dy in [-.5,.5]:
   u=(rx-P+dx-ROOT[0]-PX*A[0])/(PX*T[0]);bZ=A[2]+T[2]*u;bD=A[1]+T[1]*u;hit=np.maximum(0.,(bZ-10.)/max(co,1e-9));q=ry-P+dy-(ROOT[1]+bD-bZ);qh=(si+co)*hit;ell=np.where(q<=qh,q/(si+co),hit+q-qh);rz=np.maximum(10.,bZ-co*ell);rmin=min(rmin,float(rz.min()))
 name=names[id(source)];q=dict(phase=ns['ph'],name=name,kind='exact_native_2D_transverse_and_longitudinal_arclength_floor_surface',all_source_alpha_gt0_texels=len(sx),all_raster_alpha_gt0_texels=len(rx),source_texel_quad_plus_guard_min_Z=corner_min-2.,raster_texel_quad_plus_guard_min_Z=rmin-2.,guard_native=2.,fixed_floor_Z=10.,source_root=sa.tolist(),world_root=A.tolist(),transverse_world=T.tolist(),longitudinal_angle=angle,above_floor=bool(min(corner_min,rmin)>=2.),raster=savepart(raster,'cloth',name));records.append(q);return raster
ns.update(plane=plane,bone=bone,cloth=cloth,rows=[])
loop=rest.split('\ncontract=dict',1)[0]
loop=loop.replace("p=D/f'NE-death-phase{ph}-actual-native-v05.png'","p=OriginalD/f'NE-death-phase{ph}-actual-native-v05.png'")
loop=loop.replace('out.save(p);a=np.array(out);',"assert np.array_equal(np.array(out),np.array(Image.open(p).convert('RGBA')));a=np.array(out);")
tree=NoSourceWrites().visit(ast.parse(loop));ast.fix_missing_locations(tree);exec(compile(tree,str(rp),'exec'),ns)
for f in ns['rows']:
 assert f['sha256']==c['frames'][f['phase']]['sha256'] and len(f['strong_components'])==1 and not f['storage_boundary_alpha_contact']
bone_residual=max(abs(q[k]-275.2625)for f in c['frames']for q in f['bones'].values()for k in ['thigh_length','shin_length'])
baseGram=np.column_stack([c['source_capture_body_U'],c['source_capture_body_V']]);baseGram=baseGram.T@baseGram
staff_Gram_residual=max(float(np.max(np.abs(np.column_stack([f['arms']['R']['forearm_source_U'],f['arms']['R']['forearm_source_V']]).T@np.column_stack([f['arms']['R']['forearm_source_U'],f['arms']['R']['forearm_source_V']])-baseGram)))for f in c['frames'])
terminal=c['frames'][5];terminal_flat=max(abs(v)for Rname in ['pelvis_SO3','torso_SO3','head_SO3']for v in [float((np.array(terminal[Rname])@np.array(c['source_capture_body_U']))[2]),float((np.array(terminal[Rname])@np.array(c['source_capture_body_V']))[2])]);positive=all(q['above_floor']for q in records)
proof=dict(status='ACTUAL_NE_DEATH_V05_WHOLE_SOURCE_RASTER_TEXEL_FLOOR_AND_EXACT_PART_BINDING_PENDING_INDEPENDENT_QC'if positive else'ACTUAL_NE_DEATH_V05_FINITE_FLOOR_HOLD_PRESERVED',contract=stamp(cp),renderer=stamp(rp),fixed_C=2432,bodyunit=2.375,common_unpadded_root=c['common_unpadded_root'],storage_canvas=[2304,2304],storage_only_translation=[256,256],source_scaled=False,wholeframe_fit=False,perpose_C_or_root_fit=False,projection=[[PX,0,0],[0,1,-1]],actual_final_frame_RGBA_exact_recomposition_all6=True,all_source_and_raster_alpha_gt0_texel_quads_included=True,all_visible_material_parts_above_floor_with_guards=positive,records=records,parts=files,fixed_2752625_thigh_shin_residual=bone_residual,whole_RIGHTgrip_both_staff_ends_3D_source_Gram_residual=staff_Gram_residual,held_terminal=dict(runtime_death_seconds=.8,resource_role_seconds=.65,phase_seconds=.8/6,loop=False,held_dead_source_phase=5,back_surface_height=60.,fixed_body_head_front_thickness=60.,front_support_floor_Z=0.,terminal_body_head_plane_Z_derivative_residual=terminal_flat),limits=['One declared compatible native material/skeleton/source capture; no unique hidden anatomy is claimed.','Every complete native shoe and whole grip/staff remains one SO3 surface node. Actual flexible leather follows the exact275.2625 bones; the native transverse surface solves P(W)=actual screen-normal and W dot bone=0.','The fixed60native torso/head front support hull lies below the visible back plane; terminal front support reaches floor0. This finite hidden primitive is declared rather than a measured bitmap contour.','Whole source/raster painted material surfaces and guard bounds are proved. Corpse terminal and joint appearance require independent actual native source QC.','All failed versions/inputs remain preserved; no source/bodyunit/root/profile/threshold changes were made for this proof.'],actor_approvals_added=0,game_clips_adopted=0)
target=B/'NE-DEATH-v05-whole-actual-source-raster-floor-and-exact-editable-parts-binding-v01.json';assert not target.exists();target.write_text(json.dumps(proof,indent=2)+'\n');minimum=min(q[k]for q in records for k in ['source_texel_quad_plus_guard_min_Z','raster_texel_quad_plus_guard_min_Z']);bad=[dict(phase=q['phase'],name=q['name'],source=q['source_texel_quad_plus_guard_min_Z'],raster=q['raster_texel_quad_plus_guard_min_Z'])for q in records if not q['above_floor']];print(json.dumps(dict(proof=stamp(target),parts=len(files),records=len(records),all6_exact_RGBA=True,minimum_guarded_Z=minimum,floor_HOLD=bad)))
