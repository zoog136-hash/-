#!/usr/bin/env python3
"""Authorized evidence-only additive packaging; never counts/data/assets/Git."""
from pathlib import Path
import json,hashlib,zipfile,shutil,datetime
R=Path('/workspace/twilight');S=Path('/workspace/scratch/pr100-continuation');B=R/'docs/remake/evidence/pr100-direction-fix/original-based/batch29';A=B/'hell_cougar_monster_boss_v3';W=S/'batch29-evidence-assembly';MAX=80_000_000;SLUG='hell-cougar-monster-boss';V3=S/'temporal-batch29-v3-render';C3=S/'temporal-batch29-v3-contacts';V2=S/'temporal-batch29-v2-render';C2=S/'temporal-batch29-v2-contacts'
def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as f:
  for x in iter(lambda:f.read(1024*1024),b''):h.update(x)
 return h.hexdigest()
def digest(x):return hashlib.sha256(x).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def require(ok,msg):
 if not ok:raise ValueError(msg)
def dump(p,d):
 require(not p.exists(),'Refuse existing evidence output '+str(p));p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
old=A/'authoring-history.zip';require(old.is_file(),'Expected original authoring ZIP');oldsha=sha(old);oldbytes=old.stat().st_size;require(oldbytes==103791517,'Unexpected original authoring ZIP size')
canonical={str(p.relative_to(B)):sha(p) for p in B.rglob('*') if p.is_file() and p!=old}
require(not (A/'authoring-history-part01.zip').exists() and not (B/'temporal-main').exists() and not (B/'rejected-versions').exists(),'Fresh evidence extension paths required')
summary=read(V3/'summary.json');case=read(V3/'summary-cases'/f'{SLUG}.json');inv=read(V3/'invocation.json');independent=read(S/'hell-cougar-v3-independent-visual-review-iguana.json')
require(summary['failures']==[] and case['failures']==[] and inv['returncode']==0 and inv['validator_unchanged_during_run'] is True,'Final v3 temporal automated proof must pass unchanged')
require(sha(V3/'validator.gd')==inv['validator_sha256'],'Final frozen code SHA')
require(independent['failures']==[] and independent['all104_native_capture_sha_verified'] is True and independent['source_summary_sha256']==sha(V3/'summary.json'),'Independent review must bind exact v3')
contact=read(C3/'temporal-contact-manifest.json');require(contact['source_summary_sha256']==sha(V3/'summary.json') and len(contact['contacts'])==8,'Final8contact manifest binding')
# Everything until write_archives() below is read-only preflight.
with zipfile.ZipFile(old) as z:
 require(z.testzip() is None,'Original authoring ZIP integrity');infos=z.infolist();require(len(infos)==len(set(z.namelist())),'Repeated ZIP member name');history=[]
 for info in infos:
  require(not info.is_dir(),'Unexpected original directory entry');raw=z.read(info.filename);history.append({'member':info.filename,'bytes':len(raw),'sha256':digest(raw)})
original_map=read(A/'immutable-artwork-map.json');require(len(original_map)==18,'Expected18selected immutable PNGs');source_recovery=[]
for selected in original_map:
 matches=[v for v in history if v['sha256']==selected['sha256']]
 require(sha(R/selected['production_path'])==selected['sha256'],'Production source differs from frozen map')
 local_sources=[p for p in (S/'hell-cougar-authoring').rglob(selected['source_file']) if p.is_file() and sha(p)==selected['sha256']]
 require(len(local_sources)==1,'Selected original own source path must resolve uniquely')
 source_recovery.append({**selected,'original_authoring_relative_path':str(local_sources[0].relative_to(S/'hell-cougar-authoring')),'recoverable_archive_members':[v['member'] for v in matches],
  'recovery_basis':'history ZIP member' if matches else 'selected source intentionally excluded from history because existing production PNG is the exact unchanged original byte copy',
  'existing_repository_source_recovery_path':selected['production_path']})
# Generic raw-byte ZIP splitter, keeping every member byte SHA and fresh outputs.
pathmap=[]
def copy(src,relative):
 src=Path(src);dst=B/relative;require(src.is_file() and not dst.exists(),'Fresh copy destination/source required '+str(dst));dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst);require(sha(src)==sha(dst),'Exact evidence copy');pathmap.append({'source':str(src),'packaged_path':relative,'bytes':dst.stat().st_size,'sha256':sha(dst)})
