#!/usr/bin/env python3
"""Read exact runtime TRES and render derived contact sheets for private review."""
from pathlib import Path
import re,json,hashlib
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[5]
OUT=Path(__file__).resolve().parent
DIRS=['E','SE','S','SW','W','NW','N','NE']

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def parse(path):
 t=path.read_text();ext={i:p for p,i in re.findall(r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]',t)};atlas={}
 for i,b in re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\](.*?)(?=\n\[|\Z)',t,re.S):
  ex=re.search(r'atlas = ExtResource\("([^"]+)"\)',b);rg=re.search(r'region = Rect2\(([^)]+)\)',b);mg=re.search(r'margin = Rect2\(([^)]+)\)',b)
  if ex and rg:atlas[i]={'source':ext[ex[1]],'region':[float(x.strip()) for x in rg[1].split(',')],'margin':[float(x.strip()) for x in mg[1].split(',')] if mg else [0,0,0,0]}
 tracks={}
 for fs,n in re.findall(r'\{"frames"\s*:\s*\[(.*?)\],\s*"loop"\s*:\s*(?:true|false),\s*"name"\s*:\s*&"([^"]+)"',t,re.S):tracks[n]=[atlas[i] for i in re.findall(r'SubResource\("([^"]+)"\)',fs)]
 return {'frames_path':str(path.relative_to(ROOT)),'frames_sha256':sha(path),'sources':[{'path':p.removeprefix('res://'),'present':(ROOT/p.removeprefix('res://')).is_file(),'sha256':sha(ROOT/p.removeprefix('res://')) if(ROOT/p.removeprefix('res://')).is_file() else None} for p in ext.values()],'tracks':tracks}

def prepare_metadata():
 scope=json.loads((ROOT/'data/pr122_monster_production_scope.json').read_text());rows=sorted([x for x in scope['monsters'] if x['kind']=='boss'],key=lambda x:x['id'])[40:60]
 profiles=json.loads((ROOT/'data/combat_animation_profiles.json').read_text())['profiles'];src={x['key']:x for x in json.loads((ROOT/'data/animation_authoring_sources.json').read_text())['targets']};db=json.loads((ROOT/'data/monsters/monster_world_catalog.json').read_text());db={**db['overlays'],**{x['name']:x for x in db['additions']}};plates=json.loads((ROOT/'data/monsters/art_atlases.json').read_text());actors=[];packs={}
 for row in rows:
  key=row['id'];p=profiles[key];fp=p.get('frames_path','');pack='pack-%02d'%len(packs) if fp not in packs else packs[fp]['id']
  if fp not in packs:packs[fp]={'id':pack,**parse(ROOT/fp.removeprefix('res://')),'actors':[]}
  packs[fp]['actors'].append(key)
  if key in src:ref=src[key]['reference'];basis='animation_authoring_sources target'
  else:
   v=db.get(row['name'],{}).get('visual');ref=None;basis='NOT_FOUND'
   if v:
    plate=plates[v['atlas']];ref={'path':plate['path'],'region':plate['rects'][v['cell']],'kind':'existing_project_atlas_DB_fallback','sha256':sha(ROOT/plate['path'].removeprefix('res://'))};basis='monster_world_catalog.visual atlas/cell + art_atlases exact region'
  actors.append({'id':key,'name':row['name'],'approval_preserved':row['preserved_status']=='VERIFIED_COMPLETED','original_approval_status':row['preserved_status'],'profile':p,'profile_sha256':hashlib.sha256(json.dumps(p,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest(),'pack':pack,'reference':ref,'reference_basis':basis,'profile_catalog_sha256':sha(ROOT/'data/combat_animation_profiles.json')})
 result={'scope_order':'boss id sorted [40:60]','actors':actors,'packs':list(packs.values())};(OUT/'metadata.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');return result

_cache={}
def original(path):
 if path not in _cache:_cache[path]=Image.open(ROOT/path.removeprefix('res://')).convert('RGBA')
 return _cache[path]
def frame_pixels(frame,size=128,tint=None):
 s=original(frame['source']);x,y,w,h=[round(x) for x in frame['region']];mx,my,mw,mh=[round(x) for x in frame['margin']];cw,ch=w+mw,h+mh
 im=Image.new('RGBA',(max(1,cw),max(1,ch)));im.alpha_composite(s.crop((x,y,x+w,y+h)),(mx,my));im=im.resize((size,size),Image.Resampling.NEAREST)
 if tint:
  pix=im.load();rgb=tuple(int(tint[i:i+2],16)/255 for i in [0,2,4])
  for yy in range(size):
   for xx in range(size):
    a=pix[xx,yy];pix[xx,yy]=(round(a[0]*rgb[0]),round(a[1]*rgb[1]),round(a[2]*rgb[2]),a[3])
 return im

def render(meta):
 sheets=OUT/'contact-sheets';sheets.mkdir(exist_ok=True)
 font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',12)
 for pack in meta['packs']:
  tracks=pack['tracks'];move='run' if any(k.startswith('run_') for k in tracks) else 'walk'
  for name,roles in [('movement',[move]),('attack',['attack']),('idle-hit-death',['idle','hit','death'])]:
   cols=max(sum(len(tracks.get(f'{r}_{d}',[])) for r in roles) for d in range(8));tile=128;top=35;label=26;im=Image.new('RGB',(max(cols,1)*tile+55,top+8*(tile+label)),(34,38,45));draw=ImageDraw.Draw(im);draw.text((4,4),pack['id']+' '+name+' EXACT TRES regions/margins; normalized canvas; line=canvas anchor160/256',font=font,fill='white')
   for d in range(8):
    yy=top+d*(tile+label);draw.text((3,yy+50),DIRS[d],font=font,fill='white');col=0
    for role in roles:
     fs=tracks.get(f'{role}_{d}',[])
     for j,f in enumerate(fs):
      xx=55+col*tile;im.paste(frame_pixels(f,tile),(xx,yy),frame_pixels(f,tile));draw.line((xx,yy+80,xx+tile-1,yy+80),fill=(130,55,120));draw.text((xx+3,yy+tile),f'{role}_{d} p{j}',font=font,fill='white');col+=1
   dst=sheets/f'{pack["id"]}-{name}.png';im.save(dst)
 for start in range(0,len(meta['actors']),5):
  actors=meta['actors'][start:start+5];im=Image.new('RGB',(1000,len(actors)*250),(34,38,45));draw=ImageDraw.Draw(im)
  for j,a in enumerate(actors):
   yy=j*250;draw.text((5,yy+3),a['id']+' '+a['pack'],font=font,fill='white');ref=a['reference']
   if ref:
    src=original(ref['path']);x,y,w,h=ref['region'];crop=src.crop((round(x),round(y),round(x+w),round(y+h)));crop.thumbnail((225,215));im.paste(crop,(5,yy+28),crop)
   pack=next(p for p in meta['packs'] if p['id']==a['pack']);tr=pack['tracks'];tint=a['profile'].get('color_tint')
   for col,(r,d) in enumerate([('idle',2),('idle',6),('attack',2)]):
    fs=tr.get(f'{r}_{d}',[])
    if not fs:continue
    index=min(int(a['profile'].get('attack_hit_frame',1)),len(fs)-1) if r=='attack' else 0;pix=frame_pixels(fs[index],220,tint=tint);im.paste(pix,(250+col*245,yy+25),pix);draw.text((250+col*245,yy+225),f'{r}_{d} p{index} tint={tint}',font=font,fill='white')
  im.save(sheets/f'references-{start:02d}-{start+len(actors)-1:02d}.png')
 (OUT/'contact-sheets-index.json').write_text(json.dumps({'sheets':[{'path':str(p.relative_to(ROOT)),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(sheets.glob('*.png'))]},indent=2)+'\n')

if __name__=='__main__':
 import sys
 m=prepare_metadata()
 if '--render' in sys.argv:render(m)
 print(json.dumps({'actors':len(m['actors']),'unique_runtime_packs':len(m['packs']),'missing_runtime_PNGs':sum(sum(not x['present'] for x in p['sources']) for p in m['packs'])}))
