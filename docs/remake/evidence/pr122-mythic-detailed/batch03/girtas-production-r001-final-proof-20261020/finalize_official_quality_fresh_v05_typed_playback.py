"""Read-only serializer: requires actual48 review and exact production clone pins.

No engine, Git, network, catalog writes, approvals or counter changes occur here.
This must not run until root supplies the reviewed production resource snapshot.
"""
from pathlib import Path
import json,sys,hashlib
B=Path('/workspace/scratch/girtas-ne-final-source-cycle-independent-fresh-20261020');R=Path('/workspace/twilight')
sys.path.insert(0,str(B))
from fresh_quality_common import sha,jsha,write,ALLCHECKS,snapshot_ledger

def finalize(draft_path,staging_path,production_path,official_description_path,default_main_log_path,archive_map_path=None):
    draft=json.loads(Path(draft_path).read_text());s=json.loads(Path(staging_path).read_text());p=json.loads(Path(production_path).read_text())
    assert draft['status']=='HOLD_PENDING_EXACT_PRODUCTION_BINDING_ALL48_ACTUAL_CHECKS_PASSED'
    assert len(draft['tracks'])==48 and draft['coverage']['poses']==288
    assert draft['reviewed_staging_frames']==s['frames'] and draft['reviewed_staging_profile']==s['profile']
    assert draft['effective_profile_sha256']==s['effective_profile_sha256']
    assert all(draft['checks'][k]=='PASS' for k in ALLCHECKS)
    assert not draft['actor_approved'] and not draft['counts_changed']
    assert s['effective_profile']==p['effective_profile']
    assert s['effective_profile_literal_fields']==p['effective_profile_literal_fields']
    assert s['actor_motion_script']==p['actor_motion_script']
    assert p['track_count']==48 and p['pose_count']==288 and p['all_registry_exact'] and p['all_source_texture_exact']
    # FINAL requires the real current production/defaultMain result, never a candidate log.
    guard_path=Path('/workspace/scratch/pr122-girtas-production-reviewed/girtas_review_guard.py')
    assert sha(guard_path)=='c45becf1e68e927bf6eb908c5f8304fc1ffeaa64b2be5daaf2fefb187465655f'
    guardns={'__name__':'pr122_quality_main_log_readonly_guard','__file__':str(guard_path)}
    exec(compile(guard_path.read_text(),str(guard_path),'exec'),guardns)
    guardns['checked_gate'](R)
    test=R/'tests/pr122_girtas_native_default_main_connection_test.gd'
    expected_test='63f7d6a995d09e00274955bcc746c6f738ac65f185b5addbd4bfe0a0241ac979'
    assert sha(test)==expected_test
    mainlog=Path(default_main_log_path);assert mainlog.is_file() and not mainlog.is_symlink()
    assert sha(R/'data/pr122_native_locomotion_staging.json')==p['register']['sha256']
    maininputs=guardns['input_marker'](p['register']['sha256'],sha(R/'data/catalog_v19.json'),sha(R/'data/combat_animation_profiles.json'),p['frames']['sha256'],p['profile']['sha256'])
    guardns['verify_log'](mainlog.read_text(),marker='PR122_NATIVE_DEFAULT_MAIN_PASS key=transform:267 tracks=48 poses=288 candidate_injection=0',engine='4.7.2.stable.official.ed1daf0bf',test_sha=expected_test,inputs=maininputs)
    mainbinding={'status':'PASS_REAL_DEFAULT_MAIN_INPUTS_LOG_AND_TEST_SHA_EXACT','log':{'path':str(mainlog),'sha256':sha(mainlog)},'input_marker':maininputs,'test':{'path':str(test),'sha256':expected_test},'engine':'4.7.2.stable.official.ed1daf0bf','candidate_injection':0}
    for v in [s,p]:
        for field in ['frames','profile','register','actor_motion_script']:assert sha(v[field]['path'])==v[field]['sha256']
        for t in v['tracks']:
            assert sha(t['source'])==t['source_sha256'] and sha(t['texture'])==t['texture_sha256']
    # The official gate is definition-only/read-only. Execute it without import cache writes.
    gate=R/'tools/pr122_native_production_approvals.py';ns={'__name__':'pr122_quality_read_only_gate','__file__':str(gate)}
    exec(compile(gate.read_text(),str(gate),'exec'),ns)
    actual=ns['describe_actor'](R,'transform:267')
    expected=json.loads(Path(official_description_path).read_text());assert actual==expected
    pins=actual['pins'];descriptor={(t['direction'],t['role']):t for t in actual['tracks']}
    assert len(descriptor)==48
    for fk,pk in [('production_frames','frames'),('production_profile','profile')]:
        z=pins[fk];assert str(R/z['path'].removeprefix('res://'))==p[pk]['path'] and z['sha256']==p[pk]['sha256']
    rows=[];eq=[];seen=set()
    mapping=json.loads(Path(archive_map_path).read_text()) if archive_map_path else {}
    for row in draft['tracks']:
        key=row['direction'],row['role'];assert key not in seen;seen.add(key)
        a=next(t for t in s['tracks'] if(t['direction'],t['role'])==key);b=next(t for t in p['tracks'] if(t['direction'],t['role'])==key)
        assert len(a['poses'])==len(b['poses'])==row['poses']==6
        fields=['source_sha256','texture_sha256','loop','speed','immutable_source_geometry_pin']
        checks={k:a[k]==b[k] for k in fields}
        for n,(u,v) in enumerate(zip(a['poses'],b['poses'])):
            for f in ['region','margin','canvas_size','source_anchor','rgba_sha256','world_factor','duration']:checks[f'pose{n}_{f}']=u[f]==v[f]
        assert all(checks.values()),(key,checks)
        d=descriptor[key];assert d['source_sha256']==b['source_sha256']==row['source_sha256']
        assert d['frame_rgba_sha256']==[f['rgba_sha256'] for f in b['poses']]==row['frame_rgba_sha256']
        findings=row['visual_findings'];assert findings and all(isinstance(x,str) and x.strip() for x in findings)
        new=dict(row);new.update(d);new['status']='PASS'
        evidence=new['independent_review_evidence']
        if evidence['path'] in mapping:
            mapped=mapping[evidence['path']];assert mapped['sha256']==evidence['sha256'];assert sha(R/mapped['path'])==mapped['sha256'];new['independent_review_evidence']=mapped
        rows.append(new);eq.append({'direction':key[0],'role':key[1],'status':'PASS','compared':checks})
    assert len({h for t in rows for h in t['frame_rgba_sha256']})==288
    ep=B/'girtas-production-r001-actual48-functional-equivalence.json'
    write(ep,{'schema':'pr122-final48-staging-to-production-functional-equivalence-v1','status':'PASS','staging_numeric_pins':{'path':str(staging_path),'sha256':sha(staging_path)},'production_numeric_pins':{'path':str(production_path),'sha256':sha(production_path)},'official_description':{'path':str(official_description_path),'sha256':sha(official_description_path)},'official_gate':{'path':str(gate),'sha256':sha(gate)},'all48_source_RGBA_region_margin_C_root_timing_equal':True,'profile_numeric_and_all_effective_literal_fields_equal':True,'actor_motion_script_equal':True,'tracks':eq,'actor_approved':False,'counts_changed':False})
    out=dict(draft);out['status']='PASS';out['source_selection_sha256']=pins['source_selection_sha256'];out['production_frames']=pins['production_frames'];out['production_profile']=pins['production_profile'];out['effective_profile_sha256']=pins['effective_profile_sha256'];out['tracks']=rows;out['production_functional_equivalence_proof']={'path':str(ep),'sha256':sha(ep)};out['actual_default_Main_status']='PASS_REAL_DEFAULT_MAIN_LOG_INPUT_BINDING_VERIFIED';out['actor_approved']=False;out['counts_changed']=False
    out['current_scoped_quality_evidence']['fresh_private_image_ledger']=snapshot_ledger()
    out['current_scoped_quality_evidence']['actual_default_Main_verified_log_binding']=mainbinding
    out['current_scoped_quality_evidence']['official_description']={'path':str(official_description_path),'sha256':sha(official_description_path)}
    out['current_scoped_quality_evidence']['staging_presentation_numeric_sha256']=s['effective_profile_sha256']
    output=B/'girtas-production-r001-independent-quality-FINAL.json';write(output,out)
    return {'path':str(output),'sha256':sha(output),'functional_equivalence':{'path':str(ep),'sha256':sha(ep)},'source_selection_sha256':pins['source_selection_sha256'],'actor_approved':False,'counts_changed':False}

if __name__=='__main__':print(json.dumps(finalize(*sys.argv[1:])))
