from pathlib import Path
import copy,json,hashlib,numpy as np
from PIL import Image
from scipy.ndimage import label
B=Path(__file__).parent;D=B/'actual-own-E-DEATH-six-native-v04';D.mkdir()
cp=B/'actual-own-E-DEATH-six-native-v03/own-E-DEATH-six-actual-native-source-contract-v03.json'
fp=B/'own-E-DEATH-v03-whole-actual-source-raster-floor-and-exact108-native-parts-binding-v01.json'
c=json.loads(cp.read_text());physical=json.loads(fp.read_text());ROOT=np.array(c['common_unpadded_root']);P=np.array(c['projection_matrix']);PAD=256;N=2304
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def pair(thigh,calf,rt,rc,phase,side):
    # Both exact source surfaces are unchanged. Only the camera-ray order
    # resolves the projected fold; a nearer thigh occludes its own calf.
    a=np.array(thigh);b=np.array(calf);y,x=np.where((a[:,:,3]>0)|(b[:,:,3]>0));lo=np.array([x.min(),y.min()]);hi=np.array([x.max(),y.max()]);yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];screen=np.stack([xx-PAD-ROOT[0],yy-PAD-ROOT[1]],axis=-1)
    def depth(r):
        A=np.array(r['world_anchor']);M=np.column_stack([r['source_world_U'],r['source_world_V']]);uv=(screen-A@P.T)@np.linalg.inv(P@M).T;world=A+uv@M.T;return world[:,:,1]+world[:,:,2]
    da=depth(rt);db=depth(rc);both=(a[lo[1]:hi[1]+1,lo[0]:hi[0]+1,3]>0)&(b[lo[1]:hi[1]+1,lo[0]:hi[0]+1,3]>0);front=both&(da>db+1e-8)
    ab=Image.new('RGBA',(N,N));ab.alpha_composite(thigh);ab.alpha_composite(calf)
    ba=Image.new('RGBA',(N,N));ba.alpha_composite(calf);ba.alpha_composite(thigh)
    old=np.array(ab);swapped=np.array(ba);out=old.copy();roi=out[lo[1]:hi[1]+1,lo[0]:hi[0]+1];newroi=swapped[lo[1]:hi[1]+1,lo[0]:hi[0]+1];roi[front]=newroi[front]
    assert np.array_equal(out[:,:,3],old[:,:,3]);changed=np.any(out!=old,axis=2);allowed=np.zeros((N,N),bool);allowed[lo[1]:hi[1]+1,lo[0]:hi[0]+1]=front;assert not np.any(changed&~allowed)
    pp=D/f'phase{phase}-{side}-exact-thigh-calf-camera-ray-depth-selection-v04.npz';np.savez_compressed(pp,stored_bbox=np.r_[lo,hi],thigh_camera_ray_depth=da.astype('float32'),calf_camera_ray_depth=db.astype('float32'),both_actual_source_alpha_nonzero=both.astype('uint8'),nearer_thigh_in_front_selection=front.astype('uint8'))
    return Image.fromarray(out),allowed,dict(side=side,exact_thigh_raster=rt['raster'],exact_calf_raster=rc['raster'],selection=pin(pp),nearer_thigh_overlapping_pixels=int(front.sum()),leg_pair_changed_RGBA_pixels=int(changed.sum()),unchanged_alpha=True,only_actual_overlapping_surfaces_changed=True,camera_projection=P.tolist(),camera_ray_from_positive_Y_plus_Z=True,tie_rule='Original calf-over-thigh order retained for equal depth within1e-8.')
