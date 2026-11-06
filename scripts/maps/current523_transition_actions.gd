extends RefCounted
## Volatile cancellation receipts, not a save, teleport permission or buff clock.
var prepared: Dictionary={}
var receipts: Dictionary={}
var discarded: Dictionary={}

func failure(reason: String,epoch: int) -> Dictionary:
	return {"ok":false,"reason":reason,"combat_generation":epoch,"transient_mutation":false}

func context(world: Node) -> Array:
	var source: Dictionary={}
	if is_instance_valid(world.field_map) and world.field_map.get_meta("current523_generic_field",false)==true:
		for key: String in ["native_land","definition","catalog_sha256","source_asset"]:
			var value: Variant=world.field_map.get(key)
			source[key]=value.duplicate(true) if value is Dictionary or value is Array else value
	return [world.field_map,world.monsters_root,world.field_population,world.player,str(world.active_map_id),source]

# Capture the actual departing owner/lives BEFORE save or owner replacement.
func prepare(world: Node,root: Node2D,population: Node,before_attempt_guard: Callable=Callable()) -> Dictionary:
	var epoch: int=int(world.combat_generation)
	if not is_instance_valid(world.player):return failure("current_player_missing",epoch)
	if not is_instance_valid(root) or not is_instance_valid(population) or root!=world.monsters_root or population!=world.field_population or not world.is_ancestor_of(root) or not world.is_ancestor_of(population):return failure("departing_owner_not_current",epoch)
	if world.resolving_combat_action:return failure("combat_callback_in_progress",epoch)
	if int(world.patch523_npc_spells.generation)!=epoch:return failure("npc_service_epoch_not_current",epoch)
	var actors: Array=[];var queue: Array[Node]=[root]
	while not queue.is_empty():
		var node: Node=queue.pop_back()
		for child: Node in node.get_children():
			queue.append(child)
			if child is TwilightMonster:actors.append({"actor":weakref(child),"life":child.life_id})
	var token: String=Crypto.new().generate_random_bytes(16).hex_encode()
	while prepared.has(token) or receipts.has(token) or discarded.has(token):token=Crypto.new().generate_random_bytes(16).hex_encode()
	prepared[token]={"world":weakref(world),"root":weakref(root),"population":weakref(population),"player":weakref(world.player),"epoch":epoch,"actors":actors,"phase":"prepared","before_context":context(world),"abort_guard":before_attempt_guard}
	return {"ok":true,"token":token,"combat_generation":epoch,"prior_actor_root_id":root.get_instance_id(),"prior_population_id":population.get_instance_id(),"actor_count":actors.size(),"transient_mutation":false}

func prepared_context_matches(world: Node,capture: Dictionary,expected_epoch: int) -> bool:
	if capture.is_empty() or capture.world.get_ref()!=world or capture.epoch!=expected_epoch or int(world.combat_generation)!=expected_epoch:return false
	var root: Node=capture.root.get_ref();var population: Node=capture.population.get_ref()
	return is_instance_valid(root) and is_instance_valid(population) and world.is_ancestor_of(root) and world.is_ancestor_of(population) and root==world.monsters_root and population==world.field_population and capture.player.get_ref()==world.player and capture.before_context==context(world) and not world.resolving_combat_action and int(world.patch523_npc_spells.generation)==expected_epoch

func prepared_lives_match(capture: Dictionary) -> bool:
	var root: Node=capture.root.get_ref()
	for row: Dictionary in capture.actors:
		var actor: Node=row.actor.get_ref()
		if not is_instance_valid(actor) or actor.life_id!=row.life or not root.is_ancestor_of(actor):return false
	return true

# Mandatory barrier BEFORE options write/session switch/owner adoption/save.
# It records an attempt, not success, and never performs that attempt itself.
func begin_attempt(world: Node,token: String,expected_epoch: int) -> Dictionary:
	if receipts.has(token) or discarded.has(token):return failure("transition_not_uncommitted",int(world.combat_generation))
	var capture: Dictionary=prepared.get(token,{})
	if not prepared_context_matches(world,capture,expected_epoch) or capture.get("phase")!="prepared":return failure("transition_attempt_context_ambiguous",int(world.combat_generation))
	if not prepared_lives_match(capture):return failure("departing_actor_life_or_owner_changed",expected_epoch)
	capture["phase"]="attempt_started"
	return {"ok":true,"attempt_started":true,"combat_generation":expected_epoch,"transient_mutation":false}