def write_archives(entries,prefix):
 groups=[];group=[];total=0
 for name,loader,nbytes,expected,metadata in entries:
  size=nbytes+len(name.encode())*2+256;require(size<MAX,'Single ZIP member too large')
  if group and total+size>MAX:groups.append(group);group=[];total=0
  group.append((name,loader,nbytes,expected,metadata));total+=size
 if group:groups.append(group)
 parts=[]
 for index,group in enumerate(groups,1):
  rel=f'{prefix}-part{index:02d}.zip';p=B/rel;require(not p.exists(),'Refuse existing ZIP part');p.parent.mkdir(parents=True,exist_ok=True);members=[]
  with zipfile.ZipFile(p,'w',compression=zipfile.ZIP_STORED) as target:
   for name,loader,nbytes,expected,metadata in group:
    raw=loader();require(len(raw)==nbytes and digest(raw)==expected,'Source member drift '+name);info=zipfile.ZipInfo(name,(1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_STORED;info.external_attr=0o644<<16;target.writestr(info,raw);members.append({'member':name,'bytes':nbytes,'sha256':expected,**metadata})
  require(p.stat().st_size<90_000_000,'ZIP part must be below90MB')
  with zipfile.ZipFile(p) as target:
   require(target.testzip() is None,'ZIP part CRC failure')
   for member in members:require(digest(target.read(member['member']))==member['sha256'],'ZIP part member SHA failure')
  parts.append({'path':rel,'bytes':p.stat().st_size,'sha256':sha(p),'members':members})
 return parts
with zipfile.ZipFile(old) as sourcezip:
 history_entries=[(v['member'],lambda n=v['member']:sourcezip.read(n),v['bytes'],v['sha256'],{}) for v in history]
 history_parts=write_archives(history_entries,'hell_cougar_monster_boss_v3/authoring-history')
require(sum(len(p['members']) for p in history_parts)==len(history),'All original ZIP members must survive')
member_to_part={m['member']:p['path'] for p in history_parts for m in p['members']}
for source in source_recovery:source['recoverable_parts']=sorted({member_to_part[m] for m in source['recoverable_archive_members']})
preserved=W/'original-authoring-history-103791517.zip';require(not preserved.exists(),'Fresh original ZIP preservation path');shutil.move(old,preserved);require(sha(preserved)==oldsha and preserved.stat().st_size==oldbytes,'Original ZIP must remain byte-exact in scratch')
dump(A/'authoring-history-index.json',{'scope':'Lossless container split only; original member content unchanged','original_archive':{'prior_repository_path':str(old.relative_to(R)),'bytes':oldbytes,'sha256':oldsha,'preserved_byte_exact_scratch_path':str(preserved)},'original_member_count':len(history),'all_original_member_SHA_verified':True,'parts':history_parts,'selected18_recoverability':source_recovery,'selected18_excluded_from_original_history_recover_via_existing_repository_production_PNG':sum(not s['recoverable_archive_members'] for s in source_recovery),'source_PNG_pixels_changed':False,'completed_added':0})
# All104 actual production-controller crops +3fullviewports +8derivedcontacts.
temporal_entries=[];seen=set()
def add_temporal(path,name,metadata):
 p=Path(path);rawsha=sha(p);temporal_entries.append((name,p.read_bytes,p.stat().st_size,rawsha,{'source':str(p),**metadata}));return rawsha
for role in case['roles']:
 require(len(role['captures'])==role['native_frames'],'Every temporal native phase capture required')
 for capture in role['captures']:
  key=(role['direction'],role['role'],capture['frame']);require(key not in seen,'Duplicate temporal native phase');seen.add(key)
  require(sha(capture['path'])==capture['sha256'],'Final actual crop drift')
  add_temporal(capture['path'],'run/captures/'+SLUG+'/'+Path(capture['path']).name,{'direction':role['compass'],'role':role['role'],'phase':capture['frame'],'simulation_seconds':capture['simulation_seconds'],'wall_microseconds':capture['wall_microseconds'],'resolved_key':capture['resolved_key'],'frame_token':capture['frame_token']})
require(len(seen)==104,'Expected104native phase crops')
full=sorted((V3/'captures'/SLUG).glob('viewport-*.png'));require(len(full)==3,'Expected3unmodified full viewports')
for p in full:add_temporal(p,'run/full-viewports/'+p.name,{'scope':'unmodified actual Main fullviewport'})
for name in ['summary.json','invocation.json','validator.gd','engine.log']:add_temporal(V3/name,'run/'+name,{'scope':'frozen actual run code/log/report'})
add_temporal(V3/'summary-cases'/f'{SLUG}.json','run/summary-cases/'+SLUG+'.json',{'scope':'full120Hz controller step/sample report'})
add_temporal(C3/'temporal-contact-manifest.json','run/temporal-contact-manifest.json',{'scope':'actual crop to derived contact path/SHA map'})
for c in contact['contacts']:
 require(sha(c['path'])==c['sha256'],'Final contact drift')
 for source in c['sources']:require(sha(source['capture'])==source['sha256'],'Contact source drift')
 add_temporal(c['path'],'contacts/'+c['direction']+'-temporal-contact.png',{'direction':c['direction'],'scope':'704x640 whole actual crop uniformly352x320; no source PNG edits'})
temporal_parts=write_archives(temporal_entries,'temporal-main/controller-main-evidence')
copy(S/'hell-cougar-v3-independent-visual-review-iguana.json','temporal-main/independent-iguana-review.json')
dump(B/'temporal-main/evidence-index.json',{'status':'ROOT_AND_INDEPENDENT_REVIEW_PASS_RECORDED_NOT_REPERFORMED_BY_PACKAGER','review_basis':'Parent root authorized packaging after root actualMain review and independent Iguana all8temporal review. This packaging operation independently verifies report/code/capture/sourceSHA, not a new visual review.','scope':summary['scope'],'source_summary_sha256':sha(V3/'summary.json'),'source_case_sha256':sha(V3/'summary-cases'/f'{SLUG}.json'),'validator_sha256':sha(V3/'validator.gd'),'automated_checks':summary['checks'],'native_crops':104,'full_viewports':3,'derived_contacts':8,'archive_parts':temporal_parts,'independent_review':'independent-iguana-review.json','no_performance_AI_HP_loot_claim_from_QAclocked_stage':True,'completed_added':0})
# Historical failures: exact available reports/runners/logs + all capture SHA;
# selected failing representatives only. Never pretend failed visuals passed.
rejected_inventory=[]
for srcname,tag in [('main-batch29-first-palette-rejected','v1-palette'),('main-batch29-v2-coregrowth-rejected','v2-coregrowth')]:
 src=S/srcname
 for p in sorted(src.iterdir()):
  if p.is_file() and p.suffix in ['.json','.log','.py','.gd']:copy(p,'rejected-versions/'+tag+'/run/'+p.name)
 for mode in ['headless','render']:
  for name in ['report.json','engine.log']:copy(src/mode/name,'rejected-versions/'+tag+'/'+mode+'/'+name)
  for p in sorted((src/mode/'report-cases').glob('*.json')):copy(p,'rejected-versions/'+tag+'/'+mode+'/report-cases/'+p.name)
  for p in sorted((src/mode/'captures').rglob('*.png')):
   rejected_inventory.append({'version':tag,'mode':mode,'source':str(p),'sha256':sha(p),'bytes':p.stat().st_size,'preservation':'hash_only_unless_separately_copied_representative'})
 representatives=['authored-N-walk-0.png','authored-NE-walk-0.png','authored-N-idle-0.png'] if tag=='v1-palette' else ['authored-N-attack-1.png','authored-N-idle-0.png']
 for name in representatives:
  p=src/'render/captures'/SLUG/name
  if p.is_file():copy(p,'rejected-versions/'+tag+'/representatives/'+name)
for name in ['summary.json','invocation.json','validator.gd','engine.log']:copy(V2/name,'rejected-versions/v2-temporal/run/'+name)
copy(V2/'summary-cases'/f'{SLUG}.json','rejected-versions/v2-temporal/run/summary-cases/'+SLUG+'.json')
copy(C2/'temporal-contact-manifest.json','rejected-versions/v2-temporal/temporal-contact-manifest.json')
for direction in ['W','NW','N','NE']:copy(C2/SLUG/(direction+'-temporal-contact.png'),'rejected-versions/v2-temporal/back4contacts/'+direction+'-temporal-contact.png')
for name in ['N-attack-1.png','NE-hit-0.png']:copy(V2/'captures'/SLUG/name,'rejected-versions/v2-temporal/failing-pose-representatives/'+name)
for p in sorted((V2/'captures').rglob('*.png')):rejected_inventory.append({'version':'v2-temporal','source':str(p),'sha256':sha(p),'bytes':p.stat().st_size,'preservation':'hash_only_unless_separately_copied_representative'})
copy(S/'hell-cougar-authoring/independent/rear-action-core-v2-independent-review.json','rejected-versions/v2-coregrowth/rear-action-core-independent-review.json')
dump(B/'rejected-versions/all-old-capture-SHA256.json',{'note':'All raw prior capture files retain exact SHA/size inventories; only explicit representative PNGs are included here. Historical raw authoring source PNGs are fully retained in the split authoring-history archive. No claim that every old actualMain capture is packaged/recoverable.','captures':rejected_inventory,'counts':{tag:sum(r['version']==tag for r in rejected_inventory) for tag in ['v1-palette','v2-coregrowth','v2-temporal']}})
dump(B/'rejected-versions/visual-failure-scope.json',{'v1-palette':'Automated headless/render passed but N/NEwalking brightergray than own black neutral/action source; visualHOLD.','v2-coregrowth':'Automated headless/render and120Hz temporal passed but W/NW/N/NE attack/hit core grew materially about1.4–1.5x; visualHOLD.','v3':'New whole-source rear20 preserves own charcoal panther identity and fixed skull/core; root/independent review PASS separately bound by exact reports.','historical_code_limit':'Exact rejected runner scripts and temporalvalidator snapshots are preserved. Rejected ordinary Main runs did not record immutable historical copies of every imported game/test dependency; no reconstruction claim.','all_old_authoring_raw_members_preserved':True,'completed_added':0})
# Required existing canonical evidence must remain byte-identical.
require(all((B/name).is_file() and sha(B/name)==h for name,h in canonical.items()),'Pre-existing canonical evidence changed')
copy(Path(__file__),'assembly-code/package_batch29_temporal_and_history.py')
dump(B/'evidence-source-path-map.json',{'source_reports_copied_byte_for_byte':True,'absolute_scratch_paths_retained_in_original_reports':True,'ordinary_copies':pathmap,'history_member_resolution':'hell_cougar_monster_boss_v3/authoring-history-index.json','v3_temporal_member_resolution':'temporal-main/evidence-index.json','prior_capture_hash_inventory':'rejected-versions/all-old-capture-SHA256.json','canonical_preexisting_SHA_unchanged':canonical})
new_files=[{'path':str(p.relative_to(B)),'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(B.rglob('*')) if p.is_file() and str(p.relative_to(B)) not in canonical]
dump(B/'evidence-assembly-manifest.json',{'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Authorized additive batch29 evidence packaging only','preexisting_canonical_reports_candidates_PNG_unchanged':True,'old_authoring_archive_original_preserved_in_scratch':str(preserved),'old_authoring_archive_sha256':oldsha,'original359authoring_members_SHA_verified':len(history)==359,'selected18_raw_source_bytes_recoverable':True,'v3_temporal104_crops_3full_8contacts_exact_SHA_verified':True,'root_existing_visual_approval_not_recreated_by_packager':True,'independent_iguana_review_preserved':True,'all_parts_below90millionbytes':True,'mutations_outside_batch29_evidence_and_scratch':False,'count_completion_profile_asset_map_workflow_git_actions':False,'completed_added':0,'new_files':new_files})
print(json.dumps({'path':str(B),'original_archive_preserved':str(preserved),'history_parts':[{k:v for k,v in p.items() if k!='members'} for p in history_parts],'temporal_parts':[{k:v for k,v in p.items() if k!='members'} for p in temporal_parts],'old_capture_SHA_count':len(rejected_inventory),'canonical_existing_files_preserved':len(canonical),'selected18source_recoverability_verified':True,'assembly_manifest_sha256':sha(B/'evidence-assembly-manifest.json'),'completed_added':0},indent=2))
