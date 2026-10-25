import sys,json,hashlib,subprocess,collections,shutil
from pathlib import Path
r=Path('/workspace/twilight');s=Path('/workspace/scratch/pr122-batch-review-20261023');dest=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023/batch-review-v01';dest.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
write=lambda p,x:p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
rows=[json.loads(x) for x in (s/'audit-results.jsonl').read_text().splitlines()];summary=json.loads((s/'audit-summary.json').read_text());staging=json.loads((s/'stage-summary.json').read_text());assert json.loads((s/'integration-main-player-exit.json').read_text())['exit_code']==0
log=(s/'integration-main-player.log').read_text();assert 'PR122_BATCH_CANDIDATE_INTEGRATION_PASS actors=14 clips=83 death_directions=8' in log and 'ERROR:' not in log
holds=[];rechecks=[]
base=r/'docs/remake/evidence/pr122-mythic-detailed/batch03';old_scratch=Path('/workspace/scratch/pr122-all19-first-pass-20261023')
for k,d,role in [(399,'S','death'),(367,'SE','hit'),(411,'NW','hit')]:
 p=base/f'transform_{k}-{d}-{role}-generation-HOLD-v01.json';h=json.loads(p.read_text());q=json.loads((old_scratch/f'request-{k}-{d}-{role}.json').read_text());assert h['generation_request']==q['generation_request'];assert h['source'] is None
 paths=[base/f'transform_{k}-{d}-{role}-draft-v01.png',base/f'transform_{k}-{d}-{role}-draft-v01.json'];assert all(not x.exists() for x in paths)
 refs={h['reference'].removeprefix('res://'):h['reference_sha256']};refs.update({str(Path(p).relative_to(r)):v for p,v in h.get('additional_reference_sha256',{}).items()})
 assert all((r/p).is_file() and sha(r/p)==v for p,v in refs.items())
 rechecks.append(dict(key=h['key'],direction=d,role=role,status=h['status'],request_matches_saved=True,reference_hashes_match=True,saved_output_present=False,retried=False,record=str(p.relative_to(r)),record_sha256=sha(p),cause=h['generation_error_observed']))
reg_path=r/'data/pr122_native_locomotion_staging.json';reg=json.loads(reg_path.read_text());baseline=json.loads(subprocess.check_output(['git','show','HEAD:data/pr122_native_locomotion_staging.json'],cwd=r))
for key in ('transform:393','transform:267','transform:413'):assert reg['actors'][key]==baseline['actors'][key]
for item in staging['actors']:
 actor=reg['actors'][item['key']];actor.setdefault('verification',{})['actual_Main_Player_batch_candidate']=dict(status='PASS',evidence=str((dest/'integration-main-player.log').relative_to(r)),scope='Injected candidate only; default production catalog unchanged',clips=item['clips'],physical_scale='NOT_VALIDATED' if item['profile']!='BOUND_UNAPPROVED_CANDIDATE' else 'COMPUTED_FROM_AUTHORED_RUN_NOT_VISUALLY_APPROVED',visual_quality='NOT_REVIEWED',final_approvals_added=0)
write(reg_path,reg)
# The final inventory retains all original draft/error records. No approval reset.
for item in rows:
 if item['errors']:holds.append({k:item[k] for k in ('key','direction','role','source','sha256','errors','visible_cell_boundary_pixel_counts') } | {'geometry_error':item.get('geometry_error')})
write(dest/'remaining-errors.json',dict(schema='pr122-batch-errors-v1',source_review_scope='525 new first-draft clips; 393/267 frozen approval proofs and 413 unchanged records preserved',source_holds=holds,generation_holds=rechecks,remaining_source_clips=len(holds),remaining_missing_clips=3,visual_review='NOT_RUN; no previews or image attachments',semantic_defects='Direction, anatomy, equipment, knee folding and foot alternation are not certified by these pixel/geometry checks. They remain unreviewed, not PASS.'))
for name in ('audit-results.jsonl','audit-summary.json','audit.py','stage-safe-batch.py','stage-summary.json','sizing-tests.log','integration-main-player.log','integration-main-player-exit.json'):
 shutil.copyfile(s/name,dest/name)
shutil.copyfile(s/'finalize-review.py',dest/'finalize-review.py')
write(dest/'review-summary.json',dict(clips_reviewed=525,poses_reviewed=3150,error_free_sources=83,source_holds=442,boundary_contact=381,strict_geometry_hold=345,groups_overlap=True,missing_generation_holds=3,source_regenerated=0,repacked_new_sources=79,preserved_existing_packed_sources=4,staged_clips=83,profile_bound_actors=11,frame_fixture_only_actors=3,actual_Main_Player_candidate='PASS:14 actors/83 clips; S death all8inputdirections terminal hold',default_catalog_switches=0,final_quality_approvals_added=0,final_approved_actors=2,remaining_unapproved_actors=17,approved_393_267_and_existing_413_records_unchanged=True,normal_source_correction='Border contact may be clipping or ambiguous ownership; no padding/cropping/guessing was used to claim repair. Disconnected components need explicit art/ownership review; no components discarded.'))
# Validate the production approval certificates after all modifications.
sys.path.insert(0,str(r/'tools'));import pr122_native_production_approvals as approvals
approvals.load_state(r)
resume=r/'docs/remake/TWILIGHT_PR122_RESUME_20261019.md'
with resume.open('a') as f:f.write('\n\n2026-10-23 batch review v01: one complete automated pass over 525 new clips (3150 poses), no original source regenerated. Source SHA/6-phase uniqueness intact. Fixed error inventory: 442 source HOLD clips (381 visible cell-boundary contact; 345 strict geometry HOLD, overlapping) plus 3 missing-generation HOLDs (399 S death output unavailable; 367 SE hit output unavailable; 411 NW hit service moderation rejection). All three saved requests/reference hashes match, no hidden completed output, no blind retry. Safe 83 clips staged across 14 actors; 79 lossless new packings + 4 existing packings reused. Previous 412 SW idle newly found unsafe at internal cell boundary: selection removed, every old PNG/resource retained. Fixed walk-required sizing for new run-only scope; existing walking precedence unchanged; 7 sizing tests PASS. Actual Main/Player injected-candidate integration PASS: 14 actors,83 clips,8 death input directions with terminal hold. 11 candidate profiles use run reference;3 frame-only injected fixtures still lack a locomotion sizing reference. No default production switches; visual review NOT_RUN, final approvals added0, approved2/19, unapproved17. 393/267 certificates and413 record preserved. Exact lists and evidence: draft-first-pass-20261023/batch-review-v01/remaining-errors.json. No visual, anatomical, direction-appearance or foot-contact PASS is implied.\n')
print(json.dumps({'source_holds':len(holds),'generation_holds':len(rechecks),'integration':'PASS','approved_preservation':'PASS'}))
