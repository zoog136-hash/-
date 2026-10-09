extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("CONSUMABLE FAIL: " + message)

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
	_check(service != null, "Consumable service missing")
	if service == null:
		world.queue_free()
		await process_frame
		_finish()
		return

	# Test catalog and removal, including legacy saved inventories.
	var catalog: Dictionary = world.call("_find_catalog_item_record", "마나 회복 물약")
	_check(not catalog.is_empty(), "MP potion not present in catalog")
	var inv: Dictionary = world.get("inventory") as Dictionary
	inv["해독제"] = 2
	inv["상태이상 해제 물약"] = 1
	service.call("prune_removed")
	_check(not inv.has("해독제") and not inv.has("상태이상 해제 물약"), "Removed cleanser survived save pruning")

	# MP regen 5 per 30s, no immediate full refill.
	inv["마나 회복 물약"] = 2
	world.set("mp", 0)
	world.call("_on_inventory_item_activated", "마나 회복 물약")
	_check(int(inv.get("마나 회복 물약", 0)) == 1, "MP potion did not consume exactly one")
	var buffs: Dictionary = world.get("active_item_buffs") as Dictionary
	_check(buffs.has("마나 회복 물약"), "MP potion buff not active")
	_check(int(world.get("mp")) == 0, "Regeneration potion applied instant MP unexpectedly")
	world.call("_tick_item_buffs", 30.0)
	_check(int(world.get("mp")) == 5, "30s MP regen did not restore 5")

	# Food category uses existing damage/MR runtime, same-group cooking does not stack.
	var str_base: int = int(world.call("_melee_damage_stat"))
	var mr_base: int = int(world.call("_effective_mr"))
	inv["힘센 한우 스테이크"] = 2
	world.set("job_class", "기사")
	world.call("_on_inventory_item_activated", "힘센 한우 스테이크")
	_check(int(inv.get("힘센 한우 스테이크", 0)) == 1, "Food not consumed")
	_check(int(world.call("_melee_damage_stat")) >= str_base + 2, "Food melee bonus not applied")
	_check(int(world.call("_effective_mr")) == mr_base + 10, "Food MR bonus not applied")
	world.call("_tick_item_buffs", 30.0)
	_check(int(world.get("mp")) == 12, "Food and MP potion periodic recovery did not stack correctly")

	# Instant MP healer obeys cooldown and maximum; duplicate use must not consume.
	inv["마녀의 마력 회복제"] = 2
	world.set("mp", 0)
	world.call("_on_inventory_item_activated", "마녀의 마력 회복제")
	_check(int(world.get("mp")) == int(world.call("_effective_max_mp")), "Instant MP potion not capped at MP max")
	_check(int(inv.get("마녀의 마력 회복제", 0)) == 1, "Instant MP potion did not consume once")
	world.call("_on_inventory_item_activated", "마녀의 마력 회복제")
	_check(int(inv.get("마녀의 마력 회복제", 0)) == 1, "Cooldown bypass consumed a second instant potion")

	# Permanent elixir stats and caps are independent of level-up points.
	inv["힘의 엘릭서"] = 2
	var before_str: int = int(world.get("str_stat"))
	var before_points: int = int(world.get("stat_points"))
	world.set("level", 50)
	service.call("apply_elixir", "힘의 엘릭서", "STR")
	_check(int(world.get("str_stat")) == before_str + 1, "Elixir did not increase permanent STR")
	_check(int(world.get("stat_points")) == before_points, "Elixir unexpectedly consumed level-up stat points")
	_check(int(inv.get("힘의 엘릭서", 0)) == 1, "Elixir count did not decrease")
	var saved_state: Dictionary = service.call("export_state")
	_check(int(saved_state.get("elixirs_used", 0)) == 1, "Elixir use count did not persist")
	service.call("import_state", saved_state)
	_check(int((service.call("export_state") as Dictionary).get("elixirs_used", 0)) == 1, "Elixir restore failed")

	# Element scroll rolls are allowed to fail, but must never destroy weapon.
	inv["낡은 장검"] = 1
	inv["화령의 무기 강화 주문서"] = 1
	service.call("apply_element_scroll", "화령의 무기 강화 주문서", "낡은 장검", "fire")
	_check(int(inv.get("화령의 무기 강화 주문서", 0)) == 0, "Element scroll did not consume")
	_check(int(inv.get("낡은 장검", 0)) == 1, "Element scroll failure destroyed weapon")
	var physical_id: String = str(world.call("_chosen_instance", "낡은 장검"))
	var physical: Dictionary = (world.get("item_instances") as Dictionary).get(physical_id, {}) as Dictionary
	_check(int(physical.get("element_level", 0)) >= 0 and int(physical.get("element_level", 0)) <= 1, "Element enchant level invalid")
	_check(int(service.call("element_stage_cap", "낡은 장검", physical_id)) == 3, "Basic weapon elemental cap should be 3")
	physical["level"] = 10
	_check(int(service.call("element_stage_cap", "낡은 장검", physical_id)) == 4, "+10 weapon elemental cap should be 4")
	physical["level"] = 11
	_check(int(service.call("element_stage_cap", "낡은 장검", physical_id)) == 5, "+11 weapon elemental cap should be 5")
	physical["level"] = 0

	# Random teleport stays on same map and is traversable.
	inv["순간이동 주문서"] = 1
	var original_map: String = str(world.get("active_map_id"))
	var original_position: Vector2 = world.player.global_position
	world.call("_on_inventory_item_activated", "순간이동 주문서")
	_check(str(world.get("active_map_id")) == original_map, "Random scroll changed current map")
	_check(int(inv.get("순간이동 주문서", 0)) == 0, "Random scroll did not consume")
	_check(bool(world.call("_is_walkable_world", world.player.global_position)), "Random scroll landed inside wall")
	_check(world.player.global_position.distance_to(original_position) >= 100.0, "Random scroll did not move character")

	# Return from a dungeon is always to Aden; not to a dungeon 'safe' region.
	inv["귀환 주문서"] = 1
	world.call("_set_map", "oman_01", false)
	world.call("_on_inventory_item_activated", "귀환 주문서")
	_check(str(world.get("active_map_id")) == "aden_world", "Return scroll did not go to Aden town")
	_check(int(inv.get("귀환 주문서", 0)) == 0, "Return scroll did not consume")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("CONSUMABLE_SMOKE_OK: MP, cooking, removals, elixir, elemental scrolls, random/return teleport")
		quit(0)
	else:
		print("CONSUMABLE_SMOKE_FAILED: %d errors" % failures.size())
		quit(1)
