#!/usr/bin/env python3
"""Measure production Loading.open -> finished in an isolated, reusable profile.
No cache deletion; first/next refer to separate processes using the same profile.
"""
import argparse, hashlib, json, os, subprocess, time
from pathlib import Path
from benchmark_provenance import provenance


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def saves(profile):
    return {str(p.relative_to(profile)): sha(p) for p in profile.rglob('*')
            if p.is_file() and ('save' in p.name.lower() or 'character' in p.name.lower())}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['project','profile','output','godot']: p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--source-project',type=Path)
    p.add_argument('--condition',choices=['first','next'],required=True)
    p.add_argument('--mode',choices=['authored','source-land4','synthetic'],required=True)
    p.add_argument('--game-arg',action='append',default=[],help='Explicit production launch argument, included in first/next identity')
    p.add_argument('--options',type=Path,help='JSON for production OPTIONS.validate/write; required for source-land4')
    p.add_argument('--env',action='append',default=[],help='Explicit KEY=VALUE source paths/flags, recorded in receipt')
    p.add_argument('--input',action='append',default=[],type=Path,help='Input file to hash in receipt, e.g. original ZIP or pinned manifests')
    p.add_argument('--timeout',type=int,default=1800)
    a=p.parse_args(); root=a.project.resolve(); profile=a.profile.resolve(); output=a.output.resolve()
    code=provenance(root,(a.source_project or a.project).resolve())
    marker=profile/'.twilight-entry-benchmark.json'
    options=json.loads(a.options.read_text()) if a.options else {'enabled':False}
    if a.mode=='source-land4' and not (options.get('enabled') is True and options.get('native_land_id')==4 and options.get('navigation_profile')=='CURRENT523_GENERIC_S32_OWN_ALLOWLIST_V1' and len(options.get('source_position',[]))==2):
        p.error('source-land4 requires explicit enabled generic Land 4 options with native source_position and both exact manifest pins')
    if a.mode!='source-land4' and options.get('enabled'): p.error('enabled source options require source-land4 mode')
    inputs=[{'path':str(x.resolve()),'bytes':x.stat().st_size,'sha256':sha(x)} for x in a.input]
    extra=dict(x.split('=',1) for x in a.env)
    if any(k.startswith(('XDG_','TWILIGHT_ENTRY_')) for k in extra): p.error('profile and caller environment cannot be overridden')
    identity={'runtime_files':code['runtime_files'],'stage_project_sha256':code['project_godot']['stage_sha256'],'godot_sha256':sha(a.godot.resolve())}
    fingerprint=hashlib.sha256(json.dumps(identity,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    condition={'mode':a.mode,'options':options,'inputs':inputs,'env':extra,'code_engine_sha256':fingerprint,'game_args':a.game_arg}
    if a.condition=='first':
        if profile.exists() and any(profile.iterdir()): p.error('first requires a new/empty isolated profile')
        profile.mkdir(parents=True,exist_ok=True); marker.write_text(json.dumps({'condition':condition,'first_completed':False},sort_keys=True))
    elif not marker.is_file():
        p.error('next requires this tool’s matching successful first-run profile')
    else:
        previous=json.loads(marker.read_text())
        if previous.get('condition')!=condition or previous.get('first_completed') is not True:
            p.error('next requires the same code, engine, settings and a successful first run')
    output.mkdir(parents=True,exist_ok=True)
    label=a.mode+'-'+a.condition
    result=output/(label+'.json'); log=output/(label+'.log'); receipt=output/(label+'-receipt.json')
    if any(x.exists() for x in [result,log,receipt]): p.error('output label exists; preserve earlier evidence')
    option_copy=output/(label+'-options.json'); option_copy.write_text(json.dumps(options))
    clean_env={key:value for key,value in os.environ.items() if not key.startswith('TWILIGHT_')}
    env={**clean_env,**extra,'XDG_DATA_HOME':str(profile/'data'),'XDG_CONFIG_HOME':str(profile/'config'),'XDG_CACHE_HOME':str(profile/'cache'),'TWILIGHT_ENTRY_OPTIONS':str(option_copy),'TWILIGHT_ENTRY_RESULT':str(result)}
    if a.mode=='synthetic': env['TWILIGHT_ENTRY_DESTINATION']='res://tests/fixtures/loading/delayed_ready.tscn'
    else: env['TWILIGHT_ENTRY_DESTINATION']='res://Main.tscn'
    before=saves(profile); peak=0; timed_out=False; start=time.monotonic()
    cmd=[str(a.godot.resolve()),'--headless','--path',str(root),'--script','res://tools/boot/benchmark_loading_entry.gd']
    if a.game_arg:cmd+=['--',*a.game_arg]
    with log.open('w') as stream:
        proc=subprocess.Popen(cmd,env=env,cwd=root,stdout=stream,stderr=subprocess.STDOUT)
        while proc.poll() is None:
            try:
                for row in Path('/proc',str(proc.pid),'status').read_text().splitlines():
                    if row.startswith('VmRSS:'): peak=max(peak,int(row.split()[1]))
            except FileNotFoundError: pass
            if time.monotonic()-start>a.timeout: timed_out=True;proc.kill();proc.wait();break
            time.sleep(.05)
    elapsed=time.monotonic()-start; after=saves(profile)
    lines=log.read_text(errors='replace').splitlines(); errors=[x for x in lines if 'ERROR:' in x or 'SCRIPT ERROR:' in x]
    record=json.loads(result.read_text()) if result.is_file() else {}
    stages=[dict(v.split('=',1) for v in x.split()[1:] if '=' in v) for x in lines if x.startswith('BOOT_PROGRESS ')]
    preservation={key:{'before':value,'after':after.get(key),'unchanged':after.get(key)==value} for key,value in before.items()}
    preserved=all(x['unchanged'] for x in preservation.values())
    passed=proc.returncode==0 and not timed_out and not errors and record.get('ok') is True and record.get('failures')==[] and preserved and any(x.get('ev')=='loading_ready' for x in stages)
    artifact={'passed':passed,'returncode':proc.returncode,'timeout':timed_out,'process_wall_seconds':elapsed,'sampled_peak_rss_kib':peak,'rss_sample_interval_seconds':.05,'strict_errors':errors,'code':code,'condition':condition,'profile':str(profile),'save_preservation':preservation,'new_save_files':{k:v for k,v in after.items() if k not in before},'boot_progress':stages,'command':cmd,'result':str(result),'log':str(log),'effective_twilight_env':{k:v for k,v in env.items() if k.startswith('TWILIGHT_')},'scope':'Headless only. First is empty app profile, not controlled OS page cache; next retains own bakes/saves. No GPU/Android/full original media claim.'}
    receipt.write_text(json.dumps(artifact,ensure_ascii=False,indent=2)+'\n')
    if a.condition=='first': marker.write_text(json.dumps({'condition':condition,'first_completed':passed,'first_receipt':str(receipt)},sort_keys=True))
    print(json.dumps({'passed':passed,'receipt':str(receipt),'seconds':elapsed}))
    raise SystemExit(0 if passed else 1)

if __name__=='__main__': main()
