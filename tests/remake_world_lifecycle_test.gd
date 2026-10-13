extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var impacts: int = 0

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("REMAKE_WORLD FAIL: " + message)

func _run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world), "enter production Main")
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world._clear_monsters()
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3300, 4370)))
	var target: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(target)
	var record: Dictionary = world.monster_db[0].duplicate(true)
	target.setup(record, world.player, world, world._monster_texture(record))
	target.global_position = world.player.global_position
	target.set_physics_process(false)
	world._queue_player_attack(target, "melee", func() -> void: impacts += 1, 0.6, false, 100)
	var sequence: int = int(world.pending_attack.id)
	target.life_id += 1
	world._release_player_attack(sequence)
	check(impacts == 0 and world.pending_attack.is_empty(), "old windup cannot hit reused pooled actor")
	world._queue_player_attack(target, "melee", func() -> void: impacts += 1, 0.6, false, 100)
	var action: Dictionary = world.pending_attack
	world.pending_attack = {}
	world._impact_player_attack(action)
	world._impact_player_attack(action)
	check(impacts == 1, "one impact event has one callback")
	world._clear_combat_actions()
	world.player.motion.dead = true
	world._queue_damage_skill({"name":"rejected fixture", "attack_style":"melee"}, target, 100)
	check(world.pending_attack.is_empty(), "rejected start cannot leave metadata-only pending skill")
	world.player.motion.dead = false
	world.combat_flights.launch(Vector2.ZERO, target, "ranged", func() -> void: impacts += 1, 100)
	target.life_id += 1
	world.combat_flights._physics_process(0.01)
	check(world.combat_flights.flights.is_empty() and impacts == 1, "in-flight projectile retires when target life changes")
	var point_target := Node2D.new()
	world.add_child(point_target)
	point_target.global_position = Vector2(100, 24)
	world.combat_flights.launch(Vector2.ZERO, point_target, "ranged", func() -> void: impacts += 1, 100, 0.10)
	world.combat_flights._physics_process(0.15)
	check(world.combat_flights.flights.size() == 1, "delayed shot still in flight")
	check(is_equal_approx((world.combat_flights.flights[0].position as Vector2).x, 5.0), "low FPS delayed shot only travels time after release")
	world._clear_combat_actions()
	world._on_job_class_selected("마법사")
	var firestorm: Dictionary = world.original_skills.catalog.record_for("파이어스톰")
	check(not firestorm.is_empty(), "actual DB self-circle skill exists")
	world.original_skills.catalog.learned[str(firestorm.id)] = 1
	world.level = 90
	world.mp = 999
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	check(world.original_skills.cast(firestorm), "paid self-circle cast queues production motion")
	check(world.pending_attack.has("area_skill") and world.player.motion.active, "self-circle uses shared pending timeline")
	var cast_duration: float = world.player.motion.attack_duration
	world.player.cancel_attack()
	check(world.pending_attack.is_empty(), "movement/interrupt cancellation removes area marker")
	var original_cooldown_factor: float = world._skill_cooldown_factor()
	world.active_skill_buffs["remake_cast_option"] = {"skill_id":"remake_fixture", "skill_stats":{"castSpeed":20}}
	check(is_equal_approx(world._skill_cooldown_factor(), clampf(original_cooldown_factor - 0.2, 0.1, 1.0)), "cast-speed stat adds cooldown reduction to existing transform options")
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	world.mp = 999
	check(world.original_skills.cast(firestorm), "cast with speed option")
	check(is_equal_approx(world.player.motion.attack_duration, cast_duration), "cast speed does not accelerate animation again")
	world._clear_combat_actions()
	world.apply_presentation_settings({"reduced_motion":true, "impact_intensity":0.2, "effect_detail":"low"})
	check(world.player.motion.reduced_motion and target.motion.reduced_motion, "presentation setting reaches live actors")
	check(world.combat_vfx.reduced_motion and is_equal_approx(world.combat_vfx.impact_intensity, 0.2), "presentation setting reaches actual effects")
	check(world.combat_flights.visual_limit == 24 and Engine.time_scale == 1.0, "visual budget leaves gameplay time running")
	world.monster_combat_feedback(target, true)
	check(is_zero_approx(world.player.motion.visual_hold), "reduced motion disables local critical hold")
	target.dead = true
	world._on_monster_died(target)
	var rewards: Array = [world.experience, world.gold, world.ground_loot.records.size()]
	world._on_monster_died(target)
	check(rewards == [world.experience, world.gold, world.ground_loot.records.size()], "duplicate death cannot duplicate XP/gold/floor rewards")
	var before_hp: int = world.hp
	world._on_player_hit(target, 999, "magic")
	check(world.hp == before_hp, "dead actor cannot damage player")
	var frames := SpriteFrames.new()
	frames.add_animation("death")
	frames.add_frame("death", null, 1)
	frames.add_frame("death", null, 8)
	frames.add_frame("death", null, 1)
	check(TwilightCombatVFX._death_frame(frames, "death", 0.85) == 1, "corpse sequence retains unequal ticks")
	world.queue_free()
	await process_frame
	print("REMAKE_WORLD_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
