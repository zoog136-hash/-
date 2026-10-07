extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("EQUIPMENT SLOT FAIL: " + message)

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

	var type_expect: Dictionary = {
		"투구":"helmet", "티셔츠":"tshirt", "갑옷":"body", "하의":"pants", "망토":"cloak", "견갑":"shoulder",
		"벨트":"belt", "각반":"gaiters", "신발":"boots", "장갑":"gloves", "팔찌":"bracelet",
		"목걸이":"necklace", "휘장":"badge", "수정":"crystal", "카탈리스트":"catalyst",
		"룬":"rune", "방패":"offhand", "가더":"offhand"
	}
	for item_type: Variant in type_expect.keys():
		var record: Dictionary = {"name":"테스트 "+str(item_type), "type":str(item_type), "slot":"armor"}
		var actual: String = str(world.call("_equipment_slot_base", record))
		if actual != str(type_expect[item_type]):
			_fail("%s expected %s, got %s" % [str(item_type), str(type_expect[item_type]), actual])

	var equipped: Dictionary = world.get("equipped_items") as Dictionary
	for required_slot: String in ["weapon","offhand","helmet","tshirt","body","pants","cloak","shoulder","belt","earring1","earring2","ring1","ring2","seal1","seal2","gaiters","boots","gloves","bracelet","necklace","badge","crystal","catalyst","rune"]:
		if not equipped.has(required_slot):
			_fail("missing equipment slot: " + required_slot)

	world.set("equipped_items", world.call("_empty_equipment_slots"))
	world.call("_equip_or_acquire_item", {"name":"테스트 반지 A","type":"반지","slot":"accessory","def":1})
	world.call("_equip_or_acquire_item", {"name":"테스트 반지 B","type":"반지","slot":"accessory","def":1})
	equipped = world.get("equipped_items") as Dictionary
	if str((equipped["ring1"] as Dictionary).get("name","")) != "테스트 반지 A":
		_fail("first ring did not use ring1")
	if str((equipped["ring2"] as Dictionary).get("name","")) != "테스트 반지 B":
		_fail("second ring did not use ring2")

	world.call("_equip_or_acquire_item", {"name":"테스트 귀걸이 A","type":"귀걸이","slot":"earring","def":1})
	world.call("_equip_or_acquire_item", {"name":"테스트 귀걸이 B","type":"귀걸이","slot":"earring","def":1})
	equipped = world.get("equipped_items") as Dictionary
	if (equipped["earring1"] as Dictionary).is_empty() or (equipped["earring2"] as Dictionary).is_empty():
		_fail("earrings did not occupy two distinct slots")

	world.call("_equip_or_acquire_item", {"name":"테스트 인장 A","type":"인장","slot":"seal","def":1})
	world.call("_equip_or_acquire_item", {"name":"테스트 인장 B","type":"인장","slot":"seal","def":1})
	equipped = world.get("equipped_items") as Dictionary
	if (equipped["seal1"] as Dictionary).is_empty() or (equipped["seal2"] as Dictionary).is_empty():
		_fail("seals did not occupy two distinct slots")

	world.set("equipped_items", {
		"weapon": {},
		"armor": {"name":"구형 투구","type":"투구","slot":"armor"},
		"shield": {"name":"구형 가더","type":"가더","slot":"armor"},
		"accessory": {"name":"구형 반지","type":"반지","slot":"accessory"}
	})
	world.call("_normalize_equipment_slots")
	equipped = world.get("equipped_items") as Dictionary
	if str((equipped["helmet"] as Dictionary).get("name","")) != "구형 투구":
		_fail("legacy armor was not migrated by type")
	if str((equipped["offhand"] as Dictionary).get("name","")) != "구형 가더":
		_fail("legacy shield was not migrated to offhand")
	if str((equipped["ring1"] as Dictionary).get("name","")) != "구형 반지":
		_fail("legacy accessory was not migrated by type")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("EQUIPMENT_SLOT_SMOKE_OK: DB-driven equipment slots and migration validated")
		quit(0)
	else:
		print("EQUIPMENT_SLOT_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
