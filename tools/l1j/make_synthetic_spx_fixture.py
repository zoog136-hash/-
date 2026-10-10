#!/usr/bin/env python3
"""Create only small synthetic PNG frames for positive-path SPX runtime CI."""
from __future__ import annotations
import argparse, pathlib, struct, zlib

def rgba_png(r, g, b):
    w, h = 8, 8
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
    pixels = b''.join(b'\x00' + bytes([r,g,b,255])*w for _ in range(h))
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB',w,h,8,6,0,0,0)) + chunk(b'IDAT',zlib.compress(pixels)) + chunk(b'IEND',b'')

def build(root: pathlib.Path):
    for actor in ['21624','21653']:
        folder = root/'assets'/'external_spx'/'actors'/actor
        names = {}
        textures = []
        for role in ['idle','walk','attack','hit']:
            for direction in range(8):
                key = f'{role}_{direction}'
                names[key] = []
                for frame in range(2):
                    relative = f'assets/external_spx/actors/{actor}/{key}_{frame}.png'
                    path = root / relative
                    path.parent.mkdir(parents=True,exist_ok=True)
                    path.write_bytes(rgba_png(70+direction*19,120+frame*45,{'idle':60,'walk':90,'attack':150,'hit':205}[role]))
                    textures.append(relative)
                    names[key].append(str(len(textures)))
        lines = ['[gd_resource type="SpriteFrames" load_steps='+str(len(textures)+2)+' format=3]','']
        for i,relative in enumerate(textures,1):
            lines.append(f'[ext_resource type="Texture2D" path="res://{relative}" id="{i}"]')
        lines.extend(['','[resource]'])
        values = []
        for key,ids in names.items():
            frames = ', '.join('{"duration": 1.0, "texture": ExtResource("'+i+'")}' for i in ids)
            values.append('{"frames": ['+frames+'], "loop": true, "name": &"'+key+'", "speed": 9.0}')
        lines.append('animations = ['+',\n'.join(values)+']')
        (folder/'SpriteFrames.tres').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('SYNTHETIC_SPX_FIXTURE_OK 2 sprites 64 tracks 128 synthetic PNGs')

if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--root',type=pathlib.Path,default=pathlib.Path.cwd())
    a=p.parse_args()
    build(a.root)
