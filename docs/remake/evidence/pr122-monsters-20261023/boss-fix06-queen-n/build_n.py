"""N-only candidate: three targeted new poses plus three verified old poses.

All four full PNGs stay byte-identical; per-frame density registration is
represented by AtlasTexture margins, not resized/recolored source pixels.
"""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[5]
OUT = Path(__file__).resolve().parent
FOLDER = ROOT/'assets/actors/eight_direction/monster_boss_repair/ice_queen/n-r001'
sys.path.insert(0,str(ROOT/'tools'))
import import_original_based_motion as core


def rel(p):return p.relative_to(ROOT).as_posix()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def put(p,data):
    p.parent.mkdir(parents=True,exist_ok=True)
    if p.exists():assert p.read_bytes()==data,'Preserve existing output: '+str(p)
    else:p.write_bytes(data)
def jb(v):return(json.dumps(v,ensure_ascii=False,indent=2)+'\n').encode()


old=OUT/'references/queen-N-v03-preserved-source.png'
old_raw=core.analyze(old,6,[0,1],directions_axis='phase_grid2',canvas_size=2048,directions=['N'])
core.require_complete_pose_regions(old,old_raw)
old_normal=core.analyze(old,6,[0,1],directions_axis='phase_grid2',canvas_size=616,directions=['N'])
core.require_complete_pose_regions(old,old_normal)
assert [f['rgba_sha256'] for f in old_raw['frames']]==[f['rgba_sha256'] for f in old_normal['frames']]
old_texture=FOLDER/'N-preserved-source.png'
put(old_texture,old.read_bytes())
checks=[{'source':rel(old),'sha256':sha(old),'whole_source_body_count':6,'strict2048':'PASS','strict616':'PASS',
         'all_visible_source_pixels_preserved':'PASS','selected_old_source_slots':[0,4,1],
         'rejected_old_source_slots':{'2':'bare thigh on viewer LEFT','3':'bare thigh on viewer LEFT','5':'same LEFT-forward flight repeats instead of opposite RIGHT-forward phase'}}]
new_data={}
# Crown landmarks were found inside separately visually selected head ROIs;
# the staff orb/wing tips are excluded. Sole is the visible planted/extended
# boot endpoint. Flight height is a density calibration, not contact approval.
for name,canvas,crown,sole in [
    ('phase1-RIGHT-midstance-v01',696,[769,333],714),
    ('phase4-LEFT-midstance-v01',728,[771,327],726),
    ('phase5-RIGHT-forward-flight-v01',776,[761,315],740),
]:
    source=OUT/'raw'/(name+'.png')
    strict=core.analyze(source,1,[0],directions_axis='columns',canvas_size=2048,directions=['N'])
    core.require_complete_pose_regions(source,strict)
    normal=core.analyze(source,1,[0],directions_axis='columns',canvas_size=canvas,directions=['N'])
    core.require_complete_pose_regions(source,normal)
    assert strict['frames'][0]['rgba_sha256']==normal['frames'][0]['rgba_sha256']
    texture=FOLDER/(name+'.png')
    put(texture,source.read_bytes())
    new_data[name]=(source,texture,normal,{'method':'private_visual_head_ROI_crown_apex_to_planted_or_extended_boot_sole',
        'crown_apex_xy':crown,'sole_y':sole,'body_reference_height':sole-crown[1],
        'logical_canvas':[canvas,canvas],'reference_height':140,'uncertainty_source_pixels':3,
        'flight_contact_claim':False})
    checks.append({'source':rel(source),'sha256':sha(source),'strict2048':'PASS','strict_normalized':'PASS',
                   'all_visible_source_pixels_preserved':'PASS','logical_canvas':[canvas,canvas],
                   'geometry_before_root_registration':normal,'body_scale_measurement':new_data[name][3]})

