extends SceneTree
const AUTO = preload("res://scripts/warehouse/inventory_automation.gd")
const CATEGORY = preload("res://scripts/warehouse/equipment_category_selection.gd")
const BASE = preload("res://tests/inventory_automation_test.gd")
var checks: int = 0
var failures: Array[String] = []
class Host extends BASE.Host:
	func _equipment_slot_base(record: Dictionary) -> String:
		return "body" if record.get("slot","") == "armor" else str(record.get("slot",""))
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("CATEGORY_FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func target(auto, name: String, id: String) -> Dictionary: return {"name":name,"id":id,"identity":auto._identity(name,id)}
func run() -> void:
	var host := Host.new()
	var auto = AUTO.new()
	host.automation = auto
	auto.configure(host)
	host.inventory = {"고급 검":4,"고급 갑옷":1,"일반 검":1,"각인 검":1}
	host.loot_catalog.by_name = {"고급 검":{"name":"고급 검","slot":"weapon","grade":"고급"},"고급 갑옷":{"name":"고급 갑옷","slot":"armor","grade":"고급"},"일반 검":{"name":"일반 검","slot":"weapon","grade":"일반"},"각인 검":{"name":"각인 검","slot":"weapon","grade":"고급","bound":true}}
	host.item_instances = {"a":{"name":"고급 검","level":0},"b":{"name":"고급 검","level":3},"c":{"name":"고급 검","level":0},"d":{"name":"고급 검","level":0},"armor":{"name":"고급 갑옷","level":0},"normal":{"name":"일반 검","level":0},"marked":{"name":"각인 검","level":0}}
	host.equipped_items = {"weapon":{"instance_id":"c"}}
	host.ui_preferences.item_locks["고급 검@@@d"] = true
	var service = auto.equipment_categories
	for id: int in CATEGORY.SELECTORS:
		var preset: Dictionary = CATEGORY.fresh(id)
		check(not preset.enabled and preset.targets.is_empty() and preset.slot == "" and CATEGORY.valid(preset),"native label never activates or selects equipment "+str(id))
	var config: Dictionary = CATEGORY.fresh(45031)
	config.slot = "weapon"
	var rows: Array[Dictionary] = service.candidates(config)
	check(rows.size() == 3,"exact grade slot marking and default enchant-zero filter")
	var eligible: Array[String] = []
	for row: Dictionary in rows:
		if row.ok: eligible.append(row.id)
	check(eligible == ["a"],"equipped and locked candidates visible but unavailable")
	config.enabled = true
	config.targets = [target(auto,"고급 검","a")]
	auto.state["source_only"] = true
	var before: String = host.snapshot()
	check(not service.preview(config).ok and host.snapshot() == before,"native-only scope cannot silently broaden")
	var plan: Dictionary = service.preview(config,true)
	check(plan.ok and plan.cart.size() == 1 and plan.cart[0].id == "a" and plan.cart[0].quantity == 1 and plan.payment == 200,"explicit host scope reviews exact ID quantity and existing grade price")
	check(host.snapshot() == before,"preview and cancel leave settings and items untouched")
	host.fail_write = true
	check(not service.activate(config,plan.stamp,true).ok and host.snapshot() == before,"activation writer failure preserves all settings inventory and wallet")
	host.fail_write = false
	check(service.activate(config,plan.stamp,true).ok and host.inventory["고급 검"] == 4 and auto.state.equipment_category.enabled and not auto.state.source_only,"activation saves only approved exact targets and explicit mode change")
	check(auto.contains("sell","고급 검","a") and auto.state.equipment_category.targets.size() == 1,"exact category target joins existing auto cart")
	auto.restore(JSON.parse_string(JSON.stringify(auto.state)))
	check(service.settings(45031).targets[0].id == "a" and auto.preview("sell").cart[0].id == "a","saved category config and target survive JSON restart")
	host.inventory["고급 검"] += 1
	host.item_instances["new"] = {"name":"고급 검","level":0}
	check(auto.preview("sell").cart.size() == 1 and auto.preview("sell").cart[0].id == "a","new identical-name equipment is never added to saved category")
	plan = service.preview(config)
	host.ui_preferences.item_locks["고급 검@@@a"] = true
	check(not service.execute(config,plan.stamp).ok and host.item_instances.has("a"),"lock after preview invalidates exact cart")
	host.ui_preferences.item_locks.erase("고급 검@@@a")
	plan = service.preview(config)
	host.item_instances.a.level = 1
	check(not service.execute(config,plan.stamp).ok and not service.preview(config).ok,"changed exact equipment metadata or range requires reselection")
	host.item_instances.a.level = 0
	var wrong: Dictionary = config.duplicate(true)
	wrong.slot = "body"
	check(not service.preview(wrong).ok,"same ID cannot escape explicit selected slot")
	wrong = config.duplicate(true)
	wrong.grade = "일반"
	check(not service.preview(wrong).ok,"same ID cannot escape explicit selected grade")
	var marked: Dictionary = CATEGORY.fresh(45041)
	marked.enabled = true
	marked.slot = "weapon"
	rows = service.candidates(marked)
	check(rows.size() == 1 and rows[0].id == "marked" and not rows[0].ok,"engraved context exposes existing protection instead of bypassing it")
	marked.targets = [target(auto,"각인 검","marked")]
	check(not service.preview(marked).ok,"no sale of protected engraved equipment")
	config.max_enchant = 3
	config.targets = [target(auto,"고급 검","b")]
	plan = service.preview(config)
	check(plan.ok and plan.payment == 260,"explicit configurable enchant limit uses the priced exact physical instance")
	check(auto.set_target("sell","일반 검","normal",true,1).ok,"keep an independent pre-existing manual retention rule")
	auto.state["maintenance"] = auto.maintenance.fresh()
	auto.state.maintenance["automatic"] = {"mode":"twilight_existing_auto_day_once_v1","enabled":true,"resume_auto":false,"scope":auto.maintenance._scope(auto.state),"configured_day":1,"last_started_day":-1,"last_completed_day":-1,"run_day":-1}
	plan = service.preview(config)
	check(plan.cart.size() == 1 and plan.cart[0].id == "b" and plan.selection_state.sell.size() == 2,"category replaces only its own IDs and preserves manual retention")
	host.fail_write = true
	before = host.snapshot()
	check(not service.execute(config,plan.stamp).ok and host.snapshot() == before,"final combined writer failure preserves items wallet and category metadata")
	host.fail_write = false
	var wallet: int = host.gold
	check(service.execute(config,plan.stamp).ok and not host.item_instances.has("b") and host.item_instances.has("a") and host.item_instances.has("new") and host.gold == wallet+260 and not auto.maintenance.automatic_enabled(),"only selected exact ID sold durably; scope change disables prior automatic approval")
	check(auto.state.equipment_category.targets.is_empty() and auto.state.equipment_category.enabled and auto.state.sell.size() == 1 and auto.state.sell[0].keep == 1,"consumed category IDs cleared; manual keep preserved")
	before = host.snapshot()
	check(not service.execute(config,plan.stamp).ok and host.snapshot() == before,"duplicate confirmation cannot pay twice")
	auto.restore(JSON.parse_string(JSON.stringify(auto.state)))
	check(auto.preview("sell").cart.is_empty() and service.settings(45031).targets.is_empty(),"completed category cannot replay after restart")
	config.max_enchant = 0
	config.targets = [target(auto,"고급 검","a")]
	plan = service.preview(config)
	check(service.activate(config,plan.stamp).ok,"reselecting currently held exact ID is explicit")
	check(service.disable().ok and not auto.state.equipment_category.enabled and auto.contains("sell","일반 검","normal") and not auto.contains("sell","고급 검","a"),"disable removes only category-owned targets")
	check(auto.set_target("sell","고급 검","a",true,1).ok,"manual exact ID with keep-one")
	rows = service.candidates(config)
	var manual_preserved: bool = false
	for row: Dictionary in rows:
		if row.id == "a": manual_preserved = not row.ok and row.reason.contains("별도")
	check(manual_preserved and not service.preview(config).ok,"category cannot overwrite existing manual retention scope")
	for malformed: Dictionary in [{"enabled":true},{"version":2},config.merged({"version":true},true), config.merged({"targets":[config.targets[0],config.targets[0]]},true),config.merged({"slot":"all"},true),config.merged({"max_enchant":1.5},true),config.merged({"selector_id":999},true)]:
		check(not AUTO.valid({"equipment_category":malformed}),"malformed category namespace rejects save load")
	host.hud.free()
	host.free()
	print("EQUIPMENT_CATEGORY: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
