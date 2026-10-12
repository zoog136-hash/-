extends "res://tests/integrated_ui_test.gd"

# Display tiles and navigation cells have different sizes in the real continent.
# Exercise both the actual teleport slot and a nonzero-origin grid boundary.
func _run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	hud = world.hud
	check(CLASS_QA.enter_game(world),"enter world for landing regression")
	world.save_timer = -100000
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	check(int(world.active_map.width) > world.astar.region.size.x,"real map has more display tiles than navigation cells")
	world.rng.seed = 98765
	var all_walkable: bool = true
	for trial: int in 64:
		var position: Vector2 = world._random_walkable_position(Vector2.ZERO,0,999999)
		all_walkable = all_walkable and world._is_walkable_world(position)
	check(all_walkable,"64 random landings stay inside the actual walkable grid")
	check(world._is_walkable_world(world._spawn_position_fallback()),"fallback landing uses the actual grid bounds")
	var nearby: bool = true
	var origin: Vector2 = world.player.global_position
	for trial: int in 32:
		var summon_position: Vector2 = world._random_walkable_position(origin,30,72)
		nearby = nearby and world._is_walkable_world(summon_position) and summon_position.distance_to(origin) <= 72
	check(nearby,"summon landing remains near its owner on the large continent")
	world._on_quickslot_assignment_requested(0,"skill","텔레포트")
	hud._close_workspace()
	hud.quick_controller.pages[0] = 0
	hud._render_quickslots(world.inventory,{})
	var before: Vector2 = world.player.global_position
	var before_mp: int = world.mp
	await click(hud.v20_quickslot_buttons[0])
	check(world.player.global_position != before and world._is_walkable_world(world.player.global_position),"native quickslot teleport lands on a valid navigation cell")
	check(world.mp < before_mp and float(world.skill_cooldowns.get("텔레포트",0)) > 0,"teleport slot spends real MP and starts cooldown")
	var field: RefCounted = world.field_map
	var navigation: AStarGrid2D = world.astar
	world.field_map = null
	world.astar = AStarGrid2D.new()
	world.astar.region = Rect2i(10,20,5,4)
	world.astar.update()
	world.astar.fill_solid_region(world.astar.region,true)
	var allowed := Vector2i(12,22)
	world.astar.set_point_solid(allowed,false)
	check(world._spawn_position_fallback() == world._cell_to_world(allowed),"fallback honors a nonzero grid origin")
	check(world._random_walkable_position(Vector2.ZERO,0,999999) == world._cell_to_world(allowed),"random landing honors a nonzero grid origin")
	world.astar = navigation
	world.field_map = field
	world.queue_free()
	await frames()
	print("SKILL_LANDING_BOUNDS_OK: %d checks" % checks.size() if failures.is_empty() else "SKILL_LANDING_BOUNDS_FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
