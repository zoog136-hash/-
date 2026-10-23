"""Bind native176 original texture aliases by the pinned preservation inventory."""
from __future__ import annotations
import copy,types
import active_findings_projection_v02 as base
import active_findings_projection_v04 as phase
import active_findings_projection_v05 as scopes

INVENTORY='docs/remake/pr122-legendary-parallel/transform_176-reuse-matrix-v01.json'
INVENTORY_SHA='31d9c11b31d0b956be0df03fc13bd78779416ea72ded393a7f854673d068a082'
hydrate_historical_records=scopes.hydrate_historical_records
quality_lineages=scopes.quality_lineages
annotate=scopes.annotate

def inventory_aliases(inventory):
 if inventory.get('key')!='transform:176' or inventory.get('actual_legacy_poses_eligible_for_reuse')!=59:raise ValueError('Exact native176 preservation inventory required')
 known={}
 for track in inventory['tracks']:
  for f in track.get('legacy_source_files',[]):
   path=base.path(f['original_path']);sha=f['sha256']
   if path in known and known[path]!=sha:raise ValueError('Conflicting preserved original SHA')
   known[path]=sha
 if len(known)!=2 or len(set(known.values()))!=2:raise ValueError('Two unambiguous native source inventories required')
 return known

def bind_native_aliases(record,known):
 """Return an ephemeral record copy only; authoring records remain immutable."""
 if record.get('key')!='transform:176':return record,[]
 fixed=copy.deepcopy(record);files=fixed.get('source_files',[]);notes=[]
 existing={base.path(f['original_path']):f for f in files if f.get('original_path')}
 legacy={x.get('original_pose_id'):x for x in fixed.get('existing_pose_metadata',[])}
 sequence=fixed.get('revision_source_pose_sequence') or fixed.get('source_pose_sequence') or []
 # The oldest S ATTACK compiler records its original source explicitly in a
 # header rather than existing_pose_metadata. Accept that exact header only.
 header=base.path(fixed.get('reused_source_original_path'))
 if header:
  if header not in known or fixed.get('reused_source_sha256')!=known[header] or fixed.get('original_reused_regions_margins_rgba_unchanged') is not True:raise ValueError('Native original-header SHA/preservation contract mismatch')
  for i,pose in enumerate(sequence):
   if pose.get('source_kind')!='reused' or pose.get('original_pose_id') in legacy:continue
   check=next((c for c in fixed['automatic_checks'] if c['index']==i),None)
   if not check or pose.get('rgba_sha256')!=check.get('rgba_sha256') or pose.get('original_region')!=check.get('region') or len(pose.get('original_margin',[]))!=4 or pose.get('original_margin')!=check.get('margin',pose.get('original_margin')):raise ValueError('Native header pose coordinates/RGBA do not match exact frame checks')
   entry={'original_pose_id':pose['original_pose_id'],'source_path':header}
   fixed.setdefault('existing_pose_metadata',[]).append(entry);legacy[pose['original_pose_id']]=entry
 used=set()
 for pose in sequence:
  old=legacy.get(pose.get('original_pose_id'))
  original=pose.get('source') or pose.get('source_path')
  if not original and pose.get('source_kind')=='reused' and old:original=old['source_path']
  original=base.path(original)
  if not original or original not in {base.path(x['source_path']) for x in legacy.values()}:continue
  if original in used:continue
  used.add(original)
  if original not in known:raise ValueError('Native source absent from exact preserved inventory')
  expected=known[original]
  if original in existing:
   if existing[original]['sha256']!=expected:raise ValueError('Explicit native alias SHA conflicts with inventory')
   continue
  direct=[f for f in files if base.path(f.get('path',f.get('source')))==original]
  if direct:
   if len(direct)!=1 or direct[0]['sha256']!=expected:raise ValueError('Native original metadata conflicts with inventory')
   continue
  copies=[f for f in files if f.get('sha256')==expected and f.get('source_kind') in ('reused','preserved_native')]
  if len(copies)!=1:raise ValueError('Native texture alias has no unique SHA-identical preserved copy')
  copied=copies[0]
  if copied.get('original_path') and base.path(copied['original_path'])!=original:raise ValueError('A preserved source cannot claim conflicting original identities')
  copied['original_path']=original
  notes.append({'original_path':original,'selected_copy':base.path(copied['path']),'sha256':expected,'basis':'PINNED_NATIVE_PRESERVATION_INVENTORY_AND_EXACT_SOURCE_FILE_SHA','frame_coordinates_RGBA_anchor_mutations':0})
 return fixed,notes

def selected_poses_with_aliases(record,known):
 fixed,notes=bind_native_aliases(record,known)
 return base.selected_poses(fixed),notes

def build_active_index(evidence,gate,ownership):
 inventory,_=evidence.json(INVENTORY,INVENTORY_SHA);evidence.committed_json(INVENTORY,evidence.head,INVENTORY_SHA);known=inventory_aliases(inventory);notes=[]
 def selected(record):
  poses,aliases=selected_poses_with_aliases(record,known)
  notes.extend(dict(a,slot=[record['key'],record['direction'],record['role']]) for a in aliases)
  return poses
 # Reuse the original compiler code object with a private selected_poses binding.
 # No global monkey-patch and no source/actor resource mutation occur.
 bindings=dict(base.build_active_index.__globals__);bindings['selected_poses']=selected
 compiler=types.FunctionType(base.build_active_index.__code__,bindings,base.build_active_index.__name__,base.build_active_index.__defaults__,base.build_active_index.__closure__)
 clips,selection=compiler(evidence,gate,ownership)
 outputs={(c['output'],c['output_sha256']) for c in ownership.values()}
 for clip in clips.values():
  record,_=evidence.json(clip['record'],clip['record_sha256']);phase.authored_phase_mapping(clip,record,outputs)
 selection['source_phase_unit']='Author clip playback phase; sheet-cell ordinal is separate'
 selection['native_texture_alias_evidence']={'inventory':{'path':'res://'+INVENTORY,'sha256':INVENTORY_SHA},'ephemeral_aliases_added':notes,'source_or_record_mutations':0,'PNG_reads':0}
 return clips,selection
