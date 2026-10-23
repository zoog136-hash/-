#!/usr/bin/env python3
"""Exact JSON-only guard-only closure; no image inference or broad approval."""
import reconcile_remaining_findings_v01 as core

def validate_preservation(selection,record,selection_sha,revision,validation,parent_checks):
 if record.get('guard_only_selection_sha256')!=selection_sha or record.get('frozen_guard_issue')!=selection['frozen_issue_id']:raise ValueError('Guard selection/issue must match exactly')
 if not record.get('middle_four_RGBA_bindings_preserved'):raise ValueError('No explicit middle preservation proof')
 checks={f['index']:f for f in record['automatic_checks']}
 if set(checks)!=set(range(6)):raise ValueError('Six exact RGBA checks required')
 for frame in selection['middle_frames_preserve_exact']+selection['guard_frames_preserve_exact']:
  actual=checks[frame['index']]
  if any(actual.get(k)!=frame.get(k) for k in ['region','margin','rgba_sha256']):raise ValueError('Preserved guard/middle pixel coordinates differ')
 if validation.get('status')!='PASS' or validation.get('frames_reached')!=6:raise ValueError('Actual sixframe playback required')
 if not any(x.get('slot')==selection['slot'] and x.get('status')=='PASS' and x.get('compared_parent_guards')==2 and not x.get('errors') for x in parent_checks):raise ValueError('Exact original parent transforms required')
 if core.record_slot(record)!=tuple(selection['slot']) or revision['slot']!=selection['slot']:raise ValueError('Guard clip identity mismatch')
 inherited=revision.get('inherited_guard_checks',[])
 if {r.get('action_phase') for r in inherited}!={0,5} or any(r['parent_record_sha256']!=selection['parent_record_sha256'] for r in inherited):raise ValueError('Exact healthy parent binding required')
 return True

def collect(e,gate,frozen):
 originals={x['issue_id']:x for x in frozen['visual_findings']};closed={};proofs=[]
 for b in gate.get('guard_only_batches',[]):
  _,receipt_sha,commit=e.remote(b['remote_receipt']);lib,lib_sha=e.artifact(b['manifest']);e.committed_json(b['manifest']['path'],commit,lib_sha)
  selected,selected_sha=e.artifact(b['selection']);e.committed_json(b['selection']['path'],commit,selected_sha)
  checks=core.passed_records(e,b['validations']);parent_checks=[]
  for ref in b['validations']:
   report,sha=e.artifact(ref);e.committed_json(ref['path'],commit,sha);parent_checks+=report.get('guard_parent_checks',[])
  for s in selected['selections']:
   issue=originals.get(s['frozen_issue_id'])
   if not issue or issue['cause']!='camera' or core.path_text(issue['affected_source'])!=core.path_text(s['frozen_source']) or issue['source_sha256']!=s['frozen_source_sha256']:raise ValueError('Only exact frozen guard-camera finding can close')
   rev=next(x for x in lib['revisions'] if x['slot']==s['slot']);record,rec_sha=e.json(rev['record'],rev['record_sha256']);e.committed_json(rev['record'],commit,rec_sha)
   check=checks.get(core.path_text(rev['record']))
   if not check:raise ValueError('Guard record lacks exact changed-only playback report')
   validate_preservation(s,record,selected_sha,rev,check['row'],parent_checks)
   parent,sparent=e.json(s['parent_record'],s['parent_record_sha256']);e.committed_json(s['parent_record'],commit,sparent)
   if not s.get('healthy_parent',{}).get('quality_review'):raise ValueError('Healthy static parent evidence required')
   parent_review,parent_review_sha=e.artifact(s['healthy_parent']['quality_review']);e.committed_json(s['healthy_parent']['quality_review']['path'],commit,parent_review_sha)
   reviewed=next((r for r in parent_review.get('records',[]) if r.get('record_sha256')==sparent),None)
   if not reviewed or any(reviewed.get(k)!=v for k,v in [('camera_result','RESOLVED_STATIC'),('identity_result','PRESERVED_STATIC'),('idle_role_result','LIVING_IDLE_STATIC'),('idle_guard_result','HEALTHY_STATIC')]) or reviewed.get('reviewed_guard_phases')!=[0,5]:raise ValueError('No exact healthy static parent record')
   parent_source=next(x for x in s['parent_source_files'] if core.path_text(x['path'])==core.path_text(s['guard_frames_preserve_exact'][0]['source']))
   proof={'issue_id':issue['issue_id'],'previous_source':issue['affected_source'],'previous_source_sha256':issue['source_sha256'],'corrected_source':parent_source['path'],'corrected_source_sha256':parent_source['sha256'],'record':rev['record'],'record_sha256':rec_sha,'selection':b['selection'],'remote_receipt':b['remote_receipt']['path'],'remote_receipt_sha256':receipt_sha,'remote_commit':commit,'scope':'EXPLICIT_GUARD_CAMERA_ONLY_MIDDLE4_RGBA_PRESERVED','new_image_calls':0,'other_art_HOLDs_unchanged':True}
   closed[issue['issue_id']]=proof;proofs.append(proof)
 return closed,proofs
