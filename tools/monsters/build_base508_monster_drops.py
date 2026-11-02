"""Join native drop membership by exact IDs; never infer chance or quantity."""
import argparse,collections,gzip,hashlib,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--content',type=Path,required=True);p.add_argument('--catalog',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
def rows(name):return json.loads((a.content/(name+'.json')).read_text(encoding='utf-8-sig'))['rows']
npcs={r['ID']:r for r in rows('NpcClass')};items={r['ID']:r for r in rows('ItemClass')};descs={r['ID']:r['Description'].strip()for r in rows('DescData_Korean')};bless={r['ID']:r for r in rows('ItemBlessCode')};source=rows('NpcItemDropView');game=json.loads(a.catalog.read_text(encoding='utf-8-sig'))['아이템'];by_id=collections.defaultdict(list);by_name=collections.Counter(r['name']for r in game)
for r in game:
 if r.get('source')=='inven'and str(r.get('sourceId','')).isdigit():by_id[int(r['sourceId'])].append(r)
bindings={};unresolved={};wanted={r['ItemClassID']for r in source}
for i in sorted(wanted):
 candidates=by_id.get(i,[]);native=items[i];labels={descs.get(native[k],'')for k in ('DescID','IdentifiedDescID')}
 if len(candidates)!=1:unresolved[str(i)]='no_unique_exact_native_ID_in_existing_catalog';continue
 game_item=candidates[0]
 if game_item.get('sourceUrl')!='https://lineagem.inven.co.kr/db/item/'+str(i):unresolved[str(i)]='source_URL_ID_mismatch';continue
 if game_item['name'].strip()not in labels:unresolved[str(i)]='exact_ID_localized_descriptor_mismatch';continue
 if by_name[game_item['name']]!=1:unresolved[str(i)]='inventory_name_key_has_multiple_source_IDs';continue
 bindings[str(i)]={'native_item_class_id':i,'game_source_id':str(i),'game_source':'inven','game_source_url':game_item['sourceUrl'],'game_name':game_item['name'],'game_slot':game_item.get('slot',''),'game_type':game_item.get('type',''),'native_desc_id':native['DescID'],'native_identified_desc_id':native['IdentifiedDescID'],'native_grade_id':native['GradeID'],'native_category_id':native['CategoryID'],'native_item_row_sha256':hashlib.sha256(json.dumps(native,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest(),'evidence':'exact ItemClass.ID equals pinned sourceId/URL ID; Korean DescData label verifies same ID; unique existing inventory key. No name-search fallback.'}
index=collections.defaultdict(list);dangling=[]
for r in source:
 if r['NpcClassID']not in npcs or r['ItemClassID']not in items or r['Bless']not in bless:dangling.append(r['ID'])
 index[str(r['NpcClassID'])].append(r)
assert not dangling
result={'schema':1,'kind':'base508_monster_drop_membership','source_snapshot':'base508','contract':'Source membership only. No source drop chance/quantity. Existing host rarity/potion/material rates and quantity policies are retained. Conditional quest rows require explicit eligibility. Bless variants never silently merge.','source_sha256':{n:hashlib.sha256((a.content/(n+'.json')).read_bytes()).hexdigest()for n in ('NpcClass','ItemClass','NpcItemDropView','ItemBlessCode','DescData_Korean')},'npcs':{str(i):{'sprite_id':r['Sprite']}for i,r in npcs.items()},'drops':dict(index),'bindings':bindings,'unresolved_item_ids':unresolved,'bless_codes':{str(i):r['Name']for i,r in bless.items()},'counts':{'rows':len(source),'npc_classes':len(index),'item_classes':len(wanted),'verified_existing_item_bindings':len(bindings),'unresolved_existing_item_bindings':len(unresolved),'rows_with_verified_binding':sum(str(r['ItemClassID'])in bindings for r in source),'quest_conditional_rows':sum(r['RequiredQuestID']!=0 for r in source),'dangling_source_references':0}}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_bytes(gzip.compress((json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n').encode(),mtime=0));print(json.dumps({'counts':result['counts'],'bytes':a.output.stat().st_size,'sha256':hashlib.sha256(a.output.read_bytes()).hexdigest()}))
