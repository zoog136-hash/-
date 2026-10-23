#!/usr/bin/env python3
"""Apply two newly changed registrations, preserving every PNG and frame binding."""
import copy,json,os,shutil,subprocess
from pathlib import Path
import deliver_legendary_isolation_batches_v01 as D
import prepare_legendary_isolation_v01 as I
import prepare_legendary_ownership_delta_v02 as P

PREFIX=D.DOCS/'quality-v03'
def deliver():
    assert not D.git('status','--porcelain')
    pending=D.LOGS/'new-registration-followups-v08-pending-remote.json';assert not pending.exists()
    native_path=D.DOCS/'transform_176-registration-v04-library.json'
    guard_path=PREFIX/'guard-registration-inheritance-plan-v07.json'
    review_path=D.DOCS/'transform_176-quality-registration-review-input-v04.json'
    native=D.read(D.WORK/native_path);guards=D.read(D.WORK/guard_path)
    revisions=native['revisions']+guards['revisions'];assert len(revisions)==2
    manifest_path=PREFIX/'new-registration-followups-library-v08.json'
    manifest={'schema':'legendary-registration-followups-v08','revisions':revisions,'dependency_required_slots':[e['slot'] for e in revisions],
       'excluded_slots':[],'PNG_mutations':0,'frame_binding_mutations':0,'existing_healthy_clips_changed':0,'final_approved':0,'quality_status':'HOLD'}
    if not (D.WORK/manifest_path).exists():D.write_json(D.WORK/manifest_path,manifest,immutable=True)
    assert D.read(D.WORK/manifest_path)==manifest
    report_path=PREFIX/'new-registration-followups-affected-validation-v08.json'
    if not (D.WORK/report_path).exists():
        env=dict(os.environ,XDG_DATA_HOME='/workspace/legendary_runtime/data',XDG_CACHE_HOME='/workspace/legendary_runtime/cache',XDG_CONFIG_HOME='/workspace/legendary_runtime/config')
        D.run([D.GODOT,'--headless','--fixed-fps','60','--path',str(D.WORK),'--script',I.resource(D.DOCS/'validate_guard_parent_inheritance_v07.gd'),'--',I.resource(manifest_path),I.resource(report_path)],'new-registration-followups-v08-validation.log',env=env)
    report=D.read(D.WORK/report_path)
    assert len(report['records'])==2 and all(r['status']=='PASS' for r in report['records'])
    recovery_path=PREFIX/'new-registration-parent-binding-targeted-followup-v08.json'
    if report['failures']:
        assert report['failures']==1 and report['guard_parent_checks'][0]['errors']==['Guard source/region/margin differs from pinned parent']*2
        if not (D.WORK/recovery_path).exists():
            env=dict(os.environ,XDG_DATA_HOME='/workspace/legendary_runtime/data',XDG_CACHE_HOME='/workspace/legendary_runtime/cache',XDG_CONFIG_HOME='/workspace/legendary_runtime/config')
            D.run([D.GODOT,'--headless','--fixed-fps','60','--path',str(D.WORK),'--script',I.resource(D.DOCS/'validate_guard_parent_inheritance_v08.gd'),'--',I.resource(guard_path),I.resource(recovery_path),'--guards-only'],'new-registration-parent-binding-targeted-followup-v08.log',env=env)
        recovery=D.read(D.WORK/recovery_path);assert recovery['failures']==0 and recovery['records']==[] and len(recovery['guard_parent_checks'])==1
    else:
        assert len(report['guard_parent_checks'])==1
    ledger,previous,active=P.active_library();counts=copy.deepcopy(ledger['counts'])
    for e in revisions:
        old=active[tuple(e['slot'])]
        assert e['SpriteFrames']==old['SpriteFrames'] and e['SpriteFrames_sha256']==old['SpriteFrames_sha256']
    paths={native_path,guard_path,review_path,manifest_path,report_path}
    if report['failures']:paths.add(recovery_path)
    for e in revisions:
        for key in ['record','registration']:paths.add(Path(e[key].removeprefix('res://')))
    for n in ['prepare_guard_registration_inheritance_v07.py','deliver_new_registration_followups_v08.py','validate_guard_parent_inheritance_v07.gd','validate_guard_parent_inheritance_v08.gd']:
        paths.add(D.DOCS/n)
    merged={tuple(e['slot']):e for e in previous['revisions']}
    for e in revisions:merged[tuple(e['slot'])]=e
    aggregate=copy.deepcopy(previous);aggregate['revisions']=[merged[k] for k in sorted(merged)];aggregate['dependency_required_slots']=[list(k) for k in sorted(merged)]
    aggpath=PREFIX/'revision-library-with-registration-followups-v08.json';D.write_json(D.WORK/aggpath,aggregate,immutable=True);paths.add(aggpath)
    c=ledger['corrections'];follow=c.setdefault('new_native_quality_registration',{'versions':[],'quality_status':'HOLD','final_approved':0})
    assert not any(e['version']=='registration-v04' for e in follow['versions'])
    follow['versions'].append({'version':'registration-v04','manifest':I.resource(native_path),'manifest_sha256':I.sha((D.WORK/native_path).read_bytes()),
        'validation':I.resource(report_path),'validation_sha256':I.sha((D.WORK/report_path).read_bytes()),'registered_clips':len(native['revisions']),
        'native_frames_preserved_in_scope':native['native_frames_in_affected_clips_preserved'],'input':I.resource(review_path),'input_sha256':I.sha((D.WORK/review_path).read_bytes()),'camera_HOLD_retained':True,'new_PNGs':0})
    c['new_mixed_guard_registration_v07']={'manifest':I.resource(guard_path),'manifest_sha256':I.sha((D.WORK/guard_path).read_bytes()),
        'validation':I.resource(report_path),'validation_sha256':I.sha((D.WORK/report_path).read_bytes()),'affected_new_mixed':len(guards['revisions']),
        'unaffected_new_mixed':len(guards['unaffected_new_mixed']),'registration_HOLD':guards['registration_HOLD'],'PNG_mutations':0,'frame_binding_mutations':0,'final_approved':0}
    c.update(active_revision_library=I.resource(aggpath),active_revision_library_sha256=I.sha((D.WORK/aggpath).read_bytes()))
    byslot={tuple(e['slot']):e for e in revisions}
    for actor in ledger['actors']:
        for draft in actor['drafts']:
            key=(actor['key'],draft['direction'],draft['role'])
            if key in byslot:draft.setdefault('correction_revisions',[]).append(dict(byslot[key],kind='new_registration_followup_v08',quality_status='HOLD'))
    assert counts==ledger['counts']
    for path in sorted(paths):D.copy_new(path)
    D.write_json(D.REPO/D.LEDGER,ledger);shutil.copyfile(D.REPO/D.LEDGER,D.WORK/D.LEDGER);paths.add(D.LEDGER)
    subprocess.run(['git','add','--',*map(str,sorted(paths))],cwd=D.REPO,check=True)
    assert all(p==str(D.LEDGER) or p.startswith(str(D.DOCS)+'/') or p.startswith(str(D.ASSETS)+'/') for p in D.git('diff','--cached','--name-only').splitlines())
    subprocess.run(['git','diff','--cached','--check'],cwd=D.REPO,check=True)
    subprocess.run(['git','commit','-m','[skip ci] Inherit exact guard transforms and register new native hit'],cwd=D.REPO,check=True,stdout=subprocess.DEVNULL)
    receipt={'status':'LOCAL_COMMIT_WAITING_REMOTE','commit_sha':D.git('rev-parse','HEAD'),'manifest':I.resource(manifest_path),'registered_clips':2,'replay_passed_clips':2,'parent_guard_targeted_comparison_passed':True,'minimum_validation':I.resource(report_path),'parent_comparison_followup':I.resource(recovery_path) if report['failures'] else None,'native_frames_preserved':2,'PNG_mutations':0,'frame_binding_mutations':0,'final_approved':0}
    D.write_json(pending,receipt,immutable=True);print(json.dumps(receipt))
if __name__=='__main__':deliver()
