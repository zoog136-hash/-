extends SceneTree
## Synthetic public-API integration probes; not PR232 terrain installation.
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
const BRIDGE = preload("res://scripts/maps/patch523_source_portal_bridge.gd")
var checks: int = 0
var failures: Array[String] = []
class Coordinates extends RefCounted:
	var origin := Vector2i.ZERO
class FieldProbe extends RefCounted:
	var loaded: bool = true
	var coordinates = Coordinates.new()
	var current_cell := Vector2i.ZERO
	var cells: Dictionary = {}
	var data: Dictionary = {"portal":[]}
	func _init() -> void: set_meta("current523_source_field", true)
	func world_to_cell(_at: Vector2) -> Vector2i: return current_cell
	func source_cell_info(cell: Vector2i) -> Dictionary: return cells.get(cell, {}).duplicate(true)
class ActorProbe extends Node2D:
	var auto_enabled: bool = false
	var movement_locked: bool = false
	var stun: bool = false
	var hold: bool = false
	var fear: bool = false
	func is_stunned() -> bool: return stun
	func is_held() -> bool: return hold
	func is_feared() -> bool: return fear
class HudProbe extends Node:
	var messages: Array[String] = []
	var closes: int = 0
	func show_message(text: String) -> void: messages.append(text)
	func _close_workspace() -> void: closes += 1
class PopulationProbe extends RefCounted:
	var slots: Array = []
