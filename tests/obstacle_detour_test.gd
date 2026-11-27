extends SceneTree

const FIELD = preload("res://scripts/maps/current523_aden_source_field.gd")
const BODY_PROFILE = preload("res://scripts/maps/source_body_profile.gd")
const PROGRESS = preload("res://scripts/maps/walk_path_progress.gd")

class TestField extends FIELD:
	var blocked: Dictionary[Vector2i, bool] = {}

	func _cell_allowed(cell: Vector2i) -> bool:
		return in_bounds(cell) and not blocked.has(cell)

class TestWorld extends TwilightWorld:
	var attack_sight_override: bool = false
	var in_attack_range: bool = false
	var attacks: int = 0

	func _run_auto_ground_pickup() -> bool: return false
	func _run_auto_combat_quickslots() -> bool: return false
	func _target_in_current_weapon_range(_target: TwilightMonster) -> bool: return in_attack_range
	func _equipment523_locked_target() -> TwilightMonster: return null
	func _has_line_of_sight_world(from: Vector2, to: Vector2) -> bool:
		return attack_sight_override or super._has_line_of_sight_world(from, to)
	func _attack(_automatic: bool = false) -> void:
		attacks += 1

class PhysicsHost extends Node2D:
	var field_map: TestField
	var hud: Node = null
	var world: TestWorld

	func constrain_original_motion(actor: CharacterBody2D) -> void:
		world.constrain_original_motion(actor)

var field := TestField.new()
var world := TestWorld.new()
var host := PhysicsHost.new()
var player: TwilightPlayer
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("OBSTACLE_DETOUR_FAIL ", label)

func _grid(x: float, y: float) -> Vector2:
	return field.coordinates.grid_to_world(x, y)

func _place_player(point: Vector2) -> void:
	player.set_touch_vector(Vector2.ZERO)
	player.clear_click_path()
	player.global_position = point
	player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame

func _walk_frames(frames: int) -> bool:
	var clear: bool = true
	for i: int in frames:
		var previous: Vector2 = player.global_position
		await physics_frame
		clear = clear and field.line_clear(previous, player.global_position)
	return clear

func _manual() -> void:
	var start: Vector2 = _grid(9.9, 10.5)
	var forward: Vector2 = field.coordinates.basis_x
	field.blocked[Vector2i(10, 10)] = true
	await _place_player(start)
	player.set_touch_vector(forward)
	var route_clear: bool = await _walk_frames(100)
	var arrived: Vector2 = field.coordinates.world_to_grid(player.global_position)
	check(route_clear and arrived.x > 11.3 and absf(arrived.y - 10.5) <= 1.01,
		"stick detours around a source cell without crossing it or moving more than one cell sideways: %s" % arrived)
	field.blocked[Vector2i(10, 9)] = true
	await _place_player(start)
	player.set_touch_vector(forward)
	route_clear = await _walk_frames(100)
	arrived = field.coordinates.world_to_grid(player.global_position)
	check(route_clear and arrived.x > 11.3 and arrived.y > 11.0 and arrived.y <= 11.51,
		"when the first side is blocked the stick uses the other opening: %s" % arrived)
	field.blocked.erase(Vector2i(10, 9))
	var key_start: Vector2 = _grid(9.9, 9.9)
	await _place_player(key_start)
	Input.action_press("move_right")
	route_clear = await _walk_frames(100)
	Input.action_release("move_right")
	check(route_clear and player.global_position.x > key_start.x + 65.0,
		"keyboard steering detours around a blocked source diagonal")

	# Releasing or turning the input during the detour should take effect on
	# the next physics tick, even if a side segment is in progress.
	await _place_player(start)
	player.set_touch_vector(forward)
	await _walk_frames(10)
	player.set_touch_vector(Vector2.ZERO)
	var stopped: Vector2 = player.global_position
	await _walk_frames(8)
	check(player.global_position.distance_to(stopped) < 0.01, "release immediately stops detour movement")
	await _place_player(start)
	player.set_touch_vector(forward)
	await _walk_frames(10)
	var turned_at: Vector2 = field.coordinates.world_to_grid(player.global_position)
	player.set_touch_vector(-forward)
	await _walk_frames(12)
	arrived = field.coordinates.world_to_grid(player.global_position)
	check(arrived.x < turned_at.x - 0.2 and absf(arrived.y - turned_at.y) < 0.01,
		"reversing the stick during a detour immediately takes the new direction")

	for y: int in field.height: field.blocked[Vector2i(10, y)] = true
	await _place_player(start)
	player.set_touch_vector(forward)
	route_clear = await _walk_frames(150)
	arrived = field.coordinates.world_to_grid(player.global_position)
	check(route_clear and arrived.x < 10.0 and absf(arrived.y - 10.5) < 0.12,
		"a continuous barrier stops the player without drifting along the wall: %s" % arrived)
	field.blocked.clear()

