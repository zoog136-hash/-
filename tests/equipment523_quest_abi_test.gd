extends SceneTree
## Genuine source acquisition plus read-only ownership ABI candidates. No
## candidate consumption is saved/adopted and no processing recipe is invented.
const QA = preload("res://tests/qa_class_selection.gd")
const Host = preload("res://tests/equipment523_quest_abi_world.gd")
var ABI: Variant
var OWN: Variant
var SOURCE: Variant
const PROOF: String = "user://equipment523-quest-abi-proof.json"
const QUEST_SHA: String = "2d11ecff4e695244220dc8e3a9b5707809f8bcfe34d7789a517880a6590bcb9a"
const QUEST_BYTES: int = 9884157
const CHAIN: Array[int] = [236,237,238,239,240,241,244,245,246,247,248,249,250,251,252,254]
var checks: int = 0
var failures: Array[String] = []
var blockers: Array[String] = []
var projection_verified: bool = false
var genuine_grant: bool = false
var abi_candidate_checks: bool = false
var source_quote_denials: Array[Dictionary] = []
var reload_mode: bool = false

func _initialize() -> void:
	reload_mode = "--equipment523-quest-abi-reload-proof" in OS.get_cmdline_user_args()
	call_deferred("_reload_proof" if reload_mode else "_run")

func _load_owners() -> bool:
	# Optional public dependency closure. Check files before loading any script,
	# so an ordinary older checkout reports a blocker without a preload error.
	var paths: Array[String] = ["quests/quest_reward_consumption.gd","quests/quest_reward_ownership.gd","quests/source_quest523.gd","quests/quest_service.gd","quests/quest_item_bindings.gd","quests/quest_auto_runner.gd","quests/quest_item_provider238.gd","quests/quest_held_use238.gd","quests/quest_choice523.gd","quests/quest_regen523.gd","quests/quest_skillbooks523.gd","quests/quest_equipment523.gd","quests/quest_fixed_cards523.gd","quests/quest_reference_learning.gd","loot/quest_hp233_use.gd","loot/patch523_item_use.gd","loot/patch523_skill_book.gd","loot/patch523_item_catalog.gd","loot/currency_drops.gd","loot/patch523_monster_drops.gd","loot/patch523_item_inventory.gd","loot/patch523_ammo.gd","ui/patch523_reward_choice.gd","lineagem_pack_install.gd","lineagem_base508.gd","skills/save_writer.gd","monsters/base508_authoritative_catalog.gd","monsters/base508_monster_context.gd","card_draw_fusion.gd"]
	for path: String in paths:
		if not ResourceLoader.exists("res://scripts/"+path): blockers.append("Optional published quest dependency is unavailable: "+path)
	if not blockers.is_empty(): return false
	ABI = load("res://scripts/quests/quest_reward_consumption.gd")
	OWN = load("res://scripts/quests/quest_reward_ownership.gd")
	SOURCE = load("res://scripts/quests/source_quest523.gd")
	if ABI == null or OWN == null or SOURCE == null:
		blockers.append("Optional published quest owners could not be loaded.")
		return false
	return true

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EQUIPMENT523_QUEST_ABI_FAIL ",label)

func _args() -> Dictionary:
	var result: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		for key: String in ["rules","sha256","effects","effects-sha256"]:
			var prefix: String = "--equipment523-"+key+"="
			if arg.begins_with(prefix): result[key] = arg.trim_prefix(prefix)
		for key: String in ["projection","projection-sha256"]:
			var prefix: String = "--quest523-"+key+"="
			if arg.begins_with(prefix): result[key] = arg.trim_prefix(prefix)
	return result

