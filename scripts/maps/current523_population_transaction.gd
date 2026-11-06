extends RefCounted
## TWILIGHT host transaction over exact source inputs; not a source-server API.
const POPULATION=preload("res://scripts/maps/source_population.gd")
var stage: RefCounted
var catalog: RefCounted
var batch: Dictionary={}
var commit_receipt: Dictionary={}
var restore_receipt: Dictionary={}
var finish_receipt: Dictionary={}
var population: OriginalSourcePopulation
var state: String="NEW"
var problem: String=""
var previous: Dictionary={}
var _boss_copy: TwilightBossDirector
var _records: Dictionary={}
var _world: WeakRef
var _taken_root: bool=false
var _legacy_save_journal: Dictionary={}
var _population_restore_ready: bool=true
var actions_prepared: Dictionary={}
var cleanup_receipt: Dictionary={}
var saved_proof: Dictionary={}
var committed_cleanup_receipt: String=""
var _finished_payment: Dictionary={}
var _finished_context: Array=[]
var _finished_result: Dictionary={}
# Monotone, transaction-owned history. Rollback never clears an attempt.
var attempt_history: Dictionary={"options_write_attempted":false,"session_switch_attempted":false,"owner_adoption_attempted":false,"save_attempted":false,"catalog_finish_attempted":false}
var attempt_requested: bool=false
var attempt_receipt: Dictionary={}
var route_rejection: Dictionary={}
var discard_receipt: Dictionary={}
var _departing_action_context: Array=[]
var recovery_evidence: Dictionary={}

func configure(world: Node, prepared_stage: RefCounted, prepared_batch: Dictionary) -> bool:
	if state!="NEW" or prepared_batch.get("ok")!=true or prepared_stage.state!="DETACHED_ACTOR_BODIES":return false
	var service: Variant=world.get("patch523_npc_spells")
	catalog=service.get("catalog") if service is Object else null
	if catalog==null or prepared_stage.describe().get("detached_actor_bodies",0)<1:return false
	stage=prepared_stage;batch=prepared_batch;_world=weakref(world)
	recovery_evidence={"source_snapshot":stage.snapshot.duplicate(true),"selected_request":stage.selected_request(),"population_generation":batch.selection.population_generation,"source_identity":batch.source_identity.duplicate(true)}
	_boss_copy=stage.detached_boss_director()
	if _boss_copy==null:return false
	for record: Dictionary in batch.records:_records[str(record.sourceId)]=record.duplicate(true)
	state="PREPARED";return true

func _fail(reason: String) -> Dictionary:
	problem=reason
	if post_save_hold() and _world!=null:
		var host: Node=_world.get_ref()
		if is_instance_valid(host) and is_instance_valid(host.get("player")) and host.player.auto_enabled:host.player.set_auto_enabled(false)
	return {"ok":false,"reason":reason,"state":state,"catalog_committed":not commit_receipt.is_empty(),"restore":restore_receipt.duplicate(true),"population_restored":_population_restore_ready}

