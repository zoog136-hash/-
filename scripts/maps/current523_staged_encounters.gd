extends RefCounted
## TWILIGHT host encounter specifications, not live actors or native placement.
## Detached actor bodies use only an exact data-owner prepared receipt.
## No live catalog admission, World RNG, boss or population mutation here.
const SPAWNS=preload("res://scripts/maps/current523_source_spawns.gd")
const ROSTER=preload("res://scripts/monsters/base508_source_roster.gd")
const POLICY=preload("res://scripts/monsters/patch523_spawn_policy.gd")
const SOURCE=preload("res://scripts/resources/current523_definition_rows.gd")
const DIRECTOR=preload("res://scripts/monsters/boss_director.gd")
const SOURCE_POPULATION=preload("res://scripts/maps/source_population.gd")
const DEFINITION_PIN="2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
const DETACHED_CONTEXT=preload("res://scripts/maps/current523_detached_actor_context.gd")
var _body_count: int=0
var state: String="NEW"
var problem: String=""
var container: Node2D
var field: OriginalPlayableField
var definition: RefCounted
var records: Dictionary={}
var slots: Array[Dictionary]=[]
var occupancy: Array[Dictionary]=[]
var snapshot: Dictionary={}
var source_summary: Dictionary={}
var _prepared_boss: TwilightBossDirector
var _transferred: Node2D
var _boss_owner: RefCounted
var _boss_before: Dictionary={}
var _rng: RandomNumberGenerator
var _landing: Vector2i
var _request: Dictionary={}

static func _instance(value: Variant) -> int:
	return value.get_instance_id() if value is Object and is_instance_valid(value) else 0

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value))

static func _current_actors(world: Node) -> Array:
	var result: Array=[]
	var root: Variant=world.get("monsters_root")
	if not root is Node:return result
	for actor: Node in root.get_children():
		if not actor is TwilightMonster:continue
		result.append({"instance":actor.get_instance_id(),"life":actor.life_id,"dead":actor.dead,"position":actor.global_position})
	result.sort_custom(func(a: Dictionary,b: Dictionary)->bool:return a.instance<b.instance)
	return result

func _hold(reason: String) -> bool:
	problem=reason
	state="HELD"
	return false

