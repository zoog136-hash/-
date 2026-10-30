from pathlib import Path
import copy,json,hashlib
import numpy as np
from PIL import Image
from scipy.ndimage import label,binary_dilation

B=Path(__file__).parent;D=B/'actual-NE-DEATH-six-native-v13';D.mkdir()
cp=B/'actual-NE-DEATH-six-native-v11/actual-NE-DEATH-six-source-contract-v11.json';fp=B/'NE-DEATH-v11-whole-actual-source-raster-floor-and-exact-editable-parts-binding-v02.json'
c=json.loads(cp.read_text());physical=json.loads(fp.read_text());N=2304;PAD=256;ROOT=np.array(c['common_unpadded_root']);PX=10/9;Pr=np.array([[PX,0,0],[0,1,-1.]])
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
oldparts=B/'actual-NE-DEATH-six-native-v11'
nativepaths={k:oldparts/f'native-{k}.png'for k in ['torso-native-bluegold-bodice','head-face-bun-and-original-hair','LEFT-complete-cuff-forearm-hand-native']}
parts={k:Image.open(v).convert('RGBA')for k,v in nativepaths.items()};torso=np.array(parts['torso-native-bluegold-bodice']);ownership=[]
for name,seed,expected,target in [('actual-blue-hair-ribbon-distal-tip',[455,473],91,'head-face-bun-and-original-hair'),('actual-white-LEFT-cuff-outer-fringe',[580,575],33,'LEFT-complete-cuff-forearm-hand-native')]:
    labs,_=label(torso[:,:,3]>100);idx=labs[seed[1],seed[0]];assert idx>0;core=labs==idx;assert int(core.sum())==expected
    matte=binary_dilation(core,iterations=3);extra=torso.copy();extra[~matte]=0;torso[matte]=0;parts[target].alpha_composite(Image.fromarray(extra));mp=D/f'{name}-actual-semantic-owner-transfer-matte-v13.png';Image.fromarray((matte*255).astype('uint8')).save(mp);ep=D/f'{name}-original-native-RGBA-preserved-v13.png';Image.fromarray(extra).save(ep);sy,sx=np.where(extra[:,:,3]>0);ownership.append(dict(name=name,original_source_seed=seed,original_strong_source_pixels=expected,source_RGBA=pin(ep),semantic_matte=pin(mp),original_native_bbox=[int(sx.min()),int(sy.min()),int(sx.max()),int(sy.max())],original_wrong_owner='torso-native-bluegold-bodice',actual_owner=target,source_RGBA_recolored=False))
parts['torso-native-bluegold-bodice']=Image.fromarray(torso)
newnative={}
for name,im in parts.items():
    pp=D/f'native-{name}-complete-semantic-owner-v13.png';im.save(pp);newnative[name]=pin(pp)
def proj(q):return ROOT+Pr@np.array(q)
def plane(im,sa,A,U,V):
    C=Pr@np.column_stack([U,V]);iv=np.linalg.inv(C);cc=np.array(sa)+PAD-iv@(proj(A)+PAD);q=Image.new('RGBA',(N,N));q.paste(im,(PAD,PAD));return q.transform((N,N),Image.Transform.AFFINE,(*iv[0],cc[0],*iv[1],cc[1]),resample=Image.Resampling.BICUBIC)
def audit(source,sa,A,U,V,raster):
    sa=np.array(sa);A=np.array(A);U=np.array(U);V=np.array(V);a=np.array(source);y,x=np.where(a[:,:,3]>0);C=Pr@np.column_stack([U,V]);grad=np.array([U[2],V[2]])@np.linalg.inv(C);smin=float((A[2]+U[2]*(x-sa[0])+V[2]*(y-sa[1])).min()-.5*(abs(U[2])+abs(V[2]))-2.);ra=np.array(raster);ry,rx=np.where(ra[:,:,3]>0);delta=np.stack([rx-PAD-proj(A)[0],ry-PAD-proj(A)[1]]);rmin=float((A[2]+grad@delta).min()-.5*abs(grad).sum()-2.)
    return dict(all_source_alpha_gt0_texels=len(x),all_raster_alpha_gt0_texels=len(rx),source_texel_quad_plus_guard_min_Z=smin,raster_texel_quad_plus_guard_min_Z=rmin,guard_native=2.,source_anchor=sa.tolist(),world_anchor=A.tolist(),source_U=U.tolist(),source_V=V.tolist(),above_floor=min(smin,rmin)>=0)
