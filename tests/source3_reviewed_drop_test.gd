extends SceneTree
const DROP = preload("res://scripts/loot_drop.gd")
const REVIEW = preload("res://scripts/loot/source3_reviewed_drop.gd")
const SAVE = preload("res://scripts/skills/save_writer.gd")
const SAVE_PATH = "user://source3-reviewed-drop-test.json"
class Floor:
	extends "res://scripts/loot/ground_loot_manager.gd"
	func _icon(_item_name: String) -> Texture2D: return null
class Owner:
	extends Node
	var loot_catalog: Dictionary = {}
	var catalog_image_index: Dictionary = {}
	var drops_root: Node = Node.new()
	var maps_by_id: Dictionary = {"test":{}}
	var item_instances: Dictionary = {}
	func _is_walkable_world(_point: Vector2) -> bool: return true
	func _has_line_of_sight_world(_a: Vector2, _b: Vector2) -> bool: return true
	func _on_ground_drop_clicked(_view: Button) -> void: pass
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); print("SOURCE3_DROP_FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REVIEW.PATH))
	var ids: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REVIEW.IDENTITIES))
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	var items: Dictionary = {}
	for item: Dictionary in db["아이템"]: items[str(item.name)] = item
	var ident: Dictionary = payload.required_monster_identity
	if "--phase=drift" in OS.get_cmdline_user_args():
		check(REVIEW.candidate("희귀", items, ident).is_empty(), "modified identity/proof bytes accepted")
		print("SOURCE3_DROP_TEST phase=drift failures=" + str(failures.size()))
		quit(0 if failures.is_empty() else 1); return
	check(not REVIEW.candidate("희귀", items, ident).is_empty(), "exact identity rejected")
	for field: String in ident:
		var wrong: Dictionary = ident.duplicate(true)
		wrong[field] = "WRONG"
		check(REVIEW.candidate("희귀", items, wrong).is_empty(), "wrong mapping accepted: " + field)
	var bad: Dictionary = payload.duplicate(true); bad.item_game_source_id = "422"
	check(REVIEW.validate(bad, ids, "희귀", items, ident).is_empty(), "wrong item mapping accepted")
	bad = payload.duplicate(true); bad.source_enchant = 1
	check(REVIEW.validate(bad, ids, "희귀", items, ident).is_empty(), "source enchant changed")
	check(REVIEW.candidate("일반", items, ident).is_empty(), "wrong grade accepted")
	check(REVIEW.candidate("희귀", items, {}).is_empty(), "name or numeric ID alone accepted")
	var catalog: Dictionary = {"by_name":items, "equipment_by_grade":{}, "potions":[], "l1j_monster_drops":{}, "twilight_coverage_equipment":{}, "twilight_coverage_potions":{}, "crafting_drops":{}}
	var empty: Array[String] = []
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	check(DROP._pick_equipment_entry("희귀", empty, catalog, rng, "대법관 바로드", ident) == {"item_name":"수정 단검", "quantity":1}, "empty rare slot not connected")
	var existing: Array[String] = ["수정 단검"]
	var before: int = rng.state
	var legacy: Dictionary = DROP._pick_equipment_entry("희귀", existing, catalog, rng, "대법관 바로드")
	var after: int = rng.state; rng.state = before
	check(DROP._pick_equipment_entry("희귀", existing, catalog, rng, "대법관 바로드", ident) == legacy and rng.state == after, "existing item duplicated or RNG changed")
	existing = ["파괴의 이도류"]
	before = rng.state; legacy = DROP._pick_equipment_entry("희귀", existing, catalog, rng, "대법관 바로드"); after = rng.state; rng.state = before
	check(DROP._pick_equipment_entry("희귀", existing, catalog, rng, "대법관 바로드", ident) == legacy and rng.state == after, "existing rare pool replaced or diluted")
	for pool_key: String in ["l1j_monster_drops", "twilight_coverage_equipment"]:
		var with_pool: Dictionary = catalog.duplicate(true)
		with_pool[pool_key] = {"대법관 바로드":[{"item_name":"파괴의 이도류", "weight":17, "min":1, "max":1}]}
		before = rng.state; legacy = DROP._pick_equipment_entry("희귀", empty, with_pool, rng, "대법관 바로드"); after = rng.state; rng.state = before
		check(DROP._pick_equipment_entry("희귀", empty, with_pool, rng, "대법관 바로드", ident) == legacy and rng.state == after, "existing override/coverage pool altered: " + pool_key)
	# Seeded grade rolls remain identical. Only successful rare empty slots fill.
	DROP.unavailable_grade_reports["대법관 바로드:일반"] = true
	DROP.unavailable_grade_reports["대법관 바로드:고급"] = true
	DROP.unavailable_grade_reports["대법관 바로드:영웅"] = true
	for seed_value: int in range(10000):
		var expected_rng := RandomNumberGenerator.new(); expected_rng.seed = seed_value
		var potion_roll: float = expected_rng.randf()
		var expected_grade: String = DROP._roll_equipment_grade(false, expected_rng)
		rng.seed = seed_value
		var result: Array[Dictionary] = DROP.roll_detailed(empty, false, catalog, rng, "대법관 바로드", ident)
		var expected: Array[Dictionary] = []
		if potion_roll < DROP.NORMAL_POTION_RATE: expected.append({"item_name":"HP 물약", "quantity":1})
		if expected_grade == "희귀": expected.append({"item_name":"수정 단검", "quantity":1})
		check(result == expected, "additional/changed rarity or potion roll at seed " + str(seed_value))
	var owner_world := Owner.new(); root.add_child(owner_world); owner_world.add_child(owner_world.drops_root); owner_world.loot_catalog = catalog
	var floor_loot := Floor.new(); floor_loot.configure(owner_world); floor_loot.activate("test")
	var phase: String = "write"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
	if phase == "write":
		var drop: Button = floor_loot.spawn("수정 단검", Vector2.ZERO, 1)
		check(drop != null and floor_loot.snapshot().size() == 1, "ground drop absent before save")
		check(SAVE.write(SAVE_PATH, {"drops":floor_loot.snapshot()}) == OK, "real save failed")
	elif phase == "read":
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		floor_loot.restore(saved.drops); floor_loot.restore(saved.drops)
		check(floor_loot.records.size() == 1 and floor_loot.views.size() == 1, "restart duplicated/lost saved item")
		var view: Button = floor_loot.views.values()[0]; view.visible_since = Time.get_ticks_msec() - 1000
		var collected: Dictionary = floor_loot.take(view, Vector2.ZERO, 50)
		check(collected.get("item_name") == "수정 단검" and int(collected.get("quantity", 0)) == 1, "restarted item not collectable")
		check(floor_loot.take(view, Vector2.ZERO, 50).is_empty(), "duplicate pickup granted")
		check(SAVE.write(SAVE_PATH, {"drops":floor_loot.snapshot()}) == OK, "post-pickup save failed")
	elif phase == "empty":
		var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH)); floor_loot.restore(saved.drops)
		check(floor_loot.records.is_empty(), "collected item returned after second restart")
	floor_loot.hide_map(); owner_world.queue_free(); await process_frame
	print("SOURCE3_DROP_TEST phase=" + phase + " failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