specs=[
    (old,old_texture,old_normal,0,616,False,'RIGHT_contact',{'crown_apex_xy':[411,65],'sole_y':401,'body_reference_height':336}),
    (*new_data['phase1-RIGHT-midstance-v01'][:3],0,696,True,'RIGHT_midstance',new_data['phase1-RIGHT-midstance-v01'][3]),
    (old,old_texture,old_normal,4,616,False,'LEFT_forward_flight',{'same_source_density_as_old_contacts':True,'flight_contact_claim':False}),
    (old,old_texture,old_normal,1,616,False,'LEFT_contact',{'crown_apex_xy':[997,66],'sole_y':400,'body_reference_height':334}),
    (*new_data['phase4-LEFT-midstance-v01'][:3],0,728,True,'LEFT_midstance',new_data['phase4-LEFT-midstance-v01'][3]),
    (*new_data['phase5-RIGHT-forward-flight-v01'][:3],0,776,True,'RIGHT_forward_flight',new_data['phase5-RIGHT-forward-flight-v01'][3]),
]
frames=[]
for phase,(source,texture,geometry,slot,canvas,new,label,measure) in enumerate(specs):
    frame=deepcopy(geometry['frames'][slot])
    pixels=np.asarray(Image.open(source).convert('RGBA'))
    x,y,width,height=frame['region']
    sole_y=y+height-4
    is_flight=phase in [2,5]
    if is_flight:
        # Root X is the head/pelvis axis; the invisible ground plane is below
        # the visible airborne pose. This estimate remains physical-QA HOLD.
        anchor_x=412 if phase==2 else 768
        anchor_y=sole_y+12
        ground_kind='flight_plane_12px_below_visible_pose_bound_NOT_physical_contact_approval'
    else:
        sole_columns=np.where(pixels[max(0,sole_y-1):sole_y+1,x:x+width,3].max(axis=0)>100)[0]
        assert len(sole_columns)
        anchor_x=round(float(np.median(sole_columns)))+x
        anchor_y=sole_y
        ground_kind='visible_boot_sole_line_technical_registration_NOT_moving_world_approval'
    mx,my=canvas//2-(anchor_x-x),canvas*5//8-(anchor_y-y)
    assert min(mx,my)>=0 and mx+width<=canvas and my+height<=canvas
    frame.update(row=phase,source_slot=slot,pose_label=label,canvas_size=[canvas,canvas],foot=[canvas//2,canvas*5//8],
                 margin=[mx,my,canvas-width,canvas-height],source_anchor=[anchor_x,anchor_y],
                 source=rel(source),source_sha256=sha(source),texture=rel(texture),image_size=geometry['image_size'],
                 newly_generated=new,body_scale_measurement=measure,ground_registration=ground_kind)
    assert hashlib.sha256(pixels[y:y+height,x:x+width].tobytes()).hexdigest()==frame['rgba_sha256']
    frames.append(frame)
assert len({f['rgba_sha256'] for f in frames})==6

textures=list(dict.fromkeys(f['texture'] for f in frames))
lines=[f'[gd_resource type="SpriteFrames" load_steps={6+len(textures)+1} format=3]']
for i,texture in enumerate(textures):lines+=['',f'[ext_resource type="Texture2D" path="res://{texture}" id="{i+1}"]']
for i,frame in enumerate(frames):
    lines+=['',f'[sub_resource type="AtlasTexture" id="N_{i}"]',f'atlas = ExtResource("{textures.index(frame["texture"])+1}")',
            'region = Rect2(%s)'%', '.join(map(str,frame['region'])),'margin = Rect2(%s)'%', '.join(map(str,frame['margin'])),'filter_clip = true']
poses=',\n'.join('{"duration": 1.0, "texture": SubResource("N_%d")}'%i for i in range(6))
lines+=['','[resource]','animations = [{"frames": ['+poses+'], "loop": true, "name": &"run_6", "speed": 12.5}]',
        'metadata/twilight_canvas_size = Vector2(256, 256)','metadata/twilight_native_locomotion_staging = true',
        'metadata/twilight_production_connected = false','metadata/twilight_detailed_completed = false','']
tres=FOLDER/'SpriteFrames.tres';put(tres,'\n'.join(lines).encode())
profile_source=ROOT/'assets/actors/eight_direction/monster_boss_repair/ice_queen/combined-r001/NativeMotionProfile.tres'
body=profile_source.read_text();old_line='frames_path = "res://assets/actors/eight_direction/monster_boss_repair/ice_queen/combined-r001/SpriteFrames.tres"'
assert body.count(old_line)==1
profile=FOLDER/'NativeMotionProfile.tres';put(profile,body.replace(old_line,'frames_path = "res://'+rel(tres)+'"').encode())
track={'direction':'N','role':'run','animation':'run_6','source':rel(old),'source_sha256':sha(old),'texture':rel(old_texture),
       'geometry':{'image_size':old_normal['image_size'],'canvas_size':[616,616],'frame_canvas_sizes':[f['canvas_size'] for f in frames],
                   'per_frame_texture_source_and_canvas_override':True,'reference_canvas':[256,256],
                   'frames':frames,'distinct_pixel_frames':6,'foot':[308,385]},
       'new_source_pose_count':3,'reused_source_pose_count':3,
       'source_policy':'per-frame source/texture/source_sha256/canvas_size overrides are authoritative; track defaults describe preserved old sheet only',
       'quality_review':'HOLD final gait/contact/timing; actual selected6 preserve RIGHT bare thigh on viewer-right and LEFT cloth/staff on viewer-left'}
required=[f'{role}_{i}' for role in ['idle','run','attack','hit'] for i in range(8)]+['death_2']
candidate={'schema':'pr122-queen-N-targeted-repair-candidate-v1','batch':rel(OUT),'new_approvals':0,'default_catalog_switches':0,
           'new_raw_sources':3,'new_selected_poses':3,'reused_selected_poses':3,'existing_frozen_inputs_preserved':True,
           'actors':{'monster:얼음 여왕':{'kind':'boss','quality_tier':'mythic_transform','frames':'res://'+rel(tres),'frames_sha256':sha(tres),
                     'native_profile':'res://'+rel(profile),'native_profile_sha256':sha(profile),'production_connected':False,'detailed_completed':False,
                     'native_track_count':1,'native_pose_count':6,'new_source_pose_count':3,'reused_source_pose_count':3,
                     'missing_required_tracks':[key for key in required if key!='run_6'],
                     'quality_review':'HOLD: selected anatomical outfit continuity observed fixed; full gait, moving-world physical contact, final mythic approval remain unapproved',
                     'tracks':[track],'sizing':{'ONE_profile_scale':86/140,'reference_canvas':[256,256],'per_frame_density_canvas':True,'source_pixels_resampled':False}}}}
put(OUT/'candidate.json',jb(candidate));put(OUT/'checks/selected-sources.json',jb(checks))
print(json.dumps({'native_clips':1,'native_poses':6,'newly_generated_selected':3,'reused_selected':3,'per_frame_canvases':[f['canvas_size'][0] for f in frames],
                  'PNG_sources':len(textures),'new_approvals':0,'frames_sha256':sha(tres),'profile_sha256':sha(profile)}))