func _install_projection(args: Dictionary) -> bool:
	if "--equipment523-quest-abi-isolated" not in OS.get_cmdline_user_args():
		blockers.append("Explicit --equipment523-quest-abi-isolated and a fresh user profile are required.")
		return false
	if args.size() != 6:
		blockers.append("Three explicit private cache paths and their SHA arguments are required.")
		return false
	for existing_path: String in [SOURCE.USER_PATH,"user://twilight_v20_save.json","user://twilight_native_png_save.json","user://twilight_growth_lab_v1.json"]:
		if FileAccess.file_exists(existing_path):
			blockers.append("Fresh isolated profile required; existing file preserved: "+existing_path)
			return false
	var path: String = str(args.projection)
	if str(args["projection-sha256"]) != QUEST_SHA or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != QUEST_SHA:
		blockers.append("The exact verified current523 quest projection is unavailable.")
		return false
	var file: FileAccess = FileAccess.open(path,FileAccess.READ)
	if file == null: return false
	var length: int = file.get_length()
	file.close()
	if length != QUEST_BYTES:
		blockers.append("Unexpected source projection byte count.")
		return false
	var code: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(SOURCE.USER_PATH))
	projection_verified = code == OK and FileAccess.get_sha256(SOURCE.USER_PATH) == QUEST_SHA
	_check(projection_verified,"copy the exact source projection only into the explicit fresh private profile")
	return projection_verified

func _freeze(world: Node) -> void:
	world.set_process(false)
	world.set_physics_process(false)
	world.save_timer = -100000.0
	world.deferred_save_enabled = true
	world.deferred_save.cancel()
	world.player.set_physics_process(false)
	world.player.auto_enabled = false
	world.monsters_root.process_mode = Node.PROCESS_MODE_DISABLED
	for population: Variant in [world.field_population,world.legacy_population,world.original_population]:
		if is_instance_valid(population):
			population.set_process(false)
			population.set_physics_process(false)

func _spawn() -> Node:
	var scene: PackedScene = load("res://Main.tscn")
	_check(scene != null,"actual Main scene loads")
	if scene == null: return null
	var world: Node = scene.instantiate()
	var attached: Error = Host.attach(world)
	_check(attached == OK,"attach the QA writer observer without redeclaring inherited quest owners")
	if attached != OK:
		blockers.append("QA observer attachment refused: "+str(attached))
		world.free()
		return null
	world.set_process(false)
	world.set_physics_process(false)
	root.add_child(world)
	_freeze(world)
	await process_frame
	_check(QA.enter_game(world),"actual Main character confirmation")
	_freeze(world)
	world.quest_item_provider.configure(world)
	world.quest_auto.refresh_context(world)
	return world

func _state(world: Node) -> String:
	return JSON.stringify([world.inventory,world.item_instances,world.quest_service.export_state(),world.gold,world.next_item_instance_id,world.level,world.experience,world.exp_need,world.max_hp,world.max_mp,world.hp,world.mp,world.attack_power,world.defense,world.stat_points,world.rng.state])

func _disk(world: Node) -> String:
	return FileAccess.get_sha256(world.save_path()) if FileAccess.file_exists(world.save_path()) else "missing"

func _request(world: Node, owned: Dictionary, amount: int) -> Dictionary:
	return {"physical_id":str(owned.physical_id),"quantity":amount,"expected_quantity":int(owned.quantity),"expected_remaining":int(owned.quantity)-amount,"quest_reward_receipt":world.item_instances[str(owned.physical_id)].quest_reward_receipt.duplicate(true)}

func _info(owned: Dictionary) -> Dictionary:
	# Only OWN.proof of the genuine selected grant may create an ABI test input.
	return {"instance_id":str(owned.physical_id),"source_id":int(owned.item_class_id),"quantity":int(owned.quantity),"quest_reward_receipt":true}

func _find_grant(world: Node) -> String:
	var found: Array[String] = []
	for id: String in world.item_instances:
		var receipt: Dictionary = world.item_instances[id].get("quest_reward_receipt",{})
		if receipt.get("quest_id") == "m523:quest:254" and int(receipt.get("reward_id",0)) == 28481 and int(receipt.get("item_class_id",0)) == 313: found.append(id)
	return found[0] if found.size() == 1 else ""

