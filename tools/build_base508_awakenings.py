#!/usr/bin/env python3
"""Exact BuffCard joins for distinct native option/skill awakening catalogs."""
import argparse, collections, hashlib, json, pathlib, zipfile

MAP={'HPPlus':'hpFlat','HPPlusPercent':'hpPct','Strength':'strFlat','Dexterity':'dexFlat',
     'Intelligence':'intFlat','CarryPlus':'weightBonus','ArmorClass':'def','AttackSpeedBonus':'attackSpeed',
     'MoveSpeedBonus':'moveSpeedPct','ExperienceAdditionPercent':'xp',
     'EinasadSavingPercent':'blessing_consumption_reduction_pct','SpellCastDelayDecreasePercent':'skillCooldownPct',
     'PierceDamageReduction':'damage_reduction_ignore','MeleeHit':'meleeHit','RangeHit':'rangedHit','MagicHit':'magicHit',
     'HPPotionIncreaseStatic':'potionHealFlat','SpellPower':'sp'}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--tables',type=pathlib.Path,required=True);p.add_argument('--canonical',type=pathlib.Path,required=True);p.add_argument('--skill-evidence',type=pathlib.Path,required=True);p.add_argument('--output-dir',type=pathlib.Path,required=True);a=p.parse_args()
 evidence=json.loads(a.skill_evidence.read_text());assert hashlib.sha256(a.tables.read_bytes()).hexdigest()==evidence['source_zip_sha256']
 z=zipfile.ZipFile(a.tables); hashes={}
 def table(name):
  raw=z.read('content/'+name+'.json');hashes[name]=hashlib.sha256(raw).hexdigest();return json.loads(raw.decode('utf-8-sig'))['rows']
 cards={r['ID']:r for r in table('BuffCard')};desc={r['ID']:r['Description'] for r in table('DescData_Korean')}
 bonuses={r['ID']:r for r in table('Bonus')};types={r['ID']:r for r in table('BonusType')};units={r['ID']:r for r in table('Unit')};uiunits={r['UnitID']:r for r in table('UIUnit')}
 canonical=json.loads(a.canonical.read_text())['catalog'];records={};bycard={}
 for category,rows in canonical.items():
  for r in rows:
   raw=cards[r['source_card_id']];assert raw['BuffCardDeckID']==r['source_deck_id'] and raw['GradeID']==r['source_grade_id']
   key='source:'+r['sourceId'];assert r['sourceId']==f"m508:{raw['BuffCardDeckID']}:{raw['ID']}";assert key not in records and raw['ID'] not in bycard
   records[key]={'id':key,'category':category,'name':r['name'],'grade':r['grade'],'source_card':raw};bycard[raw['ID']]=records[key]
 assert len(records)==701
 groups=table('BuffCardOptionAwakenGroup');links=table('BuffCardOptionAwakenLevelBonus');bygroup=collections.defaultdict(list)
 for link in links:bygroup[link['BuffCardOptionAwakenGroupID']].append(link)
 limits={int(r['ServerLimitSetID']) for r in cards.values() if r['ID'] in bycard}
 limits.update(int(g['ServerLimitsetID']) for g in groups if g['BuffCardID'] in bycard)
 server=[r for r in table('ServerLimit') if r['ServerLimitSetID'] in limits]
 defs=[]
 for g in groups:
  if g['BuffCardID'] not in bycard or g['SlotIndex']!=1:continue
  card=bycard[g['BuffCardID']];stats={};applied=[];pending=[];effects=[]
  for link in bygroup[g['ID']]:
   bonus=bonuses[link['BonusID']];typ=types[bonus['BonusTypeID']];unit=units[typ['UnitID']];ui=uiunits.get(typ['UnitID'],{});den=ui.get('Denominator',1);value=bonus['Value'];name=typ['Name'];key=MAP.get(name)
   supported=link['Level']==1 and bonus['BonusApplicationTypeID']==0 and bonus['BonusApplicationTargetID']==0 and key is not None
   if unit['Name'] in ['Percentage','ValuePercent','Weight'] and den>0:value/=den
   elif unit['Name']!='Value':supported=False
   if isinstance(value,float) and value.is_integer():value=int(value)
   if supported:stats[key]=stats.get(key,0)+value
   label=(desc.get(typ['DescID']) or name)+' '+str(value)+('%' if unit['Name'] in ['Percentage','ValuePercent'] else '')
   (applied if supported else pending).append(label)
   effects.append({'link':link,'bonus':bonus,'type':typ,'unit':unit,'ui_unit':ui,'runtime_supported':supported})
  secondary=[r for r in groups if r['BuffCardID']==g['BuffCardID'] and r['SlotIndex']!=1]
  if secondary:pending.append('원본 추가 옵션 슬롯 '+','.join(str(r['SlotIndex']) for r in secondary)+' · 기존 단일 각성 상태와 별도 처리 필요')
  assert effects
  defs.append({'category':card['category'],'id':card['id'],'expected_name':card['name'],'grade':card['grade'],'mapping':'exact_source_BuffCardID_deck','bonus_options':applied+pending,'applied_options':applied,'pending_options':pending,'stats':stats,'native_source':{'card':card['source_card'],'group':g,'effects':effects,'limits':[card['source_card']['ServerLimitSetID'],g['ServerLimitsetID']],'secondary_groups':secondary}})
 option={'schema':1,'source_snapshot':'base508','definitions':defs,'raw_groups':groups,'raw_level_links':links,'source_server_limits':server,'source_table_sha256':dict(hashes)}
 spells={str(s['ID']):{'source_spell':s,'name':desc.get(s['DescID']) or s['Name']} for s in evidence['candidate_spells'] if s['ID']!=0}
 for s in spells.values():
  sid=s['source_spell']['ID'];s['effects']=[]
  for link in evidence['candidate_spell_bonus_links']:
   if link['SpellClassID']==sid:
    bonus=bonuses[link['BonusID']];typ=types[bonus['BonusTypeID']];s['effects'].append({'link':link,'bonus':bonus,'type':typ,'unit':units[typ['UnitID']]})
 books=[]
 for chain in evidence['book_pool_chains']:
  row=dict(chain);row['name']=desc.get(chain['item_row']['DescID']) or chain['item_row']['Name'];books.append(row)
 skill={'schema':1,'source_snapshot':'base508','cards':records,'tables':evidence['core_tables'],'books':books,'spells':spells,'source_server_limits':server,'unknown_rules':evidence['known_vs_unknown']['not_confirmed'],'source_table_sha256':dict(hashes),'source_evidence_sha256':hashlib.sha256(a.skill_evidence.read_bytes()).hexdigest()}
 a.output_dir.mkdir(parents=True,exist_ok=True)
 for name,obj in [('base508_option_awakening.json',option),('base508_skill_awakening.json',skill)]:
  (a.output_dir/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
 print('701 exact cards;',len(defs),'native option targets;',len(books),'skill book links;',len(spells),'live skill definitions')
if __name__=='__main__':main()
