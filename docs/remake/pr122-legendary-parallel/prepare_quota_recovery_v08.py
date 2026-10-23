#!/usr/bin/env python3
"""Explicit bounded recovery of seven original429/no-PNG calls after reset.

Old20 checkpoint/claims/receipts stay immutable. Only root may call images,
with one new recovery lock per source; total client attempts2, successfulPNG1.
"""
import argparse,collections,copy,datetime,hashlib,importlib.util,json,re
from pathlib import Path
ROOT=Path('/workspace/legendary_work/docs/remake/pr122-legendary-parallel');W=ROOT.parents[2];D=Path('docs/remake/pr122-legendary-parallel');Q=W/D/'quality-v02';R=Path('/workspace/legendary_repo')
spec=importlib.util.spec_from_file_location('unchanged_v06',ROOT/'prepare_quality_resume_v06.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
EXPECTED={'qc021','qc023','qc024','qc025','qc026','qc031','qc032'}
RECOVERY_SCHEMA='legendary-seven-original-quota-noPNG-recovery-plan-v08'
def digest(raw):return hashlib.sha256(raw).hexdigest()
def ref(path):return {'path':str(path.relative_to(W)),'sha256':digest(path.read_bytes())}
def quota_only_no_png(state,receipt):
 if state.get('status')!='BLOCKED_QUOTA_NO_RETRY' or state.get('generation_attempts')!=1 or state.get('generated') or not receipt.get('blocked') or receipt.get('generated'):return False
 if any(receipt.get(k)!=state[k] for k in ['correction_candidate_id','id','direction','role','previous_source_sha256']):return False
 return bool(re.search(r'429',str(receipt.get('error'))) and re.search(r'usage_limit_reached',str(receipt.get('error'))))
def pure_claim_gate(plan,job,now,authorized,primary_settled,prior_success,recovery_reserved,stop429,original_client_attempts=1):
 if not authorized:return 'WAIT_ROOT_ONLY_INTERNAL_EXECUTION_GUARD'
 if original_client_attempts!=1:return 'WAIT_TOTAL_CLIENT_ATTEMPT_BOUND_EXCEEDED'
 if job['correction_candidate_id'] not in EXPECTED or job.get('state')!='READY':return 'WAIT_NOT_EXACT_SEVEN_QUOTA_EXCEPTIONS'
 if now<datetime.datetime.fromisoformat(plan['quota_not_before_utc']):return 'WAIT_QUOTA_RESET'
 if not primary_settled:return 'WAIT_PRIMARY71_TOOL_REQUESTS_SETTLED'
 if prior_success:return 'WAIT_SUCCESSFUL_PNG_ALREADY_EXISTS_NO_REGENERATION'
 if recovery_reserved:return 'WAIT_RECOVERY_ALREADY_RESERVED_OR_ATTEMPTED_NO_RETRY'
 if stop429:return 'WAIT_QUOTA_REOCCURRED_STOP_ALL_ADDITIONAL_CALLS'
 return None
def inputs():
 cp,_=base.raw_json(Q/'tool-quota-checkpoint-v01.json',base.CHECKPOINT_SHA);old,_=base.raw_json(Q/'correction-plan-v05.json',base.ORIGINAL_PLAN_SHA);frozen,_=base.raw_json(ROOT/'whole-review-frozen-v01.json',base.FROZEN_SHA)
 states={x['correction_candidate_id']:x for x in cp['candidates'] if x['status']=='BLOCKED_QUOTA_NO_RETRY'}
 if set(states)!=EXPECTED:raise ValueError('Only the exact original seven429 failures are allowed')
 return cp,old,states

def verify_probe():
 probe=Q/'generation-receipts/transform_225-SW-idle-correction-v02.json';x,_=base.raw_json(probe)
 if x.get('correction_candidate_id')!='qc033' or x.get('blocked') or not x.get('generated'):raise ValueError('Reset probe must be actual successful qc033')
 req=W/x['request'];q,_=base.raw_json(req,x['request_sha256']);cp,_,_=inputs();reset=max(cp['tool_reset_utc_range'])
 if datetime.datetime.fromisoformat(x['returned_utc'].replace('Z','+00:00'))<datetime.datetime.fromisoformat(reset):raise ValueError('Probe predates reset')
 rec=R/'assets/actors/eight_direction/legendary_parallel/transform_225/quality-v02/SW-idle-record-v02.json';record,_=base.raw_json(rec)
 if record['raw_generated_file']!=x['generated'] or not Path(x['generated']).exists():raise ValueError('Probe actual PNG provenance mismatch')
 return {'candidate':'qc033','receipt':ref(probe),'request':ref(req),'source':record['source'],'source_sha256':record['source_sha256'],'availability_only_not_art_approval':True}

def prepare():
 cp,old,states=inputs();probe=verify_probe();byid={x['correction_candidate_id']:x for x in old['jobs']};jobs=[];writes={}
 for i,cid in enumerate(sorted(EXPECTED)):
  state=states[cid];original=byid[cid];oldreceipt=W/state['receipt'];rr,_=base.raw_json(oldreceipt)
  if not quota_only_no_png(state,rr):raise ValueError('Original failure is not exact429/noPNG: '+cid)
  oldrequest=W/state['request'];q,_=base.raw_json(oldrequest);q=copy.deepcopy(q)
  if [q['key'],q['direction'],q['role']]!=['transform:'+state['id'],state['direction'],state['role']]:raise ValueError('Original request identity mismatch')
  if q['correction_representation']!='six_new' or q['newly_authored_poses_requested']!=6 or q['reused_poses']!=0:raise ValueError('SevenIDLE all use existing six-new config')
  q.update(maximum_generation_calls=1,maximum_total_client_generation_attempts=2,maximum_successful_generated_PNGs=1,bounded_quota_recovery={'schema':'legendary-original429-reset-recovery-v08','explicit_root_scope_exception':'Only original seven HTTP429/no-PNG failures; original13 successes and all visualHOLDs/moderation excluded','original_checkpoint':ref(Q/'tool-quota-checkpoint-v01.json'),'original_request':ref(oldrequest),'original_blocked_receipt':ref(oldreceipt),'original_error':rr['error'],'original_client_attempts':1,'new_recovery_attempts_allowed':1,'maximum_total_client_attempts':2,'maximum_successful_generated_PNGs':1,'successful_reset_probe':probe,'on_recovery429':'PRESERVE_RESULT_AND_STOP_ALL_ADDITIONAL_RECOVERY_CALLS'})
  stem=f"transform_{state['id']}-{state['direction']}-{state['role']}-quota-recovery-v08";path=Q/'requests'/(stem+'.json');raw=(json.dumps(q,ensure_ascii=False,indent=2)+'\n').encode();writes[path]=q
  jobs.append({k:state[k] for k in ['id','direction','role','correction_candidate_id','previous_source_sha256','representation']})
  jobs[-1].update(state='READY',request=str(path.relative_to(W)),request_sha256=digest(raw),request_stem=stem,batch=311 if i<4 else 312,newly_authored_poses_requested=6,reused_poses=0,original_request=ref(oldrequest),original_receipt=ref(oldreceipt))
 plan={'schema':RECOVERY_SCHEMA,'allowed_candidate_ids':sorted(EXPECTED),'checkpoint_sha256':base.CHECKPOINT_SHA,'original_plan_sha256':base.ORIGINAL_PLAN_SHA,'frozen_review_sha256':base.FROZEN_SHA,'quota_not_before_utc':max(cp['tool_reset_utc_range']),'successful_reset_probe':probe,'jobs':jobs,'counts':{'READY':7},'first_resume_batch':311,'next_unused_batch':313,'generation_calls_authorized':False,'generation_calls_started':0,'maximum_calls_per_recovery_request':1,'maximum_total_client_attempts_per_source':2,'maximum_successful_generated_PNGs_per_source':1,'old20_checkpoint_unchanged':True,'camera_role_HOLD_retries':0,'moderation_source_retries':0,'paid_api_calls':0}
 return plan,writes

def read_plan(path):
 p,sha=base.raw_json(path)
 if p.get('schema')!=RECOVERY_SCHEMA or set(p.get('allowed_candidate_ids',[]))!=EXPECTED or p.get('checkpoint_sha256')!=base.CHECKPOINT_SHA or p.get('frozen_review_sha256')!=base.FROZEN_SHA or p.get('original_plan_sha256')!=base.ORIGINAL_PLAN_SHA:raise ValueError('Exact seven recovery plan pins mismatch')
 if len(p['jobs'])!=7 or set(x['correction_candidate_id'] for x in p['jobs'])!=EXPECTED:raise ValueError('Recovery jobs must be exact seven')
 probe=verify_probe()
 if probe!=p['successful_reset_probe']:raise ValueError('Pinned reset probe changed')
 return p,sha

def claim(plan_path,cid,authorized):
 plan,psha=read_plan(plan_path);cp,old,states=inputs();job=next((x for x in plan['jobs'] if x['correction_candidate_id']==cid),None)
 if not job:return {'status':'WAIT','reason':'WAIT_NOT_EXACT_SEVEN_QUOTA_EXCEPTIONS','candidate':cid}
 state=states[cid];rr,_=base.raw_json(W/job['original_receipt']['path'],job['original_receipt']['sha256'])
 if not quota_only_no_png(state,rr):raise ValueError('Original429/noPNG evidence mismatch')
 if any(job[k]!=state[k] for k in ['id','direction','role','previous_source_sha256']):raise ValueError('Recovery source changed')
 primary,_=base.raw_json(Q/'correction-plan-v06.json','044f43ada55205df75cc594f68a4c4901c4703121bef81c291cff538ad41692a');primarysettled=all((Q/'generation-receipts'/(Path(x['request']).stem+'.json')).exists() for x in primary['jobs'] if x['state']=='READY')
 prefix=f"transform_{job['id']}-{job['direction']}-{job['role']}-";allreceipts=list((Q/'generation-receipts').glob(prefix+'*.json'));success=any(base.raw_json(x)[0].get('generated') for x in allreceipts)
 recovery_receipts=[Q/'generation-receipts'/(j['request_stem']+'.json') for j in plan['jobs']];stop=any(x.exists() and re.search(r'429|usage_limit_reached',str(base.raw_json(x)[0].get('error',''))) for x in recovery_receipts)
 lock=Q/'generation-claims'/(prefix+'quota-recovery-once.lock');claimpath=Q/'generation-claims'/(job['request_stem']+'.json');result=Q/'generation-tool-results'/(job['request_stem']+'-result.json');receipt=Q/'generation-receipts'/(job['request_stem']+'.json')
 reserved=lock.exists() or claimpath.exists() or receipt.exists() or result.exists()
 original_attempt_count=sum(x.resolve()!=(W/job['original_receipt']['path']).resolve() and 'quota-recovery-' not in x.name for x in allreceipts)+1
 reason=pure_claim_gate(plan,job,datetime.datetime.now(datetime.timezone.utc),authorized,primarysettled,success,reserved,stop,original_attempt_count)
 if reason:return {'status':'WAIT','reason':reason,'candidate':cid}
 request,_=base.raw_json(W/job['request'],job['request_sha256']);gen=request['generation_request']
 if request.get('correction_candidate_id')!=cid or request.get('previous_source_sha256')!=job['previous_source_sha256'] or [request.get('key'),request.get('direction'),request.get('role')]!=['transform:'+job['id'],job['direction'],job['role']]:raise ValueError('Recovery request exact source/candidate mismatch')
 if set(gen)-{'prompt','referenced_image_paths','transparent_background'}:raise ValueError('Unsupported imagegen option')
 if request.get('maximum_total_client_generation_attempts')!=2 or request.get('maximum_successful_generated_PNGs')!=1 or request.get('maximum_generation_calls')!=1:raise ValueError('Client2/success1/recovery1 hard limit mismatch')
 lock.parent.mkdir(parents=True,exist_ok=True)
 try:
  with lock.open('x') as f:f.write(cid+'\n')
 except FileExistsError:return {'status':'WAIT','reason':'WAIT_RECOVERY_ONCE_LOCK_ALREADY_EXISTS','candidate':cid}
 base.immutable_json(claimpath,{'schema':'legendary-seven429-recovery-claim-v08','candidate':cid,'request':job['request'],'request_sha256':job['request_sha256'],'plan':str(plan_path),'plan_sha256':psha,'original_client_attempts':1,'recovery_attempt_number':1,'total_client_attempt_number':2,'maximum_successful_generated_PNGs':1,'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'IMAGE_CALL_ONCE_AUTHORIZED_NO_RETRY'})
 return {'status':'CLAIMED_ONCE','job':job,'generation_request':gen,'claim':str(claimpath),'receipt':str(receipt),'tool_result':str(result)}

def main():
 p=argparse.ArgumentParser(description=__doc__);m=p.add_mutually_exclusive_group(required=True);m.add_argument('--dry-run',action='store_true');m.add_argument('--prepare',action='store_true');m.add_argument('--claim');m.add_argument('--write-maps',action='store_true');p.add_argument('--plan',type=Path);p.add_argument('--root-authorized-image-call',action='store_true');a=p.parse_args()
 if a.claim:print(json.dumps(claim(a.plan,a.claim,a.root_authorized_image_call),ensure_ascii=False));return
 if a.write_maps:read_plan(a.plan);print(json.dumps(base.write_maps(a.plan),ensure_ascii=False));return
 plan,writes=prepare()
 if a.prepare:
  for path,q in writes.items():base.immutable_json(path,q)
  base.immutable_json(Q/'quota-recovery-plan-v08.json',plan)
 print(json.dumps({'status':'PREPARED_NO_CALLS' if a.prepare else 'DRY_RUN_NO_WRITES','allowed':plan['allowed_candidate_ids'],'batches':{str(n):sum(j['batch']==n for j in plan['jobs']) for n in [311,312]},'oldPNG_success_retries':0,'image_calls':0,'claims_reserved':0}))
if __name__=='__main__':main()
