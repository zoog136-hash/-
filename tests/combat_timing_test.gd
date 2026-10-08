extends SceneTree

var failures: Array[String] = []
var releases: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, detail: String) -> void:
	if not ok:
		failures.append(detail)
		print("COMBAT TIMING FAIL: " + detail)

func _run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	if world.field_population != null: world.field_population.set_process(false)
	for mob: Node in world.monsters_root.get_children():
		if world.field_population != null: world.field_population.release(mob)
		world.monsters_root.remove_child(mob)
		mob.queue_free()
	var dummy: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(dummy)
	dummy.setup({"name":"타이밍 표적", "hp":900000, "ac":0}, world.player, world, null)
	dummy.set_physics_process(false)
	dummy.collision_layer = 0
	dummy.collision_mask = 0
	dummy.position = world.player.position
	world.equipped_items.weapon = {"name":"테스트검", "type":"한손검", "slot":"weapon"}
	world.selected_monster = dummy
	world.player.attack_strike.connect(func(_id: int) -> void: releases += 1)
	var initial_hp: int = dummy.hp
	world._attack()
	check(dummy.hp == initial_hp and not world.pending_attack.is_empty(), "damage occurred at command instead of hit frame")
	await create_timer(0.10).timeout
	check(dummy.hp == initial_hp and releases == 0, "damage occurred in windup")
	await create_timer(0.72).timeout
	check(releases == 1 and world.pending_attack.is_empty(), "one swing did not emit exactly one marker")
	check(dummy.damage_hit_count <= 1, "duplicate normal damage")
	var count: int = dummy.damage_hit_count
	world.auto_attack_timer = 0.0
	world._attack()
	world.player.set_touch_vector(Vector2.RIGHT)
	await create_timer(0.05).timeout
	world.player.set_touch_vector(Vector2.ZERO)
	await create_timer(0.75).timeout
	check(dummy.damage_hit_count == count and world.pending_attack.is_empty(), "manual move failed to cancel pending hit")
	world.mp = 100
	check(world._cast_magic_attack(dummy, 26, 3, "busy marker check"), "legacy command did not start windup")
	var legacy_sequence: int = int(world.pending_attack.get("id", -1))
	check(not world._cast_magic_attack(dummy, 26, 3, "duplicate command"), "legacy command overwrote pending attack")
	check(world.mp == 97 and int(world.pending_attack.get("id", -1)) == legacy_sequence, "rejected duplicate consumed MP or changed sequence")
	await create_timer(0.85).timeout
	# An in-flight spell follows the original moving target, not selection.
	var arrived: Array[int] = []
	world.combat_flights.launch(world.player.position + Vector2(-100, -24), dummy, "magic", func() -> void: arrived.append(1), 300.0)
	dummy.position.x += 20.0
	await create_timer(0.08).timeout
	check(arrived.is_empty(), "projectile hit before arrival")
	await create_timer(0.65).timeout
	check(arrived.size() == 1, "moving projectile target failed / duplicate impact")
	world.combat_flights.launch(world.player.position + Vector2(-100, -24), dummy, "ranged", func() -> void: arrived.append(1), 100.0)
	dummy.dead = true
	await create_timer(0.15).timeout
	check(arrived.size() == 1 and world.combat_flights.flights.is_empty(), "dead target received projectile")
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("COMBAT_TIMING_OK real_physics_frames=true")
	quit(0 if failures.is_empty() else 1)
