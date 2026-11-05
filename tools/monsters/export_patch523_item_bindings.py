#!/usr/bin/env python3
"""Export exact runtime item identities for another compiler's binding catalog.

The result is private source-derived data, never a public catalog or a recipe /
price table. Bless variants are instantiated by the runtime supplier contract.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import zipfile

def export(path):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None: raise ValueError('item ZIP CRC mismatch')
        header = json.loads(archive.read('pack.json'))
        blob = archive.read('payload/monster_drops.bin')
        if len(blob) != header['bytes'] or hashlib.sha256(blob).hexdigest() != header['sha256']:
            raise ValueError('root hash mismatch')
        document = json.loads(gzip.decompress(blob))
        if not document.get('full_item_catalog') or document.get('schema') != 3:
            raise ValueError('full ItemClass schema3 required')
        for relative,info in document['item_shards'].items():
            chunk = archive.read('payload/'+relative)
            if len(chunk) != info['bytes'] or hashlib.sha256(chunk).hexdigest() != info['sha256']:
                raise ValueError('detail hash mismatch: '+relative)
        records = [document['item_definitions'][key]['native_record'] for key in document['native_item_ids']]
        for record in records:
            if record['source_test_item'] or record['sourceId'] != 'm523:item:'+str(record['source_item_class_id']):
                raise ValueError('invalid normal source identity')
        return {'schema':3,'source_snapshot':'patch523','item_pack_sha256':header['sha256'],
                'scope':'Exact runtime identities; acquisition conditions remain with each supplier.',
                '아이템':records}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--zip',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
        parser.error('private source bindings must stay outside the repository')
    value=export(args.zip)
    raw=(json.dumps(value,ensure_ascii=False,separators=(',',':'))+'\n').encode()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_bytes(raw)
    print(json.dumps({'result':'PASS','records':len(value['아이템']),'bytes':len(raw),
                     'sha256':hashlib.sha256(raw).hexdigest(),'status':'PRIVATE_LOCAL_ONLY'}))

if __name__=='__main__': main()
