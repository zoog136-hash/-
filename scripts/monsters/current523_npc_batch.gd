extends RefCounted
## TWILIGHT host transaction, not a source-server spawn/ownership API.
## Preparation projects into an isolated catalog. No live configure/admission.
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const INPUT=preload("res://scripts/monsters/current523_npc_input_projection.gd")
const NPC_VIEW=preload("res://scripts/cards/current523_card_catalog.gd")
const CONTEXT=preload("res://scripts/monsters/base508_monster_context.gd")
const STATE=["content","indexes","source_mode","source_available","source_identity","source_model_sha256","admitted_source_identities","deferred_npc_inputs","source_status","error","environment_error","environment_revision","environment_model_sha256","_environment_inputs","_environment_tables","_environment_indexes","_actor_batch_revision"]
const NPC_WRITE=["content","indexes","source_model_sha256","admitted_source_identities","deferred_npc_inputs","error","source_status"]
var _catalog: WeakRef
var _field: WeakRef
var _world: WeakRef
var _population: WeakRef
var _before: Dictionary={}
var _after: Dictionary={}
var _prepared: Dictionary={}
var _selection: Dictionary={}
var _records: Array=[]
var _state: String="new"

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value
static func _snapshot(catalog: RefCounted) -> Dictionary:
	var result: Dictionary={}
	for key: String in STATE:result[key]=_copy(catalog.get(key))
	return result
static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"reason":reason,"catalog_changed":false,"spawn_authorized":false}
static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0
static func _sha(value: Variant) -> bool:
	return value is String and value.length()==64 and value.is_valid_hex_number(false)

static func _field_identity(field: RefCounted) -> Dictionary:
	if not is_instance_valid(field) or not field.has_method("source_geographic_contract"):return {}
	var geo: Variant=field.call("source_geographic_contract")
	var definition: Variant=field.get("definition");var data: Variant=field.get("data")
	if not geo is Dictionary or not definition is Dictionary or not data is Dictionary:return {}
	if geo.get("manifest_identity_verified")!=true or geo.get("source_snapshot")!=523 or not _integer(geo.get("native_land_id")) or int(geo.native_land_id)<0:return {}
	var land: Dictionary=SOURCE.row("Land",int(geo.native_land_id))
	if land.is_empty() or land!=geo.get("native_land") or not SOURCE.declared_exclusion("Land",land).is_empty() or land.get("AssetPath")!=geo.get("native_asset_path"):return {}
	if not _sha(geo.get("source_manifest_sha256")) or not _sha(geo.get("source_inventory_sha256")) or not _sha(geo.get("native_land_table_sha256")):return {}
	if not definition.get("map_id") is String or str(definition.map_id).is_empty() or data.get("map_id")!=definition.map_id or definition.get("source_map_id")!=land.ID or definition.get("source_asset_path")!=land.AssetPath or definition.get("source_manifest_sha256")!=geo.source_manifest_sha256:return {}
	return {"field_instance_id":field.get_instance_id(),"host_map_id":definition.map_id,"land":land.duplicate(true),"asset_path":land.AssetPath,"geographic_contract":geo.duplicate(true),"definition":definition.duplicate(true)}

static func _same_npc(value: Variant,raw: Dictionary) -> bool:
	# The existing card/NPC owner adds exact descriptor/archive metadata.
	# Accept only the raw row or that actual owner result, never arbitrary extras.
	return value is Dictionary and (value==raw or value==NPC_VIEW.npc(int(raw.ID)))