func register_and_prepare() -> Dictionary:
	if state!="PREPARED":return _fail("population_not_prepared")
	var world: Node=_world.get_ref()
	var stale: Dictionary=stage.revalidate(world,stage.field,stage.definition,stage.selected_landing(),stage.selected_request())
	if stale.get("ok")!=true:return _fail(str(stale.get("reason")))
	commit_receipt=catalog.commit_actor_batch(batch.candidate)
	if commit_receipt.get("ok")!=true:
		commit_receipt={};return _fail("target_catalog_commit_rejected")
	state="CATALOG_COMMITTED"
	# No live actor setup/projection/admission or environment registration here.
	for spec: Dictionary in stage.slots:
		var actor: Variant=spec.get("actor")
		if not is_instance_valid(actor):continue
		var record: Dictionary=_records.get(str(stage.records[spec.source_key].sourceId),{})
		var admission: Dictionary=preload("res://scripts/monsters/patch523_spawn_policy.gd").admit(record,str(stage.field.data.map_id),stage.definition)
		if admission.get("ok")!=true or admission.get("applied")!=true:return _fail("target_policy_changed_before_media")
		var identity: Variant=catalog.admitted_source_identities.get(str(int(record.source_m_npc_id)))
		if not identity is Dictionary or identity.is_empty():return _fail("committed_actor_identity_unavailable")
		admission["current523_npc_source_identity"]=identity.duplicate(true)
		if not actor.prepare_registered_source_media(admission.record,admission):return _fail("target_original_media_not_ready")
		actor.home_position=spec.position;actor.spawn_region_id=str(spec.region.id)
		actor.roaming_radius=float(spec.region.get("roaming_radius",120))
		if spec.region.get("mode")=="boss":
			var saved: Dictionary=_boss_copy.state_for(str(stage.field.data.map_id),spec.region)
			var home: Variant=saved.get("home",[])
			if _saved_point(home,spec.region):actor.home_position=Vector2(home[0],home[1])
			var point: Variant=saved.get("position",[])
			if _saved_point(point,spec.region):
				var value:=Vector2(point[0],point[1])
				if value.distance_to(actor.home_position)<float(actor.ai.get("leash_distance",820.0)):actor.position=value
			spec["registered_boss_state"]=saved.duplicate(true)
	var occupied: Dictionary={};var bodies: Array=[]
	var landing: Vector2=stage.field.coordinates.to_world(Vector2(stage.selected_landing()))
	for spec: Dictionary in stage.slots:
		var actor: Variant=spec.get("actor")
		if not is_instance_valid(actor):continue
		var point: Vector2=actor.position
		if not _allowed(point,spec.region) or point.distance_to(landing)<155.0:return _fail("restored_target_actor_or_landing_collision")
		var cell: Vector2i=stage.field.world_to_cell(point)+stage.field.coordinates.origin
		if occupied.has(cell):return _fail("restored_target_duplicate_cell")
		for other: Dictionary in bodies:
			if point.distance_to(other.point)<maxf(float(spec.region.get("min_spacing",0)),float(other.spacing)):return _fail("restored_target_spacing_collision")
		occupied[cell]=true;bodies.append({"point":point,"spacing":spec.region.get("min_spacing",0)})
		spec.position=point
		spec.source_location=stage.field.source_region_context(point,stage.field.native_land).source_location.duplicate(true)
		for reservation: Dictionary in stage.occupancy:
			if reservation.get("source_key")==spec.source_key and reservation.get("slot")==stage.slots.find(spec):
				reservation.position=point;reservation.source_cell=[cell.x,cell.y];reservation.boss_restore_pending=false
		if spec.region.get("mode")=="boss":_boss_copy.capture(str(stage.field.data.map_id),spec.region,actor)
	population=POPULATION.new();population.name="Current523TravelPopulation"
	population.process_mode=Node.PROCESS_MODE_DISABLED;population.set_process(false)
	population.world=world;population.field=stage.field;population.boss_director=_boss_copy
	population.generation=int(world.field_population.generation)+1
	population.records=stage.records.duplicate(true)
	for spec: Dictionary in stage.slots:
		var actor: Variant=spec.get("actor")
		var slot: Dictionary={"region":spec.region.duplicate(true),"index":spec.index,"slot_id":population.slots.size(),"monster":actor,"remaining":0.0,"has_spawned":is_instance_valid(actor)}
		population.slots.append(slot)
		if is_instance_valid(actor):
			actor.attack_cooldown=stage.detached_rng().randf_range(0.0,actor.attack_interval*0.7)
			actor.set_meta("field_slot",int(slot.slot_id));actor.set_meta("population_generation",population.generation)
			actor.set_meta("summoned",false);actor.set_meta("source_game_id",str(spec.region.get("source_game_id","")));actor.set_meta("source_spawn_key",str(spec.region.get("source_key","")))
	if not world.has_method("prepare_current523_transition_actions") or not world.has_method("cancel_current523_transition_actions") or not world.has_method("begin_current523_transition_attempt") or not world.has_method("discard_current523_transition_actions"):return _fail("actual_integration_transition_receiver_required")
	# Current departing owners are captured before field/population replacement
	# or any save. The real receiver stores exact weak actor/life references.
	_departing_action_context=_action_context(world)
	actions_prepared=world.prepare_current523_transition_actions(world.monsters_root,world.field_population,Callable(self,"_before_attempt_discard_guard"))
	if actions_prepared.get("ok")!=true or actions_prepared.get("transient_mutation")!=false or actions_prepared.get("combat_generation")!=batch.selection.combat_generation or actions_prepared.get("prior_actor_root_id")!=stage.snapshot.actors_root or actions_prepared.get("prior_population_id")!=stage.snapshot.population:return _fail("departing_action_capture_rejected:"+str(actions_prepared.get("reason","identity_mismatch")))
	var token: Variant=actions_prepared.get("token")
	if not token is String or token.length()!=32 or not token.is_valid_hex_number(false) or not actions_prepared.get("actor_count") is int or actions_prepared.actor_count<0:return _fail("departing_action_capture_shape_invalid")
	state="REGISTERED_READY"
	return {"ok":true,"state":state,"media_ready":true,"population_adopted":false,"model_sha256":commit_receipt.model_sha256,"actions_prepared":actions_prepared.duplicate(true)}

