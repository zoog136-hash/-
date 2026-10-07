extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("WEAPON RULE FAIL: " + message)

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

	var cases: Dictionary = {
		"사이드":3, "창":3, "체인소드":5,
		"라이플":8, "핸드 캐넌":8, "활":10,
		"단검":1, "한손검":1, "양손검":1, "도끼":1, "지팡이":1
	}
	for weapon_type: Variant in cases.keys():
		var normalized: String = str(world.call("_normalized_weapon_type", str(weapon_type)))
		var actual: int = int(world.call("_weapon_range_cells_from_type", normalized))
		var expected: int = int(cases[weapon_type])
		if actual != expected:
			_fail("%s range expected %d cells, got %d" % [str(weapon_type), expected, actual])

	var bow: Dictionary = {"name":"테스트 활","type":"활","slot":"weapon","weaponAttackSpeed":27.5,"attackKind":"ranged","attackRangeCells":10,"ammo":"화살"}
	var rifle: Dictionary = {"name":"테스트 라이플","type":"라이플","slot":"weapon","weaponAttackSpeed":21.0,"attackKind":"ranged","attackRangeCells":8,"ammo":"총알"}
	var sword: Dictionary = {"name":"테스트 검","type":"한손검","slot":"weapon","weaponAttackSpeed":23.0,"attackKind":"melee","attackRangeCells":1,"ammo":""}
	if not bool(world.call("_weapon_allowed_for_job", bow, "요정")):
		_fail("Elf should be able to equip bow")
	if bool(world.call("_weapon_allowed_for_job", bow, "기사")):
		_fail("Knight should not be able to equip bow")
	if not bool(world.call("_weapon_allowed_for_job", rifle, "총사")):
		_fail("Gunslinger should be able to equip rifle")
	if not bool(world.call("_weapon_allowed_for_job", sword, "기사")):
		_fail("Knight should be able to equip one-handed sword")

	world.set("equipped_items", {"weapon":bow,"armor":{},"accessory":{}})
	var inventory: Dictionary = world.get("inventory") as Dictionary
	inventory["화살"] = 2
	world.set("inventory", inventory)
	if str(world.call("_current_attack_kind")) != "ranged":
		_fail("Bow must use ranged attack")
	if int(world.call("_current_attack_range_cells")) != 10:
		_fail("Bow must have 10-cell range")
	if str(world.call("_current_ammo_name")) != "화살":
		_fail("Bow must consume arrows")
	if not bool(world.call("_consume_weapon_ammo")):
		_fail("Bow should fire with arrows")
	inventory = world.get("inventory") as Dictionary
	if int(inventory.get("화살", 0)) != 1:
		_fail("Arrow was not consumed by one shot")

	world.set("equipped_items", {"weapon":rifle,"armor":{},"accessory":{}})
	inventory = world.get("inventory") as Dictionary
	inventory["총알"] = 1
	world.set("inventory", inventory)
	if int(world.call("_current_attack_range_cells")) != 8:
		_fail("Gun must have 8-cell range")
	if not bool(world.call("_consume_weapon_ammo")):
		_fail("Gun should fire with bullets")
	inventory = world.get("inventory") as Dictionary
	if int(inventory.get("총알", 0)) != 0:
		_fail("Bullet was not consumed by one shot")

	world.set("equipped_items", {"weapon":sword,"armor":{},"accessory":{}})
	if str(world.call("_current_attack_kind")) != "melee":
		_fail("Sword must use melee attack")
	if int(world.call("_current_attack_range_cells")) != 1:
		_fail("Other weapons must have 1-cell range")
	if str(world.call("_current_ammo_name")) != "":
		_fail("Melee weapon must not require ammo")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("WEAPON_RULE_SMOKE_OK: class limits, weapon range, attack type and ammo validated")
		quit(0)
	else:
		print("WEAPON_RULE_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