func prepare(world: Node, target: OriginalPlayableField, target_definition: RefCounted, landing: Vector2i, request: Dictionary) -> bool:
	if state!="NEW":return _hold("stage_already_used")
	if not is_instance_valid(world) or target==null or target==world.get("field_map") or target.get_meta("current523_generic_field",false)!=true:return _hold("private_target_source_field_required")
	var native_land: Variant=target.get("native_land")
	if not native_land is Dictionary or target_definition==null or target_definition.get("loaded")!=true or target_definition.get("manifest_sha256")!=DEFINITION_PIN or target_definition.get("land")!=native_land:return _hold("target_original_definition_identity_required")
	if target.get("source_asset")!=native_land.get("AssetPath") or target.definition.get("source_map_id")!=native_land.get("ID") or target.definition.get("source_asset_path")!=native_land.get("AssetPath") or target.definition.get("source_manifest_sha256")!=target.get("catalog_sha256"):return _hold("target_source_field_identity_mismatch")
	var portal: Variant=request.get("Portal")
	var territory: Variant=request.get("TargetTerritory")
	var source_land: Variant=request.get("SourceLand")
	var source_field: Variant=world.get("field_map")
	if not portal is Dictionary or not territory is Dictionary or not source_land is Dictionary or not source_field is Object or source_land!=source_field.get("native_land") or request.get("TargetLand")!=native_land:return _hold("explicit_original_portal_endpoints_required")
	if portal.get("SourceLandID")!=source_land.get("ID") or portal.get("TargetTerritoryID")!=territory.get("ID") or territory.get("LandID")!=native_land.get("ID") or request.get("definition_manifest_sha256")!=DEFINITION_PIN or not request.get("source_travel_hold") is String or not request.source_travel_hold.is_empty():return _hold("portal_original_identity_or_conditions_held")
	for key: String in ["StartX","StartY","EndX","EndY"]:
		if not _integer(territory.get(key)):return _hold("target_territory_bounds_invalid")
	if landing.x<territory.StartX or landing.x>territory.EndX or landing.y<territory.StartY or landing.y>territory.EndY:return _hold("selected_landing_outside_original_territory")
	var source_cell: Vector2i=source_field.world_to_cell(world.player.global_position)+source_field.coordinates.origin
	if source_cell!=Vector2i(int(portal.get("SourceX",-1)),int(portal.get("SourceY",-1))):return _hold("actor_not_at_original_portal_source")
	var service: Variant=world.get("patch523_npc_spells")
	var catalog: Variant=service.get("catalog") if service is Object else null
	var identity: Dictionary=SOURCE.identity()
	if not catalog is Object or catalog.get("source_available")!=true or catalog.get("source_mode")!="current523_original" or identity.is_empty() or catalog.get("source_identity")!=identity:return _hold("configured_original_npc_input_identity_required")
	if not world.get("rng") is RandomNumberGenerator:return _hold("existing_world_rng_required")
	var original_population: Variant=world.get("original_population")
	var boss: Variant=original_population.get("boss_director") if original_population is Object else null
	if not boss is RefCounted or not boss.has_method("export_state"):return _hold("existing_original_boss_state_owner_required")
	_boss_owner=boss
	_boss_before=boss.export_state().duplicate(true)
	var boss_copy=DIRECTOR.new()
	boss_copy.import_state(_boss_before)
	_prepared_boss=boss_copy
	# Capture current lives only into the private copy; leave the live director intact.
	if original_population.get("field")==source_field:
		for slot: Dictionary in original_population.get("slots"):
			if slot.region.get("mode")=="boss" and is_instance_valid(slot.get("monster")):
				boss_copy.capture(str(source_field.get("data").map_id),slot.region,slot.monster)
	field=target;definition=target_definition;_landing=landing;_request=request.duplicate(true)
	snapshot={"source_field":_instance(source_field),"target_field":_instance(target),"target_land":native_land.duplicate(true),"target_asset_path":target.get("source_asset"),"target_source_pin":target.get("catalog_sha256"),"definition_pin":DEFINITION_PIN,"source_identity":identity.duplicate(true),"npc_model_sha256":catalog.get("source_model_sha256"),"combat_generation":world.get("combat_generation"),"position":world.player.global_position,"actors_root":_instance(world.get("monsters_root")),"population":_instance(world.get("field_population")),"actors":_current_actors(world),"rng_seed":world.rng.seed,"rng_state":world.rng.state,"gold":world.get("gold")}
	_rng=RandomNumberGenerator.new();_rng.seed=world.rng.seed;_rng.state=world.rng.state
	var arrival_rng: Dictionary=request.get("own_landing_rng",{})
	if not arrival_rng.is_empty():
		if arrival_rng.get("before")!={"seed":world.rng.seed,"state":world.rng.state} or not arrival_rng.get("after_state") is int:return _hold("arrival_rng_snapshot_changed")
		_rng.state=arrival_rng.after_state
	# Explicit catalog prevents PR276's settings/cache fallback. Only the
	# caller-owned private target field's regions/summary are populated.
	source_summary=SPAWNS.apply(target,target_definition)
	if source_summary.get("ok")!=true:return _hold("target_source_spawn_definition_unavailable")
	if target.data.get("monster_spawn",[]).is_empty():return _hold("target_has_no_admitted_encounter_specs_not_empty_population_success")
	container=Node2D.new();container.name="Current523PreparedEncounterSpecifications"
	container.process_mode=Node.PROCESS_MODE_DISABLED;container.hide()
	var active_count: int=0
	var cells: Dictionary={}
	var boss_candidates: Dictionary={}
	var anchor: Vector2=target.coordinates.to_world(Vector2(landing))
	if not target.point_clear(anchor,4.0):return _hold("selected_target_landing_not_clear")
	for region: Dictionary in target.data.monster_spawn:
		var names: Variant=region.get("monster_types")
		if not names is Array or names.size()!=1 or region.get("source_m_key")!=names[0]:return _hold("exact_single_encounter_tuple_required")
		var key: String=str(names[0])
		var record: Dictionary=ROSTER.for_spawn(key,str(target.data.map_id),"",bool(region.get("source_m_allow_contextual",false)))
		if record.get("source_m_current523_final")!=true or not str(record.get("source_m_asset_manifest_path","")).is_empty() or record.get("source_m_definition_archive_sha256")!=SOURCE.SOURCE_SHA or record.get("source_m_context",{}).get("land")!=native_land:return _hold("current_original_encounter_record_required")
		var admission: Dictionary=POLICY.admit(record,str(target.data.map_id),target_definition)
		if admission.get("ok")!=true or admission.get("applied")!=true:return _hold("target_encounter_admission_held:"+str(admission.get("reason","unknown")))
		record=admission.record.duplicate(true)
		var context: Dictionary=record.source_m_context
		if context.territory.get("ID")!=region.get("source_territory_id") or context.spawn_view.get("NpcSpawnPackID")!=region.get("source_spawn_pack_id") or context.territory_link.get("TerritoriesID")!=context.territory.ID:return _hold("target_encounter_region_tuple_mismatch")
		records[key]=record
		if not _integer(region.get("max_count")) or region.max_count<1:return _hold("target_host_count_policy_invalid")
		for index: int in range(int(region.max_count)):
			var spec: Dictionary={"region":region.duplicate(true),"index":index,"source_key":key,"state":"DORMANT","actor":null}
			if target.source_spawn_active(region,anchor):
				var is_boss: bool=region.get("mode")=="boss"
				if is_boss and not boss_copy.can_spawn(str(target.data.map_id),region):
					spec.state="BOSS_COOLDOWN_SNAPSHOT"
					spec["boss_state"]=boss_copy.state_for(str(target.data.map_id),region).duplicate(true)
					slots.append(spec);continue
				if is_boss:
					var boss_key: String=boss_copy.key(str(target.data.map_id),region)
					if boss_candidates.has(boss_key):
						spec.state="SHARED_BOSS_CANDIDATE_REQUIRES_SAME_OWNER"
						spec["shared_slot"]=boss_candidates[boss_key]
						slots.append(spec);continue
					boss_candidates[boss_key]=slots.size()
				active_count+=1
				if active_count>SOURCE_POPULATION.MAX_ACTIVE:return _hold("target_active_population_exceeds_existing_host_budget")
				# Same existing source-field sampling function and private RNG.
				# No guessed original fixed actor coordinates or extra reroll policy.
				var point: Vector2=target.sample_source_spawn(region,anchor,_rng)
				if not point.is_finite() or not target.walkable(point) or not target.point_clear(point,4.0) or target.is_safe(point):return _hold("target_source_position_not_supported")
				var location: Dictionary=target.call("source_region_context",point,native_land)
				if location.is_empty():return _hold("target_position_source_member_proof_required")
				var xy: Array=location.source_cell
				var cell:=Vector2i(xy[0],xy[1])
				var bounds: Rect2i=region.source_rect
				if not bounds.has_point(cell) or cell.x<context.territory.StartX or cell.x>context.territory.EndX or cell.y<context.territory.StartY or cell.y>context.territory.EndY:return _hold("target_spawn_outside_original_territory")
				if cells.has(cell):return _hold("duplicate_target_reserved_source_cell")
				var spacing: float=float(region.get("min_spacing",0.0))
				if not is_finite(spacing) or spacing<0:return _hold("target_spacing_policy_invalid")
				for reservation: Dictionary in occupancy:
					if point.distance_to(reservation.position)<maxf(spacing,float(reservation.min_spacing)):return _hold("target_reserved_actor_spacing_rejected")
				cells[cell]=true
				spec.state="POSITION_RESERVED_REQUIRES_ACTOR_FACTORY"
				spec["position"]=point;spec["source_location"]=location.source_location.duplicate(true)
				if is_boss:spec["boss_state"]=boss_copy.state_for(str(target.data.map_id),region).duplicate(true)
				occupancy.append({"slot":slots.size(),"position":point,"source_cell":xy.duplicate(),"min_spacing":spacing,"boss_restore_pending":is_boss,"raw_IsOccupyLandTile":record.source_m_original.get("IsOccupyLandTile"),"source_key":key})
			slots.append(spec)
	container.set_meta("staged_encounter_count",slots.size())
	state="PREPARED_SPECIFICATIONS"
	var stale: Dictionary=revalidate(world,target,target_definition,landing,request)
	if stale.get("ok")!=true:return _hold(str(stale.get("reason","stage_changed_during_preparation")))
	return true

