#!/usr/bin/env python3
"""Project verified SQL item/NPC tuples into existing successful rarity rolls.
Source probabilities, stats, quest items, enchantments and stacks are not imported.
"""
import argparse, hashlib, json, re
from pathlib import Path

def sha(data): return hashlib.sha256(data).hexdigest()
def identity(record):
    raw=record['source_raw_fields'];evidence=record['identity_review_evidence']['SQL']
    return {**{key:record[key] for key in ['name','sourceId','source_id','source_npc_id','source_name_original','source_version','source_locale']},
            'raw_npc_gfxid':raw['gfxid'],'raw_npc_nameid':raw['nameid'],
            'npc_sql_sha256':evidence.get('row_sha256',evidence.get('tuple_sha256'))}
def build(root, source, runtime):
    assert runtime and all(k.startswith('source3:tw380:Taiwan:') for k in runtime), 'Expected source-keyed runtime item snapshot; refusing to overwrite registry'
    links=json.loads((root/'data/l1j/source3_item_links.json').read_text())
    all_items=json.loads((root/'data/catalog_v19.json').read_text())['아이템']
    by_game={str(row['sourceId']):row for row in all_items}
    by_source={};seen=set()
    for link in links['bindings']:
        key=link['source_item_key']
        assert link['source_item_id'] not in seen;seen.add(link['source_item_id'])
        if key not in runtime:continue
        game=by_game[link['game_source_id']]
        assert sha(json.dumps(game,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode())==link['game_record_sha256']
        item=runtime[key]
        assert (item['name'],item['type'],item['slot'])==(link['game_name'],link['game_type'],link['game_slot'])
        assert str(item.get('sourceId',item.get('grade_source_id')))==link['game_source_id']
        if item['slot'] in ['currency','consumable','material']:continue
        by_source[link['source_item_id']]=(link,item)
    monsters={r['source_npc_id']:r for filename in ['reviewed_source_monsters.json','reviewed_source_additions.json'] for r in json.loads((root/'data/monsters'/filename).read_text())['records'] if r['import_enabled'] and r.get('catalog_only')}
    source_npcs={row['fields']['npcid']:row for row in map(json.loads,(source/'source_npcs.jsonl').read_text().splitlines())}
    grouped={};holds=[];snapshots={}

    for line in (source/'source_drops.jsonl').read_text().splitlines():
        row=json.loads(line);raw=row['fields'];npc=raw['mobId']
        if npc not in monsters or raw['itemId'] not in by_source or npc=='45962':continue
        if raw['min']!=raw['max'] or raw['min']!='1' or raw['enchantlvl']!='0' or int(raw['chance'])<=0:continue
        cells=re.findall(r"'([0-9]+)'",row['raw_sql_row'])
        assert len(cells)==6 and raw==dict(zip(['mobId','itemId','min','max','chance','enchantlvl'],cells))
        source_npc=source_npcs[npc]
        assert monsters[npc]['source_raw_fields']==source_npc['fields']
        assert identity(monsters[npc])['npc_sql_sha256']==source_npc['provenance']['tuple_sha256']
        link,item=by_source[raw['itemId']];proof=row['provenance']
        path=source/'source_snapshots'/proof['path']
        if path not in snapshots:
            snapshots[path]=path.read_bytes();assert sha(snapshots[path])==proof['file_sha256']
        chunk=snapshots[path][proof['byte_offset']:proof['byte_offset']+proof['byte_length']]
        assert chunk.decode()==row['raw_sql_row'] and sha(chunk)==proof['tuple_sha256']
        target=dict(source_item_key=link['source_item_key'],item_name=item['name'],game_source_id=link['game_source_id'],grade=item['grade'],type=item['type'],slot=item['slot'],quantity=1,source_enchant=0,source_fields=raw,source_provenance=proof)
        if item['grade'] not in ['일반','고급','희귀','영웅']:
            holds.append(dict(npc_id=npc,**target,reason='No source boss classification imported; ordinary production rolls cannot reach this grade.'))
            continue
        group=grouped.setdefault(npc,dict(identity=identity(monsters[npc]),drops=[]))
        assert all(old['item_name']!=target['item_name'] for old in group['drops'])
        group['drops'].append(target)
    output=dict(schema=1,policy='EXISTING_SUCCESSFUL_GRADE_EMPTY_POOL_ONLY',source_chance_policy='Positive source chance proves membership only; never evaluate or convert it. Existing TWILIGHT grade roll and equal within-grade weights remain.',item_links_sha256=sha((root/'data/l1j/source3_item_links.json').read_bytes()),source_drop_input_sha256=sha((source/'source_drops.jsonl').read_bytes()),entries=grouped,holds=holds)
    assert len(grouped)==23 and sum(len(r['drops']) for r in grouped.values())==40 and len(holds)==1, 'Reviewed drop inventory changed; refusing to overwrite registry'
    path=root/'data/monsters/source3_drop_extensions.json';path.write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
    print('DROP_EXTENSIONS',len(grouped),'identities',sum(len(r['drops']) for r in grouped.values()),'rows',len(holds),'holds','sha256',sha(path.read_bytes()))
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);parser.add_argument('--source-input',type=Path,required=True);parser.add_argument('--runtime-items',type=Path,required=True);args=parser.parse_args();build(args.root,args.source_input,json.loads(args.runtime_items.read_text()))
