"""Stage unchanged queen source PNGs as an explicitly unapproved combat library."""
from pathlib import Path
import hashlib
import json
import math
import statistics
import sys

ROOT = Path(__file__).resolve().parents[5]
BASE = Path(__file__).resolve().parent
DEST = ROOT / 'assets/actors/eight_direction/monster_boss_repair/ice_queen/combat-r001'
sys.path.insert(0, str(ROOT / 'tools'))
import import_original_based_motion as core

COMPASS = ['E','SE','S','SW','W','NW','N','NE']
SELECTED = {'E':'queen-combat-E-v01','SE':'queen-combat-SE-v01','S':'queen-combat-S-v02',
            'SW':'queen-combat-SW-v02','W':'queen-combat-W-v01','NW':'queen-combat-NW-v01',
            'N':'queen-combat-N-v03','NE':'queen-combat-NE-v01'}
# Manual source-view annotations. Exclude staff tips and wing tips from body
# scale. These are preview measurements, not anatomical-support approval.
MEASUREMENTS = {
 'queen-combat-E-v01': {'crown_sole_y':[[70,396],[77,397]],'standing_equivalent_height':323},
 'queen-combat-SE-v01': {'crown_sole_y':[[52,377],[54,375]],'standing_equivalent_height':323},
 'queen-combat-S-v02': {'crown_sole_y':[[58,398],[57,400]],'standing_equivalent_height':341.5},
 'queen-combat-SW-v02': {'crown_sole_y':[[61,381],[64,380]],'standing_equivalent_height':318},
 'queen-combat-W-v01': {'crown_sole_y':[[66,397],[75,396]],'standing_equivalent_height':326},
 'queen-combat-NW-v01': {'crown_sole_y':[[78,368],[82,372]],'standing_equivalent_height':290},
 'queen-combat-N-v03': {'crown_sole_y':[[74,373],[79,373]],'standing_equivalent_height':296.5},
 'queen-combat-NE-v01': {'crown_sole_y':[[35,373],[32,374]],'standing_equivalent_height':340},
 'queen-hit-W-v01': {'crown_sole_y':[[80,670]],'standing_equivalent_height':660,
    'basis':'Recoil knees/torso are compressed; provisional standing equivalent from visible articulated body, not staff/wing bounds.'},
 'queen-hit-SW-v01': {'crown_sole_y':[[128,735]],'standing_equivalent_height':680,
    'basis':'Recoil knees/torso are compressed; provisional standing equivalent from visible articulated body, not staff/wing bounds.'},
 'queen-death-S-v01': {'crown_sole_y':[[94,531]],'standing_equivalent_height':525,
    'basis':'Kneeling first death is not a standing neutral. Provisional same-head-scale transfer from S combat; final source-plane support review required.'},
}


