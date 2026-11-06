extends SceneTree
const Service = preload("res://scripts/equipment523/service.gd")
const Smith = preload("res://scripts/equipment523/smith_smelt.gd")
var checks: int = 0
var failures: int = 0

class Consumables extends RefCounted:
	# Synthetic owner of the production consumable ledger; starts empty.
	var state: Dictionary = {}
	func export_state() -> Dictionary: return state.duplicate(true)
	func import_state(value: Dictionary) -> void: state = value.duplicate(true)

class World extends Node:
	var consumable_service := Consumables.new()
	var inventory: Dictionary = {"검":1,"주문서":3}
	var item_instances: Dictionary = {}
	var equipped_items: Dictionary = {}
	var catalog_db: Dictionary = {"아이템":[]}
	var item_db: Array = []
	var ui_preferences: Dictionary = {"item_locks":{}}
	var item_weight_index: Dictionary = {}
	var next_item_instance_id: int = 100
	var level: int = 80
	var gold: int = 1000000
	var rng := RandomNumberGenerator.new()
	var fail_save: bool = true
	var written: Dictionary = {}
	var invalidations: int = 0
	func _save_game(_quiet: bool, overrides: Dictionary) -> Error:
		written = overrides.duplicate(true)
		return ERR_CANT_CREATE if fail_save else OK
	func _item_locked(name: String, id: String) -> bool:
		return bool(ui_preferences.item_locks.get(name,false)) or bool(ui_preferences.item_locks.get(name+"@@@"+id,false))
	func _find_catalog_item_record(name: String) -> Dictionary:
		for record: Dictionary in catalog_db["아이템"]:
			if record.name == name: return record
		return {}
	func _enhancement_kind_for_record(record: Dictionary) -> String:
		return "weapon" if record.get("slot") == "weapon" else ""
	func _carrying_capacity() -> int: return 100000
	func _invalidate_equipment_static() -> void: invalidations += 1
	func _refresh_speed_modifiers() -> void: pass

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var world := World.new()
	world.rng.seed = 42
	var service := Service.new()
	service.store.pack = fixture()
	service.store.sha256 = "synthetic-pack"
	service.policy = {"invoke_gold_cost":0,"set_threshold_mode":"cumulative"}
	var sword: Dictionary = {"name":"검","sourceId":"91","slot":"weapon"}
	var ticket: Dictionary = {"name":"주문서","sourceId":"169994","slot":"consumable"}
	world.catalog_db["아이템"] = [sword,ticket]
	world.item_instances = {
		"t":{"name":"검","level":0,"record":sword.duplicate(true),"equipment523":{"foreign":{"keep":true}},"custom":{"keep":3}},
		"ticket":{"name":"주문서","source_reward_quantity":3,"record":ticket.duplicate(true)}}
	world.item_instances.ticket.record.source_reward_quantity = 3
	var action: Dictionary = {"kind":"invoke_replacement","target_id":"t","material_ids":["ticket"],"slot":3}
	var before: String = JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id])
	var random_before: int = world.rng.state
	var q: Dictionary = service.quote(world,action)
	check(q.get("ok",false),"bridge quotes actual owned physical material")
	check(JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id]) == before and world.rng.state == random_before,"quote leaves live state and RNG unchanged")
	check(service.snapshot(world).targets.size() == 2,"physical stack is not counted again as a name stack")
	world.item_instances.t.source_bless_code = 1
	world.item_instances.t.blessed = true
	check(service._info(world,"t",world.item_instances.t).bless_code == 2,"ordinary host blessing flags supersede a historical normal source code")
	world.item_instances.t.source_bless_code = 2
	world.item_instances.t.blessed = false
	world.item_instances.t.bless_state = "normal"
	check(service._info(world,"t",world.item_instances.t).bless_code == 1,"removed host blessing cannot retain a stale raw blessed source code")
	world.item_instances.t.erase("source_bless_code")
	world.item_instances.t.erase("blessed")
	world.item_instances.t.erase("bless_state")
	var failed: Dictionary = service.commit(world,action)
	check(not failed.get("ok",false),"save failure rejects transaction")
	check(JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id]) == before and world.rng.state == random_before,"failed write preserves inventory, physical state, wallet, ID counter and RNG")
	world.fail_save = false
	q = service.quote(world,action)
	var committed: Dictionary = service.commit(world,action)
	check(committed.get("ok",false),"confirmed transaction commits")
	check(world.inventory["주문서"] == 2 and world.item_instances.ticket.source_reward_quantity == 2 and world.item_instances.ticket.record.source_reward_quantity == 2,"partial physical stack updates both existing quantity locations")
	check(world.item_instances.t.equipment523.foreign.keep and world.item_instances.t.custom.keep == 3,"unrelated per-instance options survive processing")
	check(world.item_instances.t.equipment523.invoke_replacement.slots["3"].group_id == 10,"target receives staged selected slot")
	check(world.rng.state != random_before,"only committed outcome advances live RNG")
	check(world.item_instances.t.equipment523_last_processing.consumer_data_sha256 == service.store.sha256,"committed effect provenance records this consumer's data digest without relabelling the quest owner's journal")
	q = service.quote(world,action)
	world.gold -= 1
	random_before = world.rng.state
	check(not service.commit(world,action).get("ok",false) and world.rng.state == random_before,"stale quote cannot spend or reroll")
	world.item_instances.ticket.expires_unix = 1
	check(not service.quote(world,action).get("ok",false),"expired material is rejected before RNG or consumption")
	world.item_instances.ticket.erase("expires_unix")
	world.item_instances.erase("ticket")
	q = service.quote(world,{"kind":"invoke_replacement","target_id":"t","material_ids":["stack:169994"],"slot":3})
	check(q.get("ok",false),"exact registered legacy stack is available after excluding physical quantities")
	world.ui_preferences.item_locks["주문서"] = true
	check(not service.quote(world,{"kind":"invoke_replacement","target_id":"t","material_ids":["stack:169994"],"slot":3}).get("ok",false),"legacy stack honors item lock")
	world.ui_preferences.item_locks.clear()
	world.equipped_items.weapon = {"name":"검","sourceId":"91","instance_id":"t"}
	var expiry: int = int(Time.get_unix_time_from_system())+10
	service.store.pack.items["777"] = {"raw":{"ID":777}}
	service.store.pack.tables.ItemBonus.append_array([{"ItemClassID":777,"BonusID":4},{"ItemClassID":777,"BonusID":5}])
	service.store.pack.bonuses["4"] = {"name":"SpiritSmelt","raw":{"Value":2}}
	service.store.pack.bonuses["5"] = {"name":"SmeltExpireDate","raw":{"Value":0,"BonusApplicationTypeID":298,"BonusApplicationTargetID":99}}
	service.store.pack.tables.ItemSmelt = [{"ID":2,"SlotAmount":1}]
	service.store.pack.tables.ItemSpiritSmeltEntity = [{"ID":1,"ItemClassID":91,"ItemSmeltID":2,"BlessCode":0}]
	service.store.pack.tables.ItemSmeltBonus = [{"ID":1,"ItemSmeltID":2,"SlotNumber":1,"BonusID":1,"Prob":10000000}]
	service.store.pack.tables.ItemSmeltSlotActive = [{"ItemSmeltID":2,"SlotNumber":1,"MinEnchant":0,"MaxEnchant":7}]
	service.policy.merge({"costs":{"spirit_smelt":{"gold_cost":0,"material_amount":1}},"spirit_bless_zero":"wildcard","smelt_expiry_unix":{"99":expiry}},true)
	var temporal_quote: Dictionary = Smith.quote(service.store.pack,{"kind":"spirit_smelt","target_id":"t"},{"target":service._info(world,"t",world.item_instances.t),"materials":[{"source_id":777,"bless_code":1}],"policy":service.policy,"now_unix":int(Time.get_unix_time_from_system())})
	var local_rng := RandomNumberGenerator.new()
	world.item_instances.t.equipment523.merge(Smith.roll(service.store.pack,temporal_quote,local_rng).get("state",{}),true)
	check(service.records(world).size() == 1 and service.next_expiry_unix > 0,"installed expiry is scheduled while effect is active")
	var invalidations: int = world.invalidations
	service.next_expiry_unix = 1
	service.tick(world,0.1)
	check(world.invalidations == invalidations+1,"expiry invalidates cached equipment effects")
	world.item_instances.t.equipment523.spirit_smelt.expires_unix = 1
	check(service.records(world).is_empty(),"expired installed effect is inactive without deleting saved state")
	service.save_blocked = true
	service.problem = "fixture"
	service.after_load(world)
	check(not service.save_blocked and service.problem.is_empty(),"successful reload can clear an uncertain-save guard")
	check_quest_receipts(service,world)
	check_alchemy(service,world)
	world.free()
	print("equipment523 service checks=%d failed=%d" % [checks,failures])
	print("EQUIPMENT523_SERVICE_RESULT ",JSON.stringify({"checks":checks,"failures":[] if failures == 0 else ["failed"]}))
	quit(1 if failures else 0)

