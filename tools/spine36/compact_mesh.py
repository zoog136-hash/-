#!/usr/bin/env python3
"""Losslessly share repeated SDK-evaluated page/UV/index triples.

Reads verified inline bake evidence, retains all positions/tints/times, and emits
V1 geometries references. No geometry values are quantized, sampled or removed.
"""
from __future__ import annotations
import argparse
from array import array
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import struct
import sys
import time
import bake_mesh as bake


def poses(data):
    yield data['setup']
    for clip in data['clips'].values():
        yield from clip['frames']


def resolved(batch, geometries):
    if 'geometry' not in batch:
        return batch['page'], batch['uvs'], batch['indices']
    if any(k in batch for k in ['page','uvs','indices']):
        raise ValueError('mixed inline and referenced geometry')
    key=batch['geometry']
    if not isinstance(key,str) or not key or len(key)>256 or key not in geometries:
        raise ValueError('unknown geometry reference')
    geo=geometries[key]
    if set(geo)!={'page','uvs','indices'}:raise ValueError('invalid geometry template')
    return geo['page'],geo['uvs'],geo['indices']


def expanded_digest(data):
    """Binary64 digest of exact semantic values, independent of deduplication."""
    h=hashlib.sha256()
    def blob(value):
        h.update(struct.pack('<Q',len(value)));h.update(value)
    def floats(value):
        # JSON decoder values retain Python IEEE binary64 precision. No float32
        # conversion here, so even a sub-float32 change fails equivalence.
        blob(array('d',value).tobytes())
    blob(json.dumps({k:v for k,v in data.items() if k not in ['setup','clips','geometries']},sort_keys=True,separators=(',',':'),ensure_ascii=True,allow_nan=False).encode('ascii'))
    geometries=data.get('geometries',{})
    for name,clip in [('__setup__',{'frames':[data['setup']]})]+list(data['clips'].items()):
        blob(name.encode('utf-8'))
        blob(json.dumps({k:v for k,v in clip.items() if k!='frames'},sort_keys=True,separators=(',',':'),allow_nan=False).encode('ascii'))
        for pose in clip['frames']:
            blob(json.dumps({k:v for k,v in pose.items() if k!='batches'},sort_keys=True,separators=(',',':'),allow_nan=False).encode('ascii'))
            h.update(struct.pack('<Q',len(pose['batches'])))
            for batch in pose['batches']:
                page,uvs,indices=resolved(batch,geometries)
                blob(page.encode('utf-8'));floats(uvs);blob(array('I',indices).tobytes())
                floats(batch['positions']);floats(batch['color']);floats(batch.get('dark_color',[]))
                blob(json.dumps({k:v for k,v in batch.items() if k not in ['geometry','page','uvs','indices','positions','color','dark_color']},sort_keys=True,separators=(',',':'),ensure_ascii=True,allow_nan=False).encode('ascii'))
    return h.hexdigest()


def compact(data):
    if 'geometries' in data:raise ValueError('already compact input')
    before=expanded_digest(data);lookup={};geometries={};refs=0
    for pose in poses(data):
        for batch in pose['batches']:
            key=(batch['page'],tuple(batch['uvs']),tuple(batch['indices']))
            gid=lookup.get(key)
            if gid is None:
                gid='g%06d'%len(lookup);lookup[key]=gid
                geometries[gid]={'page':batch['page'],'uvs':batch['uvs'],'indices':batch['indices']}
            batch['geometry']=gid
            for field in ['page','uvs','indices']:del batch[field]
            refs+=1
    data['geometries']=geometries
    after=expanded_digest(data)
    if before!=after:raise ValueError('compaction changed evaluated geometry')
    return {'encoding':'shared-exact-page-uv-indices','templates':len(geometries),'batch_references':refs,'shared_values':sum(len(g['uvs'])+len(g['indices']) for g in geometries.values()),'expanded_binary64_sha256_before':before,'expanded_binary64_sha256_after':after,'semantic_values_unchanged':True,'ensure_ascii':True}


