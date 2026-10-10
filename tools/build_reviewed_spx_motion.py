#!/usr/bin/env python3
"""Build complete reviewed body tracks from restored, pixel-verified SPX frames.

Physical sequence bases below were reviewed as six-frame motion contact sheets.
They are not calculated from L1J logical action IDs. The two bodies remain
optional appearances; no class or transformation identity is invented.
"""
import argparse, hashlib, json, pathlib
from PIL import Image, ImageDraw

ACTORS={
 '21624': {'idle':16,'walk':0,'attack':8,'hit':24,
    'idle_largesword':40,'walk_largesword':32,'attack_largesword':48,'hit_largesword':56,
    'idle_onehand':16,'walk_onehand':0,'attack_onehand':8,'hit_onehand':24,
    'idle_axe':80,'walk_axe':64,'attack_axe':72,'hit_axe':88,
    'idle_unarmed':104,'walk_unarmed':96,'attack_unarmed':112,'hit_unarmed':120,
    'idle_chain':128,'walk_chain':136,'attack_chain':144,'hit_chain':160,'special_chain':152,
    'cast':176,'cast_nondirectional':168,'death':184,'special':192,'special_kick':200},
 '21653': {'idle':0,'walk':8,'attack':16,'hit':24,
    'idle_largesword':0,'walk_largesword':8,'attack_largesword':16,'hit_largesword':24,
    'idle_onehand':32,'walk_onehand':40,'attack_onehand':48,'hit_onehand':56,
    'idle_axe':64,'walk_axe':72,'attack_axe':80,'hit_axe':88,
    'idle_unarmed':96,'walk_unarmed':104,'attack_unarmed':112,'hit_unarmed':120,
    'idle_chain':128,'walk_chain':136,'attack_chain':144,'hit_chain':160,'special_chain':152,
    'cast':176,'cast_nondirectional':168,'death':184,'special':192,'special_kick':200}}
FPS={'idle':7.0,'walk':12.0,'attack':13.0,'hit':12.0,'cast':14.0,'death':16.0,'special':12.0}

def resource(mapping, placements, size):
    files=list(dict.fromkeys(p for paths in mapping.values() for p in paths)); indices={p:str(i) for i,p in enumerate(files,1)}
    lines=[f'[gd_resource type="SpriteFrames" load_steps={len(files)*2+1} format=3]','']
    lines += [f'[ext_resource type="Texture2D" path="res://{p}" id="{i}"]' for p,i in indices.items()]
    for path,index in indices.items():
        x,y,w,h=placements[path]
        lines += ['',f'[sub_resource type="AtlasTexture" id="Frame_{index}"]',f'atlas = ExtResource("{index}")',
            f'region = Rect2(0, 0, {w}, {h})',f'margin = Rect2({x}, {y}, {size[0]-w}, {size[1]-h})']
    animations=[]
    for name,paths in mapping.items():
        role=name.split('_')[0]; track=', '.join('{"duration":1.0,"texture":SubResource("Frame_'+indices[p]+'")}' for p in paths)
        animations.append('{"frames":['+track+'],"loop":'+('true' if role in ('idle','walk') else 'false')+',"name":&"'+name+'","speed":'+str(FPS[role])+'}')
    lines+=['','[resource]','animations = ['+',\n'.join(animations)+']']
    return '\n'.join(lines)+'\n'

