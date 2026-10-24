import sys,json,hashlib,subprocess,collections,shutil
from pathlib import Path
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-spacing-repair-20261023');base=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023';out=base/'spacing-repair-v01';ev=out/'evidence';ev.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,o:p.write_text(json.dumps(o,ensure_ascii=False,indent=2)+'\n')
assert json.loads((s/'assembly-main-player-exit.json').read_text())['exit_code']==0
log=(s/'assembly-main-player.log').read_text();assert 'PR122_BATCH_CANDIDATE_INTEGRATION_PASS actors=2 clips=39 death_directions=16' in log and 'ERROR:' not in log
repaired=json.loads((s/'assembled-staging-summary.json').read_text())['repaired'];assert len(repaired)==2
baseline=json.loads((base/'source-region-repair-v01/remaining-errors.json').read_text());fixed={x['original_source'] for x in repaired};remaining=[x for x in baseline['source_holds'] if x['source'] not in fixed];assert len(remaining)==319
variants=json.loads((s/'boundary-source-results.json').read_text());assert len(variants)==4 and all(x['status']=='HOLD_SOURCE_QC' for x in variants)
for row in remaining:
 row['followup_checks']=[str((ev/p).relative_to(r)) for p in ('partition-preflight.json','tight-region-preflight.json')]
 row['alternative_sources']=[dict(source=x['source'],sha256=x['sha256'],status=x['status'],cause=x['cause']) for x in variants if x['original_source']==row['source']]
write(out/'remaining-errors.json',dict(schema='pr122-spacing-repair-remaining-v1',previous_source_holds=321,repaired_source_clips=2,remaining_source_holds=319,source_holds=remaining,generation_holds=baseline['generation_holds'],new_boundary_variants=variants,method_stop=dict(attempted=4,planned_unattempted=3,reason='Same generation method produced disconnected components/overlap in all four independent clips; further calls stopped. No identical-source retry, threshold relaxation, component deletion or guessed connections.'),final_quality_approvals_added=0,visual_quality='NOT_REVIEWED'))
regpath=r/'data/pr122_native_locomotion_staging.json';reg=json.loads(regpath.read_text());old=json.loads(subprocess.check_output(['git','show','HEAD:data/pr122_native_locomotion_staging.json'],cwd=r));preserved=0
# Previous evidence pins prove the common checker and importer are unchanged.
pins=json.loads((base/'source-region-repair-v01/evidence-pins.json').read_text())['tools']
for p,h in pins.items():assert sha(r/p)==h
for key,prior in old['actors'].items():
 current=reg['actors'][key]
 if key in ('transform:393','transform:267','transform:413'):assert current==prior;continue
 tracks={t['animation']:t for t in current['tracks']}
 for t in prior['tracks']:
  assert all(tracks[t['animation']][f]==t[f] for f in ('source','source_sha256','texture','geometry'));preserved+=1
 # A measured technical verification marker required by the existing cache
 # guard was absent in earlier checkpoint records. Record the existing verified
 # result and its evidence, without changing any approval or checker code.
 for t in current['tracks']:
  assert sha(r/t['source'])==sha(r/t['texture'])==t['source_sha256']
  assert (r/t['source']).with_suffix('.geometry.json').is_file()
 current.setdefault('verification',{})['source_sha256_and_saved_geometry']='PASS'
 current['verification']['source_geometry_verification_basis']=dict(prior_204='source-region-repair-v01/evidence: unchanged importer/checker pins, actual saved-geometry verification and exact track preservation',new_2='spacing-repair-v01: immutable assembly proof and guarded staging fresh analysis',scope='Technical source/saved geometry only; no visual or actor approval')
assert preserved==204
for key in ('transform:135','transform:346'):
 entry=reg['actors'][key];entry['verification']['actual_Main_Player_spacing_repair']=dict(status='PASS',evidence=str((ev/'assembly-main-player.log').relative_to(r)),frames_sha256=entry['frames_sha256'],clips=entry['native_track_count'],scope='Injected candidate; unchanged production catalog',visual_quality='NOT_REVIEWED',final_approvals_added=0)
write(regpath,reg)
mp=r/'docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json';m=json.loads(mp.read_text());m['selected_locomotion_native_poses']=len(m['selected_locomotion_sheets'])*6;m['selected_detailed_action_native_poses']=len(m['selected_detailed_action_sheets'])*6;write(mp,m)
# Retain the four QC-failed originals and exact requests as HOLD sources;
# never select them or increase completion counters.
for name in ['check-source-partitions.py','partition-preflight.json','check-tight-regions.py','tight-region-preflight.json','assemble-two.py','assembly-results.json','stage-assembled.py','assembled-staging-summary.json','prepare-boundary-requests.py','preserve-boundary-results.py','boundary-source-results.json','check-generated-spacing.py','generated-spacing-preflight.json','assembly-main-player.log','assembly-main-player-exit.json','finalize.py']:
 shutil.copyfile(s/name,ev/name)
for p in s.glob('boundary-request-*.json'):shutil.copyfile(p,ev/p.name)
write(out/'repair-summary.json',dict(source_clips_reviewed=321,existing_drafts_repaired=2,repaired=[dict(key=x['key'],direction=x['direction'],role=x['role']) for x in repaired],new_frame_sources_generated=4,new_frames_generated=24,new_frame_source_holds=4,normal_clips_preserved=204,remaining_source_holds=319,existing_missing_generation_holds=3,technical_integration=dict(actors=2,clips=39,death_input_direction_cases=16,status='PASS_CANDIDATE_ONLY'),final_quality_approvals_added=0,approved_active_actors=2,active_total=19,unapproved_actors=17,limitations='All alpha>16 owned foreground retained by existing reviewed-pose assembler. Low-alpha residual source pixels14,564 and2,806 (alpha<=16) remain in the immutable original sheets and are explicitly recorded, not rendered as reviewed-body regions. Semantic joints, facing, foot contacts and physical scale remain unreviewed.'))
sys.path.insert(0,str(r/'tools'));import pr122_native_production_approvals as approvals;approvals.load_state(r)
with (r/'docs/remake/TWILIGHT_PR122_RESUME_20261019.md').open('a') as f:f.write('\n\n2026-10-23 spacing repair v01: reviewed remaining321 once, then refined only65 source-region/phase candidates. Strict existing reviewed-pose assembler safely repaired2 clips:135 S death and346 N hit, all original owned alpha16 foreground retained, no raster resampling; explicit output region finalization used the same immutable atlas and preserved error receipt. Original low-alpha<=16 residuals14564/2806 remain stored in original source and are not certified as reviewed body pixels. Normal204 native tracks/source/texture/geometry preserved. Main/Player affected-candidate integration PASS:2 actors,39 clips,16 death input cases. Boundary reauthoring attempted only4 clips (412 N idle,412 W run,399 E run,242 N attack),24 generated frames; all fail unchanged component/foreign-body guards and are preserved as HOLD, never selected. Further3 planned boundary calls stopped for repeated method failure. Remaining319 source HOLD +3 prior missing-generation HOLD. Final approvals added0, approved2/19; visual anatomy/contact/facing/scale still unreviewed. Existing source SHA/saved-geometry technical PASS marker now records the measured204+2 verification so the existing version-pinned reuse guard can work after commit; no checker code changed. Current detailed lists and exact failed variants: draft-first-pass-20261023/spacing-repair-v01/remaining-errors.json. No CI, preview or chat images.\n')
print(json.dumps({'repaired':2,'remaining':319,'generated_HOLD_sources':4,'normal_preserved':204,'integration':'PASS','approved_history':'PRESERVED'}))