static func _exact_record(record: Dictionary,selection: Dictionary,catalog: RefCounted) -> bool:
	var id: Variant=record.get("source_m_npc_id")
	if not _integer(id) or int(id)<=0 or record.get("source_m_current523_final")!=true or record.get("source_m_definition_archive_sha256")!=SOURCE.SOURCE_SHA:return false
	var raw: Dictionary=SOURCE.row("NpcClass",int(id))
	if raw.is_empty() or not _same_npc(record.get("source_m_original"),raw) or not catalog.definition_eligible(raw):return false
	# Preserve every early-admission condition of project_actor_record().
	for field: String in ["ID","Sprite","DescId","HP","MP","AC","MR","Exp","Str","Dex","Con","Wis","Cha","Int"]:
		if not _integer(raw.get(field)):return false
	if int(raw.HP)<=0 or int(raw.MP)<0 or int(raw.MR)<0 or int(raw.Exp)<0:return false
	if record.get("source")!="lineagem_base508" or record.get("catalog_only")!=false or record.get("source_m_sprite_id")!=raw.Sprite:return false
	var category: Dictionary=SOURCE.row("NpcCategory",int(raw.Category))
	if category.get("Name")=="Citizen":return false
	if record.get("source_m_runtime_host_map")!=selection.host_map_id:return false
	if record.get("sourceId")!="lineagem_base508:npc:%d:spawn:%d:territory:%d" % [int(id),int(record.get("source_m_spawn_view_id",-1)),int(record.get("source_m_territory_link_id",-1))]:return false
	var context: Variant=record.get("source_m_context")
	if not context is Dictionary or not _same_npc(context.get("npc"),raw) or context.get("land")!=selection.land:return false
	for pair: Array in [["spawn_view","NpcSpawnPackNpcClassView"],["territory_link","NpcSpawnPackTerritory"],["territory","Territories"]]:
		var row: Variant=context.get(pair[0])
		if not row is Dictionary or not _integer(row.get("ID")) or SOURCE.row(pair[1],int(row.ID))!=row or not SOURCE.declared_exclusion(pair[1],row).is_empty():return false
	if context.spawn_view.get("ID")!=record.get("source_m_spawn_view_id") or context.territory_link.get("ID")!=record.get("source_m_territory_link_id") or context.spawn_view.get("NpcClassID")!=id or context.spawn_view.get("NpcSpawnPackID")!=context.territory_link.get("NpcSpawnPackID") or context.territory_link.get("TerritoriesID")!=context.territory.ID or context.territory.get("LandID")!=selection.land.ID:return false
	if not _integer(context.spawn_view.get("NpcLevel")) or int(context.spawn_view.NpcLevel)<=0 or record.get("source_m_spawn_npc_level")!=context.spawn_view.NpcLevel:return false
	return CONTEXT.activation_flag(context.spawn_view.get("IsSpawn"))=="active"

func prepare(catalog: RefCounted,records: Array,field: RefCounted,world: Node,population: Node,expected_model_sha256: String) -> Dictionary:
	if _state!="new":return _fail("batch_already_prepared")
	if not is_instance_valid(catalog) or not is_instance_valid(world) or not is_instance_valid(population):return _fail("batch_owner_unavailable")
	if not catalog.source_available or catalog.source_mode!="current523_original" or catalog.content.get("input_kind")!="twilight.current523.npc-input.v1" or catalog.source_identity!=SOURCE.identity() or catalog.source_identity.get("source_sha256")!=SOURCE.SOURCE_SHA:return _fail("current_npc_registry_required")
	if not _sha(expected_model_sha256) or expected_model_sha256!=catalog.source_model_sha256:return _fail("expected_npc_model_mismatch")
	if records.is_empty() or records.size()>4096:return _fail("explicit_nonempty_batch_required")
	if not _integer(world.get("combat_generation")) or not _integer(population.get("generation")):return _fail("actual_host_generations_required")
	var selection: Dictionary=_field_identity(field)
	if selection.is_empty():return _fail("exact_selected_m_field_required")
	selection["combat_generation"]=world.get("combat_generation");selection["population_generation"]=population.get("generation")
	var before: Dictionary=_snapshot(catalog)
	var ids: Array=[];var admissions: Dictionary=catalog.admitted_source_identities.duplicate(true)
	for key: String in admissions:
		if not key.is_valid_int() or int(key)<=0:return _fail("retained_npc_identity_invalid")
		var retained: Dictionary=SOURCE.row("NpcClass",int(key))
		if retained.is_empty() or admissions[key]!={"npc_class_id":retained.ID,"sprite":retained.Sprite,"desc_id":retained.DescId,"source_snapshot":"patch523","source_archive_sha256":SOURCE.SOURCE_SHA}:return _fail("retained_npc_identity_mismatch")
		ids.append(int(key))
	var seen: Dictionary={}
	for value: Variant in records:
		if not value is Dictionary or not _exact_record(value,selection,catalog):return _fail("selected_record_source_or_field_mismatch")
		var record: Dictionary=value
		var identity: Variant=record.get("sourceId")
		if not identity is String or identity.is_empty() or seen.has(identity):return _fail("duplicate_or_missing_encounter_identity")
		seen[identity]=true
		var id: int=int(record.source_m_npc_id);var raw: Dictionary=SOURCE.row("NpcClass",id)
		var admitted: Dictionary={"npc_class_id":raw.ID,"sprite":raw.Sprite,"desc_id":raw.DescId,"source_snapshot":"patch523","source_archive_sha256":SOURCE.SOURCE_SHA}
		if admissions.has(str(id)) and admissions[str(id)]!=admitted:return _fail("retained_npc_identity_conflict")
		admissions[str(id)]=admitted
		if id not in ids:ids.append(id)
	ids.sort()
	var producer=INPUT.new()
	var payload: Dictionary=producer.build(ids)
	if payload.is_empty():return _fail("npc_closure_rejected:"+producer.problem)
	# Existing admitted/environment rows must survive, never acquire a new meaning.
	for table: String in catalog.content.get("tables",{}):
		for key: String in catalog.content.tables[table]:
			if payload.get("tables",{}).get(table,{}).get(key)!=catalog.content.tables[table][key]:return _fail("retained_npc_row_changed:"+table+":"+key)
	for table: String in catalog.get("_environment_tables"):
		for key: String in catalog.get("_environment_tables")[table]:
			var entry: Dictionary=payload.get("tables",{}).get(table,{}).get(key,{})
			if not entry.is_empty() and entry!=catalog.get("_environment_tables")[table][key]:return _fail("environment_npc_row_conflict:"+table+":"+key)
	var shadow: RefCounted=catalog.get_script().new()
	for key: String in STATE:shadow.set(key,_copy(before[key]))
	shadow._publish_original(payload)
	shadow.admitted_source_identities=admissions
	for value: Dictionary in records:shadow.deferred_npc_inputs.erase(str(int(value.source_m_npc_id)))
	var output: Array=[]
	for value: Dictionary in records:
		var projected: Dictionary=shadow.project_actor_record(value.duplicate(true))
		if projected.get("source_m_definition_snapshot")!="patch523" or projected.get("source_m_definition_archive_sha256")!=SOURCE.SOURCE_SHA or not _same_npc(projected.get("source_m_original"),SOURCE.row("NpcClass",int(value.source_m_npc_id))):return _fail("isolated_projection_rejected")
		output.append(projected)
	if _snapshot(catalog)!=before or _field_identity(field)!=_without_generations(selection) or world.get("combat_generation")!=selection.combat_generation or population.get("generation")!=selection.population_generation or SOURCE.identity()!=catalog.source_identity:return _fail("batch_inputs_changed_during_prepare")
	_before=before;_prepared=_snapshot(shadow);_selection=selection;_records=output
	_catalog=weakref(catalog);_field=weakref(field);_world=weakref(world);_population=weakref(population);_state="prepared"
	return {"ok":true,"candidate":self,"records":output.duplicate(true),"selection":selection.duplicate(true),"source_identity":catalog.source_identity.duplicate(true),"previous_model_sha256":catalog.source_model_sha256,"prepared_model_sha256":shadow.source_model_sha256,"catalog_changed":false,"spawn_authorized":false}

