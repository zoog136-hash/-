extends SceneTree
## Bag -> floor for every item kind (user 2026-11-20: "바닥으로 드롭했는데
## 바닥에 안떨어지고 삭제되고"): a legacy-name item without an original floor
## body used to lie on the floor as an invisible record (no picture, no name)
## and vanished after the floor lifetime. Each kind must
## - leave the bag and become one floor record with a visible view (original
##   floor body, or the original inventory icon / item name in its place),
## - survive save/load on the floor and be picked up again into the bag;
## and an expired player drop from before the fix returns to the bag on load
## (receipted original stacks and later drops keep the floor lifetime).
const QA = preload("res://tests/qa_class_selection.gd")
const TRANSFER = preload("res://scripts/loot/inventory_ground_transfer.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const D = preload("res://scripts/loot/patch523_monster_drops.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const MANAGER = preload("res://scripts/loot/ground_loot_manager.gd")
## Legacy-name items whose floor body the 523 pack cannot draw (2026-11-20 sweep).
const INVISIBLE_BEFORE := ["영웅급 스킬 상자(기사)", "전설 악세서리 제작 비법서", "조각난 지식의 룬", "봉인된 정상의 가호(3단) 상자"]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var world: Node

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("INVENTORY_FLOOR_DROP_KINDS_FAIL: ", label)
	return condition

func _initialize() -> void: call_deferred("run")

func frames(count: int = 6) -> void:
	for frame: int in range(count): await process_frame

func floor_of(name_value: String) -> Array:
	var found: Array = []
	for record: Dictionary in world.ground_loot.records.values():
		if record.get("item_name") == name_value: found.append(record)
	return found

func floor_total(name_value: String) -> int:
	var total: int = 0
	for record: Dictionary in floor_of(name_value): total += int(record.quantity)
	return total

## A legacy-name bag item that a save/load keeps in the bag (preferring the
## ones whose floor body the 523 pack cannot draw).
func plain_record() -> Dictionary:
	var by_name: Dictionary = {}
	var order: Array = []
	for record: Dictionary in world.catalog_db.get("아이템", []):
		if record.get("source_m_native_item") == true or not world._enhancement_kind_for_record(record).is_empty(): continue
		if bool(record.get("quest_item", false)) or not bool(record.get("droppable", record.get("drop_allowed", true))): continue
		if str(record.get("name", "")).is_empty() or not TRANSFER.source_droppable(record) or by_name.has(str(record.name)): continue
		by_name[str(record.name)] = record
		order.append(str(record.name))
	var candidates: Array = []
	for name_value: String in INVISIBLE_BEFORE:
		if by_name.has(name_value): candidates.append(name_value)
	for name_value: String in order:
		if candidates.size() >= 12: break
		if not candidates.has(name_value): candidates.append(name_value)
	for name_value: String in candidates:
		world.inventory[name_value] = 3
		world._save_game(true)
		world.item_instances = {}; world.inventory = {}
		world._load_game(true)
		# Loading re-enters the source field a few frames later.
		await frames(20)
		if int(world.inventory.get(name_value, 0)) == 3: return by_name[name_value]
		evidence["legacy_not_kept_" + name_value] = int(world.inventory.get(name_value, 0))
	return {}

func native_name(id: int) -> String:
	return str(D.variant_item(D.definition_id(str(id)).get("native_record", {}), 1).get("name", ""))

func grant(id: int, amount: int) -> bool:
	var staged: Dictionary = INVENTORY.stage(world, [{"item_class_id":id, "amount":amount, "bless_raw":1, "enchant":0}], {"kind":"twilight_debug_catalog", "initial_level_origin":"twilight_debug_default_zero"})
	if not check(staged.get("ok", false), "grant #%d (%s)" % [id, str(staged.get("error", ""))]): return false
	if not check(world._save_game(true, staged.overrides) == OK, "grant #%d save" % id): return false
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances
	return true

func physical_id(name_value: String) -> String:
	for key: String in world.item_instances:
		if world.item_instances[key] is Dictionary and world.item_instances[key].get("name") == name_value: return key
	return ""

## Something of the item is drawn: its original floor body or texture, or the
## inventory-icon / name stand-in.
func view_visible(view: Variant) -> Dictionary:
	if not is_instance_valid(view): return {"ok":false, "why":"no view"}
	var body: bool = view.body_drawn()
	var icon: bool = is_instance_valid(view.fallback_sprite) and view.fallback_sprite.visible and view.fallback_sprite.texture != null
	var source_name: bool = is_instance_valid(view.source_name_label) and view.source_name_label.visible and not view.source_name_label.text.is_empty()
	var fallback_name: bool = is_instance_valid(view.fallback_name_label) and view.fallback_name_label.visible and not view.fallback_name_label.text.is_empty()
	return {"ok":view.is_visible_in_tree() and (body or icon or source_name or fallback_name), "body":body, "icon":icon, "name":source_name or fallback_name}

func drop_kind(label: String, name_value: String, reference: String, count: int) -> void:
	var before: int = int(world.inventory.get(name_value, 0))
	var floor_before: int = floor_total(name_value)
	var quoted: Dictionary = TRANSFER.quote(world, reference)
	if not check(quoted.get("ok", false), "%s: the bag item can be put down (%s)" % [label, JSON.stringify(quoted)]): return
	var dropped: bool = world._drop_inventory_reference(str(quoted.reference), world.player.global_position + Vector2(40, 10), count)
	var row: Dictionary = {"name":name_value, "count":count}
	check(dropped and int(world.inventory.get(name_value, 0)) == before - count and floor_total(name_value) == floor_before + count, "%s: %d leave the bag onto the floor (%d -> %d, floor %d)" % [label, count, before, int(world.inventory.get(name_value, 0)), floor_total(name_value)])
	var ids: Array = []
	for record: Dictionary in floor_of(name_value):
		ids.append(str(record.id))
		var shown: Dictionary = view_visible(world.ground_loot.views.get(str(record.id)))
		row["shown"] = shown
		check(shown.ok, "%s: the floor item is visible (%s)" % [label, JSON.stringify(shown)])
	# save / load keeps it on the floor and out of the bag
	check(world._save_game(true) == OK, "%s: save" % label)
	world.item_instances = {}; world.inventory = {}
	world._load_game(true)
	await frames(20)
	check(str(world.patch523_owner_state_problem).is_empty() and int(world.inventory.get(name_value, 0)) == before - count and floor_total(name_value) == floor_before + count, "%s: load keeps bag %d and floor %d (%s)" % [label, before - count, floor_total(name_value), str(world.patch523_owner_state_problem)])
	for id: String in ids:
		var rec: Dictionary = world.ground_loot.records.get(id, {})
		check(view_visible(world.ground_loot.views.get(id)).ok, "%s: the reloaded floor item is visible (record %s map %s/%s view %s)" % [label, str(not rec.is_empty()), str(rec.get("map_id","")), world.ground_loot.current_map, str(world.ground_loot.views.has(id))])
	# pick it up again
	await create_timer(float(world.ground_loot.MIN_VISIBLE_MS + 50) / 1000.0).timeout
	for id: String in ids:
		var record: Dictionary = world.ground_loot.records.get(id, {})
		var view: Variant = world.ground_loot.views.get(id)
		if record.is_empty() or not is_instance_valid(view): continue
		world.player.global_position = Vector2(float(record.position[0]), float(record.position[1]))
		check(world._collect_ground_drop(view), "%s: picked up again" % label)
	check(int(world.inventory.get(name_value, 0)) == before and floor_total(name_value) == floor_before, "%s: the bag holds %d again (%d)" % [label, before, int(world.inventory.get(name_value, 0))])
	evidence[label] = row

func run() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	# CI Core tests share user://: put back whatever save this test found.
	var save_file: String = world.save_path()
	var had_save: bool = FileAccess.file_exists(save_file)
	var saved_bytes: PackedByteArray = FileAccess.get_file_as_bytes(save_file) if had_save else PackedByteArray()
	world.field_population.set_process(false); world.player.set_physics_process(false); world.player.auto_enabled = false
	world._clear_monsters(); world._clear_drops()
	await frames(20)
	evidence["map"] = str(world.ground_loot.current_map)
	var native_installed: bool = not DEF.not_installed()
	evidence["native"] = native_installed
	var plain: Dictionary = await plain_record()
	if str(world.ground_loot.current_map).is_empty():
		evidence["no_field"] = true
	elif check(not plain.is_empty(), "a legacy-name bag item"):
		var plain_name: String = str(plain.name)
		await drop_kind("legacy", plain_name, plain_name, 2)
		if native_installed:
			if grant(366, 12): await drop_kind("material", native_name(366), native_name(366), 5)
			if grant(233, 4): await drop_kind("consumable", native_name(233), native_name(233), 1)
			if grant(27, 1):
				var weapon: String = native_name(27)
				await drop_kind("weapon", weapon, weapon + "@@@" + physical_id(weapon), 1)
		# An expired player drop from before the fix (it may have been invisible)
		# returns to the bag on load; a later one keeps the floor lifetime.
		var now: float = Time.get_unix_time_from_system()
		var position: Array = [world.player.global_position.x, world.player.global_position.y]
		var old_drop: Dictionary = {"id":"a".repeat(32), "item_name":plain_name, "quantity":2, "map_id":world.ground_loot.current_map, "position":position,
			"created_at":now - 7200.0, "expires_at":now - 3600.0, "state":"ground", "hunt_batch":"", "player_dropped":true, "item_record":plain.duplicate(true)}
		var new_drop: Dictionary = old_drop.duplicate(true)
		new_drop.id = "b".repeat(32); new_drop.created_at = MANAGER.INVISIBLE_DROP_RECOVERY_BEFORE + 10.0; new_drop.expires_at = now - 1.0
		var monster_drop: Dictionary = old_drop.duplicate(true)
		monster_drop.id = "c".repeat(32); monster_drop.erase("player_dropped")
		var held: int = int(world.inventory.get(plain_name, 0))
		world._restore_ground_drops([old_drop, new_drop, monster_drop])
		evidence["recovered"] = world.ground_loot.recovered_to_bag.duplicate(true)
		check(int(world.inventory.get(plain_name, 0)) == held + 2 and world.ground_loot.recovered_to_bag.size() == 1, "an expired pre-fix player drop returns 2 to the bag (%d -> %d)" % [held, int(world.inventory.get(plain_name, 0))])
		check(world.ground_loot.records.is_empty(), "expired floor records do not come back on the floor")
	world.queue_free()
	await frames(4)
	if had_save:
		var file := FileAccess.open(save_file, FileAccess.WRITE); file.store_buffer(saved_bytes); file.close()
	elif FileAccess.file_exists(save_file): DirAccess.remove_absolute(save_file)
	print("INVENTORY_FLOOR_DROP_KINDS_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
