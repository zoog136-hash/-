#!/usr/bin/env python3
"""Preserve r002 pixels; select an observed opposite-support E track from immutable sources."""
from copy import deepcopy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(ROOT/'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import preserve, json_bytes

BATCH = Path('docs/remake/evidence/pr122-monsters-20261023/boss-fix07-zombie-e')
PREVIOUS = Path('docs/remake/evidence/pr122-monsters-20261023/boss-fix02-zombie-lord/candidate-r002.json')
FOLDER = Path('assets/actors/eight_direction/monster_boss_repair/zombie_lord/r003')
KEY = 'monster:죽음의 좀비 로드'


def frames_bytes(tracks):
    textures = []
    for t in tracks:
        for f in t['geometry']['frames']:
            texture = f.get('texture', t['texture'])
            if texture not in textures: textures.append(texture)
    count = sum(len(t['geometry']['frames']) for t in tracks)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={count+len(textures)+1} format=3]']
    for i, texture in enumerate(textures):
        lines += ['', f'[ext_resource type="Texture2D" path="res://{texture}" id="{i+1}"]']
    animations = []
    for i, t in enumerate(tracks):
        for j, f in enumerate(t['geometry']['frames']):
            texture_id = textures.index(f.get('texture', t['texture'])) + 1
            lines += ['', f'[sub_resource type="AtlasTexture" id="pose_{i}_{j}"]',
                      f'atlas = ExtResource("{texture_id}")',
                      'region = Rect2(%s)' % ', '.join(map(str, f['region'])),
                      'margin = Rect2(%s)' % ', '.join(map(str, f['margin'])), 'filter_clip = true']
        poses = ',\n'.join('{"duration": 1.0, "texture": SubResource("pose_%d_%d")}' % (i,j) for j in range(len(t['geometry']['frames'])))
        seconds = {'idle':1.2,'run':.48,'attack':.42,'hit':.22,'death':.65}[t['role']]
        animations.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.9f}' %
                          (poses,str(t['role'] in ('idle','run')).lower(),t['animation'],len(t['geometry']['frames'])/seconds))
    lines += ['', '[resource]', 'animations = [\n'+',\n'.join(animations)+'\n]',
              'metadata/twilight_canvas_size = Vector2(256, 256)',
              'metadata/twilight_native_locomotion_staging = true',
              'metadata/twilight_production_connected = false', 'metadata/twilight_detailed_completed = false','']
    return '\n'.join(lines).encode()


