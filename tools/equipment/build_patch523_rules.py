#!/usr/bin/env python3
"""Compile pinned 523 rules into an external private runtime file, never art.

The raw recipe/effect/probability rows stay distinct from executable recipes.
Only a conservative subset with exact existing catalog identities can execute.
"""
from __future__ import annotations
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import tempfile
import os

SOURCE_SHA256 = {
    "Class": "3760aaf5d51b118947bfc272ca55d60e8ee72e89c4ba38b736eeec05c7c4d5a8",
    "LuckyBagClass": "2d9b90b07c0e7d0c29c3ab90f7131b3e5ae7b42b483684a030e391fc08650ed4",
    "LuckyBagEntityView": "fb054980ed017431b66194d4e36cf5f6565b1e533651039e1fe5f14616d51cad",
    "LuckyBagEntityType": "153c68f41d95ec55208101c3bb0f71550b3ea5b6a3e1da3a19f3ddb909f62762",
    "LuckyBagEntityClassLimit": "a904727499fdf781a1932a52b0c2c4da585ee162eefff7a76d1034058742ed4f",
    "DescData_Korean": "af6a4bb11358bfeb2adeed63f27ec7f353770a07f36474481cec87ce0a2bfb9c",
    "ItemCraftInput": "69fc628bd295d87c0e6e0355f1b96b4ea5f2e6fc1a2c05106ab8c14209a77243",
    "ItemCraftOutputView": "675a6eb871fe56735eafc21e25d62dea8dc95c197b84a0235d57e3099e6132ae",
    "ItemCraftView": "a78987ec6313fbf616e400f12e4f66699cd25107ace7a3c6e59a1d9bb888d0f5",
    "ItemCraftRestriction": "0f66c774ce374a353793de3407cc5663d5fabb8a226c88c38d08faa546ed57c2",
    "ItemClass": "adaf246e6a70c2e24f144a5147bebaff27e9168bc5a74da8bcf871ca1287a165",
    "ItemCategory": "e070087947ac479064d954fe29e6d61cff11718e84c3c12d56c169c4a893371a",
    "ItemClassLimit": "4abd1181fd1406ef81715ac8c977ece2e8b1298075af126318ecbdc8fc42c8b6",
    "ItemBonus": "2bdc0f98cd68c1b6f10c572cbba5f1ab22b6f20588e54a279133beecf9dfc815",
    "Bonus": "1189d53da7897c13ca83d559fef06410695404e1157cc2bbf8a9e48ce7f45d59",
    "BonusType": "00cedfba3cd259dfd26fbd1471dd0fb5305023da8f85ca0b262af8f9fd0c1cf1",
    "ItemEnchantBonus": "81bd7288381de6ffd3a8431be96c29880ffa76838f6bff0dd031ffd1b082a0f5",
    "ItemEnchantProbabilityGroup": "2f1d963dc6bb333ffc8982a9e51486107e5f548fb4cf8f42761873520a940e2a",
    "ItemEnchantEquipGroupMapping": "fe1bfc97aff9bb95d107c1af611f0a65600f0e3d9b3cdb37cdafe48c6c83c9b7",
    "ItemEnchantScrollGroup": "6c1c143bd4e2ba8c2c72e7e8729e208cd218c3b9aa5bb424e6363069d06151e3",
    "ItemEnchantScrollGroupMapping": "f5f5e644de558fbb486dc0d5d4569d3dbb3de818da8dc98207f0e19c2a1b33ef",
    "BmItemEnchantProView": "a06df04f323baa5ab020c55257ef3731caceff4e5983d935565d80c59702ca2a",
    "ItemEnchantCostView": "72893915d156fa7c0e59cb10a1711d0e91110f91c6a18fd2a5670a51cc5b39cf",
    "ItemEnchantProbabilityView": "afebad1fe2eea0ab7b23239d2ac94effbb95aa79fbfa3563c526b8def723ca8f",
    "ItemBlessEnchantProbability": "5ecc104984ecd748eb4c94ffe4fd5cc93d5dd305ce543d70e294a57dfb8cfa92",
    "DateTimes_Korean": "5867945da984e08459eb43649e3b4dff75424abab11e459f00a1832440d560a5",
    "ItemBlessCode": "80832412b690e9e07fc5481c49f128326eb0b5449d91924e7cb2bd8dc92f4949",
    "EquipSlotConfig": "418fa1b0b067b0eeacb37e8081020622630df084892034c527652ec933c4f58b",
    "ItemEquipSlot": "a34a46529fbf7669487361ca8bb90005a2c3b9265e3a5f5f1185715c1a3c1a85"
}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def read_source(directory):
    tables, evidence = {}, {}
    for name, expected in SOURCE_SHA256.items():
        data = (directory / (name + '.json')).read_bytes()
        if digest(data) != expected:
            raise ValueError('not the pinned current523 table: ' + name)
        value = json.loads(data.decode('utf-8-sig'))
        if not isinstance(value, dict) or not isinstance(value.get('rows'), list):
            raise ValueError('invalid table: ' + name)
        tables[name] = value['rows']
        evidence[name] = {'sha256': expected, 'bytes': len(data), 'rows': len(value['rows'])}
    return tables, evidence


