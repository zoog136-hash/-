from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image,ImageDraw
D=Path(__file__).resolve().parent;B=Path('/workspace/scratch/mythic413-NW-run-author-20261020-r001')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
M=np.asarray(Image.open(B/'thunder_female-NW-run-contact0-v01-service.png').convert('RGBA'));C=np.asarray(Image.open(B/'thunder_female-NW-run-contact0-v04-localized-composite.png').convert('RGBA'));E=np.asarray(Image.open(B/'NW-run-contact0-localized-union-editable-mask-v04.png'))>0
prior=json.loads((D/'contact0-garment-restore-exact-provenance-v01.json').read_text());S0=np.asarray(Image.open(D/'contact0-original-garment-restore-semantic-mask-v01.png'))>0;A=np.asarray(Image.open(D/'contact0-actual-new-arm-foreground-protect-mask-v01.png'))>0
assert sha(B/'thunder_female-NW-run-contact0-v01-service.png')==prior['master']['sha256'] and sha(B/'thunder_female-NW-run-contact0-v04-localized-composite.png')==prior['previous']['sha256']
def poly(points):
 im=Image.new('L',(1254,1254),0);ImageDraw.Draw(im).polygon(points,fill=255);return np.asarray(im)>0
extra_poly=[(540,635),(825,635),(835,760),(800,755),(740,748),(680,742),(620,735),(550,725),(525,705)]
near_poly=[(519,711),(530,698),(539,691),(553,690),(568,694),(583,699),(596,711),(603,727),(622,740),(632,780),(620,850),(480,850),(480,735)]
far_poly=[(604,735),(629,724),(649,716),(671,716),(691,720),(709,728),(704,740),(693,750),(720,750),(741,754),(760,765),(778,779),(800,800),(820,820),(835,850),(605,850)]
Near=poly(near_poly);F0=poly(far_poly);yy=np.indices(E.shape)[0];rgb=C[:,:,:3].astype(float);black=(rgb.max(axis=2)<115)&(rgb[:,:,2]<1.65*(rgb[:,:,0]+1))&(rgb[:,:,2]<1.5*(rgb[:,:,1]+1));Far=F0&((yy>=760)|black)
Extra=poly(extra_poly)&E&(~A)&(~Near)&(~Far);S=(S0|Extra)&(~Near)&(~Far)&(~A);O=C.copy();O[S]=M[S]
for name,mask in [('contact0-original-garment-restore-semantic-mask-v02.png',S),('contact0-new-nearboot-cuff-protect-mask-v02.png',Near),('contact0-new-farleg-foreground-protect-mask-v02.png',Far)]:
 p=D/name;assert not p.exists();Image.fromarray((mask*255).astype('uint8')).save(p)
p=D/'thunder_female-NW-run-contact0-v06-original-hem-restored.png';assert not p.exists();Image.fromarray(O).save(p)
changed=np.any(O!=C,axis=2);assert not np.any(changed&(~S));assert not np.any(changed&(~E));assert not np.any(changed&(A|Near|Far));assert np.array_equal(O[760:,:],C[760:,:])
proof=dict(status='ORIGINAL_HEM_MASK_CORRECTION_PENDING_STATIC_QC',master=prior['master'],previous=prior['previous'],parent_restore_proof_sha256=sha(D/'contact0-garment-restore-exact-provenance-v01.json'),output=dict(path=str(p),sha256=sha(p),bytes=p.stat().st_size,canvas=[1254,1254]),original_mask_sha256=sha(B/'NW-run-contact0-localized-union-editable-mask-v04.png'),extra_semantic_polygon=extra_poly,near_actual_boot_protect_polygon=near_poly,far_actual_leg_protect_polygon=far_poly,far_protect_material_condition='below760 or near-blackactualboot; no white/gold residual skirt retained by this foregroundmask',masks=[dict(path=str(D/n),sha256=sha(D/n))for n in ['contact0-original-garment-restore-semantic-mask-v02.png','contact0-new-nearboot-cuff-protect-mask-v02.png','contact0-new-farleg-foreground-protect-mask-v02.png','contact0-actual-new-arm-foreground-protect-mask-v01.png']],changed_pixels=int(changed.sum()),outside_restore_changed=0,outside_original_editmask_changed=0,new_arm_nearboot_farleg_foreground_changed=0,lowerbody_y760_down_exact=True,newly_revealed_upperhip_pixels='exact915master below one originalhem; no oldleg BELOWbodyjoin reintroduced',source_resampled=False,native_C=2560,no_image_service_invoked=True,actor_approvals_added=0)
q=D/'contact0-original-hem-restore-exact-provenance-v02.json';q.write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'output':str(p),'sha256':sha(p),'bytes':p.stat().st_size,'changed_pixels':int(changed.sum()),'proof_sha256':sha(q)}))