func record_registered_route_rejection(result: Dictionary) -> void:
	# Only the first registered-route check, before any actual attempt.
	if state=="REGISTERED_READY" and not attempt_requested and result.get("ok")==false and route_rejection.is_empty():route_rejection=result.duplicate(true)

func begin_transition_attempt() -> Dictionary:
	if state!="REGISTERED_READY" or attempt_requested or not route_rejection.is_empty():return _fail("transition_attempt_not_fresh")
	for key: String in attempt_history:
		if attempt_history[key]!=false:return _fail("transition_attempt_history_not_empty")
	attempt_requested=true
	var world: Node=_world.get_ref()
	attempt_receipt=world.begin_current523_transition_attempt(actions_prepared.token,int(actions_prepared.combat_generation))
	if attempt_receipt.get("ok")!=true or attempt_receipt.get("attempt_started")!=true or attempt_receipt.get("combat_generation")!=actions_prepared.combat_generation or attempt_receipt.get("transient_mutation")!=false:return _fail("transition_attempt_barrier_rejected_or_uncertain")
	return attempt_receipt.duplicate(true)

func note_transition_attempt(kind: String) -> void:
	# Called immediately BEFORE the corresponding external operation.
	if attempt_history.has(kind):attempt_history[kind]=true

func _before_attempt_discard_guard(token: String,epoch: int) -> Dictionary:
	var denied: Dictionary={"ok":false,"reason":"map_uncommitted_history_not_proven"}
	if state!="CATALOG_RESTORED" or route_rejection.get("ok")!=false or attempt_requested or not attempt_receipt.is_empty() or not finish_receipt.is_empty() or not saved_proof.is_empty() or not cleanup_receipt.is_empty():return denied
	if token!=actions_prepared.get("token") or epoch!=actions_prepared.get("combat_generation") or restore_receipt.get("ok")!=true or restore_receipt.get("restored")!=true or not _population_restore_ready:return denied
	for key: String in attempt_history:
		if attempt_history[key]!=false:return denied
	var world: Node=_world.get_ref()
	if not is_instance_valid(world) or _action_context(world)!=_departing_action_context or world.field_map.get_instance_id()!=stage.snapshot.source_field or world.player.global_position!=stage.snapshot.position or world.rng.seed!=stage.snapshot.rng_seed or world.rng.state!=stage.snapshot.rng_state or world.gold!=stage.snapshot.gold:return denied
	if world.combat_generation!=epoch or world.patch523_npc_spells.generation!=epoch or world.field_population.generation!=batch.selection.population_generation or catalog.source_identity!=stage.snapshot.source_identity or catalog.source_model_sha256!=stage.snapshot.npc_model_sha256 or restore_receipt.get("model_sha256")!=stage.snapshot.npc_model_sha256:return denied
	var proof: Dictionary=attempt_history.duplicate(true)
	proof.merge({"ok":true,"token":token,"combat_generation":epoch,"abort_kind":"registered_cross_land_route_rejected","catalog_restore_confirmed":true})
	return proof

