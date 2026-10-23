"""Compose explicit frozen base32 + N6 + SE/SW replacements, without art edits.

Each AtlasTexture body and each speed/loop/duration token is copied from its
selected input TRES. Only ExtResource/SubResource identifiers are renamed.
"""
import argparse
from copy import deepcopy
import hashlib,json,re
from pathlib import Path
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[6]
OUT=Path(__file__).resolve().parent
FOLDER=ROOT/'assets/actors/eight_direction/monster_boss_repair/ice_queen/combined-r002'
KEY='monster:얼음 여왕'
DIRS=['E','SE','S','SW','W','NW','N','NE']

def local(p):
    p=(ROOT/str(p).removeprefix('res://')).resolve();p.relative_to(ROOT);return p
def rel(p):return p.resolve().relative_to(ROOT).as_posix()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pin(p):return{'path':rel(p),'bytes':p.stat().st_size,'sha256':sha(p)}
def put(p,data):
    p.parent.mkdir(parents=True,exist_ok=True)
    if p.exists():assert p.read_bytes()==data,'Preserve existing revision: '+str(p)
    else:p.write_bytes(data)
def jb(v):return(json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode()
def numbers(value):
    values=[float(x.strip()) for x in value.split(',')]
    return [int(x) if x.is_integer() else x for x in values]

def parse_frames(path):
    text=path.read_text()
    ext={i:p for p,i in re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]',text)}
    atlas={}
    for i,body in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)',text,re.S):
        e=re.search(r'atlas = ExtResource\("([^"]+)"\)',body).group(1)
        region=numbers(re.search(r'region = Rect2\(([^)]+)\)',body).group(1))
        margin=numbers(re.search(r'margin = Rect2\(([^)]+)\)',body).group(1))
        atlas[i]={'ext':e,'texture':ext[e],'body':body,'region':region,'margin':margin}
    animations={}
    pattern=r'\{\s*"frames"\s*:\s*\[(.*?)\],\s*"loop"\s*:\s*(true|false),\s*"name"\s*:\s*&"([^"]+)",\s*"speed"\s*:\s*([^,}\s]+)\s*\}'
    for body,loop,name,speed in re.findall(pattern,text,re.S):
        rows=re.findall(r'\{\s*"duration"\s*:\s*([^,]+),\s*"texture"\s*:\s*SubResource\("([^"]+)"\)\s*\}',body)
        assert rows
        animations[name]={'loop_token':loop,'speed_token':speed,'frames':[{'duration_token':d.strip(),**deepcopy(atlas[i])} for d,i in rows]}
    assert len(animations)==text.count('"name":') or len(animations)==text.count('"name" :')
    return animations

def manifest(spec):
    p=local(spec['manifest']);assert sha(p)==spec['manifest_sha256']
    entries=json.loads(p.read_text())['files'];pinned={}
    for f in entries:
        member=local(f['path']);assert member.is_file() and sha(member)==f['sha256'],str(member)
        if 'bytes' in f:assert member.stat().st_size==f['bytes']
        pinned[rel(member)]=f
    candidate=local(spec['candidate']);assert rel(candidate) in pinned
    assert sha(candidate)==spec['candidate_sha256']
    value=json.loads(candidate.read_text());a=value['actors'][KEY]
    assert not a['production_connected'] and not a['detailed_completed']
    assert value['new_approvals']==value['default_catalog_switches']==0
    for field in ['frames','native_profile']:
        resource=local(a[field]);assert rel(resource) in pinned and sha(resource)==a[field+'_sha256']
    return a,{'candidate':pin(candidate),'manifest':pin(p),'files_verified':len(entries)}

def normalized_track(t):
    t=deepcopy(t)
    if 'geometry' not in t:
        assert t.get('mixed_source') and t.get('frame_sources')
        frames=[]
        for record in t['frame_sources']:
            f=deepcopy(record['source_geometry_frame'])
            f.update(source=record['source'],source_sha256=record['source_sha256'],texture=record['texture'],
                     canvas_size=record['source_canvas'],image_size=list(Image.open(local(record['texture'])).size))
            frames.append(f)
        t.update(source=frames[0]['source'],source_sha256=frames[0]['source_sha256'],texture=frames[0]['texture'],
                 geometry={'frames':frames,'canvas_size':frames[0]['canvas_size'],'image_size':frames[0]['image_size'],
                           'frame_canvas_sizes':[f['canvas_size'] for f in frames],
                           'per_frame_texture_source_and_canvas_override':True,'distinct_pixel_frames':len(frames)})
    return t

