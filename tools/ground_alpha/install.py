#!/usr/bin/env python3
"""One-time exact-baseline edit; runtime changes are committed after tests only."""
from pathlib import Path
import hashlib

def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
p=Path('tools/ground_icons/build.py');s=p.read_text()
if 'from alpha import clear_white_border' not in s:
    assert blob(p.read_bytes())=='88fe5c98b4026e4eb7689b7f10fe89a591b5ec87','build.py changed; review required'
    s=s.replace('from PIL import Image\n','from PIL import Image\nfrom alpha import clear_white_border\n',1)
    s=s.replace("    width,height=image.size; pixels=image.load()","    image=clear_white_border(image)\n    width,height=image.size; pixels=image.load()",1)
    assert 'image=clear_white_border(image)' in s;p.write_text(s)
p=Path('scripts/loot/drop_visual.gd');s=p.read_text()
if 'const FLOOR_ALPHA' not in s:
    assert blob(p.read_bytes())=='e2212353f4d0eed898d500264ef6fb5343817078','drop_visual changed; review required'
    s=s.replace('class_name TwilightDropVisual\n','class_name TwilightDropVisual\nconst FLOOR_ALPHA = preload("res://scripts/ui/ground_alpha.gd")\n',1)
    assert s.count('\ttexture = icon\n')==1;s=s.replace('\ttexture = icon\n','\ttexture = FLOOR_ALPHA.texture(icon)\n',1)
    p.write_text(s)
print('GROUND_ALPHA_INSTALLED')
