from pathlib import Path
from PIL import Image
from scipy.ndimage import distance_transform_edt,binary_dilation,gaussian_filter
import numpy as np,json,hashlib,copy
B=Path(__file__).parent;D=B/'actual-own-E-ATTACK-native-expanded-cape-seam-v06';D.mkdir(exist_ok=False)
P=B/'actual-own-E-ATTACK-native-complete-materials-v04/E-ATTACK-own-complete-native-parts-and-actual-local-cape-provenance-v04.json';j=json.loads(P.read_text())
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
a=np.array(Image.open(j['source']['path']).convert('RGBA'));H,W=a.shape[:2]
old=np.array(Image.open(j['actual_local_cape_retouch']['source_masked_only_plate']['path']).convert('RGBA'))
paint=np.array(Image.open(j['actual_local_cape_retouch']['local_native_paint']['path']).convert('RGBA'))
rh=json.loads(Path(j['actual_local_cape_retouch']['service_handoff']['path']).read_text());m0=np.array(Image.open(rh['replacement_mask_source']['path']).convert('L'))>0;assert int(m0.sum())==5113
weapon=np.array(Image.open(j['parts']['complete-rigid-RIGHT-near-staff']['path']).convert('RGBA'))[:,:,3]>0
core0=np.array(Image.open(j['body_inputs']['attack-final-CORE-actual-local-cape-retouch']['body']['path']).convert('RGBA'));crop=a[770:1020,260:510].copy();visible=(core0[770:1020,260:510,3]>0)&~weapon[770:1020,260:510]&~m0
cape=visible|m0
# A single fixed native material expansion around the old occlusion. No actor
# registration, source body resampling, C/root or foot transformation occurs.
d=distance_transform_edt(~m0);w=np.clip(1-d/46.,0,1);w=w*w*(3-2*w)
# Keep the newly painted continuous cross and its native outline together;
# a cut through this connected gold motif caused the original vertical seam.
y,x=np.indices((250,250));gold0=(crop[:,:,0]>110)&(crop[:,:,0]>crop[:,:,2]*1.5)&(crop[:,:,1]>crop[:,:,2]*1.25)
gold1=(paint[:,:,0]>110)&(paint[:,:,0]>paint[:,:,2]*1.5)&(paint[:,:,1]>paint[:,:,2]*1.25)
seed=(gold0|gold1)&(d<77)&(y<150)&(x>100)
dg=distance_transform_edt(~seed);gw=np.clip(1-dg/8.,0,1);gw=gw*gw*(3-2*gw)
w=np.maximum(w,gw);w[~cape]=0;w[m0]=1
# Original visible cape silhouette is exact. Service RGB is nearest-interior
# extended only to that same original AA edge; no matte-colour/alpha halo.
valid=paint[:,:,3]>128
_,ix=distance_transform_edt(~valid,return_indices=True);rgb=paint[:,:,:3].copy();rgb[~valid]=paint[ix[0][~valid],ix[1][~valid],:3]
new=crop.copy();new[:,:,:3]=np.rint(crop[:,:,:3]*(1-w[:,:,None])+rgb*w[:,:,None]).astype('uint8');new[m0,3]=paint[m0,3]
# Known old-pole pixels below the actual new cape outline become transparent.
new[(m0)&(paint[:,:,3]==0)]=0
allowed=(w>0)&cape;plate=a.copy();plate[770:1020,260:510]=new;mask=np.zeros((H,W),bool);mask[770:1020,260:510]=allowed
assert not np.any(plate[~mask]!=a[~mask]);outside=int(np.count_nonzero(np.any(plate[~mask]!=a[~mask],axis=1)))
pp=D/'actual-original-E-source-only-bounded-expanded-local-cape-paint-v06.png';Image.fromarray(plate).save(pp)
mp=D/'actual-E-local-cape-expanded-fold-gold-boundary-allowed-mask-native-v06.png';Image.fromarray(mask.astype('uint8')*255).save(mp)
wp=D/'actual-E-local-cape-native-material-crossfade-weights-v06.png';Image.fromarray(np.rint(w*255).astype('uint8')).save(wp)
# Copy completed new cloth only; keep all previous semantic erasure and every
# unmodified source body/boot/gear pixel byte exact outside expanded cape ROI.
core=core0.copy();core[mask]=plate[mask];cp=D/'actual-E-complete-old-arms-staff-erased-body-fixed-boots-and-continuous-cape-v06.png';Image.fromarray(core).save(cp)
assert not np.any(core[~mask]!=core0[~mask])
j['body_inputs']['attack-final-CORE-actual-local-cape-retouch']['body']=pin(cp);j['body_inputs']['attack-final-CORE-actual-local-cape-retouch']['source_visual_status']='BOUNDED_NATIVE_CAPE_EXPANDED_MATERIAL_SEAM_CANDIDATE_PENDING_INDEPENDENT_SOURCE_QC'
j['actual_local_cape_retouch']['prior_strict5113_candidate']=pin(P);j['actual_local_cape_retouch']['source_masked_only_plate']=pin(pp);j['actual_local_cape_retouch']['expanded_local_actual_cape_mask']=pin(mp);j['actual_local_cape_retouch']['expanded_local_material_weights']=pin(wp);j['actual_local_cape_retouch']['replacement_pixels']=int(mask.sum());j['actual_local_cape_retouch']['outside_replacement_source_RGBA_difference']=outside;j['actual_local_cape_retouch']['expanded_native_cloth_only_basis']='Parent authorized cape-only enlargement: existing bluefold/gold motif retained as source material and blended into the one actual new local painted cloth; original visible alpha fixed outside original pole-occlusion mask.'
j['prior_material_input']=pin(P);j['source_production_status']='ACTUAL_E_ATTACK_LOCAL_CAPE_NATIVE_SEAM_CANDIDATE_PENDING_QC';jp=D/'E-ATTACK-own-complete-native-parts-and-bounded-expanded-cape-provenance-v06.json';jp.write_text(json.dumps(j,indent=2)+'\n')
proof={'schema':'bounded-local-actual-material-derivative-proof-v1','source':j['source'],'source_modified':False,'prior_material':pin(P),'new_material':pin(jp),'old_mask_pixels':int(m0.sum()),'new_allowed_mask_pixels':int(mask.sum()),'outside_mask_source_RGBA_changes':outside,'outside_mask_CORE_RGBA_changes':int(np.count_nonzero(np.any(core[~mask]!=core0[~mask],axis=1))),'source_visible_cape_alpha_outside_old_occlusion_changes':int(np.count_nonzero(new[:,:,3][~m0]!=crop[:,:,3][~m0])),'new_RGBA_diff_bbox':list(Image.fromarray(np.any(plate!=a,axis=2).astype('uint8')*255).getbbox()),'actor_C_root_unit_OR_boot_changes':False,'same_service_raw':j['actual_local_cape_retouch']['raw_unmodified'],'method':'single finite native distance crossfade plus whole connected cross-motif in actual cape; no affine search, no new service, no full actor transformation','SOURCE_status':'PENDING_PRIVATE_ACTUAL_SEAM_REVIEW'}
pr=D/'E-local-cape-expanded-native-mask-source-protection-proof-v06.json';pr.write_text(json.dumps(proof,indent=2)+'\n')
# A single native 2x comparison for finite private seam review.
imgs=[]
for ar in [crop,new]:
 im=Image.fromarray(ar);bg=Image.new('RGBA',im.size,(68,68,68,255));bg.alpha_composite(im);imgs.append(bg.convert('RGB'))
bd=Image.new('RGB',(500,250),(68,68,68));bd.paste(imgs[0],(0,0));bd.paste(imgs[1],(250,0));bd.save(D/'private-E-native-original-vs-expanded-cape-seam-v06.jpg',quality=92)
print(json.dumps({'material':pin(jp),'proof':pin(pr),'allowed_native_cape_pixels':int(mask.sum()),'outside_RGBA':outside}))