func _run() -> void:
	if not _load_owners():
		_finish()
		return
	var args: Dictionary = _args()
	if not _install_projection(args):
		_finish()
		return
	_check(not OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty(),"explicit source map pack for the actual Main writer")
	var world: Node = await _spawn()
	if world == null:
		_finish()
		return
	var service = world.equipment523
	_check(world.quest_service.source.quests.size() == 3621 and world.quest_service.source.loaded_path == SOURCE.USER_PATH,"public source loader validates the complete unmodified private projection")
	_check(bool(service.install(world,str(args.rules),str(args.sha256)).get("ok",false)),"actual service installs the verified processing base")
	_check(bool(service.install(world,str(args.effects),str(args["effects-sha256"])).get("ok",false)),"actual service installs the verified effects supplement")
	if service.store.pack.is_empty() or service._quest_consumer(world) == null:
		blockers.append("The verified processing pack or exact quest consumption owner is unavailable.")
		world.queue_free()
		await process_frame
		_finish()
		return
	var ids: Array[String] = []
	for id: int in CHAIN:
		ids.append("m523:quest:"+str(id))
		_check(world.quest_service.index.has(ids.back()) and not world.quest_service.claimed.has(ids.back()),"real source chain starts unclaimed: "+str(id))
	var before: String = _state(world)
	var disk_before: String = _disk(world)
	var attempts: int = int(world.qa_quest_save_attempts)
	var writes: int = int(world.qa_quest_writer_calls)
	world.qa_quest_reject_next_save = true
	_check(not world.quest_auto.complete(world,ids),"injected pre-writer failure refuses the genuine source reward transaction")
	_check(_state(world) == before and _disk(world) == disk_before,"failed genuine grant preserves claims, physical ownership, progression, RNG and save bytes")
	_check(int(world.qa_quest_save_attempts) == attempts+1 and int(world.qa_quest_writer_calls) == writes,"failed grant neither retries nor reaches the durable writer")
	var complete: bool = world.quest_auto.complete(world,ids)
	_check(complete,"real public QuestAutoRunner completes the ordered original chain through the real Main writer")
	if not complete:
		world.quest_auto.refresh_context(world)
		for id: String in ids:
			var quest: Dictionary = world.quest_service.index.get(id,{})
			if not quest.is_empty(): blockers.append(id+": "+str(world.quest_auto.failures.get(id,world.quest_service.source.gate(quest,world.quest_auto.context,world.quest_service.claimed,int(Time.get_unix_time_from_system())))))
		world.queue_free()
		await process_frame
		_finish()
		return
	_check(int(world.qa_quest_save_attempts) == attempts+2 and int(world.qa_quest_writer_calls) == writes+1,"successful ordered batch reaches the actual writer exactly once")
	for id: String in ids: _check(world.quest_service.claimed.get(id) == true,"actual source claim persisted: "+id)
	var physical_id: String = _find_grant(world)
	_check(not physical_id.is_empty(),"the genuine quest254 reward28481 uniquely grants item313")
	if physical_id.is_empty():
		world.queue_free()
		await process_frame
		_finish()
		return
	var owned: Dictionary = OWN.proof(world,physical_id)
	genuine_grant = bool(owned.get("ok",false)) and int(owned.get("quantity",0)) == 5
	_check(genuine_grant,"real claimed/source/index/receipt ownership proves exactly five held units")
	if genuine_grant:
		_test_candidates(world,owned)
		_test_source_denial(world,physical_id)
	var receipt: Dictionary = world.item_instances[physical_id].quest_reward_receipt.duplicate(true)
	var grant_disk: String = _disk(world)
	var quest_state: Dictionary = world.quest_service.export_state()
	world.queue_free()
	await process_frame
	world = await _spawn()
	if world != null:
		_check(_disk(world) == grant_disk,"reconnect preserves the exact genuine-grant save bytes")
		_check(_find_grant(world) == physical_id and OWN.proof(world,physical_id).get("ok",false),"actual Main reconnect retains the original physical receipt identity")
		_check(ABI.same(world.item_instances.get(physical_id,{}).get("quest_reward_receipt",{}),receipt) and int(world.item_instances.get(physical_id,{}).get("source_reward_quantity",0)) == 5,"staging partial/zero candidates never debits or rewrites the durable grant")
		_check(ABI.same(world.quest_service.export_state(),quest_state),"reconnect preserves the quest ledger without adopting any candidate consumption")
		if failures.is_empty() and blockers.is_empty(): _write_proof(world,physical_id,receipt,quest_state,grant_disk)
		world.queue_free()
		await process_frame
	_finish()