def group(rows, key):
    result = defaultdict(list)
    for row in rows:
        result[str(row[key])].append(row)
    return dict(result)


def compile_rules(tables, evidence, catalog_bytes):
    catalog = json.loads(catalog_bytes)['아이템']
    by_id, by_name = defaultdict(list), defaultdict(list)
    for record in catalog:
        by_name[record['name']].append(record)
        if record.get('source') == 'inven':
            by_id[str(record.get('sourceId', ''))].append(record)
    items = {str(r['ID']): r for r in tables['ItemClass']}
    descriptions = {r['ID']:r['Description'].strip() for r in tables['DescData_Korean']}
    categories = {r['ID']: r for r in tables['ItemCategory']}
    limits = group(tables['ItemClassLimit'], 'ItemClassID')
    classes = {r['ID']:r for r in tables['Class']}
    use_conditions = {}
    for key, item in items.items():
        ids = sorted({r['ClassID'] for r in limits.get(key,[])})
        if item['LevelLimitMin'] or item['LevelLimitMax'] or ids:
            use_conditions[key] = {'schema':'patch523-item-use-v1','source_id':key,
                'min_level':item['LevelLimitMin'],'max_level':item['LevelLimitMax'],
                'class_ids':ids,'class_names':[descriptions.get(classes.get(i,{}).get('DescID',0),str(i)) for i in ids]}

    inputs = group(tables['ItemCraftInput'], 'ItemCraftID')
    outputs = group(tables['ItemCraftOutputView'], 'ItemCraftID')
    views = group(tables['ItemCraftView'], 'ItemCraftID')
    restrictions = group(tables['ItemCraftRestriction'], 'ItemCraftID')
    currency_record = {'name':'아데나','source':'lineagem_patch523','sourceId':'26','slot':'currency','weight':0}
    policy = json.loads((Path(__file__).resolve().parents[2]/'data/crafting/patch523_crafting_policy.json').read_text())
    random_ids = set(map(str,policy['verified_source_craft_ids']))
    host_materials={}
    for key, binding in policy.get('host_material_bindings',{}).items():
        if key not in items: continue
        if by_id.get(key) or by_name.get(binding['item']):
            raise ValueError('host binding collides with current catalog')
        original=items[key]
        if descriptions.get(original['DescID'])!=binding['item'] or not categories[original['CategoryID']]['IsStackable']:
            raise ValueError('host binding is not the explicit original stack material')
        record={'name':binding['item'],'source':'twilight_host_binding','sourceId':key,'slot':'consumable',
                'host_kind':binding['kind'],'host_amount':binding['amount'],'binding_origin':binding['origin']}
        by_id[key]=[record];by_name[binding['item']]=[record];host_materials[key]=record

    recipes, rejected = {}, defaultdict(int)
    for craft_id, view_rows in views.items():
        reason = ''
        ins, outs = inputs.get(craft_id, []), outputs.get(craft_id, [])
        v = view_rows[0]
        probabilistic = craft_id in random_ids
        primary = next((row for row in outs if row['ItemCraftOutputTypeID']==1 and all(v[k]==row[k] for k in ['ItemClassID','Amount','Enchant','ItemBlessCodeID'])),None)
        if probabilistic and (len(view_rows)!=1 or primary is None or not outs or any(row['ItemCraftOutputTypeID'] not in [0,1,2] or not 0<row['Probability']<=1000000 for row in outs) or sum(row['Probability'] for row in outs)!=1000000):
            reason = 'unverified_random_result_contract'
        elif not probabilistic and (len(view_rows) != 1 or v['AlwaysSuccess'] != 1 or len(outs) != 1):
            reason = 'non_single_guaranteed_result'
        elif not probabilistic and (outs[0]['Probability'] != 1000000 or outs[0]['ItemCraftOutputTypeID'] != 1):
            reason = 'unresolved_probability_or_output_type'
        elif restrictions.get(craft_id) or v['ServerLimitSetID'] or v['IsCoalitionItem'] or v['NoRepeat'] or v['IsBelowLevelLimit'] or v['LevelLimitValue']:
            reason = 'unresolved_player_or_server_condition'
        elif (v['EffectiveFrom'], v['EffectiveTo'], v['CraftTimeTypeID']) != (1, 3, 1):
            reason = 'limited_calendar_or_time_type'
        elif not ins:
            reason = 'candidate_selection_required'
        elif not probabilistic and any(v[k] != outs[0][k] for k in ['ItemClassID', 'Amount', 'Enchant', 'ItemBlessCodeID']):
            reason = 'view_output_disagreement'
        elif any(row['ClanItemClassID'] or row['ClanAmount'] for row in outs):
            reason = 'clan_output'
        else:
            for row in ins + outs:
                key = str(row['ItemClassID'])
                if row['Amount'] < 1 or row['Amount'] > (1000000000 if key=='26' else 100000000) or not 0 <= row['Enchant'] <= 21 or row['ItemBlessCodeID'] not in (1, 2) or row.get('ItemHoningEpithetID', 0):
                    reason = 'unresolved_item_state'; break
                item = items.get(key, {})
                if (not item or item['TestItem'] or item['ServiceRegionCode']
                    or not 0 <= item['LevelLimitMin'] <= 1000 or not 0 <= item['LevelLimitMax'] <= 1000
                    or (item['LevelLimitMax'] and item['LevelLimitMax'] < item['LevelLimitMin'])
                    or any(r['ClassID'] not in classes or r['ClassID']<=0 for r in limits.get(key,[]))):
                    reason = 'unresolved_item_condition'; break
                if key == '26':
                    if row['Enchant'] != 0 or row['ItemBlessCodeID'] != 1 or descriptions.get(item['DescID']) != '아데나':
                        reason = 'unsupported_currency_state'; break
                    continue
                matches = by_id.get(key, [])
                if len(matches) != 1 or len(by_name[matches[0]['name']]) != 1:
                    reason = 'missing_or_ambiguous_catalog_identity'; break
                if matches[0]['name'] not in [descriptions.get(item['DescID']), descriptions.get(item['IdentifiedDescID'])]:
                    reason = 'source_identity_name_disagreement'; break
                stack = categories[item['CategoryID']]['IsStackable']
                if stack and (row['Enchant'] != 0 or row['ItemBlessCodeID'] != 1):
                    reason = 'stack_state_cannot_be_represented'; break
                slot = matches[0].get('slot', '')
                if not stack and slot not in ['weapon', 'helmet', 'armor', 'cloak', 'gloves', 'boots', 'shield', 'gaiters', 'shirt', 'belt', 'ring', 'earring', 'necklace', 'seal', 'rune', 'shoulder', 'insignia', 'body', 'offhand', 'tshirt', 'bracelet', 'badge', 'crystal', 'catalyst']:
                    reason = 'unmapped_physical_slot'; break
            if not reason:
                out = primary if probabilistic else outs[0]
                result = currency_record if out['ItemClassID']==26 else by_id[str(out['ItemClassID'])][0]
                material_rows, material_slots, adena = [], [], 0
                for slot, slot_rows in group(ins, 'SlotIndex').items():
                    candidates = []
                    for row in slot_rows:
                        key = str(row['ItemClassID'])
                        if key == '26' and len(slot_rows)==1:
                            adena += row['Amount']; continue
                        record = currency_record if key=='26' else by_id[key][0]
                        candidates.append({'item': record['name'], 'quantity': row['Amount'], 'source_id': key,
                                           'level': row['Enchant'], 'bless_code': row['ItemBlessCodeID'],
                                           'row_id': row['ID'], 'slot_index': int(slot),
                                           'physical':False if key=='26' else not categories[items[key]['CategoryID']]['IsStackable'],
                                           'wallet':key=='26'})
                    if reason: break
                    if candidates:
                        material_slots.append({'slot_index':int(slot), 'candidates':candidates})
                        material_rows.append(candidates[0])
                if not reason and material_rows:
                    recipes['patch523:' + craft_id] = {
                        'id': 'patch523:' + craft_id, 'name': '원본523 · ' + result['name'] + ' +'+str(out['Enchant']),
                        'category': '장신구' if result.get('slot') in ['ring','earring','seal','necklace','belt','rune','insignia'] else ('무기' if result.get('slot') == 'weapon' else ('재료' if result.get('slot') in ['material','consumable','currency',''] else '방어구')),
                        'source_snapshot': 'patch523', 'source_craft_id': int(craft_id),
                        'result': {'item': result['name'], 'quantity': out['Amount'], 'level': out['Enchant'],
                                   'bless_code': out['ItemBlessCodeID'], 'source_id': str(out['ItemClassID']),
                                   'physical': False if out['ItemClassID']==26 else not categories[items[str(out['ItemClassID'])]['CategoryID']]['IsStackable'],
                                   'wallet_currency':out['ItemClassID']==26},
                        'adena': adena, 'materials': material_rows, 'material_slots':material_slots,
                        'requires_material_selection':any(len(slot['candidates']) > 1 for slot in material_slots),
                        'popup_text_id': v['PopupText']}
                    recipes['patch523:'+craft_id]['host_material_bindings']=[host_materials[str(row['ItemClassID'])] for row in ins if str(row['ItemClassID']) in host_materials]
                    if probabilistic:
                        outcomes=[]
                        for row in outs:
                            item=by_id[str(row['ItemClassID'])][0]
                            outcomes.append({'item':item['name'],'source_id':str(row['ItemClassID']),
                                'quantity':row['Amount'],'level':row['Enchant'],'bless_code':row['ItemBlessCodeID'],
                                'physical':not categories[items[str(row['ItemClassID'])]['CategoryID']]['IsStackable'],
                                'probability':row['Probability'],'label':policy['output_type_labels'][str(row['ItemCraftOutputTypeID'])]})
                        recipes['patch523:'+craft_id]['outcomes']=outcomes
                        recipes['patch523:'+craft_id]['probability_origin']='원본 확률 · NC 공식 재료/결과 대조'
                        recipes['patch523:'+craft_id]['preserve_refund_instance']=bool(policy['preserve_matching_refund_instance'])
                        recipes['patch523:'+craft_id]['host_material_bindings']=[host_materials[str(row['ItemClassID'])] for row in ins if str(row['ItemClassID']) in host_materials]
                    continue
                if not reason: reason = 'currency_only_input'
        rejected[reason] += 1
    bonuses = {str(r['ID']): r for r in tables['Bonus']}
    item_bonus_rows = group(tables['ItemBonus'], 'ItemClassID')
    enchant = group(tables['ItemEnchantBonus'], 'ItemEnchantBonusGroupID')
    bound_items, used_bonuses = {}, set()
    inspectable = dict(by_id)
    if '26' in items and descriptions.get(items['26']['DescID'])=='아데나':
        inspectable['26']=[currency_record]
    for key, links in item_bonus_rows.items():
        if key in inspectable or key not in items:
            continue
        if any(bonuses[str(link['BonusID'])]['BonusTypeID'] in (2022, 8352) for link in links):
            inspectable[key] = [{'name':descriptions.get(items[key]['DescID'], items[key]['Name']),
                                 'source':'lineagem_patch523', 'sourceId':key, 'slot':'consumable'}]
    for key, records in inspectable.items():
        if key not in items or len(records) != 1:
            continue
        links = item_bonus_rows.get(key, [])
        effect_rows = []
        for link in links:
            bonus = bonuses[str(link['BonusID'])]
            used_bonuses.add(str(link['BonusID']))
            if bonus['BonusTypeID'] == 71:
                effect_rows.extend(enchant.get(str(bonus['Value']), []))
        used_bonuses.update(str(r['BonusID']) for r in effect_rows)
        bound_items[key] = {'catalog_record': records[0], 'item_class': items[key], 'item_bonuses': links,
                            'enchant_effects': effect_rows,
                            'use_conditions':use_conditions.get(key,{}) if records[0].get('source')=='inven' and records[0]['name'] in [descriptions.get(items[key]['DescID']),descriptions.get(items[key]['IdentifiedDescID'])] else {}}
    # Only these permanent guaranteed boxes have a fully checked contract.
    boxes = {}
    bag_types = {r['ID']:r for r in tables['LuckyBagEntityType']}
    bag_classes = {r['ID']:r for r in tables['LuckyBagClass']}
    limited_entities = {r['LuckyBagEntityID'] for r in tables['LuckyBagEntityClassLimit']}
    for item_id, bag_id, target_id in [(30701,12741,30671),(130611,22871,130551)]:
        rewards = [r for r in tables['LuckyBagEntityView'] if r['LuckyBagClassID']==bag_id]
        if not rewards: continue
        expected = {(target_id,1),(320802,8)}
        if (bag_types.get(1,{}).get('Name')!='IsGiven' or bag_id not in bag_classes
            or {(r['ItemClassID'],r['ItemAmount']) for r in rewards} != expected or len(rewards)!=2
            or any(r['LuckyBagEntityTypeID']!=1 or r['Probability']!=10000000
                   or r['ItemBlessCodeID']!=1 or r['ItemEnchant']!=0
                   or r['LimitClass']!=10000 or r['ID'] in limited_entities for r in rewards)):
            raise ValueError('guaranteed box source contract changed')
        boxes[str(item_id)] = {'bag_class':bag_classes[bag_id], 'rewards':rewards}
    result = {'schema': 'twilight-patch523-equipment-v1', 'snapshot': 'patch523',
              'catalog_sha256': digest(catalog_bytes), 'source_files': evidence,
              'recipes': recipes, 'recipe_summary': {'active':len(recipes), 'rejected':dict(rejected)},
              'raw_recipes': {'inputs':inputs, 'outputs':outputs, 'views':views, 'restrictions':restrictions},
              'guaranteed_boxes':boxes, 'items':bound_items, 'bonuses':{k:bonuses[k] for k in sorted(used_bonuses)},
              'bonus_types': {str(r['ID']):r for r in tables['BonusType']},
              'enchantment': {n:tables[n] for n in ['ItemEnchantProbabilityGroup','ItemEnchantEquipGroupMapping',
                  'ItemEnchantScrollGroup','ItemEnchantScrollGroupMapping','BmItemEnchantProView','ItemEnchantCostView',
                  'ItemEnchantProbabilityView','ItemBlessEnchantProbability','ItemBlessCode','EquipSlotConfig','ItemEquipSlot']}}
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--content', type=Path, required=True)
    parser.add_argument('--catalog', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.output.resolve().is_relative_to(root):
        raise ValueError('private rules must be outside the public repository')
    tables, evidence = read_source(args.content)
    result = compile_rules(tables, evidence, args.catalog.read_bytes())
    data = json.dumps(result, ensure_ascii=False, separators=(',', ':')).encode()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=args.output.parent, delete=False) as handle:
        temporary = Path(handle.name)
        handle.write(data)
    os.replace(temporary, args.output)
    print(json.dumps({'path':str(args.output), 'bytes':len(data), 'sha256':digest(data),
                      'recipe_summary':result['recipe_summary']}, ensure_ascii=False))


if __name__ == '__main__':
    main()
