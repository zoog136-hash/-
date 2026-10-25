#!/usr/bin/env python3
"""Freeze observed facts and immutable-source pins; never approve or connect art."""
from collections import Counter
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[5]
BASE = Path(__file__).resolve().parent
ASSETS = ROOT / 'assets/actors/eight_direction/monster_boss_repair/albino_demon'
KEY = 'monster:알비노 데몬'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pin(path):
    return {'path':path.relative_to(ROOT).as_posix(), 'bytes':path.stat().st_size, 'sha256':digest(path)}


def write(name, value):
    (BASE / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def freeze():
    candidate_path = BASE / 'candidate-r002.json'
    candidate = json.loads(candidate_path.read_text())
    actor = candidate['actors'][KEY]
    playback_path = BASE / 'godot-playback-r002.json'
    playback = json.loads(playback_path.read_text())
    assert playback['dedicated_clips'] == 33 and playback['unique_source_poses_replayed'] == 107
    assert playback['actual_ActorMotion_playback'] == 'PASS'
    reference_src = ROOT / 'docs/remake/evidence/pr122-monsters-20261023/review-boss-b/references/28.png'
    reference_copy = BASE / 'reference-crop.png'
    if reference_copy.exists():
        assert reference_copy.read_bytes() == reference_src.read_bytes()
    else:
        shutil.copyfile(reference_src, reference_copy)
    run_review_path = BASE / 'run-production/quality-review.json'
    run_review = json.loads(run_review_path.read_text())
    representative = deepcopy(run_review['representative_support_repair'])
    representative['review_note'] = 'Parent assembler agent also privately viewed the actual S-v02 sheet and observed the two different anatomical toeplant poses, with the RIGHT axe hand fixed.'
    findings = [
        {'criterion':'dedicated_boss_identity', 'result':'PASS_WITHIN_STATIC_SCOPE',
         'observation':'New original generated sources replace the prior squat lava-fist golem with the pinned red muscular demon: one head/two black ridged horns/two arms/two clawed legs, spiked gunmetal shoulder/forearm/shin armor, skull belt/chains, thick tail and a large iron axe. No white recolor, wings or shared golem source was used.',
         'limit':'Appearance restoration only; it does not grant mythic production, release or Main approval.'},
        {'criterion':'eight_view_camera', 'result':'PARTIAL_STATIC_PASS',
         'observation':'S is front-facing, W is left-facing, and N/NW/NE show the back of the head, rear straps, muscular back and rear tail root. New combat SW-v02 actually corrects the right-facing SW-v01 to front-left. Front/back directions are no longer a tinted proxy.',
         'limit':'E/SE and W/SW angle separation remains weak in several poses, and timed directional transitions have not had an in-game visual review.'},
        {'criterion':'NW_anatomical_weapon_ownership_repair', 'result':'PASS_WITHIN_STATIC_SCOPE',
         'observation':'Initial NW combat-v01 placed the axe in the near arm. Combat-v02 restores a near LEFT empty claw and far RIGHT weapon for idle/hit but still changed ownership in its contact pose. The final r002 uses only its idle/hit, plus a newly generated focused NW attack source whose far RIGHT shoulder/elbow/fist carries the axe and near LEFT claw remains separately empty in all three static poses.',
         'limit':'This fixes the observed ownership defect; it does not approve the attack contact trajectory.'},
        {'criterion':'action_separation_and_weight', 'result':'PASS_WITHIN_STATIC_SCOPE',
         'observation':'Combat sources include a loaded knee/hip windup, extended or overhead axe action, lower follow-through, chest/head recoil and a braced recovery distinct from neutral breathing. Death progresses from buckling to a low side-lying terminal corpse with the weapon attached to its gripping arm.',
         'limit':'Two-frame idle and hit and three-frame attack are a minimum candidate. Fluidity, timed weight transfer and transitions still require review.'},
        {'criterion':'attack_contact_direction', 'result':'HOLD',
         'observation':'E/W attacks visibly extend the axe blade beyond the head toward the facing side. Some diagonal views and N project laterally, and the focused NW contact remains high overhead rather than a demonstrated full forward chop. Headless contact-frame visitation cannot prove a real target impact.',
         'limit':'Correct the specific contact direction/trajectory before approving the affected boss clips.'},
        {'criterion':'RUN_opposite_support', 'result':'PARTIAL_STATIC_PASS',
         'observation':'S RUN-v02 phases0/3 visibly alternate anatomical RIGHT=screen-left and LEFT=screen-right toeplant while the axe stays in the anatomical RIGHT hand. NW RUN-v03 also repairs near-left empty/far-right weapon ownership.',
         'limit':'Other RUN views do not establish a complete alternating support cycle. Full six-phase timing and moving-world ground contact are not approved.'},
        {'criterion':'clipping_and_complete_source_regions', 'result':'PASS_WITHIN_GEOMETRY_SCOPE',
         'observation':'Every selected PNG passed the unchanged strict complete-pose importer. All selected regions retain their actual source pixels; all 107 selected RGBA/visible poses are distinct. Godot loaded every texture/AtlasTexture and visited every selected source pose with no flipped or rotated replacement.',
         'limit':'BBox/canvas-foot anchors are technical anchors; they do not independently establish anatomical sole contact.'},
        {'criterion':'boss_scale', 'result':'PASS_WITHIN_METADATA_SCOPE',
         'observation':'Original visual_height128 is preserved by native standing reference64 and pixel_scale2.0. Each source has its own proportional virtual canvas; source pixels are never rescaled. The first dying pose uses native58/display116 to stay below standing height.',
         'limit':'Cross-source perceived proportions and physical ground contact remain subject to visual Main review.'},
        {'criterion':'source_metadata_conflict', 'result':'HOLD',
         'observation':'The existing presentation visual.weapon metadata says sword while the exact pinned artwork visibly carries an axe. This new dedicated art follows the visible axe identity and leaves the shared DB unchanged.'},
    ]
    review = {
        'schema':'pr122-albino-demon-boss-repair-visual-review-v1', 'id':KEY, 'date':'2026-10-23', 'frozen':True,
        'revision':'r002', 'current_review':'HOLD', 'required_quality':'mythic_transform',
        'original_production_status':'NOT_AUTHORED', 'original_approval':False,
        'prior_status_unchanged':True, 'existing_approved_assets_preserved':True,
        'new_approvals':0, 'production_connected':False, 'default_catalog_switches':0,
        'method':'Actual private vision of the exact reference, every generated combat/death source sheet and representative repaired S/NW RUN sheets. Child RUN review separately viewed all generated RUN sheets. Static source observations and headless real ActorMotion playback are reported separately; no chat images were forwarded.',
        'candidate':pin(candidate_path), 'native_profile':pin(ROOT / actor['native_profile'].removeprefix('res://')),
        'SpriteFrames':pin(ROOT / actor['frames'].removeprefix('res://')),
        'reference':candidate['reference'], 'reference_crop':pin(reference_copy),
        'selected_tracks':33, 'selected_source_PNGs':len(candidate['selected_sources']), 'selected_unique_poses':107,
        'examined_views':['E','SE','S','SW','W','NW','N','NE'],
        'examined_roles':{'idle':8,'run':8,'attack':8,'hit':8,'death_S_only':1},
        'role_pose_counts':dict(Counter({role:sum(len(t['geometry']['frames']) for t in actor['tracks'] if t['role']==role) for role in ['idle','run','attack','hit','death']})),
        'findings':findings, 'representative_support_repair':representative,
        'run_private_review':pin(run_review_path), 'headless_playback':pin(playback_path),
        'headless_playback_result':'PASS: 33 clips,107 actual source poses,8 contact markers,NPC speed124 RUN and S death terminal hold from8 headings',
        'unseen_not_reviewed':['Default Main integration and timed visual transitions', 'Full eight-direction alternating anatomical gait/support cycle', 'Real moving-world ground plane/collision/sole contact', 'Real target/hitbox overlap and attack contact trajectory', 'GPU tint/material/VFX presentation', 'Final mythic boss quality/release approval'],
        'reasons':[f['observation'] for f in findings if f['result']=='HOLD'],
    }
    write('visual-review.json', review)
    selected_paths={s['path'] for s in candidate['selected_sources']}
    raw_paths=sorted(list((BASE/'raw').glob('*.png'))+list((BASE/'run-production/raw').glob('*.png')))
    requests=sorted(list((BASE/'requests').glob('*.json'))+list((BASE/'run-production/requests').glob('*.json')))
    for path in requests:
        request=json.loads(path.read_text())
        if 'preserved_path' not in request:
            final_request=json.loads((path.parent/(request['name']+'.json')).read_text())
            assert request['request']==final_request['request'],path
            request=final_request
        output=ROOT/request['preserved_path']
        assert output.exists() and digest(output)==request['sha256'], path
    inventory=[dict(pin(p),selected_in_r002=p.relative_to(ROOT).as_posix() in selected_paths) for p in raw_paths]
    write('source-inventory.json', {'schema':1,'frozen':True,'generated_PNGs':len(raw_paths),'selected_in_r002':len(selected_paths),'preserved_not_selected':len(raw_paths)-len(selected_paths),'raw_sources':inventory,'exact_requests':[pin(p) for p in requests]})
    write('checkpoint.json', {'schema':1,'date':'2026-10-23','frozen':True,'id':KEY,'stage':'DEDICATED_SOURCE_AND_PLAYBACK_CANDIDATE_HOLD','final_candidate':pin(candidate_path),'preserved_r001_candidate':pin(BASE/'candidate.json'),'clips':33,'unique_selected_poses':107,'generated_PNGs':len(raw_paths),'selected_PNGs':len(selected_paths),'role_pose_counts':review['role_pose_counts'],'godot':'4.7.2 real ActorMotion PASS','new_approvals':0,'default_catalog_switches':0,'quality_review':pin(BASE/'visual-review.json'),'resume':'Review remaining exact cameras/support/contact and Main; do not count this HOLD boss as completed.'})
    files=[]
    for directory in [BASE,ASSETS]:
        for path in sorted(directory.rglob('*')):
            if path.is_file() and path!=BASE/'file-manifest.json' and '__pycache__' not in path.parts:
                files.append(pin(path))
    tracked=set(subprocess.check_output(['git','ls-files','--',str(BASE.relative_to(ROOT)),str(ASSETS.relative_to(ROOT))],cwd=ROOT,text=True).splitlines())
    manifest={'schema':1,'date':'2026-10-23','frozen':True,'files':files,'file_count':len(files),'total_bytes':sum(p['bytes'] for p in files),'tracked_files_at_snapshot':sum(f['path'] in tracked for f in files),'snapshot_HEAD':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'existing_approved_assets_modified':0,'new_approvals':0,'default_catalog_switches':0,'delivery_note':'All immutable generated PNG/request bytes are local and hash-pinned. Parent agent handles Git delivery; local generation/playback alone is not committed delivery.'}
    write('file-manifest.json',manifest)
    for entry in files:
        assert digest(ROOT/entry['path'])==entry['sha256'],entry['path']
    print(json.dumps({'files':len(files),'bytes':manifest['total_bytes'],'generated_PNGs':len(raw_paths),'selected_PNGs':len(selected_paths),'poses':107,'clips':33,'current_review':'HOLD','manifest_sha256':digest(BASE/'file-manifest.json'),'candidate_r002_sha256':digest(candidate_path),'visual_review_sha256':digest(BASE/'visual-review.json')},ensure_ascii=False))


if __name__=='__main__':
    freeze()
