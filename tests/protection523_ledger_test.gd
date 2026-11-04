extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const Runtime = preload("res://scripts/protection/protection523_runtime.gd")
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	if "--material-contract-only" in OS.get_cmdline_user_args():
		call_deferred("run_material_contract")
		return
	call_deferred("run")

class MaterialQuest extends RefCounted:
	var claimed: Dictionary = {}
	var save_blocked := false
class MaterialPlayer extends Node:
	func is_stunned() -> bool: return false
	func is_feared() -> bool: return false
	func show_status_text(_text: String) -> void: pass
class MaterialHud extends Node:
	func show_message(_text: String) -> void: pass
	func append_log(_text: String) -> void: pass
class MaterialHost extends Node:
	var catalog_db: Dictionary = {"아이템":[]}
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var ui_preferences: Dictionary = {}
	var quest_service = MaterialQuest.new()
	var equipment_collections: Dictionary = {"save_blocked":false,"extra_save_fields":{}}
	var crafting_log: Array[Dictionary] = []
	var source_save_blocked := false
	var hp := 100
	var player = MaterialPlayer.new()
	var hud = MaterialHud.new()
	var fail_save := false
	func _index_catalog_item_sources() -> void: pass
	func _index_item_weights() -> void: pass
	func _update_hud() -> void: pass
	func _find_catalog_item_record(key: String) -> Dictionary:
		for row: Dictionary in catalog_db["아이템"]:
			if row.name == key: return row
		return {}
	func _save_game(_quiet: bool, staged: Dictionary) -> Error:
		if fail_save: return ERR_CANT_CREATE
		return Runtime.Source.write_text("user://material-contract.json",JSON.stringify(staged))

func material_record(service: RefCounted, reward: Dictionary) -> Dictionary:
	var item: Dictionary = service.source.items[str(int(reward.RewardClassID))]
	# Exact PR262 pending-item contract, not a normal-acquisition fixture.
	return {"name":"[원본 보상] "+str(item.Name),"source_display_name":str(item.Name),"slot":"quest_reward","source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:%d" % int(item.ID),"source_item_class_id":int(item.ID),"source_original_item":item.duplicate(true),"source_pending_use":true,"quest_item":true,"source_bless_code_id":int(reward.ItemBlessCodeID),"source_use_immediately":bool(reward.UseImmediately),"source_reward_id":int(reward.ID)}