func _write_proof(world: Node, id: String, receipt: Dictionary, quest_state: Dictionary, save_sha: String) -> void:
	var proof: Dictionary = {"physical_id":id,"quest_reward_receipt":receipt.duplicate(true),"quest_state":quest_state.duplicate(true),"save_sha256":save_sha,"base_sha256":str(world.equipment523.store.sha256),"effects_sha256":str(world.equipment523.store.effects_sha256)}
	var output: FileAccess = FileAccess.open(PROOF,FileAccess.WRITE)
	_check(output != null,"write the minimal proof only in the isolated user profile")
	if output == null: return
	output.store_string(JSON.stringify(proof))
	output.flush()
	var error: Error = output.get_error()
	output.close()
	_check(error == OK,"flush the isolated proof without source rows or a consumption candidate")

func _reload_proof() -> void:
	if not _load_owners():
		_finish()
		return
	_check(_args().is_empty(),"fresh-process proof receives no projection, base or effects cache paths or SHAs")
	if not _args().is_empty():
		_finish()
		return
	_check(FileAccess.file_exists(PROOF),"fresh process requires the initial isolated acquisition proof")
	if not FileAccess.file_exists(PROOF):
		_finish()
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROOF))
	_check(value is Dictionary,"isolated acquisition proof parses")
	if not value is Dictionary:
		_finish()
		return
	var proof: Dictionary = value
	var path: String = str(SOURCE.USER_PATH)
	projection_verified = FileAccess.file_exists(path) and FileAccess.get_sha256(path) == QUEST_SHA
	_check(projection_verified,"fresh process verifies the installed user projection SHA without cache CLI arguments")
	var file: FileAccess = FileAccess.open(path,FileAccess.READ) if projection_verified else null
	_check(file != null and file.get_length() == QUEST_BYTES,"fresh process verifies the installed projection byte count")
	if file != null: file.close()
	if not projection_verified:
		_finish()
		return
	var world: Node = await _spawn()
	if world == null:
		_finish()
		return
	_check(world.quest_service.source.quests.size() == 3621 and world.quest_service.source.loaded_path == SOURCE.USER_PATH,"fresh process loads all 3621 genuine source quest rows")
	var id: String = str(proof.get("physical_id",""))
	var owned: Dictionary = OWN.proof(world,id)
	genuine_grant = bool(owned.get("ok",false)) and int(owned.get("quantity",0)) == 5
	_check(genuine_grant and _find_grant(world) == id,"fresh process proves the same actual five-unit quest254 reward28481 grant")
	_check(ABI.same(world.item_instances.get(id,{}).get("quest_reward_receipt",{}),proof.get("quest_reward_receipt")),"fresh process preserves the immutable original receipt")
	_check(ABI.same(world.quest_service.export_state(),proof.get("quest_state")),"fresh process preserves the original quest ledger")
	_check(_disk(world) == str(proof.get("save_sha256","")),"fresh process preserves the exact original acquisition save bytes")
	_check(not world.equipment523.store.pack.is_empty() and world.equipment523.store.sha256 == proof.get("base_sha256") and world.equipment523.store.effects_sha256 == proof.get("effects_sha256"),"fresh process restores the base and effects cache pointers without private cache CLI paths")
	world.queue_free()
	await process_frame
	_finish()

