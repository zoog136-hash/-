extends SceneTree

var failures: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("ANIMATION RESTORE FAIL: " + label)

func _run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	world.save_timer = -10000
	world._set_map("aden_world", false)
	world.field_population.set_process(false)
	world.player.position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550, 4300)))
	var saved_position: Vector2 = world.player.position
	var chosen: Dictionary = {}
	for category: String in ["변신", "마법인형", "성물"]:
		chosen[category] = world.catalog_db[category][0].duplicate(true)
		world._equip_catalog(category, chosen[category])
	world.player.set_auto_enabled(true)
	var seq: int = world.player.start_combat_attack(saved_position + Vector2.RIGHT, 0.72, "slash")
	world._apply_transform_visual(chosen["변신"])
	check(world.player.position == saved_position and world.player.auto_enabled, "transformation changed position or AUTO")
	check(world.player.motion.sequence == seq and world.player.motion.active, "transformation lost active attack")
	var attack_interval: float = world._normal_attack_interval()
	var move_multiplier: float = world.player.equipment_move_speed_multiplier
	var expected_hp: int = world.hp
	world._save_game(true)
	world.equipped_catalog = {"변신":{}, "마법인형":{}, "성물":{}}
	world._restore_equipped_visuals()
	world.player.position += Vector2(90, 40)
	var arrivals: Array[int] = []
	world.combat_flights.launch(world.player.position, world.player, "magic", func() -> void: arrivals.append(1))
	world._load_game(true)
	check(world.player.position.is_equal_approx(saved_position), "load changed saved foot position")
	check(world.player.transform_active, "load did not restore transformation")
	check(world.player.motion.profile.profile_id == "transform:" + str(chosen["변신"].sourceId), "wrong restored transformation profile")
	check(world.doll_motion.enabled and world.relic_motion.enabled, "load lost either companion")
	check(world.doll_motion.motion.profile.profile_id == "doll:" + str(chosen["마법인형"].sourceId), "wrong restored doll profile")
	check(world.relic_motion.profile.profile_id == "relic:" + str(chosen["성물"].sourceId), "wrong restored relic profile")
	check(is_equal_approx(world._normal_attack_interval(), attack_interval), "restored attack speed changed")
	check(is_equal_approx(world.player.equipment_move_speed_multiplier, move_multiplier), "restored move speed changed")
	check(world.hp == expected_hp, "equipment HP changed during restore")
	check(world.combat_flights.flights.is_empty() and world.pending_attack.is_empty() and not world.player.motion.active, "load retained stale combat callbacks")
	world.combat_flights._physics_process(1.0)
	check(arrivals.is_empty(), "old projectile resolved after load")
	for category: String in chosen:
		check(str(world.equipped_catalog[category].sourceId) == str(chosen[category].sourceId), "lost saved catalog ID " + category)
	for i: int in range(90): world._update_companion(1.0 / 60.0)
	check(world.companion_sprite.visible and world.relic_sprite.visible, "restored companions stayed hidden")
	check(world.companion_sprite.global_position.distance_to(world.relic_sprite.global_position) > 50.0, "restored companions overlap")
	world._apply_doll_visual({})
	world._apply_relic_visual({})
	for i: int in range(30): world._update_companion(1.0 / 60.0)
	check(not world.companion_sprite.visible and not world.relic_sprite.visible, "companion dismissal stayed visible")
	world.queue_free()
	await process_frame
	if failures == 0: print("ANIMATION_RESTORE_OK transform_doll_relic=true speeds=true stale_actions=false")
	quit(0 if failures == 0 else 1)
