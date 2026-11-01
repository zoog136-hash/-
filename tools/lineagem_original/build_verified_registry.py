"""Project verified base508 tables into namespaced runtime definitions.
No legacy numeric-ID matching, no guessed units, no inferred creature levels.
"""
import argparse,collections,gzip,hashlib,json,pathlib
import original_spr
CATEGORIES={'transformation':'변신','magic_doll':'마법인형','holy_relic':'성물'}
FLAT_FIELDS={'HPPlus':'hpFlat','MPPlus':'mpFlat','Strength':'strFlat','Dexterity':'dexFlat','Intelligence':'intFlat','Wisdom':'wisFlat','Constitution':'conFlat','Charisma':'chaFlat','MagicResist':'mr','DamageReduction':'damage_reduction'}
def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def unique(rows,key='ID'):
 result={}
 for row in rows:
  if row[key] in result:raise ValueError(f'duplicate {key}: {row[key]}')
  result[row[key]]=row
 return result

def build(inputs,output):
 identity=inputs/'base508_identity_verified_tables';content=inputs/'base508_all_content_validated/content'
 definitions=read(identity/'identity_definitions.json')['rows']
 declarations=original_spr.read((inputs/'lineagem-category-source-metadata/original-spr').glob('*.spr'))
 source_cards=unique(read(identity/'BuffCard_selected.json')['rows'])
 bonus=unique(read(identity/'Bonus_selected.json')['rows']);types=unique(read(content/'BonusType.json')['rows']);units=unique(read(content/'Unit.json')['rows'])
 descriptions=unique(read(content/'DescData_Korean.json')['rows'])
 joins=collections.defaultdict(list)
 for row in read(identity/'BuffBonus_selected.json')['rows']:joins[row['BuffClassID']].append(row)
 run_rows=read(content/'SpriteRun.json')['rows'];run=unique(run_rows,'WalkSpriteID')
 separated_rows=read(content/'SpriteSeparatedWalk.json')['rows'];separated=unique(separated_rows,'SpriteId')
 categories={v:[] for v in CATEGORIES.values()};exceptions=[]
 identity_rules=read(inputs/'remaining_card_identity_rules.json') if (inputs/'remaining_card_identity_rules.json').exists() else {}
 rules_by_id={r['card_id']:r for r in identity_rules.get('records',[])}
 for d in definitions:
  role=CATEGORIES[d['role']];sid=f"m508:{d['deck_id']}:{d['card_id']}";original_card=source_cards[d['card_id']]
  record={'name':d['localized_name'],'grade':d['grade_name'],'type':'공통','source':'lineagem_base508','sourceId':sid,'source_card_id':d['card_id'],'source_deck_id':d['deck_id'],'source_grade_id':d['grade_id'],'source_grade_tier_id':d['grade_tier_id'],'source_internal_name':d['internal_name'],'source_display_sprite_id':d['display_sprite_id'],'source_inworld_sprite_ids':d['inworld_sprite_ids'],'source_original':d,'source_original_card':original_card,'source_bonuses':[],'source_stat_application':[],'image_path':'','source_ui_assets':d['ui_assets'],'sourceOptions':[],'sourceOptionsRaw':[],'desc':'','source_visual_status':'pending_native_pack','source_merge_out_disabled':original_card['IsNoMergeOut'],'source_swap_out_disabled':original_card['IsNoSwapOut']}
  rule=rules_by_id.get(d['card_id'])
  if rule:
   record['source_identity_rule_id']=d['card_id']
   record['source_identity_selection_kind']=rule['selection_kind']
   record['source_identity_rule_status']=rule['status']
   if rule['selection_kind']=='indirect_subslot_buff_summon':record['source_inworld_sprite_ids']=[rule['inworld_sprite_id']];record['source_summon_application_condition']=rule['native_application_condition']
  options=[]
  for link in joins[d['buff_class_id']]:
   b=bonus[link['BonusID']];t=types[b['BonusTypeID']];u=units[t['UnitID']];desc=descriptions.get(t['DescID'],{}).get('Description','')
   detail={'buff_bonus':link,'bonus':b,'bonus_type':t,'unit':u,'localized_description':desc,'application':'raw_preserved_pending_semantics'}
   direct=all(link.get(k,0)==0 for k in ['CharacterLevel','CharacterClass','MinSpellLevel']) and b.get('BonusApplicationTypeID',0)==0 and b.get('BonusApplicationTargetID',0)==0
   if u['ID']==1 and direct:
    detail['application']='unconditional_native_value'
    options.append(f"{desc} {b['Value']:+d}" if desc else f"{t['Name']} {b['Value']:+d}")
    if t['Name'] in FLAT_FIELDS:
     field=FLAT_FIELDS[t['Name']];record[field]=record.get(field,0)+b['Value'];record['source_stat_application'].append({'field':field,'source_bonus_id':b['ID'],'rule':'Unit1_Value_direct'})
   record['source_bonuses'].append(detail)
  record['desc']=' · '.join(options);record['sourceOptions']=options
  record['sourceOptionsRaw']=[{'type_id':x['bonus_type']['ID'],'value':x['bonus']['Value'],'unit_id':x['unit']['ID']} for x in record['source_bonuses']]
  record['source_sprite_bindings']=[{'sprite_id':sprite,'run_sprite_id':run.get(sprite,{}).get('RunSpriteID'),'walk_action_hint':separated.get(sprite,{}).get('WalkActionType')} for sprite in record['source_inworld_sprite_ids']]
  record['source_active_spr_evidence']=[{'sprite_id':sprite,'file':declarations[sprite][0].source_file,'line':declarations[sprite][0].source_line,'alias_target':declarations[sprite][0].alias_target} for sprite in record['source_inworld_sprite_ids'] if len(declarations.get(sprite,[]))==1]
  if not d['inworld_links'] and not rule:exceptions.append({'card_id':d['card_id'],'reason':'inworld_chain_unconfirmed','localized_name':d['localized_name']})
  if len(d['inworld_sprite_ids'])>1:record['source_variant_selection']='source_base_or_explicit_active_custom_option' if rule and rule['selection_kind']=='base_polymorph_or_declared_custom_sprite_option' else 'explicit_class_gender_context_required'
  categories[role].append(record)
 assert {k:len(v) for k,v in categories.items()}=={'변신':388,'마법인형':167,'성물':146}
 result={'schema':1,'source_snapshot':'base508','authority':'verified_BuffCardDeck_BuffClass_Bonus_PolymorphEntity_NpcClass_DescData_Grade_joins','catalog':categories,'exceptions':exceptions,'run_sprite_relationships':run_rows,'classes':[],'limits':['Registry definitions are not a visual quality approval.','Native percentage conversions and conditional bonuses are not guessed.','No legacy identity is silently migrated by name or numeric ID.']}
 for c in read(content/'Class.json')['rows']:
  if c.get('CanCreateClient'):
   result['classes'].append({'source_original':c,'name':descriptions.get(c['DescID'],{}).get('Description'), 'male_sprite_id':c['MaleSpriteID'],'female_sprite_id':c['FemaleSpriteID']})
 output.mkdir(exist_ok=True,parents=True)
 if identity_rules:(output/'identity_rules.json').write_text(json.dumps(identity_rules,ensure_ascii=False,separators=(',',':'))+'\n')
 (output/'cards.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
 npc_path=inputs/'lineagem-monster-boss-metadata/client_npc_stats.json.gz';npc=json.load(gzip.open(npc_path,'rt'))
 unique(npc['rows']);assert len(npc['rows'])==9470
 (output/'npc_classes.json').write_text(json.dumps({'schema':1,'source_snapshot':'base508','rows':npc['rows'],'limits':['Not a roster of9470 monsters.','No guessed Level; source IDs and variants retained.','NpcAttribute andNpcAttack remain in the validated input package.']},ensure_ascii=False,separators=(',',':'))+'\n')
 print(json.dumps({'cards':{k:len(v) for k,v in categories.items()},'inworld_chains':701 if identity_rules else 700,'npc_rows':9470,'classes':len(result['classes']),'exceptions':exceptions},ensure_ascii=False))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--inputs',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();build(a.inputs,a.output)