func _saved_point(value: Variant, region: Dictionary) -> bool:
	return value is Array and value.size()==2 and typeof(value[0]) in [TYPE_INT,TYPE_FLOAT] and typeof(value[1]) in [TYPE_INT,TYPE_FLOAT] and _allowed(Vector2(value[0],value[1]),region)

func _allowed(point: Vector2, region: Dictionary) -> bool:
	if not point.is_finite() or not stage.field.walkable(point) or not stage.field.point_clear(point,4.0) or stage.field.is_safe(point):return false
	var source: Dictionary=stage.field.source_region_context(point,stage.field.native_land)
	if source.is_empty():return false
	var cell:=Vector2i(source.source_cell[0],source.source_cell[1])
	return region.source_rect.has_point(cell)

func revalidate_registered() -> Dictionary:
	if state!="REGISTERED_READY":return _fail("registered_target_required")
	return stage.revalidate(_world.get_ref(),stage.field,stage.definition,stage.selected_landing(),stage.selected_request(),commit_receipt)

func adopt() -> Dictionary:
	if state!="REGISTERED_READY":return _fail("registered_target_required")
	var world: Node=_world.get_ref()
	if world.field_map!=stage.field or world.combat_generation!=batch.selection.combat_generation or world.field_population.generation!=batch.selection.population_generation or catalog.source_model_sha256!=commit_receipt.model_sha256:return _fail("population_adoption_owner_changed")
	previous={"root":world.monsters_root,"population":world.field_population,"original":world.original_population,"root_mode":world.monsters_root.process_mode,"root_visible":world.monsters_root.visible,"population_mode":world.field_population.process_mode}
	for spec: Dictionary in stage.slots:
		var actor: Variant=spec.get("actor")
		if not is_instance_valid(actor):continue
		var record: Dictionary=_records.get(str(stage.records[spec.source_key].sourceId),{})
		if not actor.adopt_prepared_source_record(world,record,str(commit_receipt.model_sha256)):return _fail("prepared_actor_adoption_rejected")
		if spec.region.get("mode")=="boss":
			population.restore_boss_hp(actor,spec.registered_boss_state)
			_boss_copy.capture(str(stage.field.data.map_id),spec.region,actor)
	var root: Node2D=stage.release_container()
	if root==null:return _fail("detached_container_transfer_rejected")
	_taken_root=true
	# New nodes remain disabled while the existing save owner runs synchronously.
	previous.root.process_mode=Node.PROCESS_MODE_DISABLED;previous.root.hide()
	previous.population.process_mode=Node.PROCESS_MODE_DISABLED
	world.add_child(population)
	world.add_child(root)
	world.monsters_root=root;world.field_population=population;world.original_population=population
	world.rng.state=stage.detached_rng().state
	_population_restore_ready=false
	state="ADOPTED"
	return {"ok":true,"state":state,"population_adopted":true,"actors_active":false}

func begin_save_observation() -> Dictionary:
	if state!="ADOPTED":return _fail("adopted_population_required_for_save")
	var world: Node=_world.get_ref()
	var legacy: Variant=world.get("legacy_population")
	if not legacy is FieldPopulation or legacy.get_script()!=preload("res://scripts/maps/field_population.gd"):return _fail("exact_legacy_population_save_owner_required")
	var before: Dictionary=legacy.boss_director.export_state().duplicate(true)
	var shadow=preload("res://scripts/monsters/boss_director.gd").new();shadow.import_state(before)
	if shadow.export_state()!=before:return _fail("legacy_boss_snapshot_not_exactly_reproducible")
	if legacy.field!=null:
		for slot: Dictionary in legacy.slots:
			if slot.region.get("mode")=="boss":shadow.capture(str(legacy.field.data.map_id),slot.region,slot.get("monster") as TwilightMonster if is_instance_valid(slot.get("monster")) else null)
	_legacy_save_journal={"owner":weakref(legacy),"director":weakref(legacy.boss_director),"before":before,"expected_export_capture":shadow.export_state().duplicate(true)}
	return {"ok":true,"population_save_side_effect_observed":true}

