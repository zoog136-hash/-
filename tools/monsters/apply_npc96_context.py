#!/usr/bin/env python3
"""Use the received exact source context; never execute SQL or source Java.
Only explicit positive ordinary-world spawn rows authorize this bounded batch.
Source groups, traps, enemy transforms and original special spells stay data.
"""
import argparse,collections,copy,hashlib,json
from pathlib import Path
import resolve_monster70_identities as resolver
SELECTED={'45035':('45165','source_0',False),'45402':('45130','oman_05',False),'45403':('45131','oman_05',False),'45487':('45279','source_65',False),'45724':('45160','source_65',False),'45732':('45279','source_65',False),'45733':('45285','source_65',False),'45890':('45258','source_491',False),'45920':('45116','source_55',False),'45922':('45235','source_55',False),'45924':('45192','source_55',False),'45925':('45097','source_65',False),'45933':('45160','source_65',False),'45934':('45195','source_65',False),'45938':('45279','source_65',False)}
CONTEXT_SHA='c2230dd49bbde615f1de23b872c7cf0696f75b78de0758a4528ba228a80cc11d'
LIBRARY='libfile_5f3fb38774848191a45f1ee74011be07'
def positive(rows,npc):return [r for r in rows if r['table']=='spawnlist' and r['reference_kind']=='direct_npc_typed_column' and r['values']['npc_templateid']==npc and int(r['values']['count'])>0]
def main(a):
 root=a.root.resolve();folder=a.context_input.resolve();archive=folder.parent/'pr201_npc96_exact_context.zip';assert resolver.sha(archive)==CONTEXT_SHA and archive.stat().st_size==102730
 context=resolver.read(folder/'npc96_exact_context.json');request_bytes=(folder/'monster70_context_request.json').read_bytes();assert hashlib.sha256(request_bytes).hexdigest()==context['request_sha256']
 checked=0
 for rows,proof,path in [(context['table_schemas'],'create_table','raw_create_table_path'),(context['sql_references'],'provenance','raw_tuple_path'),(context['source_reference_excerpts'],'provenance','raw_excerpt_path')]:
  for row in rows:
   data=(folder/row[path]).read_bytes();spec=row[proof];assert len(data)==spec['byte_length'] and hashlib.sha256(data).hexdigest()==spec['raw_sha256'];checked+=1
 schemas={r['name']:r['columns']for r in context['table_schemas']}
 for row in context['sql_references']:
  assert list(row['values'])==schemas[row['table']]
  for ref in row.get('requested_npc_references',[]):assert row['values'][ref['column']]==ref['npc_id'] and ref['npc_id']in context['requested_npc_ids']
 sql={r['fields']['npcid']:r for r in map(json.loads,(a.source_input/'source_npcs.jsonl').read_text().splitlines())}
 for npc in SELECTED:
  assert positive(context['sql_references'],npc),npc
  f=sql[npc]['fields'];assert f['impl']=='L1Monster' and f['hascastle']=='0' and f['transform_id']=='-1'
  assert not any(word in f['note']for word in ['クエスト','任務','攻城'])
 original_request=(root/'data/monsters/monster70_context_request.json').read_bytes()
 try:resolver.main(a,SELECTED,'context_identity_selection')
 finally:(root/'data/monsters/monster70_context_request.json').write_bytes(original_request)
 registry_path=root/'data/monsters/reviewed_source_additions.json';registry=resolver.read(registry_path)
 for record in registry['records']:
  npc=record['source_npc_id']
  if npc not in SELECTED:continue
  rows=positive(context['sql_references'],npc)
  record['identity_review_evidence']['source_spawn_context']={'archive_library_id':LIBRARY,'archive_sha256':CONTEXT_SHA,'positive_direct_rows':rows,'original_source_maps':sorted({int(r['values']['mapid'])for r in rows}),'world_spawn_policy':'Positive original spawn proves an independent prototype. Current game uses bounded explicitly local habitats and source stats; raw counts, groups, respawn distributions, original special spells and original-coordinate equivalence are not imported.'}
 resolver.write(registry_path,registry)
 habitats_path=root/'data/monsters/local_source_habitats.json';habitats=resolver.read(habitats_path)
 for row in habitats['rows']:
  npc=str(row.get('source_npc_id',''))
  if npc in SELECTED:
   rows=positive(context['sql_references'],npc);row['source_context_archive_sha256']=CONTEXT_SHA;row['source_spawn_tuple_sha256']=[r['provenance']['raw_sha256']for r in rows];row['original_source_map_ids']=sorted({int(r['values']['mapid'])for r in rows});row['placement_reason']='Independent ordinary spawn proved by exact source SQL. Bounded local habitat on the current verified floor; not original coordinates/counts/respawn or map-version equivalence.'
 resolver.write(habitats_path,habitats)
 review_path=root/'data/monsters/monster70_review.json';review=resolver.read(review_path);refs=collections.defaultdict(list)
 for row in context['sql_references']:
  for ref in row.get('requested_npc_references',[])+row.get('indirect_requested_npc_references',[]):refs[ref['npc_id']].append(row)
 for row in review['rows']:
  npc=row['npc_id']
  if npc not in context['requested_npc_ids']:continue
  evidence=refs[npc];coverage=context['npc_coverage'][npc];row['source_context']={'coverage':coverage,'references':evidence,'original_scope_limit':'Only retained same-version sources scanned. Deleted quest/pet/clan/siege tables were not restored. No-reference is not deletion or a new-species verdict.'}
  if npc=='45939':
   row['status']='verified_identity_habitat_capacity_hold';row['context_resolution']='Positive source map63 spawn and body verified; no safe space remains in the current supported aquatic map without changing prior habitats';row['missing_fields']=['safe_existing_aquatic_habitat_capacity'];continue
  if row['status']=='activated_exact_identity':continue
  if row.get('prototype_fields',{}).get('transform_id','-1')not in ['-1','0']:row['context_resolution']='source_transform_parent_and_target_known_runtime_mechanism_not_added';row['missing_fields']=['authorized_existing_enemy_transform_support']
  elif npc in context['npc_ids_without_new_reference']:row['context_resolution']='no_reference_within_retained_scope_not_proof_of_global_absence';row['missing_fields']=['independent_encounter_or_variant_role_not_established_by_retained_sources']
  elif positive(context['sql_references'],npc):row['context_resolution']='positive_world_spawn_known_visual_or_source_mechanism_review_pending'
  elif any(r['table']=='mobgroup'for r in evidence):row['context_resolution']='group_membership_known_conditional_formation_not_activated';row['missing_fields']=['supported_existing_group_spawn_adapter_or_independent_positive_spawn']
  elif any(r['table']=='spawnlist'for r in evidence):row['context_resolution']='retained_spawn_rows_have_zero_count_not_an_independent_active_spawn';row['missing_fields']=['active_spawn_condition_not_established_by_retained_sources']
  else:row['context_resolution']='source_code_or_skill_reference_known_no_independent_positive_spawn_proved'
 review['source_context_receipt']={'library_file_id':LIBRARY,'archive_sha256':CONTEXT_SHA,'requested_ids':len(context['requested_npc_ids']),'sql_references':len(context['sql_references']),'individual_excerpts_verified':checked,'no_new_reference_ids':context['npc_ids_without_new_reference'],'known_deleted_tables_not_restored':context['known_deleted_tables_absent_not_restored'],'new_world_identities':list(SELECTED)}
 review['counts']=dict(collections.Counter(row['status']for row in review['rows']))
 resolver.write(review_path,review)
 catalog_path=root/'data/monsters/source_identity_catalog.json';catalog=resolver.read(catalog_path)
 for entity in catalog['entities']:
  if entity['npc_id']=='45939':entity['status']='verified_identity_habitat_capacity_hold'
 catalog['counts']=dict(collections.Counter(entity['status']for entity in catalog['entities']));resolver.write(catalog_path,catalog,True)
 print('NPC96_CONTEXT_VERIFIED excerpts=',checked,'positive_new_world_identities=',len(SELECTED),'no_reference_within_retained_scope=',len(context['npc_ids_without_new_reference']))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--source-input',type=Path,required=True);p.add_argument('--monster-input',type=Path,required=True);p.add_argument('--desc-input',type=Path,required=True);p.add_argument('--context-input',type=Path,required=True);p.add_argument('--godot',type=Path,required=True);p.add_argument('--work',type=Path,required=True);main(p.parse_args())
