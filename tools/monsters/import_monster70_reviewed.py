#!/usr/bin/env python3
"""Rebuild five explicitly reviewed identities from the selected Library inputs.
Never choose a filename winner across variants or activate other candidates.
"""
import argparse, collections, hashlib, json, re, subprocess
from pathlib import Path
INPUTS = {
 'pr201_monster70_sprites_01.zip': ('libfile_05c6c387cf0c8191a66d207a37fc5faf','fe8ac53dcf65309429038b4d17b8b3954c75af6a96dbdb5ee9734975cf33ecbc'),
 'pr201_monster70_sprites_02.zip': ('libfile_f6c21cc38288819189822d924822dc21','7d0cedadb120a70c354a36f9f8ddf7aba58f4ead5f49eb127e7e0639623fa8d6'),
 'pr201_monster70_sprites_03.zip': ('libfile_b8553c5846bc8191a7e602938f9cd68c','8b96a3e6197d9d65ee3908543a16fbee5f87ccf47edc5c8a0eca56e63ab6cb3f'),
 'pr201_monster70_metadata.zip': ('libfile_8cfab2def2e081918b116d190a310a10','5d5f6b68d60e733690e8cd75a5a7fd1020e2964a41ea457c21088e2c310c6ce6')}
SELECTION = {'45130': ('해골 도끼병', 'source1:1104', 'base_pack'), '45309': ('블랙 티거', 'source1:3547', 'all_nonconflicting_packs'), '45171': ('네루가 오크', 'source1:788', 'all_nonconflicting_packs'), '45649': ('데몬', 'source1:1180', 'all_nonconflicting_packs'), '45604': ('마퀴스 뱀파이어', 'source1:2757', 'all_nonconflicting_packs')}
def read(p): return json.loads(p.read_text())
def write(p, x): p.write_text(json.dumps(x, ensure_ascii=False, separators=(',',':') if p.name=='source_identity_catalog.json' else None, indent=None if p.name=='source_identity_catalog.json' else 2)+'\n')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def build(a):
 for name,(_,expected) in INPUTS.items(): assert sha(a.input/name)==expected, name
 root=a.root.resolve(); meta=a.input/'metadata'; request=read(meta/'pr201-monster70-exact-extraction-request-20261030.json')
 provenance=[json.loads(l) for l in (meta/'provenance_manifest.jsonl').read_text().splitlines()]
 definitions={r['record_key']:r for r in map(json.loads,(meta/'source1_action_definitions.jsonl').read_text().splitlines())}
 entities={r['npc_id']:r for r in request['entities']}; sql={r['fields']['npcid']:r for r in map(json.loads,(a.source/'source_npcs.jsonl').read_text().splitlines())}
 a.work.mkdir(parents=True, exist_ok=True); plan={'species':[]}
 for ident,(name,model,variant) in SELECTION.items():
  e=entities[ident]; s=sql[ident]; raw=s['fields']; assert raw['impl']=='L1Monster' and e['korean_id_gfx_nameid_corroborated']
  assert (raw['gfxid'],raw['nameid'])==(str(e['gfx_id']),e['nameid']) and name==e['korean_name']
  assert s['provenance']==e['source_sql']
  if ident=='45171': continue  # Exact shared body, reuse existing verified pixels and tracks.
  candidate=next(c for c in e['model_candidates'] if c['model_key']==model); definition=definitions[candidate['definition_record_key']]
  assert candidate['definition_sha256']==definition['raw_definition_sha256']
  rows={}
  for r in provenance:
   if model not in r['model_keys'] or variant not in r['variant_contexts']:continue
   suffix=int(r['name'].split('-')[1].split('.')[0]); assert suffix not in rows;rows[suffix]=r
  tracks={}; used=collections.defaultdict(set)
  for role,code in [('idle',3),('walk',0),('attack',1),('hit',2),('death',8)]:
   action=next(x for x in definition['action_definitions'] if x['id']==(18 if ident=='45604' and role=='attack' else code)); refs=re.findall(r'(\d+)\.(\d+):(\d+)',action['definition'])
   assert len(refs)==int(action['definition'].split(',')[0].split()[-1])
   for facing in range(8):
    track=[]
    for group,frame,ticks in refs:
     suffix=int(group)+(facing+3)%8;r=rows[suffix];assert int(frame)<r['frames'];used[suffix].add(int(frame))
     track.append(dict(blob_sha256=r['sha256'],record_key=r['record_key'],frame_index=int(frame),duration_raw=int(ticks),file_suffix=suffix,requested_heading=(facing+3)%8,source_heading=(facing+3)%8))
    tracks[f'{role}_{facing}']=track
  selected=[]
  for suffix,frames in used.items():
   r=rows[suffix].copy();r['archive_path']=str(a.input/r['archive']);r['used_frames']=sorted(frames);selected.append(r)
  plan['species'].append(dict(npc_id=ident,directory=f'res://assets/monsters/reviewed_source/l1j_tw380_npc_{ident}',records=selected,tracks=tracks))
 plan_path=a.work/'render-plan.json';write(plan_path,plan)
 subprocess.run([str(a.godot),'--headless','--path',str(root),'--script','res://tools/monsters/import_monster70_reviewed.gd','--',str(plan_path)],check=True)
 def integral(v):
  if isinstance(v,float) and v.is_integer(): return int(v)
  if isinstance(v,list): return [integral(x) for x in v]
  if isinstance(v,dict): return {k:integral(x) for k,x in v.items()}
  return v
 rendered={r['npc_id']:integral(r['output']) for r in read(Path(str(plan_path)+'.rendered.json'))['species']}
 additions=read(root/'data/monsters/reviewed_source_additions.json'); additions['records']=[r for r in additions['records'] if r['source_npc_id'] not in SELECTION]
 base=next(r for r in additions['records'] if r['source_npc_id']=='45143')
 for ident,(name,model,variant) in SELECTION.items():
  raw=sql[ident]['fields']; resource=f'res://assets/monsters/reviewed_source/l1j_tw380_npc_{ident}/'; e=entities[ident]
  if ident=='45171':
   animation=json.loads(json.dumps(base['source_animation']));profile=base['animation_profile'].copy();portrait=base['source_portrait']
   animation['shared_body_identity']='45143 shares exact source1:788 body; different NPC/nameid; no new tribe color inferred'
  else:
   out=rendered[ident];canvas=out['canvas_original_grid'];w,h=canvas[2]-canvas[0],canvas[3]-canvas[1]
   additions['assets'].update(out['assets']);portrait=resource+'portrait.png'
   profile=dict(frames_path=resource+'frames.tres',layout='directional8',pixel_scale=1.0,authored_motion_weight=0.0,body_kind='special',sprite_offset=[canvas[0]+w/2-24,canvas[1]+h/2-18])
   animation=dict(source='source1',body_gfx=int(model.split(':')[1]),source_gfxid=int(raw['gfxid']),anchor_is_foot=False,canvas_original_grid=canvas,tracks=out['tracks'],composition='unmodified body RGBA; no guessed attachment/blend',timing='8fps local presentation; raw durations retained, no original tick conversion')
  record=dict(name=name,sourceId='l1j_tw380_npc_'+ident,source_id='source3:l1j-tw-99nets:L1J-TW_3.80c:Taiwan:npc:npcid:'+ident,source_npc_id=ident,source_name_original=raw['name'],source_version='3.80c',source_locale='Taiwan',source_raw_fields=raw,import_enabled=True,catalog_only=True,identity_approval='USER_REVIEWED_SQL_AND_EXISTING_BYTES_20261030',source_portrait=portrait,lv=int(raw['lvl']),hp=int(raw['hp']),mp=int(raw['mp']),ac=int(raw['ac']),mr=int(raw['mr']),xp=int(raw['exp']),undead=raw['undead']!='0',grade='일반',drop=[],animation_profile=profile,source_animation=animation,visual_grounding=dict(foot_original_grid=[24,18],policy='TWILIGHT cosmetic ground point reviewed across directions; not authenticated original anchor'),runtime_limits='Source HP/MP/AC/MR/level/XP retained; existing actor defaults/clamps and 8fps presentation. Explicit habitats only.',identity_review_evidence=dict(SQL=sql[ident]['provenance'],korean_reference=dict(npc_id=ident,gfxid=raw['gfxid'],nameid=raw['nameid'],name=name,corroboration='exact catalog SQL ID/gfx/nameid'),source_model=model,source_variant=variant,source_definition=e['model_candidates'][0]['definition_record_key'],actual_visual_review={'45130':'Skeleton with an axe; base_pack kept coherent; numbered shard variant preserved separately, never mixed','45309':'Black/gold striped quadruped; distinct source gfx3547 from existing sabre tiger gfx2086','45171':'Spear-bearing green orc; exact source1:788 body shared with Duda-Mara, distinct Neruga NPC45171/nameid$495 vs45143/$498','45649':'Large red winged horned demon; exact definition1180, canonical identity distinct from lesser/albino variants; source SQL note explicitly Ivory Tower8F BOSS','45604':'Cloaked humanoid vampire; exact named NPC45604/gfx2757/nameid verified. Action18 spell body used for existing local magic attack; original linked effects2759/2760/2761/2762 and original spell mechanics remain unimplemented'}[ident]))
  if ident=='45649':
   record['is_boss']=True;record['local_named_encounter']=True
   record['boss_classification_evidence']={'field':'source_raw_fields.note','value':raw['note'],'policy':'Explicit source boss annotation; existing boss presentation/rates/cooldown only, no imported spells or source chances'}
  if ident=='45604':
   record['local_named_encounter']=True;record['attack_type']='magic';record['attack_range']=280
   record['runtime_design']={'attack_type':'Existing TWILIGHT magic attack; no original spell formula imported','attack_range':'Existing local caster default280','attack_body_action':18,'unattached_source_effect_ids':[2759,2760,2761,2762]}
  additions['records'].append(record)
 write(root/'data/monsters/reviewed_source_additions.json',additions)
 catalog_path=root/'data/monsters/source_identity_catalog.json';catalog=read(catalog_path)
 for e in catalog['entities']:
  if e['npc_id'] in SELECTION:
   e.update(status='active_source_identity',game_source_id='l1j_tw380_npc_'+e['npc_id'],game_name=SELECTION[e['npc_id']][0],activation_review='monster70_review.json')
 catalog['game_records']=[r for r in catalog['game_records'] if r.get('game_source_id') not in ['l1j_tw380_npc_'+k for k in SELECTION]]
 for ident,(name,_,_) in SELECTION.items():catalog['game_records'].append(dict(game_key='twilight:monster:'+hashlib.sha256(name.encode()).hexdigest()[:16],name=name,game_source_id='l1j_tw380_npc_'+ident,status='exact_source_identity',source_candidates=['source3:tw380:Taiwan:npc:'+ident]))
 catalog['game_records'].sort(key=lambda r:r['name']);catalog['counts']=dict(collections.Counter(e['status'] for e in catalog['entities']));catalog['active_game_species']=len(catalog['game_records']);catalog['reverse_counts']=dict(collections.Counter(r['status'] for r in catalog['game_records']));write(catalog_path,catalog)
 review=[]
 prior_games=[g for g in catalog['game_records'] if g.get('game_source_id') not in ['l1j_tw380_npc_'+k for k in SELECTION]]
 all_entities={e['key']:e for e in catalog['entities']}
 game_models=collections.defaultdict(set)
 for g in prior_games:
  for key in g['source_candidates']:
   for c in all_entities[key]['model_candidates']:game_models[c['model_key']].add(g['name'])
 for ident,(name,model,_) in SELECTION.items():game_models[model].add(name)
 legacy={'source1:1022':['말하는 섬 고블린'],'source1:30':['말하는 섬 해골']}
 for e in request['entities']:
  models=[c['model_key']for c in e['model_candidates']]
  existing=sorted({name for model in models for name in game_models[model]})
  semantic=sorted({name for model in models for name in legacy.get(model,[])})
  if e['npc_id'] in SELECTION: status='activated_reviewed_identity'
  elif e['npc_id'] in ['45916','45611']: status='excluded_quest_identity';existing=[]
  elif e['npc_id']=='45315': status='phase_variant_hold';existing=[]
  elif e['npc_id']=='45771': status='attachment_composition_hold';existing=[]
  elif not e['korean_name']: status='untranslated_identity_hold'
  elif existing or semantic: status='existing_model_or_region_variant_review'
  else: status='named_or_composition_review'
  review.append(dict(npc_id=e['npc_id'],source_name=e['source_name'],korean_name=e['korean_name'],nameid=e['nameid'],gfx_id=e['gfx_id'],model_candidates=models,status=status,existing_game_model_candidates=existing,legacy_species_name_candidates=semantic,source_note=sql[e['npc_id']]['fields']['note']))
 write(root/'data/monsters/monster70_review.json',dict(schema=1,policy='198 exact source identities reviewed against prior438 species. Primary images of70 literal body models inspected; not every action/variant visually certified. Existing exact and name-candidate model references both checked; a candidate is not automatic identity approval. SQL quest notes exclude45916/45611. Fairy5684 clothes856/5558 bytes are already in the permitted effect packs; composition/blend semantics remain unverified, not silently omitted. Same model alone proves neither identity nor duplicate. Unknown translations/region, event, phase variants remain inactive; no pet/NPC/object inference from gfx number. Five selected identities; demon has explicit source boss annotation.',selection=SELECTION,counts=dict(collections.Counter(r['status']for r in review)),rows=review,input_sha256={p.name:sha(p)for p in sorted(a.input.glob('*.zip'))},input_library_ids={name:ref[0] for name,ref in INPUTS.items()}))
 habitat_path=a.work/'habitats.json'
 subprocess.run([str(a.godot),'--headless','--path',str(root),'--script','res://tools/maps/build_monster70_habitats.gd','--',str(habitat_path)],check=True)
 habitat_file=root/'data/monsters/local_source_habitats.json'; habitats=read(habitat_file)
 habitats['rows']=[r for r in habitats['rows'] if str(r.get('source_npc_id','')) not in SELECTION]+integral(read(habitat_path))
 write(habitat_file,habitats)
 print('MONSTER70_REVIEW',collections.Counter(r['status']for r in review))
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--input',type=Path,required=True);p.add_argument('--source',type=Path,required=True);p.add_argument('--godot',type=Path,required=True);p.add_argument('--work',type=Path,required=True);p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);build(p.parse_args())
