"""Preserve two full PNGs and compose an exact mixed-source SW attack."""
from pathlib import Path
import json,math,hashlib,sys
ROOT=Path(__file__).resolve().parents[6]
BASE=Path(__file__).resolve().parent
OUT=ROOT/'assets/actors/eight_direction/monster_boss_repair/ice_queen/combat-r002/sw-attack-r001'
sys.path.insert(0,str(ROOT/'tools'))
import import_original_based_motion as core

def put(path,data):
 path.parent.mkdir(parents=True,exist_ok=True)
 if path.exists():assert path.read_bytes()==data
 else:path.write_bytes(data)

def normalized(raw,rows,refs,axis,bodyheight):
 initial=core.analyze(raw,rows,refs,directions_axis=axis,canvas_size=2048,directions=['SW'])
 core.require_complete_pose_regions(raw,initial)
 desired=round((256*bodyheight/140)/8)*8;minimum=0
 for f in initial['frames']:
  x,y,w,h=f['region'];ax,ay=f['source_anchor'];dx,dy=ax-x,ay-y
  minimum=max(minimum,2*dx,2*(w-dx),dy*8/5,(h-dy)*8/3)
 canvas=max(desired,math.ceil(minimum/8)*8)
 result=core.analyze(raw,rows,refs,directions_axis=axis,canvas_size=canvas,directions=['SW'])
 core.require_complete_pose_regions(raw,result)
 return result,dict(strict_canvas=2048,body_height=bodyheight,desired_canvas=desired,minimum_complete_canvas=math.ceil(minimum/8)*8,source_canvas=canvas)

def main():
 prior=BASE.parent/'raw/queen-SW-attack3-v01.png';contact=BASE/'raw/queen-SW-contact1-left-hand-v01.png'
 old,oldscale=normalized(prior,3,[0,2],'phase_grid3',615.5)
 new,newscale=normalized(contact,1,[0],'rows',956)
 raw_sources=[prior,contact];textures=[OUT/'queen-SW-windup-recovery-source.png',OUT/contact.name]
 for raw,texture in zip(raw_sources,textures):put(texture,raw.read_bytes())
 selected=[(0,old['frames'][0]),(1,new['frames'][0]),(0,old['frames'][2])]
 lines=['[gd_resource type="SpriteFrames" load_steps=6 format=3]']
 for i,path in enumerate(textures):lines += ['',f'[ext_resource type="Texture2D" path="res://{path.relative_to(ROOT).as_posix()}" id="{i+1}"]']
 frame_sources=[]
 for i,(source_index,frame) in enumerate(selected):
  lines += ['',f'[sub_resource type="AtlasTexture" id="pose_{i}"]',f'atlas = ExtResource("{source_index+1}")','region = Rect2(%s)'%', '.join(map(str,frame['region'])),'margin = Rect2(%s)'%', '.join(map(str,frame['margin'])),'filter_clip = true']
  frame_sources.append(dict(frame_index=i,source=raw_sources[source_index].relative_to(ROOT).as_posix(),source_sha256=core.sha(raw_sources[source_index]),texture=textures[source_index].relative_to(ROOT).as_posix(),source_geometry_frame=frame,source_canvas=(old if source_index==0 else new)['canvas_size'],source_slot=[0,0,2][i]))
 frames=OUT/'SpriteFrames.tres';poses=', '.join('{"duration": 1.0, "texture": SubResource("pose_%d")}'%i for i in range(3))
 lines += ['', '[resource]','animations = [{"frames": ['+poses+'], "loop": false, "name": &"attack_3", "speed": 8.0}]','metadata/twilight_canvas_size = Vector2(256, 256)','metadata/twilight_native_locomotion_staging = true','metadata/twilight_production_connected = false','metadata/twilight_detailed_completed = false','']
 put(frames,'\n'.join(lines).encode())
 profile=OUT/'NativeMotionProfile.tres';oldprofile=ROOT/'assets/actors/eight_direction/monster_boss_repair/ice_queen/combat-r001/NativeMotionProfile.tres'
 put(profile,oldprofile.read_text().replace('res://assets/actors/eight_direction/monster_boss_repair/ice_queen/combat-r001/SpriteFrames.tres','res://'+frames.relative_to(ROOT).as_posix()).encode())
 track=dict(role='attack',direction='SW',animation='attack_3',frame_count=3,contact_index=1,animation_fps=8.0,loop=False,frame_durations=[1,1,1],mixed_source=True,frame_sources=frame_sources)
 actor=dict(kind='boss',quality_tier='mythic_transform',native_profile='res://'+profile.relative_to(ROOT).as_posix(),native_profile_sha256=core.sha(profile),frames='res://'+frames.relative_to(ROOT).as_posix(),frames_sha256=core.sha(frames),native_track_count=1,native_pose_count=3,tracks=[track],production_connected=False,detailed_completed=False,pixel_scale=86/140,sprite_offset=[0,-32*(86/140)],confirmed_source_defects=[],unreviewed=['Detailed Main projectile/target contact'],unreviewed_is_rejection=False,correction_precheck='SOURCE_GEOMETRY_DIRECTION_LEFT_STAFF_PASS; native1x render pending')
 result=dict(schema='pr122-queen-mixed-source-SW-attack-replacement-v1',actors={'monster:얼음 여왕':actor},replacement_only=True,replace_animations=['attack_3'],new_approvals=0,default_catalog_switches=0,newly_generated_contact_poses=1,reused_correct_new_SW_windup_recovery_poses=2,excluded_wrong_contact_source_slot=1,
 normalization=[dict(source=prior.relative_to(ROOT).as_posix(),geometry=old,scale=oldscale),dict(source=contact.relative_to(ROOT).as_posix(),geometry=new,scale=newscale)],
 composition_note='Two unchanged original PNGs; per-AtlasTexture source/region/margin must be preserved. Do not feed mixed track into one-texture frames_bytes. No resampling/mirror/rotation/cleaning; no invalid contact selected.')
 put(BASE/'candidate-SW.json',(json.dumps(result,ensure_ascii=False,indent=2)+'\n').encode())
 print(json.dumps(dict(old_canvas=old['canvas_size'],new_contact_canvas=new['canvas_size'],clips=1,poses=3,frames_sha=core.sha(frames),profile_sha=core.sha(profile))))
if __name__=='__main__':main()
