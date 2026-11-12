#!/usr/bin/env python3
"""Evaluate verified original 3.6 inputs with an external pinned Spine C SDK.

No images are created or changed. The mesh samples are a host playback policy,
not proof of original placement, frame cadence, blend policy or device behavior.
The caller must hold the Spine runtime integration rights described in README.
"""
from __future__ import annotations
import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time

SDK_GIT = '654c20e5b0e523040b6366bbd1042510d2645134'
DEFINITION_SHA = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
FILES_INFO_SHA = 'fefb29fb8126f106e4d127b59a81459efc576d5a6eab8456b4c4988ae390f4dc'
RENDER_TYPES = {'region', 'mesh', 'linkedmesh'}
BLENDS = {'normal','additive','multiply','screen'}
UNREACHABLE_SCOPE = 'default setup, declared source attachment/deform timelines and linked-mesh graph only; not external client setAttachment calls'


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''): h.update(chunk)
    return h.hexdigest()


def relative(path: str) -> PurePosixPath:
    p = PurePosixPath(path)
    if not path or p.is_absolute() or '..' in p.parts or ':' in path or '\\' in path or str(p)!=path:
        raise ValueError('unsafe source member: '+path)
    return p


def original(pack: Path, manifest: dict, member: str) -> Path:
    p = pack/'originals'/str(relative(member))
    if not p.resolve().is_relative_to((pack/'originals').resolve()): raise ValueError('source path escape')
    meta = manifest['files'].get(member)
    if not isinstance(meta,dict) or not p.is_file() or p.stat().st_size!=meta.get('bytes') or sha(p)!=meta.get('sha256'):
        raise ValueError('source byte mismatch: '+member)
    return p


def atlas_names(text: str) -> tuple[set[str], list[str]]:
    regions, pages = set(), []
    page = None
    for raw in text.splitlines():
        line = raw.strip()
        if not line: page=None; continue
        if page is None:
            if not line.endswith('.png'): raise ValueError('atlas page is not a declared PNG')
            relative(line); pages.append(line);page=line
        elif not raw[0].isspace() and ':' not in line:
            if line in regions: raise ValueError('duplicate atlas region: '+line)
            regions.add(line)
    if not pages: raise ValueError('empty atlas')
    return regions,pages


def missing_attachment_audit(data: dict, regions: set[str]) -> list[dict]:
    skins = data.get('skins'); animations=data.get('animations'); slots=data.get('slots')
    if not isinstance(skins,dict) or set(skins)!={'default'} or not isinstance(animations,dict) or not isinstance(slots,list):
        raise ValueError('unsupported skin/animation structure')
    setup={s['name']:s.get('attachment') for s in slots}
    missing=[]
    for skin_name, skin in skins.items():
        for slot_name, attachments in skin.items():
            if slot_name not in setup or not isinstance(attachments,dict): raise ValueError('invalid skin slot')
            for key, attachment in attachments.items():
                if attachment.get('type','region') not in RENDER_TYPES: continue
                resolved_name=attachment.get('name',key); path=attachment.get('path',resolved_name)
                if path in regions: continue
                names={key,resolved_name}; reasons=[]
                if setup[slot_name] in names: reasons.append('setup_attachment')
                for animation_name, animation in animations.items():
                    for entry in animation.get('slots',{}).get(slot_name,{}).get('attachment',[]):
                        if entry.get('name') in names: reasons.append('attachment_timeline:'+animation_name)
                    for group in ['deform','ffd']:
                        for name in names:
                            if name in animation.get(group,{}).get(skin_name,{}).get(slot_name,{}): reasons.append(group+':'+animation_name)
                for other_skin, other_slots in skins.items():
                    for other_slot, others in other_slots.items():
                        for other in others.values():
                            if other.get('type') in {'mesh','linkedmesh'} and 'parent' in other and other_slot==slot_name and other.get('skin','default')==skin_name and other.get('parent') in names:
                                reasons.append('linked_mesh_parent')
                row={'skin':skin_name,'slot':slot_name,'attachment':key,'path':path,'type':attachment.get('type','region'),'reason':'unreferenced_missing_original_region','scope':UNREACHABLE_SCOPE,'references':sorted(set(reasons))}
                if reasons: raise ValueError('referenced original atlas region is missing: '+json.dumps(row,ensure_ascii=False))
                missing.append(row)
    # A path is skipped by the SDK loader, so all uses of that path must have
    # independently passed the same reachability proof above.
    return missing


