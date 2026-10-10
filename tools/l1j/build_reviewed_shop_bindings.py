"""Build the four reviewed offers from audited SQL JSON; no gameplay database writes."""
import argparse
import json
from pathlib import Path

SQL_SHA = '819c1741e815321cf083aaba65aa5698f2be350cca37533a1e94da8121a351b8'
VENDORS = (70039, 70047, 70068, 70095)

def build(source: Path, visuals: Path, output: Path):
    def read(name):
        return json.loads((source / (name + '.json')).read_text(encoding='utf-8'))
    if read('extraction')['sha256'] != SQL_SHA:
        raise ValueError('Unreviewed SQL snapshot')
    visual = json.loads(visuals.read_text(encoding='utf-8'))
    matches = [r for r in visual['items'] if r['game_source_id'] == '6391'
               and r['game_name'] == '은장검' and r['source_candidate_id'] == 'ext:a3:weapon:29']
    weapons = [r for r in read('weapon') if r['item_id'] == 29 and r['desc_kr'] == '은장검']
    if len(matches) != 1 or len(weapons) != 1:
        raise ValueError('Reviewed item identity unavailable')
    npcs, shops, profiles = read('npc'), read('shop'), []
    for npc_id in VENDORS:
        candidates = [r for r in npcs if r['npcid'] == npc_id]
        offers = [r for r in shops if r['npc_id'] == npc_id and r['item_id'] == 29]
        if len(candidates) != 1 or len(offers) != 1:
            raise ValueError('Ambiguous source merchant/offer')
        npc, row = candidates[0], offers[0]
        if row['selling_price'] <= 0 or row['pack_count'] not in (0, 1) or row['enchant'] != 0 or row['pledge_rank'] != 'NONE(없음)':
            raise ValueError('Unreviewed source sale policy')
        profiles.append({
            'source_npc_id': f'ext:a3:npc:{npc_id}', 'name': npc['desc_kr'],
            'source_npc_row': {k: npc[k] for k in ('npcid', 'desc_kr', 'spriteId', 'impl')},
            'goods': [{'game_source_id': '6391', 'game_name': '은장검',
                       'source_item_id': 'ext:a3:weapon:29', 'category': '무기',
                       'price': row['selling_price'], 'quantity': 1, 'enchant': 0,
                       'source_shop_row': row}]
        })
    result = {'schema': 1, 'enabled': True, 'source_sql_sha256': SQL_SHA,
              'price_policy': 'SOURCE_BASE_PRICE_OFFLINE_ADENA_NO_TAX',
              'source_pack_policy': 'ShopTable.java: pack_count 0 becomes 1',
              'scope': 'Four merchant profiles, four offers, one existing game item. No NPC field spawns, source stat conversion, resale, tax or skills.',
              'profiles': profiles}
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'profiles': len(profiles), 'offers': 4, 'game_items': 1}))

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--visuals', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args(); build(a.source, a.visuals, a.output)
