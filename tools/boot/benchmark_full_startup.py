#!/usr/bin/env python3
"""Measure actual Loading -> title -> Characters -> Main readiness for Land 4.
Uses production scenes, official account creation/selection, zero input wait and
an isolated reusable profile. First/next keep the same verified local inputs;
account snapshots preserve raw bytes and compare the complete account envelope.
Download/install, complete media delivery and GPU/Android rendering are excluded.
"""
import argparse, hashlib, json, os, subprocess, time
from pathlib import Path
from benchmark_provenance import provenance


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def saves(profile):
    return {str(p.relative_to(profile)): sha(p) for p in profile.rglob('*')
            if p.is_file() and ('save' in p.name.lower() or 'character' in p.name.lower())}


def compare_selected_account(before, after):
    """Official account_store.select_character changes only revision, by one.

    seal_payload rebuilds the selected projection; it defines no account seal
    field. Unknown account fields must therefore remain byte-value equivalent.
    """
    if not isinstance(before, dict) or not isinstance(after, dict):
        return {'account_envelope_exact': False, 'revision_increment_exact': False}
    old_revision = before.get('revision')
    new_revision = after.get('revision')
    def whole(value):
        return (isinstance(value, (int, float)) and not isinstance(value, bool)
                and value >= 0 and value <= 9007199254740991 and value % 1 == 0)
    revision_ok = (whole(old_revision) and whole(new_revision)
                   and new_revision == old_revision + 1)
    def numeric_form(value):
        # Godot's JSON reload turns whole numbers into floats. Preserve their
        # exact safe-range value, while bools remain distinct JSON booleans.
        if isinstance(value, float) and abs(value) <= 9007199254740991 and value % 1 == 0:
            return int(value)
        if isinstance(value, dict):
            return {k: numeric_form(v) for k, v in value.items()}
        if isinstance(value, list):
            return [numeric_form(v) for v in value]
        return value
    try:
        exact = (json.dumps(numeric_form({k: v for k, v in before.items() if k != 'revision'}),
                            sort_keys=True, allow_nan=False)
                 == json.dumps(numeric_form({k: v for k, v in after.items() if k != 'revision'}),
                               sort_keys=True, allow_nan=False))
    except (TypeError, ValueError):
        exact = False
    return {'account_envelope_exact': exact,
            'revision_increment_exact': revision_ok}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ['project','profile','output','godot']: p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--source-project',type=Path)
    p.add_argument('--condition',choices=['first','next'],required=True)
    p.add_argument('--mode',choices=['source-land4'],required=True)
    p.add_argument('--game-arg',action='append',default=[],help='Explicit production launch argument, included in first/next identity')
    p.add_argument('--options',type=Path,help='JSON for production OPTIONS.validate/write; required for source-land4')
    p.add_argument('--env',action='append',default=[],help='Explicit KEY=VALUE source paths/flags, recorded in receipt')
    p.add_argument('--input',action='append',default=[],type=Path,help='Input file to hash in receipt, e.g. original ZIP or pinned manifests')
    p.add_argument('--timeout',type=int,default=1800)
    a=p.parse_args(); root=a.project.resolve(); profile=a.profile.resolve(); output=a.output.resolve()
    code=provenance(root,(a.source_project or a.project).resolve())
    marker=profile/'.twilight-fullstartup-benchmark.json'
    options=json.loads(a.options.read_text()) if a.options else {'enabled':False}
    if a.mode=='source-land4' and not (options.get('enabled') is True and options.get('native_land_id')==4 and options.get('navigation_profile')=='CURRENT523_GENERIC_S32_OWN_ALLOWLIST_V1' and len(options.get('source_position',[]))==2):
        p.error('source-land4 requires explicit enabled generic Land 4 options with native source_position and both exact manifest pins')
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
    env={**clean_env,**extra,'XDG_DATA_HOME':str(profile/'data'),'XDG_CONFIG_HOME':str(profile/'config'),'XDG_CACHE_HOME':str(profile/'cache'),'TWILIGHT_ENTRY_OPTIONS':str(option_copy),'TWILIGHT_ENTRY_RESULT':str(result),'TWILIGHT_FULLSTARTUP_CONDITION':a.condition}
    snapshot_dir=output/(label+'-save-snapshots');snapshot_dir.mkdir()
    def save_copies(tag):
        values={}
        for file in profile.rglob('*.json'):
            if not file.is_file(): continue
            try: document=json.loads(file.read_bytes())
            except (ValueError,UnicodeDecodeError): continue
            if isinstance(document,dict) and isinstance(document.get('character_account'),dict):
                rel=str(file.relative_to(profile));data=file.read_bytes();dest=snapshot_dir/(tag+'-'+hashlib.sha256(rel.encode()).hexdigest()+'.json');dest.write_bytes(data);values[rel]={'path':str(dest),'sha256':hashlib.sha256(data).hexdigest(),'document':json.loads(data)}
        return values
    accounts_before=save_copies('before')
    before=saves(profile); peak=0; timed_out=False; start=time.monotonic()
    cmd=[str(a.godot.resolve()),'--headless','--path',str(root),'--script','res://tools/boot/benchmark_full_startup.gd']
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
    elapsed=time.monotonic()-start; after=saves(profile);accounts_after=save_copies('after')
    lines=log.read_text(errors='replace').splitlines(); errors=[x for x in lines if 'ERROR:' in x or 'SCRIPT ERROR:' in x]
    record=json.loads(result.read_text()) if result.is_file() else {}
    stages=[dict(v.split('=',1) for v in x.split()[1:] if '=' in v) for x in lines if x.startswith('BOOT_PROGRESS ')]
    preservation={key:{'before':value,'after':after.get(key),'unchanged':after.get(key)==value} for key,value in before.items()}
    account_preservation={}
    for key,old in accounts_before.items():
        new=accounts_after.get(key)
        old_account=old['document']['character_account'];new_account=new['document']['character_account'] if new else {}
        comparison=compare_selected_account(old_account,new_account)
        account_preservation[key]={'before_snapshot':old['path'],'after_snapshot':new['path'] if new else None,'before_sha256':old['sha256'],'after_sha256':new['sha256'] if new else None,**comparison,'revision_before':old_account.get('revision'),'revision_after':new_account.get('revision')}
    # The only allowed account change is the documented selection revision +1.
    # Unknown account fields and unrelated existing save files remain exact.
    preserved=all(x['account_envelope_exact'] and x['revision_increment_exact'] for x in account_preservation.values()) and all(x['unchanged'] for key,x in preservation.items() if key not in accounts_before)
    preserved=preserved and bool(accounts_after) and (a.condition!='next' or bool(accounts_before))
    passed=proc.returncode==0 and not timed_out and not errors and record.get('ok') is True and record.get('failures')==[] and preserved and any(x.get('ev')=='loading_ready' for x in stages)
    artifact={'passed':passed,'returncode':proc.returncode,'timeout':timed_out,'process_wall_seconds':elapsed,'sampled_peak_rss_kib':peak,'rss_sample_interval_seconds':.05,'strict_errors':errors,'code':code,'condition':condition,'profile':str(profile),'save_preservation':preservation,'account_preservation':account_preservation,'account_snapshots':{'before':{k:{x:y for x,y in v.items() if x!='document'} for k,v in accounts_before.items()},'after':{k:{x:y for x,y in v.items() if x!='document'} for k,v in accounts_after.items()}},'new_save_files':{k:v for k,v in after.items() if k not in before},'boot_progress':stages,'command':cmd,'result':str(result),'log':str(log),'effective_twilight_env':{k:v for k,v in env.items() if k.startswith('TWILIGHT_')},'scope':'Full startup local inputs, actual lobby; selection revision must increment by exactly one; entire remaining account envelope must match. Headless only. First is empty app profile, not controlled OS page cache; next retains own bakes/saves. No GPU/Android/full original media claim.'}
    receipt.write_text(json.dumps(artifact,ensure_ascii=False,indent=2)+'\n')
    if a.condition=='first': marker.write_text(json.dumps({'condition':condition,'first_completed':passed,'first_receipt':str(receipt)},sort_keys=True))
    print(json.dumps({'passed':passed,'receipt':str(receipt),'seconds':elapsed}))
    raise SystemExit(0 if passed else 1)

if __name__=='__main__': main()