def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--root',type=pathlib.Path,required=True);p.add_argument('--report',type=pathlib.Path,required=True);a=p.parse_args()
    source=a.root/'assets/l1j/candidates/spx_converted'; manifest={'schema':1,'source':'restored source SPX, pixel hashes revalidated',
        'optional_external_art':True,'not_for_public_redistribution':True,'direction_order':'E SE S SW W NW N NE','actors':{}}
    for body,bases in ACTORS.items():
        metas={seq:json.loads((source/f'{body}-{seq}'/'frame_metadata.json').read_text()) for seq in range(208)}
        effects={seq:json.loads((source/f'{int(body)+2}-{seq}'/'frame_metadata.json').read_text()) for seq in range(208)}
        combined=[*metas.values(),*effects.values()]
        left=min(m['source_origin'][0] for m in combined); top=min(m['source_origin'][1] for m in combined)
        right=max(m['source_origin'][0]+m['canvas_size'][0] for m in combined); bottom=max(m['source_origin'][1]+m['canvas_size'][1] for m in combined)
        size=(right-left,bottom-top); dest=a.root/'assets/external_spx/actors'/body;dest.mkdir(parents=True,exist_ok=True)
        counts={};mappings={};gpu_pixels={}
        for layer,source_metas in [('body',metas),('effects',effects)]:
            paths={};placements={};total=0;pixels=0
            for seq,m in source_metas.items():
                if len(m['frames'])!=len(metas[seq]['frames']):raise ValueError('layer/body frame count mismatch')
                tracks=[]
                for i,f in enumerate(m['frames']):
                    im=Image.open(a.root/f['path'].removeprefix('res://')).convert('RGBA')
                    if hashlib.sha256(im.tobytes()).hexdigest()!=f['pixel_sha256']:raise ValueError('source pixels changed '+f['path'])
                    box=im.getchannel('A').getbbox()
                    if box is None: box=(0,0,1,1)
                    cropped=im.crop(box)
                    relative=f'assets/external_spx/actors/{body}/'+('effects/' if layer=='effects' else '')+f'sequence_{seq}/frame_{i:03}.png'
                    path=a.root/relative;path.parent.mkdir(parents=True,exist_ok=True);cropped.save(path,optimize=True)
                    placements[relative]=(m['source_origin'][0]+box[0]-left,m['source_origin'][1]+box[1]-top,cropped.width,cropped.height)
                    tracks.append(relative);total+=1;pixels+=cropped.width*cropped.height
                paths[seq]=tracks
            mapping={f'{role}_{direction}':paths[base+(6-direction)%8] for role,base in bases.items() for direction in range(8)}
            (dest/('SpriteFrames.tres' if layer=='body' else 'EffectsFrames.tres')).write_text(resource(mapping,placements,size))
            counts[layer]=total;mappings[layer]=mapping;gpu_pixels[layer]=pixels
        total=counts['body'];mapping=mappings['body']
        # Source coordinate (72, 30) lies at the established body's foot pivot.
        # Preserve the same origin across motion, weapons, casting and death.
        idle_meta=metas[bases['idle']+4];body_height=max(f['alpha_bbox'][3]-f['alpha_bbox'][1] for f in idle_meta['frames'] if f['alpha_bbox'])
        manifest['actors'][body]={'sprite_id':body,'canvas':list(size),'source_origin':[left,top],
            'foot_pixel':[72-left,30-top],'reference_body_height':body_height,'frames':total,'sequences':208,
            'effect_source_id':str(int(body)+2),'effect_frames':counts['effects'],'effects_blend':'additive, source black background is zero light',
            'gpu_rgba_bytes_estimate':4*sum(gpu_pixels.values()),'padding':'virtual AtlasTexture margins, exact source-origin alignment',
            'action_bases':bases,'tracks':len(mapping),'directions':8,'semantic_review':'all 26 physical groups reviewed, source art preserved',
            'run':'no separate verified source run; game falls back to source walk',
            'unavailable_weapon_tracks':['bow','rifle','spear','shuriken'],'class_identity':'UNMAPPED'}
        direction_sheet=Image.new('RGB',(8*144,170),(23,29,36));draw=ImageDraw.Draw(direction_sheet)
        for d,label in enumerate(('E','SE','S','SW','W','NW','N','NE')):
            im=Image.open(a.root/mapping[f'idle_{d}'][0]).convert('RGBA');im.thumbnail((144,144),Image.Resampling.LANCZOS)
            direction_sheet.paste(im,(d*144+(144-im.width)//2,20),im);draw.text((d*144+60,3),label,fill='white')
        a.report.mkdir(parents=True,exist_ok=True);direction_sheet.save(a.report/f'{body}_direction_review.png')
    path=a.root/'data/external_spx/actors_manifest.json';path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    (a.report/'reviewed_actor_tracks.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('REVIEWED_SPX_TRACKS_OK',json.dumps({k:{'frames':v['frames'],'tracks':v['tracks']} for k,v in manifest['actors'].items()}),flush=True)

if __name__=='__main__':main()
