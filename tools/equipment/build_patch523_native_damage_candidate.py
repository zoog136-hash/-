"""LOCAL_ONLY source damage/counter subset; preserve original source and old packs."""
import argparse,datetime,hashlib,json,zipfile
from pathlib import Path
from patch523_native_spells import compile_profile,compile_buff_profile
from patch523_enhancement import compile_equipment
BASE_SHA='59bf7411bed3220b7b721b9a936fb642e6542c452ebbe634fb6f3273f4d84b44'
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--report',type=Path,required=True);p.add_argument('--source-content',type=Path,default=Path('/workspace/source523/current/content'));p.add_argument('--source-archive',type=Path,default=Path('/workspace/source523/lineagem_patch523_all_content_validated_and_508_520_deltas.zip'));a=p.parse_args()
 if a.output.exists():raise ValueError('preserve existing candidates')
 original=a.base.read_bytes();assert sha(original)==BASE_SHA;data=json.loads(original)
 root=a.source_content;archive=a.source_archive
 with zipfile.ZipFile(archive) as z:index=json.loads(z.read('index.json'))
 metadata={r['path'].split('/')[-1].removesuffix('.json'):r for r in index};verified={}
 def table(name):
  raw=(root/(name+'.json')).read_bytes();assert sha(raw)==metadata[name]['sha256'];verified[name]={'sha256':sha(raw),'bytes':len(raw),'path':metadata[name]['path']};return json.loads(raw.decode('utf-8-sig'))['rows']
 spells={r['ID']:r for r in table('SpellClass')};source_bonuses={r['ID']:r for r in table('Bonus')};source_types={r['ID']:r for r in table('BonusType')};types={int(k):v for k,v in data['bonus_types'].items()};bonuses=data['bonuses'];units={r['ID']:r for r in table('Unit')};sb=table('SpellBonus');buff_class_rows=table('BuffClass');buff_bonus_rows=table('BuffBonus');date_rows={r['ID']:r for r in table('DateTimes_Korean')};enchantment=data['enchantment'];options={r['ID']:r for r in enchantment['InvokeOption']}
 referenced={o['Param1'] for o in options.values() if o['InvokeOptionTypeID']==1};effects={i:[] for i in referenced}
 for link in sb:
  if link['SpellClassID'] not in referenced:continue
  b=source_bonuses[link['BonusID']]
  t=source_types[b['BonusTypeID']];effects[link['SpellClassID']].append({'link':link,'bonus':b,'type':t,'unit':units.get(t['UnitID'],{})})
 buff_ids={e['bonus']['Value'] for es in effects.values() for e in es if e['type']['Name']=='BuffClassID'}
 buff_effects={i:[] for i in buff_ids}
 for link in buff_bonus_rows:
  if link['BuffClassID'] not in buff_effects:continue
  b=source_bonuses[link['BonusID']];t=source_types[b['BonusTypeID']];buff_effects[link['BuffClassID']].append({'link':link,'bonus':b,'type':t,'unit':units.get(t['UnitID'],{})})
 buffs={str(r['ID']):{'source_buff':r,'effects':buff_effects[r['ID']]} for r in buff_class_rows if r['ID'] in buff_ids}
 profiles={str(i):v for i in sorted(referenced) if i in spells and (v:=compile_profile({'source_spell':spells[i],'effects':effects[i]}))}
 for i in sorted(referenced):
  if str(i) not in profiles and i in spells:
   buff_profile=compile_buff_profile({'source_spell':spells[i],'effects':effects[i]},buffs)
   if buff_profile:profiles[str(i)]=buff_profile
 assert '69301' in profiles and len(profiles)>=26, 'full SpellBonus/Bonus/BonusType closure is required'
 # The raw profile input is exact. Only rows already in our remaining equipment
 # family are candidates; this does not turn all source spells into casts.
 selected={};source_rows=set();constraints={}
 for iid,runtime in data['equipment_runtime'].items():
  pending=set(runtime['unconnected_effect_row_ids']);item=data['items'][iid]
  for row in item['enchant_effects']:
   if row['ID'] not in pending:continue
   b=bonuses[str(row['BonusID'])]
   if types[b['BonusTypeID']]['Name']!='InvokeOption' or b['BonusApplicationTypeID']!=10:continue
   o=options[b['BonusApplicationTargetID']]
   if (o['InvokeOptionTypeID']==1 and str(o['Param1']) in profiles) or o['InvokeOptionTypeID']==61:selected[iid]=item
 def item_constraint(item):
  result={'schema':'patch523-equipment-spell-item-v1','delete_times':[],'blocked_reason':''}
  for link in item['item_bonuses']:
   b=bonuses[str(link['BonusID'])];kind=types[b['BonusTypeID']]['Name']
   if kind!='DeleteTime':continue
   row=None
   if b['BonusApplicationTypeID']==298 and b['Value']==0:row=date_rows.get(b['BonusApplicationTargetID'])
   elif b['BonusApplicationTypeID']==0 and b['BonusApplicationTargetID']==0:
    if b['Value']==0:continue
    text=str(b['Value'])
    if len(text)==10:row={'Year':int(text[:4]),'Month':int(text[4:6]),'Day':int(text[6:8]),'Hour':int(text[8:10]),'Minute':0}
   if row is None:result['blocked_reason']='원본 DeleteTime 조건 해석 필요';continue
   try:dt=datetime.datetime(*(row[k] for k in ['Year','Month','Day','Hour','Minute']),tzinfo=datetime.timezone.utc)
   except (ValueError,TypeError):result['blocked_reason']='원본 DeleteTime 날짜 확인 필요';continue
   result['delete_times'].append({'bonus':b,'date_row':row,'local_unix':int(dt.timestamp())})
  return result
 tables={'BonusType':list(types.values()),**{n:enchantment[n] for n in ['InvokeOption','SpecialResistanceType','ItemBlessBonus']},'EquipmentSpellProfiles':profiles}
 old_pending={i for r in data['equipment_runtime'].values() for i in r['unconnected_effect_row_ids']};rebuilt=compile_equipment(tables,selected,bonuses)
 for iid,rt in rebuilt.items():
  removed=set(data['equipment_runtime'][iid]['unconnected_effect_row_ids'])-set(rt['unconnected_effect_row_ids']);source_rows.update(removed)
  constraints[iid]=item_constraint(selected[iid])
 data['equipment_runtime'].update(rebuilt);new_pending={i for r in data['equipment_runtime'].values() for i in r['unconnected_effect_row_ids']}
 assert old_pending-new_pending==source_rows and not new_pending-old_pending
 used={str(o['Param1']) for r in rebuilt.values() for bs in r['invokes'].values() for es in bs.values() for e in es if e['kind']=='attack_source_spell' for o in [e.get('option',options.get(e.get('option_id'),{}))]}
 data['equipment_spell_profiles']={i:profiles[i] for i in sorted(used,key=int)};data['equipment_spell_item_constraints']=constraints;data['equipment_spell_source_files']=verified
 data['local_effect_revision']={'parent_sha256':BASE_SHA,'status':'LOCAL_ONLY','scope':'existing SkillService native damage/counter execution','source_rows':sorted(source_rows)}
 encoded=(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n').encode();assert len(encoded)<128*1024*1024;a.output.write_bytes(encoded)
 report={'status':'LOCAL_ONLY_NOT_UPLOADED','candidate':str(a.output),'bytes':len(encoded),'sha256':sha(encoded),'source_rows':sorted(source_rows),'new_distinct_rows':len(source_rows),'selected_item_bindings':len(rebuilt),'executable_profile_ids':sorted(used,key=int),'profile_count':len(used),'remaining_before':len(old_pending),'remaining_after':len(new_pending),'recipes_unchanged':len(data['recipes']),'expired_bindings':{i:v['delete_times'] for i,v in constraints.items() if v['delete_times']},'blocked_item_contracts':{i:v['blocked_reason'] for i,v in constraints.items() if v['blocked_reason']},'verified_source_tables':verified}
 a.report.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k not in ['source_rows','expired_bindings','verified_source_tables']},ensure_ascii=False))
if __name__=='__main__':main()
