#!/usr/bin/env python3
"""Batch identity resolution using exact SQL tuples, DESC tokens and raw SPRs.
Shared graphics never authorize a name transfer or imply a duplicate species.
"""
import argparse, collections, copy, hashlib, json, re, subprocess, unicodedata
from pathlib import Path
from import_monster70_reviewed import INPUTS
# New identity -> existing visual identity, local habitat, named encounter.
SELECTED={'45256':('45379','source_81',False),'45360':('45299','source_491',False),'45577':('45615','source_490',True),'45607':('45615','source_493',True),'45608':('45615','source_495',True),'45963':('45574','source_496',True),'46013':('45585','source_491',True),'46014':('45615','source_495',False),'45995':('45612','source_494',False),'45032':('45060','source_0',False),'45898':('45191','source_491',False),'45899':('45379','source_491',False),'45165':('__native45165','source_440',False)}
TABLE_SHA={'c':'b1c16764bba45979642d0876782c6909fe5c4ea0913e424a5166e09db39cabab','e':'137bf6fdb746d319eb18d71f146ed9fb53c57cf7decdfe4a1ca53613b2533321','k':'3c51978fba43640184dc6c492e65e86cbd7914a3f658ee8cd1e97d7becf6eabc'}
def read(p):return json.loads(p.read_text())
def write(p,v,compact=False):p.write_text(json.dumps(v,ensure_ascii=False,indent=None if compact else 2,separators=(',',':')if compact else None)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def norm(s):return ''.join(c for c in re.sub(r'\\f[A-Za-z0-9]','',s)if unicodedata.category(c)[0]in 'LN')
def integer(v):
 if isinstance(v,float)and v.is_integer():return int(v)
 if isinstance(v,list):return [integer(x)for x in v]
 if isinstance(v,dict):return {k:integer(x)for k,x in v.items()}
 return v
def tables(desc):
 spec=read(desc/'variant_identity_evidence.json');result={}
 for m in spec['table_ranges']:
  p=desc/m['decoded_original_path'];assert sha(p)==TABLE_SHA[m['lang']]
  result[m['lang']]=p.read_bytes().decode(m['encoding'],'replace').splitlines();assert len(result[m['lang']])==m['actual_splitlines']
 return result
def resolve(raw,t):
 token=raw['nameid'];result={}
 for lang,rows in t.items():
  missing=[];entries=[]
  def replace(m):
   ident=int(m[1]);index=ident+1
   if index>=len(rows):missing.append(ident);return m[0]
   entries.append({'token':ident,'line_index_zero_based':index,'value':rows[index]});return rows[index]
  surface=re.sub(r'\$(\d+)',replace,token)
  result[lang]={'display':surface if not missing else None,'missing_token_ids':missing,'entries':entries,'table_sha256':TABLE_SHA[lang]}
 return result

def main(a, selected=None, review_selection_key='additional_identity_selection'):
 global SELECTED
 if selected is not None:SELECTED=selected
 root=a.root.resolve();src=a.source_input.resolve();inp=a.monster_input.resolve();desc=a.desc_input.resolve();work=a.work.resolve();work.mkdir(parents=True,exist_ok=True)
 for name,(_,expected)in INPUTS.items():assert sha(inp/name)==expected
 definitions={r['record_key']:r for r in map(json.loads,(inp/'metadata/source1_action_definitions.jsonl').read_text().splitlines())}
 t=tables(desc);request=read(inp/'metadata/pr201-monster70-exact-extraction-request-20261030.json');provenance=[json.loads(l)for l in (inp/'metadata/provenance_manifest.jsonl').read_text().splitlines()]
 sql={r['fields']['npcid']:r for r in map(json.loads,(src/'source_npcs.jsonl').read_text().splitlines())}
 catalog=read(root/'data/monsters/source_identity_catalog.json');entities={e['npc_id']:e for e in catalog['entities']};extra=read(root/'data/monsters/reviewed_source_additions.json');original=read(root/'data/monsters/reviewed_source_monsters.json');records={r['source_npc_id']:r for r in original['records']+extra['records']}
 # Basic black knight is a different nameid from the existing dark black
 # knight. Its exact definition4003 explicitly resolves to literal body110.
 native_entity=entities['45165'];candidate=native_entity['model_candidates'][0]
 definition=definitions[candidate['definition_record_key']]
 assert definition['raw_definition_sha256']==candidate['definition_sha256'] and candidate['model_key']=='source1:110'
 native_rows={int(r['name'].split('-')[1].split('.')[0]):r for r in provenance if 'source1:110' in r['model_keys'] and 'all_nonconflicting_packs' in r['variant_contexts']}
 native_tracks={};native_used=collections.defaultdict(set)
 for role,code in [('idle',3),('walk',0),('attack',1),('hit',2),('death',8)]:
  action=next(a for a in definition['action_definitions'] if a['id']==code);refs=re.findall(r'(\d+)\.(\d+):(\d+)',action['definition']);assert len(refs)==int(action['definition'].split(',')[0].split()[-1])
  for facing in range(8):
   track=[]
   for group,frame,ticks in refs:
    suffix=int(group)+(facing+3)%8;r=native_rows[suffix];assert int(frame)<r['frames'];native_used[suffix].add(int(frame))
    track.append(dict(blob_sha256=r['sha256'],record_key=r['record_key'],frame_index=int(frame),duration_raw=int(ticks),file_suffix=suffix,requested_heading=(facing+3)%8,source_heading=(facing+3)%8))
   native_tracks[f'{role}_{facing}']=track
 native_records=[]
 for suffix,frames in native_used.items():
  r=copy.deepcopy(native_rows[suffix]);r['archive_path']=str(inp/r['archive']);r['used_frames']=sorted(frames);native_records.append(r)
 directory='res://assets/monsters/reviewed_source/l1j_tw380_npc_45165'
 native_plan=work/'native-knight-plan.json';write(native_plan,{'species':[dict(npc_id='45165',directory=directory,records=native_records,tracks=native_tracks)]})
 subprocess.run([str(a.godot),'--headless','--path',str(root),'--script','res://tools/monsters/import_monster70_reviewed.gd','--',str(native_plan)],check=True)
 native=integer(read(Path(str(native_plan)+'.rendered.json'))['species'][0]['output']);canvas=native['canvas_original_grid'];w,h=canvas[2]-canvas[0],canvas[3]-canvas[1]
 records['__native45165']=dict(source_animation=dict(source='source1',body_gfx=110,source_gfxid=4003,canvas_original_grid=canvas,tracks=native['tracks'],anchor_is_foot=False),source_portrait=directory+'/portrait.png',animation_profile=dict(frames_path=directory+'/frames.tres',layout='directional8',pixel_scale=1.0,authored_motion_weight=0.0,body_kind='special',sprite_offset=[canvas[0]+w/2-24,canvas[1]+h/2-18]),visual_grounding=dict(foot_original_grid=[24,18],policy='Local cosmetic ground point, not authenticated original anchor'))
 # Verify complete existing sequences against exact received source1 records.
 plan={'bases':[]};proof_locators={}
 for base_id in dict.fromkeys(v[0]for v in SELECTED.values()):
  if base_id=='__native45165':continue
  base=records[base_id];animation=base['source_animation'];model='source1:'+str(animation['body_gfx']);matching=collections.defaultdict(list)
  for r in provenance:
   if model in r['model_keys']:matching[r['sha256']].append(r)
  tracks={k:(v['frames']if isinstance(v,dict)else v)for k,v in animation['tracks'].items()};used={f['blob_sha256']for refs in tracks.values()for f in refs};assert used<=set(matching)
  rows=[]
  for digest in sorted(used):
   r=copy.deepcopy(matching[digest][0])
   if 'archive'in r:r['archive_path']=str(inp/r['archive'])
   else:
    ref=r['existing_blob_reference'];r['archive_path']=str(root/'assets/external_spx/source_effects'/ref['archive'].replace('.zip','.sprpack'));r['package_blob']=ref['path']
   rows.append(r)
  proof_locators[base_id]={digest:[{'record_key':r['record_key'],'model_keys':r['model_keys'],'variant_contexts':r['variant_contexts'],'sha256':r['sha256']}for r in matching[digest]]for digest in sorted(used)}
  plan['bases'].append(dict(base_npc_id=base_id,model_key=model,frames_path=base['animation_profile']['frames_path'],portrait_path=base['source_portrait'],canvas_original_grid=animation['canvas_original_grid'],tracks=tracks,records=rows))
 plan_path=work/'reuse-plan.json';write(plan_path,plan)
 subprocess.run([str(a.godot),'--headless','--path',str(root),'--script','res://tools/monsters/verify_monster70_reuse.gd','--',str(plan_path)],check=True)
 verified=integer(read(Path(str(plan_path)+'.verified.json')))
 verified['__native45165']=native;proof_locators['__native45165']={r['sha256']:[{'record_key':r['record_key'],'model_keys':r['model_keys'],'variant_contexts':r['variant_contexts'],'sha256':r['sha256']}] for r in native_records}
 prior_order={r['source_npc_id']:i for i,r in enumerate(extra['records'])}
 extra['records']=[r for r in extra['records']if r['source_npc_id']not in SELECTED]
 for ident,(base_id,mid,named)in SELECTED.items():
  e=entities[ident];raw=sql[ident]['fields'];assert raw['impl']=='L1Monster'and raw['hascastle']=='0';assert(raw['gfxid'],raw['nameid'])==(str(e['gfx_id']),e['nameid']);assert sql[ident]['provenance']==e['source_sql']
  model='source1:'+str(records[base_id]['source_animation']['body_gfx']);candidate=next(c for c in e['model_candidates']if c['model_key']==model)
  assert definitions[candidate['definition_record_key']]['raw_definition_sha256']==candidate['definition_sha256']
  d=resolve(raw,t);assert d['c']['display']and norm(d['c']['display'])==norm(raw['name'])and d['k']['display']
  name=e['korean_name']or d['k']['display']
  if ident in ['45898','45899']:name+='(도적)' if ident=='45898' else '(마법사)'
  base=records[base_id];proof=verified[base_id];animation=copy.deepcopy(base['source_animation']);animation['tracks']=proof['tracks'];animation['source']='source1';animation['source_gfxid']=int(raw['gfxid']);animation['reused_visual_source_npc_id']=base_id if base_id!='__native45165' else None;animation['same_namespace_raw_sha_reuse']=proof_locators[base_id]
  # Keep the exact existing visual and grounding, not its stats, AI or rewards.
  rec=dict(name=name,sourceId='l1j_tw380_npc_'+ident,source_id='source3:l1j-tw-99nets:L1J-TW_3.80c:Taiwan:npc:npcid:'+ident,source_npc_id=ident,source_name_original=raw['name'],source_version='3.80c',source_locale='Taiwan',source_raw_fields=raw,import_enabled=True,catalog_only=True,identity_approval='USER_REVIEWED_SQL_AND_EXISTING_BYTES_20261030',source_portrait=base['source_portrait'],lv=int(raw['lvl']),hp=int(raw['hp']),mp=int(raw['mp']),ac=int(raw['ac']),mr=int(raw['mr']),xp=int(raw['exp']),undead=raw['undead']!='0',grade='일반',drop=[],animation_profile=copy.deepcopy(base['animation_profile']),source_animation=animation,identity_review_evidence=dict(SQL=sql[ident]['provenance'],desc=d,source_namespace='Exact source1 model records and decoded pixel equality, not numeric-model name transfer',distinct_identity='Independent NPC id + display nameid + original C/DESC K name; shared visual does not merge the identities',existing_visual_identity=base_id if base_id!='__native45165' else None),runtime_limits='Source stat records retained; existing actor defaults/minimumHP30 clamp, presentation and optional local named cooldown remain. No imported source AI, special spells, costs, drop chances or prices.')
  if ident in ['45898','45899']:rec['local_display_role_qualification']={'official_desc_name':d['k']['display'],'source_role_note':raw['note'],'policy':'Local role suffix distinguishes two exact SQL/gfx identities sharing the same original display token'}
  if 'visual_grounding'in base:rec['visual_grounding']=copy.deepcopy(base['visual_grounding'])
  if named:rec['local_named_encounter']=True
  for field in ['attack_type','attack_range']:
   if field in base:rec[field]=base[field]
  rec['runtime_design']={'attack_presentation':'Reuse existing local actor attack presentation for the verified shared body; not original spell mechanics','habitat_map':mid,'named_cooldown_local_only':named}
  extra['records'].append(rec);extra['assets'].update(proof['assets'])
  e.update(status='active_source_identity',game_source_id=rec['sourceId'],game_name=name,desc_resolution=d,activation_review='monster70_review.json')
  print('IDENTITY_LINKED',ident,name,'shared_visual',base_id,'level',rec['lv'],'hp',rec['hp'])
 extra['records'].sort(key=lambda r:prior_order[r['source_npc_id']] if r['source_npc_id'] in prior_order else len(prior_order)+list(SELECTED).index(r['source_npc_id']))
 write(root/'data/monsters/reviewed_source_additions.json',extra)
 catalog['game_records']=[g for g in catalog['game_records']if g.get('game_source_id')not in ['l1j_tw380_npc_'+i for i in SELECTED]]
 for r in extra['records']:
  if r['source_npc_id']in SELECTED:catalog['game_records'].append(dict(game_key='twilight:monster:'+hashlib.sha256(r['name'].encode()).hexdigest()[:16],name=r['name'],game_source_id=r['sourceId'],status='exact_source_identity',source_candidates=['source3:tw380:Taiwan:npc:'+r['source_npc_id']]))
 catalog['game_records'].sort(key=lambda g:g['name']);catalog['counts']=dict(collections.Counter(e['status']for e in catalog['entities']));catalog['reverse_counts']=dict(collections.Counter(g['status']for g in catalog['game_records']));catalog['active_game_species']=len(catalog['game_records']);write(root/'data/monsters/source_identity_catalog.json',catalog,True)
 resolve_all(root,request,sql,t,catalog,definitions,provenance,review_selection_key)
 selection=work/'habitat-selection.json';write(selection,{i:{'map_id':v[1],'named':v[2]}for i,v in SELECTED.items()})
 habitat_output=work/'habitats.json'
 subprocess.run([str(a.godot),'--headless','--path',str(root),'--script','res://tools/maps/build_monster70_identity_habitats.gd','--',str(selection),str(habitat_output)],check=True)
 habitat_path=root/'data/monsters/local_source_habitats.json';habitats=read(habitat_path)
 habitats['rows']=[r for r in habitats['rows'] if str(r.get('source_npc_id','')) not in SELECTED]+integer(read(habitat_output))
 write(habitat_path,habitats)

def resolve_all(root,request,sql,t,catalog,definitions=None,raw_records=None,review_selection_key='additional_identity_selection'):
 definitions=definitions or {}
 review=read(root/'data/monsters/monster70_review.json');active={g['game_source_id'].removeprefix('l1j_tw380_npc_'):g['name']for g in catalog['game_records']if g['status']=='exact_source_identity'};known={}
 for g in catalog['game_records']:
  known[norm(g['name'])]=g['name']
  for key in g['source_candidates']:
   ident=key.rsplit(':',1)[1];d=resolve(sql[ident]['fields'],t)
   if d['c']['display']:known[norm(d['c']['display'])]=g['name']
 aliases={'哥布林':'말하는 섬 고블린','骷髏':'말하는 섬 해골','恐怖的吸血鬼':'공포의 뱀파이어'}
 # Actual quest/siege statements, not inferred from a numeric ID or shared body.
 quest=['クエスト','任務NPC','試煉怪','試煉的黑騎士搜索隊'];siege=['攻城戰','攻城']
 source_spawn_rows=read(root/'data/monsters/source3_map_spawns.json')['rows']
 tuple_groups=collections.defaultdict(list)
 for sid,spec in sql.items():
  f=spec['fields']
  if f['impl']=='L1Monster':tuple_groups[(f['gfxid'],f['nameid'],norm(f['name']))].append(sid)
 rows=[]
 for e in request['entities']:
  raw=sql[e['npc_id']]['fields'];d=resolve(raw,t);c=d['c']['display']or raw['name'];note=raw['note']or '';id=e['npc_id'];match=known.get(norm(c))or known.get(norm(d['k']['display']or ''))or aliases.get(c);missing=[];reason=''
  if id in active:status='activated_exact_identity';reason='Active exact SQL identity; duplicate-name/model guessing not used'
  elif any(s in note or s in c for s in quest):status='excluded_explicit_quest';reason='Source note/DESC explicitly marks quest/trial quest actor'
  elif any(s in note for s in siege):status='excluded_explicit_siege';reason='Source note explicitly marks siege'
  elif '廢止'in note:status='source_deprecated_identity';reason='Identity resolved; original source explicitly deprecated this prototype'
  elif id in ['45863','97358']:
   canonical=sql['45677']['fields'];assert raw['gfxid']==canonical['gfxid'] and norm(c).endswith(norm(canonical['name']))
   status='existing_named_actor_title_alias';reason='DESC title + identical proper name 蕾雅 and gfx3744 resolve to existing actor45677; protocol NPC ids and nameids remain distinct';match='법령군왕 라이아'
  elif id=='46081':
   canonical=sql['45745']['fields'];assert raw['gfxid']==canonical['gfxid'] and norm(note)==norm(canonical['name'])
   status='existing_named_actor_note_alias';reason='Source note explicitly names 狄高 and same gfx5351, resolving to existing actor45745';match='다곤'
  elif raw['transform_id'] not in ['-1','0']:
   status='source_transform_context_unresolved';reason='Source prototype names an explicit transform target; no new enemy-phase feature is implemented';missing=['runtime_enemy_transform_support_unimplemented','source_map_and_spawn_condition']
  elif norm(c)!=norm(raw['name'])and id=='81079':status='desc_source_name_conflict';reason='SQL NPC name and supplied DESC token resolve to different object types';missing=['matching_version_desc_token_or_correct_nameid']
  elif match:status='existing_species_or_exact_display_variant';reason='Full DESC display or established full species alias already represented; no runtime rebinding';
  elif '試煉'in c:status='trial_context_unresolved';reason='Trial identity is explicit, but source quest/instance placement is not provided';missing=['raw_spawn_or_quest_script_role','source_map_and_spawn_condition']
  elif any(s in note for s in ['變身前','分身']):status='phase_or_clone_context_unresolved';reason='Source explicitly describes morph/clone; independent spawn versus encounter phase not proven';missing=['raw_spawn_condition','transform_or_encounter_parent_identity']
  elif c.startswith(('峽谷 ','森林 ')) or '隱藏之谷'in note:status='regional_source_variant';reason='DESC regional prefix or explicit source region; base species token is retained';missing=['raw_source_spawn_rows'] if not match else []
  elif '狩獵'in raw['name']and '騎士洞穴'in note:status='training_context_variant';reason='Source explicitly places this prototype in training-knight cave; no new training feature activated';missing=['source_map_and_spawn_condition']
  elif '漆黑的'in c and '翻新'in note:status='renewal_context_variant';reason='DESC plus source note identifies a Halpas-affected renewal prototype';missing=['source_map_and_spawn_condition']
  elif id in ['45103','45128','45151','45186','45771'] or int(raw['gfxid'])in [5684,5685,5688,5690,5691,10629,10630,10634]:status='attachment_or_graphic_variant_review';reason='Distinct owner gfx/definition; literal body overlap is not identity equivalence';missing=['owner_definition_attachment_composition_verified']
  else:status='source_context_unresolved';reason='SQL/DESC identity resolved; independent encounter, variant or non-world actor requires raw source context';missing=['raw_spawn_or_script_role','source_map_and_spawn_condition']
  if id not in active and int(raw['gfxid']) in [5684,5685,5688,5690,5691,10629,10630,10634] and status not in ['excluded_explicit_quest','excluded_explicit_siege','source_deprecated_identity']:
   status='attachment_or_graphic_variant_review';reason='Owner gfx/definition differs from the literal body; shared body and a display alias do not resolve composition';missing=['owner_definition_attachment_composition_verified']
  provided_spawns=[r for r in source_spawn_rows if str(r.get('source_npc_id',''))==id]
  target_id=raw['transform_id'];target=sql.get(target_id)
  transform_target=None if target is None else {'npc_id':target_id,'fields':target['fields'],'desc':resolve(target['fields'],t),'source_sql':target['provenance']}
  declarations=[]
  for m in e['model_candidates']:
   definition=definitions.get(m['definition_record_key'],{})
   declarations.append({'model_key':m['model_key'],'definition_record_key':m['definition_record_key'],'definition_sha256':m['definition_sha256'],'declared_body_prefix':definition.get('base_sprite_id'),'declared_relations':definition.get('relation_metadata',[])})
  rows.append(dict(npc_id=id,source_transform_target=transform_target,source_name=raw['name'],nameid=raw['nameid'],gfx_id=int(raw['gfxid']),source_note=note,model_candidates=[m['model_key']for m in e['model_candidates']],model_declarations=declarations,status=status,reason=reason,existing_game_name_candidate=match,desc=d,source_sql=e['source_sql'],prototype_fields={k:raw[k]for k in ['impl','family','lvl','hp','ranged','transform_id','transform_gfxid','hascastle']},exact_same_display_model_name_npc_ids=sorted(tuple_groups[(raw['gfxid'],raw['nameid'],norm(raw['name']))]),provided_source_spawn_rows=provided_spawns,source_spawn_coverage='supplied_selective_spawns_cover_identity'if provided_spawns else 'not_covered_by_supplied_selective_spawns_not_proof_of_absence_in_original',missing_fields=missing))
 review.update(policy='Exact 198 SQL/DESC identities reviewed. Korean table range is not an identity gate. Shared graphics alone never prove duplicate identity. Explicit quest/siege remain excluded. Unresolved fields identify missing source context or composition, not missing translation.',rows=rows,counts=dict(collections.Counter(r['status']for r in rows)),desc_table_sha256=TABLE_SHA)
 review[review_selection_key]={k:{'visual_from_npc':v[0],'map_id':v[1],'local_named':v[2]}for k,v in SELECTED.items()};write(root/'data/monsters/monster70_review.json',review)
 # Refresh the selected input custody and classification without activating any
 # other prototype. Legacy action/variant diagnostics remain snapshot evidence.
 by_id={e['npc_id']:e for e in catalog['entities']}
 for r in rows:
  entity=by_id[r['npc_id']]
  if entity['status']!='active_source_identity':entity.setdefault('pre_selected_input_status',entity['status']);entity['status']=r['status']
  entity['selected_review_path']='res://data/monsters/monster70_review.json';entity['desc_resolution']=r['desc']
  k=r['desc']['k']['display'];c=r['desc']['c']['display']
  if not entity['korean_name'] and k and c and norm(c)==norm(r['source_name']):entity['korean_name']=k;entity['korean_name_evidence_kind']='DESC_K_exact_SQL_nameid_resolution_not_KR_SQL_corroboration'
 if raw_records:
  verified={(r['record_key'],r['sha256'])for r in raw_records}
  for model in catalog['models'].values():
   for record in model.get('records',[]):
    if (record[0],record[4])in verified:record[5]=True
  catalog['selected_input_custody']={'review_path':'res://data/monsters/monster70_review.json','verified_records':len(verified),'verified_unique_sha256':len({r['sha256']for r in raw_records}),'policy':'Consumer verified selected ZIP SHA/CRC/individual raw SHA. Record availability is current; prior action/variant issue counters are retained snapshot diagnostics, not a new missing-byte assertion.'}
 catalog['counts']=dict(collections.Counter(e['status']for e in catalog['entities']));write(root/'data/monsters/source_identity_catalog.json',catalog,True)
 print('BATCH_RESOLUTION',review['counts'])
 request={'schema':1,'purpose':'Resolve only remaining encounter/quest/variant scope, not translation. Original source already exists in parent; no re-upload or full111 download needed.','source_directory':'source_parts3/extracted/l1j-tw-99nets-master/L1J-TW_3.80c/db/Taiwan/','input_files_received':['npc.sql','npcaction.sql','droplist.sql','shop.sql','weapon.sql','armor.sql','etcitem.sql'],'required_tables':'Actual spawn tables and quest/instance references containing these NPC ids; include actual filename and CREATE TABLE column names. Do not guess table filenames or fabricate coordinates.','required_fields':['NPC template id','source map id','spawn x/y or bounds','count','respawn min/max','source condition/instance/quest role','source filename/full SHA/tuple byte offset+length+SHA'],'npc_ids':sorted(r['npc_id']for r in rows if any('spawn'in f or 'script'in f for f in r['missing_fields']))}
 write(root/'data/monsters/monster70_context_request.json',request)
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--source-input',type=Path,required=True);p.add_argument('--monster-input',type=Path,required=True);p.add_argument('--desc-input',type=Path,required=True);p.add_argument('--godot',type=Path,required=True);p.add_argument('--work',type=Path,required=True);main(p.parse_args())
