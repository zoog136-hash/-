#!/usr/bin/env python3
"""Build original TWILIGHT raster animations; original-game fidelity remains unverified."""
from __future__ import annotations
import argparse, hashlib, json, math
from pathlib import Path
from concurrent.futures import ProcessPoolExecutor
from PIL import Image
from vfx_raster_painter import render

CELL=128
COLUMNS=8
ROWS=12
CLIPS={
    'prepare':(0,[15,15,15,20]),
    'cast':(4,[20,20,20,25,25,30,30,40]),
    'release':(12,[10,15,15,25]),
    'travel':(16,[20]*8),
    'impact':(24,[16,16,16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,49]),
    'persistent':(44,[70,70,85,85,75,75,90,90]),
    'status':(52,[35,40,40,45,40,45,45,50]),
    'resist':(60,[45,55,65,85]),
    'end':(64,[45,60,75,100]),
    'aftermath':(68,[45,50,55,60,65,70,80,95]),
    'flare':(76,[12,14,16,18,22,26,30,35,40,50,57,65]),
    'ground':(88,[35,40,45,50,55,60,65,80]),
}
PALETTES = {
    'steel': ('84c7ed', 'eafaff', '294b78'), 'gold': ('ffcf63', 'fff8d5', 'ad6530'),
    'holy': ('ffe18a', 'fffde6', 'b89449'), 'nature': ('72edac', 'edfff4', '268e72'),
    'fire': ('ff7a31', 'fff2ac', 'a52433'), 'ice': ('69cefa', 'edffff', '356aba'),
    'storm': ('7cafff', 'f1fcff', '594bd6'), 'shadow': ('b171ec', 'e8ceff', '3a285e'),
    'blood': ('e65764', 'ffd2b9', '792753'), 'ether': ('55e6e4', 'e9ffff', '5365b4'),
    'soul': ('75d4c7', 'dcfff7', '435c87'), 'earth': ('dfaa65', 'ffe8bb', '72534c'),
    'dragon_force': ('9365ff','effaff','3d2073'),
}
PROGRAMS = {
    'bolt':'bolt', 'light':'lantern', 'shield':'ward', 'teleport':'portal',
    'cleanse':'petals', 'weight':'feathers', 'earth':'eruption', 'crown':'crown',
    'sword':'excalibur', 'stun':'stun', 'counter':'counter', 'taunt':'shockwave',
    'arrows':'arrow', 'blood':'blood', 'heal':'heal', 'buff':'enchant', 'ice':'ice',
    'seal':'seal', 'stealth':'shadow', 'lance':'lance', 'flame':'firestorm',
    'meteor':'meteor', 'shadow':'hand', 'barrier':'barrier', 'dodge':'shadow',
    'claw':'claw', 'bullets':'bullet', 'mana':'mana', 'wind':'feathers',
    'chain':'chains', 'dragon':'dragon', 'soul':'soul', 'dark_stun':'dark_stun',
    'axe':'axe', 'howl':'shockwave', 'grip':'chains', 'holy_shield':'holy_ward',
    'holy_stun':'holy_stun', 'scythe':'scythe', 'lightning':'lightning', 'mark':'mark',
    'chain_lightning':'chain_lightning', 'thunder_armor':'storm_ward', 'field':'storm_field',
    'thunder_stun':'thunder_stun', 'plasma':'plasma', 'rune':'rune', 'life':'life',
    'rune_stun':'rune_stun', 'illusion':'counter', 'phalanx':'ward', 'ether':'enchant',
    'nomad':'petals', 'guardian':'guardian', 'turn_undead':'judgement',
    'turn_undead_ancient':'judgement',
}


def rgb(s):return tuple(bytes.fromhex(s))

