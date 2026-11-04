"""Read-only full-source coverage audit for the remaining PR250 consumers."""
import argparse, collections, hashlib, json, zipfile
from pathlib import Path
SOURCE_SHA='d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
def audit(source, catalog):
 assert hashlib.sha256(source.read_bytes()).hexdigest()==SOURCE_SHA, 'original archive pin'
 with zipfile.ZipFile(source) as z:
  names=['Land','LandAttribute','LandAttributeType','Territories','BuffClass','BuffBonus','Bonus','BonusType','BonusApplicationType','Unit','InvokeOption','InvokeOptionType','AttackType','ItemClass','TrialTowerStage','OrimsTrailStage']
  raw={name:json.loads(z.read('content/'+name+'.json').decode('utf-8-sig'))['rows'] for name in names}
 full={name:{int(r['ID']):r for r in rows} for name,rows in raw.items()}
 c=json.loads(catalog.read_text()); actual=c['tables']
 def exact(table, row):
  assert actual.get(table,{}).get(str(row['ID']),{}).get('row')==row, (table,row['ID'],'not exact in runtime catalog')
 def typ(bonus): return full['BonusType'][bonus['BonusTypeID']]['Name']
 npc_types={r['ID'] for r in raw['LandAttributeType'] if r['Name']=='NpcBuff'}
 attrs=[r for r in raw['LandAttribute'] if r['LandAttributeTypeID'] in npc_types]
 buff_ids={r['Value'] for r in attrs}
 item_multipliers=[r for r in raw['BuffBonus'] if typ(full['Bonus'][r['BonusID']])=='NpcSingleItemDropProbabilityMultiple']
 required=buff_ids|{r['BuffClassID'] for r in item_multipliers}
 for row in attrs: exact('LandAttribute',row);exact('Land',full['Land'][row['LandID']])
 for bid in required: exact('BuffClass',full['BuffClass'][bid])
 for row in attrs:
  if row['TerritoryID']:exact('Territories',full['Territories'][row['TerritoryID']]);assert full['Territories'][row['TerritoryID']]['LandID']==row['LandID']
 drop_row_ids={r['ID'] for r in item_multipliers}
 relevant=[r for r in raw['BuffBonus'] if r['BuffClassID'] in buff_ids or r['ID'] in drop_row_ids]
 counts=collections.Counter(); invokes=set(); item_ids=set(); conditional=[]
 excluded=[r for r in raw['BuffBonus'] if r['BuffClassID'] in required and r not in relevant]
 for row in relevant:
  exact('BuffBonus',row); b=full['Bonus'][row['BonusID']];exact('Bonus',b)
  bt=full['BonusType'][b['BonusTypeID']];exact('BonusType',bt);exact('Unit',full['Unit'][bt['UnitID']]);counts[bt['Name']]+=1
  if bt['Name'] not in ['InvokeOption','NpcSingleItemDropProbabilityMultiple'] and (b['BonusApplicationTypeID'] or b['BonusApplicationTargetID']):conditional.append(row['ID'])
  if bt['Name']=='InvokeOption':invokes.add(b['BonusApplicationTargetID'])
 for row in item_multipliers:
  b=full['Bonus'][row['BonusID']];assert full['BonusApplicationType'][b['BonusApplicationTypeID']]['Name']=='ItemClass';assert b['BonusApplicationTargetID'] in full['ItemClass'];item_ids.add(b['BonusApplicationTargetID'])
 for iid in invokes:
  r=full['InvokeOption'][iid];exact('InvokeOption',r);exact('AttackType',full['AttackType'][r['AttackTypeID']]);exact('InvokeOptionType',full['InvokeOptionType'][r['InvokeOptionTypeID']])
 assert not conditional, ('unimplemented numeric source conditions',conditional)
 stages=collections.defaultdict(list)
 for table in ['TrialTowerStage','OrimsTrailStage']:
  for stage in raw[table]:
   territory=full['Territories'].get(stage['TeleportTerritoryID'],{})
   if territory.get('LandID') in {r['LandID'] for r in attrs}: stages[territory['LandID']].append({'table':table,**stage})
 contexts=[]
 for attribute in attrs:
  land=full['Land'][attribute['LandID']]
  contexts.append({'land_id':land['ID'],'asset_path':land['AssetPath'],'attribute_id':attribute['ID'],'buff_id':attribute['Value'],'territory_id':attribute['TerritoryID'],'direct_map_identity':land['AssetPath']==str(land['ID'])+'/','source_stages':stages.get(land['ID'],[]),'automatic_native_activation_tested':False})
 return {'native_contexts':contexts,'native_direct_identity_rows':sum(r['direct_map_identity'] for r in contexts),'requires_content_instance_or_explicit_own_context':sum(not r['direct_map_identity'] for r in contexts),'source_stage_links':sum(len(r['source_stages']) for r in contexts),'no_source_stage_parent_land_ids':[r['land_id'] for r in contexts if not r['direct_map_identity'] and not r['source_stages']],'excluded_other_personal_carrier_bonus_rows':len(excluded),'excluded_other_personal_carrier_effects':dict(collections.Counter(typ(full['Bonus'][r['BonusID']]) for r in excluded)),'unimplemented_numeric_conditions':conditional,'source_archive_sha256':SOURCE_SHA,'full_source_rows':{k:len(v) for k,v in raw.items()},'npc_buff_attributes':len(attrs),'unique_environment_buffs':len(buff_ids),'bounded_territory_rows':sum(r['TerritoryID']!=0 for r in attrs),'whole_land_rows':sum(r['TerritoryID']==0 for r in attrs),'environment_and_drop_unique_buffs':len(required),'related_buff_bonus_rows':len(relevant),'related_effects':dict(counts),'individual_drop_rows':len(item_multipliers),'individual_drop_buff_ids':sorted({r['BuffClassID'] for r in item_multipliers}),'individual_drop_item_ids':sorted(item_ids),'environment_invoke_ids':sorted(invokes),'all_runtime_source_rows_exact':True,'scope':'FULL_RELATED_SOURCE_RELATIONS; NOT ALL_NATIVE_ACTIVATION_OR_MAP_RENDERING','native_operation_without_context_claimed':False}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source-zip',type=Path,required=True);p.add_argument('--catalog',type=Path,required=True);p.add_argument('--output',type=Path);a=p.parse_args();r=audit(a.source_zip,a.catalog)
 if a.output:a.output.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps({k:v for k,v in r.items() if k!='native_contexts'},ensure_ascii=False))
