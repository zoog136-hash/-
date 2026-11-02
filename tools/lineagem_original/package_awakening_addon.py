"""Combine the exact verified prior private addon with original awakening files."""
import argparse, hashlib, json, pathlib, zipfile
from package_install_zip import encoded,digest,safe

def build(previous,stage,output):
    files={}
    with zipfile.ZipFile(previous) as z:
        old=json.loads(z.read('pack.json'))
        for chunk in old['chunks']:
            index=z.read(chunk['path']);payload=z.read(chunk['payload'])
            assert digest(index)==chunk['sha256'] and digest(payload)==chunk['payload_sha256']
            for row in json.loads(index):
                data=payload[row['offset']:row['offset']+row['bytes']]
                assert safe(row['path']) and digest(data)==row['sha256']
                assert row['path'] not in files
                files[row['path']]=data
    old_manifest=digest(files['manifest.json'])
    for p in sorted(stage.rglob('*')):
        if p.is_file():
            name=str(p.relative_to(stage));assert safe(name) and name not in files
            files[name]=p.read_bytes()
    chunks=[];rows=[];payload=bytearray()
    with zipfile.ZipFile(output,'x',zipfile.ZIP_DEFLATED,compresslevel=1) as z:
        def flush():
            if not rows:return
            i=len(chunks);ip=f'inventory/{i:04d}.json';pp=f'payload/{i:04d}.bin';data=encoded(rows)
            z.writestr(ip,data);z.writestr(pp,payload)
            chunks.append(dict(path=ip,bytes=len(data),sha256=digest(data),count=len(rows),payload=pp,payload_bytes=len(payload),payload_sha256=digest(payload)))
            rows.clear();payload.clear()
        for name,data in files.items():
            if rows and (len(rows)>=1024 or len(payload)+len(data)>32*1024*1024):flush()
            rows.append(dict(path=name,bytes=len(data),offset=len(payload),sha256=digest(data)));payload.extend(data)
        flush()
        header={**old,'release_id':'base508-original-effects-awakening-addon-v2','compatible_base_manifest_sha256':[old_manifest],'files':len(files),'bytes':sum(map(len,files.values())),'chunks':chunks,'awakening_rules':12,'awakening_compiled_idle_profiles':5,'limits':'Explicit existing awakened owned equipped cards only. Native anchor and attr8 blend compatible/unverified; 15 indexed source inputs pending. No new awakening costs/stat grants.'}
        z.writestr('pack.json',encoded(header))
    receipt=dict(file=output.name,bytes=output.stat().st_size,sha256=digest(output.read_bytes()),files=len(files),installed_bytes=header['bytes'],base_manifest_sha256=header['base_manifest_sha256'],compatible_base_manifest_sha256=header['compatible_base_manifest_sha256'])
    output.with_suffix('.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
if __name__=='__main__':
    p=argparse.ArgumentParser()
    for key in ['previous','stage','output']:p.add_argument('--'+key,type=pathlib.Path,required=True)
    a=p.parse_args();build(a.previous,a.stage,a.output)
