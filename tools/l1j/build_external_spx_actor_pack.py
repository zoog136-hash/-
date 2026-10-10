#!/usr/bin/env python3
"""Reproducible local-only A2 SPX -> Godot SpriteFrames resource pack builder.

Requires the user's a2(1).zip, Pillow and NumPy. Does NOT execute code from
the source ZIP. Generated third-party graphics are never committed to GitHub.
"""
from __future__ import annotations
import argparse, hashlib, io, json, pathlib, zipfile
from PIL import Image
from spx_decode import decode_spx

SOURCE_PATCH = 'appcenter/connector/patch/patch_1.zip'
PREFIX = 'assets/external_spx/actors'
ACTORS = {
    '21624': {'walk': 0, 'attack': 8, 'idle': 16, 'hit': 24},
    '21653': {'idle': 0, 'walk': 8, 'attack': 16, 'hit': 24},
}
FPS = {'idle': 7.0, 'walk': 12.0, 'attack': 13.0, 'hit': 12.0}

def make_resource(mapping: dict[str, list[str]]) -> str:
    all_files = [p for paths in mapping.values() for p in paths]
    indices = {p: str(i) for i,p in enumerate(all_files,1)}
    lines = ['[gd_resource type="SpriteFrames" load_steps='+str(len(all_files)+2)+' format=3]', '']
    for path,index in indices.items():
        lines.append(f'[ext_resource type="Texture2D" path="res://{path}" id="{index}"]')
    lines += ['', '[resource]']
    animations = []
    for name, paths in mapping.items():
        role = name.split('_',1)[0]
        frames = ', '.join('{"duration": 1.0, "texture": ExtResource("'+indices[path]+'")}' for path in paths)
        looping = 'true' if role in ['idle','walk'] else 'false'
        animations.append('{"frames": ['+frames+'], "loop": '+looping+', "name": &"'+name+'", "speed": '+str(FPS[role])+'}')
    lines.append('animations = ['+',\n'.join(animations)+']')
    return '\n'.join(lines)+'\n'

def generate(source: pathlib.Path, target: pathlib.Path) -> dict:
    if not source.is_file(): raise FileNotFoundError(source)
    with zipfile.ZipFile(source) as outer:
        patch = outer.read(SOURCE_PATCH)
    with zipfile.ZipFile(io.BytesIO(patch)) as archive:
        names = set(archive.namelist())
        actors = {}
        for actor_id, actions in ACTORS.items():
            tracks = {}
            size = [0,0]
            for role, start in actions.items():
                for direction in range(8):
                    # Game direction is E,SE,S,SW,W,NW,N,NE; SPX source is N,NW,W,SW,S,SE,E,NE.
                    source_dir = (6-direction) % 8
                    seq = start + source_dir
                    member = f'sprite/{actor_id}-{seq}.spx'
                    if member not in names: raise ValueError('missing source sequence '+member)
                    frames = decode_spx(archive.read(member),max_pixels_per_frame=3_000_000,max_frames=40)
                    if len(frames)<2 or any(image is None for _,image in frames):
                        raise ValueError('empty or short sequence '+member)
                    tracks[f'{role}_{direction}'] = frames
                    for _,image in frames:
                        size[0]=max(size[0],image.width)
                        size[1]=max(size[1],image.height)
            if max(size)>512: raise ValueError('unusually large actor canvas '+str(size))
            actors[actor_id] = (tracks,size)
    manifest = {'schema':1,'source':'local a2(1).zip/patch_1.zip',
                'directions':'E SE S SW W NW N NE', 'optional_external_art':True,
                'third_party_art_not_committed':True,'actors':{}}
    target.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=7) as output:
        for actor_id,(tracks,size) in actors.items():
            mapping = {}
            total = 0
            for name,frames in tracks.items():
                mapping[name] = []
                for i,(_,image) in enumerate(frames):
                    rgba = Image.new('RGBA',tuple(size),(0,0,0,0))
                    rgba.alpha_composite(image,((size[0]-image.width)//2,size[1]-image.height))
                    with io.BytesIO() as buf:
                        rgba.save(buf,'PNG',optimize=True)
                        payload = buf.getvalue()
                    path = f'{PREFIX}/{actor_id}/{name}/frame_{i:03}.png'
                    output.writestr(path,payload)
                    mapping[name].append(path)
                    total += 1
            output.writestr(f'{PREFIX}/{actor_id}/SpriteFrames.tres',make_resource(mapping))
            manifest['actors'][actor_id] = {'frames':total,'sequences':32,'canvas':size,
                                            'action_bases':ACTORS[actor_id]}
        output.writestr('data/external_spx/actors_manifest.json',
                        json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
        output.writestr('EXTERNAL_SPX_README.txt',
                        'Optional visual-only SPX pack: extract assets/ and data/ into Godot project root.\n'
                        'Run Godot editor to import. Choose 21624 or 21653 in TWILIGHT Settings.\n'
                        'No combat/stat/save changes. Third-party art: confirm redistribution rights.\n')
    with zipfile.ZipFile(target) as verify:
        bad = verify.testzip()
        if bad: raise ValueError('bad CRC '+bad)
        all_names = set(verify.namelist())
        for id in ACTORS:
            resource = verify.read(f'{PREFIX}/{id}/SpriteFrames.tres').decode()
            for role in ['idle','walk','attack','hit']:
                for direction in range(8):
                    name = f'{role}_{direction}'
                    if f'"name": &"{name}"' not in resource:
                        raise ValueError('missing '+id+'/'+name)
            if resource.count('ExtResource("') != manifest['actors'][id]['frames']:
                raise ValueError('incomplete SpriteFrames '+id)
            if any(path not in all_names for path in
                   [f'{PREFIX}/{id}/SpriteFrames.tres']):
                raise ValueError('unpack missing '+id)
    print(json.dumps({'output':str(target),'bytes':target.stat().st_size,
                      'actors':manifest['actors'],
                      'sha256':hashlib.sha256(target.read_bytes()).hexdigest()},ensure_ascii=False))
    return manifest

if __name__ == '__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--source',type=pathlib.Path,required=True)
    p.add_argument('--output',type=pathlib.Path,required=True)
    a=p.parse_args()
    generate(a.source,a.output)