func run_material_contract() -> void:
	var path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--protection523-source-zip="): path = arg.trim_prefix("--protection523-source-zip=")
	var result: Dictionary = Runtime.Source.extract(path)
	check(bool(result.get("ok",false)),"pinned actual523 source extracts")
	if not bool(result.get("ok",false)): printerr(result);quit(1);return
	var host := MaterialHost.new()
	var service = Runtime.new()
	service.world = host
	service.source = result
	service.reset_clock()
	service.register_missing()
	check(service.source.material_rewards.size() == 11,"all eleven direct material reward rows preserved")
	check(service.source.supply_recipes.size() == 2,"both exact upstream recipes loaded without quota rows")
	for reward: Dictionary in service.source.material_rewards.values():
		var record := material_record(service,reward)
		var key := str(record.name)
		var id := int(reward.RewardClassID)
		host.inventory = {key:1}
		host.item_instances = {"42":{"name":key,"level":0,"record":record,"source_reward_quantity":1}}
		host.quest_service.claimed.clear()
		check(service.owned_key(id,host.inventory).is_empty(),"unearned quest receipt rejected %d" % int(reward.ID))
		for qid: int in service.source.material_quests[str(int(reward.ID))]: host.quest_service.claimed["m523:quest:%d" % qid] = true
		check(service.owned_key(id,host.inventory) == key,"exact physical source material accepted %d" % int(reward.ID))
		record.source_item_class_id = float(id)+0.5
		check(service.owned_key(id,host.inventory).is_empty(),"fractional item identity rejected")
		record.source_item_class_id = id
		record.source_bless_code_id = 2
		check(service.owned_key(id,host.inventory).is_empty(),"blessed-state mismatch rejected")
		record.source_bless_code_id = 1
		host.item_instances["42"].source_reward_quantity = 2
		host.inventory[key] = 2
		check(service.owned_key(id,host.inventory).is_empty(),"quantity cannot exceed pinned reward")
		host.item_instances["42"].source_reward_quantity = 1
		host.inventory[key] = 1
		host.item_instances["43"] = host.item_instances["42"].duplicate(true)
		host.inventory[key] = 2
		check(service.owned_key(id,host.inventory).is_empty(),"duplicated receipt rejected")
	var grace: Dictionary = service.source.material_rewards["166628"]
	var grace_record := material_record(service,grace)
	var key := str(grace_record.name)
	host.quest_service.claimed = {"m523:quest:77992":true,"m523:quest:81108":true}
	host.catalog_db["아이템"].append({"name":"정상의 가호(3단)","source":"inven","sourceId":"123373"})
	host.inventory = {"정상의 가호(3단)":1,key:2}
	host.item_instances = {"81":{"name":key,"level":0,"record":grace_record,"source_reward_quantity":1},"82":{"name":"unrelated physical gear","level":9,"record":{"sourceId":"unrelated"}},"83":{"name":key,"level":0,"record":material_record(service,service.source.material_rewards["166848"]),"source_reward_quantity":1}}
	service.binding_catalog_size = -1
	check(service.pending_quantity(key,200698,host.item_instances) == 2 and service.owned_key(200698,host.inventory) == key,"two earned reward IDs share one exact source stack")
	check(service.quote_craft(200723).ok,"physical quest scroll reaches existing six-tier craft consumer")
	host.quest_service.save_blocked = true
	check(not service.quote_craft(200723).ok,"upstream damaged save keeps material blocked")
	host.quest_service.save_blocked = false
	var before_inventory := host.inventory.duplicate(true)
	var before_instances := host.item_instances.duplicate(true)
	var before_claimed: Dictionary = host.quest_service.claimed.duplicate(true)
	var before_disk := FileAccess.get_sha256("user://material-contract.json") if FileAccess.file_exists("user://material-contract.json") else ""
	host.fail_save = true
	check(not service.craft(200723).ok and host.inventory == before_inventory and host.item_instances == before_instances and service.state.crafted.is_empty(),"failed writer preserves stack/physical ID/title/craft state")
	check((FileAccess.get_sha256("user://material-contract.json") if FileAccess.file_exists("user://material-contract.json") else "") == before_disk,"failed writer preserves exact prior file")
	host.fail_save = false
	check(service.craft_recipe(132033).ok,"delegated body and Appellation owner succeeds with exact pending scroll")
	check(int(host.inventory.get(key,0)) == 1 and not host.item_instances.has("81") and host.item_instances["83"] == before_instances["83"] and host.item_instances["82"] == before_instances["82"],"partial consumption preserves remaining reward ID and unrelated physical ownership")
	check(host.quest_service.claimed == before_claimed,"consumer never changes upstream completion/gates")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://material-contract.json"))
	check(saved.inventory == JSON.parse_string(JSON.stringify(host.inventory)) and saved.item_instances == JSON.parse_string(JSON.stringify(host.item_instances)),"stack and physical quantity share one durable payload")
	host.inventory = saved.inventory
	host.item_instances = saved.item_instances
	check(service.load_state(saved) and service.state.crafted.has("132033"),"roundtrip reload retains consumer receipt and physical quantities")
	check(service.owned_key(200698,host.inventory) == key and int(host.item_instances["83"].source_reward_quantity) == 1,"remaining physical source stack is usable after JSON reload")
	check(not service.craft(200723).ok,"same consumer receipt cannot craft twice")
	check(service.craft(245718).ok and not host.inventory.has(key) and not host.item_instances.has("83") and host.item_instances.has("82"),"next tier consumes remaining original reward exactly once")
	check(not service.load_state({"quest_state":{"schema_version":2,"claimed":{"m523:quest:77992":true}}}) and service.save_blocked,"legacy quest host cannot erase a newer provider receipt")
	check(service.load_state({}),"compatible old save remains usable")
	service.state = Runtime.fresh()
	service.reset_clock()
	host.crafting_log.clear()
	host.catalog_db["아이템"].append({"name":"정상의 가호(2단)","source":"inven","sourceId":"75764"})
	host.quest_service.claimed = {"m523:quest:71854":true,"m523:quest:71864":true,"m523:quest:74773":true}
	var first := material_record(service,service.source.material_rewards["54144"])
	var blessing := material_record(service,service.source.material_rewards["54164"])
	var first_key := str(first.name)
	var blessing_key := str(blessing.name)
	host.inventory = {first_key:1,blessing_key:2}
	host.item_instances = {"101":{"name":first_key,"level":0,"record":first,"source_reward_quantity":1},"102":{"name":blessing_key,"level":0,"record":blessing,"source_reward_quantity":1},"103":{"name":blessing_key,"level":0,"record":material_record(service,service.source.material_rewards["76573"]),"source_reward_quantity":1}}
	service.binding_catalog_size = -1
	check(service.quote_supply(75764).ok,"earned source normal1 plus blessing reaches normal2 recipe")
	host.ui_preferences = {"item_locks":{blessing_key:true}}
	check(not service.quote_supply(75764).ok,"locked source material blocks upstream craft")
	host.ui_preferences.clear()
	host.ui_preferences = {"item_locks":{blessing_key+"@@@103":true}}
	check(not service.quote_supply(75764).ok,"physical UI lock preserves any locked member of material stack")
	host.ui_preferences.clear()
	check(not service.craft_recipe(47982).ok and not service.craft_recipe(222693).ok,"router rejects packaging and disabled recipe")
	var before_supply: Dictionary = host.inventory.duplicate(true)
	var before_supply_instances: Dictionary = host.item_instances.duplicate(true)
	host.fail_save = true
	check(not service.craft_supply(75764).ok and host.inventory == before_supply and host.item_instances == before_supply_instances,"upstream writer failure preserves all physical rewards")
	host.fail_save = false
	check(service.craft_recipe(37044).ok and service.owned_key(75764,host.inventory) == "정상의 가호(2단)","source37044 delegation creates exact existing normal2 identity")
	check(int(host.inventory.get(blessing_key,0)) == 1 and host.item_instances.has("103") and not host.item_instances.has("101") and not host.item_instances.has("102"),"upstream craft keeps second original blessing receipt")
	check(service.state.crafted.is_empty() and service.state.titles.is_empty(),"upstream recipe does not invent title or character-once quota")
	check(service.craft_recipe(47273).ok and service.owned_key(123373,host.inventory) == "정상의 가호(3단)","source47273 delegation creates actual first material for six later recipes")
	check(not host.inventory.has(blessing_key) and host.item_instances.is_empty(),"second upstream recipe consumes exact remaining physical blessing")
	check(not service.quote_supply(75764).ok and not service.quote_supply(123373).ok,"no material is fabricated by upstream crafting")
	var supply_saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://material-contract.json"))
	host.inventory = supply_saved.inventory
	host.item_instances = supply_saved.item_instances
	check(service.load_state(supply_saved) and not service.owned_key(123373,host.inventory).is_empty() and service.state.titles.is_empty(),"upstream result reloads without false permanent rewards")
	print("PROTECTION523_MATERIAL_CONTRACT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual523 rows; PR262 physical contract fixture; no combined Main or natural-supply claim"}))
	host.player.free()
	host.hud.free()
	host.free()
	quit(0 if failures.is_empty() else 1)
