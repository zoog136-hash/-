#!/usr/bin/env python3
"""Collect public Inven inventory metadata for an explicit, reviewed art map."""
import concurrent.futures, hashlib, html, json, pathlib, re, time, urllib.parse, urllib.request
OUT = pathlib.Path('/tmp/inventory-inven')
OUT.mkdir(parents=True, exist_ok=True)
HOSTS = {'lineagem.inven.co.kr', 'www.inven.co.kr', 'static.inven.co.kr'}
def fetch(url):
    p = urllib.parse.urlparse(url)
    if p.scheme != 'https' or p.hostname not in HOSTS: raise ValueError('source host rejected')
    request = urllib.request.Request(url, headers={'User-Agent':'TWILIGHT-inventory-icons/1.0'})
    with urllib.request.urlopen(request, timeout=25) as response:
        if urllib.parse.urlparse(response.url).hostname not in HOSTS: raise ValueError('redirect rejected')
        data = response.read(4000001)
        if len(data)>4000000: raise ValueError('source too large')
        return data

def props(url):
    text=fetch(url).decode('utf-8')
    match=re.search(r'id="lineagemDbItem"\s+data-props="([^"]+)"',text)
    if not match: raise ValueError('structured item data missing')
    return json.loads(html.unescape(match[1]))

def collect(job):
    label,url=job
    try:
        data=props(url)
        (OUT/(label+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2))
        print(label, 'items', len(data.get('items',[])), 'name', data.get('item',{}).get('name'),flush=True)
        return label, data
    except Exception as exc:
        print(label, str(exc),flush=True)
        return label, {'error':str(exc),'url':url}

page=fetch('https://lineagem.inven.co.kr/db/item/?vtype=pc').decode('utf-8')
js_url=re.search(r'<script[^>]*src="(https://www.inven.co.kr/lineagem/lib/js/release/item.js[^\"]*)"',page).group(1)
js=fetch(html.unescape(js_url)).decode('utf-8')
(OUT/'item.js').write_text(js)
base=props('https://lineagem.inven.co.kr/db/item/?vtype=pc')
jobs=[]
for group in base['filters'].values():
    if group.get('key') == 'filtering':
        for code,label in group['value']: jobs.append(('category_'+str(code),'https://lineagem.inven.co.kr/db/item/?filtering='+str(code)))
for key in ['name','search','q','keyword']:
    jobs.append(('query_'+key,'https://lineagem.inven.co.kr/db/item/?'+urllib.parse.urlencode({key:'드래곤'})))
for code in [233,236,137,6401,1184,549,26,477,478]:
    jobs.append(('detail_'+str(code),'https://lineagem.inven.co.kr/db/item/'+str(code)))
results={}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    for label,data in pool.map(collect,jobs): results[label]=data
(OUT/'all-sources.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
print('SOURCE_COLLECTION_READY', len(results),flush=True)