func _restore_legacy_save_capture() -> Dictionary:
	if _legacy_save_journal.is_empty():return {"ok":true}
	var legacy: Variant=_legacy_save_journal.owner.get_ref()
	var director: Variant=_legacy_save_journal.director.get_ref()
	if not is_instance_valid(legacy) or not is_instance_valid(director) or legacy.boss_director!=director:return _fail("legacy_save_population_owner_changed")
	var current: Dictionary=director.export_state()
	if current!=_legacy_save_journal.before and current!=_legacy_save_journal.expected_export_capture:return _fail("legacy_save_boss_restore_conflict_preserve_current_state")
	if current!=_legacy_save_journal.before:director.import_state(_legacy_save_journal.before)
	return {"ok":director.export_state()==_legacy_save_journal.before}

func rollback() -> Dictionary:
	if state=="DISCARD_HELD":return _fail("transition_discard_held_no_automatic_retry")
	var world: Node=_world.get_ref()
	if state=="ADOPTED":
		if world.field_population!=population or world.monsters_root!=stage.transferred_container():
			state="RESTORE_CONFLICT";return _fail("population_restore_conflict_preserve_current_owner")
		world.monsters_root=previous.root;world.field_population=previous.population;world.original_population=previous.original
		previous.root.process_mode=previous.root_mode;previous.root.visible=previous.root_visible;previous.population.process_mode=previous.population_mode
		world.rng.seed=stage.snapshot.rng_seed;world.rng.state=stage.snapshot.rng_state
		_population_restore_ready=true
		state="CATALOG_COMMITTED"
	var legacy_restored: Dictionary=_restore_legacy_save_capture()
	if legacy_restored.get("ok")!=true:
		state="RESTORE_CONFLICT";return _fail(str(legacy_restored.get("reason","legacy_population_restore_conflict")))
	if not commit_receipt.is_empty():
		restore_receipt=catalog.restore_actor_batch(batch.candidate)
		if restore_receipt.get("ok")!=true:
			state="RESTORE_CONFLICT";return _fail(str(restore_receipt.get("reason","catalog_restore_failed")))
	state="CATALOG_RESTORED"
	# Release only metadata for the proved first route rejection, after the
	# actual catalog restore and before disposal erases the staged snapshot.
	if not route_rejection.is_empty() and not attempt_requested and not actions_prepared.is_empty():
		discard_receipt=world.discard_current523_transition_actions(actions_prepared.token,int(actions_prepared.combat_generation))
		if discard_receipt.get("ok")!=true or discard_receipt.get("discarded")!=true or discard_receipt.get("transient_mutation")!=false or discard_receipt.get("authorizes_transition")!=false:
			state="DISCARD_HELD";return _fail("transition_discard_rejected_preserve_recovery")
	state="RESTORED";_dispose_owned()
	return {"ok":true,"state":state,"catalog_restore":restore_receipt.duplicate(true)}

func _action_context(world: Node) -> Array:
	# Independently compare the actual accepted field/owners around the receiver.
	# This is a map-owned observation, not a fabricated receiver response.
	var source: Dictionary={}
	if is_instance_valid(world.field_map) and world.field_map.get_meta("current523_generic_field",false)==true:
		for key: String in ["native_land","definition","catalog_sha256","source_asset"]:
			var value: Variant=world.field_map.get(key)
			source[key]=value.duplicate(true) if value is Dictionary or value is Array else value
	return [world.field_map,world.monsters_root,world.field_population,world.player,str(world.active_map_id),source]

func _current_save_matches(payment: Dictionary, world: Node) -> bool:
	var path: Variant=world.save_path()
	var fingerprint: Variant=payment.get("save_fingerprint")
	if not path is String or path.is_empty() or not fingerprint is Dictionary:return false
	var hash: Variant=fingerprint.get("sha256")
	if fingerprint.get("ok")!=true or fingerprint.get("exists")!=true or not hash is String or hash.length()!=64 or not hash.is_valid_hex_number(false):return false
	if payment.get("save_path_sha256")!=path.sha256_text() or not FileAccess.file_exists(path):return false
	return FileAccess.get_sha256(path)==hash

