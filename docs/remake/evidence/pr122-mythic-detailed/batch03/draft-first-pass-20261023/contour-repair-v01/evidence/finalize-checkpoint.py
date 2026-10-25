import collections,hashlib,json,pathlib,shutil,subprocess,sys
r=pathlib.Path('/workspace/twilight'); s=pathlib.Path('/workspace/scratch/pr122-contour-repair-20261023'); b=r/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023'; out=b/'contour-repair-v01'; ev=out/'evidence'
def load(p):return json.loads(p.read_text())
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
summary=load(s/'integration-summary.json');stage=load(s/'staging-summary.json');rows=load(s/'contour-assembly-results.json')
assert summary['status']=='PASS' and len(rows)==29 and stage['added_contour_clips']==29
for p in s.iterdir():
 if p.suffix not in ('.json','.py','.log') or p.name=='finalize.log':continue
 q=ev/p.name
 if q.exists():assert q.read_bytes()==p.read_bytes(),str(q)
 else:shutil.copyfile(p,q)
old=load(b/'spacing-repair-v01/remaining-errors.json'); repaired={x['original_source'] for x in rows};remaining=[x for x in old['source_holds'] if x['source'] not in repaired]
assert len(remaining)==290 and len(repaired)==29
regpath=r/'data/pr122_native_locomotion_staging.json';mpath=r/'docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json';reg=load(regpath);manifest=load(mpath);before=json.loads(subprocess.check_output(['git','show','HEAD:data/pr122_native_locomotion_staging.json'],cwd=r));keys=set(stage['keys']);oldtracks=0
for key,actor in before['actors'].items():
 if key not in keys:assert actor==reg['actors'][key],f'Unrelated actor changed: {key}'
 now={x['animation']:x for x in reg['actors'][key]['tracks']}
 for t in actor['tracks']:
  assert all(now[t['animation']][f]==t[f] for f in ('source','source_sha256','texture','geometry'))
  if key not in ('transform:393','transform:267','transform:413'):oldtracks+=1
assert oldtracks==206
for row in rows:
 assert sha(r/row['original_source'])==row['original_source_sha256'] and sha(r/row['source'])==row['sha256']
 assert row['original_RGBA_ownership']['missing']==row['original_RGBA_ownership']['duplicate']==0
 records=[x for x in manifest['raw_images'] if x['source']==row['source']];assert len(records)==1
 for dep in records[0]['authoring_dependencies']:assert sha(r/dep['path'])==dep['sha256'],dep['path']
for key in keys:
 a=reg['actors'][key]
 for field in ('frames','native_profile'):assert sha(r/a[field].removeprefix('res://'))==a[field+'_sha256']
 for t in a['tracks']:
  assert sha(r/t['source'])==t['source_sha256'];assert sha(r/t['texture'])==t['source_sha256']
 a['verification']=dict(source_sha256_and_saved_geometry='PASS',distinct_native_poses=a['native_pose_count'],spriteframes_parse_and_all_frame_cycles='PASS',actual_Main_and_Player_candidate_injection='PASS',production_default_catalog_playback='NOT_RUN',visual_approval='NOT_RUN',completed_added=0,frames_sha256=a['frames_sha256'],evidence=str((ev/'integration-summary.json').relative_to(r)))
write(regpath,reg)
sys.path.insert(0,str(r/'tools'));import pr122_native_production_approvals as approvals
state=approvals.load_state(r,manifest=manifest,register=reg);state.assert_preserved(manifest,reg)
write(out/'remaining-errors.json',dict(schema='pr122-contour-repair-remaining-v1',previous_source_holds=319,repaired_source_clips=29,remaining_source_holds=290,source_holds=remaining,generation_holds=old['generation_holds'],new_boundary_variants=old['new_boundary_variants'],contour_candidate_secondary_holds=[dict(key=x['key'],direction=x['direction'],role=x['role'],unclassified_soft_residue_pixels=x['unclassified_soft_residue_pixels'],max_alpha=x['unclassified_soft_residue_max_alpha'],reason='Unclassified soft source layer preserved separately; semantic/visual approval NOT_RUN') for x in rows],method_stop='32 alpha-connected foreign contours and one ambiguous foreground owner remain HOLD; do not cut merged art or guess ownership',final_quality_approvals_added=0,visual_quality='NOT_REVIEWED'))
result=dict(schema='pr122-contour-repair-summary-v1',date='2026-10-23 UTC',cause='Disjoint alpha contours had intersecting rectangular crop boxes containing adjacent-pose ink',actual_fix='Reuse unchanged foreground ownership and reviewed-pose assembler to isolate exact contour RGBA layers and rigidly translate them onto spaced cells',repaired_clips=29,reused_original_poses=174,frames_regenerated=0,normal_clips_preserved=206,new_final_approvals=0,approved_active_actors=2,unapproved_active_actors=17,primary_source_holds=290,missing_generation_holds=3,rendered_contour_nonzero_coverage='exactly_once',original_source_RGBA_storage_ownership=dict(missing=0,duplicate=0),soft_layer_review='29 unclassified alpha<=16 residue layers archived; not rendered or approved',main_player=summary,roles=dict(collections.Counter(x['role'] for x in rows)),code_changes=0,production_switches=0)
write(out/'summary.json',result)
resume=r/'docs/remake/TWILIGHT_PR122_RESUME_20261019.md';t=resume.read_text();marker='2026-10-23 contour repair v01:';assert marker not in t
resume.write_text(t+'\n'+marker+' Repaired29 disjoint-contour clips with exact alpha contour isolation and wider rigid-translation packing through the existing assembler; no code changes. Original RGBA preserved across six pose layers and an explicit unclassified soft-residue layer:0 missing/duplicate. Rendered contour texels covered exactly once. Soft alpha<=16 residue remains archived/unclassified and unrendered, so final visual approval HOLD. Reused174 original poses;0 regenerated frames. Prior206 normal candidate clips and protected393/267/413 records preserved. Actual Main/Player candidate integration PASS:9 actors,152 clips,48 death input cases; no production catalog switch. Remaining290 primary source HOLD +3 missing-generation HOLD;29 repaired candidates still require visual/semantic approval. Final approvals added0; active approved2/19. Current lists: draft-first-pass-20261023/contour-repair-v01/remaining-errors.json. No CI, previews or chat images.\n')
print(json.dumps(dict(status='PASS',repaired=29,primary_remaining=290,normal_preserved=oldtracks,approvals_added=0,roles=result['roles'])))
