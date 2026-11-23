extends SceneTree
## Controlled actors exercise the production acquisition and manual selection APIs.
var checks: int = 0
var failures: Array[String] = []

class SearchWorld extends TwilightWorld:
	var route_requests: Array[Vector2] = []
	var reachable: Dictionary = {}

	func find_world_path(_from: Vector2, to: Vector2) -> PackedVector2Array:
		route_requests.append(to)
		return PackedVector2Array([to]) if reachable.has(to) else PackedVector2Array()

	func equipment523_can_detect(actor: TwilightMonster) -> bool:
		return not actor.has_meta("hidden")

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("AUTO_SEARCH_BUDGET_FAIL ", label)

func actor(world: SearchWorld, x: float, excluded: bool = false) -> TwilightMonster:
	var monster: TwilightMonster = world.MONSTER_SCENE.instantiate()
	monster.position = Vector2(x, 0)
	if excluded: monster.source_targeting = {"IsAutoSelectable": false}
	world.monsters_root.add_child(monster)
	monster.set_physics_process(false)
	return monster

func run() -> void:
	var world := SearchWorld.new()
	world.player = load("res://scenes/Player.tscn").instantiate()
	world.monsters_root = Node2D.new()
	root.add_child(world.player)
	root.add_child(world.monsters_root)
	world.player.set_physics_process(false)
	var excluded := actor(world, 8, true)
	world.reachable[excluded.global_position] = true
	var blocked := actor(world, 16)
	var hidden := actor(world, 24)
	hidden.set_meta("hidden", true)
	var first_reachable := actor(world, 32)
	var farther := actor(world, 64)
	world.reachable[first_reachable.global_position] = true
	world.reachable[farther.global_position] = true
	check(world._acquire_auto_target().is_empty() and world.auto_target == null, "blocked first candidate defers the next route")
	check(world.route_requests == [blocked.global_position], "one actual route request on the first tick")
	var route: PackedVector2Array = world._acquire_auto_target()
	check(world.auto_target == first_reachable and route == PackedVector2Array([first_reachable.global_position]), "nearest reachable target returns its already validated route")
	check(world.route_requests.size() == 2 and world.auto_search_candidates.is_empty(), "search stops and discards candidate snapshot after success")
	check(world._nearest_reachable_monster(600.0, true) == excluded, "manual selection remains synchronous and accepts the source-excluded actor")
	world.auto_target_failed_paths.clear()
	world._acquire_auto_target()
	first_reachable.life_id += 1
	route = world._acquire_auto_target()
	check(world.auto_target == farther and route == PackedVector2Array([farther.global_position]), "same node with a recycled life cannot reuse its old candidate")
	world.auto_target_failed_paths.clear()
	world._acquire_auto_target()
	world.combat_generation += 1
	route = world._acquire_auto_target()
	check(world.auto_target == first_reachable, "generation change considers the current life in a fresh snapshot")
	world.auto_target_failed_paths.clear()
	world._acquire_auto_target()
	hidden.remove_meta("hidden")
	world.reachable[hidden.global_position] = true
	world.player.global_position += Vector2(float(world.tile_size * 2), 0)
	route = world._acquire_auto_target()
	check(world.auto_target == farther and route == PackedVector2Array([farther.global_position]), "player cell change rebuilds distance order")
	world.auto_target_failed_paths.clear()
	world.reachable.clear()
	world.player.global_position = Vector2.ZERO
	for child: Node in world.monsters_root.get_children(): child.free()
	for i: int in range(1, 13): actor(world, float(i * 8))
	var final_candidate := actor(world, 104)
	world.reachable[final_candidate.global_position] = true
	world.route_requests.clear()
	check(world._nearest_reachable_monster(99999.0, true, true) == final_candidate
		and world.route_requests.size() == 13, "synchronous reference searches all 13 candidates in one call")
	world.auto_target_failed_paths.clear()
	world.route_requests.clear()
	var max_requests_per_tick: int = 0
	var ticks: int = 0
	while ticks < 15:
		var requests_before: int = world.route_requests.size()
		route = world._acquire_auto_target()
		max_requests_per_tick = maxi(max_requests_per_tick, world.route_requests.size() - requests_before)
		ticks += 1
		if not route.is_empty(): break
	check(world.auto_target == final_candidate and ticks == 13, "budget resumes through all unreachable candidates to the same target")
	check(max_requests_per_tick == 1 and world.route_requests.size() == 13, "13 total routes with a peak of one per tick")
	print("AUTO_SEARCH_BUDGET_RESULT ", JSON.stringify({"checks": checks, "failures": failures,
		"routes": world.route_requests.size(), "max_per_tick": max_requests_per_tick, "ticks": ticks}))
	world.player.free()
	world.monsters_root.free()
	world.free()
	quit(0 if failures.is_empty() else 1)