func revalidate(world: Node, target: OriginalPlayableField, target_definition: RefCounted, landing: Vector2i, request: Dictionary, registration: Dictionary={}) -> Dictionary:
	if state not in ["PREPARED_SPECIFICATIONS","DETACHED_ACTOR_BODIES"] or target!=field or target_definition!=definition or landing!=_landing or request!=_request:return {"ok":false,"reason":"staged_request_or_ownership_changed"}
	if not is_instance_valid(container) or container.is_inside_tree() or container.get_parent()!=null or container.get_child_count()!=_body_count:return {"ok":false,"reason":"specification_container_ownership_changed"}
	for actor: Node in container.get_children():
		if not actor is TwilightMonster or actor.is_inside_tree() or actor.get("world_controller")!=null or actor.get_meta("current523_detached_actor_body",{}).get("activation_ready")!=false:return {"ok":false,"reason":"detached_actor_ownership_changed"}
	var service: Variant=world.get("patch523_npc_spells")
	var catalog: Variant=service.get("catalog") if service is Object else null
	var expected_model: String=str(snapshot.npc_model_sha256)
	if not registration.is_empty():
		var selected: Dictionary=registration.get("selection",{})
		if registration.get("ok")!=true or registration.get("catalog_changed")!=true or registration.get("source_identity")!=snapshot.source_identity or selected.get("field_instance_id")!=field.get_instance_id() or selected.get("land")!=snapshot.target_land or selected.get("asset_path")!=snapshot.target_asset_path or selected.get("combat_generation")!=snapshot.combat_generation:return {"ok":false,"reason":"actual_target_registration_receipt_required"}
		expected_model=str(registration.get("model_sha256",""))
		if expected_model.length()!=64 or not expected_model.is_valid_hex_number(false):return {"ok":false,"reason":"committed_model_identity_required"}
	if not catalog is Object or catalog.get("source_available")!=true or catalog.get("source_identity")!=snapshot.source_identity or SOURCE.identity()!=snapshot.source_identity or catalog.get("source_model_sha256")!=expected_model:return {"ok":false,"reason":"original_npc_input_identity_changed"}
	if _instance(world.get("field_map"))!=snapshot.source_field or world.get("combat_generation")!=snapshot.combat_generation or world.player.global_position!=snapshot.position or world.get("gold")!=snapshot.gold:return {"ok":false,"reason":"source_actor_field_or_cost_snapshot_changed"}
	if _instance(world.get("monsters_root"))!=snapshot.actors_root or _instance(world.get("field_population"))!=snapshot.population or _current_actors(world)!=snapshot.actors:return {"ok":false,"reason":"source_actor_population_changed"}
	if world.rng.seed!=snapshot.rng_seed or world.rng.state!=snapshot.rng_state or _boss_owner.export_state()!=_boss_before:return {"ok":false,"reason":"source_rng_or_boss_snapshot_changed"}
	if target.get("native_land")!=snapshot.target_land or target.get("source_asset")!=snapshot.target_asset_path or target.get("catalog_sha256")!=snapshot.target_source_pin or target_definition.get("land")!=snapshot.target_land or target_definition.get("manifest_sha256")!=DEFINITION_PIN:return {"ok":false,"reason":"target_original_identity_changed"}
	return {"ok":true,"activation_ready":false,"reason":"exact_data_batch_and_live_actor_adoption_still_required"}