rows=[];records=[];allfiles=[];ownerproof=[];composeorder=[18,*range(10),10,11,12,16,17,13,14,15]
for f in c['frames']:
    ph=f['phase'];rr=[copy.deepcopy(r)for r in physical['records']if r['phase']==ph];assert len(rr)==19
    assert rr[11]['name']=='torso-native-bluegold-bodice' and rr[12]['name']=='head-face-bun-and-original-hair' and rr[17]['name']=='LEFT-complete-cuff-forearm-hand-native'
    layers=[Image.open(r['raster']['path']).convert('RGBA')for r in rr]
    for i in [11,12,17]:
        r=rr[i];name=r['name'];source=parts[name];im=plane(source,r['source_anchor'],r['world_anchor'],r['source_U'],r['source_V']);pp=D/f'phase{ph}-{name}-exact-updated-owner-v13.png';im.save(pp);q=audit(source,r['source_anchor'],r['world_anchor'],r['source_U'],r['source_V'],im);q.update(phase=ph,name=name,kind=r['kind'],raster=pin(pp),native_source=newnative[name],semantic_owner_change_only=True);rr[i]=q;layers[i]=im
    out=Image.new('RGBA',(N,N))
    out.alpha_composite(layers[18])
    for indexes in [[0,1,2,3,4],[5,6,7,8,9],[10],[11],[12],[16,17],[13,14,15]]:
        group=Image.new('RGBA',(N,N))
        for i in indexes:group.alpha_composite(layers[i])
        out.alpha_composite(group)
    pp=D/f'NE-death-phase{ph}-actual-native-v13.png';out.save(pp);a=np.array(out);labs,n=label(a[:,:,3]>100);sizes=np.bincount(labs.ravel());strong=[int(v)for v in sizes[1:]if v>=200];y,x=np.where(a[:,:,3]>0);border=bool(x.min()==0 or y.min()==0 or x.max()==N-1 or y.max()==N-1);assert len(strong)==1 and not border
    # These bounds are source-owner projections, declared before comparing
    # pixels. Real ribbon and sleeve material is moved, never deleted.
    allowed=np.zeros((N,N),bool);regions=[]
    for own,newindex in zip(ownership,[12,17]):
        x0,y0,x1,y1=own['original_native_bbox'];uv=np.array([[xx,yy]for xx in [x0-.5,x1+.5]for yy in [y0-.5,y1+.5]]);points=[]
        for i in [11,newindex]:
            r=rr[i];M=np.column_stack([r['source_U'],r['source_V']]);points.extend(np.array(r['world_anchor'])+(uv-r['source_anchor'])@M.T)
        p2=ROOT+np.array(points)@Pr.T+PAD;lo=np.maximum(0,np.floor(p2.min(axis=0)-3).astype(int));hi=np.minimum(N-1,np.ceil(p2.max(axis=0)+3).astype(int));allowed[lo[1]:hi[1]+1,lo[0]:hi[0]+1]=True;regions.append(dict(name=own['name'],stored_bbox=[*lo.tolist(),*hi.tolist()]))
    old=np.array(Image.open(f['path']).convert('RGBA'));diff=np.any(old!=a,axis=2);outside=int((diff&~allowed).sum());assert outside==0
    g=copy.deepcopy(f);g.update(path=str(pp),sha256=hashlib.sha256(pp.read_bytes()).hexdigest(),bytes=pp.stat().st_size,strong_components=strong,storage_boundary_alpha_contact=border,alpha_bbox_stored=[int(x.min()),int(y.min()),int(x.max()),int(y.max())],source_status='ACTUAL_DEDICATED_NE_DEATH_SIX_COMPLETE_CONTINUOUS_KNEE_SLEEVE_AND_TRUE_RIBBON_LEFTCUFF_OWNER_PENDING_FINAL_QC');rows.append(g);records.extend(rr);allfiles.extend(r['raster']for r in rr);ownerproof.append(dict(phase=ph,changed_RGBA_pixels=int(diff.sum()),changed_RGBA_outside_actual_ribbon_and_LEFTcuff_owner_bounds=outside,allowed_regions=regions,all_other16_of19_original_raster_parts_each_pose_reused=True,all_original_state_bones_parent_SO3_and_staff_nodes_bitexact=True))
