extends SceneTree

const MANAGER = preload("res://scripts/loot/ground_loot_manager.gd")
const TRANSFER = preload("res://scripts/loot/inventory_ground_transfer.gd")
var failures: Array[String] = []

class TestWorld extends Node:
	var drops_root := Node2D.new()
	var catalog_db: Dictionary = {}
	var item_db: Array = []
	var loot_catalog: Dictionary = {"by_name":{}}
	var maps_by_id: Dictionary = {"a":{},"b":{}}
	var item_instances: Dictionary = {}
	var next_item_instance_id: int = 1
	func _is_walkable_world(point: Vector2) -> bool: return point.is_finite()
	func _has_line_of_sight_world(_from: Vector2, _to: Vector2) -> bool: return true
	func _world_to_cell(point: Vector2) -> Vector2i: return Vector2i(point)
	func _nearest_walkable_cell(cell: Vector2i) -> Vector2i: return cell
	func _cell_to_world(cell: Vector2i) -> Vector2: return Vector2(cell)

class TestManager extends TwilightGroundLootManager:
	func _create_view(record: Dictionary) -> Button:
		# Intercept only rendering, so the production restore/validation/expiry/
		# ownership paths run and the first grade delivered to the view is seen.
		var view := TwilightGroundLoot.new()
		view.set_meta("id",record.id)
		view.set_meta("grade",record.grade)
		view.visible_since = Time.get_ticks_msec()-1000
		world.drops_root.add_child(view)
		views[str(record.id)] = view
		return view

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("GROUND_GRADE_FAIL: ",label)

func without_grade_metadata(value: Variant) -> Variant:
	if value is Dictionary:
		var copy: Dictionary = {}
		for key: Variant in value:
			if str(key) not in ["grade","grade_original","sourceQuality","grade_evidence"]:
				copy[key] = without_grade_metadata(value[key])
		return copy
	if value is Array:
		var copy: Array = []
		for entry: Variant in value: copy.append(without_grade_metadata(entry))
		return copy
	return value

func saved_drop(id: String, item: Dictionary, index: int, now: float, physical_id: String = "") -> Dictionary:
	var result: Dictionary = {"id":id,"item_name":item.name,"grade":item.grade,"quantity":1,
		"map_id":"a" if index != 1 else "b","position":[index*100,0],"created_at":now-100,
		"expires_at":now+300,"state":"ground","hunt_batch":"original-batch", "item_record":item.duplicate(true)}
	if not physical_id.is_empty():
		result["player_dropped"] = true
		result["physical_item"] = {"id":physical_id,"data":{"name":item.name,"level":9,
			"element":"fire","element_level":3,"bless_state":"blessed","record":item.duplicate(true)}}
	return result

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var world := TestWorld.new()
	world.catalog_db = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	world.item_db = db["아이템"]
	for item: Dictionary in world.item_db: world.loot_catalog.by_name[str(item.name)] = item
	root.add_child(world)
	world.add_child(world.drops_root)
	var manager := TestManager.new()
	manager.configure(world)
	manager.current_map = "a"
	var now: float = Time.get_unix_time_from_system()
	var original: Array = [
		saved_drop("carried",{"name":"군터의 단도","slot":"weapon","sourceId":"176582","grade":"일반","atk":123},0,now,"98"),
		saved_drop("other-map",{"name":"군터의 단도","slot":"weapon","grade":"신화","atk":55},1,now,"99"),
		saved_drop("unknown-id",{"name":"군터의 단도","slot":"weapon","sourceId":"missing-id","grade":"일반","atk":77},2,now,"100"),
		saved_drop("wrong-id",{"name":"군터의 단도","slot":"weapon","sourceId":"344361","grade":"일반","atk":78},3,now,"101"),
		saved_drop("special",{"name":"민첩의 카탈리스트","slot":"catalyst","sourceId":"289072","grade":"희귀","atk":79},4,now,"102"),
		saved_drop("monster",{"name":"수정 단검","slot":"weapon","grade":"고급"},5,now)
	]
	original[5].erase("item_record") # Ordinary monster loot has no physical snapshot.
	var untouched: Array = original.duplicate(true)
	manager.restore(original)
	check(original == untouched,"loading does not mutate caller's stored snapshot")
	check(manager.records.size()==6 and world.item_instances.is_empty(),"restore keeps ownership on the ground without grants")
	for index: int in range(original.size()):
		var id: String = str(original[index].id)
		check(without_grade_metadata(manager.records[id]) == without_grade_metadata(original[index]),"ID, count, map, position, expiry, enhancement, element, blessing and stats preserved: "+id)
	for id: String in ["carried","other-map"]:
		var record: Dictionary = manager.records[id]
		check(record.grade=="전설" and record.item_record.grade=="전설" and record.physical_item.data.record.grade=="전설","display and pickup payload share corrected grade: "+id)
	check(manager.views["carried"].get_meta("grade")=="전설","correct grade is ready before floor view creation")
	check(not manager.views.has("other-map"),"inactive-map item repaired without creating a view")
	check(manager.records.monster.grade=="희귀","ordinary monster drop follows current loot catalog")
	check(manager.records["unknown-id"].item_record==original[2].item_record,"unknown source ID does not borrow a matching name")
	check(manager.records["wrong-id"].physical_item.data.record==original[3].physical_item.data.record,"wrong source ID remains untouched")
	check(manager.records.special.item_record==original[4].item_record,"unmapped source quality is not guessed")
	var snapshot: Array = manager.snapshot()
	manager.restore(snapshot)
	check(manager.snapshot()==snapshot,"second save/restore is stable")
	var taken: Dictionary = manager.take(manager.views["carried"],Vector2.ZERO,60.0)
	TRANSFER.restore_physical(world,taken)
	check(not manager.records.has("carried") and world.item_instances.has("98"),"pickup transfers the original physical ID exactly once")
	check(world.item_instances["98"].record.grade=="전설" and world.item_instances["98"].level==9 and world.item_instances["98"].element_level==3,"pickup cannot resurrect the stale grade or lose enhancement")
	manager.hide_map()
	world.queue_free()
	await process_frame
	print("GROUND_LOOT_GRADE_RESTORE_RESULT ",JSON.stringify({"snapshots":6,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
