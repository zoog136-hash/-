#!/usr/bin/env python3
"""Reconcile frozen findings against completed JSON proofs; never open PNGs.

Preparation: --prepare
Final single execution, only after the root's completed integration gate:
  --finalize --gate /path/to/final-completion-gate.json
No generation, image decoding, resource changes, git mutations or network calls.
"""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess

WORK=Path('/workspace/legendary_work')
REPO=Path('/workspace/legendary_repo')
PREFIX=Path('docs/remake/pr122-legendary-parallel')
FROZEN_SHA='bce7e7260712a27515627806a88690158f47bf8ddf4cd172dba5b5ba3eee00c6'
BASELINE='6bcd94f5a0868426ac4b5ae0ebffd93916fad1ba'
HEX=re.compile(r'^[0-9a-f]{64}$')
COMMIT=re.compile(r'^[0-9a-f]{40}$')

def digest(raw):return hashlib.sha256(raw).hexdigest()
def path_text(p):return str(p).removeprefix('res://')
def canonical(v):return json.dumps(v,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
def slot_of(row):
 if 'slot' in row:return tuple(row['slot'])
 return ('transform:'+str(row['actor']).removeprefix('transform:'),row['direction'],row['role'])
def record_slot(row):return (row['key'],row['direction'],row['role'])
def pretty_slot(slot):return '/'.join(slot)
def safe_json(path):
 path=Path(path)
 if path.suffix!='.json':raise ValueError('Only JSON evidence may be read: '+str(path))
 raw=path.read_bytes();return json.loads(raw),digest(raw)
def write_new(path,value):
 path=Path(path).resolve()
 if not path.is_relative_to((WORK/PREFIX).resolve()):raise ValueError('Output must use the dedicated WORK documentation prefix')
 path.parent.mkdir(parents=True,exist_ok=True)
 with path.open('x') as f:
  if isinstance(value,str):f.write(value)
  else:json.dump(value,f,ensure_ascii=False,indent=2);f.write('\n')

class Evidence:
 def __init__(self,repo,head):self.repo=Path(repo);self.head=head;self.cache={};self.rejected=[]
 def json(self,p,expected=None):
  p=Path(p) if str(p).startswith('/') else self.repo/path_text(p)
  key=str(p)
  if key not in self.cache:self.cache[key]=safe_json(p)
  data,sha=self.cache[key]
  if expected is not None and sha!=expected:raise ValueError('Evidence SHA mismatch: '+key)
  return data,sha
 def artifact(self,ref):
  if not ref or not HEX.fullmatch(ref.get('sha256','')):raise ValueError('An explicit artifact path and SHA256 are required')
  return self.json(ref['path'],ref['sha256'])
 def committed_json(self,path,commit,expected):
  p=path_text(path)
  if Path(p).is_absolute():
   absolute=Path(p).resolve()
   if absolute.is_relative_to(self.repo.resolve()):p=absolute.relative_to(self.repo.resolve()).as_posix()
   elif absolute.is_relative_to(WORK.resolve()):p=absolute.relative_to(WORK.resolve()).as_posix()
   else:raise ValueError('Committed evidence must map to a repository JSON path')
  if '..' in Path(p).parts:raise ValueError('Repository evidence path escapes its root')
  if Path(p).suffix!='.json' or not COMMIT.fullmatch(commit):raise ValueError('Only JSON at a full commit SHA may be checked')
  ancestor=subprocess.run(['git','-C',str(self.repo),'merge-base','--is-ancestor',commit,self.head],capture_output=True)
  if ancestor.returncode:raise ValueError('Receipt commit is not an ancestor of the final head: '+commit)
  result=subprocess.run(['git','-C',str(self.repo),'show',commit+':'+p],capture_output=True)
  if result.returncode or digest(result.stdout)!=expected:raise ValueError('Committed JSON proof mismatch: '+p)
 def remote(self,ref):
  row,sha=self.artifact(ref)
  if row.get('status')!='REMOTE_SAVED':raise ValueError('Pending/failed receipt cannot close an issue')
  commit=row.get('commit_sha') or row.get('remote_sha')
  if not COMMIT.fullmatch(commit or ''):raise ValueError('Receipt has no full saved commit SHA')
  return row,sha,commit

def valid_translation_proof(proof,known,technical_sha):
 """Validate the upstream lossless ownership proof, not the source image."""
 if proof.get('source')!=known['source'] or proof.get('source_sha256')!=known['sha256']:return False
 if proof.get('source_review_sha256')!=technical_sha or proof.get('baseline_sha')!=BASELINE:return False
 if proof.get('resampled') is not False or proof.get('recolored') is not False or proof.get('newly_authored_poses')!=0:return False
 if not HEX.fullmatch(proof.get('output_sha256','')):return False
 poses=proof.get('poses',[])
 if not poses or len({p['original_phase'] for p in poses})!=len(poses):return False
 if known.get('grid') and (proof.get('grid')!=known['grid'] or len(poses)!=known['grid'][0]*known['grid'][1]):return False
 if sum(p.get('foreground_pixels',0) for p in poses)!=proof.get('source_foreground_pixels'):return False
 for p in poses:
  if len(p.get('translation',[]))!=2 or not all(isinstance(v,int) for v in p['translation']):return False
  if not all(HEX.fullmatch(p.get(k,'')) for k in ('source_positions_sha256','source_rgba_sha256')):return False
 return True

def passed_records(evidence,reports):
 """Later targeted recovery reports supersede an earlier result for that path."""
 out={}
 for ref in reports:
  report,sha=evidence.artifact(ref)
  for row in report.get('records',[]):out[path_text(row['record'])]={'row':row,'report':ref['path'],'report_sha256':sha}
 return out

def ownership_evidence(e,gate,technical,technical_sha):
 known={x['source']:dict(x,_review_sha256=technical_sha,_origin='frozen') for x in technical['source_findings']}; accepted={}; batches=[];followups=[]
 for ref in gate.get('targeted_technical_artifacts',[]):
  artifact,artifact_sha=e.artifact(ref);e.committed_json(ref['path'],e.head,artifact_sha)
  if artifact.get('baseline_sha')!=BASELINE:raise ValueError('Targeted technical artifact baseline mismatch')
  if artifact.get('frozen_review_sha256',FROZEN_SHA)!=FROZEN_SHA:raise ValueError('Targeted technical artifact frozen SHA mismatch')
  for row in artifact.get('source_findings',[]):
   source=row['source'];old=known.get(source)
   if old and old['sha256']!=row['sha256']:raise ValueError('Targeted source cannot change an existing frozen source SHA')
   if not old:
    if '/quality-v02/' not in source or not HEX.fullmatch(row.get('sha256','')):raise ValueError('Followup must identify an exact versioned changed quality source')
    known[source]=dict(row,_review_sha256=artifact_sha,_origin='targeted_quality_followup');followups.append({'source':row,'artifact':ref['path'],'artifact_sha256':artifact_sha})
 for b in gate.get('ownership_batches',[]):
  try:
   receipt,receipt_sha,commit=e.remote(b['remote_receipt']);manifest,manifest_sha=e.artifact(b['manifest'])
   if manifest.get('baseline_sha')!=BASELINE:raise ValueError('Ownership baseline mismatch')
   e.committed_json(b['manifest']['path'],commit,manifest_sha)
   reports=passed_records(e,b['validations']);revisions={}
   for ref in b['validations']:e.committed_json(ref['path'],commit,e.artifact(ref)[1])
   for rev in manifest.get('revisions',[]):
    rec,rec_sha=e.json(rev['record'],rev['record_sha256']);path=path_text(rev['record'])
    e.committed_json(path,commit,rec_sha)
    check=reports.get(path)
    if not check or check['row'].get('status')!='PASS' or check['row'].get('frames_reached')!=6:continue
    if record_slot(rec)!=tuple(rev['slot']):raise ValueError('Corrected record slot mismatch')
    if rec.get('output_spriteframes_sha256')!=rev.get('SpriteFrames_sha256'):raise ValueError('Corrected resource metadata SHA mismatch')
    revisions[tuple(rev['slot'])]=(rec,rev,check)
   outcomes=[x for x in manifest.get('source_outcomes',[]) if x.get('status')=='INTEGER_TRANSLATION_PROOF_PASS']
   batch_ok=[]
   for outcome in outcomes:
    source=outcome['source'];base=known.get(source)
    if not base:
     e.rejected.append({'kind':'ownership_source','source':source,'receipt':b['remote_receipt']['path'],'reason':'Source has no exact frozen or explicitly pinned targeted technical artifact; other sources in this batch continue'})
     continue
    proof,proof_sha=e.json(outcome['proof']);e.committed_json(outcome['proof'],commit,proof_sha)
    if not valid_translation_proof(proof,base,base['_review_sha256']):raise ValueError('Invalid translation proof: '+source)
    dependents={tuple(x['slot']) for x in base['dependents']};covered=[]
    for slot in dependents:
     item=revisions.get(slot)
     if not item:continue
     rec,rev,check=item
     if path_text(outcome['proof']) not in [path_text(p) for p in rec.get('isolation_proofs',[])]:continue
     files=rec.get('source_files',[])
     has_output=(path_text(rec.get('source',''))==proof['output'] and rec.get('source_sha256')==proof['output_sha256']) or any(path_text(x.get('path',x.get('source','')))==proof['output'] and x.get('sha256')==proof['output_sha256'] for x in files)
     if not has_output:continue
     checks=rec.get('automatic_checks',[])
     if len(checks)!=6 or {x.get('index') for x in checks}!=set(range(6)) or any(not HEX.fullmatch(x.get('rgba_sha256','')) for x in checks):continue
     covered.append({'slot':list(slot),'record':rev['record'],'record_sha256':rev['record_sha256'],'SpriteFrames':rev['SpriteFrames'],'SpriteFrames_sha256':rev['SpriteFrames_sha256'],'validation':check['report'],'validation_sha256':check['report_sha256']})
    required_phases={x['phase'] for x in base['dependents']};proof_phases={x['original_phase'] for x in proof['poses']}
    if not required_phases.issubset(proof_phases) or len(covered)!=len(dependents):continue
    claim={'source':source,'source_sha256':base['sha256'],'source_review_sha256':base['_review_sha256'],'origin':base['_origin'],'proof':outcome['proof'],'proof_sha256':proof_sha,'output':proof['output'],'output_sha256':proof['output_sha256'],'phases':sorted(proof_phases),'covered_dependents':covered,'remote_commit':commit,'remote_receipt':b['remote_receipt']['path'],'remote_receipt_sha256':receipt_sha,'scope':'LOSSLESS_OWNERSHIP_ONLY_NO_CAMERA_OR_ART_APPROVAL'}
    accepted[source]=claim;batch_ok.append(source)
   batches.append({'batch':receipt.get('batch'),'receipt_status':'REMOTE_SAVED','proven_sources':batch_ok,'receipt_reported_sources':receipt.get('batch_sources'),'manifest_sha256':manifest_sha})
  except (ValueError,KeyError,OSError) as ex:e.rejected.append({'kind':'ownership_batch','receipt':b.get('remote_receipt'),'reason':str(ex)})
 return accepted,batches,followups

def quality_evidence(e,gate,frozen):
 q=gate['quality'];review,review_sha=e.artifact(q['review']);exact,exact_sha=e.artifact(q['exact_receipt']);quota,quota_sha=e.artifact(q['quota_checkpoint'])
 if exact['review_file_sha256']!=review_sha or review['frozen_review_sha256']!=FROZEN_SHA:raise ValueError('Quality review is not bound to the exact frozen source correction')
 for ref,sha in ((q['review'],review_sha),(q['exact_receipt'],exact_sha),(q['quota_checkpoint'],quota_sha)):e.committed_json(ref['path'],e.head,sha)
 originals={i['issue_id']:i for i in frozen['visual_findings']};camera={};remaining=[];saved_records={};verified_saved=[]
 for b in q['batches']:
  receipt,receipt_sha,commit=e.remote(b['remote_receipt']);lib,lib_sha=e.artifact(b['manifest']);e.committed_json(b['manifest']['path'],commit,lib_sha)
  checks=passed_records(e,b.get('validations',[]))
  for ref in b.get('validations',[]):e.committed_json(ref['path'],commit,e.artifact(ref)[1])
  for rev in lib.get('revisions',[]):
   check=checks.get(path_text(rev['record']))
   if check and check['row'].get('status')=='PASS' and check['row'].get('frames_reached')==6:saved_records[path_text(rev['record'])]=(rev,receipt_sha,commit,b['remote_receipt']['path'])
 reviewed={x['candidate']:x for x in review['results']}
 for row in exact['results']:
  key=path_text(row['record']);saved=saved_records.get(key)
  if not saved:continue
  rev,remote_sha,commit,remote_path=saved;rec,rec_sha=e.json(key,row['record_sha256']);e.committed_json(key,commit,rec_sha)
  if rev.get('record_sha256')!=rec_sha or rec.get('source_sha256')!=row['actual_source_sha256']:continue
  if path_text(rec['source'])!=path_text(row['actual_source']) or rec.get('output_spriteframes_sha256')!=row['resource_sha256']:continue
  if rec.get('frozen_review_sha256')!=FROZEN_SHA or rec.get('correction_candidate_id')!=row['candidate']:continue
  view=reviewed[row['candidate']]
  if view['camera_result']!=row['camera_result'] or view['remaining_issues']!=row['remaining_issues']:continue
  verified_saved.append({'candidate':row['candidate'],'record':key,'record_sha256':rec_sha,'source':row['actual_source'],'source_sha256':row['actual_source_sha256'],'newly_authored_poses':rec.get('newly_authored_poses_requested',rec.get('newly_authored_poses',0)),'remote_commit':commit})
  for old in rec.get('frozen_error_findings',[]):
   current=originals.get(old.get('issue_id'))
   if not current or canonical(current)!=canonical(old):continue
   if current['affected_source']!=rec['previous_source'] or current['source_sha256']!=rec['previous_source_sha256']:continue
   proof={'issue_id':current['issue_id'],'previous_source':current['affected_source'],'previous_source_sha256':current['source_sha256'],'corrected_source':row['actual_source'],'corrected_source_sha256':row['actual_source_sha256'],'record':key,'record_sha256':rec_sha,'visual_review':q['review']['path'],'visual_review_sha256':review_sha,'exact_receipt':q['exact_receipt']['path'],'exact_receipt_sha256':exact_sha,'remote_receipt':remote_path,'remote_receipt_sha256':remote_sha,'remote_commit':commit,'scope':'STATIC_CAMERA_ONLY'}
   if current['cause']=='camera' and row['camera_result']=='RESOLVED_STATIC':camera[current['issue_id']]=proof
  for issue in view['remaining_issues']:
   remaining.append({'actor':row['actor'],'direction':row['direction'],'role':row['role'],'source':row['actual_source'],'source_sha256':row['actual_source_sha256'],'candidate':row['candidate'],**issue})
 return camera,remaining,quota,{'review_sha256':review_sha,'exact_receipt_sha256':exact_sha,'quota_checkpoint_sha256':quota_sha,'verified_saved_corrections':verified_saved}

def native_registration_evidence(e,gate):
 n=gate.get('native176')
 if not n:return {'verified_clips':0,'verified_frames':0,'scope':'TECHNICAL_REGISTRATION_ONLY','camera_or_motion_approvals':0,'slots':[]}
 library,library_sha=e.artifact(n['library']);semantic,semantic_sha=e.artifact(n['review_input']);_,remote_sha,commit=e.remote(n['remote_receipt'])
 e.committed_json(n['library']['path'],commit,library_sha)
 if library.get('baseline_sha')!=BASELINE or library.get('review_input_sha256')!=semantic_sha:raise ValueError('Native176 reviewed input linkage mismatch')
 reports=passed_records(e,n['validations']);inputs={tuple(x['slot']):x for x in semantic['clips']};verified=[]
 for ref in n['validations']:e.committed_json(ref['path'],commit,e.artifact(ref)[1])
 for rev in library['revisions']:
  slot=tuple(rev['slot']);row=reports.get(path_text(rev['record']));old=inputs.get(slot)
  if slot[0]!='transform:176' or not row or not old or row['row'].get('status')!='PASS' or row['row'].get('frames_reached')!=6:continue
  rec,rec_sha=e.json(rev['record'],rev['record_sha256']);e.committed_json(rev['record'],commit,rec_sha)
  reg,reg_sha=e.json(rev['registration'],rev['registration_sha256']);e.committed_json(rev['registration'],commit,reg_sha)
  if record_slot(rec)!=slot or len(old['frames'])!=6:continue
  parent=rec;visited=set();baseline_link=False
  for _ in range(8):
   path=path_text(parent.get('revision_parent',''));expected=parent.get('revision_parent_sha256')
   if not path or path in visited or not expected:break
   visited.add(path)
   if path==path_text(old['baseline_record']) and expected==old['baseline_record_sha256']:baseline_link=True;break
   parent,_=e.json(path,expected)
  if not baseline_link or reg.get('review_input_sha256')!=semantic_sha:continue
  verified.append({'slot':list(slot),'record':rev['record'],'record_sha256':rec_sha,'registration':rev['registration'],'registration_sha256':reg_sha,'baseline_record':old['baseline_record'],'baseline_record_sha256':old['baseline_record_sha256'],'baseline_source_sha256':old['source_sha256'],'validation':row['report'],'validation_sha256':row['report_sha256']})
 return {'verified_clips':len(verified),'verified_frames':6*len(verified),'scope':'TECHNICAL_REGISTRATION_ONLY','camera_or_motion_approvals':0,'remote_commit':commit,'remote_receipt_sha256':remote_sha,'slots':verified}

def proof_reference(claim):
 return {k:claim[k] for k in ('source','source_sha256','proof','proof_sha256','remote_commit','scope')}

def visual_resolution(issue,camera,ownership,adjudications=None):
 if issue['issue_id'] in camera:return 'RESOLVED_STATIC_CAMERA',camera[issue['issue_id']]
 # Ownership proofs establish foreign-pixel isolation only. They do not establish
 # the meaning of a combined visual clipping/foreign-body finding or a guard.
 claim=ownership.get(issue.get('affected_source'))
 if claim and claim['source_sha256']==issue.get('source_sha256') and issue['cause']=='clipped_or_foreign_body':
  decision=(adjudications or {}).get(issue['issue_id'])
  if decision and decision.get('source')==issue['affected_source'] and decision.get('source_sha256')==issue['source_sha256'] and decision.get('proof_sha256')==claim['proof_sha256'] and decision.get('affected_phases') and set(decision['affected_phases']).issubset(claim['phases']) and decision.get('resolution_scope')=='TECHNICAL_OWNERSHIP_ONLY':return 'RESOLVED_TECHNICAL_OWNERSHIP',dict(proof_reference(claim),issue_adjudication=decision)
  return 'HOLD_TECHNICAL_OWNERSHIP_COVERAGE',proof_reference(claim)
 return ('BLOCKED_MODERATION_MISSING' if issue['cause']=='blocked' else ('HOLD' if issue.get('status')=='HOLD' else 'UNMODIFIED')),None

def reconcile(frozen,technical,camera,ownership,new_quality_holds,quota,native,adjudications=None,quality_saved=None):
 attempts={x['correction_candidate_id']:x for x in quota['candidates']};by_issue={}
 for x in frozen['bounded_source_correction_candidates']:
  match=next((a for a in attempts.values() if a['id']==x['actor'] and a['direction']==x['direction'] and a['role']==x['role']),None)
  for issue in x['issues']:by_issue[issue]=match
 rows=[]
 for old in frozen['visual_findings']:
  status,proof=visual_resolution(old,camera,ownership,adjudications);attempt=by_issue.get(old['issue_id']);entry=dict(old,resolution_status=status,resolution_proof=proof)
  if attempt:entry['correction_attempt_status']=attempt['status'];entry['correction_generation_attempts']=attempt['generation_attempts']
  rows.append(entry)
 source_rows=[]
 for source in technical['source_findings']:
  claim=ownership.get(source['source'])
  for index,issue in enumerate(source['findings']):
   status='HOLD' if issue['severity']=='HOLD' else 'UNMODIFIED';proof=None
   if issue['code']=='FOREIGN_POSE_FOREGROUND_INSIDE_FRAME' and claim and claim['source_sha256']==source['sha256'] and issue['phase'] in claim['phases']:status='RESOLVED_TECHNICAL_OWNERSHIP';proof=proof_reference(claim)
   source_rows.append({'issue_id':'technical-source-'+source['sha256'][:16]+'-'+str(index),'slot':source['authored_slot'],'actor':source['authored_slot'][0].split(':')[1],'direction':source['authored_slot'][1],'role':source['authored_slot'][2],'source':source['source'],'source_sha256':source['sha256'],'cause':issue['code'],'finding':issue,'resolution_status':status,'resolution_proof':proof})
 slot_rows=[]
 for group in technical['slot_findings']:
  for index,issue in enumerate(group['findings']):
   slot=group['slot'];source=issue.get('source') or f"assets/actors/eight_direction/legendary_parallel/transform_{slot[0].split(':')[1]}/draft001/{slot[1]}-{slot[2]}-source-v01.png";slot_rows.append({'issue_id':'technical-slot-'+'-'.join(slot)+'-'+str(index),'slot':slot,'actor':slot[0].split(':')[1],'direction':slot[1],'role':slot[2],'source':source,'record':group.get('record'),'cause':issue['code'],'finding':issue,'resolution_status':'BLOCKED_MODERATION_MISSING' if issue['code']=='MISSING_REQUIRED_SLOT' else ('HOLD' if issue['severity']=='HOLD' else 'UNMODIFIED'),'resolution_proof':None})
 def counts(items):
  out={}
  for row in items:
   cause=row.get('cause');d=out.setdefault(cause,{'total':0,'resolved':0,'remaining':0,'statuses':{}});d['total']+=1;d['resolved' if row['resolution_status'].startswith('RESOLVED_') else 'remaining']+=1;s=row['resolution_status'];d['statuses'][s]=d['statuses'].get(s,0)+1
  return out
 saved={x['candidate']:x for x in (quality_saved or [])};details=[]
 for old in quota['candidates']:
  item=dict(old,checkpoint_status=old['status'],current_delivery_status='REMOTE_SAVED' if old['correction_candidate_id'] in saved else old['status'])
  if old['correction_candidate_id'] in saved:item['remote_saved_proof']=saved[old['correction_candidate_id']]
  details.append(item)
 return {'schema':'pr122-legendary-proof-reconciled-residuals-v1','baseline_sha':BASELINE,'frozen_review_sha256':FROZEN_SHA,'new_final_approvals':0,'required_clip_inventory':{'required':1320,'baseline_existing':1319,'baseline_missing_moderation':frozen['missing_slots'],'correction_API_failures_do_not_remove_existing_clips':True},'correction_attempts':{**{k:quota[k] for k in ('attempted','normal_pngs','new_pose_images','blocked_quota_no_retry','pending_never_called','tool_reset_utc_range')},'verified_remote_saved_sources':len(saved),'verified_remote_saved_pose_occurrences':sum(x['newly_authored_poses'] for x in saved.values())},'correction_attempt_details':details,'visual_counts_by_cause':counts(rows),'technical_source_counts_by_cause':counts(source_rows),'technical_slot_counts_by_cause':counts(slot_rows),'visual_findings':rows,'technical_source_findings':source_rows,'technical_slot_findings':slot_rows,'new_quality_remaining_findings':new_quality_holds,'native176_registration':native,'notes':['Counts are issue occurrences grouped by evidence type; source, clip and frame units are never added together.','Ownership proofs do not close combined visual clipping/foreign-body findings without an explicit issue-level adjudication. Their exact technical coverage remains attached as HOLD.','Native176 registration is reported separately and does not close camera, identity or action findings.','All drafts remain HOLD; no PNG was opened, image decoded, whole review repeated, generation requested or runtime/resource mutated by this report.']}

def korean_markdown(r,json_name):
 c=r['correction_attempts'];n=r['native176_registration'];lines=['전설급 잔여 오류 증거 대조','',f"기준 `{BASELINE[:12]}` · 확정 목록 SHA256 `{FROZEN_SHA}`. 최종 승인 추가0.",'',f"기존 초안1319/1320 구성. 미생성은274 NE ATTACK의 원래 moderation BLOCKED1건입니다. 교정 원화는{c['normal_pngs']}건/{c['new_pose_images']}자세 저장, API한도 실패{c['blocked_quota_no_retry']}건, 아직 호출하지 않은{c['pending_never_called']}건을 별도로 보존했습니다.",'','|시각 원인|해결|잔여|','|---|---:|---:|']
 for cause,d in sorted(r['visual_counts_by_cause'].items()):lines.append(f"|{cause}|{d['resolved']}|{d['remaining']}|")
 lines+=['',f"176 등록은 기술검사 증거가 일치한{n['verified_clips']}구성/{n['verified_frames']}프레임입니다. 카메라·동작 승인은0입니다.",'','|증거 단위|원인|해결|잔여|','|---|---|---:|---:|']
 for title,key in [('기술 원화','technical_source_counts_by_cause'),('기술 구성','technical_slot_counts_by_cause')]:
  for cause,d in sorted(r[key].items()):lines.append(f"|{title}|{cause}|{d['resolved']}|{d['remaining']}|")
 lines+=['','새 교정의 잔여 HOLD: '+', '.join(sorted({x['actor']+' '+x['direction']+' '+x['role']+'('+x['cause']+')' for x in r['new_quality_remaining_findings']}))+'.','',f"정확한 actor·방향·동작·원화 경로·issue·SHA·수정 proof와 BLOCKED/HOLD/미수정 목록은 [{json_name}]({json_name})에 있습니다. 누적 예상치나 pending-remote는 해결로 세지 않았습니다.",'']
 return '\n'.join(lines)

def prepare():
 frozen,sha=safe_json(WORK/PREFIX/'whole-review-frozen-v01.json');assert sha==FROZEN_SHA
 technical_path=WORK/PREFIX/'technical-single-review-v01.json';_,technical_sha=safe_json(technical_path)
 template={'schema':'pr122-legendary-final-reconciliation-gate-v1','all_possible_corrections_complete':False,'local_integration_checks_complete':False,'repository_head':'ROOT_TO_SET_FULL_40_CHARACTER_COMMIT','repository_root':str(REPO),'frozen':{'path':str(WORK/PREFIX/'whole-review-frozen-v01.json'),'sha256':sha},'technical_review':{'path':str(technical_path),'sha256':technical_sha},'targeted_technical_artifacts':[],'ownership_batches':[],'visual_issue_adjudications':[],'quality':{'review':{'path':str(WORK/PREFIX/'quality-v02/changed-source-visual-review-v01.json'),'sha256':None},'exact_receipt':{'path':str(WORK/PREFIX/'quality-v02/changed-source-visual-review-receipt-v01.json'),'sha256':None},'quota_checkpoint':{'path':str(WORK/PREFIX/'quality-v02/tool-quota-checkpoint-v01.json'),'sha256':None},'batches':[]},'native176':None,'integration_receipts':[],'output_stem':'remaining-findings-final-v01','instruction':'Root fills only final completed evidence. Each ownership/quality batch has manifest:{path,sha256},validations:[{path,sha256}],remote_receipt:{path,sha256}. Native176 has library,review_input,validations,remote_receipt. No pending receipt is admissible. Optional visual_issue_adjudications artifacts contain claims:[{issue_id,source,source_sha256,proof_sha256,affected_phases,resolution_scope:TECHNICAL_OWNERSHIP_ONLY}]. Targeted technical artifacts have baseline_sha,frozen_review_sha256,source_findings entries in the original technical schema; their exact SHA is the proof source_review_sha256.'}
 mapping={'schema':'pr122-prepared-evidence-mapping-v1','status':'PREPARED_ONLY_NOT_RECONCILED','frozen_review_sha256':sha,'frozen_visual_issues':[{'issue_id':x['issue_id'],'slot':x['slot'],'cause':x['cause'],'source':x.get('affected_source'),'source_sha256':x.get('source_sha256'),'status':x['status']} for x in frozen['visual_findings']],'resolution_rules':{'camera':'Exact old source+frozen issue+saved new source+single changed review+proofSHA+REMOTE_SAVED match only','foreign_pixels':'Exact baseline source SHA+technical phase+lossless proofSHA+all dependent record validations+REMOTE_SAVED only','combined_visual_clipping':'Technical coverage is HOLD until explicit issue adjudication; never imply restored missing source-edge art','native176':'Separate technical registration33/198 only; no camera/identity/action approval','quota':'Failed7 vs never-called106;274 moderation missing1 is separate'},'final_reconciliation_executions':0,'PNG_reads':0}
 write_new(WORK/PREFIX/'remaining-findings-evidence-map-prepared-v01.json',mapping);write_new(WORK/PREFIX/'remaining-findings-final-gate-template-v01.json',template)
 print(json.dumps({'status':'PREPARED_NOT_FINAL_EXECUTED','PNG_reads':0,'final_reconciliation_executions':0}))

def prepare_pending_draft():
 """Commit-ready pending lists, without evaluating any ownership resolution."""
 frozen,frozen_sha=safe_json(WORK/PREFIX/'whole-review-frozen-v01.json')
 if frozen_sha!=FROZEN_SHA:raise ValueError('Frozen review mismatch')
 quota,quota_sha=safe_json(WORK/PREFIX/'quality-v02/tool-quota-checkpoint-v01.json')
 review,review_sha=safe_json(WORK/PREFIX/'quality-v02/changed-source-visual-review-v01.json')
 exact,exact_sha=safe_json(WORK/PREFIX/'quality-v02/changed-source-visual-review-receipt-v01.json')
 candidates={(x['actor'],x['direction'],x['role']):x for x in frozen['bounded_source_correction_candidates']}
 failed=[];never=[]
 for item in quota['candidates']:
  if item['status'] not in ('BLOCKED_QUOTA_NO_RETRY','PENDING_TOOL_QUOTA_NOT_CALLED'):continue
  base=candidates[(item['id'],item['direction'],item['role'])]
  row={'actor':item['id'],'direction':item['direction'],'role':item['role'],'source':base['source'],'source_sha256':base['source_sha256'],'record':base['record'],'causes':base['causes'],'frozen_issue_ids':base['issues'],'candidate':item['correction_candidate_id'],'attempt_status':item['status'],'generation_attempts':item['generation_attempts'],'error':item.get('error'),'request':item['request']}
  (failed if item['status']=='BLOCKED_QUOTA_NO_RETRY' else never).append(row)
 grouped={}
 for row in failed+never:
  for cause in row['causes']:grouped.setdefault(cause,[]).append(row)
 holds=[]
 for row in exact['results']:
  for issue in row['remaining_issues']:holds.append({'actor':row['actor'],'direction':row['direction'],'role':row['role'],'source':row['actual_source'],'source_sha256':row['actual_source_sha256'],'candidate':row['candidate'],**issue})
 frozen_groups={}
 for issue in frozen['visual_findings']:frozen_groups.setdefault(issue['cause'],[]).append({k:issue.get(k) for k in ('issue_id','actor','direction','role','affected_source','source_sha256','status')})
 draft={'schema':'pr122-legendary-pending-findings-draft-v1','status':'PRE_CI_DRAFT_NOT_FINAL_RECONCILED','baseline_sha':BASELINE,'frozen_review_sha256':FROZEN_SHA,'ownership_or_registration_resolutions_computed':False,'final_reconciliation_executions':0,'PNG_reads':0,'new_generation_calls':0,'quota_checkpoint_sha256':quota_sha,'changed_source_review_sha256':review_sha,'changed_source_exact_receipt_sha256':exact_sha,'missing_original_moderation_slots':frozen['missing_slots'],'quota_failed_corrections':failed,'quota_never_called_corrections':never,'pending_source_corrections_by_cause':grouped,'changed_source_remaining_holds':holds,'changed_sources_reviewed_once':review['results'],'frozen_visual_findings_awaiting_final_adjudication_by_cause':frozen_groups,'ownership_status':'AWAITING_ALL_COMPLETED_REMOTE_PROOFS_AND_FINAL_RUNTIME; no predicted resolved count','native176_scope':'TECHNICAL_REGISTRATION_ONLY; camera/identity/action approval0; final verified count awaits exact remote/engine proof','tool_reset_utc_range':quota['tool_reset_utc_range']}
 name='remaining-findings-pending-draft-v01.json';write_new(WORK/PREFIX/name,draft)
 lines=['전설급 미수정·보류 목록 초안','',f'확정 기준은 `{BASELINE[:12]}`이며 원본 오류 목록은 변경하지 않았습니다. 이 문서는 최종 런타임·CI 전 준비 자료이고 ownership/등록 해결 수치는 계산하지 않았습니다.','',f"최초 미생성은274 NE ATTACK의 moderation BLOCKED1건입니다. 별도로 교정 요청{len(failed)}건은 API한도 오류, {len(never)}건은 아직 미호출입니다. 기존 정상 원화는 재생성하지 않았습니다.",'','|추가 교정 원화가 없는 원인|실패 또는 미호출 source|','|---|---:|']
 for cause,items in sorted(grouped.items()):lines.append(f'|{cause}|{len(items)}|')
 lines+=['','변경 원화13건만 한 번 확인했습니다. 339 SW IDLE·275 SW IDLE은 카메라 HOLD,338 N IDLE은 충전/캐스팅처럼 보이는 대기 동작 HOLD입니다. 추가 생성·재시도는 없습니다.','',f'정확한 actor·방향·동작·원화 경로·SHA·원래 issue·실패 원문과 전체 확정전 원인별 목록은 [{name}]({name})에 보존했습니다. ownership와 새 quality source의 추가 소유권 수정은 완료 영수증 뒤에만 집계합니다.176 등록33/198은 기술 범위이며 카메라·동작 승인과 구분합니다.','']
 write_new(WORK/PREFIX/'remaining-findings-pending-draft-v01-KO.md','\n'.join(lines))
 print(json.dumps({'status':'PENDING_LISTS_PREPARED_NOT_FINAL_RECONCILED','failed':len(failed),'never_called':len(never),'PNG_reads':0,'final_reconciliation_executions':0}))

def finalize(gate_path):
 gate,gate_sha=safe_json(gate_path)
 if not gate.get('all_possible_corrections_complete') or not gate.get('local_integration_checks_complete'):raise ValueError('Root completion gate is not final; no reconciliation executed')
 if not gate.get('integration_receipts'):raise ValueError('Exact final runtime/CI receipt artifacts are required; no reconciliation executed')
 head=gate.get('repository_head','')
 if not COMMIT.fullmatch(head):raise ValueError('Final repository head must be a full commit SHA')
 stem=gate.get('output_stem','remaining-findings-final-v01')
 if not re.fullmatch('[a-z0-9-]+',stem):raise ValueError('Invalid output name')
 out=WORK/PREFIX/(stem+'.json');md=WORK/PREFIX/(stem+'-KO.md')
 if out.exists() or md.exists():raise ValueError('Final report already exists; no second final reconciliation is executed')
 e=Evidence(gate.get('repository_root',str(REPO)),head);frozen,frozen_sha=e.artifact(gate['frozen']);technical,technical_sha=e.artifact(gate['technical_review'])
 if frozen_sha!=FROZEN_SHA or frozen.get('baseline_sha')!=BASELINE:raise ValueError('Immutable frozen review mismatch')
 source=next(x for x in frozen['source_artifacts'] if x['path'].endswith('technical-single-review-v01.json'))
 if source['sha256']!=technical_sha:raise ValueError('Technical review differs from the frozen artifact')
 ownership,batches,followups=ownership_evidence(e,gate,technical,technical_sha);camera,holds,quota,qproof=quality_evidence(e,gate,frozen);native=native_registration_evidence(e,gate)
 adjudications={}
 for ref in gate.get('visual_issue_adjudications',[]):
  artifact,sha=e.artifact(ref)
  if artifact.get('frozen_review_sha256')!=FROZEN_SHA:raise ValueError('Issue adjudication frozen SHA mismatch')
  for claim in artifact.get('claims',[]):adjudications[claim['issue_id']]=dict(claim,adjudication_artifact=ref['path'],adjudication_sha256=sha)
 result=reconcile(frozen,technical,camera,ownership,holds,quota,native,adjudications,qproof['verified_saved_corrections']);result.update(final_repository_head=head,final_gate_sha256=gate_sha,ownership_completed_batches=batches,proven_unique_ownership_sources=len(ownership),ownership_proof_catalog=list(ownership.values()),quality_review_proofs=qproof,rejected_or_incomplete_evidence=e.rejected,integration_evidence=[{'path':x['path'],'sha256':e.artifact(x)[1]} for x in gate.get('integration_receipts',[])])
 followup_rows=[]
 for item in followups:
  source=item['source'];claim=ownership.get(source['source'])
  for index,finding in enumerate(source['findings']):
   resolved=claim and claim['source_sha256']==source['sha256'] and finding['code']=='FOREIGN_POSE_FOREGROUND_INSIDE_FRAME' and finding.get('phase') in claim['phases']
   followup_rows.append({'issue_id':'targeted-source-'+source['sha256'][:16]+'-'+str(index),'slot':source['authored_slot'],'source':source['source'],'source_sha256':source['sha256'],'cause':finding['code'],'finding':finding,'targeted_artifact':item['artifact'],'targeted_artifact_sha256':item['artifact_sha256'],'resolution_status':'RESOLVED_TECHNICAL_OWNERSHIP' if resolved else ('HOLD' if finding['severity']=='HOLD' else 'UNMODIFIED'),'resolution_proof':proof_reference(claim) if resolved else None})
 result['targeted_quality_followup_findings']=followup_rows
 result['targeted_followup_proven_sources']=[c for c in ownership.values() if c.get('origin')=='targeted_quality_followup']
 write_new(out,result);write_new(md,korean_markdown(result,out.name))
 print(json.dumps({'status':'FINAL_JSON_PROOF_RECONCILIATION_COMPLETE','JSON':str(out),'Korean_MD':str(md),'PNG_reads':0,'new_approvals':0}))

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);group=parser.add_mutually_exclusive_group(required=True);group.add_argument('--prepare',action='store_true');group.add_argument('--prepare-pending-draft',action='store_true');group.add_argument('--finalize',action='store_true');parser.add_argument('--gate',type=Path);args=parser.parse_args()
 if args.prepare:prepare()
 elif args.prepare_pending_draft:prepare_pending_draft()
 else:
  if not args.gate:parser.error('--finalize requires the completed root --gate JSON')
  finalize(args.gate)
