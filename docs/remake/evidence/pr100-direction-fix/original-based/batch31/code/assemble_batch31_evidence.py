#!/usr/bin/env python3
"""Prepare durable batch31 evidence only after root's explicit visual gate.

This script is NOT invoked by its author. It never updates completion numbers,
imports artwork, edits production code, or invokes Git. Root chooses a fresh
output directory after the final actual Main 112-phase independent review.
Canonical base runs are main-batch31/headless and main-batch31/render.
"""
from pathlib import Path
from PIL import Image
import argparse, hashlib, json, shutil, zipfile

COMPASS = ['E','SE','S','SW','W','NW','N','NE']
SLUG = 'black-rabbit-girl-transform328'
FOLDER = 'black_rabbit_girl_transform328'
MAX_PART = 85 * 1024 * 1024  # Strictly below the requested90MiB/file limit.
REPRESENTATIVES = [
    'authored-S-idle-0.png', 'authored-E-walk-0.png',
    'authored-S-attack-1.png', 'authored-N-hit-0.png',
    'authored-S-death-2.png', 'attack-크로우-transform-E.png',
]


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()


def digest(data): return hashlib.sha256(data).hexdigest()
def read(path): return json.loads(Path(path).read_text())
def insist(condition, reason):
    if not condition: raise ValueError(reason)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path('/workspace/twilight'))
    parser.add_argument('--base-main', type=Path, default=Path('/workspace/scratch/pr100-continuation/main-batch31'))
    parser.add_argument('--temporal-main', type=Path, required=True, help='Fresh final clear root GL run, never the rejected first run')
    parser.add_argument('--root-review-json', type=Path, required=True)
    parser.add_argument('--portable', type=Path, default=Path('/workspace/scratch/pr100-continuation/rabbit328-portable'))
    parser.add_argument('--rejected-temporal', type=Path, default=Path('/workspace/scratch/pr100-continuation/main31-temporal-root-render'))
    parser.add_argument('--output', type=Path, required=True, help='Fresh explicit output directory; no existing files may be overwritten')
    args = parser.parse_args()
    repo=args.repo.resolve(); base=args.base_main.resolve(); final=args.temporal_main.resolve(); out=args.output.resolve()
    insist(not out.exists() and not out.is_symlink(), 'Use an entirely fresh evidence output directory')
    insist(final != args.rejected_temporal.resolve(), 'The first HUD-occluded temporal run cannot be packaged as final clear evidence')
    validator=repo/'tests/original_based_transform_temporal_main_test.gd'
    review=read(args.root_review_json)
    casefile=final/'report-cases'/f'{SLUG}.json'
    temporal_case=read(casefile); temporal=temporal_case['transform_temporal']; final_summary=read(final/'report.json'); invocation=read(final/'invocation.json')
    insist(not temporal_case['failures'] and not final_summary['failures'] and invocation['returncode']==0, 'Final temporal actual Main run must pass')
    insist(invocation['validator_unchanged'] is True and sha(validator)==invocation['validator_sha256'], 'Final actual Main must use unchanged frozen validator')
    insist(temporal['native_phases']==112==temporal['rendered_native_phases'] and len(temporal['roles'])==40, 'Final actual Main must cover all112native phases/40roles')
    insist(temporal['production_HUD_notice_empty_before_pause'] is True and temporal['HUD_hidden_or_modified'] is False, 'Final actual Main notice must expire naturally without HUD modification')
    insist(temporal['camera_smoothing_reset_after_each_role_relocation'] is True, 'Final frame0 camera must reset through public methods')
    insist(temporal['stats_before']==temporal['stats_after'], 'Final temporal profile/stats/HP/inventory must match before/after')
    insist(review.get('all112_wholebody_unoccluded') is True and review.get('static112_and_gameplay56_reviewed') is True, 'Root must separately review all112clear temporal and112static+56gameplay captures')
    insist(review.get('native_phases')==112 and review.get('directions')==COMPASS, 'Root review must identify all8directions/112native phases')
    insist(review.get('temporal_report_sha256')==sha(casefile) and review.get('validator_sha256')==sha(validator), 'Root visual review must bind exact final report/validator SHA')

    # Preflight every base report and capture before creating the output tree.
    base_reports={}; base_files={}
    for mode in ['headless','render']:
        summary=read(base/mode/'report.json'); case=read(base/mode/'report-cases'/f'{SLUG}.json')
        insist(summary['failures']==[] and case['failures']==[] and len(summary['cases'])==1, 'Canonical base Main must pass independently')
        insist(len(case['player'])==8 and len(case['incoming'])==8 and len(case['monster'])==8, 'Canonical actual input/HP/AI eight-direction checks required')
        insist(case['lifecycle']['manual_pickup'] is True and len(case['pose_samples'])==112, 'Canonical real drop/manualpickup/static112 evidence required')
        insist(all(entry['death_frames']==[0,1,2] for entry in case['incoming']), 'All8actual real-clock death VFX phases required')
        base_reports[mode]={'summary':summary,'case':case}
    caproot=base/'render/captures'/SLUG
    paths=sorted(caproot.glob('*.png'))
    insist(len(paths)==168 and {p.name for p in paths}==set(base_reports['render']['case']['screenshots']), 'Canonical rendered Main must contain exactly112static+56actual screenshots')
    static=[p for p in paths if p.name.startswith('authored-')]; actual=[p for p in paths if not p.name.startswith('authored-')]
    insist(len(static)==112 and len(actual)==56, 'Canonical static/gameplay split mismatch')
    for p in paths:
        with Image.open(p) as image: insist(image.size==(1280,720), 'Base capture must retain actual full viewport: '+str(p))
        base_files[p.name]={'source':str(p),'sha256':sha(p),'bytes':p.stat().st_size,'full_viewport_size':[1280,720],
            'scope':'direct authored static sampling' if p.name.startswith('authored-') else 'inherited real input/weapon/controlled incoming HP/real death clock/AI',
            'preservation':'unmodified representative PNG' if p.name in REPRESENTATIVES else 'SHA only; not claimed recoverable from this package'}
    insist(all(name in base_files for name in REPRESENTATIVES), 'All6representative full viewports required')

    # Temporal capture bytes are fully preserved, independently SHA-verified.
    temporal_members=[]; phase_tokens=set(); full_names=set()
    for role in temporal['roles']:
        captures=sorted(role['captures'], key=lambda e:e['frame'])
        insist(len(captures)==role['native_frames'], 'Every role phase must have one actual post-draw PNG')
        for evidence in captures:
            p=Path(evidence['path']); insist(sha(p)==evidence['sha256'], 'Final temporal capture SHA mismatch: '+str(p))
            insist(evidence['animation']==role['expected_key'], 'Transform captures use animation, not normal-helper resolved_key')
            token=(role['direction'],role['role'],evidence['frame']);insist(token not in phase_tokens, 'Repeated native phase');phase_tokens.add(token)
            with Image.open(p) as image: insist(image.size==(704,640), 'Temporal PNG must retain full704x640 review crop')
            temporal_members.append((p,'captures/'+SLUG+'/'+p.name, {'direction':role['compass'],'role':role['role'],'phase':evidence['frame'],
                'animation':evidence['animation'],'frame_token':evidence['frame_token'],'simulation_seconds':evidence['simulation_seconds'],
                'render_frame':evidence['render_frame'],'scope':'120Hz QA-clocked production-controller visual playback, not wall-performance/real AI damage'}))
            if 'full_viewport' in evidence:
                full=evidence['full_viewport'];f=Path(full['path']);insist(sha(f)==full['sha256'], 'Final full viewport SHA mismatch')
                with Image.open(f) as image: insist(image.size==(1280,720), 'Temporal full viewport must be unmodified actual1280x720')
                insist(f.name not in full_names,'Repeated full viewport');full_names.add(f.name)
                temporal_members.append((f,'full-viewports/'+f.name, {'scope':'unmodified actual full Main viewport'}))
    insist(len(phase_tokens)==112 and len(full_names)==3, 'Final requires112phase crops plus3full viewports')
    matrix_index=read(final/'review-matrices/matrix-index.json')
    insist(matrix_index['source_report_sha256']==sha(casefile) and matrix_index['actual_captures']==112 and len(matrix_index['matrices'])==8, 'Final review matrices must bind exact final report/all112')
    for matrix in matrix_index['matrices']:
        p=Path(matrix['matrix']);insist(sha(p)==matrix['sha256'], 'Final contact matrix SHA mismatch')
        temporal_members.append((p,'review-matrices/'+p.name,{'scope':'derived entire704x640 uniformly0.5 diagnostic matrix; original PNG unchanged'}))

    # Verify all48 production source PNGs recover from WIP02+03+04compact+05.
    portable=args.portable.resolve(); wip04=read(portable/'rabbit328-wip-04-preband-compact-archive-index.json');wip05=read(portable/'rabbit328-wip-05-bandfixed-archive-index.json')
    current=repo/'docs/remake/evidence/pr100-direction-fix/original-based/resumed-wip/rabbit328-current'
    required=wip05['required_prior_parts']+[{'name':Path(p['path']).name,'sha256':p['sha256'],'bytes':p['bytes']} for p in wip05['parts']]
    archives=[]; archive_handles=[]; archive_members={}
    for record in required:
        name=record['name']; alternatives=[current/name,portable/name];p=next((p for p in alternatives if p.is_file() and sha(p)==record['sha256']),None)
        insist(p is not None and p.stat().st_size==record['bytes'] and p.stat().st_size<90*1024*1024, 'Missing/corrupt/oversized required authoring archive '+name)
        z=zipfile.ZipFile(p);insist(z.testzip() is None, 'Broken authoring ZIP '+name);archive_handles.append(z)
        for member in z.namelist(): archive_members.setdefault(member,[]).append((z,name))
        archives.append({'name':name,'source':str(p),'bytes':p.stat().st_size,'sha256':record['sha256'],
            'durable_existing_repo_path':str(p.relative_to(repo)) if p.is_relative_to(repo) else None})
    recovered=[]
    try:
        for selected in wip05['selected48_source_recovery_proof']:
            hit=next((name for z,name in archive_members.get(selected['package_path'],[]) if digest(z.read(selected['package_path']))==selected['sha256']),None)
            insist(hit is not None,'Selected source not exactly recoverable '+selected['package_path'])
            recovered.append({'package_path':selected['package_path'],'source_sha256':selected['sha256'],'recoverable_from_archive':hit,'original_source_path':selected['original_absolute_path']})
    finally:
        for z in archive_handles: z.close()
    proofpath=repo/'assets/actors/eight_direction/original_based'/FOLDER/'provenance.json';proof=read(proofpath)
    insist(len(recovered)==48 and len(proof['source_files'])==48 and {p['source_sha256'] for p in recovered}=={s['sha256'] for s in proof['source_files']}, 'Exactly selected48 sourceSHA must equal production provenance')
    for source in proof['source_files']:
        insist(sha(repo/source['path'].removeprefix('res://'))==source['sha256'], 'Production source PNG differs from immutable authoring bytes')
    insist(wip05['candidate_sha256']=='bad1a2db11fd589d53e11158e43264142eb6961d06743b401c819d7415cf8fb2','Wrong selected trial06 source candidate')

    # All checks above are read-only. Only now create root's chosen fresh output.
    out.mkdir(parents=True); copied=[]
    def put(source,relative):
        destination=out/relative;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination)
        insist(sha(source)==sha(destination),'Byte copy verification failed '+relative)
        copied.append({'source':str(source),'path':relative,'bytes':destination.stat().st_size,'sha256':sha(destination)})
    def dump(relative,value):
        destination=out/relative;destination.parent.mkdir(parents=True,exist_ok=True);destination.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
    for mode in ['headless','render']:
        for name in ['report.json','engine.log']:put(base/mode/name,'base-main/'+mode+'/'+name)
        put(base/mode/'report-cases'/f'{SLUG}.json','base-main/'+mode+'/case.json')
    dump('base-main/all168-full-viewport-SHA256.json',{'static_count':112,'actual_gameplay_count':56,'raw_full_viewport_images_changed':False,'representative_full_pngs':6,'captures':base_files})
    for name in REPRESENTATIVES:put(caproot/name,'base-main/full-viewport-representatives/'+name)
    for name in ['report.json','invocation.json','engine.log']:put(final/name,'temporal-main/'+name)
    put(casefile,'temporal-main/case.json');put(validator,'temporal-main/validator.gd');put(final/'review-matrices/matrix-index.json','temporal-main/review-matrices-source-index.json')
    put(args.root_review_json,'root-independent-Main-review.json');put(proofpath,'source-binding/production-provenance.json')
    put(repo/'tests/fixtures/pr100_transform_batch31.json','code/pr100_transform_batch31.json');put(Path(__file__),'code/assemble_batch31_evidence.py')
    builder=Path(__file__).parent/'build_transform_temporal_matrices.py'
    if builder.is_file():put(builder,'code/build_transform_temporal_matrices.py')
    part_records=[]; groups=[]; group=[];total=0
    for p,member,meta in temporal_members:
        budget=p.stat().st_size+len(member.encode())+256
        insist(budget<MAX_PART,'Single temporal evidence member exceeds part limit')
        if group and total+budget>MAX_PART:groups.append(group);group=[];total=0
        group.append((p,member,meta));total+=budget
    if group:groups.append(group)
    for index,group in enumerate(groups,1):
        relative=f'temporal-main/controller-main-evidence-part{index:02d}.zip';path=out/relative;entries=[]
        with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_STORED) as z:
            for p,name,metadata in group:
                info=zipfile.ZipInfo(name,(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_STORED;info.external_attr=0o644<<16
                raw=p.read_bytes();z.writestr(info,raw);entries.append({'member':name,'source':str(p),'bytes':len(raw),'sha256':digest(raw),**metadata})
        with zipfile.ZipFile(path) as z:
            insist(z.testzip() is None,'Final temporal ZIP integrity')
            for e in entries:insist(digest(z.read(e['member']))==e['sha256'],'Final temporal ZIP member SHA')
        insist(path.stat().st_size<90*1024*1024,'Final temporal ZIP exceeds requested90MiB')
        part_records.append({'path':relative,'bytes':path.stat().st_size,'sha256':sha(path),'members':entries})
    dump('temporal-main/archive-index.json',{'scope':temporal['scope'],'validator_sha256':sha(validator),'native_phase_crops':112,'unmodified_full_viewports':3,'derived_direction_matrices':8,'parts':part_records,'completed_added':0})
    for archive in archives:
        if archive['durable_existing_repo_path'] is None:put(Path(archive['source']),'authoring-history/'+archive['name'])
    put(portable/'rabbit328-wip-04-preband-compact-archive-index.json','authoring-history/wip04-index.json')
    put(portable/'rabbit328-wip-05-bandfixed-archive-index.json','authoring-history/wip05-index.json')
    dump('authoring-history/selected48-recoverability.json',{'selected48_production_source_SHA_verified':True,'selected_sources':recovered,'required_archives':archives,'all_required_archives_earlier_repo_or_this_package':True,'production_source_pixels_changed':False})

    # Preserve rejected first temporal proof/validator/HUD overlap honestly.
    rejected=args.rejected_temporal.resolve()
    if rejected.is_dir():
        for name in ['report.json','invocation.json','engine.log']:put(rejected/name,'rejected-first-temporal/'+name)
        put(rejected/'report-cases'/f'{SLUG}.json','rejected-first-temporal/case.json')
        for name in ['temporal-S-walk-0.png']:
            put(rejected/'captures'/SLUG/name,'rejected-first-temporal/'+name)
        prior=Path(__file__).parent/'frozen-8c19042a-root-first-render.gd'
        if prior.is_file():put(prior,'rejected-first-temporal/validator.gd')
        dump('rejected-first-temporal/reason.json',{'automated_test_passed':True,'all112_wholly_unoccluded_visual_PASS':False,'reason':'S walk0 actual Main HUD equip notice overlaps waist/skirt while whole Main paused; early role relocation camera stale','preservation':'Original prior run/captures remain untouched in scratch; this package retains reports/log/source and exact failing actual capture','fixed_only_in_additive_validator':'Production2.6s HUD notice expires through realprocess before pause; public camera reset after each role relocation','completed_added':0})
    dump('source-path-map.json',{'reports_preserved_byte_for_byte':True,'absolute_scratch_paths_in_reports_retained':True,'files':copied,'temporal_member_resolution':'temporal-main/archive-index.json','selected48_resolution':'authoring-history/selected48-recoverability.json'})
    dump('evidence-scope.json',{'base_static112':'Direct original authored phase sampling; not claimed continuous controller playback','base_actual56':'Inherited actual8direction input/attack/controlled incoming HP/realclock death VFX/AI screenshots. Drop/manualpickup separately asserted in canonical case reports.','temporal112':'Actual Main equipped player, fresh production controller perrole/direction,120Hz QA-clock public advance/apply; held actualdraw frame atomic across PNG I/O. No direct texture/animation/frame assignments.','scope_limit':'No wallperformance, actualAIorHP/loot claim from QA-clockedvisualstage. Inherited gameplay checks unchanged and separate. Android actualdevice unverified. CI and final completion count gates owned byroot.','package_updates_completion':False,'completed_added':0})
    files=[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(out.rglob('*')) if p.is_file()]
    (out/'SHA256SUMS').write_text(''.join(f"{e['sha256']}  {e['path']}\n" for e in files))
    dump('package-manifest.json',{'status':'ROOT_REVIEW_BOUND_EVIDENCE_PACKAGE_ONLY','validator_sha256':sha(validator),'temporal_report_sha256':sha(casefile),'source48_recoverable':True,'base_static_fullviewport_SHA':112,'base_actual_fullviewport_SHA':56,'base_fullviewport_PNG_representatives':6,'temporal_native_crops':112,'temporal_fullviewports':3,'temporal_direction_matrices':8,'completed_added':0,'files':files,'sha256sums_sha256':sha(out/'SHA256SUMS')})
    print(json.dumps({'output':str(out),'files':len(files)+2,'bytes':sum(p.stat().st_size for p in out.rglob('*') if p.is_file()),'temporal_parts':[{'path':p['path'],'bytes':p['bytes'],'sha256':p['sha256']} for p in part_records],'completed_added':0},indent=2))


if __name__=='__main__':main()