static func _without_generations(selection: Dictionary) -> Dictionary:
	var result: Dictionary=selection.duplicate(true);result.erase("combat_generation");result.erase("population_generation");return result

func _matches_owner(catalog: RefCounted) -> bool:
	return _catalog!=null and _catalog.get_ref()==catalog

func commit(catalog: RefCounted) -> Dictionary:
	if _state!="prepared" or not _matches_owner(catalog):return _fail("batch_not_prepared_for_catalog")
	var field: RefCounted=_field.get_ref();var world: Node=_world.get_ref();var population: Node=_population.get_ref()
	if not is_instance_valid(field) or not is_instance_valid(world) or not is_instance_valid(population):return _fail("batch_host_expired")
	if _snapshot(catalog)!=_before or SOURCE.identity()!=_before.source_identity or _field_identity(field)!=_without_generations(_selection) or world.get("combat_generation")!=_selection.combat_generation or population.get("generation")!=_selection.population_generation:return _fail("batch_current_state_changed")
	# Synchronous in-memory publish: no callbacks, awaits, actor setup or saves.
	for key: String in NPC_WRITE:catalog.set(key,_copy(_prepared[key]))
	catalog.set("_actor_batch_revision",int(_before._actor_batch_revision)+1)
	_after=_snapshot(catalog);_state="committed"
	return {"ok":true,"candidate":self,"catalog_changed":true,"source_identity":catalog.source_identity.duplicate(true),"model_sha256":catalog.source_model_sha256,"batch_revision":catalog.get("_actor_batch_revision"),"records":_records.duplicate(true),"selection":_selection.duplicate(true),"spawn_authorized":false,"restore_required_on_population_failure":true}

func restore(catalog: RefCounted) -> Dictionary:
	if _state!="committed" or not _matches_owner(catalog):return _fail("batch_not_restorable_for_catalog")
	if _snapshot(catalog)!=_after or SOURCE.identity()!=_before.source_identity:return _fail("batch_restore_conflict_preserve_current_registry")
	# Restore only our NPC write set; the separate environment remains untouched.
	for key: String in NPC_WRITE:catalog.set(key,_copy(_before[key]))
	catalog.set("_actor_batch_revision",int(_after._actor_batch_revision)+1)
	_state="restored"
	return {"ok":true,"restored":true,"model_sha256":catalog.source_model_sha256,"spawn_authorized":false}

func finish(catalog: RefCounted) -> Dictionary:
	if _state!="committed" or not _matches_owner(catalog):return _fail("batch_not_committed_for_catalog")
	if _snapshot(catalog)!=_after:return _fail("batch_finish_conflict")
	_state="finished";_before={};_prepared={};_records=[]
	return {"ok":true,"finalized":true,"spawn_authorized":false}
