#!/usr/bin/env python3
"""Freeze one bounded source repair attempt without changing the r002 selection."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[6]
BASE = Path(__file__).resolve().parent
PARENT = BASE.parent
BASE_SHA = 'a9b8b6162c18f4d615ec1deb3577bf2aaefa6fe4903ab526ec098ec04b323a84'
CANDIDATE_SHA = '4dd450c6a85811119e2677f78ef749c7279f6a047ac1657c23f72cd455730a22'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pin(path):
    return {'path':path.relative_to(ROOT).as_posix(),'bytes':path.stat().st_size,'sha256':sha(path)}


def write(name,value):
    (BASE/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')


def freeze():
    protected=PARENT/'file-manifest.json'
    assert sha(protected)==BASE_SHA
    manifest=json.loads(protected.read_text())
    assert len(manifest['files'])==152
    for entry in manifest['files']:
        assert sha(ROOT/entry['path'])==entry['sha256'],entry['path']
    assert sha(PARENT/'candidate-r002.json')==CANDIDATE_SHA
    source_path=BASE/'source-record-v01.json'
    source=json.loads(source_path.read_text())
    image=ROOT/source['preserved_path']
    assert sha(image)==source['sha256']
    request_path=BASE/'request-v01.json'
    assert json.loads(request_path.read_text())['request']==source['request']
    check_path=BASE/'source-check-v01.json'
    check=json.loads(check_path.read_text())
    assert check['status']=='GEOMETRY_PASS_ONLY' and len(check['geometry']['frames'])==6
    independent_path=BASE/'independent-review.json'
    independent=json.loads(independent_path.read_text())
    assert independent['current_review']=='HOLD'
    review={
        'schema':'pr122-albino-demon-E-run-followup-v1','id':'monster:알비노 데몬','date':'2026-10-23','frozen':True,
        'scope':'One newly generated E RUN source only; no direction expansion',
        'generation_attempts':1,'geometry_retries':0,'quality_retries':0,
        'current_review':'HOLD','selected_for_new_revision':False,'native_r003_created':False,
        'new_approvals':0,'new_completed_bosses':0,'new_native_clips':0,
        'generated_poses':6,'selected_poses':0,'source':pin(image),'source_record':pin(source_path),
        'exact_request':pin(request_path),'geometry_check':pin(check_path),
        'physical_phase_mapping':{'top_left':0,'middle_left':1,'bottom_left':2,'top_right':3,'middle_right':4,'bottom_right':5},
        'inspection':'Actual private tool vision of the complete six-pose PNG and exact existing project reference, followed by an independent private source-image review. No images/Base64 were forwarded to parent/user.',
        'examined_views':['E'],'examined_roles':['run'],'examined_poses':6,
        'findings':[
            {'criterion':'reference_identity','result':'PASS_WITHIN_STATIC_SCOPE','observation':'The new source preserves red demon muscle, swept black horns, heavy spiked armor, attached tail, actual axe in the visible near hand and opposite empty claw. No golem source or palette-only swap was used.'},
            {'criterion':'strict_E_camera','result':'HOLD','observation':'The face/snout is more strongly right-facing in profile, but the frontal skull-belt face and frontal chest plane remain visible. This is a partial camera change and does not establish the requested pure right-flank view.'},
            {'criterion':'opposite_anatomical_support','result':'HOLD','observation':'Top-left logical phase0 and top-right logical phase3 show a similar forward low planted leg and a rear trailing lifted foot. The requested phase3 far-LEFT toeplant with near-RIGHT knee/foot clearly raised is not established; differing pixel hashes and small body/axe changes do not prove opposite support.'},
            {'criterion':'complete_pose_geometry','result':'PASS_WITHIN_GEOMETRY_SCOPE','observation':'All six complete connected poses passed unchanged strict source geometry and full visible-region coverage checks. This technical result does not repair the camera/support findings.'}
        ],
        'independent_review':pin(independent_path),
        'reasons':['Strict E profile remains insufficient: front skull-belt/chest surfaces are still visible.','The two half-cycle landing poses do not establish opposite anatomical support.'],
        'timed_playback':'NOT_RUN: this unselected quality-HOLD source was not connected to new native resources',
        'unseen_not_reviewed':['Timed gait/transition fluidity','Moving-world physical sole-ground contact','GPU material/VFX','Default Main','Final mythic boss approval'],
        'preserved_selected_candidate':pin(PARENT/'candidate-r002.json'),
        'protected_manifest':pin(protected),'protected_manifest_files_verified_unchanged':152,
        'decision':'Preserve this actual generated PNG and exact request as a HOLD attempt; keep r002 selected. No quality retry or new direction generation.'
    }
    write('review.json',review)
    files=[pin(p) for p in sorted(BASE.rglob('*')) if p.is_file() and p.name!='file-manifest.json' and '__pycache__' not in p.parts]
    write('file-manifest.json',{'schema':1,'frozen':True,'scope':'E RUN followup only','files':files,'file_count':len(files),'total_bytes':sum(f['bytes'] for f in files),'base_152_manifest_sha256_unchanged':BASE_SHA,'selected_candidate_r002_sha256_unchanged':CANDIDATE_SHA,'new_approvals':0,'new_native_clips':0,'current_review':'HOLD'})
    for entry in files:
        assert sha(ROOT/entry['path'])==entry['sha256']
    print(json.dumps({'current_review':'HOLD','base_manifest_unchanged':True,'candidate_r002_unchanged':True,'files':len(files),'review_sha256':sha(BASE/'review.json'),'manifest_sha256':sha(BASE/'file-manifest.json'),'raw_sha256':sha(image),'raw_bytes':image.stat().st_size}))


if __name__=='__main__':
    freeze()
