#!/usr/bin/env python3
"""Read the same public item-list search endpoint used by Inven's item UI."""
import concurrent.futures, json, pathlib, urllib.parse, urllib.request
OUT=pathlib.Path('/tmp/inventory-inven'); OUT.mkdir(parents=True,exist_ok=True)
TERMS=['회복','주문서','드래곤','엘릭서','화살','탄환','철','천','가죽','목재','약초','가루','결정','광석','비법서','스테이크','연어','칠면조','용옥','루비','사파이어','아데나','성수','실','보석']
def search(term):
    url='https://lineagem.inven.co.kr/db/item/list'
    body=urllib.parse.urlencode({'name':term}).encode()
    request=urllib.request.Request(url,data=body,headers={'User-Agent':'TWILIGHT-inventory-icons/1.0','Accept':'application/json','Content-Type':'application/x-www-form-urlencoded','Referer':'https://lineagem.inven.co.kr/db/item/'})
    try:
        with urllib.request.urlopen(request,timeout=25) as response:
            if urllib.parse.urlparse(response.url).hostname!='lineagem.inven.co.kr': raise ValueError('unexpected redirect')
            raw=response.read(4000001)
            if len(raw)>4000000: raise ValueError('search too large')
            data=json.loads(raw)
        if not isinstance(data,dict) or not isinstance(data.get('items'),list): raise ValueError('unexpected search shape')
        print(term,len(data['items']),flush=True)
        return term,data
    except Exception as exc:
        print(term,str(exc),flush=True)
        return term,{'error':str(exc)}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool: result=dict(pool.map(search,TERMS))
(OUT/'consumable-search.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
if any('error' in v for v in result.values()): raise SystemExit('SEARCH_ERRORS')