func post_save_hold() -> bool:
	return state in ["SAVE_UNCERTAIN","SAVE_PROOF_REJECTED","FINISH_CONFLICT","CATALOG_FINISHED","CLEANUP_RUNNING","CLEANUP_CONFLICT","CLEANUP_UNCERTAIN"]

func finish(payment: Dictionary) -> Dictionary:
	var world: Node=_world.get_ref()
	if state=="FINISHED":
		# A callback never cleans or enables actors twice. Its original proof
		# and current accepted context must still match for idempotent success.
		if payment!=_finished_payment or _action_context(world)!=_finished_context or world.combat_generation!=actions_prepared.combat_generation or catalog.source_model_sha256!=commit_receipt.model_sha256:return _fail("completed_map_transition_context_changed")
		var repeated: Dictionary=_finished_result.duplicate(true);repeated["already_finished"]=true
		return repeated
	if post_save_hold():return _fail("transition_completion_held_no_automatic_retry")
	if state!="ADOPTED":return _fail("adopted_population_required")
	if payment.get("uncertain")==true:
		state="SAVE_UNCERTAIN";return _fail("existing_save_owner_reload_required")
	# Require the actual map payment owner's authoritative success and freshly
	# fingerprinted write. Neither a receipt string nor catalog adoption is a save.
	var changes: Dictionary=stage.selected_request().get("host_transition",{}).get("save_changes",{})
	if payment.get("ok")!=true or payment.get("saved")!=true or payment.get("save_error")!=OK or payment.get("rollback_allowed")!=false or payment.get("uncertain")!=false or payment.get("prepared_changes_sha256")!=JSON.stringify(changes,"",true,true).sha256_text() or not _current_save_matches(payment,world):
		state="SAVE_PROOF_REJECTED";return _fail("authoritative_map_save_proof_required")
	if world.field_population!=population or world.original_population!=population or world.monsters_root!=stage.transferred_container() or population.generation!=int(batch.selection.population_generation)+1 or world.combat_generation!=actions_prepared.combat_generation or world.patch523_npc_spells.generation!=actions_prepared.combat_generation or catalog.source_model_sha256!=commit_receipt.model_sha256 or catalog.source_identity!=batch.source_identity or world.player.auto_enabled:
		state="FINISH_CONFLICT";return _fail("adopted_population_or_epoch_changed_before_finish")
	saved_proof={"kind":"twilight.current523.saved-map-transition.v1","token":actions_prepared.token,"world_instance":world.get_instance_id(),"player_instance":world.player.get_instance_id(),"combat_generation":world.combat_generation,"prior_actor_root_id":actions_prepared.prior_actor_root_id,"prior_population_id":actions_prepared.prior_population_id,"target_field_instance":stage.field.get_instance_id(),"target_actor_root_id":world.monsters_root.get_instance_id(),"target_population_id":population.get_instance_id(),"target_population_generation":population.generation,"target_land_id":stage.field.native_land.ID,"target_asset_path":stage.field.source_asset,"source_manifest_sha256":stage.field.catalog_sha256,"definition_manifest_sha256":stage.definition.manifest_sha256,"npc_model_sha256":commit_receipt.model_sha256,"batch_revision":commit_receipt.batch_revision,"save_fingerprint":payment.save_fingerprint.duplicate(true),"save_path_sha256":payment.save_path_sha256,"prepared_changes_sha256":payment.prepared_changes_sha256}
	committed_cleanup_receipt=JSON.stringify(saved_proof,"",true,true).sha256_text()
	note_transition_attempt("catalog_finish_attempted")
	finish_receipt=catalog.finish_actor_batch(batch.candidate)
	if finish_receipt.get("ok")!=true:
		state="FINISH_CONFLICT";return _fail(str(finish_receipt.get("reason","batch_finish_failed")))
	state="CATALOG_FINISHED"
	var accepted_context: Array=_action_context(world)
	state="CLEANUP_RUNNING"
	cleanup_receipt=world.cancel_current523_transition_actions(actions_prepared.token,int(actions_prepared.combat_generation),committed_cleanup_receipt)
	var explicit: bool=cleanup_receipt.get("ok")==true and cleanup_receipt.get("epoch_retained")==true and cleanup_receipt.get("player_buff_and_skill_state_preserved")==true and cleanup_receipt.get("combat_generation")==actions_prepared.combat_generation and cleanup_receipt.get("prior_actor_root_id")==actions_prepared.prior_actor_root_id and cleanup_receipt.get("prior_population_id")==actions_prepared.prior_population_id and cleanup_receipt.get("retired_actor_count")==actions_prepared.actor_count
	if not explicit or accepted_context!=_action_context(world) or world.combat_generation!=actions_prepared.combat_generation or world.patch523_npc_spells.generation!=actions_prepared.combat_generation or catalog.source_model_sha256!=commit_receipt.model_sha256 or catalog.source_identity!=batch.source_identity or world.player.auto_enabled or not _current_save_matches(payment,world):
		state="CLEANUP_UNCERTAIN" if cleanup_receipt.get("transient_mutation")==true else "CLEANUP_CONFLICT"
		return _fail(str(cleanup_receipt.get("reason","cleanup_receipt_or_context_mismatch")))
	# Receiver success precedes activation. It retires only departed transient
	# actions and retains the World epoch, NPC player buffs and skill state.
	world.pending_ground_pickup=null
	world.loot_pickup.map_changed();world.ground_loot.activate(str(stage.field.data.map_id))
	var root: Node2D=stage.transferred_container()
	root.process_mode=Node.PROCESS_MODE_INHERIT;root.show()
	population.process_mode=Node.PROCESS_MODE_INHERIT;population.set_process(true)
	for spec: Dictionary in stage.slots:
		var actor: Variant=spec.get("actor")
		if not is_instance_valid(actor):continue
		actor.process_mode=Node.PROCESS_MODE_INHERIT;actor.collision_layer=2;actor.collision_mask=4;actor.input_pickable=true;actor.show()
		population._update_activity(actor)
	_finished_payment=payment.duplicate(true);_finished_context=accepted_context
	state="FINISHED"
	_finished_result={"ok":true,"already_finished":false,"state":state,"population_adopted":true,"actors_active":true,"combat_generation":world.combat_generation,"committed_cleanup_receipt":committed_cleanup_receipt,"cleanup":cleanup_receipt.duplicate(true)}
	return _finished_result.duplicate(true)

