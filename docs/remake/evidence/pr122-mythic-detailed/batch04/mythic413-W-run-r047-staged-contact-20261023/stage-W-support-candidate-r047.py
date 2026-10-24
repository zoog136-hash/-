"""One fail-stop staging/checkpoint unit using the existing PR122 APIs.

No renderer, source service, preview, approval update or catalog promotion.
"""
from pathlib import Path
import copy, hashlib, json, os, re, subprocess, sys

R = Path('/workspace/twilight')
T = Path(__file__).parent
L = Path('/workspace/scratch/pr122-death-s-only-20261022-v01')
sys.path.insert(0,str(R/'tools'))
import stage_pr122_native_locomotion as staging
import advance_pr122_native_locomotion as advance
import pr122_native_production_approvals as approvals

def sha(data):return hashlib.sha256(data).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=R,text=True,stderr=subprocess.PIPE).strip()
def load(path):return json.loads(Path(path).read_text())
def save(path,value):Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
def current_file(rel,expected=None):
    p = R/rel
    if not p.exists():
        assert p.suffix in ('.json','.py')
        data = subprocess.check_output(['git','show','HEAD:'+rel],cwd=R,stderr=subprocess.PIPE)
        assert len(data)<=2*1024*1024
        p.parent.mkdir(parents=True,exist_ok=True)
        with p.open('xb') as f:f.write(data)
    if expected:assert sha(p.read_bytes())==expected,rel
    return p

mode = sys.argv[1]
assert mode in ('Sdeath','Wattack','Wrun')
revision = {'Sdeath':'r045','Wattack':'r046','Wrun':'r047'}[mode]
head = git('rev-parse','HEAD')
assert git('branch','--show-current')=='feature/twilight-remaining106-20261016'
pending=subprocess.check_output(['git','status','--porcelain=v1','-z'],cwd=R,text=True)
assert {item[3:] for item in pending.split('\0') if item} <= ({'tests/pr122_s_only_death_main_test.gd'} if mode=='Wattack' else set())
assert Path('/workspace/scratch/pr122-last-verified-remote-sha.txt').read_text().strip()==head
policy = load(R/'data/pr122_transform_motion_scope.json')
index_rel = policy['death_source_ledger']['transform:413']['latest_unapproved_S_candidate']['preserved_source_index']
if mode=='Wrun': index_rel='docs/remake/evidence/pr122-mythic-detailed/batch04/mythic413-W-run-two-support-frames-20261023-v01/preserved-source-index.json'
index_path = current_file(index_rel)
source_index = load(index_path)
source_records = {entry['source_path']:entry for entry in source_index['files']}
if mode=='Sdeath':
    packet = L/'S-death-original-cape-v09-exact-packed-candidate-v01'
    request_file = packet/'request-SdeathCapeNative09.json'
    raw = packet/'thunder_female-S-death-original-cape-real-six-v09.png'
    expected_raw = 'a75da5e737c2f3824b85f5015140af9bda9900d274e3d941c48e61265980b6bc'
    contract = Path('/workspace/scratch/mythic413-S-death-author-20261020-v01/actual-own-S-DEATH-six-native-v09-original-cape-root-20261022/own-S-DEATH-six-actual-native-source-contract-v09.json')
elif mode=='Wattack':
    packet = L/'W-attack-distal-cuff-six-exact-packed-candidate-v01'
    request_file = packet/'request-WattackCuffNative04.json'
    raw = packet/'thunder_female-W-attack-cuff-real-six-v04.png'
    expected_raw = 'f60808c017650d4d6eb09a67c910b76a8854fb25fa0680d727c21e6934ea3716'
    contract = Path('/workspace/scratch/mythic413-W-attack-author-fresh-20261020-v01/actual-W-ATTACK6-native-profile-rig-v04-distal-cuff-bind-20261022/W-ATTACK6-actual-native-profile-RIGHT-fullstaff-LEFTguard-realcloth-candidate-v04.json')