func run() -> void:
	var world: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	check(QA.enter_game(world),"actual existing class loads")
	var service: RefCounted = world.protection523
	check(not service.source.is_empty(),"verified installed capsule restores")
	var before := FileAccess.get_sha256(world.save_path())
	var old_state: Dictionary = service.state.duplicate(true)
	var old_inventory: Dictionary = world.inventory.duplicate(true)
	var old_log: Array[Dictionary] = world.crafting_log.duplicate(true)
	var old_extra: Dictionary = world.equipment_collections.extra_save_fields.duplicate(true)
	service.state = Runtime.fresh()
	service.reset_clock()
	world.crafting_log.clear()
	world.inventory["정상의 가호(3단)"] = 1
	world.inventory["은총의 두루마리"] = 1
	var extra: Dictionary = world.equipment_collections.extra_save_fields
	extra["patch523_crafting_usage"] = {"schema":1,"recipes":{"patch523:142364":{"bucket":1,"used":1,"schedule":"604800:504000"}}}
	check(service.quote_craft(200723).ok,"unrelated valid PR239 quota preserved and allowed")
	extra.patch523_crafting_usage.recipes["patch523:132033"] = {"bucket":1,"used":1,"schedule":"lifetime"}
	check(not service.quote_craft(200723).ok,"nested exact generic recipe history prevents duplicate")
	extra.patch523_crafting_usage = {"blocked":true}
	check(not service.quote_craft(200723).ok,"blocked generic ledger remains blocked")
	extra.patch523_crafting_usage = {"schema":1,"recipes":[]}
	check(not service.quote_craft(200723).ok,"damaged generic ledger never resets quota")
	extra.erase("patch523_crafting_usage")
	world.crafting_log.append({"recipe_id":"patch523:132033","batch":1})
	check(not service.quote_craft(200723).ok,"existing exact generic log prevents duplicate")
	world.crafting_log.clear()
	var record: Dictionary = world._find_catalog_item_record("정상의 가호(3단)")
	var original_id: Variant = record.sourceId
	record.sourceId = "999999"
	check(service.owned_key(123373,world.inventory).is_empty(),"live identity change cannot use stale binding cache")
	record.sourceId = original_id
	check(not service.owned_key(123373,world.inventory).is_empty(),"restored exact identity remains usable")
	var invalid: Dictionary = old_state.duplicate(true)
	invalid.cooldowns["371108"] = "3600"
	check(not Runtime.validate(invalid).is_empty(),"malformed cooldown rejected without conversion")
	check(not service.load_state({"protection523":invalid}) and service.save_blocked,"damaged own save blocks before effects")
	check(world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == before,"blocked own save preserves durable bytes")
	check(service.load_state({"protection523":old_state}),"valid own state can restore after rejection")
	service.state = invalid
	check(world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == before,"ordinary save cannot publish an invalid runtime namespace")
	var old_policy: Dictionary = service.policy.duplicate(true)
	service.policy.project_pvp_to_pve = false
	service.policy.same_group = "replace"
	check(service.load_state({}) and service.state.policy.project_pvp_to_pve == false and service.state.policy.same_group == "replace","legacy migration respects configured host defaults")
	service.policy = old_policy
	service.state = old_state
	world.inventory = old_inventory
	world.crafting_log = old_log
	world.equipment_collections.extra_save_fields = old_extra
	check(FileAccess.get_sha256(world.save_path()) == before,"read-only integration checks preserve exact save")
	print("PROTECTION523_LEDGER_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
