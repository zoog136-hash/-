#!/usr/bin/env python3
"""Materialize never-called dependent actions only from exact healthy new parents.

Internal root execution guard, not a new user approval. No PNG decoding. Old
plans, requests, checkpoints and candidate history are never rewritten.
"""
import argparse, collections, copy, hashlib, importlib.util, json
from pathlib import Path
ROOT=Path('/workspace/legendary_work/docs/remake/pr122-legendary-parallel')
BASE_SHA='ea84a4e2cdc69495d89805a24e612992bb0e7e7c8f0b9beb3badf3b6e41095d4'
raw=(ROOT/'prepare_quality_resume_v06.py').read_bytes()
if hashlib.sha256(raw).hexdigest()!=BASE_SHA:raise ValueError('Pinned v06 helper changed')
spec=importlib.util.spec_from_file_location('immutable_resume_v06',ROOT/'prepare_quality_resume_v06.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
GUARD_ONLY={'qc063','qc098'}
PRIMARY_PLAN_SHA='044f43ada55205df75cc594f68a4c4901c4703121bef81c291cff538ad41692a'
PRIMARY,_=base.raw_json(base.WORK/base.QUALITY/'correction-plan-v06.json',PRIMARY_PLAN_SHA)
PRIMARY_COHORT={j['correction_candidate_id'] for j in PRIMARY['jobs'] if j['state']=='READY'}
if len(PRIMARY_COHORT)!=71:raise ValueError('Pinned primary cohort must have exactly71 candidates')
def exclude_guard_only(plan,writes):
 for job in plan['jobs']:
  if job['correction_candidate_id'] not in GUARD_ONLY:continue
  writes.pop(base.WORK/job['request'],None)
  job.update(state='GUARD_REBIND_ONLY_NO_NEW_IMAGE',wait_reason='FROZEN_EXPLICIT_HEALTHY_MIDDLE_FOUR_PRESERVE_EXACT_PIXELS',maximum_new_image_calls=0)
  for k in ['batch','request_sha256','request_stem','newly_authored_poses_requested']:job.pop(k,None)
 return plan,writes
class Preparation(base.Preparation):
 def accepted_parent(self,job):
  accepted,reason=super().accepted_parent(job)
  if not accepted:return accepted,reason
  revision,idle,frames,proof=accepted
  ref=proof.get('registration')
  if not ref:return None,'WAIT_EXACT_PARENT_REGISTRATION_METADATA'
  path=base.REPO/base.normalized(ref['path'])
  registration,sha=base.raw_json(path,ref['sha256'])
  if registration.get('record_sha256')!=revision['record_sha256'] or registration.get('SpriteFrames_sha256')!=revision['SpriteFrames_sha256']:return None,'WAIT_PARENT_REGISTRATION_RECORD_RESOURCE_SHA'
  transforms=[copy.deepcopy(x) for x in registration['frames'] if x['index'] in [0,5]]
  if sorted(x['index'] for x in transforms)!=[0,5]:return None,'WAIT_PARENT_BOTH_GUARD_REGISTRATIONS'
  remote,_=self.artifact(proof['remote_receipt']);commit=remote.get('commit_sha') or remote.get('remote_sha')
  output=base.subprocess.run(['git','-C',str(base.REPO),'show',commit+':'+base.normalized(ref['path'])],capture_output=True)
  if output.returncode or base.digest(output.stdout)!=sha:return None,'WAIT_EXACT_REMOTE_PARENT_REGISTRATION'
  proof=copy.deepcopy(proof);proof['preserve_guard_registration']={'metadata':ref,'record_sha256':revision['record_sha256'],'SpriteFrames_sha256':revision['SpriteFrames_sha256'],'frames':transforms,'original_parent_texture_canvas_must_be_preserved':True,'recenter_isolated_guard_virtual_canvas':False}
  return (revision,idle,frames,proof),None
 def build(self,request_revision='v05',first_batch=309):
  plan,writes=super().build(request_revision,first_batch)
  plan,writes=exclude_guard_only(plan,writes)
  for job in plan['jobs']:
   if job['correction_candidate_id'] in PRIMARY_COHORT:
    writes.pop(base.WORK/job['request'],None)
    job.update(state='PRIMARY71_SEPARATE_IN_PROGRESS_OR_ATTEMPTED',wait_reason='NO_DEPENDENT_QUEUE_CALL_PRIMARY71_ALREADY_OWNED')
    for key in ['batch','request_sha256','request_stem','newly_authored_poses_requested']:job.pop(key,None)
  for job in plan['jobs']:
   if job['state']=='READY':
    q=writes.get(base.WORK/job['request'])
    if q and q.get('resume_parent_evidence'):
     q['resume_parent_registration']=q['resume_parent_evidence']['preserve_guard_registration']
     q['draft_guard_reuse']['idle_registration']=q['resume_parent_registration']['metadata']['path']
     q['draft_guard_reuse']['idle_registration_sha256']=q['resume_parent_registration']['metadata']['sha256']
     job['request_sha256']=base.digest((json.dumps(q,ensure_ascii=False,indent=2)+'\n').encode())
    job.pop('batch',None)
  plan['next_unused_batch']=base.partition_jobs(plan['jobs'],first_batch)
  plan.update(schema='legendary-dependent-correction-resume-plan-v07',guard_only_candidate_ids=sorted(GUARD_ONLY),historical_allowed106_unchanged=True,guard_only_middle_four_new_image_calls=0,counts=dict(collections.Counter(j['state'] for j in plan['jobs'])),wait_reasons=dict(collections.Counter(j.get('wait_reason') for j in plan['jobs'] if j['state']!='READY')))
  return plan,writes
def claim(path,candidate,authorized):
 if candidate in PRIMARY_COHORT:return {'status':'WAIT','candidate':candidate,'reason':'PRIMARY71_SEPARATE_QUEUE_NO_DUPLICATE_CALL'}
 if candidate in GUARD_ONLY:return {'status':'WAIT','candidate':candidate,'reason':'GUARD_REBIND_ONLY_NO_NEW_IMAGE'}
 plan,_=base.raw_json(path)
 if set(plan.get('guard_only_candidate_ids',[]))!=GUARD_ONLY:raise ValueError('Dependent plan must retain no-new-image exclusions')
 return base.claim(path,candidate,authorized)
def main():
 p=argparse.ArgumentParser(description=__doc__);m=p.add_mutually_exclusive_group(required=True);m.add_argument('--dry-run',action='store_true');m.add_argument('--prepare',action='store_true');m.add_argument('--claim');m.add_argument('--write-maps',action='store_true');p.add_argument('--plan',type=Path);p.add_argument('--dependency-evidence',type=Path);p.add_argument('--request-revision',default='v05');p.add_argument('--first-batch',type=int,default=309);p.add_argument('--output-plan',default='correction-plan-v07.json');p.add_argument('--root-authorized-image-call',action='store_true');a=p.parse_args()
 if a.claim:print(json.dumps(claim(a.plan,a.claim,a.root_authorized_image_call)));return
 if a.write_maps:print(json.dumps(base.write_maps(a.plan)));return
 preparation=Preparation(a.dependency_evidence);plan,writes=preparation.build(a.request_revision,a.first_batch)
 if a.prepare:
  if not base.re.fullmatch(r'correction-plan-v\d{2}\.json',a.output_plan):raise ValueError('New versioned plan required')
  for path,value in writes.items():base.immutable_json(path,value)
  base.immutable_json(base.WORK/base.QUALITY/a.output_plan,plan)
 print(json.dumps({'status':'PREPARED_NO_GENERATION' if a.prepare else 'DRY_RUN_NO_WRITES','counts':plan['counts'],'wait_reasons':plan['wait_reasons'],'new_requests':len(writes),'image_calls':0,'claims_reserved':0,'historical_allowed':len(plan['allowed_candidate_ids'])},ensure_ascii=False))
if __name__=='__main__':main()
