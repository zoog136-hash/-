#!/usr/bin/env python3
"""Acquire/verify inventory-only Inven art; never edit gameplay/catalog records.

A frozen policy binds custom TWILIGHT names to explicitly identified artwork.
Aliases are presentation metadata, not claims that the items are identical.
Run --acquire only for an explicit source refresh; default validation is offline.
"""
from __future__ import annotations
import argparse, concurrent.futures, datetime, hashlib, html, io, json, re, time
import urllib.parse, urllib.request
from collections import Counter
from pathlib import Path
from PIL import Image

MANIFEST = 'data/inven_inventory_icons.json'
POLICY = 'tools/inven_inventory/policy.json'
TYPE_ALIASES = {'그레이트소드':'양손검','마검':'룬소드','방패':'방패/가더','체인소드':'체인 소드','핸드캐넌':'핸드 캐넌'}
ARMOR_SLOTS = {'gaiters','body','helmet','tshirt','cloak','gloves','boots','offhand'}
EXTRA_SCROLLS = ['무기 마법 주문서 (각인)','갑옷 마법 주문서 (각인)','장신구 마법 주문서 (각인)',
 '축복 부여 주문서 (각인)','축복받은 무기 마법 주문서 (각인)','축복받은 갑옷 마법 주문서 (각인)',
 '장인의 무기 마법 주문서 (각인)','장인의 갑옷 마법 주문서 (각인)','오림의 장신구 마법 주문서 (각인)',
 '축복받은 오림의 장신구 마법 주문서 (각인)']

