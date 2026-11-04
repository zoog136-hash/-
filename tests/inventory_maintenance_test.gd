extends SceneTree
const AUTO = preload("res://scripts/warehouse/inventory_automation.gd")
const STORAGE = preload("res://scripts/warehouse/local_warehouse.gd")
var checks: int = 0
var failures: Array[String] = []
class Player extends Node2D:
	var click_path: PackedVector2Array = PackedVector2Array()
	var velocity: Vector2 = Vector2.ZERO
	var locked: bool = false
	func clear_click_path() -> void: click_path.clear()
	func set_auto_enabled(_enabled: bool) -> void: pass
	func is_stunned() -> bool: return locked
	func is_feared() -> bool: return false
	func is_held() -> bool: return false
class Field extends RefCounted:
	var clear: bool = true
	var data: Dictionary = {"layout_revision":4,"portal":[{"id":"approved","name":"Fixture portal","position":[0,0],"target_position":[100,100],"target_map":"test_map","target_layout_revision":4,"radius":10}]}
	func _init() -> void: set_meta("source_map84",true)
	func point_clear(_point: Vector2,_radius: float) -> bool: return clear
class Hud extends Node:
	func show_message(_text: String) -> void: pass
	func append_log(_text: String) -> void: pass
	func refresh_inventory(_inventory: Dictionary) -> void: pass