func _test_candidates(world: Node, owned: Dictionary) -> void:
	var before: String = _state(world)
	var disk_before: String = _disk(world)
	var attempts: int = int(world.qa_quest_save_attempts)
	var digest: String = str(world.equipment523.store.sha256)
	var partial: Dictionary = ABI.stage(world,[_request(world,owned,1)],digest)
	_check(bool(partial.get("ok",false)) and partial.get("use_authorized") == false,"ABI staging proves only ownership debit, never effect authorization")
	if not partial.get("ok",false):
		blockers.append("Genuine ownership staging refused: "+str(partial.get("reason","unknown")))
		return
	var id: String = str(owned.physical_id)
	var key: String = str(owned.inventory_key)
	var receipt: Dictionary = world.item_instances[id].quest_reward_receipt
	_check(int(partial.overrides.item_instances[id].source_reward_quantity) == 4 and int(partial.overrides.inventory[key]) == int(world.inventory[key])-1,"partial candidate uses the observed five-to-four remaining quantity")
	_check(ABI.same(partial.overrides.item_instances[id].quest_reward_receipt,receipt) and int(partial.overrides.item_instances[id].quest_reward_receipt.quantity) == 5,"partial candidate preserves the immutable five-unit grant receipt")
	_check(ABI.matches_payload(world,partial,partial.overrides),"the exact partial final payload matches its source-owned ledger candidate")
	var selected: Dictionary = world.equipment523._quest_stage(world,[_info(owned)],{id:1})
	_check(ABI.same(selected,partial),"service _quest_stage creates the same candidate from the genuine OWN.proof selection")
	var zero: Dictionary = ABI.stage(world,[_request(world,owned,5)],digest)
	_check(bool(zero.get("ok",false)) and not zero.get("overrides",{}).get("item_instances",{}).has(id),"zero candidate deletes the selected physical ID without applying it live")
	if zero.get("ok",false):
		_check(ABI.same(world.equipment523._quest_stage(world,[_info(owned)],{id:5}),zero),"service _quest_stage preserves the explicit zero remaining candidate")
		_check(ABI.matches_payload(world,zero,zero.overrides),"the exact fully consumed candidate matches its immutable ledger")
		var resurrected: Dictionary = zero.overrides.duplicate(true)
		resurrected.item_instances[id] = world.item_instances[id].duplicate(true)
		_check(not ABI.matches_payload(world,zero,resurrected),"final payload cannot resurrect a fully consumed selected ID")
	var overwritten: Dictionary = partial.overrides.duplicate(true)
	overwritten.inventory = world.inventory.duplicate(true)
	_check(not ABI.matches_payload(world,partial,overwritten),"another full inventory baseline cannot overwrite the staged selected debit")
	overwritten = partial.overrides.duplicate(true)
	overwritten.quest_state = world.quest_service.export_state()
	_check(not ABI.matches_payload(world,partial,overwritten),"another ledger baseline cannot erase the staged used count")
	overwritten = partial.overrides.duplicate(true)
	overwritten.item_instances[id].quest_reward_receipt.quantity = 4
	_check(not ABI.matches_payload(world,partial,overwritten),"a final payload cannot rewrite the original grant quantity")
	var tampered: Dictionary = _request(world,owned,1)
	tampered.quest_reward_receipt.reward_id = int(tampered.quest_reward_receipt.reward_id)+1
	_check(not ABI.stage(world,[tampered],digest).get("ok",false),"a request with a different source reward receipt is rejected")
	_check(not ABI.stage(world,[_request(world,owned,1),_request(world,owned,1)],digest).get("ok",false),"duplicate physical selections require one explicitly combined request")
	_check(not ABI.stage(world,[_request(world,owned,6)],digest).get("ok",false),"overconsumption cannot become an ownership candidate")
	var locks: Dictionary = world.ui_preferences.get("item_locks",{}).duplicate(true)
	world.ui_preferences["item_locks"] = locks.duplicate(true)
	world.ui_preferences.item_locks[key+"@@@"+id] = true
	_check(not ABI.stage(world,[_request(world,owned,1)],digest).get("ok",false) and not ABI.current(world,partial),"the real host physical-item lock refuses stage and stales an earlier candidate")
	world.ui_preferences["item_locks"] = locks
	var quantity: Variant = world.item_instances[id].source_reward_quantity
	world.item_instances[id].source_reward_quantity = int(quantity)-1
	_check(not ABI.current(world,partial) and not ABI.matches_payload(world,partial,partial.overrides),"a changed live remaining quantity makes an earlier candidate stale")
	world.item_instances[id].source_reward_quantity = quantity
	_test_batch(world,owned,digest)
	_check(_state(world) == before and _disk(world) == disk_before and int(world.qa_quest_save_attempts) == attempts,"all ABI partial/zero/batch/tamper tests leave live state, RNG, ledger and save bytes unchanged")
	abi_candidate_checks = true

