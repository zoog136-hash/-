#!/usr/bin/env python3
"""Classify the entire pinned SQL monster universe without activating candidates.
Record locators refer to original packs, never guessed transport URLs. A name or
shared graphic alone is never an automatic gameplay identity binding.
"""
import argparse, collections, csv, hashlib, io, json, re, zipfile
from pathlib import Path
CATALOG_SHA='638adc0a6fb47fbe40b62979869efec68c299c4a1029d4fc28f09958dcfb848c'
PACK_SHA='fcc4daa36165d5046275a1cb11f7a6bf9a9e4bac67571a3a861abdfd6f8f8d4c'
EXCLUDED={'45025','97006','97044','97094','81082'}
def sha(data):return hashlib.sha256(data).hexdigest()
def jl(data):return [json.loads(line) for line in data.decode().splitlines()]
def normal(name):return re.sub(r'\s+','',name).lower()
def enrich_game_records(output, root):
 sources=json.loads((root/'data/monsters/reviewed_source_monsters.json').read_text())['records']+json.loads((root/'data/monsters/reviewed_source_additions.json').read_text())['records']
 sources=[r for r in sources if r['import_enabled']]
 base=json.loads((root/'data/game_db_v17.json').read_text())['몬스터']
 additions=json.loads((root/'data/monsters/monster_world_catalog.json').read_text())['additions']
 games={r['name']:r for r in base}
 for r in additions:games.setdefault(r['name'],r)
 for r in sources:games[r['name']]=r
 by_name=collections.defaultdict(list)
 for entity in output['entities']:
  for name in entity['game_name_candidates']:by_name[name].append(entity['key'])
 active={entity.get('game_source_id'):entity for entity in output['entities'] if entity.get('game_source_id')}
 source_records={r['source_npc_id']:r for r in sources}
 for entity in output['entities']:
  source=source_records.get(entity['npc_id'])
  if not source:continue
  tracks=source.get('source_animation',{}).get('tracks',{}).values()
  aliases=[ref for track in tracks for ref in (track if isinstance(track,list) else track.get('frames',[])) if ref.get('explicit_same_body_death_heading0_alias')]
  if aliases:entity['local_presentation_exception']='Death direction explicitly reuses the supplied same-body slot0 sequence; original 33..39 directional files are absent, not falsely claimed as delivered'
 reverse=[];counts=collections.Counter()
 for name,record in sorted(games.items()):
  game_id=str(record.get('sourceId',''));direct=active.get(game_id)
  status='exact_source_identity' if direct else ('source_name_candidates_only' if by_name[name] else 'no_corroborated_source_name')
  counts[status]+=1
  reverse.append(dict(game_key='twilight:monster:'+hashlib.sha256(name.encode()).hexdigest()[:16],name=name,game_source_id=game_id,status=status,source_candidates=[direct['key']] if direct else by_name[name]))
 output['game_records']=reverse;output['reverse_counts']=dict(counts)
 assert len(reverse)==output['active_game_species']

