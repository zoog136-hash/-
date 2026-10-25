from pathlib import Path
from PIL import Image
from scipy.ndimage import binary_dilation
import json,hashlib,numpy as np

D=Path(__file__).parent
S=Path('/workspace/scratch/mythic413-SW-private-base-generation-continuing-20261020-v01/service-SW-fullbody-base-native-r001.png')
def rec(p):
 b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
assert rec(S)['sha256']=='1e5de9a93d8755783a2405733eddb21f7f59b3141acb9f5204332228a7a263ee'
a=np.asarray(Image.open(S).convert('RGBA'));strong=a[:,:,3]>=8
keep=binary_dilation(strong,iterations=2)&(a[:,:,3]>0)
clean=a.copy();clean[~keep]=0
out=D/'SW-new-high-quality-native-background-AA-clean-v01.png';assert not out.exists();Image.fromarray(clean).save(out)
mask=D/'SW-new-base-actual-material-plus-two-pixel-native-AA-support-mask-v01.png';Image.fromarray(keep.astype('uint8')*255).save(mask)
assert not np.any(clean[strong]!=a[strong])
y,x=np.where(clean[:,:,3]>0)
proof=dict(schema='MYTHIC413_NEW_SW_BASE_NATIVE_BACKGROUND_AA_CLEAN_V01',raw_service_source=rec(S),output=rec(out),support_mask=rec(mask),method='Retain every native RGBA pixel alpha>=8 exactly, and its existing alpha>0 antialias material within a two-pixel dilation. All other sub-alpha8 isolated background and RGB-under-alpha0 are exact RGBA0. No new painted pixels, resampling, alpha-height normalization or density registration.',all_original_alpha_ge8_RGBA_mismatch=int(np.any(clean[strong]!=a[strong],axis=1).sum()),preserved_visible_source_pixels=int(strong.sum()),cleared_RGBA_pixels=int(np.any(clean!=a,axis=2).sum()),clean_alpha_bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)],native_size=list(Image.open(out).size),source_density_or_foot_geometry_changed=False,C_root_unit_registration='PENDING_ONCE_BODY_GATE',actor_approvals_added=0)
p=D/'SW-new-native-base-background-AA-clean-source-and-preservation-proof-v01.json';p.write_text(json.dumps(proof,indent=2)+'\n')
print(json.dumps(dict(source=rec(out),proof=rec(p),alpha_bbox=proof['clean_alpha_bbox'],visible_RGBA_mismatch=proof['all_original_alpha_ge8_RGBA_mismatch'],cleared=proof['cleared_RGBA_pixels']),separators=(',',':')))
