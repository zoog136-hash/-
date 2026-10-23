import sys,json,hashlib,subprocess,collections,shutil
from pathlib import Path
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-region-repair-20261023');base=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023';out=base/'source-region-repair-v01';evidence=out/'evidence';evidence.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
a=json.loads((s/'repair-summary.json').read_text());b=json.loads((s/'fragment-repair-summary.json').read_text());fixes=a['repaired_clips']+b['repaired_clips'];assert len(fixes)==121
for f in fixes:assert sha(r/f['source'])==sha(r/f['original_source'])==f['source_sha256']
old_errors=json.loads((base/'batch-review-v01/remaining-errors.json').read_text());fixed={x['original_source'] for x in fixes};remaining=[x for x in old_errors['source_holds'] if x['source'] not in fixed];assert len(remaining)==321
counts=collections.Counter()
for row in remaining:
 e=row.get('geometry_error') or ''
 if e.startswith('Expected exactly 6 separated poses'):counts['large_component_count_not_six']+=1
 elif e.startswith('A pose rectangle includes another body'):counts['foreign_component_inside_pose_rectangle']+=1
 elif 'visible pixels outside pose regions' in e:counts['foreground_ownership_or_overlapping_expansion']+=1
 elif e=='A visible pose touches the image boundary':counts['original_outer_boundary_contact']+=1
 else:counts['grid_pose_assignment']+=1
assert sum(counts.values())==321
integration=json.loads((s/'integration-main-player-exit.json').read_text());assert integration['exit_code']==0
log=(s/'integration-main-player.log').read_text();assert 'PR122_BATCH_CANDIDATE_INTEGRATION_PASS actors=15 clips=204 death_directions=56' in log and 'ERROR:' not in log
reg_path=r/'data/pr122_native_locomotion_staging.json';reg=json.loads(reg_path.read_text());original=json.loads(subprocess.check_output(['git','show','HEAD:data/pr122_native_locomotion_staging.json'],cwd=r));preserved=0
for key,prior in original['actors'].items():
 current=reg['actors'][key]
 if key in ('transform:393','transform:267','transform:413'):assert current==prior;continue
 now={x['animation']:x for x in current['tracks']}
 for track in prior['tracks']:
  assert all(now[track['animation']][field]==track[field] for field in ('source','source_sha256','texture','geometry'));preserved+=1
assert preserved==83
keys=[k for k in reg['actors'] if k not in ('transform:393','transform:267','transform:413')]
for key in keys:
 actor=reg['actors'][key];actor.setdefault('verification',{})['actual_Main_Player_source_region_repair']=dict(status='PASS',evidence=str((evidence/'integration-main-player.log').relative_to(r)),frames_sha256=actor['frames_sha256'],clips=actor['native_track_count'],scope='Injected candidate; all available tracks; no production catalog switch',visual_quality='NOT_REVIEWED',physical_scale='NOT_VISUALLY_APPROVED' if 'native_profile' in actor else 'FRAME_FIXTURE_ONLY_NO_LOCOMOTION_REFERENCE',final_approvals_added=0)
write(reg_path,reg)
mp=r/'docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json';m=json.loads(mp.read_text())
# These are selection counts, never actor/quality approvals.
m['selected_locomotion_native_poses']=len(m['selected_locomotion_sheets'])*6;m['selected_detailed_action_native_poses']=len(m['selected_detailed_action_sheets'])*6;write(mp,m)
write(out/'remaining-errors.json',dict(schema='pr122-source-region-repair-remaining-v1',previous_source_holds=442,repaired_extraction_clips=121,remaining_source_holds=321,mutually_exclusive_primary_cause_counts=dict(counts),source_holds=remaining,fragment_ownership_holds=b['hold_candidates'],generation_holds=old_errors['generation_holds'],visual_anatomy_direction_contact_review='NOT_RUN; automatic source/region gates only',repeated_attempts='No source generation or repeated frame patching; ambiguous ownership remains HOLD.'))
summary=dict(repaired_extraction_clips=121,whole_pose_instead_of_fixed_cell=97,topology_owned_region_expansion=24,existing_normal_clips_preserved=83,original_pngs_modified=0,source_frames_regenerated=0,final_quality_approvals_added=0,actors_final_approved=2,active_actor_total=19,actors_unapproved=17,remaining_source_clips=321,missing_generation_clips=3,primary_causes=dict(counts),integration=dict(actors=15,clips=204,poses=1224,death_input_direction_cases=56,status='PASS_CANDIDATE_ONLY',sized_candidate_profiles=13,unsized_frame_fixtures=2,production_switches=0),approved_393_267_and_existing_413_records_unchanged=True,limitations='Whole pose/ownership and game playback pass are not visual approval. Semantic joints, knee bending, foot alternation, direction appearance and runtime size remain NOT_REVIEWED.')
write(out/'repair-summary.json',summary)
for n in ('repair-extraction.py','repair-summary.json','check-fragments.py','fragment-preflight.json','repair-fragments.py','fragment-repair-summary.json','grid-tests-final.log','incremental-tests-final.log','sizing-tests.log','integration-main-player.log','integration-main-player-exit.json','finalize.py'):
 shutil.copyfile(s/n,evidence/n)
# Pin current tools and all exact source outputs so unchanged filenames cannot
# authorize reuse after a checker/config change.
write(out/'evidence-pins.json',dict(tools={p:sha(r/p) for p in ['tools/stage_pr122_native_locomotion.py','tools/pr122_reviewed_runtime_layout.py','tools/pr122_reviewed_source_regions.py','tools/import_original_based_motion.py','tests/test_pr122_native_source_grid.py','tests/pr122_native_batch_candidate_test.gd']},evidence={str(p.relative_to(r)):sha(p) for p in evidence.iterdir() if p.is_file()},source_outputs=[dict(source=x['source'],sha256=x['source_sha256'],original_source=x['original_source']) for x in fixes]))
sys.path.insert(0,str(r/'tools'));import pr122_native_production_approvals as approvals;approvals.load_state(r)
resume=r/'docs/remake/TWILIGHT_PR122_RESUME_20261019.md'
with resume.open('a') as f:f.write('\n\n2026-10-23 source-region repair v01: corrected121 of442 source HOLD clips without regenerating or modifying any original PNG (97 fixed-cell truncation candidates now use exact whole-pose regions in original phase_grid3;24 foreground omissions fixed through existing alpha16/alpha100 topology ownership and32px minimum-owner-margin region expansion). Defaults retain phase_grid2; explicit source/layout/region grid agreement is checked. Five grid/ownership tests,10 incremental-analysis tests and7 sizing tests PASS. All180 previously staged candidate tracks revalidated after shared checker change; original83 normal tracks/source/texture/geometry preserved. Actual Main/Player candidate integration PASS:15 actors/204 clips/1224 poses,56 death input-direction cases including corpse terminal hold and rejected post-death attack/movement.13 run-sized profiles +2 unsized frame fixtures; production switches0, visual final approvals added0, approved2/19, unapproved17. Remaining321 source HOLD:245 non-six component count,64 foreign-body bounding regions,7 original outer-boundary contact,4 ownership/overlap failures,1 grid assignment. Three prior generation HOLDs unchanged; no blind retries. Exact current list: draft-first-pass-20261023/source-region-repair-v01/remaining-errors.json. Existing 393/267 approval certificates and413 record unchanged. No images/previews/full CI.\n')
print(json.dumps({'repaired':121,'remaining':321,'normal_preserved':83,'integration':'PASS','approval_preservation':'PASS'}))
