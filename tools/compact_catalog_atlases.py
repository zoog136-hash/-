#!/usr/bin/env python3
"""Package newly rendered catalog atlases as high-quality RGBA WebP.

Alpha is verified byte-for-byte. Source references and original source files
are unchanged. RGB quality is 94; this is derivative animation art, not a
byte-identical original-resource restoration. PNGs remain in staging for QA.
"""
import argparse, concurrent.futures, hashlib, json, pathlib
from PIL import Image

p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=pathlib.Path,required=True)
p.add_argument('--staging',type=pathlib.Path,required=True);p.add_argument('--reports',type=pathlib.Path,required=True)
a=p.parse_args();files=sorted((a.root/'assets/catalog_motion').rglob('*.png'));a.staging.mkdir(parents=True,exist_ok=True)
def encode(source):
    im=Image.open(source).convert('RGBA');relative=source.relative_to(a.root).with_suffix('.webp')
    dest=a.staging/relative;dest.parent.mkdir(parents=True,exist_ok=True)
    im.save(dest,'WEBP',quality=94,method=4)
    decoded=Image.open(dest).convert('RGBA')
    if decoded.size!=im.size or decoded.getchannel('A').tobytes()!=im.getchannel('A').tobytes():
        raise ValueError('RGBA alpha changed '+str(source))
    return {'old':'res://'+source.relative_to(a.root).as_posix(),'new':'res://'+relative.as_posix(),
            'old_bytes':source.stat().st_size,'bytes':dest.stat().st_size,
            'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'rgba_alpha_verified':True}
rows=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as workers:
    for i,row in enumerate(workers.map(encode,files),1):
        rows.append(row)
        if i%50==0: print('ENCODED',i,'/',len(files),flush=True)
a.reports.mkdir(parents=True,exist_ok=True)
(a.reports/'atlas_encoding.json').write_text(json.dumps(rows,indent=2)+'\n')
print('ATLAS_ENCODING_OK',len(rows),'png_bytes',sum(r['old_bytes'] for r in rows),'webp_bytes',sum(r['bytes'] for r in rows),flush=True)
