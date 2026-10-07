extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("ITEM BUFF FAIL: " + message)

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

	var conqueror: Dictionary = world.call("_find_catalog_item_record", "정복자의 서클릿")
	if conqueror.is_empty():
		_fail("정복자의 서클릿 DB record missing")
	else:
		var parsed: Dictionary = world.call("_timed_item_buff_from_record", conqueror)
		if int(parsed.get("duration", 0)) != 600:
			_fail("정복자의 서클릿 duration should be 600 seconds")
		if int(parsed.get("hp_flat", 0)) != 1000:
			_fail("Max HP +1000 was not parsed")
		if int(parsed.get("stun_resistance", 0)) != 5:
			_fail("stun resistance +5 was not parsed")
		if int(parsed.get("damage_reduction", 0)) != 5:
			_fail("damage reduction +5 was not parsed")
		if int(parsed.get("melee_damage", 0)) != 5 or int(parsed.get("ranged_damage", 0)) != 5:
			_fail("melee/ranged damage +5 was not parsed")
		if int(parsed.get("sp", 0)) != 5:
			_fail("SP +5 was not parsed")
		if int(parsed.get("melee_accuracy", 0)) != 10 or int(parsed.get("ranged_accuracy", 0)) != 10 or int(parsed.get("magic_accuracy", 0)) != 5:
			_fail("accuracy effects were not parsed")

		var inv: Dictionary = world.get("inventory") as Dictionary
		inv["정복자의 서클릿"] = 2
		world.set("inventory", inv)
		var hp_max_before: int = world.call("_effective_max_hp")
		var melee_before: int = world.call("_melee_damage_stat")
		var ranged_before: int = world.call("_ranged_damage_stat")
		var magic_before: int = world.call("_magic_damage_stat")
		var stun_before: int = world.call("_stun_resistance_stat")
		world.call("_on_inventory_item_activated", "정복자의 서클릿")
		inv = world.get("inventory") as Dictionary
		if int(inv.get("정복자의 서클릿", 0)) != 1:
			_fail("timed buff item did not consume exactly one")
		if int(world.call("_effective_max_hp")) != hp_max_before + 1000:
			_fail("timed Max HP buff not applied")
		if int(world.call("_melee_damage_stat")) != melee_before + 5:
			_fail("timed melee damage buff not applied")
		if int(world.call("_ranged_damage_stat")) != ranged_before + 5:
			_fail("timed ranged damage buff not applied")
		if int(world.call("_magic_damage_stat")) != magic_before + 5:
			_fail("timed SP buff not applied to magic damage")
		if int(world.call("_stun_resistance_stat")) != mini(100, stun_before + 5):
			_fail("timed stun resistance buff not applied")

	var balrog: Dictionary = world.call("_find_catalog_item_record", "발록의 가호")
	if balrog.is_empty():
		_fail("발록의 가호 DB record missing")
	else:
		var parsed_balrog: Dictionary = world.call("_timed_item_buff_from_record", balrog)
		if int(parsed_balrog.get("duration", 0)) != 600 or int(parsed_balrog.get("cooldown", 0)) != 3600:
			_fail("발록의 가호 duration/cooldown not parsed")
		var inv2: Dictionary = world.get("inventory") as Dictionary
		inv2["발록의 가호"] = 2
		world.set("inventory", inv2)
		world.call("_on_inventory_item_activated", "발록의 가호")
		inv2 = world.get("inventory") as Dictionary
		var count_after_first: int = int(inv2.get("발록의 가호", 0))
		world.call("_on_inventory_item_activated", "발록의 가호")
		inv2 = world.get("inventory") as Dictionary
		if int(inv2.get("발록의 가호", 0)) != count_after_first:
			_fail("cooldown did not block second use")
		var cooldowns: Dictionary = world.get("item_use_cooldowns") as Dictionary
		if int(cooldowns.get("발록의 가호", 0)) != 3600:
			_fail("1 hour cooldown was not stored")

	var teleport_scroll: Dictionary = world.call("_find_catalog_item_record", "오만의 탑 1층 이동 주문서")
	if not teleport_scroll.is_empty():
		var inv3: Dictionary = world.get("inventory") as Dictionary
		inv3["오만의 탑 1층 이동 주문서"] = 1
		world.set("inventory", inv3)
		world.call("_on_inventory_item_activated", "오만의 탑 1층 이동 주문서")
		inv3 = world.get("inventory") as Dictionary
		if int(inv3.get("오만의 탑 1층 이동 주문서", 0)) != 1:
			_fail("empty-desc teleport scroll should not be consumed")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("ITEM_BUFF_SMOKE_OK: DB-description timed item buffs validated")
		quit(0)
	else:
		print("ITEM_BUFF_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
