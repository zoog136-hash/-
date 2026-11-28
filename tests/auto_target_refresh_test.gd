extends SceneTree
## Production AUTO tick with controlled routes and monotonic times in milliseconds.
const TEST_WORLD = preload("res://tests/qa_auto_selection_world.gd")
const INTERACTIONS = preload("res://scripts/input/world_interactions.gd")
const FIELD_FIXTURE = preload("res://tests/current523_aden_source_field_test.gd")
const BODY_PROFILE = preload("res://scripts/maps/source_body_profile.gd")
var checks: int = 0
var failures: Array[String] = []

class HuntWorld extends TEST_WORLD:
	var visible_target: bool = true
	var in_weapon_range: bool = true
	var locked_actor: TwilightMonster
	func _has_line_of_sight_world(_from: Vector2, _to: Vector2) -> bool: return visible_target
	func _target_in_current_weapon_range(_target: TwilightMonster) -> bool: return in_weapon_range
	func _equipment523_locked_target() -> TwilightMonster: return locked_actor

class RoamHost extends Node2D:
	var field_map: PlayableField

class RoamField extends FIELD_FIXTURE.MemoryField:
	var walk_leg_checks: int = 0
	func line_clear(from: Vector2, to: Vector2) -> bool:
		walk_leg_checks += 1
		return super.line_clear(from, to)

class RoamWorld extends HuntWorld:
	var pickup_goal := Vector2.INF
	func _run_auto_ground_pickup() -> bool:
		if not pickup_goal.is_finite(): return false
		player.set_click_path(PackedVector2Array([pickup_goal]), pickup_goal)
		return true

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
	world.in_weapon_range = false
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
	world.in_weapon_range = true

func attackable_without_route(world: HuntWorld) -> void:
	var actor: TwilightMonster = add_actor(world, Vector2i(1, 0))
	var key: String = world._auto_target_failure_key(actor)
	world.auto_target_failed_paths[key] = Time.get_ticks_msec() + 60000
	world.blocked_positions[actor.global_position] = true
	var calls: int = world.selection_path_calls
	world.visible_target = false
	world._run_auto_hunt(0)
	check(world.auto_target == null and world.selection_path_calls == calls,
		"a backed-off actor behind an obstacle still cannot be selected for an attack")
	world.visible_target = true
	world._run_auto_hunt(250)
	check(world.auto_target == actor and world.last_test_attack == actor and world.selection_path_calls == calls,
		"an actor already in weapon range and sight can be attacked during path backoff without routing")
	check(world.auto_target_failed_paths.has(key), "an attack does not certify that the failed walking route is now passable")
	world.blocked_positions.clear()
	actor.free()
	world._clear_auto_target_search()
	world.auto_target = null
	world.selected_monster = null
	world.auto_target_failed_paths.clear()
	world.auto_target_next_search_ms = 0
	world._auto_target_refresh_ms = 0

func roaming_walk_and_target(world: RoamWorld, field: FIELD_FIXTURE.MemoryField) -> void:
	var player: TwilightPlayer = world.player
	var start: Vector2 = player.global_position
	world._run_auto_hunt(0)
	var first_goal: Vector2 = player.navigation_agent.target_position
	check(player.auto_roaming_navigation and field.line_clear(start, first_goal) and world.selection_path_calls == 0,
		"empty local scan starts a walkable roam leg without a full route search")
	var first_path: PackedVector2Array = player.click_path
	world._run_auto_hunt(1)
	check(player.click_path == first_path, "a running roam leg is kept between target scans")
	player.set_physics_process(true)
	for frame: int in range(10): await physics_frame
	player.set_physics_process(false)
	check(player.global_position.distance_to(first_goal) < start.distance_to(first_goal) - 4.0,
		"the ordinary player physics walks toward the selected cell")

	var headings: Dictionary = {world._auto_roam_direction: true}
	var avoids_reverse: bool = true
	for leg: int in range(1, 7):
		var previous: Vector2i = world._auto_roam_direction
		player.global_position = player.navigation_agent.target_position
		player.path_index = player.click_path.size()
		world._run_auto_hunt(leg * 250)
		var heading: Vector2i = world._auto_roam_direction
		headings[heading] = true
		avoids_reverse = avoids_reverse and heading != -previous
	check(headings.size() >= 3 and avoids_reverse, "seeded open terrain chooses varied headings without immediate backtracking")
	var actor: TwilightMonster = add_actor(world, Vector2i(1, 0))
	world._run_auto_hunt(1501)
	check(world.auto_target == actor and world.last_test_attack == actor and player.click_path.is_empty() and not player.auto_roaming_navigation,
		"a newly available target interrupts the current roam leg before the next empty-scan deadline")
	actor.free()