def build(args):
 root=args.root;available={};locations=collections.defaultdict(list);pack_roots={}
 # Verify bytes in already materialized bundles; metadata alone is not availability.
 for package in sorted(args.monster_inputs.glob('*/content_blobs.jsonl')):
  folder=package.parent
  for blob in jl(package.read_bytes()):
   digest=blob['sha256'];path=folder/blob['package_path']
   if digest not in available:
    data=path.read_bytes();assert len(data)==blob['bytes'] and sha(data)==digest
    available[digest]=blob['prior_frame_count']
   locations[digest].append(folder.name)
  print('VERIFIED_EXISTING_BUNDLE',folder.name,flush=True)
 with zipfile.ZipFile(args.transform_input) as source:
  assert sha(args.transform_input.read_bytes())==PACK_SHA
  prefix='transformation_source_candidates_v1/'
  for blob in jl(source.read(prefix+'content_blobs.jsonl')):
   digest=blob['sha256']
   if digest not in available:
    data=source.read(prefix+blob['package_path']);assert len(data)==blob['bytes'] and sha(data)==digest
    available[digest]=blob['prior_frame_count']
   locations[digest].append('transformation_source_candidates_v1')
  for record in jl(source.read(prefix+'raw_asset_records.jsonl')):
   if record.get('original_pak_relative'):pack_roots[record['source']]=str(Path(record['original_pak_relative']).parent)
 npcs={r['fields']['npcid']:r for r in jl((args.source_input/'source_npcs.jsonl').read_bytes())}
 korean=json.loads(args.korean_reference.read_text())
 original=json.loads((root/'data/monsters/reviewed_source_monsters.json').read_text())['records']
 gaps=json.loads((root/'data/monsters/reviewed_source_additions.json').read_text())['records']
 selected={r['source_npc_id']:r for r in original+gaps if r['import_enabled']}
 by_display=collections.defaultdict(list)
 for ident,record in selected.items():by_display[(record['source_raw_fields']['gfxid'],record['source_raw_fields']['nameid'])].append(ident)
 base=json.loads((root/'data/game_db_v17.json').read_text())['몬스터'];catalog=json.loads((root/'data/monsters/monster_world_catalog.json').read_text())
 games={r['name'] for r in base}|{r['name'] for r in catalog['additions']}|{r['name'] for r in selected.values()}
 game_names=collections.defaultdict(list)
 for name in games:game_names[normal(name)].append(name)
 assert sha(args.catalog.read_bytes())==CATALOG_SHA
 with zipfile.ZipFile(args.catalog) as source:
  def csv_rows(member):return csv.DictReader(io.TextIOWrapper(source.open(member),encoding='utf-8-sig',newline=''))
  entities=[r for r in csv_rows('sprites/source3_sql_crosscheck.csv') if r['sql_impl']=='L1Monster'];assert len(entities)==1693 and len({r['sql_record_id'] for r in entities})==1693
  definitions=collections.defaultdict(list)
  wanted={int(r['graphics_id']) for r in entities}
  for row in csv_rows('sprites/source1_actions.csv'):
   if int(row['definition_id']) in wanted:definitions[int(row['definition_id'])].append(row)
  prefixes={int(row['base_sprite_id']) for entries in definitions.values() for row in entries}
  models={prefix:[] for prefix in prefixes};file_index=collections.defaultdict(list)
  for row in csv_rows('sprites/source1_spr_rows.csv'):
   if not row['numeric_sprite_prefix'] or int(row['numeric_sprite_prefix']) not in prefixes:continue
   prefix=int(row['numeric_sprite_prefix']);digest=row['sha256'];local=digest in available
   item=[row['record_key'],row['name'],int(row['offset']),int(row['size']),digest,local,int(row['frames'] or 0)]
   models[prefix].append(item)
   match=re.fullmatch(r'\d+-(\d+)\.spr',row['name'],re.I)
   if match:file_index[prefix,int(match[1])].append(item)
  other_prefixes={int(link.get('base_id') if link.get('base_id') is not None else link['id']) for entity in entities for link in json.loads(entity['action_links']) if link['source']=='source2'}
  other_models={prefix:[] for prefix in other_prefixes}
  for row in csv_rows('sprites/source2_sprite_all_rows.csv'):
   if not row['numeric_sprite_prefix'] or int(row['numeric_sprite_prefix']) not in other_prefixes:continue
   prefix=int(row['numeric_sprite_prefix']);digest=row['sha256'];local=digest in available
   other_models[prefix].append([row['record_key'],row['name'],int(row['offset']),int(row['size']),digest,local,int(row['frames'] or 0)])
  output=[];counts=collections.Counter();missing_models=set()
  for entity in entities:
   ident=entity['sql_record_id'];row=npcs[ident];raw=row['fields'];assert raw['gfxid']==entity['graphics_id'] and raw['nameid']==entity['sql_nameid'] and raw['name']==entity['sql_name']
   assert row['provenance']['file_sha256']==entity['sql_sha256']
   kr=korean['rows'].get(ident,{})
   corroborated=kr.get('impl')=='L1Monster' and (kr.get('gfxid'),kr.get('nameid'))==(raw['gfxid'],raw['nameid']) and bool(re.search('[가-힣]',kr.get('name','')))
   name=kr.get('name') if corroborated else None
   model_candidates=[];complete=False;partial=False
   for definition in definitions[int(raw['gfxid'])]:
    prefix=int(definition['base_sprite_id']);actions=json.loads(definition['action_definitions']);by_code=collections.defaultdict(list)
    for action in actions:by_code[int(action['id'])].append(action)
    idle=3 if 3 in by_code else 0;roles={k:(v if v in by_code else idle) for k,v in [('idle',3),('walk',0),('attack',1),('hit',2),('death',8)]}
    issues=collections.Counter();required=set();unavailable=set();unresolved=[]
    for role,code in roles.items():
     candidates=by_code.get(code,[])
     if len(candidates)!=1:issues['action_missing_or_ambiguous']+=1;continue
     text=candidates[0]['definition'];refs=re.findall(r'(-?\d+)\.(\d+):(-?\d+)',text)
     if not refs:issues['literal_sequence_missing']+=1;continue
     count=re.match(r'\s*\d+\s+(\d+),',text)
     if not count or int(count[1])!=len(refs):issues['sequence_grammar_needs_review']+=1;continue
     for group,frame,duration in refs:
      if int(group)<0:issues['negative_reference_needs_review']+=1;continue
      for heading in range(8):
       suffix=int(group)+heading;required.add(suffix);records=file_index.get((prefix,suffix),[])
       hashes={r[4] for r in records if r[6]>0}
       if len(hashes)!=1:
        issues['original_record_missing_or_variant_ambiguous']+=1;unresolved.append(suffix);continue
       digest=next(iter(hashes))
       if digest not in available:issues['local_original_bytes_absent']+=1;unavailable.add(suffix)
       elif int(frame)>=available[digest]:issues['literal_frame_out_of_bounds']+=1
    local_count=sum(r[5] for r in models[prefix]);partial=partial or local_count>0
    passed=not issues;complete=complete or passed
    if unavailable or unresolved:missing_models.add(prefix)
    model_candidates.append(dict(model_key='source1:'+str(prefix),definition_record_key=definition['record_key'],definition_sha256=definition['raw_definition_sha256'],definition_name=definition['local_name'],required_suffixes=sorted(required),missing_local_suffixes=sorted(unavailable),unresolved_original_suffixes=sorted(set(unresolved)),literal_body_check_pass=passed,issues=dict(issues),fallback_roles={role:code for role,code in roles.items() if code!={'idle':3,'walk':0,'attack':1,'hit':2,'death':8}[role]}))
   other_candidates=[]
   for link in json.loads(entity['action_links']):
    if link['source']!='source2':continue
    prefix=int(link.get('base_id') if link.get('base_id') is not None else link['id'])
    other_candidates.append(dict(model_key='source2:'+str(prefix),definition_table=link['table'],definition_index=link['definition_index'],definition_name=link.get('name'),prefix_basis=link.get('prefix_basis'),identity_confirmed=False,local_record_count=sum(r[5] for r in other_models[prefix])))
   display=by_display.get((raw['gfxid'],raw['nameid']),[])
   if ident in EXCLUDED:status='explicit_user_exclusion'
   elif ident=='45153':status='appearance_hold'
   elif ident in selected:status='active_source_identity'
   elif display:status='same_source_display_and_model_variant'
   elif name and normal(name) in game_names:status='existing_game_name_candidate_not_automatic_binding'
   elif complete:status='local_literal_body_available_identity_review_required'
   elif partial:status='local_body_incomplete_or_ambiguous'
   elif any(v['local_record_count'] for v in other_candidates):status='other_namespace_pixels_available_identity_unresolved'
   else:status='original_body_bytes_required'
   counts[status]+=1
   record=dict(key='source3:tw380:Taiwan:npc:'+ident,npc_id=ident,source_name=raw['name'],nameid=raw['nameid'],gfx_id=int(raw['gfxid']),korean_name=name,korean_id_gfx_nameid_corroborated=corroborated,status=status,game_name_candidates=game_names.get(normal(name),[]) if name else [],same_display_model_active_ids=display,source_sql=row['provenance'],model_candidates=model_candidates,other_namespace_candidates=other_candidates,feature_scope='Only L1Monster; pet/quest/clan/siege exclusivity is not inferred from an ID or tamable flag')
   if ident in selected:record['game_source_id']=selected[ident]['sourceId']
   output.append(record)
 out=dict(schema=1,scope='Exhaustive 1693-row classification. Candidate/variant is not an activated identity or a claim that every original monster is implemented.',catalog_library_id='libfile_75db772b016c8191a00df045badca067',catalog_archive_sha256=CATALOG_SHA,catalog_members=['sprites/source3_sql_crosscheck.csv','sprites/source1_actions.csv','sprites/source1_spr_rows.csv','sprites/source2_sprite_all_rows.csv'],korean_reference={'url':korean['source_url'],'git_blob':korean['source_blob'],'policy':'Exact NPC id + gfxid + nameid + L1Monster corroboration; not official LineageM naming'},counts=dict(counts),active_game_species=len(games),record_columns=['record_key','original_filename','pak_byte_offset','bytes','sha256','verified_bytes_available_locally','decoded_frames'],original_pack_roots=pack_roots,local_bundle_blobs_verified=len(available),entities=output,models={**{'source1:'+str(prefix):dict(original_pack_root=pack_roots.get('source1'),records=records,local_record_count=sum(r[5] for r in records)) for prefix,records in sorted(models.items())},**{'source2:'+str(prefix):dict(original_pack_root=pack_roots.get('source2'),identity_policy='Separate source namespace; same prefix never establishes a source1 or SQL identity',records=records,local_record_count=sum(r[5] for r in records)) for prefix,records in sorted(other_models.items())}})
 enrich_game_records(out,root)
 (root/'data/monsters/source_identity_catalog.json').write_text(json.dumps(out,ensure_ascii=False,separators=(',',':'))+'\n')
 print('SOURCE_CLASSIFICATION_RESULT',dict(counts),'total',sum(counts.values()),'game',len(games),'models',len(models),'raw_records',sum(len(v) for v in models.values()))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--catalog',type=Path,required=True);p.add_argument('--monster-inputs',type=Path,required=True);p.add_argument('--transform-input',type=Path,required=True);p.add_argument('--source-input',type=Path,required=True);p.add_argument('--korean-reference',type=Path,required=True);p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);build(p.parse_args())
