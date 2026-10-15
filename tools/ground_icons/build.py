#!/usr/bin/env python3
"""Bake bounded, transparent floor representatives from existing repository PNGs.

No network, no new artwork claims, no gameplay identity modifications. Original
source PNGs remain byte-for-byte unchanged; output paths belong to floor art only.
"""
from __future__ import annotations
import argparse, hashlib, io, json
from collections import deque
from pathlib import Path
from PIL import Image
from alpha import clear_white_border

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT/'data/ground_item_icons.json'
# True floor sources already present in the project take priority.
FLOOR = {
 'sword':('assets/l1j/verified/ground/29.png','은장검'),
 'dagger':('assets/l1j/verified/ground/8.png','미스릴 단검'),
 'bow':('assets/l1j/verified/ground/181.png','장궁'),
 'spear':('assets/original_items/ground/5.png','벡드코빈'),
 'claw':('assets/original_items/ground/3309.png','증오의 발톱'),
 'gauntlet':('assets/original_items/ground/2921.png','건틀렛'),
 'helmet':('assets/original_items/ground/7208.png','쿠쿨칸의 마스크'),
 'armor':('assets/original_items/ground/3427.png','라스타바드 체인 메일'),
 'cloak':('assets/original_items/ground/13.png','군주의 위엄'),
 'shield':('assets/original_items/ground/3425.png','라스타바드 라운드 실드'),
 'necklace':('assets/original_items/ground/7212.png','제브 레퀴의 마안')}
IDS = {'greatsword':'250','axe':'474','scythe':'185804','dual':'492','staff':'481',
 'rifle':'96414','cannon':'96424','chain':'114102','runesword':'291722',
 'tshirt':'384','pants':'601','gloves':'231','boots':'230','ring':'312','earring':'621',
 'belt':'323','bracelet':'150443','badge':'183691','seal':'30671','crystal':'213481',
 'catalyst':'289062','rune':'882','potion_hp':'233','potion_mp':'385','potion_buff':'117294',
 'scroll':'6401','food':'855','elixir':'4151','dragon_gem':'7651','coins':'26',
 'ore':'379','leather':'366','cloth':'739','powder':'3732','gem':'254','recipe':'754',
 'arrow':'389','bullet':'75174'}

def read(path): return json.loads(path.read_text(encoding='utf-8'))
def digest(data): return hashlib.sha256(data).hexdigest()

def sources():
    catalog = {str(r['sourceId']):r for r in read(ROOT/'data/catalog_v19.json')['아이템']}
    candidates = read(ROOT/'data/visuals/runtime_manifest.json')['items']
    inven = {str(r['art_source']['id']):r for r in read(ROOT/'data/inven_inventory_icons.json')['items']}
    result = {k:{'source_path':'res://'+p,'source_name':n,'source_kind':'existing_floor_sprite'} for k,(p,n) in FLOOR.items()}
    ids = dict(IDS)
    for category,kind in [('shoulder','견갑'),('box','상자'),('material','상자'),('misc','상자')]:
        rows = [r for r in catalog.values() if r.get('type')==kind]
        if not rows: raise ValueError('missing representative kind: '+kind)
        ids[category] = min(rows,key=lambda r:int(r['sourceId']))['sourceId']
    for category,identity in ids.items():
        identity=str(identity); row=catalog.get(identity)
        if identity in candidates and (ROOT/candidates[identity]['path'].removeprefix('res://')).is_file():
            path=candidates[identity]['path']; name=candidates[identity]['name']; kind='existing_item_sprite'
        elif row is not None:
            path=row['image_path']; name=row['name']; kind='existing_inventory_image'
        elif identity in inven:
            value=inven[identity]; path=value['path']; name=value['art_source']['name']; kind='existing_inventory_image'
        else: raise ValueError('missing source for '+category+' / '+identity)
        result[category]={'source_path':path,'source_name':name,'source_kind':kind,'art_reference_id':identity}
    return result

def prepare(raw: bytes):
    with Image.open(io.BytesIO(raw)) as opened:
        if not 1<=opened.width<=512 or not 1<=opened.height<=512: raise ValueError('invalid source size')
        image=opened.convert('RGBA')
    image=clear_white_border(image)
    width,height=image.size; pixels=image.load()
    corners=[pixels[0,0],pixels[width-1,0],pixels[0,height-1],pixels[width-1,height-1]]
    white=sum(min(p[:3])>=250 for p in corners)>=3
    black=sum(max(p[:3])<=3 for p in corners)>=3
    # Only border-connected background is removed. Interior metal highlights,
    # inscriptions and all other source foreground pixels remain present.
    def background(x,y):
        p=pixels[x,y]
        return p[3]==0 or (white and min(p[:3])>=250) or (black and max(p[:3])<=3)
    queue=deque([(x,0) for x in range(width)]+[(x,height-1) for x in range(width)]+[(0,y) for y in range(height)]+[(width-1,y) for y in range(height)])
    seen=set()
    while queue:
        x,y=queue.popleft()
        if (x,y) in seen or not 0<=x<width or not 0<=y<height: continue
        seen.add((x,y))
        if not background(x,y): continue
        p=pixels[x,y];pixels[x,y]=(p[0],p[1],p[2],0)
        queue.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
    bounds=image.getchannel('A').getbbox()
    if bounds is None: raise ValueError('empty source icon')
    image=image.crop(bounds)
    scale=min(56/image.width,52/image.height)
    extent=(max(1,round(image.width*scale)),max(1,round(image.height*scale)))
    image=image.resize(extent,Image.Resampling.NEAREST)
    result=Image.new('RGBA',(64,64),(0,0,0,0))
    result.paste(image,((64-image.width)//2,58-image.height))
    out=io.BytesIO();result.save(out,format='PNG',compress_level=9)
    return out.getvalue(),list(bounds),list(extent)

def build(write=False):
    entries={}
    for key,source in sources().items():
        relative=source['source_path'].removeprefix('res://')
        if '..' in Path(relative).parts or not relative.startswith('assets/'): raise ValueError('unsafe source')
        raw=(ROOT/relative).read_bytes(); png,bounds,extent=prepare(raw)
        path='assets/ground_categories/'+key+'.png'
        entry={**source,'path':'res://'+path,'source_sha256':digest(raw),'sha256':digest(png),'size':[64,64],'source_crop':bounds,'draw_extent':extent}
        entries[key]=entry
        target=ROOT/path
        if write:
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(png)
        elif not target.is_file() or digest(target.read_bytes())!=entry['sha256']:
            raise ValueError('missing/modified representative: '+path)
    document={'schema':1,'scope':'ground_only','mapping':'Representative category, not original item identity','preparation':'Border-connected background alpha; aspect-preserving fit on 64px canvas. Original files unchanged.','categories':entries}
    if write: MANIFEST.write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    elif read(MANIFEST)!=document: raise ValueError('manifest is out of date')
    print('GROUND_ASSETS_OK',len(entries),'categories;',sum(r['source_kind']=='existing_floor_sprite' for r in entries.values()),'existing floor representatives')
    return document

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--write',action='store_true');args=p.parse_args();build(args.write)
