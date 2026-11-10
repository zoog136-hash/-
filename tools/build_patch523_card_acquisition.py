#!/usr/bin/env python3
"""Export verified523 Nemesis guaranteed crafting; other paths are diagnostic.

Names never turn TWILIGHT's existing generic coin stack into source Item3252.
The exporter changes no runtime/save and supplies no payment or RNG consumer.
"""
import argparse
import collections
import hashlib
import json
import pathlib
import zipfile

SOURCE_SHA256 = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'


def build(source, output):
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != SOURCE_SHA256:
        raise ValueError('Expected verified patch523 source ZIP')
    names = ('ItemCraftView', 'ItemCraftInput', 'ItemCraftOutputView',
             'ItemCraftRestriction', 'ItemCraftMainCategory', 'ItemCraftSubCategory',
             'ItemCraftSub2Category', 'ItemCraftGroupType', 'ItemCraftRecommend',
             'ItemCraftInputSource', 'ItemClass', 'ItemCategory', 'Grade',
             'ItemBlessCode', 'ItemClassLimit', 'ItemBonus', 'Bonus', 'BonusType',
             'Unit', 'UIUnit', 'Currency', 'CurrencyUnitClass', 'BuffCard',
             'BuffCardDeck', 'BuffCardSourceView', 'DescData_Korean', 'ServerLimit',
             'DateTimes', 'DateTimes_Korean', 'GotChaEntityView',
             'BuffCardSourceCraftView', 'BuffCardRuleMergeView', 'BuffCardRuleSwap',
             'BuffCardRuleSwapCost', 'SelectReward', 'SelectRewardEntity', 'Reward',
             'RewardType', 'MarketProduct', 'MarketPurchaseProduct')
    tables, hashes = {}, {}
    with zipfile.ZipFile(source) as archive:
        for name in names:
            raw = archive.read('content/' + name + '.json')
            hashes[name] = hashlib.sha256(raw).hexdigest()
            tables[name] = json.loads(raw.decode('utf-8-sig'))['rows']
    by = {name: {r['ID']: r for r in rows if 'ID' in r}
          for name, rows in tables.items()}
    positions = {name: {id(row): i for i, row in enumerate(rows)}
                 for name, rows in tables.items()}

    def ref(name, row):
        return {'table': name, 'row_index_zero': positions[name][id(row)], 'raw': row}

    def get(name, row_id):
        return ref(name, by[name][row_id])

    def desc(row, fields):
        return {field: get('DescData_Korean', row[field])
                for field in fields if row.get(field) in by['DescData_Korean']}

    def effect(link):
        bonus = by['Bonus'][link['BonusID']]
        typ = by['BonusType'][bonus['BonusTypeID']]
        result = {'link': ref('ItemBonus', link), 'bonus': get('Bonus', bonus['ID']),
                  'type': get('BonusType', typ['ID']), 'unit': get('Unit', typ['UnitID'])}
        ui = next((r for r in tables['UIUnit'] if r['UnitID'] == typ['UnitID']), None)
        if ui is not None:
            result['ui_unit'] = ref('UIUnit', ui)
        return result

    def item(row_id):
        row = by['ItemClass'][row_id]
        return {'item': get('ItemClass', row_id), 'category': get('ItemCategory', row['CategoryID']),
                'grade': get('Grade', row['GradeID']),
                'descriptions': desc(row, ('DescID', 'IdentifiedDescID', 'StoryDescID',
                                           'ProductTitleDescID', 'ProductDescID')),
                'class_limits': [ref('ItemClassLimit', r) for r in tables['ItemClassLimit']
                                 if r['ItemClassID'] == row_id],
                'effects': [effect(r) for r in tables['ItemBonus'] if r['ItemClassID'] == row_id]}

    def recipe(recipe_id):
        views = [r for r in tables['ItemCraftView'] if r['ItemCraftID'] == recipe_id]
        if len(views) != 1:
            raise ValueError('Ambiguous craft view')
        view = views[0]
        inputs = [r for r in tables['ItemCraftInput'] if r['ItemCraftID'] == recipe_id]
        outputs = [r for r in tables['ItemCraftOutputView'] if r['ItemCraftID'] == recipe_id]
        def payload(name, row):
            result = {'link': ref(name, row), 'bless_code': get('ItemBlessCode', row['ItemBlessCodeID'])}
            if row['ItemClassID'] != 0:
                result['item_definition'] = item(row['ItemClassID'])
            if 'DescID' in row:
                result['descriptions'] = desc(row, ('DescID',))
            return result
        dates = {name: {field: get(name, view[field]) if view[field] in by[name] else None
                        for field in ('EffectiveFrom', 'EffectiveTo')}
                 for name in names if name.startswith('DateTimes')}
        categories = {}
        for field, name in [('MainCategoryID', 'ItemCraftMainCategory'),
                            ('SubCategoryID', 'ItemCraftSubCategory'),
                            ('Sub2CategoryID', 'ItemCraftSub2Category'),
                            ('CraftGroupTypeID', 'ItemCraftGroupType')]:
            if view[field] in by[name]:
                row = by[name][view[field]]
                categories[field] = {'row': get(name, row['ID']), 'descriptions': desc(row, ('DescID',))}
        return {'view': ref('ItemCraftView', view),
                'inputs': [payload('ItemCraftInput', r) for r in inputs],
                'outputs': [payload('ItemCraftOutputView', r) for r in outputs],
                'restrictions': [ref('ItemCraftRestriction', r) for r in tables['ItemCraftRestriction']
                                 if r['ItemCraftID'] == recipe_id],
                'recommendations': [ref('ItemCraftRecommend', r) for r in tables['ItemCraftRecommend']
                                    if r['ItemCraftID'] == recipe_id],
                'categories': categories, 'dates': dates,
                'server_limits': [ref('ServerLimit', r) for r in tables['ServerLimit']
                                  if r['ServerLimitSetID'] == view['ServerLimitSetID']],
                'raw_probability_sum': sum(r['Probability'] for r in outputs)}

    nemesis = recipe(258482)
    card = by['BuffCard'][25152]
    nemesis['card'] = get('BuffCard', 25152)
    nemesis['deck'] = get('BuffCardDeck', card['BuffCardDeckID'])
    nemesis['source_flags'] = get('BuffCardSourceView', 25152)
    nemesis['source_craft_links'] = [ref('BuffCardSourceCraftView', r)
                                    for r in tables['BuffCardSourceCraftView'] if r['ID'] == 25152]
    nemesis['coin_currency'] = get('Currency', 1102)
    nemesis['coin_currency_bindings'] = [ref('CurrencyUnitClass', r) for r in tables['CurrencyUnitClass']
        if r['CurrencyID'] == 1102 and r['UnitID'] == 4 and r['ClassID'] == 3252]
    nemesis['currency_item_unit'] = get('Unit', 4)
    nemesis['coin_source_hints'] = [ref('ItemCraftInputSource', r)
                                  for r in tables['ItemCraftInputSource'] if r['ItemClassID'] == 3252]
    if (len(nemesis['inputs']) != 1 or len(nemesis['outputs']) != 1
            or nemesis['inputs'][0]['link']['raw']['ID'] != 500592
            or nemesis['inputs'][0]['link']['raw']['ItemClassID'] != 3252
            or nemesis['inputs'][0]['link']['raw']['Amount'] != 3000000
            or nemesis['outputs'][0]['link']['raw']['ID'] != 369922
            or nemesis['outputs'][0]['link']['raw']['Probability'] != 1000000
            or nemesis['view']['raw']['AlwaysSuccess'] != 1
            or nemesis['view']['raw']['ServerLimitSetID'] != 0
            or nemesis['restrictions']):
        raise ValueError('Reviewed guaranteed Nemesis craft changed')
    ticket_effects = nemesis['outputs'][0]['item_definition']['effects']
    if (len(ticket_effects) != 1 or ticket_effects[0]['bonus']['raw']['ID'] != 2392192
            or ticket_effects[0]['type']['raw']['Name'] != 'BuffCardID'
            or ticket_effects[0]['bonus']['raw']['Value'] != 25152
            or ticket_effects[0]['link']['raw']['IsPossession']):
        raise ValueError('Nemesis ticket dispatch changed')

    # These declarations are evidence for later review, never automatic routes.
    new_ids = [25182, 25192, 25202, 25212, 25293, 25303, 25314, 25324,
               25334, 25344, 25354, 25364, 25072, 25142, 25152, 25162]
    gotcha = collections.defaultdict(list)
    for row in tables['GotChaEntityView']:
        if row['UnitID'] == 33 and row['ClassID'] in new_ids and row['BuffCardID'] == row['ClassID']:
            gotcha[row['GotChaClassID']].append(row)
    gacha_diagnostics = {}
    for group_id, selected in gotcha.items():
        all_rows = [r for r in tables['GotChaEntityView'] if r['GotChaClassID'] == group_id]
        products = [r for r in tables['MarketProduct'] if r['UnitID'] == 35 and r['ClassID'] == group_id]
        product_ids = {r['ID'] for r in products}
        gacha_diagnostics[str(group_id)] = {
            'new_card_rows': [ref('GotChaEntityView', r) for r in selected],
            'complete_pool_row_count': len(all_rows),
            'complete_pool_probability_sum': sum(r['Probability'] for r in all_rows),
            'typed_market_products': [ref('MarketProduct', r) for r in products],
            'market_purchase_links': [ref('MarketPurchaseProduct', r) for r in tables['MarketPurchaseProduct']
                                      if r['MarketProductID'] in product_ids]}
    diagnostics = {
        'runtime_enabled': False,
        'cards': {str(i): {'card': get('BuffCard', i), 'source_flags': get('BuffCardSourceView', i)}
                  for i in new_ids},
        'guardian_craft': recipe(258592), 'gacha_groups': gacha_diagnostics,
        'relic_merge': [ref('BuffCardRuleMergeView', r) for r in tables['BuffCardRuleMergeView']
                        if r['BuffCardDeckID'] == 98 and r['SuccessGradeID'] == 4],
        'unique_doll_swap': [ref('BuffCardRuleSwap', r) for r in tables['BuffCardRuleSwap']
                             if r['BuffCardDeckID'] == 2 and r['GradeID'] == 52],
        'unique_doll_swap_costs': [ref('BuffCardRuleSwapCost', r) for r in tables['BuffCardRuleSwapCost']
                                  if r['BuffCardDeckID'] == 2 and r['GradeID'] == 52],
        'selection_group_definitions': [get('SelectReward', i) for i in (15422, 15452, 15482, 15612)],
        'unresolved_acquisition_card_ids': [25293, 25303],
        'notes': ['Gacha weights do not establish payment eligibility, bonus draws, RNG independence or claim timing.',
                  'Merge/swap declarations do not supply per-card selection weights; never choose uniformly by grade.',
                  'Challenge selection boxes369742/369772/369802 expire at Korean DateTime280242 (2026-10-28 05:00).',
                  'Selectable LuckyBag83791 and SelectReward15612 are different typed systems; do not copy selection counts.']}
    result = {'schema': 1, 'source_snapshot': 'patch523', 'source_zip_sha256': digest,
        'source_table_sha256': hashes, 'guaranteed_nemesis': nemesis, 'diagnostics': diagnostics,
        'execution_boundaries': {
            'primary': 'Only recipe258482 is the reviewed deterministic contract; output is the exact source ticket370562, then explicit ticket use dispatches BuffCardID25152.',
            'currency_identity': 'Item3252/Currency1102 is source typed. Existing TWILIGHT name-only 마법인형 제작 코인 inventory has no automatic m508 or m523 provenance.',
            'missing_enum_definitions': ['CraftTimeTypeID', 'CraftDashBoardTypeID', 'ItemCraftOutputTypeID'],
            'source_enum_scope': 'Raw enum values retained; AlwaysSuccess1, sole output1m and output Desc973922=성공 establish deterministic outcome without guessing enum names.',
            'save_policy': 'Explicit craft/open actions require staged inventory/provenance and durable save; no automatic acquisition, debit, migration or RNG advance is implemented.'}}
    count = 0
    def verify(value):
        nonlocal count
        if isinstance(value, dict):
            if {'table', 'row_index_zero', 'raw'} <= value.keys():
                if tables[value['table']][value['row_index_zero']] != value['raw']:
                    raise ValueError('Source reference mismatch')
                count += 1
            else:
                for child in value.values():
                    verify(child)
        elif isinstance(value, list):
            for child in value:
                verify(child)
    verify(result)
    result['verified_embedded_references'] = count
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(json.dumps({'verified_embedded_references': count, 'deterministic_recipe_id': 258482,
                      'diagnostic_only': True}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=pathlib.Path)
    parser.add_argument('--output', default='data/cards/patch523_card_acquisition.json', type=pathlib.Path)
    args = parser.parse_args()
    build(args.source, args.output)