func landing_status() -> Dictionary:
	if state not in ["PREPARED_SPECIFICATIONS","DETACHED_ACTOR_BODIES"]:return {"ok":false,"reason":problem}
	var anchor: Vector2=field.coordinates.to_world(Vector2(_landing))
	for reservation: Dictionary in occupancy:
		if reservation.boss_restore_pending:return {"ok":false,"reason":"prepared_boss_actor_restore_position_required"}
		# Preserve Main's existing 155px teleport margin, applied to target
		# reservations only. This is host policy, not a decoded native bit.
		if anchor.distance_to(reservation.position)<155.0:return {"ok":true,"clear":false,"policy":"EXISTING_HOST_TELEPORT_155PX"}
	return {"ok":true,"clear":true,"policy":"EXISTING_HOST_TELEPORT_155PX","actor_materialized":_body_count>0}

func describe() -> Dictionary:
	return {"state":state,"reason":problem,"records":records.size(),"slots":slots.size(),"reserved_positions":occupancy.size(),"live_actors":0,"detached_actor_bodies":_body_count,"media_ready":false,"activation_ready":false,"native_population_verified":false,"placement_policy":SPAWNS.PLACEMENT_POLICY,"rng_scope":"PRIVATE_COPY_OF_EXISTING_WORLD_RNG","target_field_owned_by":"travel_caller","container_owned_by":"staged_encounters","landing":landing_status(),"requires":"source_media_boss_restore_population_adoption_and_save_transaction"}