def immutable(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        assert path.read_bytes() == data, 'Never overwrite an existing staged file: ' + str(path)
    else:
        path.write_bytes(data)


def js(value):
    return (json.dumps(value, ensure_ascii=False, indent=2)+'\n').encode()


def main():
    sources = []
    for direction, name in SELECTED.items():
        sources.append((name, direction, {'idle':[0,1], 'attack':[2,3,4], 'hit':[5,6]}))
    # Dedicated two-pose sources replace both observed reversed-facing hit
    # tracks. No problematic original or original pixels are discarded.
    sources = [(n,d,{r:slots for r,slots in clips.items() if not (d in ['W','SW'] and r=='hit')}) for n,d,clips in sources]
    sources += [('queen-hit-W-v01','W',{'hit':[0,1]}),('queen-hit-SW-v01','SW',{'hit':[0,1]}),
                ('queen-death-S-v01','S',{'death':[0,1,2,3]})]
    ext=[]; poses=[]; tracks=[]; geometries=[]; visible=set()
    for source_index,(name,direction,clips) in enumerate(sources):
        request=json.loads((BASE/'requests'/f'{name}.json').read_text())
        checked=json.loads((BASE/'checks'/f'{name}.json').read_text())
        assert checked['status']=='GEOMETRY_PASS_ONLY', name
        raw=BASE/'raw'/f'{name}.png'
        assert core.sha(raw)==checked['sha256']
        desired_canvas=max(64,round(256*MEASUREMENTS[name]['standing_equivalent_height']/140/8)*8)
        # Preserve the strict canvas-fit requirement as well as every source
        # pixel. If a raised staff needs more headroom, enlarge the WHOLE
        # source canvas and disclose the resulting smaller body preview.
        minimum_canvas=0
        for frame in checked['geometry']['frames']:
            x,y,w,h=frame['region']; ax,ay=frame['source_anchor']; dx,dy=ax-x,ay-y
            minimum_canvas=max(minimum_canvas,2*dx,2*(w-dx),dy*8/5,(h-dy)*8/3)
        minimum_canvas=math.ceil(minimum_canvas/8)*8
        canvas=max(desired_canvas,minimum_canvas)
        geometry=core.analyze(raw,request['rows'],request['reference_rows'],directions_axis=request['axis'],
                              canvas_size=canvas,directions=[direction])
        core.require_complete_pose_regions(raw,geometry)
        texture=DEST/f'{name}.png'
        immutable(texture,raw.read_bytes())
        ext.append(texture)
        geometry_row=dict(source=name,source_sha256=checked['sha256'],strict_original_canvas=2048,
                          normalized_canvas=canvas,desired_body_canvas=desired_canvas,minimum_complete_source_canvas=minimum_canvas,
                          preview_body_world_height=MEASUREMENTS[name]["standing_equivalent_height"]*256/canvas*(86/140),
                          body_measurement=MEASUREMENTS[name],geometry=geometry)
        geometries.append(geometry_row)
        source_poses={}
        for role,slots in clips.items():
            ids=[]
            for slot in slots:
                frame=geometry['frames'][slot]
                if slot not in source_poses:
                    pose_id=len(poses);source_poses[slot]=pose_id
                    poses.append((source_index,frame))
                    with core.Image.open(raw) as image:
                        x,y,w,h=frame['region']; fingerprint=core._visible_pose_fingerprint(core.np.asarray(image)[y:y+h,x:x+w])
                    assert fingerprint not in visible, 'Repeated visible selected pose'
                    visible.add(fingerprint)
                ids.append(source_poses[slot])
            tracks.append(dict(role=role,direction=direction,animation=f'{role}_{COMPASS.index(direction)}',
                               source=name,source_slots=slots,pose_ids=ids,normalized_canvas=canvas,
                               frame_count=len(slots),contact_index=1 if role=='attack' else None))
    assert len(tracks)==25 and len(poses)==60 and len(visible)==60
    lines=[f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(poses)+1} format=3]']
    for i,path in enumerate(ext):
        lines += ['',f'[ext_resource type="Texture2D" path="res://{path.relative_to(ROOT).as_posix()}" id="{i+1}"]']
    for i,(source_index,frame) in enumerate(poses):
        lines += ['',f'[sub_resource type="AtlasTexture" id="pose_{i}"]',f'atlas = ExtResource("{source_index+1}")',
                  'region = Rect2(%s)' % ', '.join(map(str,frame['region'])),
                  'margin = Rect2(%s)' % ', '.join(map(str,frame['margin'])),'filter_clip = true']
    animations=[]
    for track in sorted(tracks,key=lambda t:(['idle','attack','hit','death'].index(t['role']),COMPASS.index(t['direction']))):
        frames=', '.join('{"duration": 1.0, "texture": SubResource("pose_%d")}'%i for i in track['pose_ids'])
        animations.append('{"frames": ['+frames+'], "loop": '+('true' if track['role']=='idle' else 'false')+', "name": &"'+track['animation']+'", "speed": '+str({'idle':5.5,'attack':8.0,'hit':12.0,'death':6.0}[track['role']])+'}')
    lines += ['', '[resource]','animations = [\n'+',\n'.join(animations)+'\n]',
              'metadata/twilight_canvas_size = Vector2(256, 256)',
              'metadata/twilight_native_locomotion_staging = true',
              'metadata/twilight_production_connected = false','metadata/twilight_detailed_completed = false','']
    frames_path=DEST/'SpriteFrames.tres';immutable(frames_path,'\n'.join(lines).encode())
    scale=86/140
    profile_path=DEST/'NativeMotionProfile.tres'
    profile=['[gd_resource type="Resource" script_class="TwilightAnimationProfile" load_steps=2 format=3]','',
       '[ext_resource type="Script" path="res://scripts/animation/animation_profile.gd" id="1"]','', '[resource]',
       'script = ExtResource("1")','profile_id = "monster:얼음 여왕"',f'frames_path = "res://{frames_path.relative_to(ROOT).as_posix()}"',
       'layout = "directional8"','motion_style = "magic"','movement_fps = 12.5','reference_speed = 210.0',
       f'pixel_scale = {scale:.12f}',f'sprite_offset = Vector2(0, {-32*scale:.12f})',
       'body_kind = "caster"','floating = false','authored_motion_weight = 0.0','hit_recoil = 0.0',
       'embedded_shadow = false','attack_hit_frame = 1','action_hit_frames = {"attack": 1, "cast": 1}',
       'attack_hit_ratio = 0.52','death_duration = 0.8','metadata/twilight_production_connected = false',
       'metadata/twilight_detailed_completed = false','']
    immutable(profile_path,'\n'.join(profile).encode())
    candidate=dict(schema='pr122-queen-combat-candidate-v1',key='monster:얼음 여왕',quality_tier='mythic_transform',
       native_profile='res://'+profile_path.relative_to(ROOT).as_posix(),native_profile_sha256=core.sha(profile_path),
       frames='res://'+frames_path.relative_to(ROOT).as_posix(),frames_sha256=core.sha(frames_path),
       clips=25,poses=60,unique_selected_visible_poses=60,required_RUN_not_present=8,tracks=tracks,
       geometries=geometries,source_count=len(sources),pixel_scale=scale,reference_height=140,
       source_pixels_unchanged=True,production_connected=False,new_approvals=0,
       status='TECHNICALLY_STAGED_QUALITY_HOLD',
       quality_HOLD=['N staff continuity improved in v03 but pale slit/covered leg identity still swaps between poses.',
        'NE exact rear heading and SE/SW attack vector require gameplay-size visual review.',
        'All source-plane anchors default to preserved geometry conventions; actual boots/cloth/staff ground contacts are unapproved.',
        'Hit/death standing-equivalent scale estimates require visual confirmation; no mythic-quality approval inferred.'])
    candidate['default_catalog_switches']=0
    actor=dict(candidate)
    actor['native_track_count']=25
    actor['native_pose_count']=60
    candidate['actors']={'monster:얼음 여왕':actor}
    immutable(BASE/'candidate.json',js(candidate))
    immutable(BASE/'body-scale-measurements.json',js(dict(reference_height=140,world_crown_to_sole_height=86,
        annotation_status='Manual source-view preview measurements, not final gameplay/contact approval',sources=MEASUREMENTS)))
    print(json.dumps(dict(clips=25,poses=60,unique=60,new_approvals=0,profile=str(profile_path))))


if __name__=='__main__':main()
