#!/usr/bin/env python3
"""Bind the entire current game inventory to inspected supplied visual packs.

No SQL execution, save edits, sourceId replacement, balance updates or texture
invention. Regional monsters use explicit same-species aliases, never just a
shared generic humanoid silhouette. Bosses retain dedicated existing visuals.
"""
from __future__ import annotations
import argparse, collections, hashlib, io, json, pathlib, re, zipfile
from PIL import Image

# Each left-hand name denotes an existing species, not a newly created monster.
# Ordered choices are the exact source names in the installed A2 manifest.
FAMILIES = {
 '해골 궁수': ['해골 궁수'], '해골 저격병':['부식된 해골 저격병','격전의 해골 저격병'],
 '해골 근위병':['부식된 해골 근위병','격전의 해골 근위병'],
 '해골 돌격병':['부식된 해골 돌격병','격전의 해골 돌격병'],
 '해골 도끼병':['부패한 해골 도끼병'], '해골 창병':['부패한 해골 창병'],
 '스파토이':['수련 스파토이'], '해골':['썩어가는 해골'],
 '좀비':['부식된 좀비'], '구울':['구울'], '유령':['떠도는 유령'],
 '오크 궁수':['아덴의 오크 궁병'], '오크 마법사':['숲 오크 마법사'],
 '오크 도끼병':['오염된 오크 도끼병'], '오크':['오크'],
 '킹버그베어':['굶주린 킹 버그베어'], '버그베어':['굶주린 버그베어'],
 '오우거':['계곡의 오우거'], '거대 개미':['거대 강화 개미'],
 '병정개미':['변종 거대 병정 개미'], '일개미':['거대 강화 개미'],
 '산성개미':['거대 산성 개미'], '개미수호병':['거대 수호 개미'],
 '거미':['거대 거미','거미'], '라바 골렘':['라바 골렘(분신)'],
 '돌 골렘':['골렘','돌 골렘'], '아이언 골렘':['공포의 아이언 골렘'],
 '도마뱀전사':['리자드맨 전사'], '리자드맨':['리자드맨'],
 '산적':['산적'], '코카트리스':['코카트리스'], '바실리스크':['바실리스크'],
 '수중정령':['격전의 물 정령'], '심해정령':['격전의 물 정령'],
 '불꽃정령':['격전의 불 정령'], '폭풍정령':['격전의 바람 정령'],
 '나무정령':['격전의 땅 정령'], '땅 정령':['격전의 땅 정령'],
 '크랩맨':['크랩맨'], '드레이크':['변종 드레이크'],
 '서큐버스':['봉인된 서큐버스'], '본 드래곤':['지옥의 본 드래곤'],
 '하피':['계곡 하피'], '마이노':['마이노'], '에틴':['마계의 에틴'],
 '사이클롭스':['오염된 사이클롭스'], '라이칸스로프':['돌연변이 라이칸스로프'],
 '늑대인간':['돌연변이 늑대인간'], '슬라임':['슬라임'],
 '젤라틴 큐브':['젤라틴 큐브'], '미노타우르스':['미노타우르스(도끼)'],
 '메두사':['메두사'], '웅골리언트':['칠흑의 웅골리언트'],
 '라미아':['변종 라미아'], '스콜피온':['모래 스콜피온'],
 '에티':['냉한의 에티'], '아이스 골렘':['냉한의 아이스 골렘'],
 '혼 켈베로스':['탈출한 혼 켈베로스'], '켈베로스':['굶주린 켈베로스'],
 '다이어울프':['다이어울프'], '댄싱 소드':['댄싱 소드'],
 '임프 마법사':['임프 마법사'], '임프':['임프'],
 '네크로맨서':['네크로맨서'], '개구리':['개구리'],
 '악어거북':['악어거북','악어 거북'], '악어':['해안가 악어'],
}
ALIASES = {'스켈레톤':'해골','고스트':'유령','킹 버그베어':'킹버그베어',
           '거대개미':'거대 개미','해골궁수':'해골 궁수','아이언골렘':'아이언 골렘'}