class Host extends Node:
	var inventory: Dictionary = {"HP 물약":250}
	var item_instances: Dictionary = {}
	var equipped_items: Dictionary = {}
	var ui_preferences: Dictionary = {"item_locks":{}}
	var loot_catalog: Dictionary = {"by_name":{"HP 물약":{"name":"HP 물약","slot":"consumable","grade":"일반"}}}
	var warehouse = STORAGE.new()
	var player = Player.new()
	var field_map = Field.new()
	var hud = Hud.new()
	var gold: int = 10000
	var level: int = 35
	var hp: int = 100
	var active_map_id: String = "test_map"
	var fail_write: bool = false
	var blocked_route: bool = false
	var saved: Dictionary = {}
	var now: int = 1000
	func _ready() -> void: add_child(player); add_child(hud)
	func _find_catalog_item_record(name: String) -> Dictionary: return loot_catalog.by_name.get(name,{})
	func _enhancement_kind_for_record(_record: Dictionary) -> String: return ""
	func _item_locked(name: String,id: String) -> bool: return ui_preferences.item_locks.get(name+("@@@"+id if id != "" else ""),false)
	func _update_hud() -> void: pass
	func _save_game(_quiet: bool,override: Dictionary = {}) -> Error:
		if fail_write: return ERR_CANT_CREATE
		saved = override.duplicate(true)
		return OK
	func find_world_path(from: Vector2,to: Vector2) -> PackedVector2Array: return PackedVector2Array() if blocked_route else PackedVector2Array([from,to])
	func _set_click_destination(point: Vector2) -> void: player.click_path = find_world_path(player.global_position,point)
	func snapshot(service) -> String: return JSON.stringify([inventory,item_instances,warehouse.snapshot(),gold,service.state])
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("MAINTENANCE_FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host := Host.new()
	root.add_child(host)
	var auto = AUTO.new()
	auto.configure(host)
	# This test is explicitly a host fixture, not a native-map proof.
	auto.source_rules.document = {}
	var m = auto.maintenance
	m.test_unix_time = func() -> int: return host.now
	check(auto.set_target("deposit","HP 물약","",true,7).ok and auto.set_target("sell","HP 물약","",true,2).ok,"configure two phases")
	var before: String = host.snapshot(auto)
	var plan: Dictionary = m.preview(true,true)
	check(plan.ok and plan.override.inventory["HP 물약"] == 2 and plan.override.warehouse.stacks["HP 물약"] == 243 and plan.payment == 200,"store before sale with both reserve counts")
	check(host.snapshot(auto) == before,"combined preview and cancel are read only")
	check(m.portals().size() == 1,"only exact local portal contract listed")
	host.player.global_position = Vector2(50,0)
	host.blocked_route = true
	check(not m.arm("approved",true,true,120).ok and host.snapshot(auto) == before,"no route cannot arm or consume")
	host.blocked_route = false
	host.field_map.data.portal.append({"id":"crossing","position":[25,0],"radius":10})
	check(not m.arm("approved",true,true,120).ok and host.snapshot(auto) == before,"path crossing another portal cannot arm or consume")
	check(not m.safe_walk(PackedVector2Array([Vector2.ZERO]),"approved"),"destination-only authoritative route checks player-to-first segment")
	host.field_map.data.portal.pop_back()
	check(m.arm("approved",true,true,120).ok and not host.player.click_path.is_empty(),"explicit arm uses existing movement API")
	check(not m.before_portal("approved").ok and host.inventory["HP 물약"] == 250,"remote direct portal call cannot process before arrival")
	auto.restore(JSON.parse_string(JSON.stringify(auto.state)))
	check(m.paused and not m.before_portal("approved").ok,"restart requires explicit resume")
	check(m.arm("approved",true,true,120).ok,"explicit resume")
	host.now = 999
	m.tick()
	check(m.paused and host.player.click_path.is_empty() and not m.before_portal("approved").ok and host.inventory["HP 물약"] == 250,"clock rollback stops owned route and cannot trigger a transaction")
	check(not m.arm("approved",true,true,120).ok,"rollback cannot be hidden by rearming")
	host.now = 1001
	check(m.arm("approved",true,true,120).ok,"rearm after clock recovery")
	m.deadline_ms = Time.get_ticks_msec()-1
	m.tick()
	check(m.paused and not m.before_portal("approved").ok,"monotonic deadline pauses once")
	check(m.cancel().ok and not m.settings().armed and host.player.click_path.is_empty(),"cancel clears only owned movement and no items")
	host.fail_write = true
	check(not m.arm("approved",true,true,120).ok and not m.settings().armed,"failed arm save cannot activate schedule")
	host.fail_write = false
	check(m.arm("approved",true,true,120).ok,"arm after transient write failure")
	host.player.global_position = Vector2.ZERO
	host.fail_write = true
	before = host.snapshot(auto)
	check(not m.before_portal("approved").ok and host.snapshot(auto) == before,"failed combined commit preserves both phases and pending intent")
	host.fail_write = false
	check(not m.before_portal("approved").ok,"failed run pauses instead of retrying every portal tick")
	check(m.arm("approved",true,true,120,false).ok,"explicit retry after reviewing failure")
	host.field_map.data.layout_revision = 5
	check(not m.before_portal("approved").ok and host.inventory["HP 물약"] == 250,"changed map revision cannot spend")
	host.field_map.data.layout_revision = 4
	host.player.locked = true
	check(not m.before_portal("approved").ok,"status lock blocks processing")
	host.player.locked = false
	check(m.before_portal("approved").get("performed",false),"confirmed arrival commits once")
	check(host.inventory["HP 물약"] == 2 and host.warehouse.stacks["HP 물약"] == 243 and host.gold == 10200,"two phases published together after durable commit")
	check(not m.settings().armed and m.settings().run_id == m.settings().completed_run_id and host.saved.inventory == host.inventory and host.saved.warehouse == host.warehouse.snapshot(),"one saved payload contains items and consumed run token")
	before = host.snapshot(auto)
	check(not m.before_portal("approved").get("performed",false) and host.snapshot(auto) == before,"duplicate trigger cannot repeat")
	auto.restore(JSON.parse_string(JSON.stringify(auto.state)))
	check(not m.settings().armed and not m.before_portal("approved").get("performed",false),"restart after commit cannot replay")
	check(m.arm("approved",true,true,120,false).ok,"new one-shot run may be explicitly requested")
	check(auto.set_target("sell","HP 물약","",true,1).ok and not m.settings().armed,"changing selected scope disarms prior standing order")
	for raw: Variant in [{"armed":true}, {"armed":true,"deposit":true,"sell":true,"map_id":"x","portal_id":"p","rules_sha":"","revision":4,"run_id":1,"completed_run_id":1,"armed_unix":1000,"completed_unix":1000,"timeout_seconds":120}]:
		check(not auto.valid({"maintenance":raw}),"malformed or consumed pending token rejected")
	host.free()
	print("INVENTORY_MAINTENANCE: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