def read(path: Path): return json.loads(path.read_text(encoding='utf-8'))
def write(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
def sha(data: bytes) -> str: return hashlib.sha256(data).hexdigest()

def targets(root: Path) -> dict[str, dict]:
    catalog = read(root/'data/catalog_v19.json')['아이템']
    names = {r['name'] for r in catalog}
    result = {}
    for row in read(root/'data/game_db_v17.json')['아이템']:
        if row['name'] not in names: result.setdefault(row['name'],row)
    gd = (root/'scripts/consumable_rules.gd').read_text(encoding='utf-8')
    literal = gd.split('static func records()',1)[1].split('\nstatic func definition',1)[0]
    records = json.loads(literal[literal.index('return [')+7:].strip())
    for row in records:
        if row['name'] not in names: result[row['name']] = row
    for name in EXTRA_SCROLLS:
        if name not in names: result.setdefault(name,{'name':name,'type':'강화주문서','slot':'consumable'})
    for name in ['화살','총알']:
        if name not in names: result.setdefault(name,{'name':name,'type':'탄약','slot':'consumable'})
    return result

class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urllib.parse.urlparse(newurl)
        if parsed.scheme != 'https' or parsed.hostname != urllib.parse.urlparse(req.full_url).hostname:
            raise ValueError('cross-origin source redirect rejected')
        return super().redirect_request(req,fp,code,msg,headers,newurl)

def download(url: str, host: str, prefix: str, limit: int) -> bytes:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != 'https' or parsed.hostname != host or not parsed.path.startswith(prefix):
        raise ValueError('unapproved source URL: '+url)
    error = None
    for attempt in range(3):
        try:
            req = urllib.request.Request(url,headers={'User-Agent':'TWILIGHT-inventory-icons/1.0'})
            with urllib.request.build_opener(SafeRedirect()).open(req, timeout=25) as response:
                data = response.read(limit+1)
            if len(data)>limit: raise ValueError('source size limit exceeded')
            return data
        except Exception as exc:
            error=exc
            if attempt<2: time.sleep(attempt+1)
    raise RuntimeError(f'{url}: {error}')

def decode(data: bytes) -> list[int]:
    if not data.startswith(b'\x89PNG\r\n\x1a\n'): raise ValueError('source is not an original PNG')
    with Image.open(io.BytesIO(data)) as image:
        image.load()
        if not (16<=image.width<=512 and 16<=image.height<=512): raise ValueError('unexpected icon size')
        if not image.convert('RGBA').getchannel('A').getbbox(): raise ValueError('empty alpha icon')
        return list(image.size)

def resolve_policy(root: Path) -> tuple[dict, dict]:
    policy=read(root/POLICY); catalog={str(x['sourceId']):x for x in read(root/'data/catalog_v19.json')['아이템']}
    selections={}; specifications={}
    for name,row in targets(root).items():
        if name in policy.get('unresolved', {}): continue
        if name in policy['special']:
            source=policy['special'][name]; identity=str(source['id']); expected=source['name']
        else:
            family='weapon' if row['slot']=='weapon' else ('armor' if row['slot'] in ARMOR_SLOTS else 'accessory')
            prefix=name.split(' ')[0]
            position=policy['prefixes'][family].index(prefix)
            identity=str(policy['art'][family][row['type']][position])
            if identity=='0': raise ValueError('unreviewed new target: '+name)
            expected=catalog[identity]['name']
            if catalog[identity]['type'] != TYPE_ALIASES.get(row['type'],row['type']):
                raise ValueError('equipment family mismatch: '+name)
        specifications[identity]={'id':identity,'name':expected}
        selections[name]={'name':name,'type':row['type'],'slot':row['slot'],'art_source_id':identity}
    return selections,specifications

def acquire(root: Path) -> None:
    selections,specifications=resolve_policy(root)
    catalog={str(x['sourceId']):x for x in read(root/'data/catalog_v19.json')['아이템']}
    old_proofs=read(root/'data/item_visual_provenance.json')['records']
    now=datetime.datetime.now(datetime.timezone.utc).isoformat()
    def one(spec):
        identity=spec['id']; url='https://lineagem.inven.co.kr/db/item/'+identity
        if identity in catalog:
            c=catalog[identity]; path=c['image_path']; data=(root/path.removeprefix('res://')).read_bytes()
            proof=old_proofs.get(identity,{})
            if c['name']!=spec['name'] or proof.get('identity')!='source_id_name_image_bytes_verified' or proof.get('sha256')!=sha(data) or proof.get('path')!=path:
                raise ValueError('existing Inven source proof mismatch: '+identity)
            source={'id':identity,'name':c['name'],'url':url,'image_url':c['sourceImageUrl'],
                    'verification':'existing_id_name_image_bytes_verified','acquired_now':False}
        else:
            page=download(url,'lineagem.inven.co.kr','/db/item/',4_000_000)
            match=re.search(r'id="lineagemDbItem"\s+data-props="([^"]+)"',page.decode('utf-8'))
            if not match: raise ValueError('missing structured item detail: '+identity)
            props=json.loads(html.unescape(match[1])); item=props['item']
            if str(props.get('code'))!=identity or str(item.get('code'))!=identity or item['name']!=spec['name']:
                raise ValueError('detail identity mismatch: '+identity+' / '+str(item.get('name')))
            data=download(item['icon'],'static.inven.co.kr','/image_2011/site_image/lineagem/',2_000_000)
            path='res://assets/inven_inventory/'+identity+'_'+sha(data)[:16]+'.png'
            source={'id':identity,'name':item['name'],'url':url,'image_url':item['icon'],
                    'verification':'detail_id_name_image_bytes_verified','acquired_now':True,
                    'checked_at':now,'page_sha256':sha(page)}
            decode(data)
            asset=root/path.removeprefix('res://');asset.parent.mkdir(parents=True,exist_ok=True);asset.write_bytes(data)
        return identity,{'path':path,'sha256':sha(data),'size':decode(data),'art_source':source}
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        sources=dict(pool.map(one,specifications.values()))
    rows=[]
    for name,selection in selections.items():
        source=sources[selection.pop('art_source_id')]
        rows.append({**selection,**source,'match_kind':'exact_name' if source['art_source']['name']==name else 'visual_alias'})
    rows.sort(key=lambda r:(r['type'],r['name']))
    write(root/MANIFEST,{'schema':1,'scope':'inventory_only','generated_at':now,
        'unresolved':[{'name':name,'reason':reason} for name,reason in read(root/POLICY).get('unresolved',{}).items()],
        'rights':'Source identity and bytes are verified; public availability is not a redistribution licence. No gameplay identity is replaced by an art-source ID.',
        'summary':{'bindings':len(rows),'unique_images':len({r['path'] for r in rows}),
                   'new_images':sum(s['art_source']['acquired_now'] for s in sources.values()),
                   'match_kinds':dict(Counter(r['match_kind'] for r in rows))},'items':rows})
    validate(root)

def validate(root: Path) -> None:
    data=read(root/MANIFEST); planned=targets(root); selections,specs=resolve_policy(root); seen=set(); images=set()
    if data.get('schema')!=1 or data.get('scope')!='inventory_only': raise ValueError('invalid manifest scope')
    for entry in data['items']:
        name=entry['name']
        if name in seen or name not in planned: raise ValueError('duplicate/unexpected target: '+name)
        seen.add(name); record=planned[name]
        if any(entry[k]!=record[k] for k in ('type','slot')): raise ValueError('target type/slot changed: '+name)
        source=entry['art_source']; identity=selections[name]['art_source_id']
        if source['id']!=identity or source['name']!=specs[identity]['name']: raise ValueError('frozen source policy changed: '+name)
        expected='exact_name' if source['name']==name else 'visual_alias'
        if entry['match_kind']!=expected: raise ValueError('alias falsely labelled exact: '+name)
        if source['url']!='https://lineagem.inven.co.kr/db/item/'+identity: raise ValueError('source URL mismatch')
        path=entry['path']; relative=path.removeprefix('res://')
        if not path.startswith(('res://assets/catalog/','res://assets/inven_inventory/')) or '..' in Path(relative).parts or '\\' in path:
            raise ValueError('unsafe asset path')
        raw=(root/relative).read_bytes()
        if sha(raw)!=entry['sha256'] or decode(raw)!=entry['size']: raise ValueError('image bytes changed: '+path)
        images.add(path)
    unresolved={row['name']:row['reason'] for row in data.get('unresolved',[])}
    if unresolved!=read(root/POLICY).get('unresolved',{}): raise ValueError('unresolved list changed')
    if seen & set(unresolved) or seen | set(unresolved) != set(planned): raise ValueError('unaccounted targets')
    print('INVEN_INVENTORY_ASSETS_OK',json.dumps({'bindings':len(seen),'unresolved':sorted(unresolved),'images':len(images),'match_kinds':dict(Counter(e['match_kind'] for e in data['items']))},ensure_ascii=False))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--root',type=Path,default=Path('.'));parser.add_argument('--acquire',action='store_true');args=parser.parse_args()
    acquire(args.root) if args.acquire else validate(args.root)
