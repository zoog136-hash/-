extends SceneTree

var failures: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("VOLLEY FAIL: " + label)

func _run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for child: Node in world.monsters_root.get_children():
		world.field_population.release(child)
		world.monsters_root.remove_child(child)
		child.queue_free()
	var mob: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(mob)
	mob.setup({"name":"연사 검증", "hp":999999, "ac":0}, world.player, world, null)
	mob.set_physics_process(false)
	mob.position = world.player.position
	world._on_job_class_selected("요정")
	world.equipped_items.weapon = {"name":"연사 활", "type":"활", "slot":"weapon"}
	world.selected_monster = mob
	world.mp = 999
	world.inventory["화살"] = 100
	var skill: Dictionary = world._skill_record("트리플 애로우")
	world.level = 90
	world.inventory[str(skill.book_name)] = 1
	world.original_skills.catalog.learn(str(skill.id))
	world.skills_db = [skill]
	world.active_skill_buffs.clear()
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	check(world._cast_job_skill("트리플 애로우"), "triple command rejected")
	check(mob.damage_hit_count == 0, "volley hit at command")
	world.player.motion.advance(0.3, Vector2.ZERO)
	check(world.combat_flights.flights.size() == 3, "triple did not launch 3 independently scheduled projectiles")
	var start_count: int = world.combat_flights.resolved_count
	world.combat_flights._physics_process(0.035)
	var first_count: int = world.combat_flights.resolved_count
	check(first_count > start_count and first_count < start_count + 3, "volley impacts collapsed into one frame")
	preload("res://tests/combat_test_clock.gd").settle(world)
	check(world.combat_flights.resolved_count == start_count + 3, "volley impact count not exactly three")
	check(int(world.inventory["화살"]) == 97, "volley ammo cost changed")
	check(mob.damage_hit_count <= 3 and mob.damage_hit_count > 0, "volley damage duplicated or missing")
	world.combat_vfx.clear()
	mob.take_damage(5, true)
	var critical_count: int = 0
	for entry: Dictionary in world.combat_vfx.active:
		if bool(entry.get("critical", false)): critical_count += 1
	check(critical_count == 2, "actual critical lacks impact and number")
	check(world.player.motion.visual_hold > 0 and Engine.time_scale == 1.0, "critical hit stop altered simulation clock")
	world.queue_free()
	await process_frame
	if failures == 0: print("VOLLEY_MOTION_OK projectiles=3 staggered=true critical_visual_only=true")
	quit(0 if failures == 0 else 1)
