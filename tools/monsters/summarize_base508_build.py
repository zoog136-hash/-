"""Keep source catalog, build readiness and actual placements separately reviewable."""
import argparse,collections,gzip,json
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
for name in('catalog','requests','pack','output'):p.add_argument('--'+name,type=Path,required=True)
a=p.parse_args();catalog=json.load(gzip.open(a.catalog));req=json.load(gzip.open(a.requests));pack=json.loads(a.pack.read_text());files={r['name']:r for r in req['files']};models={};classes={}
for sid,m in catalog['models'].items():
 missing=[n for n in m['original_members']if 'available_library_package'not in files[n]]
 if sid in pack['models']:status='compiled'
 elif sid in pack['model_failures']:status='core_action_compile_failed'
 elif m['reference_issues']:status='source_reference_unresolved'
 elif m['missing_standard_roles']:status='source_has_no_standard_five_role_contract'
 elif not m['original_members']:status='source_member_graph_empty'
 elif missing:status='known_original_members_not_supplied'
 else:status='eligible_not_compiled'
 models[sid]={'status':status,'reference_issues':m['reference_issues'],'missing_standard_roles':m['missing_standard_roles'],'missing_known_members':missing,'compile_error':pack['model_failures'].get(sid),'source_npc_ids':m['source_npc_ids']}
for r in catalog['rows']:
 nid=str(r['npc_id']);sid=str(r['sprite_id'])
 if nid in pack['records']:status='source_factory_and_view_available'
 elif r['source_TestNPC']:status='test_npc_not_activated'
 elif r['source_kind']not in('source_ui_boss_npc','source_attackable_monster_actor'):status='noncombat_or_component_not_activated'
 elif not r['source_world_context_count']:status='no_authoritative_world_spawn_context'
 else:status=models.get(sid,{'status':'missing_model'})['status']
 classes[nid]={'status':status,'source_sprite_id':r['sprite_id'],'source_kind':r['source_kind']}
optional={}
for sid,ref in pack['models'].items():
 model=json.loads((a.pack.parent/ref['tracks_ref']).read_text());issues=model.get('source_action_issues',{})
 if issues:optional[sid]=issues
result={'optional_source_action_issues':optional,'models_with_optional_action_issues':len(optional),'source_snapshot':'base508','catalog_classes':len(catalog['rows']),'source_models':len(models),'model_status_counts':dict(collections.Counter(x['status']for x in models.values())),'class_status_counts':dict(collections.Counter(x['status']for x in classes.values())),'compiled_classes':len(pack['records']),'compiled_models':len(pack['models']),'source_context_pairs':sum(len(x['source_contexts'])for x in pack['records'].values()),'native_geographic_instances':0,'existing_guarded_host_ports':14,'visual_inspection_performed':False,'device_validation_performed':False,'models':models,'classes':classes};a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items()if k not in('models','classes')},ensure_ascii=False))
