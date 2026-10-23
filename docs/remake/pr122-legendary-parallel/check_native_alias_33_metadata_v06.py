#!/usr/bin/env python3
"""Inspect ONLY native17633 clip metadata after the source-alias projector fix."""
import json,hashlib
from pathlib import Path
import reconcile_remaining_findings_v01 as core
import active_findings_projection_v06 as projection
W=Path('/workspace/legendary_work');P=W/core.PREFIX
HEAD='164787709a7aad7ee8b2f8e0c245a807e275b2e9'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 e=core.Evidence(core.REPO,HEAD);gate=json.loads((P/'remaining-findings-final-completion-gate-v06.json').read_text());st,st_sha=e.artifact(gate['active_staging']);lib,lib_sha=e.artifact(gate['active_manifest']);inventory,_=e.json(projection.INVENTORY,projection.INVENTORY_SHA);e.committed_json(projection.INVENTORY,HEAD,projection.INVENTORY_SHA);known=projection.inventory_aliases(inventory)
 configs={}
 for a in st['actors']:
  for d in a['drafts']:
   if d['key']=='transform:176':configs[(d['key'],d['direction'],d['role'])]=d
 for rev in lib['revisions']:
  if rev['slot'][0]=='transform:176':configs[tuple(rev['slot'])]=rev
 if len(configs)!=33:raise ValueError('Native17633 exact slots required')
 rows=[];native=0;added=[]
 for slot,c in sorted(configs.items()):
  rec,rec_sha=e.json(c['record'],c.get('record_sha256'));e.committed_json(c['record'],HEAD,rec_sha);poses,notes=projection.selected_poses_with_aliases(rec,known)
  if len(poses)!=6:raise ValueError('Six metadata poses required')
  n=sum(p['source_sha256'] in known.values() for p in poses);native+=n;added.extend(dict(x,slot=list(slot)) for x in notes)
  rows.append({'slot':list(slot),'record':c['record'],'record_sha256':rec_sha,'metadata_status':'PASS','selected_poses':poses,'preserved_native_pose_occurrences':n,'ephemeral_aliases_added':notes})
 if native!=59 or len(added)!=4:raise ValueError(f'Exactly native59 occurrences and four explicit header/record aliases expected, found {native}/{len(added)}')
 out={'schema':'legendary-native176-only-source-alias-metadata-check-v06','status':'PASS_METADATA_ONLY','repository_head':HEAD,'staging_sha256':st_sha,'active_manifest_sha256':lib_sha,'native_inventory':{'path':'res://'+projection.INVENTORY,'sha256':projection.INVENTORY_SHA},'native_clips_inspected':33,'metadata_frames_projected':198,'preserved_native_pose_occurrences':native,'aliases_added_ephemerally':added,'records':rows,'PNG_reads':0,'resource_or_PNG_changes':0,'visual_reviews':0,'Godot_replays':0,'whole_corpus_projection_runs':0,'final_report_completions':0,'quality_approvals_added':0}
 target=P/'native176-alias-only-metadata-validation-v06.json'
 with target.open('x') as f:f.write(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({'status':out['status'],'clips':33,'frames':198,'native_occurrences':native,'added_alias_rows':len(added),'output':str(target),'sha256':sha(target)}))
if __name__=='__main__':run()