REGIONAL_PREFIXES=['말하는 섬 ','검은숲 ','글루디오 던전 ','에바 왕국 ','용의 계곡 ',
    '오만의 탑 ','화룡의 둥지 ','풍룡의 둥지 ','지룡의 둥지 ','수룡의 둥지 ','잊혀진 섬 ',
    '라스타바드 ','테베라스 ','아틀란티스 ','마계 ','천상계 ','시간의 균열 ','종말의 성역 ',
    '공포의 ','왜곡의 ','오만한 ','불신의 ','지옥의 ','암흑의 ','교만의 ','탐욕의 ',
    '분노의 ','질투의 ','알비노 ','에스카로스 ','지배자의 ']

def normalize_name(name):
    return ' '.join(re.sub(r'\\a[A-Za-z0-9]', '', str(name)).split())

def is_boss(record):
    if 'is_boss' in record: return bool(record['is_boss'])
    if 'boss' in record: return bool(record['boss'])
    name=record['name']
    return '보스' in record.get('desc','') or name.endswith('의 지배자') or name in ['흑장로','이프리트','드레이크','거대 드레이크']

def all_monsters(root):
    base=json.loads((root/'data/game_db_v17.json').read_text())['몬스터']
    db=json.loads((root/'data/monsters/monster_world_catalog.json').read_text())
    result=[];by_name={}
    for record in base:
        copy=record.copy();copy.update(db['overlays'].get(record['name'],{}))
        result.append(copy);by_name[copy['name']]=copy
    for patch in db['additions']:
        if patch['name'] in by_name: continue
        record=by_name.get(patch.get('template','해골 근위병'),{}).copy();record.update(patch)
        result.append(record);by_name[record['name']]=record
    return result

def family_for(record, original):
    name=record['name']
    clean=name
    for old,new in ALIASES.items(): clean=clean.replace(old,new)
    for family in sorted(FAMILIES, key=len, reverse=True):
        if family in clean:
            for candidate in [family,*FAMILIES[family]]:
                if candidate in original:
                    return family, candidate, original[candidate]
            return family,'',{}
    if name in original: return name,name,original[name]
    # Only explicit existing region/rank prefixes are removed. The remaining
    # species must be an exact, non-conflicting original source name.
    for prefix in REGIONAL_PREFIXES:
        if clean.startswith(prefix):
            species=clean.removeprefix(prefix)
            if species in original:return species,species,original[species]
    return '', '', {}

def jp_images(source):
    result={}
    with zipfile.ZipFile(source) as outer:
        for group in ['InvGfx','GrdGfx']:
            nested=next(n for n in outer.namelist() if '/'+group+'/' in n and n.endswith('.zip'))
            with zipfile.ZipFile(io.BytesIO(outer.read(nested))) as art:
                result[group]={str(int(pathlib.PurePosixPath(n).stem)):art.read(n)
                               for n in art.namelist() if n.lower().endswith('.png') and pathlib.PurePosixPath(n).stem.isdigit()}
    return result

def verify_png(raw):
    with Image.open(io.BytesIO(raw)) as im:
        im.load()
        return im.size

