#!/usr/bin/env python3
"""Build an offline install ZIP from the preserved baseline + checkpoint delta.
No image conversion, public upload or mutation of either input. JSON inventory is
sharded to avoid loading hundreds of thousands of file records on Android.
"""
import argparse, hashlib, json, tarfile, zipfile
from pathlib import Path, PurePosixPath

ROOT = 'lineagem-base508-native-v2/'
DELTA = 'private-pack-delta/' + ROOT
REQUIRED = ['manifest.json', 'source_effect_bindings.json', 'registered_effect_layers.json']

def digest(data): return hashlib.sha256(data).hexdigest()
def encoded(value): return json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode()
def safe(name):
    return bool(name) and '\\' not in name and ':' not in name and not name.startswith('/') and all(x not in ('', '.', '..') for x in name.split('/'))

def build(base, delta, output):
    with zipfile.ZipFile(delta) as dz:
        restore = json.loads(dz.read('RESTORE.json'))
        h = hashlib.sha256()
        with open(base, 'rb') as f:
            for block in iter(lambda: f.read(4*1024*1024), b''): h.update(block)
        if h.hexdigest() != restore['base_sha256'] or base.stat().st_size != restore['base_bytes']:
            raise ValueError('Baseline does not match preserved checkpoint receipt')
        overrides = {n[len(DELTA):]: n for n in dz.namelist() if n.startswith(DELTA) and not n.endswith('/')}
        output.parent.mkdir(parents=True, exist_ok=True)
        if output.exists(): raise FileExistsError(output)
        chunks, rows, seen = [], [], set()
        payload = bytearray()
        total = count = 0
        def flush(z):
            if not rows: return
            blob_name = 'payload/%04d.bin' % len(chunks)
            z.writestr(blob_name, payload)
            data = encoded(rows)
            name = 'inventory/%04d.json' % len(chunks)
            z.writestr(name, data)
            chunks.append({'path': name, 'sha256': digest(data), 'bytes': len(data), 'count': len(rows), 'payload':blob_name, 'payload_bytes':len(payload), 'payload_sha256':digest(payload)})
            rows.clear()
            payload.clear()
        with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=1, allowZip64=True) as z:
            def add(name, data):
                nonlocal total, count
                if not safe(name) or name in seen: raise ValueError('Unsafe/duplicate path: '+name)
                if len(data)>64*1024*1024: raise ValueError('Oversized individual entry: '+name)
                seen.add(name)
                if rows and len(payload)+len(data)>32*1024*1024: flush(z)
                rows.append({'path': name, 'bytes': len(data), 'offset':len(payload), 'sha256': digest(data)})
                payload.extend(data)
                total += len(data); count += 1
                if len(rows)==1024: flush(z)
                if count%25000==0: print(json.dumps({'files':count,'bytes':total}), flush=True)
            with tarfile.open(base, 'r|gz') as t:
                for m in t:
                    if m.isdir(): continue
                    if not m.isfile() or not m.name.startswith(ROOT): raise ValueError('Unexpected tar entry '+m.name)
                    name=m.name[len(ROOT):]
                    if name not in overrides: add(name,t.extractfile(m).read())
            for name, member in overrides.items(): add(name,dz.read(member))
            flush(z)
            if not all(x in seen for x in REQUIRED): raise ValueError('Missing required runtime metadata')
            manifest=json.loads(dz.read(overrides['manifest.json']))
            if manifest.get('source_snapshot')!='base508' or sum(k.startswith('sprite:') for k in manifest.get('records',{}))!=743: raise ValueError('Unexpected runtime catalog')
            pack={'schema':2,'kind':'twilight-lineagem-offline-runtime','source_snapshot':'base508',
                  'release_id':'base508-577a5f4d-v3','files':count,'bytes':total,'required':REQUIRED,
                  'sprite_records':743,'card_definitions':701,'chunks':chunks,
                  'provenance':{'baseline_sha256':restore['base_sha256'],'delta_sha256':digest(delta.read_bytes())},
                  'limitations':'Unverified timing/blend compatibility and known missing source assets retained; not visual equivalence approval.'}
            z.writestr('pack.json',encoded(pack))
    h=hashlib.sha256()
    with output.open('rb') as f:
        for block in iter(lambda:f.read(4*1024*1024),b''):h.update(block)
    receipt={'file':str(output),'bytes':output.stat().st_size,'sha256':h.hexdigest(),'inventory_files':count,'installed_bytes':total,'release_id':pack['release_id'],'external_delivery':'not_uploaded'}
    output.with_suffix('.receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--delta',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();build(a.base,a.delta,a.output)
