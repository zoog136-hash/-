extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("INVENTORY DB FAIL: " + message)

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_fail("Main.tscn load failed")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	var catalog: Dictionary = world.get("catalog_db") as Dictionary
	var catalog_names: Dictionary = {}
	for v: Variant in catalog.get("아이템", []) as Array:
		if v is Dictionary:
			catalog_names[str((v as Dictionary).get("name",""))] = true
	if not catalog_names.has("낡은 장검"):
		_fail("local game DB equipment was not merged into catalog")

	var record: Dictionary = world.call("_find_catalog_item_record", "낡은 장검")
	if record.is_empty():
		_fail("local game DB equipment lookup failed")
	elif str(record.get("slot","")) != "weapon":
		_fail("local sword slot is not weapon")

	world.call("_on_job_class_selected", "기사")
	var inv: Dictionary = world.get("inventory") as Dictionary
	var before: int = int(inv.get("낡은 장검", 0))
	world.call("_on_inventory_item_activated", "낡은 장검")
	inv = world.get("inventory") as Dictionary
	var after: int = int(inv.get("낡은 장검", 0))
	if after != before:
		_fail("equipping from inventory changed item count")
	var equipped: Dictionary = world.get("equipped_items") as Dictionary
	if str((equipped.get("weapon", {}) as Dictionary).get("name","")) != "낡은 장검":
		_fail("double-tap inventory equipment did not equip weapon")

	var candidates: Array = world.call("_enhancement_candidates", "weapon", "normal")
	var found: bool = false
	for c: Variant in candidates:
		if c is Dictionary and str((c as Dictionary).get("name","")) == "낡은 장검":
			found = true
			break
	if not found:
		_fail("local DB weapon is missing from enhancement candidates")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("INVENTORY_DB_SMOKE_OK: local DB merge, inventory equip and enhancement lookup validated")
		quit(0)
	else:
		print("INVENTORY_DB_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
