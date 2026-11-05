#!/usr/bin/env python3
"""Project a small private gear view from verified239 rules; never build rules again."""
import argparse,hashlib,json,os,tempfile
from pathlib import Path
SOURCE='5e6ffac68fab01ba6de84226c1407f3076320aa8681fb83573116a2f822cb8d6'
IDS=[240,248,249,305,349,383,427,587,691,829,917,926,929,1129,1197,2772,2802,2832,2862,2872,3042,4851,4871,4921,4951,4971,5021,9091,30213,85643,226318]
def build(source,output):
 raw=source.read_bytes()
 if len(raw)!=124512155 or hashlib.sha256(raw).hexdigest()!=SOURCE:raise ValueError('exact existing239 input required')
 original=json.loads(raw)
 result={k:original[k] for k in ['snapshot','catalog_sha256','source_files']}
 result.update(schema='twilight-quest-equipment-view-v1',source_rules_sha256=SOURCE,items={},equipment_runtime={})
 for iid in map(str,IDS):
  bound=original['items'][iid];runtime=original['equipment_runtime'][iid]
  result['items'][iid]={'item_class':bound['item_class'],'enchant_effects':[r for r in bound['enchant_effects'] if r['EnchantLevel']==0]}
  result['equipment_runtime'][iid]={k:{'1':{'0':runtime.get(k,{}).get('1',{}).get('0',[] if k=='invokes' else {})}} for k in ['options','extra_options','invokes']}
  result['equipment_runtime'][iid]['unconnected_effect_row_ids']=runtime.get('unconnected_effect_row_ids',[])
 encoded=(json.dumps(result,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n').encode()
 output.parent.mkdir(parents=True,exist_ok=True)
 if output.exists():
  if output.read_bytes()!=encoded:raise ValueError('preserve existing different output')
 else:
  with tempfile.NamedTemporaryFile(dir=output.parent,delete=False) as stream:
   temporary=Path(stream.name);stream.write(encoded);stream.flush();os.fsync(stream.fileno())
  os.replace(temporary,output)
 return {'path':str(output),'bytes':len(encoded),'sha256':hashlib.sha256(encoded).hexdigest(),'source_rules_sha256':SOURCE,'scope':'LOCAL_ONLY exact31 gear definitions/rank0; not full equipment/crafting execution'}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--rules',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 if a.output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):p.error('source-derived view must remain outside repository')
 print(json.dumps(build(a.rules,a.output)))
