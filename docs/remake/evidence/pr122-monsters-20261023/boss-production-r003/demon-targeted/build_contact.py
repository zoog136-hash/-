#!/usr/bin/env python3
"""Replace the wrong NW attack contact, keeping 106 existing RGBA poses."""
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[5]
sys.path.insert(0,str(ROOT/'tools'))
import import_original_based_motion as core
spec = importlib.util.spec_from_file_location('frozen_queen_parser',ROOT/'docs/remake/evidence/pr122-monsters-20261023/boss-fix06-queen-n/combined-output/combine_latest.py')
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def put(p,data):
    if p.exists():
        assert p.read_bytes()==data,'Use a new revision: '+str(p)
    else:
        p.parent.mkdir(parents=True,exist_ok=True)
        p.write_bytes(data)

def main():
    base=ROOT/'docs/remake/evidence/pr122-monsters-20261023/boss-fix08-demon-e/candidate.json'
    actor=deepcopy(json.loads(base.read_text())['actors']['monster:알비노 데몬'])
    clips=reader.parse_frames(ROOT/actor['frames'].removeprefix('res://'))
    prior=deepcopy(clips)
    raw=HERE/'raw/NW-contact-v02.png'
    # Ground center is between the two braced feet on the NW ground plane.
    # Horn crest y=300; ground center y=1200 gives 900px body at reference96.
    geometry=core.analyze(raw,1,[0],directions_axis='columns',canvas_size=2048,
                          source_anchors=[[685,1200]],directions=['NW'])
    core.require_complete_pose_regions(raw,geometry)
    canvas=2400
    frame=deepcopy(geometry['frames'][0])
    core._rebase_mixed_frame_canvas(frame,canvas)
    geometry.update(frames=[frame],canvas_size=[canvas,canvas],foot=[canvas//2,canvas*5//8])
    core.require_complete_pose_regions(raw,geometry)
    texture=ROOT/'assets/actors/eight_direction/monster_boss_repair/albino_demon/r004/NW-contact-v02.png'
    put(texture,raw.read_bytes())
    frame.update(row=1,physical_source_row=0,texture=texture.relative_to(ROOT).as_posix(),source=raw.relative_to(ROOT).as_posix(),source_sha256=sha(raw),source_canvas_size=[canvas,canvas])
    pose=clips['attack_5']['frames'][1]
    pose.update(ext='new',texture='res://'+frame['texture'],region=frame['region'],margin=frame['margin'],body='\n'.join(['atlas = ExtResource("new")','region = Rect2(%s)'%', '.join(map(str,frame['region'])),'margin = Rect2(%s)'%', '.join(map(str,frame['margin'])),'filter_clip = true','']))
    assert all(clips[k]==prior[k] for k in clips if k!='attack_5')
    assert clips['attack_5']['frames'][0]==prior['attack_5']['frames'][0] and clips['attack_5']['frames'][2]==prior['attack_5']['frames'][2]
    paths,ext,resources,animations={},[],[],[]
    serial=0
    for name,clip in clips.items():
        poses=[]
        assert (clip['speed_token'],clip['loop_token'])==(prior[name]['speed_token'],prior[name]['loop_token'])
        for f in clip['frames']:
            t=f['texture']
            if t not in paths:
                paths[t]=str(len(paths)+1)
                ext+=['',f'[ext_resource type="Texture2D" path="{t}" id="{paths[t]}"]']
            key='demon_pose_'+str(serial);serial+=1
            body=f['body'].replace(f'ExtResource("{f["ext"]}")',f'ExtResource("{paths[t]}")')
            resources+=['',f'[sub_resource type="AtlasTexture" id="{key}"]',body.rstrip()]
            poses.append('{"duration": %s, "texture": SubResource("%s")}'%(f['duration_token'],key))
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}'%(',\n'.join(poses),clip['loop_token'],name,clip['speed_token']))
    out=texture.parent
    frames,native=out/'SpriteFrames.tres',out/'NativeMotionProfile.tres'
    text='\n'.join([f'[gd_resource type="SpriteFrames" load_steps={serial+len(paths)+1} format=3]',*ext,*resources,'','[resource]','animations = [\n'+',\n'.join(animations)+'\n]','metadata/twilight_canvas_size = Vector2(256, 256)','metadata/twilight_production_connected = false','metadata/twilight_detailed_completed = false',''])
    put(frames,text.encode())
    profile=(ROOT/actor['native_profile'].removeprefix('res://')).read_text()
    put(native,profile.replace(actor['frames'],'res://'+frames.relative_to(ROOT).as_posix()).encode())
    track=next(t for t in actor['tracks'] if t['animation']=='attack_5')
    track['geometry']['frames'][1]=frame
    track.update(multi_source=True,source_visual_first_pass='PASS targeted NW contact: far RIGHT shoulder/arm owns extended axe; near LEFT claw hangs empty. Original contact hand swap corrected.')
    actor.update(frames='res://'+frames.relative_to(ROOT).as_posix(),frames_sha256=sha(frames),native_profile='res://'+native.relative_to(ROOT).as_posix(),native_profile_sha256=sha(native),quality_review='NW contact reach and RIGHT weapon ownership repaired with one new dedicated pose; other106 poses and all33 timings retained. SE RUN opposite support is being re-authored separately.',production_connected=False,detailed_completed=False)
    actor['distinct_source_pose_count']=len({f['rgba_sha256'] for t in actor['tracks'] for f in t['geometry']['frames']})
    assert actor['native_track_count']==33 and actor['distinct_source_pose_count']==107
    evidence=HERE/'r004'
    put(evidence/'candidate.json',(json.dumps(dict(schema='pr122-boss-repair-staging-v1',actors={'monster:알비노 데몬':actor},new_approvals=0,default_catalog_switches=0),ensure_ascii=False,indent=2)+'\n').encode())
    put(evidence/'source-review.json',(json.dumps(dict(scope='NW attack contact frame1 only',targeted_weapon_hand_and_forward_reach='PASS',other106_RGBA_poses_preserved=True,all33_timings_preserved=True,reference_body_height=96,source_horn_crest_y=300,source_ground_center=[685,1200],source_canvas=2400,new_approvals=0),indent=2)+'\n').encode())
    print('Demon r004:33 clips107 poses; NW contact replaced; other106 preserved')

if __name__=='__main__':
    main()
