extends SceneTree
const RULE = preload("res://scripts/quickslots/regional_return.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
var failures: Array[String] = []
var checks: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("REGIONAL_RETURN_FAIL ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if OS.get_environment("TWILIGHT_REGIONAL_RETURN_TEST") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		printerr("REGIONAL_RETURN_TEST_REQUIRES_ISOLATED_XDG_PROFILE")
		quit(2)
		return
	check(RULE.DATA.data.source_item_ids.size() == 3 and RULE.DATA.data.lands.size() == 3, "exact source table coverage")
	for source_item: Variant in RULE.DATA.data.source_item_ids:
		var entry: Dictionary = {"kind":"item", "id":RULE.DATA.data.items[str(int(source_item))].name, "auto":false}
		for land: String in RULE.DATA.data.lands:
			check(RULE.effective(entry, int(land), true, {}).id == "잊혀진 귀환 주문서 (각인)", "source group and exact Land " + land)
		check(RULE.effective(entry, 44544, false, {}) == entry and RULE.effective(entry, 70, true, {}) == entry, "off and unrelated numeric map do not convert")
	check(RULE.effective({"kind":"skill","id":"귀환 주문서"},44544,true,{}).kind == "skill", "skills untouched")
	check(RULE.effective({"kind":"item","id":"축복받은 귀환 주문서"},44544,true,{}).id == "축복받은 귀환 주문서", "no name substring guessing")
	check(RULE.land_for("source_70",{}, {"source_land_id":99}) == 99, "explicit Land wins over estimated host binding")
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "actual Main class confirmation")
	world.player.set_physics_process(false)
	check(not world.get_regional_return_enabled(), "old save defaults off")
	world.inventory["귀환 주문서"] = 10
	world.inventory["잊혀진 귀환 주문서 (각인)"] = 3
	world._on_quickslot_assignment_requested(0,"item","귀환 주문서")
	var original_slots: Array = world.quickslots.duplicate(true)
	world.hud.open_settings_info()
	var toggle: CheckButton = world.hud.find_child("RegionalReturnEnabled",true,false)
	check(toggle != null, "actual settings control mounted")
	if toggle != null: toggle.button_pressed = true
	check(world.get_regional_return_enabled(), "actual toggle changes world preference")
	world._set_map("source_70",false)
	for frame: int in range(3): await process_frame
	check(world.active_map_id == "source_70" and world.field_map != null, "actual existing Forgotten Island pack loads")
	if world.active_map_id != "source_70" or world.field_map == null:
		print("REGIONAL_RETURN_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
		world.queue_free();quit(1);return
	check(world.hud.quickslot_entries[0].id == "잊혀진 귀환 주문서 (각인)", "real HUD projects regional item on map entry")
	check(world.quickslots == original_slots, "entry preserves every authored slot")
	var spawn: Vector2 = world._spawn_position()
	var probes: Array = world.SOURCE_MAP84.policy()["source_70"].walk_probes
	var other: Vector2 = world.field_map.coordinates.to_world(Vector2(probes[1][0],probes[1][1]))
	world.player.global_position = other
	world._on_quickslot_pressed(0)
	check(world.player.global_position == spawn and int(world.inventory.get("잊혀진 귀환 주문서 (각인)",0)) == 2, "actual slot consumes regional scroll and returns to host entry")
	check(world.inventory["귀환 주문서"] == 10, "base scroll never consumed by projection")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(saved.ui_preferences.regional_return_enabled == true and saved.quickslots[0].id == "귀환 주문서", "durable setting and original slot binding")
	world._set_map("aden_world",false)
	check(world.hud.quickslot_entries[0].id == "귀환 주문서", "leaving region immediately restores original HUD item")
	world._load_game(true)
	check(world.active_map_id == "source_70" and world.get_regional_return_enabled() and world.hud.quickslot_entries[0].id == "잊혀진 귀환 주문서 (각인)", "restart style load restores map setting and projection")
	world.inventory.erase("잊혀진 귀환 주문서 (각인)")
	world.player.global_position = other
	world._on_quickslot_pressed(0)
	check(world.player.global_position == other and world.inventory["귀환 주문서"] == 10, "missing regional item does not fall back or travel")
	world.inventory["잊혀진 귀환 주문서 (각인)"] = 1
	world.player.apply_stun(1.0)
	world._on_quickslot_pressed(0)
	check(world.player.global_position == other and world.inventory["잊혀진 귀환 주문서 (각인)"] == 1, "stun rejects before movement or spending")
	world.player.clear_status_effects()
	world.source_save_blocked = true
	world._on_quickslot_pressed(0)
	check(world.player.global_position == other and world.inventory["잊혀진 귀환 주문서 (각인)"] == 1, "failed durable save rolls back item and position")
	world.source_save_blocked = false
	world._save_game(true)
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	var bad: Dictionary = good.duplicate(true)
	bad.ui_preferences.regional_return_enabled = "true"
	check(WRITER.write(world.save_path(),bad) == OK, "malformed setting fixture written atomically")
	var bad_sha: String = FileAccess.get_sha256(world.save_path())
	var gold: int = world.gold
	world._load_game(true)
	check(world.source_save_blocked and world.gold == gold, "malformed setting rejected before live progression changes")
	check(world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == bad_sha, "malformed save bytes protected")
	WRITER.write(world.save_path(),good)
	world._load_game(true)
	check(not world.source_save_blocked, "valid save can recover")
	world.set_regional_return_enabled(false)
	check(world.hud.quickslot_entries[0].id == "귀환 주문서", "disabling restores original immediately")
	world._set_map("aden_world",false)
	world.inventory["유일한 귀환 주문서 (각인)"] = 1
	world._on_inventory_item_activated("유일한 귀환 주문서 (각인)")
	check(world.inventory.get("유일한 귀환 주문서 (각인)",0) == 1 and world.hud.message_label.text == "아덴 마을로 귀환했습니다", "successful return preserves source InfiniteAmount")
	var target_count: int = int(world.inventory.get("잊혀진 귀환 주문서 (각인)",0))
	world._on_inventory_item_activated("잊혀진 귀환 주문서 (각인)")
	check(int(world.inventory.get("잊혀진 귀환 주문서 (각인)",0)) == target_count and world.active_map_id == "aden_world", "regional item rejected outside allowed lands")
	print("REGIONAL_RETURN_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"actual_host_maps":1,"native_labs_playtested":0}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