def build():
    previous = json.loads((ROOT/PREVIOUS).read_text())
    r = deepcopy(previous);a=r['actors'][KEY]
    old_e = next(t for t in a['tracks'] if t['role']=='run' and t['direction']=='E')
    untouched = {(t['role'],t['direction']):deepcopy(t['geometry']['frames']) for t in a['tracks'] if t is not old_e}
    whole_sources = []
    selected = []
    # Actual reviewed near/right stance, not the old first three source rows:
    # old row2 already lifts the near leg and cannot be labeled RIGHT stance.
    for row in [0,1,4]:
        f = deepcopy(old_e['geometry']['frames'][row])
        f.update(texture=old_e['texture'],source=old_e['source'],source_sha256=old_e['source_sha256'],
                 observed_support='anatomical_RIGHT_near',selected_source_row=row)
        selected.append(f)
    for name, rows in [('zombie-lord-E-far-left-support3-guide-v01',[1,2]),
                       ('zombie-lord-E-run6-structural-final-v01',[4])]:
        request_path = ROOT/BATCH/'requests'/(name+'.json')
        q = json.loads(request_path.read_text());source=BATCH/'raw'/(name+'.png')
        initial = core.analyze(ROOT/source,q['rows'],q['reference_rows'],directions_axis=q['directions_axis'],
                               canvas_size=2048,directions=['E'])
        core.require_complete_pose_regions(ROOT/source,initial)
        # Whole-source calibration at reference96; every phase from this PNG
        # shares one canvas. No raster scaling, recolor, mirror or cleanup.
        canvas=max(64,round(initial['neutral_height']*256/96/8)*8)
        g=core.analyze(ROOT/source,q['rows'],q['reference_rows'],directions_axis=q['directions_axis'],
                       canvas_size=canvas,directions=['E'])
        core.require_complete_pose_regions(ROOT/source,g)
        texture=FOLDER/(name+'.png');preserve(ROOT/texture,(ROOT/source).read_bytes())
        whole_sources.append({'source':source.as_posix(),'sha256':core.sha(ROOT/source),'request':request_path.relative_to(ROOT).as_posix(),
                              'request_sha256':core.sha(request_path),'strict_complete_source_geometry':g,'selected_rows':rows})
        for row in rows:
            f=deepcopy(g['frames'][row]);core._rebase_mixed_frame_canvas(f,canvas)
            f.update(texture=texture.as_posix(),source=source.as_posix(),source_sha256=core.sha(ROOT/source),
                observed_support='anatomical_LEFT_far',selected_source_row=row,already_rebased96=True)
            selected.append(f)
    assert len(selected)==6 and len({f['rgba_sha256'] for f in selected})==6
    # Rebase all previous virtual margins only. The source/crop/anchor/RGBA of
    # every non-E pose is preserved, with profile scale2 ->128/96 compensating.
    for t in a['tracks']:
        g=t['geometry'];canvas=max(64,round(g['canvas_size'][0]*(64/96)/8)*8)
        for f in g['frames']:
            core._rebase_mixed_frame_canvas(f,canvas)
        g.update(canvas_size=[canvas,canvas],foot=[canvas//2,canvas*5//8])
        t['reference_height']=96
    old_canvas=old_e['geometry']['canvas_size'][0]
    for phase,f in enumerate(selected):
        if not f.pop('already_rebased96',False):core._rebase_mixed_frame_canvas(f,old_canvas)
        f['playback_phase']=phase
    old_e['geometry'].update(frames=selected,distinct_pixel_frames=6,
        canvas_size=[max(f['canvas_size'][0] for f in selected)]*2,
        source_geometry_kind='explicitly_selected_frames_from_strictly_checked_whole_sources')
    old_e.update(observed_support_sequence=['RIGHT','RIGHT','RIGHT','LEFT','LEFT','LEFT'],
        mixed_source_frames=True,quality_review='Source-plane opposite support observed at phases0/3. Swing arc/timing/pivot/weight remain HOLD; no Main approval.')
    for t in a['tracks']:
        k=(t['role'],t['direction'])
        if k not in untouched:continue
        for old,new in zip(untouched[k],t['geometry']['frames']):
            for field in ['region','source_anchor','rgba_sha256']:assert old[field]==new[field]
    frames=FOLDER/'SpriteFrames.tres';preserve(ROOT/frames,frames_bytes(a['tracks']))
    profile=FOLDER/'NativeMotionProfile.tres'
    body=(ROOT/a['native_profile'].removeprefix('res://')).read_text().replace('/r002/SpriteFrames.tres','/r003/SpriteFrames.tres')
    body=body.replace('pixel_scale = 2.0','pixel_scale = 1.333333333333').replace('sprite_offset = Vector2(0, -64)','sprite_offset = Vector2(0, -42.666666666656)')
    preserve(ROOT/profile,body.encode())
    all_hashes=[f['rgba_sha256'] for t in a['tracks'] for f in t['geometry']['frames']]
    assert len(all_hashes)==len(set(all_hashes))==116
    a.update(frames='res://'+frames.as_posix(),frames_sha256=core.sha(ROOT/frames),native_profile='res://'+profile.as_posix(),
        native_profile_sha256=core.sha(ROOT/profile),reference_height=96,display_height=128,
        quality_review='HOLD: mixed E selected nearRIGHT3/farLEFT3 fixes visible phase0/3 support repetition; incomplete swing arcs, source-plane pivot, cross-source continuity, weight/contact/Main still need review.',
        source_pixel_edits=0,unmodified_other_110_pose_RGBA=True)
    r.update(revision='r003',batch=BATCH.as_posix(),previous_candidate=PREVIOUS.as_posix(),previous_candidate_sha256=core.sha(ROOT/PREVIOUS),
        new_source_poses_this_revision=3,reused_source_poses_from_r002=113,
        reference_height_change='64 to96 virtual-canvas metadata only; profile128/96 keeps nominal game height128. Full-source PNG/RGBA unchanged.',
        actual_source_plane_improvement='E phase0 nearRIGHT grounded vsphase3 farLEFT grounded; do not count this as final mythic approval.',
        runtime_switch_recommendation='HOLD pending independent source QA and root game rendering; no runtime connection in this task.')
    preserve(ROOT/BATCH/'candidate.json',json_bytes(r))
    preserve(ROOT/BATCH/'selected-source-checks.json',json_bytes(whole_sources))
    preserve(ROOT/BATCH/'selection.json',json_bytes({'source_rows':[0,1,4,1,2,4],
        'sources':[old_e['source']]*3+[whole_sources[0]['source']]*2+[whole_sources[1]['source']],
        'observed_support_sequence':old_e['observed_support_sequence'],'new_poses':3,'reused_E_poses':3,
        'unmodified_non_E_poses':110,'unique_selected_source_hashes':all_hashes,
        'gait_hold':'Near half has weak forward swing and far half repeats bent-under position. Support exchange improvement is narrower than complete run-cycle approval.'}))
    print(json.dumps({'revision':'r003','clips':33,'poses':116,'new_poses':3,'reused_poses':113,'unmodified_other_RGBA':110,'new_approvals':0}))


if __name__=='__main__':build()
