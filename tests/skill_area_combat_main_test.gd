extends SceneTree

const QA := preload("res://tests/qa_class_selection.gd")
const MONSTER := preload("res://scenes/Monster.tscn")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures.append(label)
	return ok

func spawn(world: TwilightWorld, point: Vector2) -> TwilightMonster:
	var target: TwilightMonster = MONSTER.instantiate()
	world.monsters_root.add_child(target)
	target.setup({"name":"skill_area_fixture","hp":900000,"lv":1,"mr":0,"ac":0}, world.player, world, null)
	target.set_physics_process(false)
	target.global_position = point
	return target

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
	var far: TwilightMonster = spawn(world, origin + Vector2(unit * 14, unit * 10))
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
	check(str(skill.get("shape", "")) != "single" and service.targets(skill, primary) == [primary, second],
		"area radius and wall geometry admit the intended two actors in order")
	world.quickslots = [{"kind":"skill","id":str(base.id),"auto":false}]
	world.selected_monster = primary
	check(not world._run_auto_combat_quickslots() and world.mp == 1000, "an OFF slot leaves MP alone")
	world.quickslots[0].auto = true
	world.selected_monster = far
	var rng_before: int = world.rng.state
	check(not world._run_auto_combat_quickslots() and world.mp == 1000 and rng_before == world.rng.state,
		"an ON but out-of-range slot keeps MP and the random stream")
	world.selected_monster = primary
	if check(world._run_auto_combat_quickslots(), "an in-range ON slot starts the real spell"):
		check(world.mp == 1000 - int(skill.mp) and world.skill_global_cooldown > 0,
			"the real area spell pays once and begins its cooldown")
		check(primary.damage_hit_count == 0 and second.damage_hit_count == 0, "windup does not damage either target")
		world._release_player_attack(int(world.pending_attack.get("id", -1)))
		for _step: int in 60: world.combat_flights._physics_process(0.025)
		check(primary.damage_hit_count == 1 and second.damage_hit_count == 1 and blocked.damage_hit_count == 0 and far.damage_hit_count == 0,
			"the paid strike hits exactly both selected targets once and respects the wall and range")
	var proof: Dictionary = {"hits":[primary.damage_hit_count,second.damage_hit_count,blocked.damage_hit_count,far.damage_hit_count],
		"hp":[primary.hp,second.hp,blocked.hp,far.hp],"rng_state":str(world.rng.state),"mp":world.mp}
	world.queue_free()
	await process_frame
	finish(proof)

func finish(proof: Dictionary) -> void:
	print("SKILL_AREA_COMBAT_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"fixture":proof}))
	quit(0 if failures.is_empty() else 1)
