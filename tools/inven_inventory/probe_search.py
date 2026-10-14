#!/usr/bin/env python3
import json,pathlib,urllib.parse,urllib.request
out=pathlib.Path('/tmp/inventory-inven');out.mkdir(parents=True,exist_ok=True)
base='https://lineagem.inven.co.kr/db/item/list'
boundary='TwilightSourceForm20261014'
body=('--'+boundary+'\r\nContent-Disposition: form-data; name="name"\r\n\r\n드래곤\r\n--'+boundary+'--\r\n').encode()
requests=[('form',base,urllib.parse.urlencode({'name':'드래곤'}).encode(),'application/x-www-form-urlencoded'),('multipart',base,body,'multipart/form-data; boundary='+boundary),('get',base+'?'+urllib.parse.urlencode({'name':'드래곤'}),None,'application/json'),('searchname','https://lineagem.inven.co.kr/db/item/?'+urllib.parse.urlencode({'searchname':'드래곤'}),None,'text/html')]
for name,url,data,ctype in requests:
    try:
        req=urllib.request.Request(url,data=data,headers={'User-Agent':'TWILIGHT-inventory-icons/1.0','Content-Type':ctype,'Accept':'application/json','Referer':'https://lineagem.inven.co.kr/db/item/'})
        with urllib.request.urlopen(req,timeout=20) as r:
            raw=r.read(2000000);print(name,r.url,r.status,raw[:500],flush=True)
        (out/('probe-'+name+'.txt')).write_bytes(raw)
    except Exception as e: print(name,str(e),flush=True)
