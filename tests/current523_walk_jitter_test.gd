extends SceneTree
## User report 2026-11-19 (after #642 original walk speed):
## "케릭이 이속수정한뒤에 이동하면서 앞뒤로 왔다갔다해".
##
## Records the player every physics frame (position in original source grid
## components, facing8, motion state, source role/frame) and counts reversals:
## a moving frame whose grid displacement points against the previous moving
## frame (angle > 150 degrees in grid space; A* 8-direction turns are at most
## 135 degrees) or, for the joystick, against the stick.
##
## Always (synthetic, CI): a 523 cell basis player follows click paths whose
## first point is behind it / which are re-set every 0.65 s (auto pursuit),
## at the original 2.25 cells/s, slowed and hasted; the walk animation clock.
## With --source523-pack=<root> (actual Main on the original 523 Land):
## joystick 8 directions, click move, auto hunting pursuit.
const WALK = preload("res://scripts/maps/source_walk_speed.gd")
const COORDS = preload("res://scripts/maps/source_coordinates.gd")
const HOST = preload("res://scripts/maps/current523_host.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const PATH_PROGRESS = preload("res://scripts/maps/walk_path_progress.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}
var world: Node

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("WALK_JITTER_FAIL: ", label)
	return condition

func _initialize() -> void: _run.call_deferred()

func _pack_root() -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source523-pack="): return value.trim_prefix("--source523-pack=")
	return ""

func _wait_for(condition: Callable, frames: int) -> bool:
	for _frame: int in frames:
		if condition.call(): return true
		await process_frame
	return condition.call()

## Frame recorder ---------------------------------------------------------
class Track extends RefCounted:
	var coordinates: Object
	var samples: Array = []
	var reversals: int = 0
	var facing_flips: int = 0
	var against_stick: int = 0
	var moving_frames: int = 0
	var _last_move: Vector2 = Vector2.ZERO
	var _last_facing: int = -1
	var _facings: Array[int] = []
	var first_reversal: Dictionary = {}
	func grid(p: Vector2) -> Vector2:
		var g: Variant = coordinates.call("world_to_grid", p)
		return g if g is Vector2 else p
	func add(previous: Vector2, current: Vector2, facing: int, state: String, extra: Dictionary = {}, stick: Vector2 = Vector2.ZERO) -> void:
		var d: Vector2 = grid(current) - grid(previous)
		var sample: Dictionary = {"p": [snappedf(current.x, 0.01), snappedf(current.y, 0.01)], "d": [snappedf(d.x, 0.0001), snappedf(d.y, 0.0001)], "f": facing, "s": state}
		sample.merge(extra)
		samples.append(sample)
		if d.length() < 0.004: return # ~0.1 px: standing
		moving_frames += 1
		if _last_move != Vector2.ZERO and d.normalized().dot(_last_move.normalized()) < cos(deg_to_rad(150.0)):
			reversals += 1
			if first_reversal.is_empty(): first_reversal = {"index": samples.size() - 1, "before": [_last_move.x, _last_move.y], "after": [d.x, d.y], "around": samples.slice(maxi(0, samples.size() - 6), samples.size())}
		if stick != Vector2.ZERO:
			var stick_grid: Vector2 = grid(current + stick) - grid(current)
			if d.dot(stick_grid) < 0.0: against_stick += 1
		_last_move = d
		# Facing: an opposite facing between moving frames, or A-B-A flicker.
		if _last_facing >= 0 and posmod(facing - _last_facing, 8) == 4: facing_flips += 1
		_facings.append(facing)
		if _facings.size() >= 3 and _facings[-1] == _facings[-3] and _facings[-1] != _facings[-2]: facing_flips += 1
		_last_facing = facing
	## A legitimate new heading (new target, attack in between): the next
	## moving frame is not compared with the old one.
	func reset_direction() -> void:
		_last_move = Vector2.ZERO
		_last_facing = -1
		_facings.clear()
	func summary() -> Dictionary:
		return {"frames": samples.size(), "moving": moving_frames, "reversals": reversals, "facing_flips": facing_flips, "against_stick": against_stick, "first_reversal": first_reversal}

## Synthetic (CI) ----------------------------------------------------------
class FakeField extends Node:
	var coordinates: RefCounted
	var blocked_skip: bool = false
	func line_clear(_from: Vector2, _to: Vector2) -> bool: return not blocked_skip
class FakeWorld extends Node2D:
	var field_map: Node

func _synthetic_player(c: RefCounted) -> Array:
	var host := FakeWorld.new()
	var field := FakeField.new()
	field.coordinates = c
	field.set_meta("current523_source_field", true)
	host.field_map = field
	host.add_child(field)
	root.add_child(host)
	var player: CharacterBody2D = load("res://scenes/Player.tscn").instantiate()
	host.add_child(player)
	player.collision_mask = 0
	return [host, player]

## Lets the engine step the player (project physics rate) and records each tick.
func _step(player: CharacterBody2D, track: Track, frames: int, auto_repath: Callable = Callable(), goal: Vector2 = Vector2.INF) -> void:
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var repath_clock: float = 0.0
	for i: int in frames:
		if auto_repath.is_valid():
			repath_clock -= dt
			if repath_clock <= 0.0:
				repath_clock = 0.65
				auto_repath.call()
		var before: Vector2 = player.global_position
		await physics_frame
		track.add(before, player.global_position, int(player.motion.facing8), str(player.motion.state), {"i": int(player.get("path_index"))})
		# CI time budget: stop a few frames after arriving.
		if goal.is_finite() and player.global_position.distance_to(goal) < 6.0 and int(player.get("path_index")) >= player.click_path.size() and i > 0:
			for k: int in 3:
				before = player.global_position
				await physics_frame
				track.add(before, player.global_position, int(player.motion.facing8), str(player.motion.state), {})
			return

func synthetic() -> void:
	var c := COORDS.new()
	c.configure([0, 0], [512, 512])
	var pair: Array = _synthetic_player(c)
	var host: Node2D = pair[0]
	var player: CharacterBody2D = pair[1]
	var cell := func(x: float, y: float) -> Vector2: return c.grid_to_world(x, y)
	var results: Dictionary = {}
	for multiplier: float in [1.0, 0.5, 1.6]:
		player.set_equipment_speed_multipliers(multiplier, 1.0)
		# 1) Click path whose first point is the centre of the cell the player
		# stands in, behind it (A* start cell when the next corner is hidden).
		var headings: Array = [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(-1, -1), Vector2(1, -1)]
		if multiplier != 1.0: headings = [Vector2(1, 0), Vector2(0, -1), Vector2(-1, 1), Vector2(1, 1)]
		for heading: Vector2 in headings:
			var start: Vector2 = cell.call(100.5, 100.5) + (cell.call(heading.x, heading.y) - cell.call(0, 0)) * 0.4
			player.global_position = start
			var route := PackedVector2Array([cell.call(100.5, 100.5)])
			for k: int in range(1, 4): route.append(cell.call(100.5 + heading.x * k, 100.5 + heading.y * k))
			player.set_click_path(route, route[-1])
			var track := Track.new(); track.coordinates = c
			await _step(player, track, 240 * 4, Callable(), route[-1])
			results["click_%s_x%.1f" % [str(heading), multiplier]] = track.summary()
			check(track.reversals == 0, "click path (first point behind) x%.1f %s: no reversal %s" % [multiplier, str(heading), str(track.first_reversal)])
			check(player.global_position.distance_to(route[-1]) < 6.0, "click path x%.1f %s arrives" % [multiplier, str(heading)])
		# 2) Auto pursuit: the route to a target is re-searched every 0.65 s from
		# wherever the player is; every new route starts at its cell centre.
		var target: Vector2 = cell.call(100.5, 110.5)
		player.global_position = cell.call(100.5, 100.5)
		var repath := func() -> void:
			var here: Vector2 = c.world_to_grid(player.global_position)
			var from := Vector2(floorf(here.x) + 0.5, floorf(here.y) + 0.5)
			var route := PackedVector2Array([c.grid_to_world(from.x, from.y)])
			var g: Vector2 = from
			while g.distance_to(Vector2(100.5, 110.5)) > 0.01:
				g = g + Vector2(signf(100.5 - g.x), signf(110.5 - g.y))
				route.append(c.grid_to_world(g.x, g.y))
			player.set_click_path(route, target)
		var pursuit := Track.new(); pursuit.coordinates = c
		await _step(player, pursuit, int(ceil(10.0 / (2.25 * multiplier) * 120.0)) + 180, repath, target)
		results["pursuit_x%.1f" % multiplier] = pursuit.summary()
		check(pursuit.reversals == 0 and pursuit.facing_flips == 0, "auto pursuit re-search x%.1f: no reversal/facing flip %s" % [multiplier, str(pursuit.first_reversal)])
		check(player.global_position.distance_to(target) < 6.0, "auto pursuit x%.1f reaches the target" % multiplier)
	player.set_equipment_speed_multipliers(1.0, 1.0)
	# 2b) A real corner is still walked through (no corner cutting).
	player.global_position = cell.call(100.5, 100.5)
	var corner: Vector2 = cell.call(103.5, 100.5)
	player.set_click_path(PackedVector2Array([cell.call(101.5, 100.5), cell.call(102.5, 100.5), corner, cell.call(103.5, 101.5), cell.call(103.5, 103.5)]), cell.call(103.5, 103.5))
	var corner_track := Track.new(); corner_track.coordinates = c
	var closest: float = INF
	for i: int in 480:
		await _step(player, corner_track, 1)
		closest = minf(closest, player.global_position.distance_to(corner))
	results["corner_closest_px"] = closest
	check(closest <= 5.5, "an L route passes its corner point (closest %.2f px)" % closest)
	check(corner_track.reversals == 0, "an L route has no reversal")
	# 3) Pure helper: a route that has passed points drops them and never turns back.
	var here: Vector2 = cell.call(10.9, 10.5)
	var trimmed: PackedVector2Array = PATH_PROGRESS.trim_passed(here, PackedVector2Array([cell.call(10.5, 10.5), cell.call(11.5, 10.5), cell.call(12.5, 10.5)]), c, func(_a: Vector2, _b: Vector2) -> bool: return true)
	check(trimmed.size() == 2 and trimmed[0] == cell.call(11.5, 10.5), "trim_passed drops the start cell behind the player")
	var ahead: PackedVector2Array = PATH_PROGRESS.trim_passed(cell.call(10.1, 10.5), PackedVector2Array([cell.call(10.5, 10.5), cell.call(10.5, 11.5)]), c, func(_a: Vector2, _b: Vector2) -> bool: return true)
	check(ahead.size() == 2, "a first point ahead (a real corner) is kept")
	var turn: PackedVector2Array = PATH_PROGRESS.trim_passed(cell.call(10.9, 10.5), PackedVector2Array([cell.call(10.5, 10.5), cell.call(10.5, 11.5)]), c, func(_a: Vector2, _b: Vector2) -> bool: return true)
	check(turn.size() == 2, "a corner cell the player is still inside is kept (no wall cutting)")
	var walled: PackedVector2Array = PATH_PROGRESS.trim_passed(here, PackedVector2Array([cell.call(10.5, 10.5), cell.call(11.5, 10.5)]), c, func(_a: Vector2, _b: Vector2) -> bool: return false)
	check(walled.size() == 2, "a passed point is kept when the field blocks the straight walk (no wall cutting)")
	check(PATH_PROGRESS.trim_passed(here, PackedVector2Array([cell.call(10.5, 10.5), cell.call(11.5, 10.5)]), c).size() == 2, "without a field line test nothing is skipped")
	# 4) Stuck detection is per expected step, not per pixel: a legal slow
	# vertical walk (0.9 px per 60 Hz frame) is progress.
	check(not PATH_PROGRESS.stalled(Vector2(0, 0.9), 54.0, 1.0 / 60.0), "slow vertical step is not a stall")
	check(PATH_PROGRESS.stalled(Vector2(0, 0.02), 54.0, 1.0 / 30.0), "no motion while walking is a stall")
	check(not PATH_PROGRESS.stalled(Vector2.ZERO, 0.0, 1.0 / 30.0), "standing still on purpose is not a stall")
	evidence["synthetic"] = results
	host.queue_free()

## Actual Main ---------------------------------------------------------------
func _cell() -> Vector2i:
	return world.field_map.world_to_cell(world.player.global_position) + world.field_map.coordinates.origin

func _record(track: Track, frames: int, stick: Vector2 = Vector2.ZERO, until: Callable = Callable()) -> int:
	var p: Node = world.player
	for i: int in frames:
		var before: Vector2 = p.global_position
		await physics_frame
		var extra: Dictionary = {"r": p.original_source_preview.source_role(), "sf": int(p.original_source_preview.last_source_frame), "pi": int(p.path_index), "pn": p.click_path.size()}
		if is_instance_valid(world.auto_target): extra["t"] = world.auto_target.get_instance_id() % 100000
		extra["st"] = snappedf(float(world.auto_stuck_time), 0.01)
		track.add(before, p.global_position, int(p.motion.facing8), str(p.motion.state), extra, stick)
		if until.is_valid() and until.call(): return i + 1
	return frames

func _open_cell(from: Vector2i, step: Vector2i, cells: int) -> bool:
	var field = world.field_map
	for k: int in range(1, cells + 1):
		if not field.walkable(field.coordinates.to_world(Vector2(from + step * k))): return false
	return true

func _find_open_spot(cells: int) -> bool:
	# Somewhere on this Land with open ground in all 8 directions (scroll hops).
	var scroll: String = ""
	for key: Variant in world.inventory.keys():
		if str(key).contains("순간이동 주문서"): scroll = str(key); break
	for attempt: int in 12:
		var here: Vector2i = _cell()
		var all_open: bool = true
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			all_open = all_open and _open_cell(here, step, cells)
		if all_open: return true
		if scroll.is_empty() or int(world.inventory.get(scroll, 0)) <= 0: return false
		world.portal_cooldown = 0.0
		world._use_quick_item(scroll)
		for i: int in 20: await process_frame
	return false

func real_main(base: String) -> void:
	if root.get_node_or_null("Source523Pack") == null or not bool(root.get_node("Source523Pack").get("configured")):
		var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
		check(read.ok, "installed pack descriptor")
		if read.ok: PACK.apply(PACK.selections(base, read.descriptor, PACK.read_addons(base)))
	HOST.refresh()
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	var opened: bool = await _wait_for(func() -> bool: return bool(world.get("current523_aden_play_active")), 1500)
	if not check(opened, "523 play mode active: " + str(world.get("current523_aden_play_problem"))): return
	check(QA.enter_game(world), "class chosen (game entered)")
	await _wait_for(func() -> bool: return world.player.original_source_preview.installed(), 600)
	for i: int in 60: await process_frame
	world.level = maxi(int(world.level), 60)
	var p: Node = world.player
	p.set_auto_enabled(false)
	evidence["start"] = {"land": world.field_map.native_land.get("ID"), "cell": [_cell().x, _cell().y], "actor_installed": p.original_source_preview.installed(), "speed_multiplier": p.walk_speed_multiplier()}
	var field = world.field_map
	var open: bool = await _find_open_spot(4)
	evidence["open_spot"] = {"ok": open, "cell": [_cell().x, _cell().y]}
	# 1) Joystick, 8 directions (the HUD stick drives set_touch_vector).
	var joystick: Dictionary = {}
	var total_reversals: int = 0
	for stick: Vector2 in [Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2.DOWN, Vector2(-1, 1).normalized(), Vector2.LEFT, Vector2(-1, -1).normalized(), Vector2.UP, Vector2(1, -1).normalized()]:
		var track := Track.new(); track.coordinates = field.coordinates
		p.set_touch_vector(stick)
		await _record(track, 30, stick)
		p.set_touch_vector(-stick)
		await _record(track, 30, -stick)
		p.set_touch_vector(Vector2.ZERO)
		await _record(track, 4)
		# The deliberate 180-degree stick change is one reversal by definition.
		var s: Dictionary = track.summary()
		s["reversals"] = maxi(0, track.reversals - 1)
		s["facing_flips"] = maxi(0, track.facing_flips - 1)
		s.erase("first_reversal")
		joystick[str(stick)] = s
		total_reversals += int(s.reversals) + track.against_stick
		check(track.against_stick == 0 and int(s.reversals) == 0, "joystick %s: no frame against the stick / no reversal %s" % [str(stick), str(s)])
		check(int(s.facing_flips) == 0, "joystick %s: facing does not flip back and forth (%d)" % [str(stick), int(s.facing_flips)])
		check(track.moving_frames >= 40, "joystick %s moves (%d moving frames)" % [str(stick), track.moving_frames])
	evidence["joystick"] = joystick
	# 2) Click move: the HUD tap destination route (world._set_click_destination),
	# near and far (far taps around obstacles take an A* route).
	var clicks: Dictionary = {}
	for step: Vector2i in [Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(0, -3), Vector2i(3, 3), Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(9, 2), Vector2i(-2, 9), Vector2i(-9, -3), Vector2i(4, -9)]:
		var goal_cell: Vector2i = _cell() + step
		var goal: Vector2 = field.coordinates.to_world(Vector2(goal_cell) + Vector2(0.37, 0.61), false)
		if not field.walkable(goal): continue
		var track := Track.new(); track.coordinates = field.coordinates
		p.clear_click_path()
		world._set_click_destination(goal)
		if p.click_path.is_empty() or p.path_index >= p.click_path.size(): continue
		var route_points: int = p.click_path.size()
		var used: int = await _record(track, 300, Vector2.ZERO, func() -> bool: return p.path_index >= p.click_path.size())
		await _record(track, 3)
		var s: Dictionary = track.summary()
		s["frames_to_arrive"] = used
		s["route_points"] = route_points
		clicks[str(step)] = s
		check(track.reversals == 0 and track.facing_flips == 0, "click move %s: no reversal / facing flip %s" % [str(step), str(s)])
	evidence["click"] = clicks
	check(clicks.size() >= 4, "enough click moves on open ground (%d)" % clicks.size())
	# 3) Auto hunting pursuit (world._run_auto_hunt as played): explicit test
	# fixtures (never original spawn records) placed around the player, one at
	# a time, in the open and behind obstacles (A* pursuit routes).
	var spots: Array[Vector2i] = []
	var origin_cell: Vector2i = _cell()
	for offset: Vector2i in [Vector2i(0, 8), Vector2i(-7, -7), Vector2i(8, 0), Vector2i(7, -7), Vector2i(-8, 2), Vector2i(2, -8)]:
		if field.walkable(field.coordinates.to_world(Vector2(origin_cell + offset))): spots.append(origin_cell + offset)
	var hidden: int = 0
	for r: int in range(5, 13):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if hidden >= 3 or maxi(absi(dx), absi(dy)) != r: continue
				var cell: Vector2i = origin_cell + Vector2i(dx, dy)
				var spot: Vector2 = field.coordinates.to_world(Vector2(cell))
				if not field.walkable(spot) or field.line_clear(p.global_position, spot): continue
				var route: PackedVector2Array = world.find_world_path(p.global_position, spot)
				if route.size() < 3 or route.size() > 30: continue
				spots.append(cell); hidden += 1
	evidence["auto_spots"] = {"open": spots.size() - hidden, "behind_obstacles": hidden}
	var pursuit := Track.new(); pursuit.coordinates = field.coordinates
	var drops: int = 0
	var reached: int = 0
	var pursuit_frames: int = 0
	var per_spot: Array = []
	for cell: Vector2i in spots:
		var fixture: TwilightMonster = preload("res://scenes/Monster.tscn").instantiate()
		fixture.position = world.monsters_root.to_local(field.coordinates.to_world(Vector2(cell)))
		world.monsters_root.add_child(fixture)
		fixture.setup({"name": "walk_jitter_fixture", "hp": 1000000000, "lv": 1, "atk": 0}, p, world, null)
		fixture.set_physics_process(false)
		world.auto_target = null
		world.selected_monster = null
		world.auto_repath_timer = 0.0
		world.auto_target_failed_paths.clear()
		world.auto_target_next_search_ms = 0
		p.clear_click_path()
		p.set_auto_enabled(true)
		pursuit.reset_direction()
		var arrived: bool = false
		var spot_frames: int = 0
		var spot_reversals: int = pursuit.reversals
		var trace: Array = []
		var routes: Array = []
		var last_route: PackedVector2Array = PackedVector2Array()
		var src := func(v: Vector2) -> Array:
			var q: Vector2 = field.coordinates.to_source(v) - Vector2(origin_cell)
			return [snappedf(q.x, 0.01), snappedf(q.y, 0.01)]
		for i: int in 360:
			var before_target: Variant = world.auto_target
			var stuck_before: float = float(world.auto_stuck_time)
			await _record(pursuit, 1)
			if p.click_path != last_route:
				last_route = p.click_path.duplicate()
				if routes.size() < 40: routes.append({"f": i, "at": src.call(p.global_position), "pts": Array(last_route).map(func(v: Vector2) -> Array: return src.call(v))})
			if trace.size() < 200: trace.append([i] + src.call(p.global_position) + [p.path_index, snappedf(float(world.auto_stuck_time), 0.01), bool(p.motion.active), world.auto_target == fixture])
			if world.auto_target != before_target:
				pursuit.reset_direction()
				if before_target == fixture and is_instance_valid(fixture) and stuck_before > 1.9: drops += 1
			if p.path_index < p.click_path.size(): pursuit_frames += 1; spot_frames += 1
			if world.auto_target == fixture and world._target_in_current_weapon_range(fixture) and bool(p.motion.active):
				arrived = true
				break
		p.set_auto_enabled(false)
		p.clear_click_path()
		if arrived: reached += 1
		var entry: Dictionary = {"cell": [cell.x - origin_cell.x, cell.y - origin_cell.y], "arrived": arrived, "walk_frames": spot_frames, "reversals": pursuit.reversals - spot_reversals, "fixture_at": src.call(fixture.global_position)}
		if OS.get_cmdline_user_args().has("--trace") and (not arrived or int(entry.reversals) > 0):
			entry["routes"] = routes
			entry["trace"] = trace
		per_spot.append(entry)
		world.auto_target = null
		world.selected_monster = null
		fixture.queue_free()
		for i: int in 3: await physics_frame
	var auto_summary: Dictionary = pursuit.summary()
	auto_summary["stuck_drops"] = drops
	auto_summary["reached"] = reached
	auto_summary["pursuit_frames"] = pursuit_frames
	auto_summary["per_spot"] = per_spot
	evidence["auto"] = auto_summary
	check(pursuit.reversals == 0 and pursuit.facing_flips == 0, "auto hunting pursuit: no reversal / facing flip %s" % str(auto_summary))
	check(drops == 0, "auto hunting never drops a live target as stuck while walking (%d)" % drops)
	check(spots.size() >= 3 and reached >= spots.size() - 1, "auto hunting reaches the placed targets (%d/%d)" % [reached, spots.size()])

func _run() -> void:
	var base: String = _pack_root()
	if not base.is_empty():
		await real_main(base)
		if is_instance_valid(world): world.queue_free()
		for i: int in 5: await process_frame
	var synthetic_started: int = Time.get_ticks_msec()
	# CI time budget: the synthetic walks run at 120 physics ticks/s, uncapped
	# frames (the walk is velocity x delta; the project keeps its own rates).
	var ticks: int = Engine.physics_ticks_per_second
	var max_fps: int = Engine.max_fps
	Engine.physics_ticks_per_second = 120
	Engine.max_physics_steps_per_frame = 8
	Engine.max_fps = 0
	await synthetic()
	Engine.physics_ticks_per_second = ticks
	Engine.max_fps = max_fps
	evidence["synthetic_seconds"] = (Time.get_ticks_msec() - synthetic_started) / 1000.0
	evidence["real_input_checked"] = not base.is_empty()
	print("WALK_JITTER_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence}))
	await process_frame
	quit(0 if failures.is_empty() else 1)
