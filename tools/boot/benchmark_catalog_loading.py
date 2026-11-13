#!/usr/bin/env python3
"""Run the real-source catalog benchmark locally with explicit isolated state.

The source ZIP is read/verified only. Profiles and logs stay local. Godot output
must contain a successful completion record and no parser/runtime errors. A
second invocation with --derived-cold may retain that arm's own verified raw
row bakes; it clears only the five named producer caches in the GD harness.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
from benchmark_provenance import provenance
import re
import subprocess
import time
import zipfile

SOURCE_BYTES=25031173
SOURCE_SHA='d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
MARKER='CATALOG_LOADING_BENCHMARK_RESULT '

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',required=True,type=Path)
    parser.add_argument('--profile',required=True,type=Path)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--label',required=True)
    parser.add_argument('--godot',required=True,type=Path)
    parser.add_argument('--source',required=True,type=Path)
    parser.add_argument('--source-project',type=Path)
    parser.add_argument('--owner',choices=['profiled','production'],default='profiled')
    parser.add_argument('--derived-cold',action='store_true')
    parser.add_argument('--market-public',action='store_true',help='After producer timing, measure actual public Market graph generation')
    parser.add_argument('--phase',choices=['both','native'],default='both')
    parser.add_argument('--timeout',default=1800,type=int)
    args=parser.parse_args()
    root=args.project.resolve(); profile=args.profile.resolve(); output=args.output.resolve();source=args.source.resolve()
    code=provenance(root,(args.source_project or args.project).resolve())
    source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
    if source.stat().st_size!=SOURCE_BYTES or source_hash!=SOURCE_SHA:
        raise ValueError('explicit source ZIP identity differs; no other input selected')
    with zipfile.ZipFile(source) as archive:
        bad=archive.testzip()
        if bad is not None:raise ValueError('source ZIP CRC mismatch: '+bad)
        member_count=len(archive.infolist())
    profile_marker=profile/'.twilight-catalog-benchmark-profile.json'
    if args.derived_cold:
        if not profile_marker.is_file() or json.loads(profile_marker.read_text()).get('source_sha256')!=SOURCE_SHA:
            raise ValueError('--derived-cold only accepts this tool\'s marked isolated benchmark profile')
    else:
        if profile.exists() and any(profile.iterdir()):
            raise ValueError('fresh benchmark profile must be new/empty; refusing existing user data')
        profile.mkdir(parents=True,exist_ok=True)
        profile_marker.write_text(json.dumps({'source_sha256':SOURCE_SHA,'scope':'benchmark-only, no player saves'}))
    output.mkdir(parents=True,exist_ok=True)
    log=output/(args.label+'.log'); result=output/(args.label+'.json'); receipt=output/(args.label+'-receipt.json')
    if log.exists() or result.exists() or receipt.exists():raise ValueError('output label exists; preserve prior results')
    clean_env={key:value for key,value in os.environ.items() if not key.startswith('TWILIGHT_')}
    env={**clean_env,'XDG_DATA_HOME':str(profile/'data'),'XDG_CONFIG_HOME':str(profile/'config'),'XDG_CACHE_HOME':str(profile/'cache'),
         'TWILIGHT_PATCH523_CONTENT':str(source),'TWILIGHT_BAKE_DISK_REQUIRED':'1','TWILIGHT_NATIVE_FIELDS_EAGER':'0','TWILIGHT_RULES_RECORDS_RESIDENT':'0','TWILIGHT_CATALOG_BENCHMARK_PROFILE':'1','TWILIGHT_CATALOG_BENCHMARK_PROFILE_ROOT':str(profile),'TWILIGHT_NATIVE_REGISTER_PROFILE':'1'}
    cmd=[str(args.godot.resolve()),'--headless','--path',str(root),'--script','res://tools/boot/benchmark_catalog_loading.gd','--','--catalog-benchmark-json='+str(result)]
    if args.derived_cold:cmd.append('--catalog-derived-cold')
    cmd.append('--catalog-benchmark-phase='+args.phase)
    cmd.append('--catalog-benchmark-owner='+args.owner)
    if args.market_public:cmd.append('--catalog-market-public')
    started=time.monotonic()
    with log.open('w') as stream:
        proc=subprocess.run(cmd,env=env,cwd=root,stdout=stream,stderr=subprocess.STDOUT,timeout=args.timeout)
    elapsed=time.monotonic()-started
    lines=log.read_text(errors='replace').splitlines()
    errors=[line for line in lines if 'SCRIPT ERROR:' in line or 'ERROR:' in line or '_FAIL' in line]
    markers=[line[len(MARKER):] for line in lines if line.startswith(MARKER)]
    record=json.loads(markers[-1]) if markers else {}
    passed=proc.returncode==0 and not errors and bool(markers) and record.get('failures')==[]
    def git(*words):return subprocess.check_output(['git','-C',str(root),*words],text=True).strip()
    stages=[]
    for line in lines:
        if line.startswith('BOOT_PROGRESS ') and ' ev=end ' in line:
            parts=dict(item.split('=',1) for item in line.split() if '=' in item)
            if 'stage' in parts and 'ms' in parts:stages.append(parts)
    artifact={'passed':passed,'returncode':proc.returncode,'wall_seconds':elapsed,'strict_errors':errors,'project':str(root),'revision':code['revision'],'status':code['status'],'code':code,'owner':args.owner,'market_public':args.market_public,
              'source':{'path':str(source),'bytes':SOURCE_BYTES,'sha256':source_hash,'members':member_count,'crc':'all pass'},
              'profile':str(profile),'condition':'raw bakes retained from own code; only derived producer bakes removed' if args.derived_cold else 'fresh raw and derived bakes',
              'effective_twilight_env':{k:v for k,v in env.items() if k.startswith('TWILIGHT_')},'native_profile_diagnostics':True,'phase':args.phase,'command':cmd,'log':str(log),'result':str(result),'stages':stages,'scope':'Linux headless; original definition tables, no original maps/media/Android timing'}
    receipt.write_text(json.dumps(artifact,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'label':args.label,'passed':passed,'seconds':elapsed,'result':str(result),'receipt':str(receipt)},ensure_ascii=False))
    if not passed:raise SystemExit(1)

if __name__=='__main__':main()