rows=[];proofrows=[]
for f in c['frames']:
    ph=f['phase'];rr=[r for r in physical['records']if r['phase']==ph];assert len(rr)==18
    assert [r['name']for r in rr[:5]]==['R-thigh','R-calf','R-kneestrip','R-anklestrip','R-foot']
    assert [r['name']for r in rr[5:10]]==['L-thigh','L-calf','L-kneestrip','L-anklestrip','L-foot']
    layers=[]
    for r in rr:
        pp=Path(r['raster']['path']);assert hashlib.sha256(pp.read_bytes()).hexdigest()==r['raster']['sha256'];layers.append(Image.open(pp).convert('RGBA'))
    leglayers=[];selection=[];allowed=np.zeros((N,N),bool)
    for side,start in [('R',0),('L',5)]:
        leg,aa,q=pair(layers[start],layers[start+1],rr[start],rr[start+1],ph,side);allowed|=aa
        for i in [start+2,start+3,start+4]:leg.alpha_composite(layers[i])
        leglayers.append(leg);selection.append(q)
    out=Image.new('RGBA',(N,N));out.alpha_composite(layers[17])
    for leg in leglayers:out.alpha_composite(leg)
    for i in [10,11,12]:out.alpha_composite(layers[i])
    for indexes in [[15,16],[13,14]]:
        arm=Image.new('RGBA',(N,N))
        for i in indexes:arm.alpha_composite(layers[i])
        out.alpha_composite(arm)
    old=np.array(Image.open(f['path']).convert('RGBA'));a=np.array(out);changed=np.any(a!=old,axis=2);assert np.array_equal(a[:,:,3],old[:,:,3]);assert not np.any(changed&~allowed)
    lab,n=label(a[:,:,3]>100);sz=np.bincount(lab.ravel());strong=[int(v)for v in sz[1:]if v>=200];assert len(strong)==1;yx=np.argwhere(changed);bbox=[int(yx[:,1].min()),int(yx[:,0].min()),int(yx[:,1].max()),int(yx[:,0].max())]if len(yx)else None
    pp=D/f'E-DEATH-phase{ph}-actual-native-v04.png';out.save(pp);g=copy.deepcopy(f);g.update(path=str(pp),sha256=hashlib.sha256(pp.read_bytes()).hexdigest(),bytes=pp.stat().st_size,strong_components=strong,exact_fixed_plane_depth_selection=selection);rows.append(g);proofrows.append(dict(phase=ph,changed_RGBA_pixels=int(changed.sum()),changed_RGBA_bbox=bbox,changed_RGBA_outside_actual_fixed_plane_occlusion_overlap=0,full_actor_alpha_bitexact=True,all18_original_material_rasters_sha_unchanged=True,original_parent_bones_pose_source_controls_SO3_floor_unchanged=True,selection=selection))
final=copy.deepcopy(c);final.update(status='ACTUAL_OWN_E_DEATH_SIX_FIXED_NATIVE_SURFACE_RAY_DEPTH_SELF_OCCLUSION_CLOSED_PENDING_FINAL_QC',frames=rows,prior_exact_native_source_contract=pin(cp),original_exact108_surface_floor_proof=pin(fp),self_occlusion_renderer=pin(Path(__file__)),self_occlusion_rule='For each original thigh/calf pair, use greater worldY+worldZ along the declared null ray[0,1,1] as foreground at overlapping painted texel centers. Source rasters, geometry, alpha and floor remain exact. Original continuous knee/ankle and complete foot material nodes retain their attachment layering.');target=D/'own-E-DEATH-six-actual-native-source-contract-v04.json';target.write_text(json.dumps(final,indent=2)+'\n')
proof=copy.deepcopy(physical);proof.update(status='PASS_OWN_E_DEATH_V04_ORIGINAL_EXACT108_PHYSICAL_SURFACES_WITH_CORRECT_FIXED_PLANE_SELF_OCCLUSION_PENDING_FINAL_QC',contract=pin(target),renderer=pin(Path(__file__)),prior_original_native_renderer=physical['renderer'],source_native_geometry_and_floor_proof=pin(fp),actual_all6_RGBA_exact_recomposition=True,all108_original_raster_source_geometry_and_floor_unchanged=True,self_occlusion_only=True,self_occlusion_rows=proofrows);out=B/'own-E-DEATH-v04-whole-original108-source-raster-floor-and-exact-self-occlusion-binding-v01.json';out.write_text(json.dumps(proof,indent=2)+'\n')
op=B/'own-E-DEATH-v04-v03-fixed-surface-ray-depth-only-changed-RGBA-binding-v01.json';op.write_text(json.dumps(dict(status='PASS_TRUE_FIXED_SURFACE_OCCLUSION_ONLY_NO_ASSET_OR_GEOMETRY_CHANGES',old_contract=pin(cp),new_contract=pin(target),defining_depth_selection_function=pin(Path(__file__)),all108_original_source_rasters_preserved_sha=True,all_parent_bones_source_controls_SO3_and_floor_values_exact=True,all6_actor_alpha_bitexact=True,rows=proofrows,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(contract=pin(target),physical=pin(out),selection_proof=pin(op),all6strong1=True,all6alpha_bitexact=True,changed_RGBA=[r['changed_RGBA_pixels']for r in proofrows])))