def validate_source_constraints(data: dict) -> None:
    for section,key in [('paths','path'),('ik','ik'),('transform','transform')]:
        declared={v['name'] for v in data.get(key,[])}
        for animation in data['animations'].values():
            unknown=set(animation.get(section,{}))-declared
            if unknown: raise ValueError('unknown source constraint: '+repr(unknown))


def build(sdk: Path, output: Path, cc: str) -> tuple[Path,dict]:
    actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=sdk,text=True).strip()
    if actual!=SDK_GIT or subprocess.check_output(['git','status','--porcelain','--untracked-files=all'],cwd=sdk,text=True).strip():
        raise ValueError('SDK pin or tracked working tree mismatch')
    license_file=sdk/'LICENSE'; sources=sorted((sdk/'spine-c/spine-c/src/spine').glob('*.c'))
    include=sdk/'spine-c/spine-c/include'; exporter=Path(__file__).with_name('export_mesh.c')
    if not sources or not license_file.is_file(): raise ValueError('external SDK files absent')
    output.mkdir(parents=True,exist_ok=True); binary=output/'export_mesh';obj=output/'export_mesh.o'
    commands=[[cc,'-O2','-std=c99','-Wall','-Wextra','-Werror','-I',str(include),'-c',str(exporter),'-o',str(obj)],
              [cc,'-O2','-std=c99','-I',str(include),str(obj),*[str(p) for p in sources],'-lm','-o',str(binary)]]
    logs=[]
    for command in commands:
        result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
        logs.append(result.stdout)
        if result.returncode: raise ValueError('SDK build failed: '+result.stdout)
    (output/'build.log').write_text('\n'.join(logs));shutil.copy2(license_file,output/'SPINE_RUNTIME_LICENSE.txt')
    return binary,{'sdk_git':actual,'sdk_license_sha256':sha(license_file),'exporter_sha256':sha(exporter),'binary_sha256':sha(binary),'compiler':subprocess.check_output([cc,'--version'],text=True).splitlines()[0],'flags':['-O2','-std=c99'],'fast_math':False}


