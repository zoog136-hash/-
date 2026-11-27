extends SceneTree

const QA := preload("res://tests/qa_class_selection.gd")
const MONSTER := preload("res://scenes/Monster.tscn")
var checks: int = 0
var failures: Array[String] = []
var marker_effects: Array[Vector2] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SKILL_AREA_COMBAT_MAIN_FAIL ", label)
	return ok

func spawn(world: TwilightWorld, point: Vector2) -> TwilightMonster:
	var target: TwilightMonster = MONSTER.instantiate()
	world.monsters_root.add_child(target)
	target.setup({"name":"skill_area_fixture","hp":900000,"lv":1,"mr":0,"ac":0}, world.player, world, null)
	target.set_physics_process(false)
	target.global_position = point
	return target

func clear_cooldown(world: TwilightWorld) -> void:
	world.player.cancel_attack()
	world.skill_global_cooldown = 0.0
	world.skill_cooldowns.clear()

func marker(world: TwilightWorld) -> void:
	var id: int = int(world.pending_attack.get("id", -1))
	world._release_player_attack(id)
	world._release_player_attack(id) # A repeated marker cannot apply a second hit.

func run() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "enter the actual Main scene")
	world.player.set_physics_process(false)
	world.player.set_auto_enabled(false)
	world.field_population.set_process(false)
	world._clear_monsters()
	if not check(world.field_map == null, "this combat fixture runs without an installed map"):
		world.queue_free()
		finish({})
		return
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-16, -16, 48, 48)
	grid.cell_size = Vector2.ONE * world.tile_size
	grid.update()
	grid.set_point_solid(Vector2i(2, 0))
	world.astar = grid
	var unit: float = float(world.tile_size)
	var origin: Vector2 = Vector2.ONE * unit * 0.5
	world.player.global_position = origin
	var primary: TwilightMonster = spawn(world, origin + Vector2(0, unit))
	var second: TwilightMonster = spawn(world, origin + Vector2(-unit, unit * 2))
	var blocked: TwilightMonster = spawn(world, origin + Vector2(unit * 3, 0))
	var far: TwilightMonster = spawn(world, origin + Vector2(0, unit * 6))
	var concealed: TwilightMonster = spawn(world, origin + Vector2(0, -unit))
	concealed.concealed523 = true
	check(world._has_line_of_sight_world(origin,primary.global_position) and world._has_line_of_sight_world(origin,second.global_position)
		and not world._has_line_of_sight_world(origin,blocked.global_position), "Game collision rejects the blocked target")

	world.job_class = "마법사"
	world.level = 85
	world.max_mp = 1000
	world.mp = 1000
	world.skill_cooldowns.clear()
	world.skill_global_cooldown = 0
	world.rng.seed = 282026
	var service: TwilightOriginalSkillService = world.original_skills
	var base: Dictionary = service.catalog.record_for("미티어 스트라이크")
	if not check(not base.is_empty(), "the installed game catalog contains Meteor Strike"):
		world.queue_free()
		finish({})
		return
	service.catalog.learned[str(base.id)] = 1
	service.catalog.revision += 1
	var skill: Dictionary = service.catalog.resolve(base)
	check(TwilightOriginalSkillService.is_area_cast(skill) and service.targets(skill, null) == [primary, second],
		"area radius from the caster admits only the two visible enemies")
	var spell_visual: String = TwilightOriginalSkillService.presentation_id(skill)
	service.vfx.phase_started.connect(func(id: String, phase: String, at: Vector2) -> void:
		if id == spell_visual and phase == "impact": marker_effects.append(at))
	world.quickslots = [{"kind":"skill","id":str(base.id),"auto":false}]
	world.selected_monster = null
	check(not world._run_auto_area_quickslots() and world.mp == 1000, "an OFF slot leaves MP alone")
	world.quickslots[0].auto = true
	world.auto_attack_timer = 90.0
	world.auto_target_next_search_ms = Time.get_ticks_msec() + 30000
	world.auto_target_failed_search_actor_count = world.monsters_root.get_child_count()
	world.selected_monster = far
	var rng_before: int = world.rng.state
	check(not world._run_auto_combat_quickslots() and world.mp == 1000,
		"the per-frame targeted slot loop leaves the area slot alone")
	var second_inside: Vector2 = second.global_position
	second.global_position += Vector2(0, unit * 7)
	world.player.set_auto_enabled(true)
	world.auto_heal_sweep_elapsed = 0.0
	var path_checks: int = world.auto_target_path_checks
	var full_hud: int = int(world.hud_publish_counts.full)
	world._process_frame(0.24)
	check(world.pending_attack.is_empty() and world.mp == 1000 and rng_before == world.rng.state,
		"area slot waits for the next scheduler pulse")
	world.pending_attack = {"fixture_attack":true}
	world._process_frame(0.27)
	check(world.pending_attack.has("fixture_attack") and world.mp == 1000,
		"area pulse does not replace a pending attack")
	world.pending_attack.clear()
	world._process_frame(0.01)
	if check(world.pending_attack.has("area_skill") and not world.pending_attack.has("target"),
		"scheduled AUTO starts the spell without a selected target or a flight target"):
		check(world.auto_target_path_checks == path_checks and int(world.hud_publish_counts.full) == full_hud,
			"area cast bypasses hunt pathfinding and the full HUD rebuild")
		check(world.mp == 1000 - int(skill.mp) and world.skill_global_cooldown > 0,
			"the real area spell pays once and begins its cooldown")
		check(primary.damage_hit_count == 0 and second.damage_hit_count == 0, "windup does not damage either target")
		world.selected_monster = null
		second.global_position = second_inside
		marker(world)
		check(world.combat_flights.flights.is_empty(), "target-free marker launches no tracked projectile")
		check(primary.damage_hit_count == 1 and second.damage_hit_count == 1 and blocked.damage_hit_count == 0 and far.damage_hit_count == 0,
			"the marker hits the two in-range actors once and leaves blocked or far actors alone")
		check(concealed.damage_hit_count == 0 and marker_effects == [origin],
			"concealment is preserved and the area effect fires once at the caster")
	world.player.set_auto_enabled(false)

	clear_cooldown(world)
	primary.global_position += Vector2(0, unit * 7)
	second.global_position += Vector2(0, unit * 7)
	var before_mp: int = world.mp
	check(not world._run_auto_area_quickslots() and world.mp == before_mp,
		"AUTO spends nothing when the area has only a wall, hidden actor and far actors")
	world._on_quickslot_pressed(0)
	if check(world.pending_attack.has("area_skill") and not world.pending_attack.has("target"),
		"manual quickslot press casts into an empty area without selecting an actor"):
		marker(world)
		check(world.mp == before_mp - int(skill.mp) and marker_effects == [origin, origin]
			and primary.damage_hit_count == 1 and second.damage_hit_count == 1,
			"manual empty cast pays once and creates one effect with no victims")

	clear_cooldown(world)
	world._on_quickslot_pressed(0)
	var cancelled_id: int = int(world.pending_attack.get("id", -1))
	world.player.cancel_attack()
	world._release_player_attack(cancelled_id)
	check(cancelled_id >= 0 and world.pending_attack.is_empty() and marker_effects.size() == 2,
		"cancelled area windup cannot produce an impact")

	for name: String in ["파이어 볼", "파이어스톰"]:
		clear_cooldown(world)
		var row: Dictionary = service.catalog.record_for(name)
		service.catalog.learned[str(row.id)] = 1
		service.catalog.revision += 1
		world.selected_monster = null
		check(world._cast_job_skill(str(row.id)) and world.pending_attack.has("area_skill") and not world.pending_attack.has("target"),
			name + " uses the same target-free registration")

	clear_cooldown(world)
	var single: Dictionary = service.catalog.record_for("에너지 볼트")
	service.catalog.learned[str(single.id)] = 1
	service.catalog.revision += 1
	world.selected_monster = far
	far.global_position += Vector2(0, unit * 14)
	before_mp = world.mp
	check(not world._cast_job_skill(str(single.id)) and world.mp == before_mp, "out-of-range single-target skill still refuses")
	primary.global_position = origin + Vector2(0, unit)
	world.selected_monster = primary
	check(world._cast_job_skill(str(single.id)) and world.pending_attack.has("target") and not world.pending_attack.has("area_skill"),
		"single-target quickslot retains the original tracked motion")
	var proof: Dictionary = {"hits":[primary.damage_hit_count,second.damage_hit_count,blocked.damage_hit_count,far.damage_hit_count],
		"hp":[primary.hp,second.hp,blocked.hp,far.hp],"rng_state":str(world.rng.state),"mp":world.mp,
		"area_effects":marker_effects.size(),"hunt_searches":world.auto_target_path_checks - path_checks}
	world.queue_free()
	await process_frame
	finish(proof)

func finish(proof: Dictionary) -> void:
	print("SKILL_AREA_COMBAT_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"fixture":proof}))
	quit(0 if failures.is_empty() else 1)
