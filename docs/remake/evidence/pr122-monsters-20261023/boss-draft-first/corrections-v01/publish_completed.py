#!/usr/bin/env python3
"""Connect three reviewed dedicated bosses, preserving old clips and combat data."""
from copy import deepcopy
import hashlib,json,re
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def put(p,b):
    p.parent.mkdir(parents=True,exist_ok=True)
    if p.exists():assert p.read_bytes()==b
    else:p.write_bytes(b)
def main():
    out=HERE/'default-connection';out.mkdir(exist_ok=True)
    cp=ROOT/'data/combat_animation_profiles.json';original_text=cp.read_text();catalog=json.loads(original_text);before=deepcopy(catalog)
    staging=json.loads((ROOT/'data/pr122_monster_boss_repair_staging.json').read_text())['actors']
    actors=[]
    for key,slug in [('monster:알비노 유니콘','albino_unicorn'),('monster:테베 아누비스','thebes_anubis'),('monster:커츠','kurtz')]:
        a=staging[key];assert a['native_track_count']==33 and not a['missing_required_tracks']
        original=catalog['profiles'][key];old=deepcopy(original)
        source_frames=ROOT/a['frames'].removeprefix('res://');source_native=ROOT/a['native_profile'].removeprefix('res://')
        text=source_frames.read_text();profile=source_native.read_text()
        base=ROOT/'assets/actors/eight_direction/monster_boss_repair'/slug/'published-v02';frames=base/'SpriteFrames.tres'
        # Identical texture regions, timing and poses. Only presentation flags
        # change to enable the existing native HIT envelope and exact views.
        text=re.sub(r'^metadata/twilight_(?:native_locomotion_staging|production_connected|detailed_completed) = .*\n','',text,flags=re.M)
        text+='metadata/twilight_native_locomotion_staging = true\nmetadata/twilight_production_connected = true\nmetadata/twilight_detailed_completed = false\n'
        put(frames,text.encode())
        def scalar(name):return float(re.search(r'^'+name+r' = ([\d.]+)',profile,re.M)[1])
        pixel=scalar('pixel_scale');offset=[0,-32*pixel];contact=int(scalar('attack_hit_frame'))
        visual=dict(frames_path='res://'+frames.relative_to(ROOT).as_posix(),layout='directional8',pixel_scale=pixel,sprite_offset=offset,movement_fps=scalar('movement_fps'),embedded_shadow=False,authored_motion_weight=0,hit_recoil=0,color_tint='ffffff',attack_hit_frame=contact,action_hit_frames={'attack':contact,'cast':contact})
        original.update(visual)
        for name in ('shared_visual_source','shared_visual_policy','shared_visual_basis'):
            original.pop(name,None)
        original['preserved_proxy_profile']=old
        # Never change motion style, attack marker/clock, collision, statistics,
        # AI, loot, save schema or the existing death/corpse clock.
        for name in ['motion_style','attack_hit_ratio','attack_animation_speed','death_duration','floating','collision_offset','hit_position','projectile_origin','shadow_size']:
            assert original.get(name)==old.get(name)
        actors.append(dict(key=key,source_frames=a['frames'],source_frames_sha256=sha(source_frames),frames=visual['frames_path'],frames_sha256=sha(frames),native_profile=a['native_profile'],visual_settings=visual,prior_profile=old,tracks=33,poses=a['native_pose_count']))
    keys={a['key'] for a in actors}
    assert all(v==catalog['profiles'][k] for k,v in before['profiles'].items() if k not in keys)
    put(out/'prior-catalog.json',(json.dumps(before,ensure_ascii=False,indent=2)+'\n').encode())
    # Preserve every unrelated profile line byte-for-byte in this large file.
    for key in keys:
        pattern=re.compile(r'("'+re.escape(key)+r'"\s*:\s*)')
        match=pattern.search(original_text);assert match
        _,end=json.JSONDecoder().raw_decode(original_text,match.end())
        value=json.dumps(catalog['profiles'][key],ensure_ascii=False,separators=(',',':'))
        original_text=original_text[:match.end()]+value+original_text[end:]
    assert json.loads(original_text)==catalog
    cp.write_text(original_text)
    put(out/'connection-plan.json',(json.dumps(dict(actors=actors,normal_profiles_unchanged=True,combat_and_death_clocks_preserved=True,existing_PNGs_modified=0,new_art_generated=0,actual_Main='PENDING'),ensure_ascii=False,indent=2)+'\n').encode())
    print('Connected 3 newly completed dedicated boss resources; prior published bosses and normal profiles preserved')
if __name__=='__main__':main()
