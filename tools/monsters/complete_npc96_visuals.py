#!/usr/bin/env python3
"""Compile exact source1 ant/lycan bodies and verify the remaining ordinary identities.
No source groups, spells, traps or enemy transformations are executed.
"""
import argparse,collections,copy,hashlib,json,re,subprocess,zipfile
from pathlib import Path
import resolve_monster70_identities as R
from import_monster70_reviewed import INPUTS
SELECTED={'45939':('45285','source_65',False),'45485':('__native1108','oman_05',False),'45945':('__native1037','source_491',False),'45948':('__native1037','source_491',False)}
def annotate(root,work,prior,context_input):
 context=R.read(context_input/'npc96_exact_context.json')
 from apply_npc96_context import positive,CONTEXT_SHA,LIBRARY
 review=R.read(root/'data/monsters/monster70_review.json');old={r['npc_id']:r for r in prior['rows']}
 for row in review['rows']:
  previous=old.get(row['npc_id'],{})
  for key in ['source_context','context_resolution']:
   if key in previous:row[key]=copy.deepcopy(previous[key])
  if row['npc_id'] in SELECTED:
   row['missing_fields']=[];row['context_resolution']='positive_ordinary_source_spawn_exact_body_visually_verified_local_habitat'
  elif row['npc_id']=='45315':
   row['context_resolution']='positive_source_spawn_is_conditional_group70_leader_with_clothes2540_unverified';row['missing_fields']=['verified_clothes2540_blend_and_sequence_composition','existing_supported_group_encounter_adapter']
 review['source_context_receipt']=copy.deepcopy(prior['source_context_receipt']);review['source_context_receipt']['new_world_identities']=list(dict.fromkeys(review['source_context_receipt']['new_world_identities']+list(SELECTED)))
 review['counts']=dict(collections.Counter(r['status']for r in review['rows']));R.write(root/'data/monsters/monster70_review.json',review)
 registry=R.read(root/'data/monsters/reviewed_source_additions.json')
 for record in registry['records']:
  npc=record['source_npc_id']
  if npc not in SELECTED:continue
  rows=positive(context['sql_references'],npc);assert rows and all(r['values']['group_id']=='0'for r in rows)
  record['identity_review_evidence']['source_spawn_context']={'archive_library_id':LIBRARY,'archive_sha256':CONTEXT_SHA,'positive_direct_rows':rows,'original_source_maps':sorted({int(r['values']['mapid'])for r in rows}),'world_spawn_policy':'Positive independent ordinary-world identity. Local bounded habitat only; original coordinates, groups, special spells and respawn formula not imported.'}
  record['runtime_design']['habitat_map']=SELECTED[npc][1]
  if str(record['source_animation'].get('reused_visual_source_npc_id','')).startswith('__native'):record['source_animation']['reused_visual_source_npc_id']=None
 R.write(root/'data/monsters/reviewed_source_additions.json',registry)
 habitat=R.read(root/'data/monsters/local_source_habitats.json');rows=R.integer(R.read(work/'habitats.json'))
 assert len(rows)==4
 for row in rows:
  refs=positive(context['sql_references'],row['source_npc_id']);row['source_context_archive_sha256']=CONTEXT_SHA;row['source_spawn_tuple_sha256']=[r['provenance']['raw_sha256']for r in refs];row['original_source_map_ids']=sorted({int(r['values']['mapid'])for r in refs})
  if row['source_npc_id']=='45939':row['placement_reason']='Local aquatic habitat: one crab, roaming32, reachable physical floor; 64-unit authoring buffer rather than default160; prior habitats unchanged. Not original map63 coordinates.'
 habitat['rows']=[r for r in habitat['rows']if str(r.get('source_npc_id',''))not in SELECTED]+rows;R.write(root/'data/monsters/local_source_habitats.json',habitat)
