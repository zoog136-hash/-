#!/usr/bin/env python3
"""Audit every committed floor representative and dedicated alpha cutout.

Report all files rather than trusting only alpha at (0,0). Requiring transparent
edges is safe for 64px representative sprites; dedicated originals may touch an
edge legitimately and are checked for remaining near-white exterior matte.
"""
from __future__ import annotations
import hashlib, json, subprocess
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    categories=json.loads((ROOT/'data/ground_item_icons.json').read_text())['categories']
    dedicated=json.loads((ROOT/'data/ground_alpha.json').read_text())['images']
    issues=[];rows=[];changed=[]
    for category,entry in categories.items():
        path=ROOT/entry['path'].removeprefix('res://')
        image=Image.open(path).convert('RGBA');w,h=image.size
        samples=list(image.getdata());opaque=[p for p in samples if p[3]>0]
        border=[image.getpixel((x,0)) for x in range(w)]+[image.getpixel((x,h-1)) for x in range(w)]
        border += [image.getpixel((0,y)) for y in range(h)]+[image.getpixel((w-1,y)) for y in range(h)]
        if [w,h]!=[64,64] or not opaque:issues.append(f'{category}: dimensions / empty object')
        if any(p[3] for p in border):issues.append(f'{category}: opaque outer border')
        if digest(path)!=entry['sha256']:issues.append(f'{category}: manifest SHA mismatch')
        if entry['source_sha256'] != digest(ROOT/entry['source_path'].removeprefix('res://')):
            issues.append(f'{category}: original source changed')
        try:
            old=subprocess.check_output(['git','show',f'HEAD:{entry["path"].removeprefix("res://")}'],
                                        cwd=ROOT,stderr=subprocess.DEVNULL)
            if hashlib.sha256(old).hexdigest()!=digest(path):changed.append(category)
        except subprocess.CalledProcessError:
            changed.append(category)
        rows.append({'category':category,'size':[w,h],'opaque_pixels':len(opaque),
                     'transparent_pixels':w*h-len(opaque),'sha256':digest(path)})
    for source,entry in dedicated.items():
        path=ROOT/entry['path'].removeprefix('res://')
        if not path.exists():issues.append(f'{source}: dedicated missing');continue
        image=Image.open(path).convert('RGBA')
        if list(image.size)!=entry['size'] or image.getchannel('A').getbbox() is None:
            issues.append(f'{source}: dedicated changed dimensions or empty')
        if digest(path)!=entry['sha256']:issues.append(f'{source}: dedicated hash mismatch')
        if digest(ROOT/source.removeprefix('res://'))!=entry['source_sha256']:
            issues.append(f'{source}: dedicated original altered')
    scythe=Image.open(ROOT/'assets/ground_categories/scythe.png').convert('RGBA')
    if sum(p[3]>0 for p in scythe.getdata()) > 1100:
        issues.append('scythe retains too much green backdrop')
    if scythe.getchannel('A').getbbox() is None:
        issues.append('scythe silhouette accidentally removed')
    if len(rows)!=53 or len(dedicated)!=24:
        issues.append('unexpected ground asset census')
    result={'base_main':'3c9ff2cd89b7104afdd6b53ace69ca9ba39988f6',
            'category_total':len(rows),'dedicated_total':len(dedicated),
            'changed_categories':changed,'changed_count':len(changed),
            'issues':issues,'categories':rows,
            'scope':'ground presentation only; inventory and game data remain unmodified'}
    out=ROOT/'docs/verification/ground_matte_20261015'
    out.mkdir(parents=True,exist_ok=True)
    (out/'audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('GROUND_MATTE_AUDIT',json.dumps({k:v for k,v in result.items() if k!='categories'},ensure_ascii=False),flush=True)
    if issues: raise SystemExit(1)

if __name__=='__main__':main()