else:
    packet = L/'W-run-own-native-six-exact-packed-candidate-v06'
    request_file = packet/'request-WrunOwnNative06.json'
    raw = packet/'thunder_female-W-run-own-native-real-six-v06.png'
    expected_raw = '011234ff4584d130204ab4221296b7ee9c4676a4795be80e4792099c013dab76'
    contract = Path('/workspace/scratch/mythic413-W-run-own-native-20261022-v01/actual-W-RUN-six-own-native-v06-world-contact/W-RUN-six-own-native-source-contract-v06.json')
assert sha(raw.read_bytes())==expected_raw
entry = source_records[str(contract)]
contract_path = current_file(entry['repo_path'],entry['sha256'])
q = load(request_file)
assert q['status']=='REQUESTED_NOT_APPROVED' and q['key']=='transform:413'
q['authoring_dependencies'] = [dict(path=index_rel,sha256=sha(index_path.read_bytes())),
    dict(path=entry['repo_path'],sha256=entry['sha256'])]
if mode in ('Wattack','Wrun'):
    shared = 'docs/remake/evidence/pr122-mythic-detailed/batch04/mythic413-shared-W-settings-incremental-20261023-v01'
    for name in ('W-exact-native-complete-RIGHT-staff-LEFT-upper-and-true-bow-parts-v04-shared-bindings.json',
                 'W-shared-direction-bindings-equivalence.json'):
        dep = R/shared/name
        q['authoring_dependencies'].append(dict(path=dep.relative_to(R).as_posix(),sha256=sha(dep.read_bytes())))
q['source_visual_status'] = 'HOLD_NOT_REVIEWED'
manifest_before = load(R/staging.SOURCE_MANIFEST)
register_before = load(R/staging.REGISTER)
before_actor = register_before['actors']['transform:413']
approval_state = approvals.load_state(R,manifest=manifest_before,register=register_before)
assert approval_state.completed_count==2
approval_state.require_mutable('transform:413','stage an explicitly unapproved existing candidate for')
frozen = {key:copy.deepcopy(value) for key,value in register_before['actors'].items() if key!='transform:413'}
frozen_files = {name:(R/name).read_bytes() for name in ['data/combat_animation_profiles.json',
    'data/pr122_palette_finish_20261019.json','docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json']}
old_profile_path = R/before_actor['native_profile'].removeprefix('res://')
old_profile = old_profile_path.read_bytes()
assert sha(old_profile)==before_actor['native_profile_sha256']
context = staging.capture_geometry_reuse(R,'transform:413')
assert context and len(context['entries'])==before_actor['native_track_count']
for name,value in [('manifest',manifest_before),('register',register_before),('policy',policy)]:
    save(T/f'{revision}.before-{name}.json',value)
state_path = T/f'{revision}.state.json'
save(state_path,dict(last_safe_head=head,mode=mode,phase='BEFORE_SOURCE_ADOPTION',source_visual_status='HOLD_NOT_REVIEWED'))
folder = R/'docs/remake/evidence/pr122-mythic-detailed/batch04'
request_dest = folder/f'request-{revision[1:]}-thunder_female-{q["direction"]}-{q["role"]}-{q["version"]}.json'
assert not request_dest.exists()
save(request_dest,q)
real_analyze = staging.importer.analyze
analysis_calls = []
def counted(path,*args,**kwargs):
    analysis_calls.append(dict(path=str(path),caller=sys._getframe(1).f_code.co_name))
    save(T/f'{revision}.analysis-calls.json',analysis_calls)
    return real_analyze(path,*args,**kwargs)