def main(a):
 prior=R.read(a.root/'data/monsters/monster70_review.json')
 a.work.mkdir(parents=True,exist_ok=True)
 for name,(_,digest) in INPUTS.items():
  path=a.monster_input/name;assert R.sha(path)==digest
  with zipfile.ZipFile(path) as archive:assert archive.testzip() is None
 raw=[json.loads(l)for l in (a.monster_input/'metadata/provenance_manifest.jsonl').read_text().splitlines()]
 definitions={r['record_key']:r for r in map(json.loads,(a.monster_input/'metadata/source1_action_definitions.jsonl').read_text().splitlines())}
 species=[]
 for body in [1037,1108]:
  definition=definitions[f'source1:Text.pak:list.spr:definition:{body}']
  rows={int(r['name'].split('-')[1].split('.')[0]):r for r in raw if f'source1:{body}'in r['model_keys']and r['variant_contexts']==['all_nonconflicting_packs']}
  tracks={};used=collections.defaultdict(set)
  for role,code in [('idle',3),('walk',0),('attack',1),('hit',2),('death',8)]:
   action=next(x for x in definition['action_definitions']if x['id']==code);refs=re.findall(r'(\d+)\.(\d+):(\d+)',action['definition'])
   assert len(refs)==int(action['definition'].split(',')[0].split()[-1])
   for facing in range(8):
    sequence=[]
    for group,frame,ticks in refs:
     suffix=int(group)+(facing+3)%8;r=rows[suffix];assert int(frame)<r['frames'];used[suffix].add(int(frame))
     sequence.append(dict(blob_sha256=r['sha256'],record_key=r['record_key'],frame_index=int(frame),duration_raw=int(ticks),file_suffix=suffix,requested_heading=(facing+3)%8,source_heading=(facing+3)%8))
    tracks[f'{role}_{facing}']=sequence
  records=[]
  for suffix,frames in used.items():
   r=copy.deepcopy(rows[suffix]);r.update(archive_path=str(a.monster_input/r['archive']),used_frames=sorted(frames));records.append(r)
  species.append(dict(npc_id=str(body),directory=f'res://assets/monsters/reviewed_source/body_{body}',records=records,tracks=tracks,definition_record_key=definition['record_key'],definition_sha256=definition['raw_definition_sha256']))
 plan=a.work/'native-bodies.json';R.write(plan,{'species':species})
 subprocess.run([str(a.godot),'--headless','--path',str(a.root),'--script','res://tools/monsters/import_monster70_reviewed.gd','--',str(plan)],check=True)
 # Import only the new native atlases; leave unrelated large catalog trees alone.
 guards=[]
 try:
  for folder in ['assets/catalog','assets/catalog_motion','assets/directional']:
   guard=a.root/folder/'.gdignore'
   if guard.parent.exists()and not guard.exists():guard.write_text('');guards.append(guard)
  subprocess.run([str(a.godot),'--headless','--editor','--import','--path',str(a.root)],check=True,stdout=(a.work/'import.log').open('w'),stderr=subprocess.STDOUT,timeout=180)
 finally:
  for guard in guards:guard.unlink()
 bases={}
 for item in R.read(Path(str(plan)+'.rendered.json'))['species']:
  output=R.integer(item['output']);canvas=output['canvas_original_grid'];body=int(item['npc_id']);w,h=canvas[2]-canvas[0],canvas[3]-canvas[1]
  bases[f'__native{body}']=dict(source_animation=dict(source='source1',body_gfx=body,source_gfxid=body,canvas_original_grid=canvas,tracks=output['tracks'],anchor_is_foot=False,definition_record_key=item['definition_record_key'],definition_sha256=item['definition_sha256']),source_portrait=item['directory']+'/portrait.png',animation_profile=dict(frames_path=item['directory']+'/frames.tres',layout='directional8',pixel_scale=1.0,authored_motion_weight=0.0,body_kind='special',sprite_offset=[canvas[0]+w/2-24,canvas[1]+h/2-18]),visual_grounding=dict(foot_original_grid=[24,18],policy='Existing reviewed transform-family foot point; local grounding, not authenticated original client anchor'))
 request=a.root/'data/monsters/monster70_context_request.json';before=request.read_bytes()
 try:R.main(a,SELECTED,'remaining_visual_selection',bases,{'45945':'청소 개미'},{'45939':{'search_max_distance':4500,'habitat_clearance':64,'max_count':1,'roaming_radius':32}})
 finally:request.write_bytes(before)
 annotate(a.root,a.work,prior,a.context_input)
 print('REMAINING_NATIVE_VISUALS',len(SELECTED))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 for name in ['root','source-input','monster-input','desc-input','context-input','godot','work']:p.add_argument('--'+name,type=Path,required=True)
 main(p.parse_args())
