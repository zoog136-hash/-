#!/usr/bin/env python3
"""Collect immutable JSON references only; never run the final corpus audit."""
import hashlib,json
from pathlib import Path
W=Path('/workspace/legendary_work');P=W/'docs/remake/pr122-legendary-parallel';PREFIX=Path('docs/remake/pr122-legendary-parallel')
def read(path):return json.loads(path.read_text())
def ref(path):return {'path':'res://'+str(path.relative_to(W)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
def prepare():
 # Preserve every historical false gate rather than update it in place.
 gate=read(P/'remaining-findings-final-gate-prepared-v03.json');follow=read(P/'quality-v04/followup-delivery-evidence-v05.json')
 if follow['status']!='REMOTE_SAVED':raise ValueError('Only actual remotely saved evidence is admissible')
 gate.update(schema='pr122-legendary-final-reconciliation-gate-v05',all_possible_corrections_complete=False,local_integration_checks_complete=False,repository_head='ROOT_TO_SET_FINAL_FULL_COMMIT_AFTER_DELTA_GPU',asset_staging_freeze_head=follow['asset_freeze_commit'],active_staging=follow['staging'],active_manifest=follow['active_manifest'],output_stem='remaining-findings-final-v05',preparation_status='PREPARED_ONLY_FINAL_EXECUTIONS_0',additional_delivery_evidence=ref(P/'quality-v04/followup-delivery-evidence-v05.json'),generation_calls=0,PNG_reads=0)
 gate['additional_quality_batches']=[{'manifest':b['manifest'],'validations':[b['minimum_validation']],'remote_receipt':b['receipt']} for b in follow['raw_quality_followup_batches']]
 units={}
 for folder in ['quality-v03','quality-v04']:
  for path in sorted((P/folder/'source-visual').glob('qc*-review-v*.json')):
   view=read(path)
   if view['candidate'] in units and path.name<=units[view['candidate']].name:continue
   units[view['candidate']]=path
 if len(units)!=96:raise ValueError('Exactly96 new post-reset source review units expected')
 gate['additional_quality_visual_units']=[ref(units[c]) for c in sorted(units)]
 technical={r['path']:r for r in gate['targeted_technical_artifacts']}
 for folder in ['quality-v03','quality-v04']:
  for path in sorted((P/folder).glob('batch*-changed-source-technical-index-v01.json')):
   r=ref(path);technical[r['path']]=r
 gate['targeted_technical_artifacts']=list(technical.values())
 for group in follow['new_source_ownership_groups']:
  for b in group['batches']:gate['ownership_batches'].append({'manifest':b['manifest'],'validations':[b['validation']],'remote_receipt':b['receipt']})
 gate['native176_additional_cohorts']=[{'library':n['manifest'],'review_input':n['input'],'validations':[n['validation']],'remote_receipt':n['receipt']} for n in follow['new_native_registration_versions']]
 def ownership_receipt(version,batch):
  return next(b['receipt'] for g in follow['new_source_ownership_groups'] if g['version']==version for b in g['batches'] if b['batch']==batch)
 gate['guard_only_batches']=[{'selection':ref(P/'quality-v03/guard-only-ready-qc063-v07.json'),'manifest':ref(P/'quality-v03/guard-only-rebinding-library-v07.json'),'validations':[ref(P/'quality-v03/ownership-batch005-affected-validation-v07.json')],'remote_receipt':ownership_receipt('v07',5)}, {'selection':ref(P/'quality-v03/guard-only-ready-original-1-NW-hit-v09.json'),'manifest':ref(P/'quality-v03/guard-only-rebinding-library-v09.json'),'validations':[ref(P/'quality-v04/ownership-batch001-affected-validation-v10.json')],'remote_receipt':ownership_receipt('v10',1)}]
 gate['dependent35_current_status']=ref(P/'quality-v04/dependent35-and-guard6-final-status-v10.json')
 gate['expected_verified_correction_sources']=109;gate['expected_verified_correction_pose_occurrences']=604
 gate['expected_unique_ownership_sources']=721
 gate['integration_receipts']=[ref(P/name) for name in ['final-runtime-integration-reconciled-v01.json','staging-import-exclusion-validation-v01.json','final-github-ci-receipt-v01.json','final-github-ci-receipt-v02-completed-v01.json']]
 gate['pending_final_inputs']=['Root exact final-correction-render-integration-v01.json SHA and append integration_receipts','Root final repository HEAD including all evidence/docs','Root explicit both completion booleans true after checks, regardless of CI failure outcome']
 gate['historical_CI_input_commit']='a2dbbb01659e562980653c8d33898d3b7d761e58'
 gate['completion_is_not_CI_or_art_quality_approval']=True
 gate['helper_is_internal_duplicate_guard_not_user_reapproval']=True
 output=P/'remaining-findings-final-gate-prepared-v05.json'
 with output.open('x') as f:f.write(json.dumps(gate,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'prepared':str(output),'sha256':ref(output)['sha256'],'new_source_units':len(units),'audit_runs':0,'PNG_reads':0}))
if __name__=='__main__':prepare()
