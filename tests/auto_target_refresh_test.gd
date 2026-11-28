extends SceneTree
## Production AUTO tick with controlled routes and monotonic times in milliseconds.
const TEST_WORLD = preload("res://tests/qa_auto_selection_world.gd")
const INTERACTIONS = preload("res://scripts/input/world_interactions.gd")
var checks: int = 0
var failures: Array[String] = []

class HuntWorld extends TEST_WORLD:
	var visible_target: bool = true
	var in_weapon_range: bool = true
	var locked_actor: TwilightMonster
	func _has_line_of_sight_world(_from: Vector2, _to: Vector2) -> bool: return visible_target
	func _target_in_current_weapon_range(_target: TwilightMonster) -> bool: return in_weapon_range
	func _equipment523_locked_target() -> TwilightMonster: return locked_actor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("AUTO_TARGET_REFRESH_FAIL ", label)

func add_actor(world: HuntWorld, offset: Vector2i) -> TwilightMonster:
	var actor: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(actor)
	actor.set_physics_process(false)
	set_offset(world, actor, offset)
	return actor

func set_offset(world: HuntWorld, actor: TwilightMonster, offset: Vector2i) -> void:
	actor.global_position = world.player.global_position + Vector2(offset * world.tile_size)

func approaching_target(world: HuntWorld) -> void:
	var incumbent: TwilightMonster = add_actor(world,Vector2i(4,0))
	var blocked: TwilightMonster = add_actor(world,Vector2i(1,0))
	var approaching: TwilightMonster = add_actor(world,Vector2i(6,0))
	world.blocked_positions[blocked.global_position] = true
	world.auto_target = incumbent
	var before: int = world.selection_path_calls
	world._refresh_auto_hunt_target(20000)
	check(world.auto_target==incumbent and world.selection_path_calls==before+1 and not world.auto_search_candidates.is_empty(),"a blocked nearer candidate leaves the incumbent and the remaining queue intact")
	set_offset(world,approaching,Vector2i(2,0))
	var route: PackedVector2Array = world._refresh_auto_hunt_target(20001)
	check(world.auto_target==approaching and not route.is_empty() and world.selection_path_calls==before+2,"the pending search reaches a moving candidate that is now closer than the incumbent")
	world.blocked_positions.clear()
	incumbent.free();blocked.free();approaching.free()
	world._clear_auto_target_search()
	world.auto_target = null
	world.auto_target_failed_paths.clear()
	world.auto_target_next_search_ms = 0
	world._auto_target_refresh_ms = 0