staging.importer.analyze = counted
try:
    fresh = advance.preserve_action(R,raw,q)
    assert fresh is not None
    manifest = load(R/staging.SOURCE_MANIFEST)
    record = manifest['raw_images'][-1]
    assert record['sha256']==expected_raw and record['geometry']['status']=='GEOMETRY_PASS'
    record['source_visual_status']='HOLD_NOT_REVIEWED'
    record['staging_only']=True
    source = record['source']
    manifest.setdefault('reviewed_runtime_layouts',{})[source]=copy.deepcopy(q['reviewed_runtime_layout'])
    manifest.setdefault('selected_detailed_action_sheets',{})[f'transform:413:{q["direction"]}:{q["role"]}']=source
    manifest['selected_detailed_action_native_poses']=6*len(manifest['selected_detailed_action_sheets'])
    approval_state.assert_preserved(manifest,register_before)
    save(R/staging.SOURCE_MANIFEST,manifest)
    q.update(output_source=source,output_sha256=expected_raw,output_bytes=record['bytes'],
             status='GENERATED_GEOMETRY_PASS_NOT_APPROVED')
    save(request_dest,q)
    fresh = staging.preserved_source_analysis(R,record,fresh['geometry'])
    source_paths = [source,str(Path(source).with_suffix('.geometry.json')),staging.SOURCE_MANIFEST.as_posix(),request_dest.relative_to(R).as_posix()]
    git('add','--sparse','--',*source_paths)
    with staging.source_analysis_context(R,'transform:413',context,{source:fresh}):
        stats = staging.stage(R,'transform:413',revision)
finally:
    staging.importer.analyze = real_analyze
assert analysis_calls and all(call['path']==str(R/source) for call in analysis_calls)
assert stats==dict(reused=before_actor['native_track_count']-(1 if mode=='Wrun' else 0),fresh=1,analyzed=0)
register = load(R/staging.REGISTER)
actor = register['actors']['transform:413']
old_tracks = {track['animation']:track for track in before_actor['tracks']}
current_tracks = {track['animation']:track for track in actor['tracks']}
assert all(current_tracks[name]==track for name,track in old_tracks.items() if not(mode=='Wrun' and name=='run_4'))
if mode=='Wrun': assert sha((R/current_tracks['run_4']['texture']).read_bytes())==expected_raw and len(current_tracks['run_4']['geometry']['frames'])==6
assert actor['native_track_count']==before_actor['native_track_count']+(0 if mode=='Wrun' else 1)
profile_path = (R/actor['frames'].removeprefix('res://')).with_name('NativeMotionProfile.tres')
old_line = ('frames_path = "'+before_actor['frames']+'"').encode()
new_line = ('frames_path = "'+actor['frames']+'"').encode()
assert old_profile.count(old_line)==1
profile_data = old_profile.replace(old_line,new_line)
staging.preserve_write(profile_path,profile_data)
assert profile_data.replace(new_line,old_line)==old_profile
actor.update(native_profile='res://'+profile_path.relative_to(R).as_posix(),native_profile_sha256=sha(profile_data),
             native_profile_basis=copy.deepcopy(before_actor['native_profile_basis']),
             retained_native_profile_source=copy.deepcopy(before_actor['retained_native_profile_source']),
             visual_review='HOLD_NOT_REVIEWED; explicitly unapproved native staging only')
assert not actor['production_connected'] and not actor['detailed_completed']
save(R/staging.REGISTER,register)
save(state_path,dict(last_safe_head=head,mode=mode,phase='STAGED_AWAITING_RUNTIME_CHECKS',source=source,
    analysis_calls=len(analysis_calls),analysis_stats=stats,source_visual_status='HOLD_NOT_REVIEWED'))
print(json.dumps(dict(phase='STAGED',mode=mode,clips=actor['native_track_count'],analysis_calls=len(analysis_calls),stats=stats,frames_rerendered=0)),flush=True)
env=os.environ.copy()
env.update(XDG_DATA_HOME='/workspace/scratch/twilight-test-pr122-'+revision,
           XDG_CACHE_HOME=str(T/'godot-cache'),XDG_CONFIG_HOME=str(T/'godot-config'),
           TWILIGHT_NATIVE_TEST_KEYS='transform:413')
godot='/workspace/scratch/godot472/Godot_v4.7.2-stable_linux.x86_64'
cases=[('resource','tests/pr122_native_locomotion_resource_test.gd','PR122_NATIVE_RESOURCE_PASS'),
       ('player','tests/pr122_native_player_connection_test.gd','PR122_NATIVE_PLAYER_CONNECTION_PASS'),
       ('action','tests/pr122_native_action_test.gd','PR122_NATIVE_ACTION_PASS')]