func dispose_replaced() -> void:
	# Only a later accepted transaction or normal source exit calls this.
	if state!="FINISHED":return
	_dispose_owned();state="DISPOSED"

func _dispose_owned() -> void:
	var root: Node2D=stage.transferred_container() if _taken_root else null
	if is_instance_valid(root):
		root.process_mode=Node.PROCESS_MODE_DISABLED;root.hide()
		for actor: Node in root.get_children():
			if actor is TwilightMonster:actor.retire_prepared_source_record()
		if root.is_inside_tree():root.queue_free()
		else:root.free()
	if is_instance_valid(population):
		population.process_mode=Node.PROCESS_MODE_DISABLED
		if population.is_inside_tree():population.queue_free()
		else:population.free()
	if not _taken_root and is_instance_valid(stage.container):
		for actor: Node in stage.container.get_children():
			if actor is TwilightMonster:actor.retire_prepared_source_record()
	stage.discard()

func describe() -> Dictionary:
	return {"state":state,"reason":problem,"commit":not commit_receipt.is_empty(),"restore":restore_receipt.duplicate(true),"finish":finish_receipt.duplicate(true),"actions_prepared":actions_prepared.duplicate(true),"attempt_requested":attempt_requested,"attempt":attempt_receipt.duplicate(true),"attempt_history":attempt_history.duplicate(true),"recovery_evidence":recovery_evidence.duplicate(true),"route_rejection":route_rejection.duplicate(true),"discard":discard_receipt.duplicate(true),"cleanup":cleanup_receipt.duplicate(true),"committed_cleanup_receipt":committed_cleanup_receipt,"population_adopted":state in ["ADOPTED","FINISHED"] or post_save_hold(),"population_restored":_population_restore_ready,"executed_observation":false}