func roaming_obstacles_and_ownership(world: RoamWorld, host: RoamHost, field: RoamField) -> void:
	var player: TwilightPlayer = world.player
	var cell := Vector2i(24, 24)
	player.global_position = field.cell_to_world(cell)
	for direction: Vector2i in OriginalPlayableField.DIRECTIONS:
		field.attribute(cell + direction, 0, 1)
	field.attribute(cell + Vector2i.RIGHT, 0, 0)
	field.attribute(cell + Vector2i.RIGHT * 2, 0, 1)
	var goal: Vector2 = field.cell_to_world(cell + Vector2i.RIGHT)
	field.walk_leg_checks = 0
	world._run_auto_hunt(2000)
	check(player.auto_roaming_navigation and player.click_path == PackedVector2Array([goal]),
		"a dead end uses the sole walkable direction and shortens the leg before blocked cells")
	check(field.walk_leg_checks == 3, "the other seven closed neighbors need no route-leg checks")

	var blocker := StaticBody2D.new()
	blocker.collision_layer = 4
	blocker.position = player.global_position.lerp(goal, 0.5)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	blocker.add_child(shape)
	host.add_child(blocker)
	await physics_frame
	await physics_frame
	world.auto_stuck_time = 1.0
	world._run_auto_hunt(2500)
	check(field.line_clear(player.global_position, goal) and player.click_path.is_empty(),
		"a stalled roam leg is abandoned and a physical foot blocker prevents choosing it again")
	blocker.free()
	await physics_frame
	await physics_frame
	world._run_auto_hunt(2999)
	check(player.click_path.is_empty(), "a fully blocked roam attempt backs off before checking again")
	world._run_auto_hunt(3000)
	check(player.auto_roaming_navigation and player.click_path == PackedVector2Array([goal]),
		"roaming resumes when the physical blocker is gone")

	world.pickup_goal = goal
	world._run_auto_hunt(3001)
	check(not player.auto_roaming_navigation and player.click_path == PackedVector2Array([goal]),
		"loot owns its new route even when its destination matches the old roam")
	world.pickup_goal = Vector2.INF
	player.set_manual_click_path(PackedVector2Array([goal]), goal)
	world._run_auto_hunt(3002)
	check(player.manual_navigation and player.click_path == PackedVector2Array([goal]), "manual click movement keeps its route")
	player.clear_click_path()
	world._run_auto_hunt(3003)
	player.set_touch_vector(Vector2.RIGHT)
	world._run_auto_hunt(3004)
	check(player.click_path.is_empty(), "manual steering cancels a roam leg")
	player.set_touch_vector(Vector2.ZERO)
	world._run_auto_hunt(3005)
	player.set_auto_enabled(false)
	check(player.click_path.is_empty() and not player.auto_roaming_navigation, "disabling AUTO stops an active roam leg")
	player.set_auto_enabled(true)
	world.field_map = null
	world._run_auto_hunt(3006)
	check(player.click_path.is_empty(), "an absent field does not start an unverified walk")

func roaming_checks_are_bounded(world: RoamWorld, host: RoamHost, field: RoamField) -> void:
	world.field_map = field
	var player: TwilightPlayer = world.player
	player.global_position = field.cell_to_world(Vector2i(40, 40))
	# The terrain permits all eight exits. Four physical walls block the foot.
	for axis: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 4
		wall.position = player.global_position + axis * 12.0
		var collision := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(4, 48) if axis.x != 0.0 else Vector2(48, 4)
		collision.shape = rectangle
		wall.add_child(collision)
		host.add_child(wall)
	await physics_frame
	await physics_frame
	var remaining_per_tick: Array[int] = []
	for frame: int in range(4):
		world._run_auto_hunt(4000 + frame * 16)
		remaining_per_tick.append(world._auto_roam_headings.size())
	check(remaining_per_tick == [6, 4, 2, 0] and player.click_path.is_empty(),
		"all eight physically blocked headings are checked over four ticks without starting a walk")
	field.walk_leg_checks = 0
	world._run_auto_hunt(4547)
	check(field.walk_leg_checks == 0, "the retry delay begins only after the final heading was checked")
	world._run_auto_hunt(4548)
	check(world._auto_roam_headings.size() == 6, "a new attempt resumes with only two headings per tick")
	var actor: TwilightMonster = add_actor(world, Vector2i(1, 0))
	field.walk_leg_checks = 0
	world._run_auto_hunt(4549)
	check(world.last_test_attack == actor and world._auto_roam_headings.is_empty() and field.walk_leg_checks == 0,
		"a target found between probe ticks is attacked before any remaining roam work")

func run_roaming() -> void:
	var world := RoamWorld.new()
	var field := RoamField.new()
	field.prepare({})
	field.set_meta("current523_source_field", true)
	world.field_map = field
	world._auto_roam_random.seed = 70411
	var host := RoamHost.new()
	host.field_map = field
	root.add_child(host)
	world.player = load("res://scenes/Player.tscn").instantiate()
	world.player.collision_mask = 4
	BODY_PROFILE.apply(world.player, true)
	world.player.position = field.cell_to_world(Vector2i(20, 20))
	host.add_child(world.player)
	world.player.set_physics_process(false)
	world.monsters_root = Node2D.new()
	host.add_child(world.monsters_root)
	world.hud = TwilightHUD.new()
	world.hud.auto_button = Button.new()
	world.hud.add_child(world.hud.auto_button)
	world.loot_pickup.world = world
	world.player.auto_toggled.connect(world._on_auto_toggled)
	world.player.set_auto_enabled(true)
	await roaming_walk_and_target(world, field)
	await roaming_obstacles_and_ownership(world, host, field)
	await roaming_checks_are_bounded(world, host, field)
	world.hud.free()
	host.free()
	world.free()

func run() -> void:
	var world := HuntWorld.new()
	world.player = load("res://scenes/Player.tscn").instantiate()
	world.monsters_root = Node2D.new()
	root.add_child(world.player)
	root.add_child(world.monsters_root)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2(528, 528)
	approaching_target(world)
	attackable_without_route(world)
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
	check(world.auto_target == near and world.last_test_attack == near and world.selection_path_calls == calls,
		"first eligible tick after 3 seconds adopts a closer attackable target without requesting a route")

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
	await run_roaming()
	print("AUTO_TARGET_REFRESH_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
