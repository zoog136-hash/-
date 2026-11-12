#!/usr/bin/env python3
"""Final strict consumer contract and on-disk binary64 equivalence gate."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path, PurePosixPath
import sys
import bake_mesh as bake
import compact_mesh as compact


def numeric(v):
    return not isinstance(v,bool) and isinstance(v,(int,float)) and math.isfinite(v)


def verify(path, proof, manifest, pack):
    if path.stat().st_size!=proof['bytes'] or bake.sha(path)!=proof['sha256']:raise ValueError('mesh file hash mismatch')
    data=json.loads(path.read_text(encoding='ascii'))
    if data.get('schema')!='twilight.spine36.mesh.v1' or data.get('coordinate_space')!='godot_y_down' or data.get('premultiplied_alpha') is not False:raise ValueError('invalid envelope')
    member=proof['json_path'];source_json=json.loads(bake.original(pack,manifest,member).read_text());atlas_member=manifest['lobby_spines'][member]['atlas'];atlas_path=bake.original(pack,manifest,atlas_member)
    regions,page_names=bake.atlas_names(atlas_path.read_text());pages={}
    for name in page_names:
        page=str(PurePosixPath(atlas_member).parent/name);p=bake.original(pack,manifest,page);pages[page]={'bytes':p.stat().st_size,'sha256':bake.sha(p)}
    expected={'json_sha256':bake.sha(bake.original(pack,manifest,member)),'atlas_sha256':bake.sha(atlas_path),'spine_version':source_json['skeleton']['spine'],'runtime_git':bake.SDK_GIT,'pages':pages,'unreferenced_missing_attachments':bake.missing_attachment_audit(source_json,regions)}
    if data.get('source')!=expected or proof['source']!=expected or proof['build']['sdk_git']!=bake.SDK_GIT:raise ValueError('source metadata mismatch')
    if set(data.get('clips',{}))!=set(source_json['animations']):raise ValueError('clip keys changed')
    geometries=data.get('geometries')
    if not isinstance(geometries,dict) or len(geometries)!=proof['compact']['templates']:raise ValueError('invalid templates')
    for key,geo in geometries.items():
        if not isinstance(key,str) or not key or len(key)>256 or set(geo)!={'page','uvs','indices'} or geo['page'] not in pages:raise ValueError('invalid geometry template')
        uv,ids=geo['uvs'],geo['indices']
        if not isinstance(uv,list) or len(uv)<6 or len(uv)%2 or not isinstance(ids,list) or len(ids)<3 or len(ids)%3:raise ValueError('invalid template arrays')
        if any(not numeric(v) or v < -1e-5 or v > 1.00001 for v in uv):raise ValueError('invalid template UV')
        if any(isinstance(v,bool) or not isinstance(v,int) or v<0 or v>=len(uv)//2 for v in ids):raise ValueError('invalid template indices')
    values=triangles=refs=max_batches=0
    for pose in compact.poses(data):
        batches=pose.get('batches')
        if not isinstance(batches,list):raise ValueError('invalid pose')
        max_batches=max(max_batches,len(batches))
        for batch in batches:
            if 'geometry' not in batch:raise ValueError('final body still contains inline geometry')
            page,uv,ids=compact.resolved(batch,geometries);positions=batch['positions']
            if len(positions)!=len(uv) or any(not numeric(v) for v in positions):raise ValueError('invalid evaluated positions')
            if batch.get('blend') not in bake.BLENDS:raise ValueError('invalid blend')
            for key in ['color','dark_color']:
                if key not in batch:
                    if key=='color':raise ValueError('missing light tint')
                    continue
                tint=batch[key]
                if not isinstance(tint,list) or len(tint)!=4 or any(not numeric(v) or v<0 or v>1 for v in tint):raise ValueError('invalid tint')
                if key=='dark_color' and tint[3]!=0:raise ValueError('dark shader alpha differs from PMA-false policy')
            values+=len(positions)+len(uv)+len(ids);triangles+=len(ids)//3;refs+=1
    frames=0
    for clip in data['clips'].values():
        duration=clip['duration'];samples=clip['frames'];fps=clip['fps']
        if not numeric(duration) or duration<0 or not numeric(fps) or fps<1 or fps>120 or not samples or samples[0]['time']!=0 or abs(samples[-1]['time']-duration)>1e-5:raise ValueError('invalid clip range')
        previous=-1
        for pose in samples:
            t=pose['time']
            if not numeric(t) or t<=previous or t>duration+1e-5:raise ValueError('timestamps are not strictly increasing')
            previous=t;frames+=1
    metrics=proof['metrics']
    if any(actual!=metrics[key] for key,actual in [('geometry_values',values),('triangles',triangles),('max_batches',max_batches),('frames',frames)]):raise ValueError('expanded geometry counts changed')
    if refs!=proof['compact']['batch_references']:raise ValueError('reference count differs')
    digest=compact.expanded_digest(data)
    if digest!=proof['compact']['expanded_binary64_sha256_before'] or digest!=proof['compact']['expanded_binary64_sha256_after']:raise ValueError('on-disk binary64 geometry changed')
    return {'json_path':member,'mesh_path':str(path),'bytes':path.stat().st_size,'sha256':bake.sha(path),'frames':frames,'clips':len(data['clips']),'templates':len(geometries),'expanded_geometry_values':values,'binary64_roundtrip_sha256':digest,'strict_timestamp_tint_geometry_pass':True,'missing_unreferenced':len(expected['unreferenced_missing_attachments']),'source':expected,'build':proof['build']}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--directory',type=Path,required=True);parser.add_argument('--pack',type=Path,required=True);parser.add_argument('--manifest-sha256',required=True);args=parser.parse_args()
    try:
        pack=args.pack.resolve();directory=args.directory.resolve();manifest_path=pack/'original_ui.json'
        if directory.is_relative_to(pack) or bake.sha(manifest_path)!=args.manifest_sha256:raise ValueError('invalid output or manifest pin')
        manifest=json.loads(manifest_path.read_text());before={n:bake.sha(bake.original(pack,manifest,n)) for n in manifest['files']};reports=[]
        for member in manifest['lobby_spines']:
            path=directory/(PurePosixPath(member).stem+'.mesh.json');proof=json.loads(path.with_suffix('.proof.json').read_text())
            report=verify(path,proof,manifest,pack);reports.append(report);print(json.dumps({'body':member,'bytes':report['bytes'],'strict_pass':True}),flush=True)
        if any(bake.sha(pack/'originals'/n)!=v for n,v in before.items()) or bake.sha(manifest_path)!=args.manifest_sha256:raise ValueError('original files changed')
        summary={'schema':'twilight.spine36.final-verification.v1','manifest_sha256':args.manifest_sha256,'original_files':len(before),'original_bytes':sum(manifest['files'][n]['bytes'] for n in before),'originals_unchanged':True,'source_manifest_unchanged':True,'bodies':reports,'total_bytes':sum(r['bytes'] for r in reports),'maximum_body_bytes':max(r['bytes'] for r in reports),'clips':sum(r['clips'] for r in reports),'frames':sum(r['frames'] for r in reports),'scope':'official SDK source mesh and strict on-disk data contract; not original pixel/layout/GPU/device acceptance'}
        (directory/'final-summary.json').write_text(json.dumps(summary,ensure_ascii=True,indent=2));print(json.dumps({'bodies':len(reports),'clips':summary['clips'],'frames':summary['frames'],'total_bytes':summary['total_bytes'],'maximum_body_bytes':summary['maximum_body_bytes'],'all_pass':True}));return 0
    except (OSError,ValueError,TypeError,KeyError) as error:
        print('SPINE36_VERIFY_ERROR '+str(error),file=sys.stderr);return 2

if __name__=='__main__':raise SystemExit(main())
