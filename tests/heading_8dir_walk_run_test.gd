extends SceneTree
## User report 2026-11-20 (phone recording 1001112624.mp4, elf, auto combat with
## the acceleration run): "왼쪽 위 뛰는거봐" - the suspicion was a wrong heading
## index (front pose while running up-left).
##
## Checked against the recording: at 12.3-13.8 s, where the body shows the
## front run pose, the stick is held straight down and the field scrolls up
## (the player runs S, the front pose is the S view). At 9.0-9.8 s (stick
## up-left) the body shows the NW back view, at 8.0-8.8 s (up-right) the NE
## view, at 14-17 s (up) the N back view, and left the side view.
##
## This test keeps the whole chain fixed for all eight directions, walk and
## run, so a later change cannot swap a view:
##   stick / click / auto-hunt route -> one of the eight cell steps (#733)
##   -> ActorMotion facing8 (clockwise from E) -> stored source direction
##   (facing8 + 3) whose own original frames travel that same way,
##   for the walk actor 15282 and its SpriteRun run actor 15284 (#697).
##
## Always (CI): sector snap, route legs, facing, the source direction mapping
## and the measured 523 travel of every stored direction of both actors.
## With --source523-pack=<root> (actual Main, elf on the 523 Land): stick,
## click and a multi-leg route (the auto-hunt API) in all eight directions at
## the base speed (walk 15282) and accelerated (run 15284): the shown role,
## facing and source direction, and the real track's own travel direction.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const SOURCE_WALK = preload("res://scripts/maps/source_walk_speed.gd")
const HOST = preload("res://scripts/maps/current523_host.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const NAMES: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
## One-loop travel (source px) of each stored direction 0..7, measured from the
## cooked 523 frames (body anchor, least squares over the 8 frames).
const WALK_15282_TRAVEL: Array[Vector2] = [Vector2(-36.95, -12.10), Vector2(1.10, -24.86), Vector2(37.29, -12.29), Vector2(48.76, 0.10), Vector2(24.19, 11.95), Vector2(-0.48, 22.95), Vector2(-34.38, 19.10), Vector2(-47.52, -0.71)]
const RUN_15284_TRAVEL: Array[Vector2] = [Vector2(-27.81, -11.29), Vector2(3.14, -23.90), Vector2(18.76, -13.33), Vector2(46.76, -1.14), Vector2(27.62, 10.86), Vector2(-4.29, 24.00), Vector2(-19.05, 11.86), Vector2(-47.48, -4.10)]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class FakeCoords extends RefCounted:
	var valid: bool = true
	var basis_x := Vector2(24, -12)
	var basis_y := Vector2(24, 12)
	func world_to_grid(p: Vector2) -> Vector2:
		var d: float = basis_x.x * basis_y.y - basis_x.y * basis_y.x
		return Vector2((p.x * basis_y.y - p.y * basis_y.x) / d, (p.y * basis_x.x - p.x * basis_x.y) / d)
	func grid_to_world(x: float, y: float) -> Vector2: return basis_x * x + basis_y * y

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("HEADING_8DIR_FAIL: ", label)
	return condition

func _initialize() -> void: _run.call_deferred()

## The facing8 (0..7) of the one-cell screen step closest in angle to `travel`.
static func nearest_cell_facing(steps: Array[Vector2], travel: Vector2) -> int:
	var best: int = -1
	var best_angle: float = INF
	for step: Vector2 in steps:
		var angle: float = absf(angle_difference(step.angle(), travel.angle()))
		if angle < best_angle:
			best_angle = angle
			best = posmod(int(round(step.angle() / (PI / 4.0))), 8)
	return best

func _facing_of(velocity: Vector2) -> int:
	var motion = MOTION.new()
	motion.face(velocity)
	return motion.facing8

func pure() -> void:
	var c := FakeCoords.new()
	var steps: Array[Vector2] = SOURCE_WALK.cell_steps(c)
	var bad: Array = []
	# Stick: every direction inside each 45-degree sector walks that sector's
	# cell step and faces it.
	for k: int in 8:
		for wobble: float in [-20.0, 0.0, 20.0]:
			var stick := Vector2.RIGHT.rotated(deg_to_rad(45.0 * k + wobble))
			var step: Vector2 = SOURCE_WALK.cell_direction(c, stick)
			var facing: int = _facing_of(step)
			if facing != k or nearest_cell_facing(steps, step) != k: bad.append([NAMES[k], wobble, str(step), facing])
	check(bad.is_empty(), "stick: eight sectors -> their cell step and facing %s" % str(bad))
	# Click / auto-hunt route legs: diagonal then straight, each facing its step.
	bad.clear()
	for gx: int in [-3, -1, 0, 1, 3]:
		for gy: int in [-3, -1, 0, 1, 3]:
			if gx == 0 and gy == 0: continue
			var leg: Dictionary = SOURCE_WALK.cell_leg(c, Vector2.ZERO, c.grid_to_world(gx, gy))
			if leg.is_empty(): bad.append([gx, gy, "none"]); continue
			var facing: int = _facing_of(leg.direction)
			if facing != nearest_cell_facing(steps, leg.direction): bad.append([gx, gy, str(leg.direction), facing])
	check(bad.is_empty(), "route legs face their own cell step %s" % str(bad))
	# Facing -> stored source direction -> that direction's original frames
	# travel the same way, for walk 15282 and run 15284.
	var mapping: Array = []
	for role: String in ["walk", "run"]:
		var travel: Array[Vector2] = WALK_15282_TRAVEL if role == "walk" else RUN_15284_TRAVEL
		bad.clear()
		for k: int in 8:
			var source: int = PREVIEW.source_direction_for(k)
			if role == "walk": mapping.append(source)
			var got: int = nearest_cell_facing(steps, travel[source])
			if got != k: bad.append([NAMES[k], source, NAMES[got] if got >= 0 else "?"])
		check(bad.is_empty(), "%s: facing E..NE shows the stored direction whose frames move that way %s" % [role, str(bad)])
	evidence["facing_to_source"] = mapping
	check(mapping == [3, 4, 5, 6, 7, 0, 1, 2], "facing E,SE,S,SW,W,NW,N,NE -> stored 3,4,5,6,7,0,1,2 (%s)" % str(mapping))
	# The front (S) view is the down move only; NW is stored 0.
	check(PREVIEW.source_direction_for(2) == 5 and PREVIEW.source_direction_for(5) == 0 and PREVIEW.source_direction_for(-3) == 0 and PREVIEW.source_direction_for(13) == 0, "S -> stored 5 (front), NW -> stored 0, out-of-range facings wrap")

func _pack_root() -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source523-pack="): return value.trim_prefix("--source523-pack=")
	return ""

func _run() -> void:
	pure()
	var base: String = _pack_root()
	if not base.is_empty(): await real_main(base)
	var result: Dictionary = {"checks": checks, "failures": failures, "evidence": evidence}
	print("HEADING_8DIR_RESULT ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _sample(p: Node2D, pv: Node, role: String, expected: int, frames: int, label: String, report: Dictionary) -> void:
	var good: int = 0
	var bad: Dictionary = {}
	for i: int in frames:
		await physics_frame
		var v: Vector2 = p.get_real_velocity()
		if v.length_squared() < 1.0: continue
		var want: int = expected if expected >= 0 else posmod(int(round(v.angle() / (PI / 4.0))), 8)
		var key: String = "f8=%d src_facing=%d role=%s" % [p.motion.facing8, int(pv.source_facing), str(pv.source_role())]
		if p.motion.facing8 == want and int(pv.source_facing) == want and pv.source_role() == role: good += 1
		else: bad[key] = int(bad.get(key, 0)) + 1
	report[label] = {"good": good, "bad": bad}
	check(good >= 10 and bad.is_empty(), "%s: %s facing and source view (%d good, %s)" % [label, role, good, str(bad)])

func real_main(base: String) -> void:
	var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
	if not check(read.ok, "installed pack descriptor"): return
	PACK.apply(PACK.selections(base, read.descriptor, PACK.read_addons(base)))
	HOST.refresh()
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for i: int in 1500:
		if bool(world.get("current523_aden_play_active")): break
		await process_frame
	if not check(bool(world.get("current523_aden_play_active")), "523 play mode active"): return
	check(QA.enter_game(world, "요정"), "elf chosen")
	world.set_source_character_gender(2)
	var p: Node2D = world.player
	for i: int in 900:
		if p.original_source_preview.installed(): break
		await process_frame
	if not check(p.original_source_preview.installed(), "the elf's original actor is drawn"): return
	for i: int in 30: await process_frame
	p.set_auto_enabled(false)
	var pv = p.original_source_preview
	var coords: Variant = SOURCE_WALK.coordinates_of(world.get("field_map"))
	if not check(coords != null, "original Land cell basis"): return
	var steps: Array[Vector2] = SOURCE_WALK.cell_steps(coords)
	evidence["cooked_actor"] = pv.cooked_actor()
	# The real tracks: each stored direction's own frames travel the way its facing moves.
	var tracks: Dictionary = {}
	for role: String in ["walk", "run"]:
		if not check(pv._playback_tracks.has(role), "%s track loaded" % role): return
		var track: Dictionary = pv._playback_tracks[role]
		tracks[role] = int(track.get("source_sprite_id", 0))
		var saved: String = pv._role
		pv._role = role
		var bad: Array = []
		var travel: Array = []
		for k: int in 8:
			var source: int = PREVIEW.source_direction_for(k)
			var points: Array[Vector2] = pv._walk_anchor_points(track.directions[source], source)
			var slope: Vector2 = PREVIEW.fit_root_motion(points)
			travel.append([snappedf(slope.x * points.size(), 0.01), snappedf(slope.y * points.size(), 0.01)])
			if slope == Vector2.ZERO or nearest_cell_facing(steps, slope) != k: bad.append([NAMES[k], source, str(slope)])
		pv._role = saved
		evidence["%s_travel_by_facing" % role] = travel
		check(bad.is_empty(), "real %s %d: the view of each facing travels that way %s" % [role, tracks[role], str(bad)])
	evidence["actors"] = tracks
	check(tracks.get("walk") == 15282 and tracks.get("run") == 15284, "walk 15282, SpriteRun 15284 (%s)" % str(tracks))
	var report: Dictionary = {}
	for mult: float in [1.0, 1.5]:
		var role: String = "walk" if mult == 1.0 else "run"
		p.skill_speed_multiplier = mult
		for k: int in 8:
			var stick := Vector2.RIGHT.rotated(k * PI / 4.0)
			p.set_touch_vector(stick)
			for i: int in 4: await physics_frame
			await _sample(p, pv, role, k, 20, "stick %s %s" % [NAMES[k], role], report)
			p.set_touch_vector(Vector2.ZERO)
			for i: int in 4: await physics_frame
		for k: int in 8:
			var step: Vector2 = SOURCE_WALK.cell_direction(coords, Vector2.RIGHT.rotated(k * PI / 4.0))
			var target: Vector2 = p.global_position + step * 150.0
			p.set_manual_click_path(PackedVector2Array([target]), target)
			for i: int in 2: await physics_frame
			await _sample(p, pv, role, k, 20, "click %s %s" % [NAMES[k], role], report)
			p.clear_click_path()
			for i: int in 4: await physics_frame
		# Auto-hunt route (set_click_path): off-grid points walked as diagonal
		# then straight cell legs; every leg faces its own move.
		var o: Vector2 = p.global_position
		var route := PackedVector2Array([o + coords.grid_to_world(3.0, 1.0), o + coords.grid_to_world(1.0, -2.0), o + coords.grid_to_world(-2.0, -1.0), o + coords.grid_to_world(0.0, 2.0)])
		p.set_click_path(route, route[route.size() - 1])
		await _sample(p, pv, role, -1, 90, "route %s" % role, report)
		p.clear_click_path()
		for i: int in 4: await physics_frame
	p.skill_speed_multiplier = 1.0
	evidence["main"] = report