class WorldProbe extends Node:
	var field_map: RefCounted = FieldProbe.new()
	var player = ActorProbe.new()
	var hud = HudProbe.new()
	var field_population = PopulationProbe.new()
	var hp: int = 100
	var portal_cooldown: float = 0
	var charge_skill: Dictionary = {}
	var current523_aden_play_active: bool = true
	var current523_aden_play_problem: String = "SYNTHETIC_BACKEND_FAILURE"
	var active_map: Dictionary = {"name":"SYNTHETIC_TEST_ONLY"}
	var active_map_id: String = "aden_world"
	var rows: Array = []
	var calls: Array[int] = []
	var response: Variant = true
	var change_on_failure: bool = false
	var nested_bridge: RefCounted
	var nested_receipt: Dictionary = {}
	var nested_result: Dictionary = {}
	var catalog: RefCounted
	func _init() -> void: add_child(player); add_child(hud)
	func current523_aden_source_portals() -> Array: return rows.duplicate(true)
	func current523_aden_source_portal_context(id: int) -> Dictionary:
		for row: Dictionary in rows:
			if row.id == id: return row.duplicate(true)
		return {}
	func use_current523_aden_source_portal(id: int) -> Variant:
		calls.append(id)
		if nested_bridge != null: nested_result = nested_bridge.request(self, catalog, nested_receipt)
		if response == false and change_on_failure: player.global_position += Vector2(1,0)
		return response
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("SOURCE_BRIDGE_FAIL: ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var options: Dictionary = POLICY.settings()
	var catalog = LINKS.new()
	check(catalog.load_land(options.root, 4, "Aden/", options.sha), "current523 declarations load")
	var absent := Node.new()
	check(BRIDGE.inspect(absent,catalog,335).code == "source_runtime_api_required", "all three real Main methods are required")
	check(BRIDGE.inspect(absent,null,335).code == "portal_missing", "missing catalog is held")
	absent.free()
	var original: String = JSON.stringify(catalog.shard)
	var world := WorldProbe.new(); root.add_child(world); world.catalog = catalog
	for row: Dictionary in catalog.portal_evidence():
		var contract: Dictionary = catalog.portal_contract(int(row.portal.ID))
		var entry: Dictionary = row.duplicate(true)
		entry.id = int(row.portal.ID); entry.source_position = contract.source_point
		entry.landing_position = contract.declared_arrival
		entry.activation_candidate = entry.id in [335,343]
		entry.raw_endpoint_match = entry.activation_candidate
		entry.matched_raw_record_ids = ["SYNTHETIC_TEST_ONLY"] if entry.activation_candidate else []
		entry.source_support = {"s32_member_verified":true,"member":"Map/Aden/SYNTHETIC_TEST_ONLY.s32","sha256":"a".repeat(64)}
		entry.target_support = entry.source_support.duplicate(true)
		world.rows.append(entry)
		if entry.activation_candidate:
			for at: Array in [entry.source_position,entry.landing_position]:
				var cell := Vector2i(int(at[0]),int(at[1]))
				world.field_map.cells[cell] = {"status":"allowed","walkable":true,"source_cell":cell,"member":entry.source_support.member,"source_sha256":entry.source_support.sha256}
	var bridge = BRIDGE.new()
	var start: Vector2 = BRIDGE.point(catalog.portal_contract(335).source_point)
	world.field_map.current_cell = Vector2i(start)
	var state: Dictionary = BRIDGE.inspect(world,catalog,335)
	check(state.request_enabled and not state.travel_enabled, "exact current source cell enables explicit delegation only")
	world.field_map.current_cell = Vector2i(BRIDGE.point(catalog.portal_contract(343).source_point))
	check(BRIDGE.inspect(world,catalog,343).request_enabled, "second synthetic supported endpoint pair stays selectable")
	world.field_map.current_cell = Vector2i(start)
	var candidate: Dictionary = world.rows.filter(func(row: Dictionary) -> bool: return row.id == 345)[0]
	candidate.activation_candidate = true; candidate.raw_endpoint_match = true; candidate.matched_raw_record_ids = ["SYNTHETIC_TEST_ONLY"]
	check(BRIDGE.inspect(world,catalog,345).code == "endpoint_policy_blocked", "raw endpoint candidate alone is not actual source-field support")
	candidate.activation_candidate = false
	var initial: Vector2 = world.player.global_position
	check(bridge.request(world,catalog,state.receipt).ok and world.calls == [335] and world.player.global_position == initial, "request delegates once without adapter-owned movement")
	world.calls.clear(); world.nested_bridge = bridge; world.nested_receipt = state.receipt
	check(bridge.request(world,catalog,state.receipt).ok and not world.nested_result.ok and world.calls == [335], "reentrant request cannot double-delegate")
	world.nested_bridge = null; world.calls.clear()
	world.field_map.current_cell += Vector2i(1,0)
	check(BRIDGE.inspect(world,catalog,335).code == "actor_not_at_declared_portal", "no invented trigger radius")
	world.field_map.current_cell = Vector2i(start)
	for name: String in ["auto_enabled","movement_locked","stun","hold","fear"]:
		world.player.set(name,true)
		check(not BRIDGE.inspect(world,catalog,335).request_enabled, "actor state blocks: " + name)
		world.player.set(name,false)
	world.portal_cooldown = 1
	check(BRIDGE.inspect(world,catalog,335).code == "actor_state_blocked", "runtime cooldown remains authoritative")
	world.portal_cooldown = 0; world.charge_skill = {"test":true}
	check(not BRIDGE.inspect(world,catalog,335).request_enabled, "charge blocks request")
	world.charge_skill = {}; world.hp = 0
	check(not BRIDGE.inspect(world,catalog,335).request_enabled, "dead actor blocks request")
	world.hp = 100; world.current523_aden_play_active = false
	check(BRIDGE.inspect(world,catalog,335).code == "source_field_inactive", "inactive source mode blocks request")
	world.current523_aden_play_active = true; world.field_map.remove_meta("current523_source_field")
	check(BRIDGE.inspect(world,catalog,335).code == "source_field_inactive", "parent label is not substituted for actual field metadata")
	world.field_map.set_meta("current523_source_field",true)
	world.field_map.set_meta("current523_source_field",1)
	check(BRIDGE.inspect(world,catalog,335).code == "source_field_inactive", "numeric metadata is not active source proof")
	world.field_map.set_meta("current523_source_field",true)
	var cell_info: Dictionary = world.field_map.cells[Vector2i(start)].duplicate(true)
	world.field_map.cells[Vector2i(start)].walkable = false
	check(BRIDGE.inspect(world,catalog,335).code == "endpoint_policy_blocked", "field policy verdict blocks endpoint")
	world.field_map.cells[Vector2i(start)] = cell_info
	var row335: Dictionary = world.rows.filter(func(row: Dictionary) -> bool: return row.id == 335)[0]
	row335.source_support.sha256 = "b".repeat(64)
	check(BRIDGE.inspect(world,catalog,335).code == "endpoint_policy_blocked", "actual endpoint member hash must match runtime support")
	row335.source_support.sha256 = "a".repeat(64)
	row335.portal.SourceX += 1
	check(BRIDGE.inspect(world,catalog,335).code == "declaration_mismatch", "runtime cannot replace current M declaration")
	row335.portal.SourceX -= 1
	var row350: Dictionary = world.rows.filter(func(row: Dictionary) -> bool: return row.id == 350)[0]
	row350.landing_position = [34278,32224]
	check(BRIDGE.inspect(world,catalog,350).code == "declared_arrival_mismatch", "Portal350 raw candidate never becomes arrival")
	row350.landing_position = catalog.portal_contract(350).declared_arrival
	check(not BRIDGE.inspect(world,catalog,350).request_enabled, "metadata-only source match is not activation")
	world.rows.append(row335.duplicate(true))
	check(BRIDGE.inspect(world,catalog,335).code == "runtime_contract_changed", "duplicate selected runtime IDs are rejected")
	world.rows.pop_back()
	var lease: Dictionary = BRIDGE.inspect(world,catalog,335).receipt
	row335.raw_test_revision = 1
	check(bridge.request(world,catalog,lease).code == "stale_selection" and world.calls.is_empty(), "changed context requires reselection before execution")
	row335.erase("raw_test_revision")
	var prior_field: RefCounted = world.field_map
	var replacement := FieldProbe.new(); replacement.cells = prior_field.cells.duplicate(true); replacement.current_cell = prior_field.current_cell
	world.field_map = replacement
	check(bridge.request(world,catalog,lease).code == "stale_selection" and world.calls.is_empty(), "replaced field invalidates selection even with identical declarations")
	world.field_map = prior_field
	world.response = false
	var failure: Dictionary = bridge.request(world,catalog,BRIDGE.inspect(world,catalog,335).receipt)
	check(not failure.ok and failure.position_preserved and failure.reason == world.current523_aden_play_problem and world.player.global_position == initial, "backend rejection preserves its reason and state")
	world.change_on_failure = true
	failure = bridge.request(world,catalog,BRIDGE.inspect(world,catalog,335).receipt)
	check(failure.code == "runtime_changed_state_on_failure" and world.player.global_position == initial + Vector2(1,0), "adapter does not overwrite controller-owned failure recovery")
	world.change_on_failure = false; world.player.global_position = initial; world.response = true
	var panel = load("res://scripts/ui/patch523_world_panel.gd").new(); root.add_child(panel); panel.configure(world)
	panel.mode.select(2); panel.mode.item_selected.emit(2); panel.search.text = "포탈 335 →"; panel.filter_rows()
	check(not panel.action.disabled, "synthetic public API enables actual panel request button")
	var prior_calls: int = world.calls.size(); panel.action.pressed.emit()
	check(world.calls.size() == prior_calls+1 and world.hud.closes == 1, "panel delegates selected portal once and closes on success")
	world.response = false; panel.refresh(); panel.action.pressed.emit()
	check(panel.action.disabled and world.hud.closes == 1 and panel.detail.text.begins_with(world.current523_aden_play_problem), "panel keeps failure visible and does not close or retry")
	panel.search.text = "SYNTHETIC_NO_MATCH"; panel.filter_rows()
	prior_calls = world.calls.size(); panel.use_source_portal()
	check(panel.source_selection.is_empty() and world.calls.size() == prior_calls, "empty filtered selection cannot execute the previous portal")
	check(JSON.stringify(catalog.shard) == original, "adapter leaves all source declarations unchanged")
	panel.queue_free(); world.queue_free(); await process_frame
	print("PATCH523_SOURCE_BRIDGE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"positive_runtime_is_synthetic":true}))
	quit(0 if failures.is_empty() else 1)