if mode=='Sdeath':
    env.update(TWILIGHT_NATIVE_DEATH_ACTOR='transform:413',PR122_DEATH_RUNTIME_PROOF=str(T/f'{revision}.main-death-proof.json'))
    cases.append(('main-death','tests/pr122_s_only_death_main_test.gd','PR122_S_ONLY_DEATH_MAIN_RESULT'))
if mode=='Wattack':
    env.update(TWILIGHT_NATIVE_DEATH_ACTOR='transform:413',TWILIGHT_NATIVE_MAIN_ACTION='attack_4',
               TWILIGHT_NATIVE_MAIN_EXPECTED_SOURCE_SHA=expected_raw,
               PR122_ACTION_RUNTIME_PROOF=str(T/f'{revision}.main-attack-proof.json'))
    cases.append(('main-attack','tests/pr122_s_only_death_main_test.gd','PR122_NATIVE_MAIN_ATTACK_PASS'))
if mode=='Wrun':
    env.update(PR122_W_RUN_GEOMETRY=str(L/'new-W-run-own-native-six-candidate-runtime-geometry-v06.json'),
               PR122_W_CONTACT_POINTS=str(T/'W-contact-points-v06.json'),PR122_W_CONTACT_MAX_SLIP='0.1',
               PR122_W_USE_ACTUAL_PROFILE='1',PR122_RUNTIME_PROOF_PATH=str(T/f'{revision}.main-run-proof.json'))
    cases.append(('main-run',str(L/'W_413_own_native_run_main_player_test.gd'),'MYTHIC413_W_OWN_NATIVE_RUN_CANDIDATE'))
logs={}
for name,script,marker in cases:
    log=T/f'{revision}.{name}.log'
    with log.open('xb') as f:
        result=subprocess.run([godot,'--headless','--disable-render-loop','--fixed-fps','60','--path',str(R),'--script',script],cwd=R,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=60)
    text=log.read_text(errors='replace')
    assert result.returncode==0 and marker in text and 'ERROR:' not in text, f'{name} stopped; preserve {log}'
    logs[name]=dict(path=str(log),sha256=sha(log.read_bytes()),status='PASS')
    print(name+': PASS',flush=True)
actor=load(R/staging.REGISTER)['actors']['transform:413']
register=load(R/staging.REGISTER)
register['actors']['transform:413']['verification'] = dict(source_sha256_and_saved_geometry='PASS',
    spriteframes_parse_and_all_frame_cycles='PASS',actual_Player_scene_form_api='PASS',
    actual_Player_dedicated_actions_and_markers='PASS',actual_Main_eight_death_inputs='PASS' if mode=='Sdeath' else 'UNCHANGED_PREVIOUS_PROOF_PRESERVED',
    visual_approval='HOLD_NOT_REVIEWED',source_analysis_scope=stats,distinct_native_poses=actor['native_pose_count'],completed_added=0)
assert all(register['actors'][key]==value for key,value in frozen.items())
approval_state.assert_preserved(load(R/staging.SOURCE_MANIFEST),register)
save(R/staging.REGISTER,register)
result=dict(status='EXISTING_CANDIDATE_STAGED_RUNTIME_PASS_SOURCE_VISUAL_HOLD',mode=mode,revision=revision,
    source=source,source_sha256=expected_raw,clips_added=0 if mode=='Wrun' else 1,clips_replaced=1 if mode=='Wrun' else 0,poses_connected=6,frames_rerendered=0,
    existing_tracks_preserved=len(old_tracks),analysis_calls=len(analysis_calls),analysis_scope=stats,
    profile_literal_changes=['frames_path'],source_visual_status='HOLD_NOT_REVIEWED',production_connected=False,
    final_motion_approvals_added=0,actor_approvals_added=0,active_actor_approved=2,active_actor_total=19,checks=logs)
save(T/f'{revision}.runtime-result.json',result)
save(state_path,dict(last_safe_head=head,mode=mode,phase='RUNTIME_CHECKED_READY_FOR_SCOPED_COMMIT',source=source))
assert all((R/name).read_bytes()==data for name,data in frozen_files.items())
print(json.dumps({key:result[key] for key in ['status','mode','clips_added','poses_connected','frames_rerendered','analysis_calls','final_motion_approvals_added']}),flush=True)
