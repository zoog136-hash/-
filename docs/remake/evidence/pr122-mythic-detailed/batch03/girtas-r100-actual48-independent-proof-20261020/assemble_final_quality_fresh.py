"""Assemble only after all five fresh actual track certificates exist and match target."""
from pathlib import Path
import json,hashlib,datetime,sys
B=Path('/workspace/scratch/girtas-ne-final-source-cycle-independent-fresh-20261020')
A=Path('/workspace/scratch/girtas-final-actual-quality-v03')
sys.path.insert(0,str(B))
from fresh_quality_common import sha,jsha,write,ALLCHECKS,BASECHECKS,snapshot_ledger

def assemble(target_revision,fresh_certificates):
    target_path=B/f'actual-{target_revision}-all48-numeric-pins.json';target=json.loads(target_path.read_text())
    assert target['track_count']==48 and target['pose_count']==288
    assert target['all_registry_exact'] and target['all_source_texture_exact']
    for field in ['frames','profile','register','actor_motion_script']:
        assert sha(target[field]['path'])==target[field]['sha256'],field
    for t in target['tracks']:
        assert sha(t['source'])==t['source_sha256']
        assert sha(t['texture'])==t['texture_sha256']
        assert t['source_sha256']==t['texture_sha256']
    assert len({p['rgba_sha256'] for t in target['tracks'] for p in t['poses']})==288
    stable=A/'girtas-r096-independent-quality-reviewed43-FINAL.json'
    assert sha(stable)=='78e2670b0a91e7ec1eb0a0917707715d845219a05ce329c8e7776b616413bb89'
    stablepins=A/'r096-reviewed43-transferable-exact-pins.json'
    assert sha(stablepins)=='4bfc50bfe4f66d169308e70fc55d1c61e9a3eabea08b992313bcb0ff519aff65'
    old=json.loads(stablepins.read_text());stablecert=json.loads(stable.read_text())
    assert len(stablecert['tracks'])==len(old['tracks'])==43
    certificates=[(stable,stablecert,old)]
    for p in fresh_certificates:
        p=Path(p);c=json.loads(p.read_text());assert c['independent'] and not c['actor_approved']
        revision=Path(c['reviewed_staging_frames']['path']).parent.name
        ev=c['current_scoped_quality_evidence'];binding=ev.get('actual_numeric_pins',ev.get('numeric_actual_pin'))
        assert binding
        pins=Path(binding['path'])
        assert pins.parent in [B,Path('/workspace/scratch/girtas-final-actual-quality-v04')]
        assert pins.name==f'actual-{revision}-all48-numeric-pins.json'
        assert pins.resolve()==pins and sha(pins)==binding['sha256']
        certificates.append((p,c,json.loads(pins.read_text())))
    freshkeys={(t['direction'],t['role']) for _,c,_ in certificates[1:] for t in c['tracks']}
    assert freshkeys=={('W','walk'),('SE','run'),('NW','run'),('SW','run'),('NE','run')},freshkeys
    finaltracks=[];transferrows=[];certpins=[];seen=set()
    for cp,cert,reviewed in certificates:
        reviewed_frames=reviewed.get('frames',reviewed.get('reviewed_frames'))
        reviewed_profile=reviewed.get('profile',reviewed.get('reviewed_profile'))
        assert cert['reviewed_staging_frames']==reviewed_frames
        assert cert['reviewed_staging_profile']==reviewed_profile
        ef=reviewed.get('effective_profile',reviewed.get('effective_profile_numeric'))
        assert ef==target['effective_profile']
        assert reviewed['effective_profile_literal_fields']==target['effective_profile_literal_fields']
        assert reviewed['actor_motion_script']==target['actor_motion_script']
        assert cert['effective_profile_sha256']==target['effective_profile_sha256']
        certpins.append({'path':str(cp),'sha256':sha(cp),'reviewed_tracks':len(cert['tracks'])})
        for ct in cert['tracks']:
            key=ct['direction'],ct['role'];assert key not in seen,key;seen.add(key)
            assert ct['status'].startswith('PASS'),(key,ct['status'])
            a=next(t for t in reviewed['tracks'] if(t['direction'],t['role'])==key)
            b=next(t for t in target['tracks'] if(t['direction'],t['role'])==key)
            assert len(a['poses'])==len(b['poses'])==ct['poses']==6
            assert ct['source_sha256']==a['source_sha256']==b['source_sha256']
            assert ct['loop']==a['loop']==b['loop'] and ct['fps']==a['speed']==b['speed']
            assert ct['duration_seconds']==sum(p['duration'] for p in a['poses'])/a['speed']
            assert ct['immutable_source_geometry_pin']==a['immutable_source_geometry_pin']==b['immutable_source_geometry_pin']
            checks={f:a[f]==b[f] for f in ['source_sha256','texture_sha256','loop','speed','immutable_source_geometry_pin']}
            for n,(p,q) in enumerate(zip(a['poses'],b['poses'])):
                for f in ['region','margin','canvas_size','source_anchor','rgba_sha256','world_factor','duration']:
                    checks[f'pose{n}_{f}']=p[f]==q[f]
            assert all(checks.values()),(key,checks)
            assert len({p['rgba_sha256'] for p in b['poses']})==6
            expected=set(BASECHECKS)
            if key[1]=='attack':expected.add('attack_contact')
            if key[1]=='hit':expected.add('hit_recovery')
            if key[1]=='death':expected.add('death_irreversibility')
            assert set(ct['applicable_checks'])==expected
            assert set(ct['not_applicable_checks'])==set(ALLCHECKS)-expected
            assert all(v=='PASS' for v in ct['applicable_checks'].values())
            row=dict(ct);row['status']='PASS';row['source']=b['source'];row['texture']=b['texture'];row['source_sha256']=b['source_sha256'];row['frame_rgba_sha256']=[p['rgba_sha256'] for p in b['poses']];row['independent_review_evidence']={'path':str(cp),'sha256':sha(cp)};row['actual_review_transferred_by_exact_equality']=True;row['visual_findings']=ct['visual_notes'];row['baseline_unchanged_review_reused']=cp==stable
            finaltracks.append(row);transferrows.append({'direction':key[0],'role':key[1],'from_frames':cert['reviewed_staging_frames'],'to_frames':target['frames'],'status':'PASS_EXACT_FUNCTIONAL_EQUALITY','compared':checks})
    assert len(seen)==48 and sum(t['poses'] for t in finaltracks)==288
    for check in ALLCHECKS:
        applicable=[t for t in finaltracks if check in t['applicable_checks']]
        assert applicable and all(t['applicable_checks'][check]=='PASS' for t in applicable)
    tp=B/f'final-{target_revision}-reviewed48-exact-functional-equivalence.json'
    write(tp,{'schema':'pr122-v04-final48-exact-functional-equivalence-v1','status':'PASS','target_revision':target_revision,'target_numeric_pins':{'path':str(target_path),'sha256':sha(target_path)},'all48_tracks_all288_sourceRGBA_region_margin_C_root_sourceSHA_loop_fps_duration_exact':True,'effective_profile_numeric_and_all_literal_fields_exact':True,'actor_motion_script_exact':True,'tracks':transferrows,'image_views_repeated':0,'actor_approved':False,'counts_changed':False})
    ledger=B/'private-image-ledger.json';ld=json.loads(ledger.read_text());assert ld['viewed_encoded_bytes']<6000000
    out={'schema':'pr122-native-independent-quality-v1','key':'transform:267','status':'HOLD_PENDING_EXACT_PRODUCTION_BINDING_ALL48_ACTUAL_CHECKS_PASSED','independent':True,'reviewer':'Codex independent reviewers: v03 stable43, v04 Wwalk/SErun/NWrun/SWrun, and fresh NErun plus exact transfer aggregation; no reviewer authored the source/layout changes under their actual-review scope','source_selection_sha256':jsha([{'direction':t['direction'],'role':t['role'],'source_sha256':t['source_sha256'],'immutable_source_geometry_pin':t['immutable_source_geometry_pin']} for t in sorted(finaltracks,key=lambda t:(t['direction'],t['role']))]),'effective_profile_sha256':target['effective_profile_sha256'],'checks':{k:'PASS' for k in ALLCHECKS},'tracks':sorted(finaltracks,key=lambda t:(t['direction'],t['role'])),'coverage':{'stable_actual_reviewed_tracks_transferred_exact':43,'fresh_final_actual_reviewed_tracks':5,'tracks':48,'poses':288,'nine_checks':'ALL_APPLICABLE_PASS','stable43_images_reopened_by_v04':0,'stable43_images_reopened_by_fresh':0,'pending_quality_HOLDs_on_selected48':0},'reviewed_staging_frames':target['frames'],'reviewed_staging_profile':target['profile'],'production_functional_equivalence_proof':{'status':'NOT_RUN_SEPARATE_ROOT_PRODUCTION_VALIDATION_REQUIRED'},'current_scoped_quality_evidence':{'final_staging_functional_equivalence_proof':{'path':str(tp),'sha256':sha(tp)},'certificates':certpins,'target_numeric_pins':{'path':str(target_path),'sha256':sha(target_path)},'fresh_private_image_ledger':snapshot_ledger(),'v04_historical_ledger_hash_resolution':{'path':str(Path('/workspace/scratch/girtas-final-actual-quality-v04/private-image-ledger-history-immutable-index.json')),'sha256':sha(Path('/workspace/scratch/girtas-final-actual-quality-v04/private-image-ledger-history-immutable-index.json'))},'v03_private_image_ledger':stablecert['private_encoded_image_ledger']},'quality_scope':'Independent strict unique-tier actual selected TRES/profile model/gear/direction/anatomy/motion/loop-entry-exit/contact3/hit recovery/death5/physical scale-footing review. Stable43 directly read by v03 and final4 directly read by v04 and NErun read by fresh independent reviewer; exact original sourceRGBA/region/margin/perposeC/root/sourceSHA/timing/effectiveprofile/script equality checked for every track before aggregation. Private still reconstructions use PIL actual resource data and are not Godot screenshots. No source editing, bbox fitting, forced flatbootY/idlefootdepth or impossible hiddenbone metrology. Selected revised4 source supersedes failedold4 without deleting history.','actual_default_Main_status':'Separate root actual default Main / production connection validation required; not claimed by this quality certificate.','actor_approved':False,'completed_added':0,'detailed_completed':False,'counts_changed':False,'main_chat_image_attachments':0}
    p=B/f'girtas-{target_revision}-independent-quality-48tracks288poses-PRODUCTION-BINDING-DRAFT.json';write(p,out);return {'path':str(p),'sha256':sha(p),'equivalence_path':str(tp),'equivalence_sha256':sha(tp)}

if __name__=='__main__':
    print(json.dumps(assemble(sys.argv[1],sys.argv[2:])))
