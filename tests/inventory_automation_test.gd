extends SceneTree
const AUTO = preload("res://scripts/warehouse/inventory_automation.gd")
const STORAGE = preload("res://scripts/warehouse/local_warehouse.gd")
var failures: Array[String] = []
var checks: int = 0
class FakeHud extends Node:
	func refresh_inventory(_v: Dictionary) -> void: pass
	func append_log(_v: String) -> void: pass
	func show_message(_v: String) -> void: pass
class Host extends Node:
	var inventory: Dictionary = {"HP 물약":250,"수정 단검":3,"귀속품":2,"퀘스트":1}
	var item_instances: Dictionary = {"a":{"name":"수정 단검","level":5,"element":"water"},"b":{"name":"수정 단검","level":9,"element":"fire"},"c":{"name":"수정 단검","level":0}}
	var equipped_items: Dictionary = {"weapon":{"instance_id":"a"}}
	var ui_preferences: Dictionary = {"item_locks":{}}
	var loot_catalog: Dictionary = {"by_name":{"HP 물약":{"name":"HP 물약","slot":"consumable","grade":"일반"},"수정 단검":{"name":"수정 단검","slot":"weapon","grade":"고급"},"귀속품":{"name":"귀속품","slot":"consumable","grade":"일반","bound":true},"퀘스트":{"name":"퀘스트","slot":"consumable","grade":"일반","quest_item":true}}}
	var gold: int = 10000
	var warehouse = STORAGE.new()
	var hud = FakeHud.new()
	var fail_write: bool = false
	var writes: int = 0
	var saved: Dictionary = {}
	var automation
	var reenter: bool = false
	func _find_catalog_item_record(item: String) -> Dictionary: return loot_catalog.by_name.get(item,{})
	func _enhancement_kind_for_record(record: Dictionary) -> String: return "weapon" if record.get("slot","") == "weapon" else ""
	func _item_locked(item: String, id: String) -> bool: return ui_preferences.item_locks.get(item+("@@@"+id if id != "" else ""),false)
	func _update_hud() -> void: pass
	func _save_game(_quiet: bool, staged: Dictionary = {}) -> Error:
		writes += 1
		if fail_write: return ERR_CANT_CREATE
		if reenter:
			reenter = false
			assert(not automation.execute("sell","wrong").get("ok",false))
		saved = staged.duplicate(true)
		return OK
	func snapshot() -> String: return JSON.stringify([inventory,item_instances,warehouse.snapshot(),gold,automation.state])
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("AUTO_FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Host.new()
	var service = AUTO.new()
	host.automation = service
	service.configure(host)
	check(AUTO.valid({}),"legacy missing state defaults empty")
	for malformed: Variant in [null,{"version":2},{"sell":"all"},{"sell":[{"name":"HP 물약","identity":"x","keep":-1}]},{"sell":[{"name":"HP 물약","identity":"x","keep":1.5}]}]: check(not AUTO.valid(malformed),"malformed state rejected")
	check(not service.set_target("sell","귀속품","",true).ok,"bound sale denied")
	check(not service.set_target("sell","퀘스트","",true).ok,"quest sale denied")
	check(not service.set_target("deposit","수정 단검","a",true).ok,"equipped storage denied")
	check(not service.set_target("sell","수정 단검","",true).ok,"physical selection needs exact ID")
	check(service.set_target("deposit","수정 단검","b",true).ok,"select exact enchanted equipment")
	check(service.set_target("deposit","HP 물약","",true,7).ok,"select stack and retention")
	service.restore(JSON.parse_string(JSON.stringify(service.state)))
	host.item_instances = JSON.parse_string(JSON.stringify(host.item_instances))
	host.warehouse.stacks["HP 물약"] = 999999
	check(not service.preview("deposit").ok,"warehouse save quantity ceiling rejects without loss")
	host.warehouse.stacks.clear()
	var before: String = host.snapshot()
	var plan: Dictionary = service.preview("deposit")
	check(plan.ok and plan.cart.size() == 2 and plan.cart[1].quantity == 243,"cart supports stack above legacy UI99")
	check(host.snapshot() == before,"preview and cancellation never mutate")
	host.fail_write = true
	check(not service.execute("deposit",plan.stamp).ok and host.snapshot() == before,"disk failure preserves inventory storage gold settings")
	host.fail_write = false
	var result: Dictionary = service.execute("deposit",plan.stamp)
	check(result.ok and host.inventory["HP 물약"] == 7 and host.warehouse.stacks["HP 물약"] == 243,"atomic storage after successful write")
	check(host.warehouse.instances.b.level == 9 and host.warehouse.instances.b.element == "fire" and not host.item_instances.has("b") and host.item_instances.has("a"),"exact ID enchant element retained")
	check(host.saved.inventory == host.inventory and host.saved.warehouse == host.warehouse.snapshot() and host.saved.gold == host.gold,"one persisted override matches published state")
	check(not service.execute("deposit",plan.stamp).ok,"repeated old confirmation cannot duplicate")
	check(not service.contains("deposit","수정 단검","b"),"consumed equipment target removed")
	check(service.contains("deposit","HP 물약",""),"stack target retained")
	check(service.set_target("sell","HP 물약","",true,2).ok,"select sale")
	plan = service.preview("sell")
	host.ui_preferences.item_locks["HP 물약"] = true
	check(not service.execute("sell",plan.stamp).ok,"lock after confirmation invalidates cart")
	check(service.preview("sell").cart.is_empty(),"locked target is skipped")
	host.ui_preferences.item_locks.clear()
	plan = service.preview("sell")
	host.gold += 1
	check(not service.execute("sell",plan.stamp).ok,"wallet change invalidates quote")
	plan = service.preview("sell")
	var wallet_before: int = host.gold
	host.reenter = true
	check(service.execute("sell",plan.stamp).ok and host.inventory["HP 물약"] == 2 and host.gold == wallet_before+int(plan.payment),"sale uses authoritative current price and respects retention")
	check(service.set_target("sell","수정 단검","c",true).ok,"exact sale gear target")
	host.item_instances.c.level = 1
	check(service.preview("sell").cart.is_empty(),"changed equipment metadata requires re-selection")
	check(service.set_target("sell","수정 단검","c",true).ok,"review changed gear")
	plan = service.preview("sell")
	host.equipped_items["other"] = {"instance_id":"c"}
	check(not service.execute("sell",plan.stamp).ok and service.preview("sell").cart.is_empty(),"newly equipped gear cannot be sold")
	host.equipped_items.erase("other")
	host.ui_preferences.item_locks["수정 단검"] = true
	check(service.preview("sell").cart.is_empty(),"name-level gear lock protects exact target")
	host.ui_preferences.item_locks.clear()
	host.gold = 9000000000000000000
	before = host.snapshot()
	check(not service.preview("sell").ok and host.snapshot() == before,"wallet overflow fails entire cart without mutation")
	host.gold = 100
	plan = service.preview("sell")
	check(service.execute("sell",plan.stamp).ok and not host.item_instances.has("c") and host.item_instances.has("a"),"only chosen physical item sold")
	var roundtrip = AUTO.new()
	roundtrip.restore(JSON.parse_string(JSON.stringify(service.state)))
	check(JSON.stringify(roundtrip.state) == JSON.stringify(service.state),"JSON roundtrip preserves selected targets")
	var preserved: String = JSON.stringify(service.state)
	host.fail_write = true
	check(not service.clear("deposit").ok and JSON.stringify(service.state) == preserved,"setting clear failure preserves targets")
	check(not service.set_target("sell","HP 물약","",true).ok and JSON.stringify(service.state) == preserved,"setting write failure preserves previous state")
	host.hud.free()
	host.free()
	print("INVENTORY_AUTOMATION: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
