from pathlib import Path
from PIL import Image
import re, json, hashlib
REPO=Path('/workspace/twilight')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def js_sha(o):return hashlib.sha256(json.dumps(o,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def nums(s): return [float(x) if '.' in x else int(x) for x in s.split(', ')]
def parse(frames_path,profile_path,registry_path):
    frames_path=Path(frames_path);profile_path=Path(profile_path)
    raw=frames_path.read_text();pr=profile_path.read_text();reg=json.load(open(registry_path))['actors']['transform:267']
    ext={i:REPO/p.removeprefix('res://') for p,i in re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]',raw)}
    sub={}
    for sid,body in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[)',raw,re.S):
        eid=re.search(r'atlas = ExtResource\("([^\"]+)"\)',body)[1]
        sub[sid]={'texture':str(ext[eid]),'region':nums(re.search(r'region = Rect2\(([^)]+)\)',body)[1]),'margin':nums(re.search(r'margin = Rect2\(([^)]+)\)',body)[1])}
    animations=[]
    for f,loop,name,speed in re.findall(r'\{"frames": \[(.*?)\], "loop": (true|false), "name": &"([^"]+)", "speed": ([\d.]+)\}',raw,re.S):
        animations.append({'name':name,'loop':loop=='true','speed':float(speed),'frames':[dict(sub[sid],duration=float(d)) for d,sid in re.findall(r'\{"duration": ([\d.]+), "texture": SubResource\("([^\"]+)"\)\}',f)]})
    profile={'pixel_scale':float(re.search(r'^pixel_scale = ([\d.]+)',pr,re.M)[1]),'sprite_offset':nums(re.search(r'^sprite_offset = Vector2\(([^)]+)\)',pr,re.M)[1]),'reference_canvas':nums(re.search(r'metadata/twilight_canvas_size = Vector2\(([^)]+)\)',raw)[1])}
    imgs={};tracks=[]
    byname={a['name']:a for a in animations}
    for t in reg['tracks']:
        a=byname[t['animation']];s=REPO/t['source'];tx=REPO/t['texture'];im=imgs.setdefault(str(tx),Image.open(tx).convert('RGBA'));s_sha=sha(s);t_sha=sha(tx);poses=[]
        for n,(f,g) in enumerate(zip(a['frames'],t['geometry']['frames'])):
            x,y,w,h=f['region'];mx,my,mw,mh=f['margin'];C=[w+mw,h+mh];root=[x+C[0]*.5-mx,y+C[1]*.625-my]
            crop=im.crop((x,y,x+w,y+h));rgba=hashlib.sha256(crop.tobytes()).hexdigest();bbox=crop.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox();factor=profile['pixel_scale']*profile['reference_canvas'][0]/C[0]
            effective={'texture':str(tx),'source_sha256':s_sha,'texture_sha256':t_sha,'region':f['region'],'margin':f['margin'],'canvas_size':C,'source_anchor':root,'rgba_sha256':rgba,'world_factor':factor,'world_alpha16_bounds':[(bbox[0]+x-root[0])*factor,(bbox[1]+y-root[1])*factor,(bbox[2]+x-root[0])*factor,(bbox[3]+y-root[1])*factor],'duration':f['duration']}
            effective['registry_geometry_equal']=f['region']==g['region'] and f['margin']==g['margin'] and rgba==g['rgba_sha256'] and root==g['source_anchor'] and C==g.get('canvas_size',t['geometry']['canvas_size'])
            poses.append(effective)
        selection={'direction':t['direction'],'role':t['role'],'animation':a['name'],'source_sha256':s_sha,'source':str(s),'texture':str(tx),'texture_sha256':t_sha,'source_texture_exact':s_sha==t_sha,'loop':a['loop'],'speed':a['speed'],'poses':poses}
        selection['immutable_source_geometry_pin']=js_sha([{k:p[k] for k in ('source_sha256','region','margin','canvas_size','source_anchor','rgba_sha256')} for p in poses])
        tracks.append(selection)
    return {'frames':{'path':str(frames_path),'sha256':sha(frames_path)},'profile':{'path':str(profile_path),'sha256':sha(profile_path)},'registry':{'path':str(registry_path),'sha256':sha(registry_path)},'effective_profile':profile,'effective_profile_sha256':js_sha(profile),'tracks':tracks,'all_registry_exact':all(p['registry_geometry_equal'] for t in tracks for p in t['poses']),'all_sources_exact':all(t['source_texture_exact'] for t in tracks),'track_count':len(tracks),'pose_count':sum(len(t['poses']) for t in tracks)}
