"""LOCAL_ONLY delta from the held tested candidate; no upload/ref mutation."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from patch523_enhancement import compile_equipment

BASE_SHA='bcafb3e219145ce94ebf519e428a065808f58aad5539cdabbc81ae950953ba7d'
NEW_TYPES={'PierceMeleeDamageReduction','PierceRangeDamageReduction','PierceMagicDamageReduction'}
def sha(data):return hashlib.sha256(data).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--report',type=Path,required=True);a=p.parse_args()
 original=a.base.read_bytes()
 if sha(original)!=BASE_SHA:raise ValueError('exact previously tested candidate required')
 data=json.loads(original);types={int(k):v for k,v in data['bonus_types'].items()};bonuses=data['bonuses'];enchantment=data['enchantment'];opts={r['ID']:r for r in enchantment['InvokeOption']}
 selected={};source_rows=set()
 for iid,runtime in data['equipment_runtime'].items():
  pending=set(runtime['unconnected_effect_row_ids'])
  for row in data['items'][iid]['enchant_effects']:
   if row['ID'] not in pending:continue
   b=bonuses[str(row['BonusID'])];name=types[b['BonusTypeID']]['Name']
   if name in NEW_TYPES or (name=='InvokeOption' and b['BonusApplicationTypeID']==10 and opts[b['BonusApplicationTargetID']]['InvokeOptionTypeID']==6):selected[iid]=data['items'][iid];source_rows.add(row['ID'])
 old_pending={i for r in data['equipment_runtime'].values() for i in r['unconnected_effect_row_ids']}
 tables={'BonusType':list(types.values()),**{n:enchantment[n] for n in ['InvokeOption','SpecialResistanceType','ItemBlessBonus']}}
 rebuilt=compile_equipment(tables,selected,bonuses)
 data['equipment_runtime'].update(rebuilt)
 new_pending={i for r in data['equipment_runtime'].values() for i in r['unconnected_effect_row_ids']}
 if old_pending-new_pending!=source_rows or new_pending-old_pending:raise ValueError('delta changed unrelated pending source rows')
 if len(source_rows)!=36:raise ValueError('expected entire 15 weapon scale +21 typed flat source row set')
 data['local_effect_revision']={'parent_sha256':BASE_SHA,'scope':'LOCAL_ONLY weapon-base scale and labelled existing typed-flat projection','source_rows':sorted(source_rows)}
 encoded=(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n').encode()
 a.output.write_bytes(encoded)
 result={'candidate':{'path':str(a.output),'bytes':len(encoded),'sha256':sha(encoded),'status':'LOCAL_ONLY'},'changed_item_ids':sorted(selected,key=int),'new_source_rows':len(source_rows),'new_source_row_ids':sorted(source_rows),'remaining_rows_before':len(old_pending),'remaining_rows_after':len(new_pending),'recipes_unchanged':len(data['recipes']),'source_files_unchanged':data['source_files']==json.loads(original)['source_files'],'source_raw_unchanged':data['raw_recipes']==json.loads(original)['raw_recipes']}
 a.report.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()