func check_quest_receipts(service, world: World) -> void:
	service.store.pack = fixture()
	service.store.pack.items["169994"]["raw"] = {"ID":169994,"Name":"[내부-주문서] 원문 이름","GradeID":3}
	var original: Dictionary = {"ID":169994,"Name":"[내부-주문서] 원문 이름","GradeID":3,"unretained_source_field":7}
	var held: Dictionary = {"name":"[원본 보상] [내부-주문서] 원문 이름","source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:169994","source_item_class_id":169994,"source_original_item":original.duplicate(true),"source_bless_code_id":1,"source_reward_id":44,"source_pending_use":true}
	var foreign: Dictionary = held.duplicate(true)
	foreign.source = "another_supplier"
	var inventory: Dictionary = {held.name:3,"다른 공급 보상":3}
	var instances: Dictionary = {"held":{"name":held.name,"level":0,"record":held.duplicate(true),"source_reward_quantity":3},"foreign":{"name":"다른 공급 보상","record":foreign.duplicate(true),"source_reward_quantity":3}}
	check(service._source(held) == 169994 and service._source(foreign) == 0,"legacy dictionary reward requires exact source namespace, original fields, ID and distinct display prefix")
	var restored_held: Dictionary = JSON.parse_string(JSON.stringify(held))
	check(service._source(restored_held) == 169994,"legacy original row identity survives a JSON save roundtrip")
	var display_alias: Dictionary = held.duplicate(true)
	display_alias.name = "[원본 보상] " + str(service.store.pack.items["169994"].name)
	check(service._source(display_alias) == 0,"quest reward uses the original ItemClass Name rather than a distinct DescData display label")
	var error: String = service._consume(inventory,instances,{"name":held.name,"instance_id":"held","quantity":3},1)
	check(error.is_empty() and instances.held.source_reward_quantity == 2 and inventory[held.name] == 2 and instances.held.record.source_original_item == original,"receipt-free legacy dictionary reward consumes 3 to 2 without changing original evidence")
	check(instances.foreign.source_reward_quantity == 3 and inventory["다른 공급 보상"] == 3 and instances.foreign.record.source == "another_supplier","receipt-free debit preserves another supplier and physical ID")
	var changed: Dictionary = held.duplicate(true)
	changed.source_original_item.GradeID = 4
	check(service._source(changed) == 0,"legacy dictionary reward rejects altered source fields")
	changed = held.duplicate(true)
	changed.name = "주문서"
	check(service._source(changed) == 0,"dictionary source evidence cannot bypass its exact reward identity through a registered alias")
	for invalid_quantity: Variant in [2.5,"3",true]:
		var malformed: Dictionary = {"record":held,"source_reward_quantity":invalid_quantity}
		check(service._quantity(malformed) == -1,"malformed physical quantities are preserved without rounding or coercion")
	var sword: Dictionary = {"name":"검","sourceId":"91","slot":"weapon"}
	world.inventory = {"검":1,held.name:3}
	world.item_instances = {"t":{"name":"검","level":0,"record":sword},"held":{"name":held.name,"level":0,"record":held.duplicate(true),"source_reward_quantity":3,"quest_reward_receipt":{"schema":1,"quest_id":"m523:quest:9","reward_id":44,"item_class_id":169994,"bless_code_id":1,"source_sha256":"fixture-source","quantity":3}}}
	world.catalog_db["아이템"] = [sword]
	world.equipped_items.clear()
	var info: Dictionary = service._info(world,"held",world.item_instances.held)
	check(info.get("quest_reward_receipt",false) and info.get("quantity") == 3,"recognized quest receipt remains visible with an explicit ownership flag")
	var before: String = JSON.stringify([world.inventory,world.item_instances])
	var random_before: int = world.rng.state
	var q: Dictionary = service.quote(world,{"kind":"invoke_replacement","target_id":"t","material_ids":["held"],"slot":3})
	check(not q.get("ok",false) and str(q.get("error","")).contains("사용 영수증") and JSON.stringify([world.inventory,world.item_instances]) == before and world.rng.state == random_before,"quest receipt material quote clearly refuses consumption and preserves receipt, remainder and RNG")
	inventory = world.inventory.duplicate(true)
	instances = world.item_instances.duplicate(true)
	error = service._consume(inventory,instances,{"name":held.name,"instance_id":"held","quantity":3},1)
	check(not error.is_empty() and instances.held.quest_reward_receipt.quantity == 3 and instances.held.source_reward_quantity == 3 and inventory[held.name] == 3,"defensive debit preserves immutable grant quantity and live remainder")
	world.item_instances.held.source_reward_quantity = 2
	world.inventory[held.name] = 2
	check(service._quantity(world.item_instances.held) == 2 and world.item_instances.held.quest_reward_receipt.quantity == 3,"recognized historical remainder does not equate original grant and remaining quantity")
	var restored_receipt: Dictionary = JSON.parse_string(JSON.stringify(world.item_instances.held))
	check(service._quantity(restored_receipt) == 2 and restored_receipt.quest_reward_receipt.quantity == 3,"JSON-restored receipt retains separate exact grant and remainder quantities")
	var ticket: Dictionary = {"name":"주문서","sourceId":"169994","slot":"consumable"}
	world.inventory = {"주문서":3}
	world.item_instances = {"bad":{"name":"주문서","record":ticket,"source_reward_quantity":3,"quest_reward_receipt":null}}
	world.catalog_db["아이템"] = [ticket]
	check(service._entries(world).is_empty(),"unknown quest receipt cannot escape through a same-name virtual stack")

