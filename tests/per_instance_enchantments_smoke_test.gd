extends SceneTree

# All standard/blessed/craftsman/Orim and elemental enchantment targets must be physical IDs.
var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		print("PER_INSTANCE_FAIL: " + message)

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false, "Main.tscn did not load")
		_finish()
		return
	var world: Variant = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var service: Node = world.get("consumable_service") as Node
	_check(service != null, "Consumable service unavailable")
	if service == null:
		world.queue_free()
		await process_frame
		_finish()
		return

	world.set("equipped_items", {})
	world.set("inventory", {
		"낡은 장검":2,
		"무기 마법 주문서 (각인)":5,
		"축복받은 무기 마법 주문서 (각인)":2,
		"화령의 무기 강화 주문서":2
	})
	world.set("item_instances", {})
	world.set("enhancement_levels", {})
	world.set("next_item_instance_id", 1)
	world.call("_sync_item_instances")
	var instances: Dictionary = world.get("item_instances") as Dictionary
	var ids: Array[String] = []
	for key: Variant in instances.keys():
		if str((instances[key] as Dictionary).get("name", "")) == "낡은 장검":
			ids.append(str(key))
	ids.sort()
	_check(ids.size() == 2, "Same-name equipment copies must have 2 distinct instance IDs")
	if ids.size() != 2:
		world.queue_free()
		await process_frame
		_finish()
		return
	var a: String = ids[0]
	var b: String = ids[1]
	_check(a != b, "Both physical items were assigned the same ID")

	# Normal enchant uses the exact UI target_id. Guaranteed +1 while below safe cap.
	var options: Array = world.call("_enhancement_candidates", "weapon", "normal")
	_check(options.size() == 2, "Normal enhancement must list both identical items")
	var target_ids: Array[String] = []
	for opt: Variant in options:
		target_ids.append(str((opt as Dictionary).get("target_id", "")))
	_check(target_ids.has("낡은 장검@@@" + a), "First ID missing in standard enhancement")
	_check(target_ids.has("낡은 장검@@@" + b), "Second ID missing in standard enhancement")
	for scroll_mode: String in ["blessed", "craftsman"]:
		for opt: Variant in world.call("_enhancement_candidates", "weapon", scroll_mode):
			_check(str((opt as Dictionary).get("target_id", "")).contains("@@@"), "Scroll mode " + scroll_mode + " must use an instance ID")
	world.call("_attempt_enhancement", "무기 마법 주문서 (각인)", "낡은 장검@@@" + a)
	instances = world.get("item_instances") as Dictionary
	_check(int((instances[a] as Dictionary).get("level", -1)) == 1, "First sword did not increase to +1")
	_check(int((instances[b] as Dictionary).get("level", -1)) == 0, "Normal enhancement incorrectly changed second sword")

	# Equipping one of two same-named items must respect explicitly selected ID.
	world.call("_on_inventory_item_activated", "낡은 장검@@@" + b)
	var equipment: Dictionary = world.get("equipped_items") as Dictionary
	var held: Dictionary = equipment.get("weapon", {}) as Dictionary
	_check(str(held.get("instance_id", "")) == b, "Explicit second sword equip selected the wrong ID")
	_check(int(world.call("_equipment_enhancement_level", "weapon")) == 0, "Equipped sword inherited upgrade from different copy")
	var attack_before: int = int(world.call("_effective_attack"))
	(instances[a] as Dictionary)["level"] = 8
	_check(int(world.call("_effective_attack")) == attack_before, "Upgrading non-equipped sword changed equipped attack")

	# Elemental enchant scroll selects exact duplicate (success is probabilistic).
	service.call("apply_element_scroll", "화령의 무기 강화 주문서", "낡은 장검@@@" + b, "fire")
	instances = world.get("item_instances") as Dictionary
	var first: Dictionary = instances[a] as Dictionary
	var second: Dictionary = instances[b] as Dictionary
	_check(int(first.get("element_level", 0)) == 0, "Element scroll modified wrong sword")
	_check(int(second.get("element_level", 0)) in [0, 1], "Element level should succeed once or fail")
	_check(int((world.get("inventory") as Dictionary).get("낡은 장검", 0)) == 2, "Element scroll must not destroy swords")

	# Force known resulting enchant metadata to test stat routing, no combat RNG.
	second["element"] = "fire"
	second["element_level"] = 2
	instances[b] = second
	_check(str(service.call("weapon_element", held)) == "fire", "Equipped second sword element missing")
	_check(int(service.call("element_stage_cap", "낡은 장검", b)) == 3, "Regular sword elemental limit should be 3")
	first["level"] = 10
	instances[a] = first
	_check(int(service.call("element_stage_cap", "낡은 장검", a)) == 4, "+10 sword elemental limit should be 4")
	_check(int(service.call("element_stage_cap", "낡은 장검", b)) == 3, "Higher upgrade in other copy changed elemental limit")
	first["level"] = 11
	instances[a] = first
	_check(int(service.call("element_stage_cap", "낡은 장검", a)) == 5, "+11 sword elemental limit should be 5")
	for target: Variant in world.call("_enhancement_candidates", "weapon", "blessed"):
		_check(str((target as Dictionary).get("instance_id", "")) != "", "Blessed scroll has an unkeyed candidate")

	# Failure destroys only its actual target; equipped other item stays intact.
	world.call("_destroy_enhancement_target", "낡은 장검", a)
	instances = world.get("item_instances") as Dictionary
	_check(not instances.has(a), "Destroyed first sword ID still exists")
	_check(instances.has(b), "Destroying first sword also erased second sword")
	_check(int((world.get("inventory") as Dictionary).get("낡은 장검", 0)) == 1, "Destroy did not decrease count by exactly one")
	held = (world.get("equipped_items") as Dictionary).get("weapon", {}) as Dictionary
	_check(str(held.get("instance_id", "")) == b, "Destroying other sword unequipped surviving sword")
	_check(int((instances[b] as Dictionary).get("element_level", 0)) == 2, "Other sword lost elemental state")

	# Full save/load verifies stable ID, enchant, equip and no resurrected destroyed ID.
	world.call("_save_game", true)
	world.set("item_instances", {})
	world.set("equipped_items", {})
	world.set("inventory", {})
	world.call("_load_game", true)
	instances = world.get("item_instances") as Dictionary
	_check(not instances.has(a) and instances.has(b), "Save/load changed surviving physical IDs")
	if instances.has(b):
		_check(int((instances[b] as Dictionary).get("element_level", 0)) == 2, "Save/load lost elemental enchant")
	held = (world.get("equipped_items") as Dictionary).get("weapon", {}) as Dictionary
	_check(str(held.get("instance_id", "")) == b, "Save/load lost the right equipped instance")

	# Pre-instance saves have name-based enhancement; migrate once, not on future drops.
	world.set("inventory", {"낡은 장검":2})
	world.set("equipped_items", {})
	world.set("item_instances", {})
	world.set("enhancement_levels", {"낡은 장검":4})
	world.call("_sync_item_instances")
	instances = world.get("item_instances") as Dictionary
	var migrated_ids: Array[String] = []
	for key: Variant in instances.keys():
		if str((instances[key] as Dictionary).get("name", "")) == "낡은 장검":
			migrated_ids.append(str(key))
	_check(migrated_ids.size() == 2, "Old save migration failed to create two IDs")
	for id: String in migrated_ids:
		_check(int((instances[id] as Dictionary).get("level", 0)) == 4, "Old save lost existing enhancement")
	(world.get("inventory") as Dictionary)["낡은 장검"] = 3
	world.call("_sync_item_instances")
	instances = world.get("item_instances") as Dictionary
	var fresh_count: int = 0
	for key: Variant in instances.keys():
		var entry: Dictionary = instances[key] as Dictionary
		if str(entry.get("name", "")) == "낡은 장검" and int(entry.get("level", 0)) == 0:
			fresh_count += 1
	_check(fresh_count == 1, "Newly collected third sword inherited legacy +4 enchant")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if errors.is_empty():
		print("PER_INSTANCE_ENCHANTMENTS_OK: all enchantment targets, equip, loss, elemental, migration and persistence")
		quit(0)
	else:
		print("PER_INSTANCE_ENCHANTMENTS_FAILED: %d errors" % errors.size())
		quit(1)