def convert(input_path, output, expected_manifest_sha, pack):
    started=time.monotonic();proof_path=input_path.with_suffix('.proof.json')
    proof=json.loads(proof_path.read_text())
    if proof['bytes']!=input_path.stat().st_size or proof['sha256']!=bake.sha(input_path):raise ValueError('inline proof mismatch: '+str(input_path))
    manifest=json.loads((pack/'original_ui.json').read_text())
    if bake.sha(pack/'original_ui.json')!=expected_manifest_sha:raise ValueError('manifest pin mismatch')
    if proof['build']['sdk_git']!=bake.SDK_GIT:raise ValueError('runtime pin mismatch')
    member=proof['json_path'];atlas_member=proof['atlas_path'];json_path=bake.original(pack,manifest,member);atlas_path=bake.original(pack,manifest,atlas_member)
    source_json=json.loads(json_path.read_text());regions,page_names=bake.atlas_names(atlas_path.read_text())
    pages={}
    for name in page_names:
        path=str(PurePosixPath(atlas_member).parent/name);p=bake.original(pack,manifest,path);pages[path]={'sha256':bake.sha(p),'bytes':p.stat().st_size}
    data=json.loads(input_path.read_text())
    expected_source={'json_sha256':bake.sha(json_path),'atlas_sha256':bake.sha(atlas_path),'spine_version':source_json['skeleton']['spine'],'runtime_git':bake.SDK_GIT,'pages':pages,'unreferenced_missing_attachments':bake.missing_attachment_audit(source_json,regions)}
    if data['source']!=expected_source or proof['source']!=expected_source:raise ValueError('source metadata mismatch')
    metrics=bake.validate_mesh(data,set(source_json['animations']),pages)
    if metrics!=proof['metrics']:raise ValueError('revalidated inline geometry differs from proof')
    compression=compact(data)
    output.mkdir(parents=True,exist_ok=True);target=output/input_path.name
    if target.resolve()==input_path.resolve():raise ValueError('compact output must preserve inline evidence')
    with target.open('w',encoding='ascii') as f:json.dump(data,f,separators=(',',':'),ensure_ascii=True,allow_nan=False)
    # Roundtrip without keeping a second whole body in memory. The serializer is
    # Python's round-trip JSON encoder, and a readback digest is performed by the
    # native consumer test separately; exact in-memory binary64 equality is here.
    report=dict(proof);report.update({'mesh_path':str(target),'bytes':target.stat().st_size,'sha256':bake.sha(target),'inline_evidence':{'path':str(input_path),'bytes':proof['bytes'],'sha256':proof['sha256']},'compact':compression,'compact_seconds':time.monotonic()-started})
    target.with_suffix('.proof.json').write_text(json.dumps(report,ensure_ascii=True,indent=2))
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--input',type=Path,action='append',required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--pack',type=Path,required=True);parser.add_argument('--manifest-sha256',required=True);args=parser.parse_args()
    try:
        pack=args.pack.resolve();output=args.output.resolve()
        if output.is_relative_to(pack):raise ValueError('cannot modify original pack')
        manifest_path=pack/'original_ui.json'
        if bake.sha(manifest_path)!=args.manifest_sha256:raise ValueError('manifest pin mismatch')
        manifest=json.loads(manifest_path.read_text());before={n:bake.sha(bake.original(pack,manifest,n)) for n in manifest['files']}
        reports=[]
        for path in args.input:
            report=convert(path.resolve(),output,args.manifest_sha256,pack);reports.append(report)
            print(json.dumps({'body':report['json_path'],'bytes':report['bytes'],'inline_bytes':report['inline_evidence']['bytes'],'templates':report['compact']['templates'],'binary64_unchanged':True}),flush=True)
        if any(bake.sha(pack/'originals'/n)!=v for n,v in before.items()) or bake.sha(manifest_path)!=args.manifest_sha256:raise ValueError('original files changed')
        shutil.copy2(Path(__file__).with_name('SPINE_RUNTIME_LICENSE.txt'),output/'SPINE_RUNTIME_LICENSE.txt')
        summary={'schema':'twilight.spine36.compact-verification.v1','manifest_sha256':args.manifest_sha256,'original_files':len(before),'originals_unchanged':True,'source_manifest_unchanged':True,'bodies':reports,'scope':'exact page/UV/index deduplication of official SDK mesh evaluation; no original pixel/layout/device acceptance'}
        (output/'compact-summary.json').write_text(json.dumps(summary,ensure_ascii=True,indent=2));return 0
    except (ValueError,OSError,KeyError,TypeError) as error:
        print('SPINE36_COMPACT_ERROR '+str(error),file=sys.stderr);return 2

if __name__=='__main__':raise SystemExit(main())
