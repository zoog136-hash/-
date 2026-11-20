extends SceneTree
## User report 2026-11-19 (phone recording, elf in 거울의 숲, auto combat):
## "여전히 케릭이동은 앞뒤로 왔다갔다하고".
##
## The recording shows the background scrolling smoothly while the character
## picture runs ahead along the walk direction and jumps back once per walk
## cycle (about one cell). Cause: the original walk/run frames carry the step
## themselves (523 elf 15282 walking up: body offset y +2, +1, 0, -4, -9, -11,
## -12, -17, then frame 0 again), while TWILIGHT also moves the player node
## smoothly at the original 2.25 cells/s, so the step was applied twice.
## original_source_preview.gd now removes the frames' linear drift for hosts
## that move smoothly (the player).
##
## Always (CI): the drift fit on the measured 523 frames, in-place cycles, other
## roles, the opt-in flag, cooked-state anchors.
## With --source523-pack=<root> (actual Main, the elf on the 523 Land): the
## picture's position relative to the player node stays within a few pixels
## over whole walk cycles in 3 directions (it swept 22-42 px before).
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
## One walk frame's step (48 px cell / 8 frames) plus the sampling slack.
const FRAME_STEP_SPAN: float = 8.0
const FRAME_STEP_JUMP: float = 6.5
const HOST = preload("res://scripts/maps/current523_host.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("WALK_ROOT_MOTION_FAIL: ", label)
	return condition

func _initialize() -> void: _run.call_deferred()

class FakeCoords extends RefCounted:
	var basis_x := Vector2(24, -12)
	var basis_y := Vector2(24, 12)
	func world_to_grid(p: Vector2) -> Vector2:
		var d: float = basis_x.x * basis_y.y - basis_x.y * basis_y.x
		return Vector2((p.x * basis_y.y - p.y * basis_y.x) / d, (p.y * basis_x.x - p.x * basis_x.y) / d)
	func grid_to_world(x: float, y: float) -> Vector2: return basis_x * x + basis_y * y

## Stick and route moves use the original's eight cell directions.
func walk_cells() -> void:
	var walk := preload("res://scripts/maps/source_walk_speed.gd")
	var c := FakeCoords.new()
	var expect: Dictionary = {0: Vector2(48, 0), 15: Vector2(48, 0), 30: Vector2(24, -12), 45: Vector2(24, -12), 60: Vector2(24, -12), 90: Vector2(0, -24), 180: Vector2(-48, 0), 225: Vector2(-24, 12), 270: Vector2(0, 24)}
	var bad: Array = []
	for deg: int in expect:
		var got: Vector2 = walk.cell_direction(c, Vector2.RIGHT.rotated(deg_to_rad(-float(deg))))
		if not got.is_equal_approx((expect[deg] as Vector2).normalized()): bad.append([deg, str(got)])
	check(bad.is_empty(), "a stick picks the cell step of its 45-degree sector: %s" % str(bad))
	check(walk.cell_direction(null, Vector2(1, 2)) == Vector2(1, 2), "off an original Land the stick is unchanged")
	var leg: Dictionary = walk.cell_leg(c, Vector2.ZERO, c.grid_to_world(3.0, 1.0))
	check(leg.get("kind") == "diagonal" and (leg.direction as Vector2).is_equal_approx(Vector2(48, 0).normalized()) and is_equal_approx(float(leg.length), 48.0), "a route leg walks the diagonal cell step first (%s)" % str(leg))
	var straight: Dictionary = walk.cell_leg(c, c.grid_to_world(1.0, 1.0), c.grid_to_world(3.0, 1.0))
	check(straight.get("kind") == "straight" and (straight.direction as Vector2).is_equal_approx(Vector2(24, -12).normalized()), "then straight along the remaining grid axis")
	var blocked: Dictionary = walk.cell_leg(c, Vector2.ZERO, c.grid_to_world(3.0, 1.0), func(a: Vector2, b: Vector2) -> bool: return not (a == Vector2.ZERO and b.is_equal_approx(c.grid_to_world(1.0, 1.0))))
	check(blocked.get("kind") == "straight_first", "a blocked diagonal corner walks the straight part first")

func _pack_root() -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source523-pack="): return value.trim_prefix("--source523-pack=")
	return ""

func _frames(points: Array) -> Array:
	var frames: Array = []
	for p: Variant in points:
		frames.append({"source_frame": frames.size(), "duration": 0.055, "layers": [
			{"kind": "shadow", "offset": [9, 4]},
			{"kind": "body", "offset": [p.x, p.y]}]})
	return frames

func _run() -> void:
	# 1) The measured 523 elf walk (facing up, source frames 0..7).
	var up: Array[Vector2] = [Vector2(6, 2), Vector2(6, 1), Vector2(5, 0), Vector2(6, -4), Vector2(7, -9), Vector2(7, -11), Vector2(7, -12), Vector2(6, -17)]
	var slope: Vector2 = PREVIEW.fit_root_motion(up)
	evidence["elf_up_slope"] = [slope.x, slope.y]
	check(slope.y < -2.5 and slope.y > -3.1 and absf(slope.x) < 0.3, "523 elf walk up: about one cell of drift per cycle is found %s" % str(slope))
	var worst: float = 0.0
	for k: int in up.size(): worst = maxf(worst, absf((up[k] - slope * float(k)).y - up[0].y))
	evidence["elf_up_residual_px"] = worst
	check(worst <= 4.0, "523 elf walk up: the cancelled body stays within 4 px of frame 0 (%.2f)" % worst)
	# In place: a bobbing idle-like walk is drawn unchanged.
	var bob: Array[Vector2] = [Vector2(0, 0), Vector2(0, -2), Vector2(1, -3), Vector2(0, -1), Vector2(0, 0), Vector2(0, -2), Vector2(-1, -3), Vector2(0, -1)]
	check(PREVIEW.fit_root_motion(bob) == Vector2.ZERO, "an in-place walk cycle has no drift to cancel")
	check(PREVIEW.fit_root_motion([Vector2.ZERO, Vector2(0, -9)] as Array[Vector2]) == Vector2.ZERO, "two frames are not a cycle")
	# 2) The preview applies it to its own position, per selected frame.
	var preview = PREVIEW.new()
	root.add_child(preview)
	preview._record = {"source_sprite_id": 15282}
	var frames: Array = _frames(up)
	var track: Dictionary = {"loop": true, "source_sprite_id": 15282, "source_action_id": 0, "directions": []}
	preview._role = "walk"
	preview._apply_walk_root_motion(track, frames, 4, 5, false)
	check(preview.position == Vector2.ZERO and preview.walk_root_motion_offset == Vector2.ZERO, "off by default (monsters, dolls, relics keep their frames)")
	preview.cancel_walk_root_motion = true
	var drawn: Array = []
	for k: int in frames.size():
		preview._apply_walk_root_motion(track, frames, 4, k, false)
		drawn.append((up[k] + preview.position).y)
	evidence["elf_up_drawn_body_y"] = drawn
	check(absf(float(drawn.max()) - float(drawn.min())) <= 5.0, "player: the body's drawn y spans at most 5 px over a cycle (was 19) %s" % str(drawn))
	check(absf(float(drawn[0]) - float(drawn[-1])) <= 4.0, "player: no jump back at the cycle start")
	preview.scale = Vector2(2, 2)
	preview._apply_walk_root_motion(track, frames, 4, 4, false)
	check(preview.position.is_equal_approx(preview.walk_root_motion_offset * 2.0), "scaled preview: the offset is converted to the parent's space")
	preview.scale = Vector2.ONE
	for role: String in ["idle", "attack"]:
		preview._role = role
		preview._apply_walk_root_motion(track, frames, 4, 6, false)
		check(preview.position == Vector2.ZERO, "%s frames are drawn unchanged" % role)
	preview._role = "run"
	preview._apply_walk_root_motion(track, frames, 4, 6, false)
	check(preview.position.y > 10.0, "run frames are cancelled like walk")
	var once: Dictionary = track.duplicate(); once["loop"] = false
	preview._role = "walk"
	preview._apply_walk_root_motion(once, frames, 4, 6, false)
	check(preview.position == Vector2.ZERO, "a one-shot track is drawn unchanged")
	preview._apply_walk_root_motion(track, frames, 4, 6, true)
	check(preview.position == Vector2.ZERO, "a static pending track is drawn unchanged")
	var no_body: Array = []
	for k: int in 8: no_body.append({"source_frame": k, "layers": [{"kind": "effect", "offset": [0, -k * 3]}]})
	preview._apply_walk_root_motion({"loop": true, "source_sprite_id": 1, "source_action_id": 0}, no_body, 0, 6, false)
	check(preview.position == Vector2.ZERO, "frames without a body layer are drawn unchanged")
	# 2026-11-20 "손발은 아직 살짝 어색": inside a shown frame the cancel is
	# continuous (the loop position), so the cell origin and the planted
	# foot stay put while the host node moves on.
	preview._role = "walk"
	preview._apply_walk_root_motion(track, frames, 4, 2.0, false)
	var at_two: Vector2 = preview.position
	preview._apply_walk_root_motion(track, frames, 4, 2.5, false)
	var at_half: Vector2 = preview.position
	preview._apply_walk_root_motion(track, frames, 4, 3.0, false)
	check(at_half.is_equal_approx((at_two + preview.position) * 0.5) and at_half != at_two, "the cancel moves continuously within a frame (2 -> 2.5 -> 3)")
	walk_cells()
	preview.clear()
	check(preview.position == Vector2.ZERO and preview._root_motion_fits.is_empty(), "clear() resets the offset and fits")
	preview.queue_free()
	# 3) Actual Main with the 523 pack.
	var base: String = _pack_root()
	if not base.is_empty(): await real_main(base)
	var result: Dictionary = {"checks": checks, "failures": failures, "evidence": evidence}
	print("WALK_ROOT_MOTION_RESULT ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func _box(node: Node) -> Rect2:
	var box := Rect2()
	var first: bool = true
	for child: Node in node.find_children("*", "Sprite2D", true, false):
		var sprite := child as Sprite2D
		if not sprite.is_visible_in_tree() or sprite.texture == null: continue
		var rect: Rect2 = sprite.get_global_transform() * sprite.get_rect()
		box = rect if first else box.merge(rect)
		first = false
	return box

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
	check(pv.cancel_walk_root_motion, "the player opts in")
	evidence["main_cooked_actor"] = pv.cooked_actor()
	var directions: Dictionary = {}
	for stick: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2(1, 1).normalized()]:
		p.set_touch_vector(stick)
		var along: Array = []
		var frames_seen: Dictionary = {}
		for i: int in 40:
			await physics_frame
			if str(p.motion.state) != "walk" or pv.source_role() != "walk": continue
			# Picture centre relative to the node, along the walk direction.
			var rel: Vector2 = _box(pv).get_center() - p.global_position
			var screen_dir: Vector2 = Vector2(stick.x, stick.y * 0.5).normalized()
			along.append(rel.dot(screen_dir))
			frames_seen[pv.last_source_frame] = true
		p.set_touch_vector(Vector2.ZERO)
		for i: int in 8: await physics_frame
		var span: float = (float(along.max()) - float(along.min())) if along.size() > 0 else -1.0
		var jump: float = 0.0
		for k: int in range(1, along.size()): jump = maxf(jump, absf(float(along[k]) - float(along[k - 1])))
		directions[str(stick)] = {"samples": along.size(), "frames": frames_seen.size(), "span_px": snappedf(span, 0.01), "max_step_px": snappedf(jump, 0.01)}
		check(along.size() >= 25 and frames_seen.size() >= 6, "%s: walks through a whole cycle" % str(stick))
		# Since 2026-11-20 the body keeps its cell origin while a frame is
		# shown (planted feet) and steps with the authored frame offset, so it
		# may lead or trail the node by up to one frame's step (1/8 of a cell:
		# 6 px sideways, 3 px up), never the old whole-cycle sweep.
		check(span >= 0.0 and span <= FRAME_STEP_SPAN and jump <= FRAME_STEP_JUMP, "%s: the picture stays on the moving node within one frame step (span %.2f, step %.2f; was 22-42 px)" % [str(stick), span, jump])
	evidence["main_directions"] = directions