def build(root, metadata, jp, reports):
    reports.mkdir(parents=True,exist_ok=True)
    path=root/'data/visuals/runtime_manifest.json'
    manifest=json.loads(path.read_text()) if path.exists() else {'schema':1}
    bridge=json.loads((root/'data/external_l1j/a2_bridge_v1.json').read_text())
    reviewed=json.loads((root/'data/l1j/live_visual_bindings.json').read_text())
    # Keep earlier reviewed identities and recover their original PNG files from
    # the hash-gated local byte pack. Never substitute a regional variant for a
    # previously reviewed body, or silently replace its ground icon with a UI icon.
    for group in ('items','monsters'):
        for entry in reviewed.get(group,[]):
            pairs=[('inventory_texture','inventory_sha256'),('ground_texture','ground_sha256')] if group=='items' else [('texture','sha256')]
            for path_key,digest_key in pairs:
                digest=entry[digest_key]; raw=root/f'data/l1j/verified_bytes/{digest}.l1jpng'
                target=root/entry[path_key].removeprefix('res://')
                if raw.is_file() and hashlib.sha256(raw.read_bytes()).hexdigest()==digest:
                    verify_png(raw.read_bytes());target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw.read_bytes())
    originals=dict(bridge['monsters']);monsters={};monster_rows=[]
    for entry in reviewed.get('monsters',[]):
        target=root/entry['texture'].removeprefix('res://')
        if target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest()==entry['sha256']:
            originals[entry['game_name']]={'path':entry['texture'],'graphic_id':str(entry['source_sprite_id']),
                'source_ids':[entry['source_candidate_id'].split(':')[-1]],'verified_game_name':entry['game_name']}
    for record in all_monsters(root):
        boss=is_boss(record)
        family,candidate,source=family_for(record, originals) if not boss else ('','',{})
        available=bool(source) and (root/str(source.get('path',''))[6:]).is_file()
        if available:
            # A single ID cache entry and exact same path for every family member.
            monsters[record['name']]={'family_id':family,'source_sprite_id':source['graphic_id'],
                'path':source['path'],'source_npc_ids':source['source_ids'],
                'source_name':candidate,'original_animation':False,'mapping':'explicit same-species regional alias'}
            if source.get('verified_game_name'):monsters[record['name']]['verified_game_name']=source['verified_game_name']
        monster_rows.append({'game_name':record['name'],'level':record.get('lv',record.get('level')),
            'boss':boss,'family':family,'source_name':candidate,'source_sprite_id':source.get('graphic_id'),
            'path':source.get('path'),'source_available':available,'connected':False,'verified':False,
            'original_animation':False,'remaining':'existing dedicated boss retained' if boss else
            ('original action SPX/SPR missing; static original portrait' if available else 'matching original monster image missing; existing playable art retained')})
    manifest['monsters']=monsters
    (reports/'monster_bindings.json').write_text(json.dumps(monster_rows,ensure_ascii=False,indent=2)+'\n')

    images=jp_images(jp);source_rows=collections.defaultdict(list)
    for table in ['weapon','armor','etcitem']:
        for record in json.loads((metadata/(table+'.json')).read_text()):
            name=normalize_name(record['desc_kr'])
            source_rows[name].append(record|{'source_table':table})
    items={};names=collections.defaultdict(list);item_rows=[]
    reviewed_items={r['game_source_id']:r for r in reviewed.get('items',[])}
    catalog=json.loads((root/'data/catalog_v19.json').read_text())['아이템']
    old=json.loads((root/'data/game_db_v17.json').read_text())['아이템']
    # Catalog counts remain separate from starting/legacy records.
    records=[(r,True) for r in catalog]+[(r,False) for r in old]
    for record,in_catalog in records:
        game_name=record['name'];key=str(record.get('sourceId','')) or 'legacy:'+game_name
        candidates=source_rows.get(game_name,[])
        slot=record.get('slot','')
        if slot=='weapon': candidates=[r for r in candidates if r['source_table']=='weapon']
        elif slot and slot not in ['consumable','currency']:
            candidates=[r for r in candidates if r['source_table']=='armor']
        unique={(r['source_table'],int(r['iconId'])) for r in candidates}
        available=False;ground=False;source='';binding={}
        if len(unique)==1:
            table,gfx=next(iter(unique));ids=sorted({str(r['item_id']) for r in candidates})
            rawpath=root/f'assets/external_l1j/items/{gfx}.png'
            source='A3 iconId + recovered A2 PNG'
            if not rawpath.is_file() and str(gfx) in images['InvGfx']:
                raw=images['InvGfx'][str(gfx)];verify_png(raw)
                rawpath=root/f'assets/original_items/inventory/{gfx}.png'
                rawpath.parent.mkdir(parents=True,exist_ok=True);rawpath.write_bytes(raw)
                source='A3 iconId + supplied JP InvGfx ID (same ID namespace; visual review pending)'
            if rawpath.is_file():
                available=True
                ground_ids={int(r['spriteId']) for r in candidates}
                binding={'game_source_id':key,'name':game_name,'source_table':table,
                         'source_ids':ids,'source_icon_id':gfx,'path':'res://'+rawpath.relative_to(root).as_posix(),
                         'source':source,'mapping':'exact name + weapon/armor table + unique iconId'}
                if len(ground_ids)==1:
                    gid=next(iter(ground_ids))
                    if str(gid) in images['GrdGfx']:
                        raw=images['GrdGfx'][str(gid)];verify_png(raw)
                        groundpath=root/f'assets/original_items/ground/{gid}.png'
                        groundpath.parent.mkdir(parents=True,exist_ok=True);groundpath.write_bytes(raw)
                        ground=True;binding['ground_path']='res://'+groundpath.relative_to(root).as_posix()
                        binding['source_ground_id']=gid
                # A2 icon remains the safe fallback when a separate ground icon is absent.
                if not ground: binding['ground_path']=binding['path']
                previous=reviewed_items.get(key)
                if previous and all((root/previous[k].removeprefix('res://')).is_file() for k in ('inventory_texture','ground_texture')):
                    binding['path']=previous['inventory_texture'];binding['ground_path']=previous['ground_texture']
                    binding['source']='previously reviewed, hash-verified original item/ground pair'
                    binding['manual_icon_review']=True;ground=True
                items[key]=binding;names[game_name].append(key)
        item_rows.append({'game_source_id':key,'name':game_name,'slot':slot,'catalog':in_catalog,
            'original_available':available,'original_ground_available':ground,'path':binding.get('path'),
            'ground_path':binding.get('ground_path'),'source_icon_id':binding.get('source_icon_id'),
            'game_connected':False,'game_verified':False,'manual_icon_review':False,
            'remaining':('manual icon identity review' if available else
                         ('ambiguous original icon IDs; current game icon retained' if len(unique)>1 else 'original name/type/icon match missing; current game icon retained'))})
    manifest['items']=items
    manifest['item_names']={name:ids[0] for name,ids in names.items() if len(set(ids))==1}
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':'))+'\n')
    (reports/'item_bindings.json').write_text(json.dumps(item_rows,ensure_ascii=False,indent=2)+'\n')
    counts={'monsters':len(monster_rows),'normal':sum(not r['boss'] for r in monster_rows),
            'bosses':sum(r['boss'] for r in monster_rows),'original_normal_images':len(monsters),
            'shared_source_families':len({r['source_sprite_id'] for r in monsters.values()}),
            'items_registered':len(catalog),'items_original_matched':sum(r['original_available'] for r in item_rows if r['catalog']),
            'items_ground_matched':sum(r['original_ground_available'] for r in item_rows if r['catalog']),
            'legacy_original_matched':sum(r['original_available'] for r in item_rows if not r['catalog']),
            'jp_inventory_png':len(images['InvGfx']),'jp_ground_png':len(images['GrdGfx'])}
    (reports/'original_binding_summary.json').write_text(json.dumps(counts,indent=2)+'\n');print(json.dumps(counts))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=pathlib.Path,required=True);p.add_argument('--metadata',type=pathlib.Path,required=True)
    p.add_argument('--jp',type=pathlib.Path,required=True);p.add_argument('--reports',type=pathlib.Path,required=True)
    a=p.parse_args();build(a.root.resolve(),a.metadata,a.jp,a.reports)
