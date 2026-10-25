"""Stage only the successful SE ATTACK3 replacement, preserving all old art."""
from pathlib import Path
import json
import hashlib
import math
import sys
ROOT=Path(__file__).resolve().parents[5]
BASE=Path(__file__).resolve().parent
OUT=ROOT/'assets/actors/eight_direction/monster_boss_repair/ice_queen/combat-r002'
sys.path.insert(0,str(ROOT/'tools'))
import import_original_based_motion as core

def put(path,data):
 path.parent.mkdir(parents=True,exist_ok=True)
 if path.exists():assert path.read_bytes()==data, 'Do not overwrite preserved output: '+str(path)
 else:path.write_bytes(data)

def main():
 name='queen-SE-attack3-v01';raw=BASE/'raw'/f'{name}.png';req=json.loads((BASE/'requests'/f'{name}.json').read_text())
 original=json.loads((BASE/'checks'/f'{name}.json').read_text());assert original['status']=='GEOMETRY_PASS_ONLY'
 desired=round((256*575.5/140)/8)*8;minimum=0
 for f in original['geometry']['frames']:
  x,y,w,h=f['region'];ax,ay=f['source_anchor'];dx,dy=ax-x,ay-y
  minimum=max(minimum,2*dx,2*(w-dx),dy*8/5,(h-dy)*8/3)
 canvas=max(desired,math.ceil(minimum/8)*8)
 geometry=core.analyze(raw,3,[0,2],directions_axis='phase_grid3',canvas_size=canvas,directions=['SE'])
 core.require_complete_pose_regions(raw,geometry)
 texture=OUT/f'{name}.png';put(texture,raw.read_bytes())
 lines=['[gd_resource type="SpriteFrames" load_steps=5 format=3]','',f'[ext_resource type="Texture2D" path="res://{texture.relative_to(ROOT).as_posix()}" id="1"]']
 for i,f in enumerate(geometry['frames']):
  lines += ['',f'[sub_resource type="AtlasTexture" id="pose_{i}"]','atlas = ExtResource("1")','region = Rect2(%s)'%', '.join(map(str,f['region'])),'margin = Rect2(%s)'%', '.join(map(str,f['margin'])),'filter_clip = true']
 poses=', '.join('{"duration": 1.0, "texture": SubResource("pose_%d")}'%i for i in range(3))
 lines += ['', '[resource]','animations = [{"frames": ['+poses+'], "loop": false, "name": &"attack_1", "speed": 8.0}]','metadata/twilight_canvas_size = Vector2(256, 256)','metadata/twilight_native_locomotion_staging = true','metadata/twilight_production_connected = false','metadata/twilight_detailed_completed = false','']
 frames=OUT/'SpriteFrames.tres';put(frames,'\n'.join(lines).encode())
 old=ROOT/'assets/actors/eight_direction/monster_boss_repair/ice_queen/combat-r001/NativeMotionProfile.tres';profile=OUT/'NativeMotionProfile.tres'
 text=old.read_text().replace('res://assets/actors/eight_direction/monster_boss_repair/ice_queen/combat-r001/SpriteFrames.tres','res://'+frames.relative_to(ROOT).as_posix());put(profile,text.encode())
 track=dict(role='attack',direction='SE',animation='attack_1',source=raw.relative_to(ROOT).as_posix(),source_sha256=core.sha(raw),texture=texture.relative_to(ROOT).as_posix(),geometry=geometry,frame_count=3,contact_index=1,animation_fps=8.0,loop=False,frame_durations=[1.0]*3)
 actor=dict(kind='boss',quality_tier='mythic_transform',frames='res://'+frames.relative_to(ROOT).as_posix(),frames_sha256=core.sha(frames),native_profile='res://'+profile.relative_to(ROOT).as_posix(),native_profile_sha256=core.sha(profile),native_track_count=1,native_pose_count=3,tracks=[track],pixel_scale=86/140,sprite_offset=[0,-32*(86/140)],production_connected=False,detailed_completed=False,
            correction_precheck='PASS_SOURCE_GEOMETRY_DIRECTION_LEFT_STAFF_NATIVE1X',
            confirmed_source_defects=[],unreviewed=['Detailed Main target/projectile contact has not been reviewed and is not a rejection.'])
 value=dict(schema='pr122-queen-diagonal-attack-partial-replacement-v1',actors={'monster:얼음 여왕':actor},replacement_only=True,replace_animations=['attack_1'],preserved_existing_other_poses=57,new_poses=3,new_approvals=0,default_catalog_switches=0,
            normalization=dict(original_strict_canvas=2048,body_crown_sole_annotations_y=[[126,687],[105,695]],body_height_median=575.5,desired_canvas=desired,minimum_complete_canvas=math.ceil(minimum/8)*8,source_canvas=canvas,world_body_preview_height=575.5*256/canvas*(86/140)),
            failed_attempts_preserved=['queen-SW-attack3-v01: contact switches to RIGHT arm','queen-SW-attack3-v02: actual foreign body pixels in both first AABB regions; held, not cropped'])
 put(BASE/'candidate-SE.json',(json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode())
 print(json.dumps(dict(canvas=canvas,clips=1,poses=3,frames_sha=core.sha(frames),profile_sha=core.sha(profile))))
if __name__=='__main__':main()
