#!/usr/bin/env python3
"""Metadata-only final status of original35 dependent jobs and explicit guard6."""
import json,hashlib,collections
from pathlib import Path
W=Path('/workspace/legendary_work');P=W/'docs/remake/pr122-legendary-parallel'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def ref(p):return {'path':str(p.relative_to(W)),'sha256':sha(p)}
def run():
 old=read(P/'quality-v03/dependent35-current-status-v09.json');rows=[]
 completed={}
 for b in [309,310,313,314]:
  lp=Path(f'/workspace/legendary_delivery_logs/quality-batch{b}-delivery.json');receipt=read(lp)
  if receipt['status']!='REMOTE_SAVED':raise ValueError('No pending remote accepted')
  mp=P/f'quality-v02/batch{b}-revision-library-v02.json'
  for rev in read(mp)['revisions']:completed[rev['correction_candidate_id']]=(b,lp,receipt,rev,mp)
 for original in old['jobs']:
  row=dict(original);cid=row['correction_candidate_id']
  if cid in completed:
   b,lp,receipt,rev,mp=completed[cid]
   row.update(category='NEW18_COMPLETED_ONCE',state='PNG_READY_REMOTE_SAVED',batch=b,generation_attempts=1,remote_receipt={'path':str(lp),'sha256':sha(lp)},remote_sha=receipt['remote_sha'],raw_record=rev['record'],raw_record_sha256=rev['record_sha256'],manifest=ref(mp))
  elif cid in ['qc063','qc098']:row['category']='GUARD_ONLY_NO_NEW_IMAGE'
  else:
   row.update(category='FINAL15_WAIT_NO_RETRY',generation_calls_allowed=0)
   pcid=row['parent_candidate']
   if pcid in ['qc025','qc026']:
    vp=P/f'quality-v04/source-visual/{pcid}-review-v01.json';v=read(vp)
    if v['identity_result']!='HOLD':raise ValueError('245 final parent identity HOLD expected')
    row.update(state='WAIT_IDENTITY_PARENT_HOLD',wait_cause='PARENT_IDENTITY_HOLD_NO_RETRY',parent_visual_review=ref(vp),parent_remaining_issues=v['remaining_issues'],historical429_preserved=True,quota_wait_current=False)
   elif row.get('parent_camera_result')=='HOLD':row['state']='WAIT_CAMERA_PARENT_HOLD'
   elif row.get('parent_identity_result')=='HOLD':row['state']='WAIT_IDENTITY_PARENT_HOLD'
   else:row['state']='WAIT_IDLE_ROLE_PARENT_HOLD'
  rows.append(row)
 if collections.Counter(r['category'] for r in rows)!=collections.Counter({'NEW18_COMPLETED_ONCE':18,'FINAL15_WAIT_NO_RETRY':15,'GUARD_ONLY_NO_NEW_IMAGE':2}):raise ValueError('Original35 status exact count drift')
 guards=read(P/'quality-v03/frozen-guard-only-adjudication-v07.json')['selections'];grows=[]
 for g in guards:
  a=g['slot'][0];d=g['slot'][1];role=g['slot'][2];resolved=(a,d,role) in [('transform:178','NW','hit'),('transform:1','NW','hit')]
  grows.append({'slot':g['slot'],'candidate':g.get('candidate'),'frozen_issue_id':g['frozen_issue_id'],'frozen_source':g['frozen_source'],'frozen_source_sha256':g['frozen_source_sha256'],'state':'RESOURCE_ONLY_REBOUND_EVIDENCE_REQUIRED' if resolved else 'HOLD_PARENT_CAMERA_NO_RETRY','resolved_claim_requires_exact_remote_SHA_Godot_and_middle4_RGBA':resolved,'new_image_calls_allowed':0})
 out={'schema':'legendary-final-original-wait35-and-guard6-v10','frozen_review_sha256':old['frozen_review_sha256'],'previous_snapshot':ref(P/'quality-v03/dependent35-current-status-v09.json'),'counts':dict(collections.Counter(r['category'] for r in rows)),'final_wait15_causes':dict(collections.Counter(r['state'] for r in rows if r['category']=='FINAL15_WAIT_NO_RETRY')),'jobs':rows,'explicit_guard_only_six':grows,'guard_only_units':{'required':6,'resource_rebound_claims_pending_final_evidence_check':2,'HOLD':4},'PNG_reads':0,'image_calls':0,'corpus_audit_runs':0,'final_approved':0}
 target=P/'quality-v04/dependent35-and-guard6-final-status-v10.json'
 with target.open('x') as f:f.write(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'path':str(target),'sha256':sha(target),'counts':out['counts'],'wait_causes':out['final_wait15_causes']}))
if __name__=='__main__':run()