func check_alchemy(service, world: World) -> void:
	world.equipped_items.clear()
	world.inventory = {"검":3,"재료2":1,"재료3":1}
	world.item_instances = {
		"a":{"name":"검","level":0,"source_reward_quantity":3,"record":{"name":"검","sourceId":"91","slot":"weapon","source_reward_quantity":3}},
		"b":{"name":"재료2","level":0,"record":{"name":"재료2","sourceId":"92","slot":"weapon"}},
		"c":{"name":"재료3","level":0,"record":{"name":"재료3","sourceId":"93","slot":"weapon"}}}
	world.catalog_db["아이템"] = [world.item_instances.a.record,world.item_instances.b.record,world.item_instances.c.record]
	service.store.pack = fixture()
	var pack: Dictionary = service.store.pack
	for id: int in [91,92,93]:
		var name: String = "검" if id == 91 else "재료"+str(id-90)
		pack.items[str(id)] = {"name":name,"names":[name],"raw":{"ID":id,"GradeID":3}}
		pack.bindings[str(id)] = {"source_id":id,"name":name}
	pack.items["999"] = {"name":"원본검","names":["원본검"],"raw":{"ID":999,"GradeID":3}}
	pack.tables.merge({"AlchemyRecipeType":[{"ID":63,"GroupID":3,"IsEnabled":true}],"Grade":[{"ID":3,"GradeValue":3}],
		"AlchemyConstants":[{"Name":"MinLevel","Value":1},{"Name":"AlchemyMaterialMaxDemand","Value":6},{"Name":"AlchemyCurrency","Value":1}],
		"AlchemyConstantByRecipeGroup":[{"GroupID":3,"ConstantTypeID":3,"Value":3},{"GroupID":3,"ConstantTypeID":13,"Value":1},{"GroupID":3,"ConstantTypeID":23,"Value":2},{"GroupID":3,"ConstantTypeID":93,"Value":100}],
		"AlchemyBlessPriceGroup":[{"ID":1,"GroupID":1,"BlessCodeID":1,"Price":0}],"AlchemyItem":[],
		"AlchemyResult":[{"ID":701,"RecipeTypeID":63,"PriceLow":3,"PriceHigh":3,"ServerLimitSetID":0,"Probability":10000000,"ItemClassID":999,"Amount":2,"Enchant":4,"BlessCode":2}]},true)
	for id: int in [91,92,93]: pack.tables.AlchemyItem.append({"ItemClassID":id,"RecipeTypeID":63,"BasePrice":1,"EnchantGroupID":1,"ElementalEnchantGroupID":1,"BlessGroupID":1,"IsRecipeItem":false})
	service.policy.alchemy = {"evaluation_mode":"additive_v1","cost_mode":"flat_recipe_group_v1","range_mode":"inclusive_v1","server_limit_mode":"unrestricted_only"}
	var action: Dictionary = {"kind":"alchemy","target_id":"","material_ids":["a","b","c"],"recipe_type":63}
	var q: Dictionary = service.quote(world,action)
	check(q.get("ok",false),"Alchemy preflights an exact unregistered reward without inventing equipment stats")
	var result: Dictionary = service.commit(world,action)
	check(result.get("ok",false),"Alchemy commits a preserved original reward")
	check(world.item_instances.a.source_reward_quantity == 2 and world.item_instances.a.record.source_reward_quantity == 2,"Alchemy consumes one unit from a selected physical stack")
	check(not world.item_instances.has("b") and not world.item_instances.has("c"),"Alchemy removes exactly the other selected physical items")
	check(world.inventory.get("[원본보상]원본검",0) == 2 and not world.inventory.has("원본검"),"unregistered reward does not merge with a normal-name alias")
	var outputs: Array = []
	for info: Dictionary in service.snapshot(world).targets:
		if int(info.source_id) == 999: outputs.append(info)
	check(outputs.size() == 1 and outputs[0].quantity == 2 and outputs[0].level == 4 and outputs[0].bless_code == 2,"exact reward ID, quantity, enchant and blessing survive snapshot roundtrip")
	check(outputs.size() == 1 and not outputs[0].record.has("slot") and not outputs[0].record.has("atk"),"placeholder does not invent an equipment slot or damage")

