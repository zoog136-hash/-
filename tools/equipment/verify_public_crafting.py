#!/usr/bin/env python3
"""Compare cached NC public crafting rows with pinned original recipe contracts.

Use the browser API's /contents and /resources export as --public-table. Keep
that full export private; this emits only the checked recipe IDs and outcomes.
"""
import argparse
from decimal import Decimal
import importlib.util
import json
from pathlib import Path


def flatten(rows, parent=None):
    for row in rows:
        values = {**(parent or {}), **{k:v for k,v in row.items() if k!='@entries'}}
        if '@entries' in row:
            yield from flatten(row['@entries'],values)
        else:
            yield values


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--content',type=Path,required=True)
    parser.add_argument('--public-table',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    root=Path(__file__).resolve().parents[2]
    spec=importlib.util.spec_from_file_location('builder',root/'tools/equipment/build_patch523_rules.py')
    builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
    tables,_=builder.read_source(args.content)
    policy=json.loads((root/'data/crafting/patch523_crafting_policy.json').read_text())
    snapshot=json.loads(args.public_table.read_text())
    if snapshot['version']!=policy['official_version']: raise ValueError('public version mismatch')
    public=list(flatten(snapshot['records']))
    items={r['ID']:r for r in tables['ItemClass']}
    desc={r['ID']:r['Description'].strip() for r in tables['DescData_Korean']}
    name=lambda item_id:desc[items[item_id]['DescID']]
    bless={1:'기본',2:'축복받은'}
    report=[]
    for craft_id in policy['verified_source_craft_ids']:
        views=[r for r in tables['ItemCraftView'] if r['ItemCraftID']==craft_id]
        if len(views)!=1: raise ValueError('ambiguous original view')
        attempt=name(views[0]['ItemClassID'])
        ins=[r for r in tables['ItemCraftInput'] if r['ItemCraftID']==craft_id]
        inputs={(r['SlotIndex'],name(r['ItemClassID']),r['Amount'],r['Enchant'],bless[r['ItemBlessCodeID']]) for r in ins}
        outcomes=[]
        for row in [r for r in tables['ItemCraftOutputView'] if r['ItemCraftID']==craft_id]:
            label=policy['output_type_labels'][str(row['ItemCraftOutputTypeID'])]
            matches=[r for r in public if r['제작 시도 아이템명']==attempt and r['제작 결과']==label
                     and r['제작 결과 아이템명']==name(row['ItemClassID']) and int(r['획득 아이템 수량'])==row['Amount']
                     and int(r['강화 수치'])==row['Enchant'] and r['축복 부여 상태']==bless[row['ItemBlessCodeID']]
                     and Decimal(r['확률[%]'])*10000==row['Probability']]
            actual={(int(r['재료 슬롯 번호']),r['제작 재료 아이템명'],int(r['재료 필요 수량']),int(r['강화도 수치']),r['축복 부여 여부']) for r in matches}
            if actual!=inputs: raise ValueError('public input/outcome mismatch: '+str(craft_id))
            outcomes.append({'type':label,'source_id':row['ItemClassID'],'probability':row['Probability']})
        report.append({'craft_id':craft_id,'matched':True,'outcomes':outcomes})
    result={'url':policy['official_url'],'version':snapshot['version'],'matched':True,'contracts':report}
    if args.output.resolve().is_relative_to(root): raise ValueError('evidence must be outside public repository')
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'matched':True,'recipes':len(report),'version':snapshot['version']}))


if __name__=='__main__': main()
