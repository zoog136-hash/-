#!/usr/bin/env python3
"""Map previously reviewed new IDLE bodies through exact lossless ownership proof.

Metadata only: no PNG decoding/review, no source/record writes or generation.
New parent wrappers still wait for an exact REMOTE_SAVED review receipt before
any dependent producer may use them. Unrelated visual HOLDs never clear.
"""
import argparse,hashlib,json,re
from pathlib import Path
W=Path('/workspace/legendary_work');R=Path('/workspace/legendary_repo');D=Path('docs/remake/pr122-legendary-parallel');Q=W/D/'quality-v03'
def read(p):return json.loads(p.read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def norm(s):return str(s).removeprefix('res://')
def ref(p,root=W):return {'path':'res://'+p.relative_to(root).as_posix(),'sha256':sha(p)}
def write(p,d):
 p.parent.mkdir(parents=True,exist_ok=True);raw=(json.dumps(d,ensure_ascii=False,indent=2)+'\n').encode()
 if p.exists():
  if p.read_bytes()!=raw:raise ValueError('Immutable metadata changed; new version required')
 else:
  with p.open('xb') as f:f.write(raw)
def exact(p,expected):
 if sha(p)!=expected:raise ValueError('Exact artifact SHA mismatch: '+str(p))
 return read(p)
def validate_mapping(visual,technical,active,record,proof,index):
 if not technical['findings'] or any(f['code']!='FOREIGN_POSE_FOREGROUND_INSIDE_FRAME' for f in technical['findings']):raise ValueError('Only previously confirmed safe ownership may map body review')
 if record['revision_parent_sha256']!=visual['record_sha256'] or norm(record['revision_parent'])!=norm(visual['record']):raise ValueError('Exact raw visual parent record mismatch')
 if norm(proof['source'])!=norm(visual['source']) or proof['source_sha256']!=visual['source_sha256']:raise ValueError('Proof does not derive from reviewed source')
 if norm(proof['output'])!=norm(record['source']) or proof['output_sha256']!=record['source_sha256']:raise ValueError('Current output source mismatch')
 if proof.get('resampled') is not False or proof.get('recolored') is not False or proof.get('original_source_mutations')!=0:raise ValueError('Camera/body evidence cannot inherit a pixel-changing transform')
 if proof.get('visible_source_coverage')!='EXACTLY_ONCE' or proof.get('integer_translation_verification')!='PASS':raise ValueError('Full owned-pixel coverage proof must pass')
 if proof['source_foreground_pixels']<=0 or proof['source_visible_pixels']<=0:raise ValueError('Empty proof')
 matched=[s for s in index['source_findings'] if norm(s['source'])==norm(visual['source']) and s['sha256']==visual['source_sha256']]
 if len(matched)!=1 or matched[0]['findings']!=technical['findings']:raise ValueError('Exact targeted technical source evidence mismatch')
 poses={x['original_phase']:x for x in proof['poses']};checks={x['index']:x for x in record['automatic_checks']}
 if set(poses)!=set(range(6)) or set(checks)!=set(range(6)):raise ValueError('Six original IDLE poses required')
 for i,p in poses.items():
  if checks[i]['region']!=p['region'] or any(not isinstance(x,int) for x in p['translation']):raise ValueError('Exact integer pose/region mismatch')
  if any(not re.fullmatch('[0-9a-f]{64}',p[k]) for k in ['source_positions_sha256','source_rgba_sha256']):raise ValueError('Exact owned-pixel proof SHA missing')
 return [dict(index=i,original_phase=i,translation=poses[i]['translation'],source_positions_sha256=poses[i]['source_positions_sha256'],source_rgba_sha256=poses[i]['source_rgba_sha256']) for i in [0,5]]
def prepare():
 staging=read(R/'data/pr122_legendary_parallel_staging.json');manifest=exact(R/norm(staging['corrections']['active_revision_library']),staging['corrections']['active_revision_library_sha256']);active={tuple(x['slot']):x for x in manifest['revisions']};prepared=[];waiting=[]
 for vp in sorted((Q/'source-visual').glob('qc*-review-v01.json')):
  v=read(vp)
  if v['role']!='idle' or v.get('guard_body_result')!='HEALTHY_STATIC' or v['camera_result']!='RESOLVED_STATIC' or v['identity_result']!='PRESERVED_STATIC' or v['idle_role_result']!='LIVING_IDLE_STATIC':continue
  t=exact(W/norm(v['technical_review']['path']),v['technical_review']['sha256'])
  if not t['findings']:continue
  a=active[tuple(v['slot'])];rp=R/norm(a['record']);record=exact(rp,a['record_sha256'])
  if a['record_sha256']==v['record_sha256']:
   waiting.append({'candidate':v['candidate'],'reason':'WAIT_SAFE_OWNERSHIP_ACTIVE_REVISION'});continue
  links=record.get('isolation_proofs',[])
  if len(links)!=1:waiting.append({'candidate':v['candidate'],'reason':'WAIT_EXACT_SINGLE_LOSSLESS_PROOF'});continue
  pp=R/norm(links[0]);proof=read(pp);ip=W/norm(proof['source_review_path']);index=exact(ip,proof['source_review_sha256']);guards=validate_mapping(v,t,a,record,proof,index)
  regp=R/norm(a['registration']);registration=exact(regp,a['registration_sha256'])
  if registration['record_sha256']!=a['record_sha256'] or registration['SpriteFrames_sha256']!=a['SpriteFrames_sha256']:raise ValueError('Active registration pin mismatch')
  transforms=[x for x in registration['frames'] if x['index'] in [0,5]]
  if len(transforms)!=2:raise ValueError('Both projected guard registrations required')
  row={'slot':v['slot'],'record_sha256':a['record_sha256'],'camera_result':'RESOLVED_STATIC','identity_result':'PRESERVED_STATIC','idle_role_result':'LIVING_IDLE_STATIC','idle_guard_result':'HEALTHY_STATIC','reviewed_guard_phases':[0,5],'reviewed_raw_source':v['source'],'reviewed_raw_source_sha256':v['source_sha256'],'active_source':record['source'],'active_source_sha256':record['source_sha256'],'registration':ref(regp,R),'registration_record_sha256':registration['record_sha256'],'preserve_guard_transforms':transforms,'new_action_registration_rule':'Inherit exact original parent canvas/anchor/scale through the integer proof; do not recenter the isolated virtual canvas','visual_review':ref(vp),'technical_review':v['technical_review'],'integer_ownership_proof':ref(pp,R),'source_review':ref(ip),'guard_owned_RGBA_mapping':guards,'scope':'Only lossless metadata mapping of the already reviewed body/camera; no new PNG/visual review or final approval'}
  target=Q/'parent-evidence'/f"{v['candidate']}-review-v02.json";write(target,{'schema':'legendary-targeted-lossless-new-idle-parent-quality-v04','frozen_review_sha256':v['frozen_review_sha256'],'records':[row],'new_png_reads':0,'new_visual_reviews':0,'new_image_calls':0,'automatic_rebindings':0,'final_approved':0});prepared.append({'candidate':v['candidate'],'quality_review':ref(target),'record':ref(rp,R),'SpriteFrames':{'path':a['SpriteFrames'],'sha256':a['SpriteFrames_sha256']},'registration':ref(regp,R),'status':'WAIT_EXACT_REMOTE_REVIEW_AND_AFFECTED_VALIDATION'})
 return {'prepared':prepared,'waiting':waiting,'new_png_reads':0,'new_image_calls':0}
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--output',type=Path);args=a.parse_args();result=prepare()
 if args.output:write(args.output,result)
 print(json.dumps({'prepared':[x['candidate'] for x in result['prepared']],'waiting':len(result['waiting']),'PNG_reads':0,'image_calls':0}))
