from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image,ImageDraw
B=Path('/workspace/scratch/mythic413-NW-run-author-20261020-r001');D=Path(__file__).resolve().parent
master=B/'thunder_female-NW-run-contact0-v01-service.png';current=B/'thunder_female-NW-run-contact0-v04-localized-composite.png';original_mask=B/'NW-run-contact0-localized-union-editable-mask-v04.png'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(master)=='915b1a2dfbaf90529bd63601a25cece5ece5dfbda5520489a38f3bdb0c1f5007'
assert sha(current)=='e37a2866b069ece600288777962d44a535ce17a88bd8f4f4b30dd6f56219228a'
assert sha(original_mask)=='d8115f8b78640bfd1a4497891dd91daae923cf2ee809726e783a381badf5e012'
M=np.asarray(Image.open(master).convert('RGBA'));C=np.asarray(Image.open(current).convert('RGBA'));E=np.asarray(Image.open(original_mask).convert('L'))>0
body=[(550,330),(650,320),(731,361),(750,420),(735,479),(720,520),(757,552),(810,629),(807,705),(786,714),(745,704),(709,692),(672,692),(636,685),(609,681),(580,674),(556,667),(538,655),(535,550),(557,490),(543,425)]
arm=[(553,392),(579,393),(603,401),(623,416),(628,438),(617,452),(626,478),(641,512),(643,544),(636,570),(623,594),(613,612),(611,630),(616,651),(620,675),(613,690),(598,701),(583,695),(577,681),(576,662),(574,640),(575,621),(568,609),(563,592),(568,565),(567,544),(565,522),(561,498),(551,486),(532,489),(520,479),(513,463),(513,438),(517,418),(532,401)]
def poly(points):
 im=Image.new('L',(1254,1254),0);ImageDraw.Draw(im).polygon(points,fill=255);return np.asarray(im)>0
A=poly(arm);S=poly(body)&E&(~A);O=C.copy();O[S]=M[S]
for n,a in [('contact0-original-garment-restore-semantic-mask-v01.png',S),('contact0-actual-new-arm-foreground-protect-mask-v01.png',A)]:
 p=D/n;assert not p.exists();Image.fromarray((a*255).astype('uint8'),'L').save(p)
p=D/'thunder_female-NW-run-contact0-v05-original-garment-restored.png';assert not p.exists();Image.fromarray(O,'RGBA').save(p)
changed=np.any(O!=C,axis=2)
assert np.count_nonzero(changed&(~S))==0 and np.count_nonzero(changed&(~E))==0
assert np.array_equal(O[A],C[A]) and np.array_equal(O[S],M[S])
assert np.array_equal(O[720:,:],C[720:,:])
proof=dict(status='ORIGINAL_GARMENT_RGBA_RESTORED_PENDING_INDEPENDENT_STATIC_QC',master=dict(path=str(master),sha256=sha(master)),previous=dict(path=str(current),sha256=sha(current)),output=dict(path=str(p),sha256=sha(p),bytes=p.stat().st_size,canvas=[1254,1254]),restore_mask=dict(path=str(D/'contact0-original-garment-restore-semantic-mask-v01.png'),sha256=sha(D/'contact0-original-garment-restore-semantic-mask-v01.png'),polygon=body),actual_new_arm_protect=dict(path=str(D/'contact0-actual-new-arm-foreground-protect-mask-v01.png'),sha256=sha(D/'contact0-actual-new-arm-foreground-protect-mask-v01.png'),polygon=arm),restored_pixels=int(S.sum()),changed_pixels=int(changed.sum()),outside_restore_changed_pixels=0,outside_original_editable_mask_changed_pixels=0,new_actual_arm_foreground_changed_pixels=0,entire_lowerbody_y720_down_exact=True,restored_pixels_source='EXACT_ORIGINAL_MASTER915_RGBA',no_service_or_pose_piece_pixels_added=True,raw_resampled=False,source_canvas_C=2560,source_static_approved=False,full_cycle_approved=False,actor_approvals_added=0)
q=D/'contact0-garment-restore-exact-provenance-v01.json';q.write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps({'output':str(p),'sha256':sha(p),'bytes':p.stat().st_size,'changed_pixels':int(changed.sum()),'provenance_sha256':sha(q)}))
