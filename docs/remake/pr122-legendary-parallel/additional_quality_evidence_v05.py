#!/usr/bin/env python3
"""JSON-only exact evidence adapter for post-reset bounded correction cohorts.

This module is called only by the final gated runner. Unit tests use synthetic
metadata, never production PNGs/corpus. It adds no approvals or image calls.
"""
import reconcile_remaining_findings_v01 as core

def validate_unit(view,record,record_sha,revision):
 if view.get('frozen_review_sha256')!=core.FROZEN_SHA or record.get('frozen_review_sha256')!=core.FROZEN_SHA:raise ValueError('Exact frozen source required')
 if view['record_sha256']!=record_sha or revision['record_sha256']!=record_sha:raise ValueError('Exact reviewed raw record mismatch')
 if view['candidate']!=record['correction_candidate_id'] or core.slot_of(view)!=core.record_slot(record):raise ValueError('Candidate/actor/direction/action mismatch')
 if core.path_text(view['source'])!=core.path_text(record['source']) or view['source_sha256']!=record['source_sha256']:raise ValueError('Exact newly authored source mismatch')
 if view['SpriteFrames_sha256']!=record['output_spriteframes_sha256'] or view['SpriteFrames_sha256']!=revision['SpriteFrames_sha256']:raise ValueError('Exact sixframe resource SHA mismatch')
 if record.get('actor_approvals_added',0)!=0 or record.get('final_motion_approvals_added',0)!=0:raise ValueError('Cannot inherit a final approval')
 return True

def issue_resolution(view,record,issue):
 if core.path_text(issue['affected_source'])!=core.path_text(record['previous_source']) or issue['source_sha256']!=record['previous_source_sha256']:return None
 if any(i['cause']==issue['cause'] for i in view['remaining_issues']):return None
 if issue['cause']=='camera' and view['camera_result']=='RESOLVED_STATIC':return 'STATIC_CAMERA_ONLY'
 if issue['cause']=='identity_weapon_action' and view['identity_result']=='PRESERVED_STATIC' and view['camera_result']=='RESOLVED_STATIC' and view.get('motion_role_result')=='ARTICULATED_ORIGINAL_WEAPON_ATTACK_STATIC_SEQUENCE':return 'STATIC_ORIGINAL_WEAPON_ACTION_ONLY'
 return None

def collect(e,gate,frozen):
 originals={i['issue_id']:i for i in frozen['visual_findings']};saved={};resolutions={};remaining=[];records={};units=[]
 for b in gate.get('additional_quality_batches',[]):
  _,receipt_sha,commit=e.remote(b['remote_receipt']);lib,lib_sha=e.artifact(b['manifest']);e.committed_json(b['manifest']['path'],commit,lib_sha);checks=core.passed_records(e,b.get('validations',[]))
  for ref in b.get('validations',[]):e.committed_json(ref['path'],commit,e.artifact(ref)[1])
  for rev in lib.get('revisions',[]):
   check=checks.get(core.path_text(rev['record']))
   if check and check['row'].get('status')=='PASS' and check['row'].get('frames_reached')==6:records[core.path_text(rev['record'])]=(rev,receipt_sha,commit,b['remote_receipt']['path'])
 for ref in gate.get('additional_quality_visual_units',[]):
  view,unit_sha=e.artifact(ref);e.committed_json(ref['path'],e.head,unit_sha);key=core.path_text(view['record'])
  if key not in records:raise ValueError('Changed source review has no exact REMOTE_SAVED sixframe record')
  rev,receipt_sha,commit,receipt_path=records[key];record,record_sha=e.json(key,view['record_sha256']);e.committed_json(key,commit,record_sha);validate_unit(view,record,record_sha,rev)
  cid=view['candidate']
  if cid in saved:raise ValueError('Choose only the latest one immutable visual unit per candidate')
  saved[cid]={'candidate':cid,'record':key,'record_sha256':record_sha,'source':view['source'],'source_sha256':view['source_sha256'],'newly_authored_poses':record.get('newly_authored_poses_requested',record.get('newly_authored_poses',0)),'remote_commit':commit,'visual_review':ref,'visual_review_sha256':unit_sha}
  for old in record.get('frozen_error_findings',[]):
   issue=originals.get(old.get('issue_id'))
   if not issue or core.canonical(issue)!=core.canonical(old):continue
   scope=issue_resolution(view,record,issue)
   if scope:resolutions[issue['issue_id']]={'issue_id':issue['issue_id'],'previous_source':issue['affected_source'],'previous_source_sha256':issue['source_sha256'],'corrected_source':view['source'],'corrected_source_sha256':view['source_sha256'],'record':key,'record_sha256':record_sha,'visual_review':ref['path'],'visual_review_sha256':unit_sha,'remote_receipt':receipt_path,'remote_receipt_sha256':receipt_sha,'remote_commit':commit,'scope':scope}
  for issue in view['remaining_issues']:remaining.append({'actor':view['actor'],'direction':view['direction'],'role':view['role'],'source':view['source'],'source_sha256':view['source_sha256'],'candidate':cid,**issue})
  units.append({'candidate':cid,'review':ref,'record_sha256':record_sha,'remote_commit':commit})
 return {'resolutions':resolutions,'remaining':remaining,'saved':list(saved.values()),'unit_proofs':units,'source_or_PNG_reads':0,'approvals_added':0}

def native_followups(e,gate,original):
 rows={tuple(x['slot']):x for x in original['slots']};events=[]
 for n in gate.get('native176_additional_cohorts',[]):
  follow=core.native_registration_evidence(e,{'native176':n});events.append(follow)
  for row in follow['slots']:rows[tuple(row['slot'])]=row
 out=dict(original,verified_clips=len(rows),verified_frames=6*len(rows),slots=list(rows.values()),additional_revision_events=events,scope='TECHNICAL_REGISTRATION_ONLY',camera_or_motion_approvals=0)
 return out