func run() -> void:
	var world := HuntWorld.new()
	world.player = load("res://scenes/Player.tscn").instantiate()
	world.monsters_root = Node2D.new()
	root.add_child(world.player)
	root.add_child(world.monsters_root)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2(528, 528)
	approaching_target(world)
	world.selection_path_calls = 0

	var out_of_range: TwilightMonster = add_actor(world, Vector2i(11, 0))
	world._run_auto_hunt(0)
	check(world.auto_target == null and world.selection_path_calls == 0, "11 cells is outside AUTO range before routing")
	check(world._nearest_reachable_monster(600.0, true) == out_of_range, "manual search still reaches beyond the AUTO radius")

	var edge: TwilightMonster = add_actor(world, Vector2i(10, 10))
	world._run_auto_hunt(10)
	check(world.auto_target == edge and world.last_test_attack == edge, "Chebyshev limit includes diagonal cell 10")
	var near: TwilightMonster = add_actor(world, Vector2i(4, 0))
	var calls: int = world.selection_path_calls
	world._run_auto_hunt(3009)
	check(world.auto_target == edge and world.selection_path_calls == calls, "live target retained at 2999ms")
	world.pending_attack = {"fixture_attack":true}
	world._run_auto_hunt(3010)
	check(world.auto_target == edge and world.selection_path_calls == calls and not world.pending_attack.is_empty(),
		"refresh does not interrupt an in-flight attack")
	world.pending_attack.clear()
	world._run_auto_hunt(3011)
	check(world.auto_target == near and world.last_test_attack == near and world.selection_path_calls == calls + 1,
		"first eligible tick after 3 seconds adopts closer reachable target")

	var blocked: TwilightMonster = add_actor(world, Vector2i(1, 0))
	world.blocked_positions[blocked.global_position] = true
	var moving: TwilightMonster = add_actor(world, Vector2i(2, 0))
	var moving_farther: TwilightMonster = add_actor(world, Vector2i(3, 0))
	world.visible_target = false
	world.in_weapon_range = false
	world.auto_repath_timer = 0.0
	var previous_walk := PackedVector2Array([world.player.global_position + Vector2(32, 32), near.global_position])
	world.player.set_click_path(previous_walk, near.global_position)
	calls = world.selection_path_calls
	world._run_auto_hunt(6011)
	check(world.auto_target == near and world.player.click_path == previous_walk and world.selection_path_calls == calls + 1,
		"pending local search keeps the old walk and spends one route on the nearer blocked actor")
	check(not world.auto_search_candidates.is_empty(), "remaining candidates are carried to the next tick")
	set_offset(world, moving, Vector2i(12, 0))
	set_offset(world, moving_farther, Vector2i(8, 0))
	world.auto_repath_timer = 0.5
	world._run_auto_hunt(6012)
	check(world.auto_target == near and world.player.click_path == previous_walk and world.selection_path_calls == calls + 1,
		"candidates that leave the radius or move behind the incumbent between ticks are skipped")
	check(world.auto_search_candidates.is_empty(), "unchanged incumbent finishes the refresh")

	edge.dead = true
	blocked.dead = true
	moving_farther.dead = true
	set_offset(world, near, Vector2i(11, 0))
	world._run_auto_hunt(9012)
	check(world.auto_target == null and world.player.click_path.is_empty() and world.selection_path_calls == calls + 1,
		"refresh drops an automatic target that left the radius without chasing distant candidates")

	var manual_walk := PackedVector2Array([world.player.global_position + Vector2(64, 16)])
	world.player.set_manual_click_path(manual_walk, manual_walk[0])
	var arrival: TwilightMonster = add_actor(world, Vector2i(3, 0))
	world._run_auto_hunt(9300)
	check(world.auto_target == null and world.player.click_path == manual_walk and world.player.manual_navigation,
		"manual movement takes priority over a due refresh")
	world.player.clear_click_path()
	world.visible_target = true
	world.in_weapon_range = true
	var interactions = INTERACTIONS.new()
	interactions.world = world
	world.world_interactions = interactions
	interactions.selections.append(interactions.monster_entry(out_of_range))
	world._run_auto_hunt(9301)
	check(world.auto_target == out_of_range and world.last_test_attack == out_of_range and not world.last_test_attack_automatic,
		"explicit target stays pinned outside the automatic search radius")
	interactions.free()
	world.world_interactions = null
	world.locked_actor = out_of_range
	world._run_auto_hunt(12301)
	check(world.auto_target == out_of_range and world.last_test_attack == out_of_range and not world.last_test_attack_automatic,
		"equipment lock stays pinned during the periodic refresh")
	world.locked_actor = null
	world._run_auto_hunt(12302)
	check(world.auto_target == arrival and world.last_test_attack_automatic, "AUTO resumes local selection after the lock ends")

	arrival.dead = true
	var replacement: TwilightMonster = add_actor(world, Vector2i(-3, -2))
	world._run_auto_hunt(12303)
	check(world.auto_target == replacement, "death triggers a new search without waiting another 3 seconds")

	# Releasing a distant explicit target must reapply AUTO admission before
	# the periodic deadline. An earlier attack can still finish first.
	world.locked_actor = out_of_range
	world._run_auto_hunt(12304)
	check(world.last_test_attack == out_of_range and not world.last_test_attack_automatic, "lock accepts an explicit distant target")
	world.locked_actor = null
	world.pending_attack = {"fixture_attack":true}
	world._run_auto_hunt(12305)
	check(world.auto_target == out_of_range and not world.pending_attack.is_empty(), "releasing lock does not interrupt a queued attack")
	world.pending_attack.clear()
	world._run_auto_hunt(12306)
	check(world.auto_target == replacement and world.last_test_attack == replacement and world.last_test_attack_automatic,
		"AUTO reacquires a local target after lock release, before the refresh deadline")

	interactions = INTERACTIONS.new()
	interactions.world = world
	world.world_interactions = interactions
	interactions.selections.append(interactions.monster_entry(out_of_range))
	world._run_auto_hunt(12307)
	interactions.selections.clear()
	world._run_auto_hunt(12308)
	check(world.auto_target == replacement and world.last_test_attack == replacement and world.last_test_attack_automatic,
		"clearing a manual selection also returns to local AUTO admission")
	interactions.free()
	world.world_interactions = null

	world.monsters_root.free()
	world.player.free()
	world.free()
	print("AUTO_TARGET_REFRESH_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