def render_atlas(task):
    sid,program,palette,path=task
    seed=int(sid[-8:],16);atlas=Image.new('RGBA',(CELL*COLUMNS,CELL*ROWS))
    for phase,(first,times) in CLIPS.items():
        clock=0;total=sum(times)
        for i,ms in enumerate(times):
            # Time-based trajectories respect nonuniform frame exposure.
            t=clock/total
            if phase not in ('persistent','travel','status') and i==len(times)-1:t=1.0
            pic=render(program,[rgb(s) for s in PALETTES[palette]],seed,phase,t)
            atlas.paste(pic,((first+i)%COLUMNS*CELL,(first+i)//COLUMNS*CELL))
            clock+=ms
    path=Path(path);temporary=path.with_suffix('.png.tmp')
    atlas.save(temporary,format='PNG',optimize=True);temporary.replace(path)
    return sid

def choose(row,legacy):
    name=row['name'];motif=legacy.get('motif','');program=PROGRAMS.get(motif,'enchant')
    if name=='포우 슬레이어':program='foe'
    if name=='어스 재일':program='earth_prison'
    if name=='슬로우':program='slow'
    if name in ('인비지블리티','쉐도우 하이딩','언케니 닷지'):program='stealth'
    if name=='쉐도우 아머':program='dark_ward'
    if name=='이럽션':program='eruption'
    palette='ether'
    if program in ('stun','counter','ward','arrow'):palette='steel' if program!='arrow' else 'nature'
    elif program in ('excalibur','crown','bullet','axe','shockwave'):palette='gold'
    elif program.startswith('holy') or program in ('judgement','guardian','lance','barrier'):palette='holy'
    elif program in ('firestorm','meteor','foe','eruption'):palette='fire'
    elif program=='ice':palette='ice'
    elif program in ('lightning','chain_lightning','mark','storm_field','storm_ward','thunder_stun','plasma'):palette='storm'
    elif program in ('dark_stun','hand','shadow','scythe','stealth','dark_ward'):palette='shadow'
    elif program=='blood':palette='blood'
    elif program in ('heal','life','petals','feathers'):palette='nature'
    elif program in ('soul','dragon'):palette='soul'
    if name=='어스 재일':palette='earth'
    if program=='foe':palette='dragon_force'
    return program,palette

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);parser.add_argument('--jobs',type=int,default=4);parser.add_argument('--only',nargs='*');args=parser.parse_args();root=args.root
    data=root/'data/skills';assets=root/'assets/skills/authored_vfx';assets.mkdir(parents=True,exist_ok=True)
    rows=json.loads((data/'master.json').read_text())['records'];legacy=json.loads((data/'vfx.json').read_text());relations=json.loads((data/'relations.json').read_text())
    profiles={};art=[];tasks=[]
    dormant={'stats','stack_defense','stack_attack','amplify'}
    for row in rows:
        sid=row['id'];program,palette=choose(row,legacy[sid]);seed=int(sid[-8:],16)
        p={'name':row['name'],'class':row['class'],'mode':row['mode'],'program':program,'palette':palette,
           'color':'#'+PALETTES[palette][0], 'reference_status':'UNVERIFIED','fidelity_approval':'PENDING',
           'standalone_event':row['mode'] not in dormant and row['mode']!='upgrade',
           'directional':program in ('arrow','bullet','claw','foe','scythe','axe','counter','rune'),
           'persistent_offset':[0,-38], 'scale':1.0,
           'cast_body_offset':[0,-38], 'ground_offset':[0,-32],
           'status_offset':[0,-24] if 'stun' in program else [0,0],
           'impact_offset':[0,-4] if program in ('lightning','storm_field','thunder_stun') else [0,11] if program in ('eruption','meteor','firestorm','earth_prison') else [0,19] if program=='shockwave' and row['mode']!='taunt' else [0,-38] if row['mode'] in ('heal','buff','stealth','convert','cleanse','teleport') else [0,0],
           'ground_contact_y':42 if program in ('lightning','storm_field','thunder_stun') else 27 if program in ('eruption','meteor','firestorm','earth_prison') else 19 if program=='shockwave' else None,
           'clips':{k:{'first':v[0],'durations_ms':v[1],'loop':k in ('travel','persistent')} for k,v in CLIPS.items()}}
        if row['mode']=='upgrade':p['inherits_visual']=relations[sid]['upgrades_from'];p['upgrade_visual_difference']='UNVERIFIED_KEEP_BASE'
        elif row['mode'] not in dormant:
            path=assets/(sid+'.png')
            if not args.only or sid in args.only or row['name'] in args.only:
                tasks.append((sid,program,palette,str(path)))
            p['atlas']='res://'+str(path.relative_to(root));p['atlas_rgba_bytes']=CELL*CELL*COLUMNS*ROWS*4
            p['cell_size']=CELL;p['columns']=COLUMNS;p['rows']=ROWS;p['art_revision']=2
        profiles[sid]=p
    with ProcessPoolExecutor(max_workers=max(1,args.jobs)) as pool:
        for sid in pool.map(render_atlas,tasks):print('PAINTED',sid,flush=True)
    for sid,p in profiles.items():
        if 'atlas' not in p:continue
        path=root/p['atlas'].removeprefix('res://')
        art.append({'id':sid,'path':str(path.relative_to(root)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size,'frames':COLUMNS*ROWS,'width':CELL*COLUMNS,'height':CELL*ROWS})
    manifest={'schema':2,'art_revision':2,'cell_size':CELL,'columns':COLUMNS,'rows':ROWS,'max_cached_atlases':8,'max_resident_rgba_bytes':48*1024*1024,
              'authorship':'Independent raster light fields, turbulent heated material and painted blade sheets created for TWILIGHT; no external bitmap input.',
              'warning':'Fallback studies, not original fidelity approval. No publisher timing is asserted.',
              'profiles':profiles,'assets':art,
              'preview_profiles':{
                  'lm_42262935d6f53b07':{'name':'포우 슬레이어(임팩트)','preview_only':True,'runtime_status':'BLOCKED','inherits_visual':'lm_45d35daedfc527c9','visual_status':'UNVERIFIED_KEEP_BASE'},
                  'lm_816e9fd2e2e8a4e8':{'name':'아우라키아','preview_only':True,'runtime_status':'BLOCKED','inherits_visual':'lm_517ca31126a31b45','visual_status':'UNVERIFIED_SHARED_DRAGON_STUDY_NOT_FINISHED_AURAKIYA'}
              }}
    (data/'authored_vfx.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'profiles':len(profiles),'atlases':len(art),'frames':len(art)*COLUMNS*ROWS,'png_bytes':sum(x['bytes'] for x in art)}))

if __name__=='__main__':main()
