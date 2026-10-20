"""Read-only reproducibility/preservation check; no actor/source approval."""
from pathlib import Path
import hashlib,json
from PIL import Image
import numpy as np
HERE=Path(__file__).parent
MASTER=HERE.parent/'thunder_female-NW-walk-contact0-v01-service.png'
FILES={MASTER:'dc5da66b30171bdff9ab4c25cf5a22327debe8c8b41088693824433cb4e684db',
 HERE/'thunder_female-NW-walk-contact0-LEFTbackswing-v02-service.png':'1cfe78368dbb3049f97a3495e030a04fde417ec65404a76dc1fec65ca45bf81d',
 HERE/'thunder_female-NW-walk-contact0-LEFTbackswing-bounded-v02.png':'0874d56a0adf0d76b5e91c565ec41d601d8bbb76457c64e703a89dba54cf0645',
 HERE/'allowed-actual-LEFT-backarm-mask-v02.png':'455d3552cdd4252168ad54df86a3f2ba515e18a50aa8d99bc8e93df003024181'}
for p,s in FILES.items():assert hashlib.sha256(p.read_bytes()).hexdigest()==s,p
base=Image.open(MASTER).convert('RGBA');raw=Image.open(HERE/'thunder_female-NW-walk-contact0-LEFTbackswing-v02-service.png').convert('RGBA')
actual=Image.open(HERE/'thunder_female-NW-walk-contact0-LEFTbackswing-bounded-v02.png').convert('RGBA');mask=Image.open(HERE/'allowed-actual-LEFT-backarm-mask-v02.png').convert('L')
assert base.size==raw.size==actual.size==mask.size==(1254,1254)
assert np.array_equal(np.asarray(Image.composite(raw,base,mask)),np.asarray(actual))
a=np.asarray(base);b=np.asarray(actual);m=np.asarray(mask)>0;changes=np.any(a!=b,axis=2)
assert not np.any(changes&~m)
assert np.array_equal(a[:435],b[:435]) and np.array_equal(a[750:],b[750:])
assert np.array_equal(a[:,750:],b[:,750:])
print(json.dumps({'status':'BOUNDED_RGBA_REPRODUCTION_PASS_NOT_SOURCE_APPROVAL','outside_mask_changed_pixels':0,'inside_mask_changed_pixels':int(np.count_nonzero(changes&m)),'virtual_C':2048,'resampling':'NONE_FOR_FINAL_SOURCE','actor_approval_added':0}))
