#!/usr/bin/env python3
"""Render every current catalog identity into private, RGBA animation atlases.

Uses the user's explicitly permitted 2D part/mesh rigging route. Existing art
and known four-view sheets are retained. It never invents unseen directions,
labels generated motion as original SPX, or counts pixel tests as visual review.
The source catalog, equipment statistics, source IDs and saved data are read-only.
"""
from __future__ import annotations
import argparse, collections, hashlib, json, math, pathlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import map_coordinates

KINDS = {"변신": "transform", "마법인형": "doll", "성물": "relic"}
COLORS = {"일반": (190, 195, 200), "고급": (95, 210, 125), "희귀": (65, 140, 255),
          "영웅": (255, 85, 65), "전설": (175, 90, 255), "신화": (255, 205, 65), "유일": (60, 255, 195)}
FPS = {"idle": 7, "walk": 10, "run": 14, "attack": 14, "ranged_attack": 13,
       "cast": 11, "hit": 14, "death": 13, "summon": 12, "despawn": 12,
       "activate": 13, "float": 8, "energy": 9, "equip": 12, "unequip": 12}

def digest(data): return hashlib.sha256(data).hexdigest()

def rig_type(kind, record, old):
    name = record['name']
    if kind == 'relic':
        return 'relic', True
    if any(s in name for s in ['유령', '영혼', '고스트', '리치', '하딘', '정령', '위스프']):
        return 'spirit', True
    if any(s in name for s in ['드래곤', '드레이크', '페어리', '피닉스', '하피', '서큐버스', '할파스', '천사', '박쥐']):
        return 'winged', True
    if any(s in name for s in ['거미', '크랩', '개미', '악어', '개구리', '뱀', '늑대', '토끼', '호랑이', '팬더', '개 ']):
        return 'creature', False
    return 'humanoid', bool(old.get('floating', False))

def attack_style(record, old):
    text = record['name'] + ' ' + ' '.join(record.get('sourceOptions', []))
    if any(s in record['name'] for s in ['(활)', '(총)', '궁수', '총사', '질리언', '총병']): return 'bow'
    if any(s in record['name'] for s in ['마법사', '조우', '하딘', '리치', '위자드', '마녀', '마법인형']): return 'magic'
    if '원거리 대미지' in text and '근거리 대미지' not in text: return 'bow'
    if '마법 대미지' in text and '근거리 대미지' not in text: return 'magic'
    if any(s in record['name'] for s in ['광전사', '(도끼)', '오우거', '골렘']): return 'heavy'
    if any(s in record['name'] for s in ['(창)', '창병']): return 'thrust'
    return str(old.get('motion_style', 'slash'))

def source_views(root, kind, record, directional, statuses):
    key = kind + ':' + str(record['sourceId'])
    path = record['image_path']
    sheet = directional.get(key, {})
    member = root / sheet.get('path', '')[6:]
    if sheet and member.is_file():
        im = Image.open(member).convert('RGBA')
        if im.width % 4 or im.height % 4: raise ValueError('nonuniform known sheet ' + key)
        w, h = im.width // 4, im.height // 4
        rows = statuses.get(key, {}).get('sourceRows', [0, 1, 2, 3])
        views = [(suffix, im.crop((0, row*h, w, (row+1)*h)))
                 for suffix, row in zip(['down', 'up', 'left', 'right'], rows)]
        return views, sheet['path'], 'existing four-view art, newly rigged actions'
    im = Image.open(root / path[6:]).convert('RGBA')
    return [('', im)], path, 'single-view reference, newly rigged actions; other views unavailable'

