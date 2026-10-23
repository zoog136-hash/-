#!/usr/bin/env python3
"""Re-register the preserved boss and replace only E RUN source art."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[5]
BASE=Path(__file__).resolve().parent
OLD=BASE.parent/'boss-fix03-albino-demon'
FOLDER=Path('assets/actors/eight_direction/monster_boss_repair/albino_demon/r003')
KEY='monster:알비노 데몬'
REFERENCE_HEIGHT=96
sys.path.insert(0,str(ROOT/'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import preserve,json_bytes


def canonical_hash(value):
    return hashlib.sha256(json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def frames_bytes(tracks):
    paths=[]
    for track in tracks:
        for frame in track['geometry']['frames']:
            path=frame.get('texture',track['texture'])
            if path not in paths:paths.append(path)
    ids={p:str(i+1) for i,p in enumerate(paths)}
    count=sum(len(t['geometry']['frames']) for t in tracks)
    lines=[f'[gd_resource type="SpriteFrames" load_steps={count+len(paths)+1} format=3]']
    for path in paths:lines+=['',f'[ext_resource type="Texture2D" path="res://{path}" id="{ids[path]}"]']
    animations=[]
    speed={'idle':1.25,'run':12.5,'attack':4.6875,'hit':6.666666667,'death':3.0}
    for i,track in enumerate(tracks):
        for j,frame in enumerate(track['geometry']['frames']):
            lines+=['',f'[sub_resource type="AtlasTexture" id="pose_{i}_{j}"]',f'atlas = ExtResource("{ids[frame.get("texture",track["texture"])]}")',
                    'region = Rect2(%s)'%', '.join(map(str,frame['region'])),
                    'margin = Rect2(%s)'%', '.join(map(str,frame['margin'])),'filter_clip = true']
        poses=',\n'.join('{"duration": 1.0, "texture": SubResource("pose_%d_%d")}'%(i,j) for j in range(len(track['geometry']['frames'])))
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.9f}'%(poses,str(track['role'] in ['idle','run']).lower(),track['animation'],speed[track['role']]))
    lines+=['','[resource]','animations = [\n'+',\n'.join(animations)+'\n]',
            'metadata/twilight_canvas_size = Vector2(256, 256)',
            'metadata/twilight_native_locomotion_staging = true','metadata/twilight_dedicated_boss_repair = true',
            'metadata/twilight_production_connected = false','metadata/twilight_detailed_completed = false','']
    return '\n'.join(lines).encode()


def build():
    original_path=OLD/'candidate-r002.json'
    old=json.loads(original_path.read_text())
    actor=deepcopy(old['actors'][KEY])
    source_plans={s['path']:s for s in old['selected_sources']}
    registrations={}
    checks=[]
    tracks=[]
    reused_pose_count=0
    for track in actor['tracks']:
        if track['role']=='run' and track['direction']=='E':continue
        source=track['source'];plan=source_plans[source]
        if source not in registrations:
            canvas=max(64,round(plan['canvas_size']*64/REFERENCE_HEIGHT/8)*8)
            geometry=core.analyze(ROOT/source,plan['rows'],plan['reference_rows'],directions_axis=plan['axis'],canvas_size=canvas,directions=plan['directions'])
            core.require_complete_pose_regions(ROOT/source,geometry)
            registrations[source]=geometry
        geometry=registrations[source]
        rows=[f['row'] for f in track['geometry']['frames']]
        part=deepcopy(geometry)
        part['frames']=[next(f for f in geometry['frames'] if f['row']==row and f['direction']==track['direction']) for row in rows]
        part['distinct_pixel_frames']=len(rows)
        for before,after in zip(track['geometry']['frames'],part['frames']):
            for field in ['row','direction','region','source_anchor','rgba_sha256']:
                assert before[field]==after[field],(track['animation'],field)
        old_canvas=track['geometry']['canvas_size'][0]
        new_canvas=part['canvas_size'][0]
        height_ratio=(128/REFERENCE_HEIGHT)/2*old_canvas/new_canvas
        assert abs(height_ratio-1)<0.01
        checks.append({'animation':track['animation'],'source_png_unchanged':True,'source_png_sha256':core.sha(ROOT/track['texture']),
                       'frames':len(rows),'old_canvas':old_canvas,'new_canvas':new_canvas,'display_size_ratio':height_ratio,
                       'maximum_allowed_size_error':0.01,'RGBA_regions_anchors_preserved':True})
        reused_pose_count+=len(rows)
        track['geometry']=part
        tracks.append(track)
    assert len(tracks)==32 and reused_pose_count==101
    new_plan=[('pair-a-landing-v01',[0,1],{0:0,1:3}),
              ('demon-E-right-half3-v01',[0],{1:1,2:2}),
              ('demon-E-left-half3-v01',[0],{1:4,2:5})]
    new_frames={};new_sources=[]
    for name,refs,selected in new_plan:
        request=json.loads((BASE/'requests'/(name+'.json')).read_text())
        path=ROOT/request['preserved_path']
        assert core.sha(path)==request['sha256']
        rows=2 if name.startswith('pair-') else 3
        initial=core.analyze(path,rows,refs,directions_axis='columns',canvas_size=2048,directions=['E'])
        core.require_complete_pose_regions(path,initial)
        canvas=max(64,round(initial['neutral_height']*256/REFERENCE_HEIGHT/8)*8)
        geometry=core.analyze(path,rows,refs,directions_axis='columns',canvas_size=canvas,directions=['E'])
        core.require_complete_pose_regions(path,geometry)
        texture=FOLDER/path.name
        preserve(ROOT/texture,path.read_bytes())
        new_sources.append({'path':request['preserved_path'],'sha256':request['sha256'],'texture':texture.as_posix(),
                            'physical_canvas_size':canvas,'neutral_height':initial['neutral_height'],
                            'reference_rows':refs,'selected_physical_to_logical_phase':selected})
        for physical,logical in selected.items():
            frame=deepcopy(next(f for f in geometry['frames'] if f['row']==physical))
            frame.update(row=logical,physical_source_row=physical,texture=texture.as_posix(),source=request['preserved_path'],
                         source_sha256=request['sha256'],source_image_size=geometry['image_size'],source_canvas_size=geometry['canvas_size'])
            assert logical not in new_frames
            new_frames[logical]=frame
    assert sorted(new_frames)==list(range(6))
    e_frames=[new_frames[i] for i in range(6)]
    assert len({f['rgba_sha256'] for f in e_frames})==6
    # The common logical canvas is 256. A source's physical-pixel canvas is
    # uniform across its poses; ActorMotion already normalizes these sources.
    e_track={'direction':'E','role':'run','animation':'run_0','multi_source':True,
             'source':new_sources[0]['path'],'source_sha256':new_sources[0]['sha256'],
             'texture':new_sources[0]['texture'],'textures':[s['texture'] for s in new_sources],
             'source_sheets':new_sources,
             'geometry':{'frames':e_frames,'distinct_pixel_frames':6,'canvas_size':[256,256],'foot':[128,160],
                         'logical_canvas':True,'source_canvas_policy':'Per-source constant proportional canvas; exact pixels and regional anchors preserved, no per-pose rescaling'}}
    tracks.append(e_track)
    assert len(tracks)==33 and sum(len(t['geometry']['frames']) for t in tracks)==107
    frames=FOLDER/'SpriteFrames.tres';preserve(ROOT/frames,frames_bytes(tracks))
    profile=FOLDER/'NativeMotionProfile.tres'
    profile_text=(ROOT/actor['native_profile'].removeprefix('res://')).read_text()
    assert 'pixel_scale = 2.0' in profile_text and 'sprite_offset = Vector2(0, -64)' in profile_text
    scale=128/REFERENCE_HEIGHT
    profile_text=profile_text.replace('/r002/SpriteFrames.tres','/r003/SpriteFrames.tres').replace('pixel_scale = 2.0',f'pixel_scale = {scale:.14f}').replace('sprite_offset = Vector2(0, -64)',f'sprite_offset = Vector2(0, {-32*scale:.14f})')
    preserve(ROOT/profile,profile_text.encode())
    actor.update(tracks=tracks,frames='res://'+frames.as_posix(),frames_sha256=core.sha(ROOT/frames),native_profile='res://'+profile.as_posix(),native_profile_sha256=core.sha(ROOT/profile),
                 quality_review='TARGETED E RUN batch QA PASS: side camera and opposite support repaired. Confirmed unchanged SE RUN phase0/3 same-support repetition and NW overhead contact pose remain specific motion followups. Unreviewed details are not additional batch approval gates; see review.json.',
                 new_source_poses=6,reused_source_poses=101,newly_approved=False)
    candidate={'schema':'pr122-boss-targeted-repair-multisource-v1','batch':BASE.relative_to(ROOT).as_posix(),'revision':'r003','actors':{KEY:actor},
               'new_source_poses':6,'reused_source_poses':101,'selected_native_poses':107,'reference':old['reference'],
               'new_sources':new_sources,'preserved_base_candidate':{'path':original_path.relative_to(ROOT).as_posix(),'sha256':core.sha(original_path)},
               'source_pixel_policy':'All old PNG bytes, frame RGBA regions/anchors, phases and timings are preserved; only proportional virtual canvas/profile registration changes for32 reused clips. E RUN uses6 new selected poses from3 source sheets.',
               'logical_canvas':[256,256],'native_reference_height':REFERENCE_HEIGHT,'pixel_scale':scale,'newly_approved':0,'default_catalog_switches':0,
               'multi_source_contract':'For run_0 frame.texture/source_image_size/source_canvas_size are authoritative per frame; track.texture is only the first texture. Native SpriteFrames binds each frame to its exact PNG.'}
    preserve(BASE/'candidate.json',json_bytes(candidate))
    preserve(BASE/'registration-checks.json',json_bytes({'reused_clips':checks,'reused_RGBA_poses':101,'new_E_poses':6,'profile_scale':scale,'logical_canvas':[256,256],'all_size_errors_under_one_percent':True,'strict_importer_relaxed':False}))
    print('DEMON_E_R003_STAGED clips=33 reused_RGBA_poses=101 new_E_poses=6')


if __name__=='__main__':build()
