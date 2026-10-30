from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import re,json,hashlib,datetime,sys

B=Path('/workspace/scratch/girtas-ne-final-source-cycle-independent-fresh-20261020')
R=Path('/workspace/twilight')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def jsha(o): return hashlib.sha256(json.dumps(o,sort_keys=True,separators=(',',':')).encode()).hexdigest()
def nums(s): return [float(v) if '.' in v else int(v) for v in s.split(',')]
def parse(revision,register,frames_path=None):
    fp=Path(frames_path) if frames_path is not None else R/f'assets/actors/eight_direction/native_locomotion_staging/girtas_267/{revision}/SpriteFrames.tres'
    pp=fp.with_name('NativeMotionProfile.tres')
    f,p=fp.read_text(),pp.read_text(); actor=json.loads(Path(register).read_text())['actors']['transform:267']
    exts={i:R/s[6:] for s,i in re.findall(r'\[ext_resource type="Texture2D" path="(res://[^"]+)" id="([^"]+)"\]',f)}
    subs={}
    for sid,body in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[)',f,re.S):
        eid=re.search(r'atlas = ExtResource\("([^"]+)"\)',body)[1]
        subs[sid]={'texture':str(exts[eid]),'region':nums(re.search(r'region = Rect2\(([^)]+)\)',body)[1]),'margin':nums(re.search(r'margin = Rect2\(([^)]+)\)',body)[1]),'filter_clip': 'filter_clip = true' in body}
    anim={}
    for body,loop,name,speed in re.findall(r'\{"frames": \[(.*?)\], "loop": (true|false), "name": &"([^"]+)", "speed": ([\d.]+)\}',f,re.S):
        anim[name]={'loop':loop=='true','speed':float(speed),'frames':[dict(subs[sid],duration=float(d)) for d,sid in re.findall(r'\{"duration": ([\d.]+), "texture": SubResource\("([^"]+)"\)\}',body)]}
    ef={'pixel_scale':float(re.search(r'^pixel_scale = ([\d.]+)',p,re.M)[1]),'sprite_offset':nums(re.search(r'^sprite_offset = Vector2\(([^)]+)\)',p,re.M)[1]),'reference_canvas':nums(re.search(r'metadata/twilight_canvas_size = Vector2\(([^)]+)\)',f)[1])}
    literal={k:v for k,v in re.findall(r'^([a-z_]+) = (.+)$',p,re.M) if k not in ('script','frames_path')}
    assert sha(fp)==actor['frames_sha256'] and sha(pp)==actor['native_profile_sha256']
    tracks=[]
    for t in actor['tracks']:
        a=anim[t['animation']]; src=R/t['source']; tx=R/t['texture']; im=Image.open(tx).convert('RGBA'); poses=[]
        assert len(a['frames'])==len(t['geometry']['frames'])==6
        for n,(g,af) in enumerate(zip(t['geometry']['frames'],a['frames'])):
            x,y,w,h=af['region'];mx,my,mw,mh=af['margin'];c=[w+mw,h+mh]; root=[x+c[0]/2-mx,y+c[1]*.625-my]
            assert af['texture']==str(tx)
            rgba=hashlib.sha256(im.crop((x,y,x+w,y+h)).tobytes()).hexdigest()
            ok=af['region']==g['region'] and af['margin']==g['margin'] and rgba==g['rgba_sha256'] and c==g.get('canvas_size',t['geometry']['canvas_size']) and root==g['source_anchor']
            assert ok,(revision,t['direction'],t['role'],n)
            crop=im.crop((x,y,x+w,y+h));ab=crop.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox(); factor=ef['pixel_scale']*ef['reference_canvas'][0]/c[0]
            poses.append(dict(af,canvas_size=c,source_anchor=root,rgba_sha256=rgba,world_factor=factor,world_alpha16_bounds=[(ab[0]+x-root[0])*factor,(ab[1]+y-root[1])*factor,(ab[2]+x-root[0])*factor,(ab[3]+y-root[1])*factor],registry_geometry_equal=True))
        tracks.append({'direction':t['direction'],'role':t['role'],'animation':t['animation'],'source':str(src),'source_sha256':sha(src),'texture':str(tx),'texture_sha256':sha(tx),'source_texture_exact':sha(src)==sha(tx),'loop':a['loop'],'speed':a['speed'],'poses':poses,'immutable_source_geometry_pin':jsha([{'source_sha256':sha(src),**{k:v[k] for k in ('region','margin','canvas_size','source_anchor','rgba_sha256')}} for v in poses])})
    return {'schema':'pr122-v04-actual-parsed-pins-v1','revision':revision,'frames':{'path':str(fp),'sha256':sha(fp)},'profile':{'path':str(pp),'sha256':sha(pp)},'register':{'path':str(register),'sha256':sha(register)},'effective_profile':ef,'effective_profile_sha256':jsha(ef),'effective_profile_literal_fields':literal,'effective_profile_literal_fields_sha256':jsha(literal),'actor_motion_script':{'path':str(R/'scripts/animation/actor_motion.gd'),'sha256':sha(R/'scripts/animation/actor_motion.gd')},'all_registry_exact':True,'all_source_texture_exact':all(t['source_texture_exact'] for t in tracks),'track_count':len(tracks),'pose_count':sum(len(t['poses']) for t in tracks),'tracks':tracks}

def save_exact(path, data):
    content=(json.dumps(data,ensure_ascii=False,indent=2)+'\n').encode()
    path=Path(path)
    if path.exists(): assert path.read_bytes()==content, 'Existing actual pin file differs; preserve and inspect'
    else:
        with path.open('xb') as f: f.write(content)
if __name__=='__main__':
    rev=sys.argv[1];register=sys.argv[2];fp=sys.argv[3] if len(sys.argv)>3 else None
    d=parse(rev,register,fp);p=B/f'actual-{rev}-all48-numeric-pins.json';save_exact(p,d)
    print(json.dumps({'path':str(p),'sha256':sha(p),'all_registry_exact':d['all_registry_exact'],'all_source_texture_exact':d['all_source_texture_exact'],'effective_profile_sha256':d['effective_profile_sha256']}))
