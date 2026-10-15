#!/usr/bin/env python3
"""Bake alpha-only copies of legacy dedicated floor PNGs, preserving sources."""
from __future__ import annotations
import argparse, hashlib, io, json, sys
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools/ground_icons'))
from alpha import clear_white_border
MANIFEST = ROOT/'data/ground_alpha.json'

def sha(raw: bytes) -> str: return hashlib.sha256(raw).hexdigest()
def png(image: Image.Image) -> bytes:
    output = io.BytesIO(); image.save(output, format='PNG', compress_level=9); return output.getvalue()

def build(write: bool = False) -> dict:
    rows = {}
    paths = sorted(list((ROOT/'assets/l1j/verified/ground').glob('*.png')) + list((ROOT/'assets/original_items/ground').glob('*.png')))
    if not paths: raise ValueError('No dedicated ground sources')
    for source in paths:
        raw = source.read_bytes()
        with Image.open(io.BytesIO(raw)) as opened: original = opened.convert('RGBA')
        cleaned = clear_white_border(original)
        removed = 0
        for before, after in zip(original.getdata(), cleaned.getdata()):
            if before != after:
                if after[:3] != before[:3] or after[3] != 0 or min(before[:3]) < 250:
                    raise ValueError('A foreground pixel was altered: '+str(source))
                if before[3] > 0: removed += 1
        if cleaned.getchannel('A').getbbox() is None:
            raise ValueError('Empty foreground: '+str(source))
        key = 'res://'+source.relative_to(ROOT).as_posix()
        target = ROOT/'assets/ground_alpha'/f'{source.stem}_{sha(key.encode())[:12]}.png'
        payload = png(cleaned)
        row = {'source_path':key,'path':'res://'+target.relative_to(ROOT).as_posix(),
            'source_sha256':sha(raw),'source_rgba_sha256':sha(original.tobytes()),
            'sha256':sha(payload),'size':list(original.size),'removed_white_pixels':removed,
            'foreground_pixels':sum(p[3]>0 for p in cleaned.getdata())}
        if write:
            target.parent.mkdir(parents=True, exist_ok=True);target.write_bytes(payload)
        elif not target.exists() or target.read_bytes() != payload:
            raise ValueError('Missing/stale floor cutout: '+str(target))
        rows[key] = row
    result = {'schema':1,'scope':'ground_display_only','transform':'exterior_connected_white_alpha_8_neighbors',
        'source_pixels_preserved':True,'same_dimensions':True,'images':rows}
    if write: MANIFEST.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    elif json.loads(MANIFEST.read_text(encoding='utf-8')) != result:
        raise ValueError('Ground alpha manifest mismatch')
    print('GROUND_ALPHA_ASSETS_OK',json.dumps({'images':len(rows),'changed':sum(v['removed_white_pixels']>0 for v in rows.values()),'removed_white_pixels':sum(v['removed_white_pixels'] for v in rows.values())}),flush=True)
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--write',action='store_true');args=parser.parse_args();build(args.write)