func materialize_actor_bodies(world: Node, receipt: Dictionary) -> Dictionary:
	if state!="PREPARED_SPECIFICATIONS":return {"ok":false,"reason":"specifications_required"}
	var stale: Dictionary=revalidate(world,field,definition,_landing,_request)
	if stale.get("ok")!=true:return stale
	var projected: Variant=receipt.get("records")
	if not projected is Array or projected.size()!=records.size():return {"ok":false,"reason":"exact_batch_record_set_required"}
	var by_source: Dictionary={}
	for value: Variant in projected:
		if not value is Dictionary:return {"ok":false,"reason":"projected_record_shape"}
		var key: String=str(value.get("sourceId",""))
		if key.is_empty() or by_source.has(key):return {"ok":false,"reason":"unique_projected_encounters_required"}
		by_source[key]=value
	for record: Dictionary in records.values():
		var projected_record: Dictionary=by_source.get(str(record.get("sourceId","")),{})
		if projected_record.get("source_m_original")!=record.get("source_m_original") or projected_record.get("source_m_context")!=record.get("source_m_context"):return {"ok":false,"reason":"projected_original_tuple_changed"}
	var guard=DETACHED_CONTEXT.new()
	if not guard.configure(receipt,world,field,definition,world.get("field_population")):return {"ok":false,"reason":"prepared_batch_owner_mismatch"}
	for slot: Dictionary in slots:
		if slot.state!="POSITION_RESERVED_REQUIRES_ACTOR_FACTORY":continue
		var record: Dictionary=by_source.get(str(records[slot.source_key].get("sourceId","")),{})
		var actor: TwilightMonster=world.MONSTER_SCENE.instantiate()
		actor.position=slot.position
		if not actor.prepare_source_record(record,world.player,guard):
			actor.free();return {"ok":false,"reason":"detached_actor_setup_held","prepared_actor_bodies":_body_count}
		# This is an inactive host body, not source-media readiness or spawn permission.
		preload("res://scripts/maps/source_body_profile.gd").apply(actor,true)
		container.add_child(actor);slot.actor=actor;slot.state="DETACHED_ACTOR_BODY"
		_body_count+=1
	state="DETACHED_ACTOR_BODIES"
	return {"ok":true,"detached_actor_bodies":_body_count,"live_actors":0,"catalog_changed":false,"activation_ready":false,"reason":"media_boss_population_adoption_and_save_transaction_required"}

func actor_batch_request() -> Dictionary:
	# Exact unique templates supplied to the received data-owner batch ABI.
	if state not in ["PREPARED_SPECIFICATIONS","DETACHED_ACTOR_BODIES"]:return {"ok":false,"reason":problem}
	var selected: Array=[]
	var keys: Array=records.keys();keys.sort()
	for key: String in keys:selected.append(records[key].duplicate(true))
	return {"ok":true,"records":selected,"source_archive_identity":snapshot.source_identity.duplicate(true),"expected_npc_model_sha256":snapshot.npc_model_sha256,"target_land":snapshot.target_land.duplicate(true),"target_asset_path":snapshot.target_asset_path,"target_field_instance":snapshot.target_field,"source_manifest_sha256":snapshot.target_source_pin,"definition_manifest_sha256":DEFINITION_PIN,"activation_ready":false}

func detached_boss_director() -> TwilightBossDirector:
	return _prepared_boss
func detached_rng() -> RandomNumberGenerator:
	return _rng
func selected_landing() -> Vector2i:
	return _landing
func selected_request() -> Dictionary:
	return _request.duplicate(true)
func release_container() -> Node2D:
	if state!="DETACHED_ACTOR_BODIES" or not is_instance_valid(container) or container.get_parent()!=null or container.is_inside_tree():return null
	_transferred=container;container=null;state="CONTAINER_TRANSFERRED"
	return _transferred
func transferred_container() -> Node2D:
	return _transferred

func discard() -> void:
	if state=="DISCARDED":return
	if is_instance_valid(container):
		if container.is_inside_tree() or container.get_parent()!=null:
			state="DISCARD_HELD_OWNER_CHANGED";problem="container_no_longer_detached_owned_candidate";return
		container.free()
	container=null;_body_count=0;records.clear();slots.clear();occupancy.clear();snapshot.clear()
	field=null;definition=null;_boss_owner=null;_rng=null;_request.clear();_boss_before.clear()
	state="DISCARDED"

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:discard()
