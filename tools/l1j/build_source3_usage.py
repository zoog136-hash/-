#!/usr/bin/env python3
"""Read-only source use/hold inventory; never registers items, offers or actions."""
import argparse, collections, hashlib, json
from pathlib import Path
from build_source3_item_links import build

def sha(data): return hashlib.sha256(data).hexdigest()
def read(path): return json.loads(path.read_text())
def lines(path): return [json.loads(line) for line in path.read_text().splitlines()]
def matches(link, item):
    ids=[str(item[k]) for k in ('sourceId','grade_source_id') if k in item]
    return bool(ids) and all(i==link['game_source_id'] for i in ids) and all(item.get(k)==link['game_'+k] for k in ('name','type','slot'))
def generate(root, source, desc, runtime):
    prior=read(root/'data/l1j/source3_item_links.json'); rebuilt=build(root,source,desc)
    assert all(rebuilt[k]==v for k,v in prior.items() if k!='catalog_sha256'), 'Existing reviewed identities changed'
    links={r['source_item_key']:r for r in rebuilt['bindings']}
    runtime_links={k:r for k,r in links.items() if matches(r,runtime.get(r['game_name'],{}))}
    guards={}
    for name in ('source_items.jsonl','source_npcs.jsonl','source_drops.jsonl','source_shops.jsonl','source_npcactions.jsonl','source_recipes.jsonl','scope_projection.jsonl','source_feature_exclusions.json'):
        guards[name]=sha((source/name).read_bytes())
    monster=read(root/'data/monsters/source_identity_catalog.json')
    active={e['npc_id'] for e in monster['entities'] if e['status']=='active_source_identity'}
    source_npcs={r['fields']['npcid']:r for r in lines(source/'source_npcs.jsonl')}
    for e in monster['entities']:
        assert source_npcs[e['npc_id']]['provenance']['tuple_sha256']==e['source_sql']['tuple_sha256']
    source_rows={r['source_row_key']:r for name in ('source_drops.jsonl','source_shops.jsonl') for r in lines(source/name)}
    drop_registry=read(root/'data/monsters/source3_drop_extensions.json')
    registered={r['source_provenance']['tuple_sha256'] for spec in drop_registry['entries'].values() for r in spec['drops']}
    retained_drop_holds={r['source_provenance']['tuple_sha256'] for r in drop_registry['holds']}
    legacy=read(root/'data/monsters/source3_reviewed_drops.json')
    vendors={p['source_npc_id'].rsplit(':',1)[1]:p for p in read(root/'data/l1j/reviewed_shop_bindings.json')['profiles']}
    npc_conflicts={key for key,p in vendors.items() if source_npcs[key]['fields']['impl']!=p['source_npc_row']['impl'] or int(source_npcs[key]['fields']['gfxid'])!=int(p['source_npc_row']['spriteId'])}
    item_rows=[]
    for item in lines(source/'source_items.jsonl'):
        key=item['source_item_key']
        status=('existing_runtime_identity' if key in runtime_links else 'existing_catalog_identity' if key in links else 'explicit_feature_exclusion' if item['excluded_feature_reasons'] or not item['eligible_for_identity_mapping'] else 'unresolved_identity')
        row={'key':key,'status':status,'source_tuple_sha256':item['source_row']['provenance']['tuple_sha256']}
        if key in links:row['game_source_id']=links[key]['game_source_id']
        item_rows.append(row)
    projected=[]
    for row in lines(source/'scope_projection.jsonl'):
        key=row['source_row_key'];raw=source_rows[key];npc=row['source_npc_id'];item=row.get('source_item_key');kind=row['record_kind'];proof=raw['provenance']['tuple_sha256']
        if row['hold_reasons'] or not row['eligible_source_record_only']:status='source_hold'
        elif kind=='drop' and (proof in registered or raw['fields']==legacy['source_drop_fields']):status='existing_registered_drop_membership'
        elif kind=='drop' and proof in retained_drop_holds:status='existing_unreachable_grade_hold'
        elif item not in links:status='item_identity_unresolved'
        elif item not in runtime_links:status='catalog_item_only_not_runtime'
        elif kind=='drop':status='active_monster_requires_drop_review' if npc in active else 'monster_identity_not_registered'
        elif npc not in vendors:status='source_vendor_not_registered'
        elif npc in npc_conflicts:status='existing_vendor_source_identity_conflict'
        else:status='existing_vendor_other_sql_version_offer_hold'
        projected.append({'key':key,'kind':kind,'status':status,'source_npc_id':npc,'source_item_key':item,'source_tuple_sha256':proof,'source_holds':row['hold_reasons']})
    dialogues=set(read(root/'data/npc/source_six_dialogues.json')['dialogues'])
    actions=[{'key':r['source_row_key'],'status':'existing_dialogue_source_action_not_enabled' if 'l1j_tw380_npc_'+r['fields']['npcid'] in dialogues else 'source_action_identity_not_registered','source_npc_id':r['fields']['npcid'],'source_tuple_sha256':r['provenance']['tuple_sha256']} for r in lines(source/'source_npcactions.jsonl')]
    recipes=[{'key':r['recipe_key'],'status':'excluded_dependency' if r['excluded_dependency_ids'] else 'source_recipe_hold' if r['review_holds'] or r['missing_item_ids'] else 'unmapped_source_recipe','source_xml_sha256':r['source_xml_sha256'],'xml_serialized_sha256':r['xml_serialized_sha256'],'source_holds':r['review_holds']} for r in lines(source/'source_recipes.jsonl')]
    def counts(rows):return dict(sorted(collections.Counter(r['status'] for r in rows).items()))
    summary={'items':counts(item_rows),'drops':counts([r for r in projected if r['kind']=='drop']),'shops':counts([r for r in projected if r['kind']=='shop']),'npcactions':counts(actions),'recipes':counts(recipes)}
    assert len(item_rows)==2992 and len(projected)==12760 and len(actions)==1112 and len(recipes)==534
    assert len(runtime_links)==26 and len(links)==252
    assert summary['drops'].get('existing_registered_drop_membership')==42
    return {'schema':1,'gameplay_enabled':False,'policy':'Read-only source classification. Catalog identity, runtime identity, existing drop membership and functional activation are separate. Never execute source SQL, HTML or NPC actions, import source prices/probabilities, revive excluded features, or replace existing local recipes.','input_sha256':guards,'current_item_record_guards_preserved':252,'runtime_item_identities':26,'existing_vendor_identity_conflict_ids':sorted(npc_conflicts),'summary':summary,'items':item_rows,'drop_and_shop_links':projected,'npcactions':actions,'recipes':recipes}

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=Path(__file__).resolve().parents[2]);p.add_argument('--source-input',type=Path,required=True);p.add_argument('--desc-input',type=Path,required=True);p.add_argument('--runtime-items',type=Path,required=True);a=p.parse_args()
    out=generate(a.root,a.source_input,a.desc_input,read(a.runtime_items));path=a.root/'data/l1j/source3_usage.json';path.write_text(json.dumps(out,ensure_ascii=False,separators=(',',':'))+'\n');print('SOURCE3_USAGE',json.dumps(out['summary'],ensure_ascii=False));print('NO_NEW_GAMEPLAY_REGISTRATION; vendor identity holds',out['existing_vendor_identity_conflict_ids'])
if __name__=='__main__':main()
