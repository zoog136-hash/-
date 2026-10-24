"""Compile new generated materials/sprites at reviewed PNG-world coordinates.

No old PNG pixels, A3 coordinates, navigation changes or automatic terrain
classification are inputs. Reuses the existing lossless chunk compiler.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps
from build_native_png_maps import compile_chunks, digest, write

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/maps/aden_modular_pilot'


def tile(material, size):
    # Mirrored material repeats meet at identical edge pixels. This only
    # orients material texture; directional object sprites are separate.
    w, h = material.size
    periodic = Image.new('RGBA', (w*2, h*2))
    periodic.paste(material, (0, 0))
    periodic.paste(ImageOps.mirror(material), (w, 0))
    periodic.paste(ImageOps.flip(material), (0, h))
    periodic.paste(ImageOps.flip(ImageOps.mirror(material)), (w, h))
    result = Image.new('RGBA', size)
    for y in range(0, size[1], h*2):
        for x in range(0, size[0], w*2):
            result.paste(periodic, (x, y))
    return result


def compile_pilot(base=BASE):
    BASE = base
    layout = json.loads((BASE/'layout.json').read_text())
    x0,y0,width,height = layout['world_bounds']
    origin = layout['source_origin']
    def point(p): return [round((p[0]-origin[0])*6), round((p[1]-origin[1])*6)]
    source_root = ROOT / layout.get('source_root', str(BASE.relative_to(ROOT) / 'source'))
    materials = Image.open(source_root/'materials.png').convert('RGBA')
    hw,hh = materials.width//2,materials.height//2
    tiles = {}
    for name,(x,y) in dict(stone=(0,0),grass=(1,0),water=(0,1),dirt=(1,1)).items():
        tiles[name] = materials.crop((x*hw,y*hh,(x+1)*hw,(y+1)*hh)).resize((256,256),Image.Resampling.LANCZOS)
    tiles['stone'] = Image.open(source_root/'paving.png').convert('RGBA').resize((512,512),Image.Resampling.LANCZOS)
    ground = tile(tiles['stone'],(width,height))
    for row in layout['terrain']:
        mask = Image.new('L',ground.size)
        ImageDraw.Draw(mask).polygon([tuple(point(p)) for p in row['polygon']],fill=255)
        ground.paste(tile(tiles[row['material']],ground.size),(0,0),mask)
    atlas=Image.open(source_root/'objects.png').convert('RGBA')
    # Actual generated atlas cells were visually inspected; objects are not
    # assumed to obey the requested 512px grid.
    boxes={'fountain':(0,0,550,460),'hedge':(550,0,1008,460),'bed':(1008,0,1536,460),
           'wall':(0,460,550,1024),'gate':(550,460,1008,1024),'tree':(1008,460,1536,1024)}
    sprites={}
    for name,box in boxes.items():
        sprite=atlas.crop(box)
        # Ignore only sub-visible generation padding when finding crop bounds;
        # preserve all original alpha values inside the retained bounds.
        visible=sprite.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox()
        if visible is None:raise ValueError('Empty generated sprite '+name)
        sprites[name]=sprite.crop(visible)
    palace=Image.open(source_root/'palace.png').convert('RGBA')
    sprites['palace']=palace.crop(palace.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox())
    sprites['wall_reverse']=ImageOps.mirror(sprites['wall'])
    for name, spec in layout.get('additional_sprites', {}).items():
        sheet = Image.open(ROOT/spec['file']).convert('RGBA')
        sprite = sheet.crop(tuple(spec['crop']))
        bounds = sprite.getchannel('A').point(lambda a:255 if a>=16 else 0).getbbox()
        assert bounds, name
        sprites[name] = sprite.crop(bounds)
    out=BASE/'compiled';out.mkdir(exist_ok=True)
    chunks=compile_chunks(ground,[0,0,width,height],out/'ground',512)
    composite=ground.copy();records=[];cache={}
    for row in sorted(layout['placements'],key=lambda r:point(r['source_anchor'])[1]):
        key=(row['asset'],row['width']);source=sprites[key[0]]
        if key[1]>source.width:raise ValueError('Upscaling generated sprite forbidden: '+str(key))
        if key not in cache:
            size=(key[1],round(source.height*key[1]/source.width))
            sprite=source.resize(size,Image.Resampling.LANCZOS)
            name=f'{key[0]}-{key[1]}.png';sprite.save(out/name);cache[key]=(sprite,name)
        sprite,name=cache[key];foot=point(row['source_anchor'])
        pivot=[round(row['foot_uv'][0]*sprite.width),round(row['foot_uv'][1]*sprite.height)]
        position=[foot[0]-pivot[0],foot[1]-pivot[1]]
        composite.alpha_composite(sprite,tuple(position))
        records.append(dict(id=row['id'],file=name,position=position,foot=foot,size=list(sprite.size),sha256=digest(out/name)))
    full_name=layout.get('full_png','palace_gardens_3072x2048.png')
    if layout.get('export_full_png',True):composite.save(out/full_name)
    for panel in layout.get('panels',[]):
        composite.crop(tuple(panel['rect'])).save(out/panel['file'])
    # Reconstruct all written ground chunks before accepting the compilation.
    restored=Image.new('RGBA',ground.size)
    for row in chunks:restored.paste(Image.open(out/'ground'/row['file']),tuple(row['position']))
    assert restored.tobytes()==ground.tobytes(), 'Ground seam/ownership mismatch'
    for row in records:restored.alpha_composite(Image.open(out/row['file']),tuple(row['position']))
    assert restored.tobytes()==composite.tobytes(), 'Ground/foreground reconstruction mismatch'
    report=dict(schema=1,world_bounds=layout['world_bounds'],source_origin=origin,source_scale=6,
                image_pixels_per_world_unit=1,ground_chunks=chunks,foreground=records,
                full_png=full_name if layout.get('export_full_png',True) else None,full_png_sha256=digest(out/full_name) if layout.get('export_full_png',True) else None,
                layout_sha256=digest(BASE/'layout.json'),source_assets={p.name:digest(p) for p in sorted(source_root.glob('*.png'))},
                additional_source_assets={spec['file']:digest(ROOT/spec['file']) for spec in layout.get('additional_sprites',{}).values()},
                panels=layout.get('panels',[]),
                ground_rgba_bytes=width*height*4,unique_foreground_rgba_bytes=sum(s.width*s.height*4 for s,n in cache.values()),
                ground_chunk_roundtrip=True,composite_roundtrip=True,navigation_modified=False,
                placement_count=len(records),source_art_upscaled=False)
    write(out/'manifest.json',report)
    print(json.dumps({k:v for k,v in report.items() if k not in ['ground_chunks','foreground']}))

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser()
    parser.add_argument('--base',type=Path,default=BASE)
    compile_pilot(parser.parse_args().base.resolve())