func _auto_tick(target: TwilightMonster) -> void:
	world.auto_target = target
	world._auto_target_refresh_ms = 20000
	world.auto_repath_timer = 0.0
	world._run_auto_hunt(10000)

func _auto(target: TwilightMonster) -> void:
	# A legal source diagonal can grant combat sight while the off-center
	# foot line clips an obstructed cell. Combat sight must still allow attacks.
	field.blocked[Vector2i(9, 10)] = true
	world.attack_sight_override = true
	await _place_player(_grid(9.25, 9.95))
	target.global_position = _grid(10.85, 10.45)
	check(not field.line_clear(player.global_position, target.global_position), "fixture has a blocked direct foot line")
	_auto_tick(target)
	check(player.click_path.size() > 1 and player.click_path[-1] == target.global_position,
		"AUTO routes around the corner even when combat sight is clear")
	var blocked_via: Vector2 = _grid(10.75, 10.15)
	player.set_click_path(PackedVector2Array([blocked_via, target.global_position]), target.global_position)
	_auto_tick(target)
	check(not player.click_path.is_empty() and player.click_path[0] != blocked_via \
		and field.line_clear(player.global_position, player.click_path[0]), "AUTO replans from the player when its previous waypoint is blocked")
	world.in_attack_range = true
	_auto_tick(target)
	check(world.attacks == 1 and player.click_path.is_empty(), "neighboring combat sight can still attack")
	world.in_attack_range = false
	world.attack_sight_override = false
	field.blocked.clear()

	var start: Vector2 = _grid(9.5, 9.5)
	var blocker := StaticBody2D.new()
	blocker.position = start + Vector2(18.0, 0.0)
	blocker.collision_layer = 4
	blocker.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12.0, 16.0)
	shape.shape = rectangle
	blocker.add_child(shape)
	host.add_child(blocker)
	await _place_player(start)
	target.global_position = start + Vector2(110, 0)
	world.auto_stuck_time = 0.0
	var side_peak: float = 0.0
	for i: int in 150:
		if i % 39 == 0: _auto_tick(target)
		var before: Vector2 = player.global_position
		await physics_frame
		var delta: float = 1.0 / Engine.physics_ticks_per_second
		var stalled: bool = PROGRESS.stalled(player.global_position - before, player.intended_walk_speed(), delta)
		world.auto_stuck_time = world.auto_stuck_time + delta if stalled else 0.0
		side_peak = maxf(side_peak, absf(player.global_position.y - start.y))
	check(player.global_position.distance_to(target.global_position) <= 5.0 and side_peak > 12.0 and side_peak <= 24.1,
		"AUTO passes a physical blocker, rejoins its route, and keeps a one-cell lateral bound: %s %.2f" % [player.global_position - start, side_peak])
	blocker.queue_free()

	await _place_player(start)
	var alternative: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(alternative)
	alternative.set_physics_process(false)
	alternative.collision_layer = 0
	alternative.global_position = start + Vector2(130, 30)
	_auto_tick(target)
	world.auto_stuck_time = 2.01
	_auto_tick(target)
	check(world.auto_target == null and player.click_path.is_empty() and world.auto_target_failed_paths.has(world._auto_target_failure_key(target)),
		"an unreachable pursuit is dropped and remembered for acquisition backoff")
	var next_path: PackedVector2Array = world._acquire_auto_target()
	check(world.auto_target == alternative and not next_path.is_empty(), "AUTO can choose another nearby monster during the backoff")

func _run() -> void:
	field.coordinates.configure([0, 0], [24, 24])
	field.width = 24
	field.height = 24
	field.loaded = true
	field.policy = {"attribute_rule": FIELD.CLIENT_RULE}
	field.set_meta("current523_source_field", true)
	world.field_map = field
	host.field_map = field
	host.world = world
	root.add_child(host)
	player = preload("res://scenes/Player.tscn").instantiate()
	host.add_child(player)
	player.collision_mask = 4
	BODY_PROFILE.apply(player, true)
	world.player = player
	world.monsters_root = Node2D.new()
	host.add_child(world.monsters_root)
	var target: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(target)
	target.set_physics_process(false)
	target.collision_layer = 0
	await _manual()
	await _auto(target)
	print("OBSTACLE_DETOUR_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	host.free()
	world.free()
	quit(0 if failures.is_empty() else 1)