func fixture() -> Dictionary:
	return {"source_sha256":"fixture-source","bindings":{"91":{"source_id":91,"name":"검"},"169994":{"source_id":169994,"name":"주문서"}},
		"items":{"91":{"name":"검","names":["검"],"raw":{"ID":91}},"169994":{"name":"주문서","names":["주문서"],"raw":{"ID":169994}}},
		"tables":{"ItemSet":[],"ItemForItemSet":[],"ItemSetBonus":[],
			"ItemBonus":[{"ItemClassID":91,"BonusID":2,"IsPossession":false}],
			"ItemInvokeReplacementEntityView":[{"ID":21,"ItemInvokeReplacementID":9,"SlotNumber":3,"ItemInvokeReplacementBonusGroupID":10,"Prob":1000000},{"ID":22,"ItemInvokeReplacementID":9,"SlotNumber":3,"ItemInvokeReplacementBonusGroupID":11,"Prob":0}],
			"ItemInvokeReplacementBonusGroup":[{"ID":10,"Name":"fixture"},{"ID":11,"Name":"None"}]},
		"bonuses":{"1":{"name":"Strength","supported":true,"record":{"strFlat":1}},"2":{"type":{"Name":"ItemInvokeReplacementID"},"raw":{"Value":9,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0}}}}
