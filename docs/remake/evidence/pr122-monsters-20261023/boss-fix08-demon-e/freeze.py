#!/usr/bin/env python3
"""Record concrete repaired defects, remaining defects, and minimum batch QA."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[5]
BASE=Path(__file__).resolve().parent
ASSETS=ROOT/'assets/actors/eight_direction/monster_boss_repair/albino_demon/r003'
OLD=BASE.parent/'boss-fix03-albino-demon'


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def pin(p):return {'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)}
def write(name,value):(BASE/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')


def freeze():
    protected=OLD/'file-manifest.json'
    assert sha(protected)=='a9b8b6162c18f4d615ec1deb3577bf2aaefa6fe4903ab526ec098ec04b323a84'
    for row in json.loads(protected.read_text())['files']:assert sha(ROOT/row['path'])==row['sha256']
    followup=OLD/'e-run-followup/file-manifest.json'
    assert sha(followup)=='de69b90e79b3b787e1451dca6791324a15fd97be4dc7c45c3d18d908deea1264'
    candidate_path=BASE/'candidate.json';candidate=json.loads(candidate_path.read_text())
    actor=candidate['actors']['monster:알비노 데몬']
    tracks=actor['tracks'];assert len(tracks)==33
    assert len({f['rgba_sha256'] for t in tracks for f in t['geometry']['frames']})==107
    play_path=BASE/'godot-playback.json';play=json.loads(play_path.read_text())
    assert play['actual_DB_speed_75_RUN']=='PASS' and play['all_107_source_poses_visited']=='PASS'
    registration=json.loads((BASE/'registration-checks.json').read_text())
    ratio_errors=[abs(r['display_size_ratio']-1) for r in registration['reused_clips']]
    independent=BASE/'independent-review.json';ind=json.loads(independent.read_text())
    assert ind['source_first_pass']=='PASS_WITHIN_EXAMINED_E_RUN_SOURCE_SCOPE'
    se_path=OLD/'run-production/raw/albino-demon-SE-run6-v01.png'
    nw_path=OLD/'raw/albino_attack_NW_v01.png'
    review={
        'schema':'pr122-demon-targeted-E-correction-review-v1','id':'monster:알비노 데몬','date':'2026-10-23','frozen':True,
        'revision':'r003','targeted_E_result':'PASS_USER_MINIMUM_BATCH_QA',
        'overall_boss_completed':False,'new_approvals':0,'default_catalog_switches':0,
        'scope':'E RUN confirmed wrong-SE camera and repeated foreground support correction; preserve S/NW and all other old source art',
        'generation_calls':3,'authored_new_PNGs':3,'authored_pose_count':8,'selected_new_E_poses':6,'reused_RGBA_poses':101,'native_clips':33,'native_poses':107,
        'candidate':pin(candidate_path),'independent_source_review':pin(independent),'godot_playback':pin(play_path),
        'minimum_batch_QA':{'actual_RGBA_PNGs':'PASS','frame_counts_and_unique_selected_poses':'PASS','SpriteFrames_and_NativeProfile_load':'PASS','Godot4_7_2_actual_ActorMotion_playback':'PASS','actual_DB_speed_75_RUN_all8directions':'PASS','all107poses_and8contact_markers_visited':'PASS','canvas_anchor_and_bounds':'PASS','Sdeath_all8headings_terminal':'PASS','selected_E_obvious_grounding_clipping_body_collapse_visual_check':'PASS'},
        'confirmed_fixed_defects':[
            {'defect':'E source looked like frontal SE','result':'FIXED_IN_EXAMINED_SOURCE','observation':'All selected E figures have right-facing nose/one dominant eye, near shoulder occlusion and lateral torso. The belt ornament is foreshortened; the previous broad frontal chest/SE camera is visibly reduced.'},
            {'defect':'E phases0/3 used the same foreground support leg','result':'FIXED_IN_EXAMINED_SOURCE','observation':'The original successful pair is directly selected: phase0 large near RIGHT shin/foot plants low while far LEFT foot lifts; phase3 large near RIGHT knee/foot folds visibly up near waist while far LEFT foot plants low. The RIGHT axe grip stays fixed, so this is not whole-body mirroring.'},
            {'defect':'Support-pair large physical image exceeded native64 canvas guard','result':'FIXED_BY_REGISTRATION','observation':'New revision uses native reference96/pixel_scale128÷96 and proportional per-source physical canvases with common logical256. Strict source bounds and full-visible-region checks remain unchanged; no pixels were rescaled or retouched.'}
        ],
        'selected_E_source_mapping':[
            {'phase':0,'source':'pair-a-landing-v01','physical_row':0},
            {'phase':1,'source':'demon-E-right-half3-v01','physical_row':1},
            {'phase':2,'source':'demon-E-right-half3-v01','physical_row':2},
            {'phase':3,'source':'pair-a-landing-v01','physical_row':1},
            {'phase':4,'source':'demon-E-left-half3-v01','physical_row':1},
            {'phase':5,'source':'demon-E-left-half3-v01','physical_row':2}],
        'not_selected_generated_poses':[{'source':'demon-E-right-half3-v01','physical_row':0,'reason':'Original pair phase0 retains the clearest established landing.'},{'source':'demon-E-left-half3-v01','physical_row':0,'reason':'Actually repeats near-RIGHT support; exclude rather than count as left landing.'}],
        'confirmed_remaining_motion_defects':[
            {'clip':'SE RUN','source':pin(se_path),'observation':'A separate actual private source view confirms phase0 and phase3 both keep the screen-right forward leg low while the opposite foot stays folded behind the axe. The opposite support change repaired in E is still absent in this unchanged SE source.','status':'KNOWN_FOLLOWUP_NOT_FIXED_HERE','impact':'Prevents declaring the whole eight-direction RUN quality complete.'},
            {'clip':'NW ATTACK','source':pin(nw_path),'observation':'The preserved focused NW attack fixes RIGHT weapon ownership, but its nominated contact pose still holds the axe high overhead rather than showing a completed forward chop.','status':'SPECIFIC_CONTACT_POSE_FOLLOWUP_NOT_FIXED_HERE'}],
        'unreviewed_details_not_additional_batch_gates':['Fine loop timing and inter-direction transitions in the final arena','Other directions complete anatomical gait review beyond the confirmed SE issue','Detailed weapon/armor/tail secondary motion','Main-scene physical target contact and moving-world collision'],
        'approval_note':'These unreviewed details are deferred review scope, not invented prerequisites for the user-minimum batch QA. The E repair passes that QA; the overall boss remains incomplete because specific unchanged motion defects are identified above.',
        'preservation':{'existing152_manifest':pin(protected),'previous_failed_followup_manifest':pin(followup),'old_source_RGBA_poses_preserved':101,'reused_clips':32,'all_old_regions_source_anchors_and_phase_order_preserved':True,'max_reused_display_size_error':max(ratio_errors),'all_errors_under_one_percent':max(ratio_errors)<0.01,'S_and_NW_improvements_preserved':True},
        'multi_source_binding':'run_0 uses frame.texture/source_canvas_size for3 exact PNGs. Native SpriteFrames and headless ActorMotion loaded and visited every frame with common logicalcanvas256.',
        'next_specific_fix':'Repair SE opposite support with targeted pose pairs; do not undo the new E camera/support or preserved S/NW improvements.'}
    write('review.json',review)
    write('checkpoint.json',{'schema':1,'frozen':True,'stage':'E_RUN_TARGETED_REPAIR_AND_MINIMUM_BATCH_QA_PASS','candidate':pin(candidate_path),'review':pin(BASE/'review.json'),'new_source_poses':6,'reused_source_poses':101,'native_clips':33,'native_poses':107,'new_approvals':0,'overall_boss_completed':False,'actual_DB_speed_tested':75})
    files=[pin(p) for d in [BASE,ASSETS] for p in sorted(d.rglob('*')) if p.is_file() and p!=BASE/'file-manifest.json' and '__pycache__' not in p.parts]
    write('file-manifest.json',{'schema':1,'frozen':True,'files':files,'file_count':len(files),'bytes':sum(r['bytes'] for r in files),'old152_manifest_sha256_unchanged':sha(protected),'old_failed_followup_manifest_sha256_unchanged':sha(followup),'new_approvals':0,'default_catalog_switches':0,'targeted_E_QA':'PASS','overall_boss_completed':False})
    for row in files:assert sha(ROOT/row['path'])==row['sha256']
    print(json.dumps({'files':len(files),'bytes':sum(r['bytes'] for r in files),'manifest_sha256':sha(BASE/'file-manifest.json'),'candidate_sha256':sha(candidate_path),'review_sha256':sha(BASE/'review.json'),'godot_sha256':sha(play_path),'targeted_E_QA':'PASS','overall_boss_completed':False}))


if __name__=='__main__':freeze()