def compose(args):
    config=json.loads(local(args.inputs).read_text())
    assert set(config)=={'base','N','SE','SW'}
    selected={};tracks={};pins=[];profiles=[]
    for name,spec in config.items():
        actor,input_pin=manifest(spec);pins.append({'input':name,**input_pin})
        parsed=parse_frames(local(actor['frames']));profiles.append(local(actor['native_profile']).read_text())
        if name=='base':assert len(parsed)==32 and 'run_6' not in parsed
        expected=None if name=='base' else {'N':{'run_6'},'SE':{'attack_1'},'SW':{'attack_3'}}[name]
        if expected is not None:assert set(parsed)==expected
        for raw in actor['tracks']:
            t=normalized_track(raw);key=t['animation'];assert key in parsed
            if name=='base':assert key not in selected
            selected[key]=deepcopy(parsed[key]);tracks[key]=t
            t['selected_frozen_input']=name
            t['selected_input_SpriteFrames_pin']=pin(local(actor['frames']))
    required={f'{r}_{i}' for r in ['idle','run','attack','hit'] for i in range(8)}|{'death_2'}
    assert set(selected)==set(tracks)==required and len(selected)==33
    base_profile=profiles[0]
    for text in profiles:
        scale=float(re.search(r'^pixel_scale = (.+)$',text,re.M).group(1));assert abs(scale-86/140)<1e-9
        offset=numbers(re.search(r'^sprite_offset = Vector2\(([^)]+)\)',text,re.M).group(1))
        assert abs(offset[0])<1e-9 and abs(offset[1]+32*scale)<1e-9
        assert re.search(r'^attack_hit_frame = 1$',text,re.M)
    images={};source_hashes={};all_rgba=[];checks=[]
    for key in sorted(tracks):
        t=tracks[key];animation=selected[key];assert len(t['geometry']['frames'])==len(animation['frames'])
        for phase,(f,actual) in enumerate(zip(t['geometry']['frames'],animation['frames'])):
            source=local(f.get('source',t['source']));texture=local(f.get('texture',t['texture']))
            expected_sha=f.get('source_sha256',t['source_sha256'])
            if rel(source) not in source_hashes:source_hashes[rel(source)]=sha(source)
            assert source_hashes[rel(source)]==expected_sha and source.read_bytes()==texture.read_bytes()
            assert rel(texture)==rel(local(actual['texture']))
            assert f['region']==actual['region'] and f['margin']==actual['margin']
            x,y,w,h=actual['region'];mx,my,mw,mh=actual['margin'];canvas=[w+mw,h+mh]
            assert f.get('canvas_size',t['geometry']['canvas_size'])==canvas
            assert min(mx,my)>=0 and mx+w<=canvas[0] and my+h<=canvas[1]
            if rel(texture) not in images:images[rel(texture)]=np.asarray(Image.open(texture).convert('RGBA'))
            pixels=images[rel(texture)];assert x>=0 and y>=0 and x+w<=pixels.shape[1] and y+h<=pixels.shape[0]
            digest=hashlib.sha256(pixels[y:y+h,x:x+w].tobytes()).hexdigest();assert digest==f['rgba_sha256']
            all_rgba.append(digest)
            f.update(row=phase,source=rel(source),source_sha256=expected_sha,texture=rel(texture),canvas_size=canvas,
                     duration=float(actual['duration_token']))
        t.update(animation_fps=float(animation['speed_token']),loop=animation['loop_token']=='true',
                 frame_durations=[float(f['duration_token']) for f in animation['frames']])
        checks.append({'animation':key,'frames':len(animation['frames']),'FPS':t['animation_fps'],'loop':t['loop'],
                       'frame_durations':t['frame_durations'],'all_AtlasTexture_source_region_margin_and_RGBA':'PASS'})
    assert len(all_rgba)==len(set(all_rgba))==108
    order=sorted(tracks,key=lambda k:(['idle','run','attack','hit','death'].index(k.rsplit('_',1)[0]),int(k.rsplit('_',1)[1])))
    textures=list(dict.fromkeys(f['texture'] for key in order for f in selected[key]['frames']))
    lines=[f'[gd_resource type="SpriteFrames" load_steps={108+len(textures)+1} format=3]']
    for i,texture in enumerate(textures):lines+=['',f'[ext_resource type="Texture2D" path="{texture}" id="T{i}"]']
    animations=[]
    for ti,key in enumerate(order):
        animation=selected[key];frame_tokens=[]
        for fi,frame in enumerate(animation['frames']):
            new_id=f'A{ti}_{fi}';ext='T'+str(textures.index(frame['texture']))
            body=frame['body'].replace('ExtResource("'+frame['ext']+'")','ExtResource("'+ext+'")')
            lines+=['',f'[sub_resource type="AtlasTexture" id="{new_id}"]',body.rstrip()]
            frame_tokens.append('{"duration": '+frame['duration_token']+', "texture": SubResource("'+new_id+'")}')
        animations.append('{"frames": ['+',\n'.join(frame_tokens)+'], "loop": '+animation['loop_token']+', "name": &"'+key+'", "speed": '+animation['speed_token']+'}')
    lines+=['','[resource]','animations = [\n'+',\n'.join(animations)+'\n]',
            'metadata/twilight_canvas_size = Vector2(256, 256)','metadata/twilight_native_locomotion_staging = true',
            'metadata/twilight_production_connected = false','metadata/twilight_detailed_completed = false','']
    frames_path=FOLDER/'SpriteFrames.tres';profile_path=FOLDER/'NativeMotionProfile.tres'
    frames_data='\n'.join(lines).encode()
    base_actor=json.loads(local(config['base']['candidate']).read_text())['actors'][KEY]
    old='frames_path = "'+base_actor['frames']+'"';new='frames_path = "res://'+rel(frames_path)+'"'
    assert base_profile.count(old)==1
    profile_data=base_profile.replace(old,new).encode();assert profile_data.decode().replace(new,old)==base_profile
    actor={'kind':'boss','quality_tier':'mythic_transform','frames':'res://'+rel(frames_path),'frames_sha256':hashlib.sha256(frames_data).hexdigest(),
           'native_profile':'res://'+rel(profile_path),'native_profile_sha256':hashlib.sha256(profile_data).hexdigest(),
           'native_track_count':33,'native_pose_count':108,'missing_required_tracks':[],
           'production_connected':False,'detailed_completed':False,
           'quality_review':'HOLD: complete technical33-track candidate; preserved source QA limits, full timed gait/contact/mythic acceptance not promoted by composition',
           'tracks':[tracks[k] for k in order],'sizing':{'ONE_pixel_scale':86/140,'per_AtlasTexture_source_and_virtual_canvas_preserved':True,'source_pixels_resampled':False}}
    candidate={'schema':'pr122-queen-combined-r002-frozen-input-union-v1','actors':{KEY:actor},'new_approvals':0,'default_catalog_switches':0,
               'new_source_PNGs_from_composition':0,'new_poses_generated_by_composition':0,'source_poses_referenced':108,
               'N_new_source_poses':3,'N_reused_correct_source_poses':3,'SE_replacement_poses':3,'SW_replacement_poses':3,
               'old_reversed_N_source_slots2_3_5_connected':False,'existing_approved_assets_and_frozen_inputs_preserved':True,
               'input_pins':pins,'all_input_AtlasTexture_and_timing_checks':checks}
    if args.apply:
        put(frames_path,frames_data);put(profile_path,profile_data);put(OUT/'candidate.json',jb(candidate))
        reconstructed=parse_frames(frames_path)
        for key in order:
            old_animation=selected[key];new_animation=reconstructed[key]
            assert old_animation['loop_token']==new_animation['loop_token'] and old_animation['speed_token']==new_animation['speed_token']
            for old_frame,new_frame in zip(old_animation['frames'],new_animation['frames']):
                assert all(old_frame[k]==new_frame[k] for k in ['texture','region','margin','duration_token'])
        put(OUT/'composition-verification.json',jb({'native_tracks':33,'unique_RGBA_source_poses':108,'missing_required_tracks':[],
            'all_input_manifests_verified':True,'source_PNG_RGBA_region_margin_order_timing_preserved':True,
            'N_per_frame_canvases':[f['canvas_size'] for f in tracks['run_6']['geometry']['frames']],
            'SW_per_frame_canvases':[f['canvas_size'] for f in tracks['attack_3']['geometry']['frames']],
            'base_profile_only_frames_path_changed':True,'new_approvals':0,'inputs':pins,'checks':checks}))
    print(json.dumps({'mode':'written' if args.apply else 'read_only_verified','clips':33,'poses':108,'missing':[],
                      'new_pixels_from_composition':0,'candidate':rel(OUT/'candidate.json'),'new_approvals':0}))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--inputs',required=True);parser.add_argument('--apply',action='store_true')
    compose(parser.parse_args())
