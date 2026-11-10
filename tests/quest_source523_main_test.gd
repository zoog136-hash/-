extends SceneTree
const SOURCE = preload("res://scripts/quests/source_quest523.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("QUEST523_MAIN_FAIL: "+label)
func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func run() -> void:
	var installed: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--quest-pack="):
			installed = SOURCE.install_zip(argument.trim_prefix("--quest-pack=")).ok
			check(installed,"received ZIP installed into a fresh consumer profile")
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate() as TwilightWorld
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	check(QA.enter_game(world),"real class creation")
	check(not world.source_save_blocked and world.field_map!=null,"real committed current-map pack loads")
	if installed: check(world.quest_service.source.loaded_path==SOURCE.USER_PATH,"actual Main uses the installed received bytes")
	check(world.quest_service.source.quests.size()==3621,"all original quests loaded into actual Main")
	if world.source_save_blocked or world.quest_service.source.quests.size()!=3621: quit(1);return
	world.gold = 7654321
	world.inventory["HP 물약"] = int(world.inventory.get("HP 물약",0))+7
	world.quest_service.claimed["twilight:main:001"] = true
	check(world._save_game(true)==OK,"baseline atomic save")
	var path: String = world.save_path()
	var prior_hash: String = FileAccess.get_sha256(path)
	var prior_inventory: Dictionary = world.inventory.duplicate(true)
	var prior_instances: Dictionary = world.item_instances.duplicate(true)
	var prior_quickslots: Array = world.quickslots.duplicate(true)
	var before_growth: Dictionary = {}
	for key: String in ["gold","level","experience","exp_need","hp","max_hp","mp","max_mp","attack_power","defense","stat_points"]: before_growth[key]=world.get(key)
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_FILE_CANT_WRITE
	check(not world.quest_auto.complete(world,["m523:quest:236"]),"failed atomic write rejects automatic reward")
	check(FileAccess.get_sha256(path)==prior_hash and world.inventory==prior_inventory and world.item_instances==prior_instances,"failed transaction preserves disk, items and physical IDs")
	for key: String in before_growth: check(world.get(key)==before_growth[key],"failure restores "+key)
	check(not world.quest_service.claimed.has("m523:quest:236"),"failed transaction leaves original quest unclaimed")
	world.equipment_collections.test_save_writer = Callable()
	world.quest_auto.retry_at = 0.0
	check(world.quest_auto.complete(world,["m523:quest:236"]),"original starting quest completes with zero goal progress and no claim button")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(disk.quest_state.claimed.has("m523:quest:236") and disk.quest_state.claimed.has("twilight:main:001"),"source and historical claims commit together")
	for key: String in ["level","experience","exp_need","hp","max_hp","mp","max_mp","defense","stat_points"]: check(disk[key]==world.get(key),"EXP/level growth durable: "+key)
	var once_hash: String = FileAccess.get_sha256(path)
	check(not world.quest_auto.complete(world,["m523:quest:236"]) and FileAccess.get_sha256(path)==once_hash,"duplicate request cannot pay or rewrite")
	world.quest_auto.refresh_context(world)
	var uncertain_id: String = ""
	for row: Dictionary in world.quest_service.source.quests:
		if world.quest_service.claimed.has(str(row.id)): continue
		if world.quest_service.source.gate(row,world.quest_auto.context,world.quest_service.claimed,int(Time.get_unix_time_from_system())).is_empty() and world.quest_service.source.reward_plan(row,world.quest_auto.context).ok:
			uncertain_id = str(row.id)
			break
	check(not uncertain_id.is_empty(),"a real second acquired quest exists for post-write recovery")
	world.equipment_collections.test_save_writer = func(target: String,data: Dictionary) -> Error:
		var written: Error = WRITER.write(target,data)
		return ERR_FILE_CANT_WRITE if written==OK else written
	if not uncertain_id.is_empty():
		check(world.quest_auto.complete(world,[uncertain_id]),"post-write error is confirmed from complete disk transaction")
		check(world.quest_service.claimed.has(uncertain_id),"confirmed committed reward is acknowledged once")
	world.equipment_collections.test_save_writer = Callable()
	check(world._save_game(true)==OK,"confirmed write adopts the existing stale-write guard identity")
	# Drive the production acquisition loop to a fixed point over every source
	# row, including all newly unlocked prerequisites and EXP level changes.
	var batches: int = 0
	for step: int in range(3622):
		var before: int = world.quest_service.claimed.size()
		world.quest_auto.next_scan = 0.0
		world.quest_auto.retry_at = 0.0
		world.quest_auto.auto_claim=true;world.quest_auto.tick(world)
		if world.quest_service.claimed.size()==before: break
		batches += 1
	world.quest_auto.refresh_context(world)
	var counts: Dictionary = {"completed":0,"pending_use_completed":0,"excluded":0,"locked_or_deferred":0}
	var reasons: Dictionary = {}
	var capabilities: Dictionary = {"reward_storage_supported":0,"with_items_pending_use":0,"unsupported_reasons":{}}
	for row: Dictionary in world.quest_service.source.quests:
		var checked_plan: Dictionary = world.quest_service.source.reward_plan(row,world.quest_auto.context)
		if checked_plan.ok:
			capabilities.reward_storage_supported+=1
			if not checked_plan.pending_use.is_empty(): capabilities.with_items_pending_use+=1
		else:
			var unsupported: String = str(checked_plan.error)
			capabilities.unsupported_reasons[unsupported]=int(capabilities.unsupported_reasons.get(unsupported,0))+1
		if world.quest_service.claimed.has(str(row.id)):
			counts.completed += 1
			if not world.quest_service.source.reward_plan(row,world.quest_auto.context).get("pending_use",[]).is_empty(): counts.pending_use_completed += 1
		else:
			var reason: String = world.quest_service.source.gate(row,world.quest_auto.context,world.quest_service.claimed,int(Time.get_unix_time_from_system()))
			if reason.is_empty(): reason=str(world.quest_service.source.reward_plan(row,world.quest_auto.context).get("error",""))
			check(not reason.is_empty(),"no payable acquired quest remains at fixed point")
			reasons[reason]=int(reasons.get(reason,0))+1
			if not row.excluded_reasons.is_empty(): counts.excluded+=1
			else: counts.locked_or_deferred+=1
	var held_totals: Dictionary = {}
	for physical: Dictionary in world.item_instances.values():
		if bool(physical.get("record",{}).get("source_pending_use",false)):
			var name_value: String = str(physical.name)
			held_totals[name_value]=int(held_totals.get(name_value,0))+int(physical.get("source_reward_quantity",1))
	for name_value: String in held_totals: check(held_totals[name_value]==world.inventory[name_value],"native reward stack quantity survives physical identity projection")
	var receipt_count: int = 0
	var receipts_match: bool = true
	for physical_id: String in world.item_instances:
		if prior_instances.has(physical_id): continue
		var physical: Dictionary = world.item_instances[physical_id]
		var receipt: Dictionary = physical.get("quest_reward_receipt",{})
		receipt_count += 1
		receipts_match = receipts_match and int(receipt.get("schema",0))==1 and world.quest_service.claimed.has(str(receipt.get("quest_id",""))) and receipt.get("source_sha256")==SOURCE.SOURCE_SHA and int(receipt.get("item_class_id",0))==int(physical.record.source_item_class_id) and int(receipt.get("quantity",0))==int(physical.get("source_reward_quantity",1))
	check(receipt_count>0 and receipts_match,"every actual new physical reward stores its source and committed quest receipt")
	check(not held_totals.is_empty(),"real source reward exists for merged inventory protection check")
	if not held_totals.is_empty():
		var held_name: String = str(held_totals.keys()[0])
		var held_before: Dictionary = world.inventory.duplicate(true)
		var held_disk: String = FileAccess.get_sha256(path)
		world._on_inventory_item_activated(held_name)
		world._use_quick_item(held_name)
		check(world.inventory==held_before and FileAccess.get_sha256(path)==held_disk,"merged use guards preserve held source reward and save bytes")
		check(world.inventory_automation._protected(held_name,"","deposit") and world.inventory_automation._protected(held_name,"","sell"),"merged inventory automation protects held source rewards from transfer and sale")
	for id: String in prior_instances: check(world.item_instances.get(id)==prior_instances[id],"existing physical item is unchanged")
	check(int(world.inventory.get("HP 물약",0))==int(prior_inventory["HP 물약"]),"prior consumables preserved")
	check(world.quickslots==prior_quickslots,"original tutorial registrations preserve all existing user bindings")
	check(world.quest_service.ui_requests.has("m523:quest:59912"),"native tutorial parameters are recorded without blocking its quest chain")
	var good_bytes: String = FileAccess.get_file_as_string(path)
	var good: Dictionary = JSON.parse_string(good_bytes)
	world._load_game(true)
	check(not world.quest_service.save_blocked and normalized(world.quest_service.claimed)==good.quest_state.claimed,"all source and legacy completion states reload")
	check(normalized(world.inventory)==good.inventory and normalized(world.item_instances)==good.item_instances,"every awarded source item and ID reloads unchanged")
	check(world.gold==good.gold and world.level==good.level and world.experience==good.experience,"native currency and EXP survive reload")
	var corrupt: Dictionary = good.duplicate(true)
	corrupt.quest_state.claimed["m523:quest:236"] = 1
	check(WRITER.write(path,corrupt)==OK,"create isolated corrupt-save case")
	var corrupt_hash: String = FileAccess.get_sha256(path)
	world._load_game(true)
	check(world.quest_service.save_blocked,"malformed completion is rejected before state mutation")
	check(world._save_game(true)!=OK and FileAccess.get_sha256(path)==corrupt_hash,"corrupt source save cannot be overwritten")
	check(WRITER.write_text(path,good_bytes)==OK,"restore isolated valid save")
	world._load_game(true)
	check(not world.quest_service.save_blocked,"valid reload recovers saving")
	var claimed: Dictionary = world.quest_service.claimed.duplicate(true)
	var inventory: Dictionary = world.inventory.duplicate(true)
	var previous_runner: WeakRef = weakref(world.quest_auto)
	world.queue_free()
	await process_frame
	check(previous_runner.get_ref()==null,"production item-consumer binding releases the quest runner on restart")
	var restarted: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate() as TwilightWorld
	root.add_child(restarted)
	restarted.set_process(false)
	restarted.player.set_physics_process(false)
	check(restarted.quest_service.claimed==claimed and restarted.inventory==inventory,"fresh Main instance preserves completion and rewards")
	var summary: Dictionary = {"checks":checks,"failures":failures,"source_quests":3621,"counts":counts,"reward_capabilities_current_game":capabilities,"batches":batches,"remaining_reasons":reasons,"initial_level":int(before_growth.level),"final_level":restarted.level,"physical_items":restarted.item_instances.size()}
	print("QUEST523_MAIN_RESULT "+JSON.stringify(summary))
	var output := FileAccess.open("user://quest523-main-coverage.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(summary,"\t"))
	restarted.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