def validate_mesh(data: dict, expected_clips: set[str], pages: dict) -> dict:
    if data.get('schema')!='twilight.spine36.mesh.v1' or data.get('coordinate_space')!='godot_y_down' or data.get('premultiplied_alpha') is not False:
        raise ValueError('invalid mesh envelope')
    if set(data.get('clips',{}))!=expected_clips: raise ValueError('SDK clip set differs from raw JSON')
    values=0;max_batches=0;frames=0;triangles=0;movement={};bounds=[math.inf,math.inf,-math.inf,-math.inf]
    def pose(p: dict) -> str:
        nonlocal values,max_batches,triangles
        if not isinstance(p.get('batches'),list):raise ValueError('invalid pose')
        max_batches=max(max_batches,len(p['batches']));h=hashlib.sha256()
        for batch in p['batches']:
            ps,uvs,ids=batch['positions'],batch['uvs'],batch['indices']
            if batch.get('page') not in pages or batch.get('blend') not in BLENDS or len(ps)<6 or len(ps)%2 or len(ps)!=len(uvs) or not ids or len(ids)%3:raise ValueError('invalid batch')
            if any(isinstance(i,bool) or not isinstance(i,int) or i<0 or i>=len(ps)//2 for i in ids):raise ValueError('invalid triangle index')
            if any(isinstance(x,bool) or not isinstance(x,(int,float)) or not math.isfinite(x) for x in ps+uvs+batch['color']+batch.get('dark_color',[])):raise ValueError('nonfinite geometry')
            if len(batch['color'])!=4 or ('dark_color'in batch and len(batch['dark_color'])!=4):raise ValueError('invalid tint')
            if any(v<0 or v>1 for v in batch['color']+batch.get('dark_color',[])):raise ValueError('tint outside [0,1]')
            if any(v < -1e-5 or v > 1.00001 for v in uvs):raise ValueError('UV outside original page')
            for i in range(0,len(ps),2):bounds[0]=min(bounds[0],ps[i]);bounds[1]=min(bounds[1],ps[i+1]);bounds[2]=max(bounds[2],ps[i]);bounds[3]=max(bounds[3],ps[i+1])
            values+=len(ps)+len(uvs)+len(ids);triangles+=len(ids)//3
            for field in [ps,uvs,batch['color'],batch.get('dark_color',[])]:h.update(array('f',field).tobytes())
            h.update(array('I',ids).tobytes());h.update(batch['page'].encode());h.update(batch['blend'].encode())
        return h.hexdigest()
    setup_hash=pose(data['setup'])
    for name,clip in data['clips'].items():
        duration=clip['duration'];samples=clip['frames']
        if not math.isfinite(duration) or duration<0 or not samples or samples[0]['time']!=0 or abs(samples[-1]['time']-duration)>1e-5:raise ValueError('invalid clip time range')
        previous=-1; hashes=set()
        for sample in samples:
            t=sample['time']
            if not math.isfinite(t) or t<=previous or t>duration+1e-5:raise ValueError('invalid sample time')
            previous=t;hashes.add(pose(sample));frames+=1
        movement[name]={'duration':duration,'frames':len(samples),'distinct_geometry_hashes':len(hashes),'sampling_fps':clip['fps']}
    return {'geometry_values':values,'max_batches':max_batches,'frames':frames,'triangles':triangles,'bounds':bounds,'setup_geometry_sha256':setup_hash,'clips':movement}


def bake(pack: Path, manifest: dict, member: str, output: Path, binary: Path, build_info: dict, fps: int) -> dict:
    start=time.monotonic();json_path=original(pack,manifest,member);atlas_member=manifest['lobby_spines'][member]['atlas'];atlas_path=original(pack,manifest,atlas_member)
    raw=json.loads(json_path.read_text());validate_source_constraints(raw);regions,page_names=atlas_names(atlas_path.read_text());missing=missing_attachment_audit(raw,regions)
    pages={}
    for name in page_names:
        path=str(PurePosixPath(atlas_member).parent/name);p=original(pack,manifest,path);pages[path]={'sha256':sha(p),'bytes':p.stat().st_size}
    target=output/(PurePosixPath(member).stem+'.mesh.json');raw_path=output/(target.stem+'.sdk.json');log_path=output/(target.stem+'.sdk.log')
    command=[str(binary),'--json',str(json_path),'--atlas',str(atlas_path),'--page-prefix',str(PurePosixPath(atlas_member).parent)+'/', '--fps',str(fps)]
    for path in sorted({m['path'] for m in missing}):command+=['--skip-unreachable-path',path]
    with raw_path.open('wb') as stream,log_path.open('wb') as log:
        result=subprocess.run(command,stdout=stream,stderr=log,timeout=300)
    if result.returncode:raise ValueError('SDK evaluation failed: '+log_path.read_text())
    sdk_log=log_path.read_text();observed=re.search(r'skipped_unreferenced=(\d+)',sdk_log)
    if not observed or int(observed.group(1))!=len(missing):raise ValueError('SDK skip count differs from audited declarations')
    data=json.loads(raw_path.read_text())
    if data['source']['spine_version']!=raw['skeleton']['spine'] or not data['source']['spine_version'].startswith('3.6.'):raise ValueError('SDK/source version mismatch')
    data['source'].update({'json_sha256':sha(json_path),'atlas_sha256':sha(atlas_path),'runtime_git':SDK_GIT,'pages':pages,'unreferenced_missing_attachments':missing})
    metrics=validate_mesh(data,set(raw['animations']),pages)
    with target.open('w') as f:json.dump(data,f,separators=(',',':'),ensure_ascii=False,allow_nan=False)
    report={'json_path':member,'atlas_path':atlas_member,'mesh_path':str(target),'bytes':target.stat().st_size,'sha256':sha(target),'source':data['source'],'build':build_info,'metrics':metrics,'seconds':time.monotonic()-start,'sdk_log':sdk_log,'adapter_policy':{'dark_alpha':'0: shader straight-alpha/PMA-false flag; SDK six-digit-dark RGB alpha sentinel is not a shader input'},'scope':'official3.6 SDK evaluation and strict mesh-data validation; no original render/layout/device acceptance'}
    target.with_suffix('.proof.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));raw_path.unlink()
    return report


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--pack',type=Path,required=True);parser.add_argument('--manifest-sha256',required=True);parser.add_argument('--sdk',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);parser.add_argument('--body',action='append');parser.add_argument('--fps',type=int,default=60);parser.add_argument('--cc',default='cc');args=parser.parse_args()
    try:
        pack=args.pack.resolve();output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
        if output.is_relative_to(pack):raise ValueError('derived output must not alter the original pack')
        if not 1<=args.fps<=120 or not re.fullmatch('[0-9a-f]{64}',args.manifest_sha256):raise ValueError('invalid fps/manifest pin')
        manifest_path=pack/'original_ui.json'
        if sha(manifest_path)!=args.manifest_sha256:raise ValueError('manifest pin mismatch')
        manifest=json.loads(manifest_path.read_text());source=manifest.get('lobby_source',{})
        if source.get('kind')!='twilight.source523.lobby-input.v1' or source.get('source_snapshot')!='patch523' or source.get('definition_sha256')!=DEFINITION_SHA or source.get('files_info_sha256')!=FILES_INFO_SHA:raise ValueError('source provenance mismatch')
        before={name:sha(original(pack,manifest,name)) for name in manifest['files']};before_manifest=sha(manifest_path)
        members=args.body or list(manifest['lobby_spines'])
        if len(set(members))!=len(members) or any(m not in manifest['lobby_spines'] for m in members):raise ValueError('unknown/duplicate body')
        binary,build_info=build(args.sdk.resolve(),output/'build',args.cc);reports=[]
        for member in members:
            report=bake(pack,manifest,member,output,binary,build_info,args.fps);reports.append(report);print(json.dumps({'body':member,'bytes':report['bytes'],'frames':report['metrics']['frames'],'geometry_values':report['metrics']['geometry_values'],'unreferenced_missing':len(report['source']['unreferenced_missing_attachments'])}),flush=True)
        after={name:sha(pack/'originals'/name) for name in before};assert after==before and sha(manifest_path)==before_manifest
        summary={'schema':'twilight.spine36.bake-verification.v1','manifest_sha256':before_manifest,'original_files':len(before),'originals_unchanged':True,'source_manifest_unchanged':True,'build':build_info,'bodies':reports,'scope':'computed source mesh samples, not authored images or original layout/render/device acceptance'}
        (output/'bake-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2));print(json.dumps({'bodies':len(reports),'summary':str(output/'bake-summary.json'),'originals_unchanged':True}));return 0
    except (ValueError,OSError,KeyError,AssertionError,subprocess.SubprocessError) as error:
        print('SPINE36_BAKE_ERROR '+str(error),file=sys.stderr);return 2

if __name__=='__main__':raise SystemExit(main())
