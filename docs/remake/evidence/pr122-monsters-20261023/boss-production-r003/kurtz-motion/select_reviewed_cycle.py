#!/usr/bin/env python3
"""Use existing correct-facing art; change only three defective run cycles."""
from copy import deepcopy
import hashlib,importlib.util,json,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[5]
sys.path.insert(0,str(ROOT/'tools'))
spec=importlib.util.spec_from_file_location('reader',ROOT/'docs/remake/evidence/pr122-monsters-20261023/boss-fix06-queen-n/combined-output/combine_latest.py')
reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def put(p,b):
    p.parent.mkdir(parents=True,exist_ok=True)
    if p.exists():assert p.read_bytes()==b
    else:p.write_bytes(b)
def main():
    key='monster:커츠';a=deepcopy(json.loads((HERE/'r013/candidate.json').read_text())['actors'][key])
    clips=reader.parse_frames(ROOT/a['frames'].removeprefix('res://'));prior=deepcopy(clips)
    oldtracks=deepcopy(a['tracks']);changed=[]
    for direction,index in [('SW',3),('W',4),('NW',5)]:
        name='run_'+str(index);track=next(t for t in a['tracks'] if t['animation']==name)
        old=deepcopy(track['geometry']['frames'])
        # Correct-facing old W recovery poses supply the first half's swing;
        # the earlier v02 art supplies the opposite support, without mirroring.
        selection=[0,4,5,'new3','new4','new5'] if direction=='W' else ([0,1,2,'new3','new4','new5'] if direction=='SW' else [0,1,2,'new3',4,5])
        selected=[]
        for i,ref in enumerate(selection):
            if isinstance(ref,int):f=deepcopy(old[ref])
            else:
                n=int(ref[3:]);rec=json.loads((HERE/direction/'run'/f'phase{n}-v02-checks.json').read_text())
                assert rec['status']=='STRICT_GEOMETRY_PASS'
                src=ROOT/rec['source'];assert sha(src)==rec['sha256']
                texture=Path('assets/actors/eight_direction/monster_boss_repair/kurtz/production-r003/sources')/f'{direction}-run-phase{n}-v02.png';put(ROOT/texture,src.read_bytes())
                f=deepcopy(rec['geometry']['frames'][0]);f.update(texture=texture.as_posix(),source=rec['source'],source_sha256=rec['sha256'],source_canvas_size=rec['geometry']['canvas_size'],physical_source_row=0)
            f['row']=i;selected.append(f)
            if f['rgba_sha256']!=old[i]['rgba_sha256']:changed.append(dict(animation=name,phase=i,old_rgba_sha256=old[i]['rgba_sha256'],new_rgba_sha256=f['rgba_sha256']))
            pose=clips[name]['frames'][i];pose.update(ext='new',texture='res://'+f['texture'],region=f['region'],margin=f['margin'],body='\n'.join(['atlas = ExtResource("new")','region = Rect2(%s)'%', '.join(map(str,f['region'])),'margin = Rect2(%s)'%', '.join(map(str,f['margin'])),'filter_clip = true','']))
        assert len({f['rgba_sha256'] for f in selected})==6
        track['geometry']['frames']=selected
        track['source_sheets']=[dict(source=f['source'],source_sha256=f['source_sha256'],texture=f['texture']) for f in selected]
        track['quality_review']='Single whole-cycle review: select six existing correct-facing poses with both support sides. No art regenerated.'
    for name in clips:
        assert (clips[name]['speed_token'],clips[name]['loop_token'])==(prior[name]['speed_token'],prior[name]['loop_token'])
        if name not in ['run_3','run_4','run_5']:assert clips[name]==prior[name]
    paths={};ext=[];resources=[];animations=[];serial=0
    for name,c in clips.items():
        poses=[]
        for f in c['frames']:
            t=f['texture']
            if t not in paths:
                paths[t]=str(len(paths)+1);ext+=['',f'[ext_resource type="Texture2D" path="{t}" id="{paths[t]}"]']
            rid='pose_'+str(serial);serial+=1;body=f['body'].replace(f'ExtResource("{f["ext"]}")',f'ExtResource("{paths[t]}")')
            resources+=['',f'[sub_resource type="AtlasTexture" id="{rid}"]',body.rstrip()]
            poses.append('{"duration": %s, "texture": SubResource("%s")}'%(f['duration_token'],rid))
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}'%(',\n'.join(poses),c['loop_token'],name,c['speed_token']))
    out=ROOT/'assets/actors/eight_direction/monster_boss_repair/kurtz/r014';frames=out/'SpriteFrames.tres';native=out/'NativeMotionProfile.tres'
    text='\n'.join([f'[gd_resource type="SpriteFrames" load_steps={serial+len(paths)+1} format=3]',*ext,*resources,'','[resource]','animations = [\n'+',\n'.join(animations)+'\n]','metadata/twilight_canvas_size = Vector2(256, 256)','metadata/twilight_production_connected = false','metadata/twilight_detailed_completed = false',''])
    put(frames,text.encode());profile=(ROOT/a['native_profile'].removeprefix('res://')).read_text();put(native,profile.replace(a['frames'],'res://'+frames.as_posix().removeprefix(str(ROOT)+'/')).encode())
    a.update(frames='res://'+frames.relative_to(ROOT).as_posix(),frames_sha256=sha(frames),native_profile='res://'+native.relative_to(ROOT).as_posix(),native_profile_sha256=sha(native),quality_review='Three run cycles corrected using existing artwork; W hit remains a camera-facing HOLD. Other30 clips and all33 timings unchanged.',confirmed_visual_holds=[dict(animation='hit_4',reason='Both W recoil source poses face right; requires targeted artwork, provider quota active.')])
    a['distinct_source_pose_count']=len({f['rgba_sha256'] for t in a['tracks'] for f in t['geometry']['frames']})
    ev=HERE/'r014';put(ev/'candidate.json',(json.dumps(dict(schema='pr122-boss-repair-staging-v1',actors={key:a},new_approvals=0,default_catalog_switches=0),ensure_ascii=False,indent=2)+'\n').encode())
    put(ev/'changed-poses.json',(json.dumps(dict(changed=changed,unchanged_clips=30,timings_preserved=33,source_pngs_regenerated=0,remaining_hold='hit_4'),ensure_ascii=False,indent=2)+'\n').encode())
    print(json.dumps(dict(changed_poses=len(changed),clips=33,remaining_hold='hit_4')))
if __name__=='__main__':main()
