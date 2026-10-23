#!/usr/bin/env python3
"""Pin new IDLE-only static evidence to exact active metadata; no PNG reads."""
import hashlib, importlib.util, json
from pathlib import Path
WORK=Path('/workspace/legendary_work'); REPO=Path('/workspace/legendary_repo'); DOCS=Path('docs/remake/pr122-legendary-parallel'); OUT=WORK/DOCS/'quality-v03'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text())
def norm(s):return str(s).removeprefix('res://')
def ref(p,root=WORK):return {'path':'res://'+p.relative_to(root).as_posix(),'sha256':sha(p)}
def new(p,value):
 p.parent.mkdir(parents=True,exist_ok=True)
 raw=(json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()
 if p.exists():
  if p.read_bytes()!=raw:raise ValueError('Use new evidence version: '+str(p))
 else:
  with p.open('xb') as f:f.write(raw)
def prepare():
 staging=read(REPO/'data/pr122_legendary_parallel_staging.json'); manifest=read(REPO/norm(staging['corrections']['active_revision_library'])); active={tuple(x['slot']):x for x in manifest['revisions']}
 created=[];waiting=[]
 for vp in sorted((OUT/'source-visual').glob('qc*-review-v01.json')):
  v=read(vp)
  if v['role']!='idle' or v['idle_guard_result']!='HEALTHY_STATIC':continue
  t=read(WORK/norm(v['technical_review']['path']))
  if t['findings']:raise ValueError('Clean raw parent must not bypass technical findings')
  a=active.get(tuple(v['slot']))
  if not a or a['record_sha256']!=v['record_sha256']:
   waiting.append({'candidate':v['candidate'],'reason':'WAIT_EXACT_LOSSLESS_PROOF_MAPPING_OR_NEW_ACTIVE_RECORD'});continue
  rp=REPO/norm(a['record']);tp=REPO/norm(a['SpriteFrames']);r=read(rp)
  if sha(rp)!=a['record_sha256'] or sha(tp)!=a['SpriteFrames_sha256'] or r['source_sha256']!=v['source_sha256']:raise ValueError('Active parent metadata mismatch')
  regp=REPO/norm(a.get('registration',r['frame_registration'])); reg=read(regp)
  if reg['record_sha256']!=a['record_sha256'] or reg['SpriteFrames_sha256']!=a['SpriteFrames_sha256']:raise ValueError('Registration parent pin mismatch')
  transforms=[x for x in reg['frames'] if x['index'] in [0,5]]
  if sorted(x['index'] for x in transforms)!=[0,5]:raise ValueError('Both parent guard registrations required')
  data={'schema':'legendary-targeted-new-idle-parent-quality-v03','frozen_review_sha256':v['frozen_review_sha256'],'records':[{'slot':v['slot'],'record_sha256':a['record_sha256'],'camera_result':v['camera_result'],'identity_result':v['identity_result'],'idle_role_result':v['idle_role_result'],'idle_guard_result':'HEALTHY_STATIC','reviewed_guard_phases':[0,5],'source':v['source'],'source_sha256':v['source_sha256'],'registration':ref(regp,REPO),'registration_record_sha256':reg['record_sha256'],'preserve_guard_transforms':transforms,'new_action_registration_rule':'Inherit these exact original parent texture canvas/anchor/scale for phases0/5; do not recenter an isolated virtual canvas','visual_review':ref(vp),'technical_review':v['technical_review'],'scope':'Static camera/identity/living-idle guard selection only; other HOLDs and final approval unchanged'}],'new_png_reads':0,'new_visual_reviews':0,'new_image_calls':0,'automatic_rebindings':0,'final_approved':0}
  target=OUT/'parent-evidence'/f"{v['candidate']}-review-v01.json";new(target,data);created.append({'candidate':v['candidate'],'review':ref(target),'record':ref(rp,REPO),'SpriteFrames':ref(tp,REPO),'registration':ref(regp,REPO),'status':'WAIT_REMOTE_SAVED_REVIEW_AND_EXACT_VALIDATION'})
 return {'prepared_parents':created,'waiting':waiting,'new_png_reads':0,'new_image_calls':0}
if __name__=='__main__':print(json.dumps(prepare(),ensure_ascii=False))
