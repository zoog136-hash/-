extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("SHIELD RULE FAIL: " + message)

func _run() -> void:
	var main_scene: PackedScene = load("res://Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn could not be loaded")
		_finish()
		return
	var world: Node = main_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	for weapon_type: String in ["단검", "한손검", "지팡이", "마검"]:
		if not bool(world.call("_weapon_supports_shield", {"type":weapon_type,"slot":"weapon"})):
			_fail("%s should allow shield" % weapon_type)
	for weapon_type: String in ["양손검", "그레이트소드", "창", "도끼", "이도류", "크로우", "사이드", "체인소드", "건틀렛", "활", "라이플", "핸드캐넌"]:
		if bool(world.call("_weapon_supports_shield", {"type":weapon_type,"slot":"weapon"})):
			_fail("%s should not allow shield" % weapon_type)

	var shield: Dictionary = {"name":"테스트 방패","type":"방패","slot":"armor","def":5}
	var guarder: Dictionary = {"name":"테스트 가더","type":"가더","slot":"armor","def":2}
	var catalog_shield: Dictionary = {"name":"마신의 방패","type":"방패/가더","slot":"offhand","def":5}
	var catalog_guarder: Dictionary = {"name":"샌드웜의 가더","type":"방패/가더","slot":"offhand","def":2}
	var catalog_focus: Dictionary = {"name":"마나 수정구","type":"방패/가더","slot":"offhand","def":1}
	var bow: Dictionary = {"name":"테스트 활","type":"활","slot":"weapon"}
	var sword: Dictionary = {"name":"테스트 검","type":"한손검","slot":"weapon"}

	world.set("equipped_items", {"weapon":sword,"armor":{},"offhand":{},"accessory":{}})
	if not bool(world.call("_can_equip_offhand", shield)):
		_fail("one-handed sword should allow shield")
	world.set("equipped_items", {"weapon":bow,"armor":{},"offhand":{},"accessory":{}})
	if bool(world.call("_can_equip_offhand", shield)):
		_fail("bow should block shield")
	if not bool(world.call("_can_equip_offhand", guarder)):
		_fail("guarder should remain compatible with bow")
	if str(world.call("_offhand_kind", catalog_shield)) != "shield":
		_fail("generic catalog shield should be classified as shield by name")
	if bool(world.call("_can_equip_offhand", catalog_shield)):
		_fail("generic catalog shield should be blocked by bow")
	if str(world.call("_offhand_kind", catalog_guarder)) != "guarder":
		_fail("generic catalog guarder should be classified as guarder by name")
	if not bool(world.call("_can_equip_offhand", catalog_guarder)):
		_fail("generic catalog guarder should remain compatible with bow")
	if str(world.call("_offhand_kind", catalog_focus)) != "offhand":
		_fail("generic catalog focus should remain a neutral offhand")
	if not bool(world.call("_can_equip_offhand", catalog_focus)):
		_fail("neutral catalog offhand should remain compatible with bow")

	world.set("equipped_items", {"weapon":bow,"armor":{},"offhand":shield,"accessory":{}})
	world.call("_enforce_shield_weapon_compatibility", true)
	var equipped: Dictionary = world.get("equipped_items") as Dictionary
	var offhand: Variant = equipped.get("offhand", {})
	if not (offhand is Dictionary) or not (offhand as Dictionary).is_empty():
		_fail("incompatible shield should auto-unequip")

	world.set("equipped_items", {"weapon":bow,"armor":{},"offhand":guarder,"accessory":{}})
	world.call("_enforce_shield_weapon_compatibility", true)
	equipped = world.get("equipped_items") as Dictionary
	offhand = equipped.get("offhand", {})
	if not (offhand is Dictionary) or (offhand as Dictionary).is_empty():
		_fail("guarder should not auto-unequip with bow")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("SHIELD_RULE_SMOKE_OK: shield/offhand weapon compatibility validated")
		quit(0)
	else:
		print("SHIELD_RULE_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