# A stored Map-owned callback must prove its ACTUAL transaction has attempted
# neither owner adoption, save nor catalog finish. Missing/ambiguous proof holds.
# This releases metadata only; it is never rollback, refund or cleanup success.
func discard(world: Node,token: String,expected_epoch: int) -> Dictionary:
	if receipts.has(token):return failure("cleanup_receipt_must_be_preserved",int(world.combat_generation))
	if discarded.has(token):
		var tombstone: Dictionary=discarded[token]
		if tombstone.world!=world.get_instance_id() or tombstone.epoch!=expected_epoch:return failure("discard_token_collision",int(world.combat_generation))
		return {"ok":true,"discarded":true,"already_discarded":true,"transient_mutation":false,"authorizes_transition":false}
	var capture: Dictionary=prepared.get(token,{})
	if not prepared_context_matches(world,capture,expected_epoch) or capture.get("phase")!="prepared" or not prepared_lives_match(capture):return failure("discard_not_proven_uncommitted",int(world.combat_generation))
	var guard: Callable=capture.abort_guard
	if not guard.is_valid():return failure("map_before_attempt_witness_required",expected_epoch)
	capture["phase"]="discard_checking"
	var proof: Variant=guard.call(token,expected_epoch)
	var safe: bool=proof is Dictionary and proof.get("ok")==true and proof.get("token")==token and proof.get("combat_generation")==expected_epoch and proof.get("abort_kind")=="registered_cross_land_route_rejected" and proof.get("catalog_restore_confirmed")==true and proof.get("options_write_attempted")==false and proof.get("owner_adoption_attempted")==false and proof.get("save_attempted")==false and proof.get("catalog_finish_attempted")==false
	if not safe or receipts.has(token) or not prepared_context_matches(world,capture,expected_epoch) or capture.get("phase")!="discard_checking" or not prepared_lives_match(capture):
		if capture.get("phase")=="discard_checking":capture["phase"]="prepared"
		return failure("map_uncommitted_phase_not_proven",int(world.combat_generation))
	discarded[token]={"world":world.get_instance_id(),"epoch":expected_epoch}
	prepared.erase(token)
	return {"ok":true,"discarded":true,"already_discarded":false,"combat_generation":expected_epoch,"transient_mutation":false,"authorizes_transition":false}

# ONLY after the map owner has confirmed its save and catalog adoption. Actors
# must remain disabled until this returns ok. No rollback/refund/retry here.
func cancel(world: Node,token: String,expected_epoch: int,committed_receipt: String) -> Dictionary:
	var epoch: int=int(world.combat_generation)
	if receipts.has(token):
		var previous: Dictionary=receipts[token]
		if previous.world!=world.get_instance_id() or previous.epoch!=expected_epoch or previous.receipt!=committed_receipt:return failure("transition_receipt_collision",epoch)
		if epoch!=expected_epoch or (previous.get("complete",false) and previous.context!=context(world)):return failure("completed_transition_context_changed",epoch)
		if previous.get("complete",false)!=true:return {"ok":false,"reason":"cleanup_outcome_uncertain","combat_generation":epoch,"transient_mutation":true}
		var repeated: Dictionary=previous.result.duplicate(true);repeated["already_applied"]=true
		return repeated
	var capture: Dictionary=prepared.get(token,{})
	if capture.is_empty() or committed_receipt.is_empty() or capture.world.get_ref()!=world or expected_epoch!=epoch or capture.epoch!=epoch:return failure("transition_owner_epoch_or_receipt_mismatch",epoch)
	if capture.get("phase")!="attempt_started":return failure("transition_attempt_barrier_required",epoch)
	var root: Node=capture.root.get_ref();var population: Node=capture.population.get_ref()
	if not is_instance_valid(root) or not is_instance_valid(population) or capture.player.get_ref()!=world.player or world.resolving_combat_action or int(world.patch523_npc_spells.generation)!=epoch:return failure("departing_owner_or_player_changed",epoch)
	for row: Dictionary in capture.actors:
		var actor: Node=row.actor.get_ref()
		if not is_instance_valid(actor) or actor.life_id!=row.life or not root.is_ancestor_of(actor):return failure("departing_actor_life_or_owner_changed",epoch)
	# Mark started before cancellation signals can re-enter this owner. A runtime
	# interruption keeps a held receipt, never a second automatic cleanup.
	var committed_context: Array=context(world)
	receipts[token]={"world":world.get_instance_id(),"epoch":epoch,"receipt":committed_receipt,"complete":false,"context":committed_context}
	world._cancel_player_attack(int(world.pending_attack.get("id",-1)))
	world.pending_attack.clear()
	world._clear_skill_charge()
	world.halphas_star.combat.cancel_charge()
	world.player.cancel_attack()
	world.player.velocity=Vector2.ZERO
	world.player.clear_click_path()
	world.player.set_touch_vector(Vector2.ZERO)
	if is_instance_valid(world.combat_flights):world.combat_flights.clear()
	for row: Dictionary in capture.actors:
		var actor: Node=row.actor.get_ref()
		# Existing retirement owner removes only this departed actor's actions/
		# self state, never NPC-applied player buffs or shared skill lifetimes.
		world.patch523_npc_spells.forget(actor)
		actor.source_boss_combat._cancel_pending_motion()
		actor.motion.cancel_attack()
	world.selected_monster=null;world.auto_target=null
	world.auto_target_failed_paths.clear()
	world.auto_target_next_search_ms=0;world.auto_target_failed_search_actor_count=-1
	world.auto_repath_timer=0.0;world.auto_attack_timer=0.0;world.auto_stuck_time=0.0
	world.manual_route_pending_target=Vector2.INF
	if is_instance_valid(world.world_interactions):world.world_interactions.clear_selection()
	world.loot_pickup.cancel()
	if is_instance_valid(world.hud):world.hud.clear_target()
	if epoch!=int(world.combat_generation) or committed_context!=context(world):return {"ok":false,"reason":"context_changed_during_cleanup","combat_generation":int(world.combat_generation),"transient_mutation":true}
	var result: Dictionary={"ok":true,"already_applied":false,"combat_generation":epoch,"transient_mutation":true,"retired_actor_count":capture.actors.size(),"prior_actor_root_id":root.get_instance_id(),"prior_population_id":population.get_instance_id(),"player_buff_and_skill_state_preserved":true,"epoch_retained":true}
	receipts[token]["complete"]=true;receipts[token]["result"]=result.duplicate(true)
	prepared.erase(token)
	return result