func _test_batch(world: Node, selected: Dictionary, digest: String) -> void:
	var other: Dictionary = {}
	for id: String in world.item_instances:
		if id == str(selected.physical_id): continue
		var candidate: Dictionary = OWN.proof(world,id)
		if candidate.get("ok",false) and not candidate.get("source_use_immediately",true) and not candidate.get("source_item",{}).get("TestItem",true):
			other = candidate
			break
	_check(not other.is_empty(),"the actual source chain supplies another independently proven held reward for batch ABI QA")
	if other.is_empty(): return
	var requests: Array = [_request(world,selected,1),_request(world,other,1)]
	var step: Dictionary = ABI.stage(world,requests,digest)
	_check(bool(step.get("ok",false)) and step.get("selections",[]).size() == 2,"one batch stages both genuine selected receipts without baseline overwrite")
	if not step.get("ok",false): return
	_check(ABI.matches_payload(world,step,step.overrides),"one final candidate preserves both selected debits and cumulative quest ledger updates")
	var service_step: Dictionary = world.equipment523._quest_stage(world,[_info(selected),_info(other)],{str(selected.physical_id):1,str(other.physical_id):1})
	_check(ABI.same(service_step,step),"service _quest_stage batches multiple exact OWN.proof selections once")
	var payload: Dictionary = step.overrides.duplicate(true)
	payload.item_instances[str(other.physical_id)] = world.item_instances[str(other.physical_id)].duplicate(true)
	_check(not ABI.matches_payload(world,step,payload),"replacing another selected record with its old baseline is rejected")

func _test_source_denial(world: Node, id: String) -> void:
	var before: String = _state(world)
	var disk_before: String = _disk(world)
	var attempts: int = int(world.qa_quest_save_attempts)
	for kind: String in ["alchemy","invoke_replacement","elemental_smith","bless_reinforcement","smelt","spirit_smelt"]:
		var action: Dictionary = {"kind":kind,"target_id":"" if kind == "alchemy" else id,"material_ids":[id] if kind == "alchemy" else [],"recipe_type":63,"slot":3}
		var quote: Dictionary = world.equipment523.quote(world,action)
		_check(not quote.get("ok",false),"the actual source processing quote refuses unsupported genuine313: "+kind)
		source_quote_denials.append({"kind":kind,"reason":str(quote.get("error",quote.get("reason","")))})
	_check(_state(world) == before and _disk(world) == disk_before and int(world.qa_quest_save_attempts) == attempts,"source processing refusal preserves genuine ownership, RNG, ledger, quantities and durable bytes")

func _finish() -> void:
	print("EQUIPMENT523_QUEST_ABI_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"blockers":blockers,"reload_mode":reload_mode,"projection_sha256":QUEST_SHA,"projection_verified":projection_verified,"genuine_quest313_grant":genuine_grant,"abi_candidates_checked":abi_candidate_checks,"source_quote_denials":source_quote_denials,"scope":"GENUINE_SOURCE_QUEST_ACQUISITION_WRITE_REJECTION_RECONNECT_AND_READ_ONLY_ABI_STAGING; NO_PROCESSING_POSITIVE_OR_CONSUMPTION_SAVE"}))
	quit(0 if failures.is_empty() and blockers.is_empty() else 1)