def normalize(im, kind):
    # Consistent canvas and ground anchor; effects around the silhouette survive.
    box = im.getbbox()
    if box is None: raise ValueError('empty RGBA reference')
    art = im.crop(box)
    w, h = (144, 160) if kind == 'transform' else (96, 112)
    maxw, maxh = (122, 132) if kind == 'transform' else (82, 88)
    ratio = min(maxw / art.width, maxh / art.height)
    art = art.resize((max(1, round(art.width*ratio)), max(1, round(art.height*ratio))), Image.Resampling.LANCZOS)
    foot = h - 12
    top = (h-art.height)//2 if kind == 'relic' else foot-art.height
    canvas = Image.new('RGBA', (w, h))
    canvas.alpha_composite(art, ((w-art.width)//2, top))
    return canvas, ((w-art.width)//2, top, art.width, art.height), foot

def mesh_frame(source, bounds, rig, role, phase, style):
    """Continuous local joint deformation, not an affine icon wobble.

    Lower-left/right legs, shoulders/weapon, head, wing tips and torso use
    separate displacement fields. This preserves visible source details while
    creating distinct local poses. Anatomy positions are inferred, with explicit
    review_pending metadata; hidden limbs/views are not synthesized.
    """
    pixels = np.asarray(source, dtype=np.float32)
    h, w = pixels.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    x0, y0, bw, bh = bounds
    nx = (xx-(x0+bw/2)) / max(1, bw/2)
    ny = (yy-y0) / max(1, bh)
    wave = math.sin(phase*math.tau)
    dx = np.zeros((h, w), dtype=np.float32)
    dy = np.zeros((h, w), dtype=np.float32)
    torso = np.exp(-((ny-.46)/.19)**2) * np.exp(-(nx/.65)**4)
    head = np.exp(-((ny-.18)/.14)**2) * np.exp(-(nx/.65)**4)
    leg = np.clip((ny-.62)/.33, 0, 1)
    shoulders = np.exp(-((ny-.45)/.21)**2) * np.clip((np.abs(nx)-.28)/.50, 0, 1)
    right = np.clip((nx+.1)*1.5, 0, 1)
    dx += nx*torso*wave*.45
    dy += head*wave*.40 - torso*wave*.50
    if role in ['walk', 'run']:
        amplitude = 4.7 if role == 'run' else 3.2
        if rig == 'humanoid':
            dx += leg*wave*np.sign(nx)*amplitude*.60
            dy += leg*wave*np.sign(nx)*amplitude
            dx -= shoulders*wave*np.sign(nx)*amplitude*.55
        elif rig == 'creature':
            dy += leg*np.sin(phase*math.tau+nx*math.pi)*amplitude
            dx += np.exp(-((ny-.7)/.25)**2)*np.sin(nx*math.pi)*wave*1.2
        elif rig == 'winged':
            wing = np.clip((np.abs(nx)-.20)/.65, 0, 1)*np.exp(-((ny-.35)/.33)**2)
            dy += wing*wave*6.0
            dx += wing*wave*np.sign(nx)*2.5
        else:
            dx += np.sin(ny*math.tau+phase*math.tau)*np.clip(ny, 0, 1)*2.4
    elif role in ['attack', 'ranged_attack', 'cast']:
        windup = math.sin(min(1, phase/.46)*math.pi*.5) if phase < .46 else 1-(phase-.46)/.54
        if role == 'cast' or style == 'magic':
            dy -= shoulders*windup*9
            dx += shoulders*windup*np.sign(nx)*3.2
            dy -= head*windup
        elif role == 'ranged_attack' or style == 'bow':
            dx += shoulders*(right*5-(1-right)*6)*windup
            dy -= shoulders*windup*1.4
        else:
            sweep = -math.cos(min(1, phase/.64)*math.pi)*math.sin(phase*math.pi)
            dx += shoulders*right*sweep*(13 if style == 'heavy' else 9)
            dy -= shoulders*right*math.sin(phase*math.pi)*8
            dx += torso*windup*1.5
            dy += leg*windup*np.sign(nx)*1.2
    elif role == 'hit':
        recoil = math.sin(phase*math.pi)
        dx -= (torso+head)*recoil*4.5
        dy += torso*recoil*1.5
        dx += shoulders*recoil*np.sign(nx)*1.8
    elif role == 'death':
        # Local head/torso folding and leg collapse; no whole-icon rotation.
        fall = phase*phase
        dx -= (head*8+torso*4)*fall
        dy += (head*bh*.24+torso*bh*.15)*fall
        dx += leg*np.sign(nx)*fall*3
        dy -= leg*fall*3
    elif rig == 'winged':
        wings = np.clip((np.abs(nx)-.27)/.60, 0, 1)*np.exp(-((ny-.36)/.33)**2)
        dy += wings*wave*3.0
    elif rig == 'spirit':
        dx += np.sin(ny*7+phase*math.tau)*np.clip(ny-.35, 0, 1)*2.6
    elif rig == 'creature':
        dy += np.exp(-((ny-.5)/.3)**2)*wave*.75
    # Premultiplied alpha avoids black seams at transparently warped edges.
    alpha = pixels[..., 3]/255.0
    premul = pixels[..., :3]*alpha[..., None]
    coords = [yy-dy, xx-dx]
    out_a = map_coordinates(alpha, coords, order=1, mode='constant', cval=0)
    out = np.zeros_like(pixels)
    for channel in range(3):
        values = map_coordinates(premul[..., channel], coords, order=1, mode='constant', cval=0)
        out[..., channel] = np.divide(values, out_a, out=np.zeros_like(values), where=out_a>.002)
    out[..., 3] = out_a*255
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), 'RGBA')

def relic_frame(source, role, phase, color, mode):
    # The reference body is preserved; an independent, circulating energy
    # layer lights different edges instead of scaling the entire icon.
    w, h = source.size
    body = source.copy()
    energy = Image.new('RGBA', source.size)
    draw = ImageDraw.Draw(energy)
    angle = phase*math.tau
    strength = 1.0
    if role in ['equip', 'activate', 'summon']: strength = math.sin(phase*math.pi)*1.6+.35
    if role in ['unequip', 'despawn']: strength = max(.05, 1-phase)
    rx, ry = (w*.37, h*.20) if mode != '마법' else (w*.29, h*.30)
    for i in range(4):
        a = angle+i*math.tau/4
        x, y = w/2+math.cos(a)*rx, h/2+math.sin(a)*ry
        radius = 1.6+(i%2)*.7
        draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=(*color,min(240,int(165*strength))))
        draw.arc((w/2-rx,h/2-ry,w/2+rx,h/2+ry),
                 math.degrees(a)-18,math.degrees(a)+5,fill=(*color,min(180,int(95*strength))),width=1)
    if role == 'activate':
        ring = (phase*.4+.12)*min(w,h)
        draw.ellipse((w/2-ring,h/2-ring,w/2+ring,h/2+ring),outline=(*color,int(180*(1-phase))),width=2)
    glow = energy.filter(ImageFilter.GaussianBlur(2.0))
    body.alpha_composite(glow)
    body.alpha_composite(energy)
    return body