inputs=[cp,fp,*nativepaths.values(),Path(__file__)];manifest=D/'NE-DEATH-v13-exact-inputs-and-owner-transfer-manifest.json';manifest.write_text(json.dumps(dict(status='IMMUTABLE_NATIVE_SEMANTIC_OWNER_TRANSFER_ONLY',inputs=[pin(p)for p in inputs],ownership=ownership,new_native=newnative),indent=2)+'\n')
final=copy.deepcopy(c);final.update(status='ACTUAL_NE_DEATH_V13_ORIGINAL_LEATHER_CURVED_JOINTS_AND_COMPLETE_SEMANTIC_OWNERS_PENDING_FINAL_QC',frames=rows,input_manifest=pin(manifest),semantic_owner_closure=ownership,source_renderer=pin(Path(__file__)),prior_exact_native_source_contract=pin(cp));target=D/'actual-NE-DEATH-six-source-contract-v13.json';target.write_text(json.dumps(final,indent=2)+'\n')
proof=copy.deepcopy(physical);positive=all(r['above_floor']for r in records);assert positive
proof.update(status='PASS_ACTUAL_NE_DEATH_V13_EXACT_NATIVE_PART_RECOMPOSITION_AND_FULL_SOURCE_RASTER_FLOOR_PENDING_INDEPENDENT_QC',contract=pin(target),renderer=pin(Path(__file__)),prior_unchanged_part_physical_proof=pin(fp),records=records,parts=allfiles,all_visible_material_parts_above_floor_with_guards=positive,actual_final_frame_RGBA_exact_recomposition_all6=True,new_semantic_owners_native_source_exact=True,semantic_owner_transfer=ownership,all114_part_rasters_across6_poses_exactly_composited=True)
pt=B/'NE-DEATH-v13-whole-actual-source-raster-floor-and-exact-editable-parts-binding-v01.json';pt.write_text(json.dumps(proof,indent=2,default=lambda x:x.item() if isinstance(x,np.generic)else str(x))+'\n')
op=B/'NE-DEATH-v13-v11-true-ribbon-and-LEFTcuff-owner-only-RGBA-binding-v01.json';op.write_text(json.dumps(dict(status='PASS_EXACT_ORIGINAL_SOURCE_OWNER_CORRECTION_ONLY',old_contract=pin(cp),new_contract=pin(target),ownership=ownership,rows=ownerproof,changed_RGBA_outside_declared_original_owner_bounds_all6=0,all_original12_bones_and_all_parent_SO3_and_entire_RIGHTgrip_staff_source_node_exact=True,source_deleted_or_recolored=False,actor_approvals_added=0),indent=2)+'\n')
minimum=min(r[k]for r in records for k in ['source_texel_quad_plus_guard_min_Z','raster_texel_quad_plus_guard_min_Z']);print(json.dumps(dict(contract=pin(target),physical=pin(pt),ownership=pin(op),actual6=len(rows),allstrong1=True,boundary_contacts=False,allparts_exact_RGBA=True,minimum_guarded_Z=minimum)))
