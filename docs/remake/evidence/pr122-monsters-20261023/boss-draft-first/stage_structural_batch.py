#!/usr/bin/env python3
"""Minimum per-batch source/frames load preparation, without visual review.

Use the mythic repair's explicit phase_grid3 whole-pose extraction from the
original PNG. Each source is analyzed once and cached by PNG/importer hashes.
Unsafe regions remain HOLD; nothing cuts a body into fixed atlas cells.
"""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'tools'))
import import_original_based_motion as core
COMPASS=['E','SE','S','SW','W','NW','N','NE']
SECONDS=dict(idle=1.2,run=.48,attack=.6,hit=.22,death=.8)

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def put(p,data):
    p.parent.mkdir(parents=True,exist_ok=True)
    if p.exists():assert p.read_bytes()==data,'Use a new draft revision'
    else:p.write_bytes(data)

def main():
    p=argparse.ArgumentParser();p.add_argument('slug');p.add_argument('--revision',required=True);a=p.parse_args()
    actor=next(v for v in json.loads((HERE/'plan.json').read_text())['actors'] if v['slug']==a.slug)
    folder=HERE/a.slug
    importer_sha=sha(ROOT/'tools/import_original_based_motion.py')
    tracks,holds=[],[]
    receipts=sorted(v for v in folder.glob('*-receipt.json') if v.name!='canonical-v01-receipt.json')
    for receipt in receipts:
        record=json.loads(receipt.read_text());source=ROOT/record['source']
        assert sha(source)==record['sha256']
        clip=receipt.stem.removesuffix('-receipt')
        job=json.loads((folder/'requests'/f'{clip}.json').read_text())
        check=folder/'structural-checks'/f'{clip}.json'
        if check.exists():
            result=json.loads(check.read_text());assert result['source_sha256']==record['sha256'] and result['importer_sha256']==importer_sha
        else:
            result=dict(source=record['source'],source_sha256=record['sha256'],importer_sha256=importer_sha,layout='phase_grid3',visual_review='DEFERRED_UNTIL_ALL_DRAFTS')
            try:
                geometry=core.analyze(source,6,[0,3],directions_axis='phase_grid3',canvas_size=2048,directions=[job['direction']])
                core.require_complete_pose_regions(source,geometry)
                canvas=max(64,round(geometry['neutral_height']*256/96/8)*8)
                for f in geometry['frames']:core._rebase_mixed_frame_canvas(f,canvas)
                geometry.update(canvas_size=[canvas,canvas],foot=[canvas//2,canvas*5//8],strict_source_analysis_canvas=2048)
                core.require_complete_pose_regions(source,geometry)
                assert len(geometry['frames'])==6 and len({f['rgba_sha256'] for f in geometry['frames']})==6
                result.update(status='STRICT_WHOLE_POSE_PASS',geometry=geometry)
            except (ValueError,AssertionError) as error:
                result.update(status='SOURCE_HOLD',reason=str(error) or 'Six distinct full poses required')
            check.parent.mkdir(exist_ok=True)
            check.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
        if result['status']!='STRICT_WHOLE_POSE_PASS':
            holds.append(dict(clip=clip,reason=result['reason']));continue
        texture=ROOT/'assets/actors/eight_direction/boss_draft_first'/a.slug/'sources'/source.name
        put(texture,source.read_bytes())
        track=dict(role=job['role'],direction=job['direction'],animation=f'{job["role"]}_{COMPASS.index(job["direction"])}',source=record['source'],source_sha256=record['sha256'],texture=texture.relative_to(ROOT).as_posix(),geometry=deepcopy(result['geometry']),quality_review='FIRST_DRAFT_ONLY; full review deferred',production_connected=False)
        tracks.append(track)
    assert tracks,'No safely separated six-pose clips for playback; keep raw sources and continue other bosses'
    assets=ROOT/'assets/actors/eight_direction/boss_draft_first'/a.slug/a.revision
    paths={t['texture']:str(i+1) for i,t in enumerate(tracks)}
    lines=[f'[gd_resource type="SpriteFrames" load_steps={len(tracks)*7+1} format=3]']
    for texture,key in paths.items():lines+=['',f'[ext_resource type="Texture2D" path="res://{texture}" id="{key}"]']
    animations=[]
    for i,t in enumerate(tracks):
        poses=[]
        for phase,f in enumerate(t['geometry']['frames']):
            key=f'draft_{i}_{phase}'
            lines+=['',f'[sub_resource type="AtlasTexture" id="{key}"]',f'atlas = ExtResource("{paths[t["texture"]]}")','region = Rect2(%s)'%', '.join(map(str,f['region'])),'margin = Rect2(%s)'%', '.join(map(str,f['margin'])),'filter_clip = true']
            poses.append('{"duration": 1.0, "texture": SubResource("%s")}'%key)
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.9f}'%(',\n'.join(poses),str(t['role'] in ('idle','run')).lower(),t['animation'],6/SECONDS[t['role']]))
    lines+=['','[resource]','animations = [\n'+',\n'.join(animations)+'\n]','metadata/twilight_canvas_size = Vector2(256, 256)','metadata/twilight_production_connected = false','metadata/twilight_detailed_completed = false','']
    frames=assets/'SpriteFrames.tres';put(frames,'\n'.join(lines).encode())
    native=assets/'NativeMotionProfile.tres'
    db=json.loads((ROOT/'data/monsters/monster_world_catalog.json').read_text())
    record=db['overlays'].get(actor['name'],next((v for v in db['additions'] if v['name']==actor['name']),{}))
    height=record.get('visual_height',128);scale=height/96
    profile='\n'.join(['[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]','','[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]','','[resource]','script = ExtResource("1")','profile_id = '+json.dumps(actor['id'],ensure_ascii=False),'frames_path = "res://'+frames.relative_to(ROOT).as_posix()+'"','layout = "directional8"','motion_style = '+json.dumps(record.get('animation_profile',{}).get('motion_style','slash')),'movement_fps = 12.5','reference_speed = 210.0',f'pixel_scale = {scale:.12f}',f'sprite_offset = Vector2(0, {-32*scale:.12f})','authored_motion_weight = 0.0','hit_recoil = 0.0','embedded_shadow = false','floating = '+str(record.get('animation_profile',{}).get('floating',False)).lower(),'attack_hit_frame = 2','action_hit_frames = {"attack": 2}','death_duration = 0.8','metadata/twilight_production_connected = false','metadata/twilight_detailed_completed = false',''])
    put(native,profile.encode())
    missing=sorted(({f'{role}_{d}' for role in ('idle','run','attack','hit') for d in range(8)}|{'death_2'})-{t['animation'] for t in tracks})
    staged=dict(kind='boss',quality_tier='mythic_transform',tracks=tracks,frames='res://'+frames.relative_to(ROOT).as_posix(),frames_sha256=sha(frames),native_profile='res://'+native.relative_to(ROOT).as_posix(),native_profile_sha256=sha(native),native_track_count=len(tracks),native_pose_count=len(tracks)*6,distinct_source_pose_count=len({f['rgba_sha256'] for t in tracks for f in t['geometry']['frames']}),missing_required_tracks=missing,production_connected=False,detailed_completed=False,quality_review='DRAFT_ONLY; minimum structural pass; whole-scope one-pass review/fixes pending')
    out=folder/a.revision
    put(out/'candidate.json',(json.dumps(dict(schema='pr122-boss-repair-staging-v1',actors={actor['id']:staged},source_holds=holds,source_drafts_saved=len(receipts),new_approvals=0,default_catalog_switches=0),ensure_ascii=False,indent=2)+'\n').encode())
    print(json.dumps(dict(slug=a.slug,source_drafts=len(receipts),safe_clips=len(tracks),held_clips=len(holds),candidate=(out/'candidate.json').relative_to(ROOT).as_posix())))

if __name__=='__main__':main()