def build(root, report_dir):
    catalog = json.loads((root/'data/catalog_v19.json').read_text())
    directional = json.loads((root/'data/directional_art_v19.json').read_text())
    status = {r['key']:r for r in json.loads((root/'data/directional_status_v19.json').read_text())}
    profiles = json.loads((root/'data/combat_animation_profiles.json').read_text())['profiles']
    target = root/'assets/catalog_motion'
    report_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = root/'data/visuals/runtime_manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'schema':1}
    manifest['catalog'] = {}
    manifest['method'] = 'new local part/mesh rigging from current artwork; no new unseen views'
    report = {}
    for category, kind in KINDS.items():
        rows = []
        for index, record in enumerate(catalog[category]):
            key = kind+':'+str(record['sourceId'])
            old = profiles.get(key, {})
            rig, floating = rig_type(kind, record, old)
            style = attack_style(record, old)
            views, source_path, provenance = source_views(root,kind,record,directional,status)
            if kind == 'transform':
                roles = ['idle','walk','run','attack','hit','death']
                if style == 'bow': roles.append('ranged_attack')
                if style == 'magic': roles.append('cast')
            elif kind == 'doll': roles = ['idle','walk','run','summon','despawn','activate']
            else: roles = ['idle','float','energy','equip','unequip','activate']
            canvas = (144,160) if kind == 'transform' else (96,112)
            count = 6
            sheet = Image.new('RGBA',(canvas[0]*count,canvas[1]*len(roles)*len(views)))
            tracks = []
            qa = []
            for view_index,(suffix,source) in enumerate(views):
                base,bounds,foot = normalize(source,kind)
                for role_index,role in enumerate(roles):
                    row = view_index*len(roles)+role_index
                    name = role+('_'+suffix if suffix else '')
                    signatures = []
                    for fi in range(count):
                        phase = fi/count if role in ['idle','float','energy','walk','run'] else fi/(count-1)
                        frame = relic_frame(base,role,phase,COLORS.get(record['grade'],COLORS['일반']),record.get('type','만능')) if kind=='relic' else mesh_frame(base,bounds,rig,role,phase,style)
                        if role in ['summon','despawn']:
                            alpha = np.asarray(frame.getchannel('A'),dtype=np.float32)
                            alpha *= max(.14,phase) if role=='summon' else max(.14,1-phase)
                            frame.putalpha(Image.fromarray(alpha.astype(np.uint8)))
                        signatures.append(digest(frame.tobytes()))
                        sheet.alpha_composite(frame,(fi*canvas[0],row*canvas[1]))
                    distinct = len(set(signatures))
                    if distinct < 2: raise ValueError('repeated still frame '+key+'/'+name)
                    tracks.append({'name':name,'row':row,'count':count,'fps':FPS[role],
                                   'loop':role in ['idle','float','energy','walk','run']})
                    qa.append({'track':name,'distinct_frames':distinct,'hashes':signatures})
            folder=target/kind;folder.mkdir(parents=True,exist_ok=True)
            path=folder/(str(record['sourceId'])+'.png')
            sheet.save(path,compress_level=7)
            height=canvas[1]
            shown=120 if kind=='transform' else 72
            info={'game_id':str(record['sourceId']),'name':record['name'],'grade':record['grade'],
                  'source':source_path,'atlas':'res://'+path.relative_to(root).as_posix(),
                  'cell':list(canvas),'directions':len(views),'tracks':tracks,'rig':rig,
                  'floating':floating,'motion_style':style,'movement_fps':10,'attack_hit_frame':3,
                  'sprite_offset':[0,round(-(height-12-height/2)*shown/height,3)],
                  'animation_origin':'newly rigged current TWILIGHT art',
                  'atlas_sha256':digest(path.read_bytes()),'unseen_views_generated':False}
            manifest['catalog'][key]=info
            rows.append(info|{'frames':len(tracks)*count,'pixel_qa':qa,'provenance':provenance,
                             'engine_connected':False,'engine_verified':False,'manual_pose_review':False,
                             'remaining':['manual anatomy/weapon pose review','eight-view reference missing'] if len(views)<8 and kind!='relic' else ['manual body/effect review']})
            if (index+1)%50==0 or index+1==len(catalog[category]):
                print(f'{kind} atlases {index+1}/{len(catalog[category])}',flush=True)
        report[kind]=rows
        (report_dir/(kind+'_sheets.json')).write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    manifest_path.parent.mkdir(parents=True,exist_ok=True)
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n')
    summary={kind:{'registered':len(rows),'atlases':len(rows),'frames':sum(r['frames'] for r in rows),
                   'known_four_views':sum(r['directions']==4 for r in rows),
                   'single_view':sum(r['directions']==1 for r in rows),'game_verified':0,'manual_reviewed':0}
             for kind,rows in report.items()}
    (report_dir/'catalog_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1])
    p.add_argument('--reports',type=pathlib.Path,required=True)
    a=p.parse_args();build(a.root.resolve(),a.reports.resolve())
