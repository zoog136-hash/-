extends SceneTree
## User report after #832 (phone): "성물·인형 이동이 앞뒤로 왔다 갔다 함" -
## while the character walks, the summoned doll and relic surge back and forth.
##
## Causes reproduced here (same family as the character's #687/#733):
## 1. Root motion: the original 523 walk frames carry the step itself. The
##    character's actor cancels it (cancel_walk_root_motion), the followers'
##    actors did not, so their pictures ran ahead by up to a cell and jumped
##    back every cycle while the anchor itself moved smoothly.
## 2. Catch-up: the follow eased toward a point fixed to the character
##    (move_toward rate distance*7*dt). A long phone frame (200 ms) snapped the
##    follower onto that point, then the lag grew back: relative to the
##    character it jumped forward and drifted back after every hitch.
## 3. Heading: the placement turned to every facing8 change; an auto-hunt route
##    alternating diagonal / straight legs swung it back and forth.
##
## Kept for all eight directions (walk and run), with phone-like frame pacing
## (16.7 ms frames, one 200 ms frame every 0.25 s): each follower's progress
## along the travel direction never goes back, its offset to the character
## does not jump at hitches, and a zig-zag route does not swing it.
##   godot --headless --path <repo> --script res://tests/companion_follow_surge523_test.gd
const PLACEMENT = preload("res://scripts/animation/companion_placement.gd")
const FOLLOWER = preload("res://scripts/animation/follower_motion.gd")
const RELIC = preload("res://scripts/animation/relic_motion.gd")
const SUBSLOT = preload("res://scripts/cards/native_doll_subslot_visual.gd")
const NAMES: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const WALK_SPEED: float = 108.0
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
## Body anchor (source px) of the 8 walk frames per facing8 E..NE, read from the
## installed 523 bank in actual Main (doll 그레그 actor 9699, relic 세계수의
## 꽃잎 actor 29540). The relic hops while it steps.
const DOLL_9699_WALK: Array = [[[17,-22],[22,-28],[29,-31],[36,-30],[43,-28],[49,-22],[54,-20],[59,-20]], [[17,-22],[20,-27],[23,-28],[27,-26],[30,-21],[33,-14],[36,-11],[38,-9]], [[17,-22],[18,-26],[18,-25],[18,-21],[17,-15],[17,-6],[17,-1],[16,2]], [[17,-22],[15,-27],[12,-28],[8,-26],[4,-21],[0,-14],[-3,-11],[-6,-9]], [[17,-22],[12,-28],[6,-31],[-1,-30],[-9,-28],[-15,-22],[-21,-20],[-27,-20]], [[17,-22],[15,-29],[12,-33],[8,-34],[4,-34],[0,-30],[-3,-30],[-6,-30]], [[17,-22],[18,-31],[18,-36],[18,-39],[17,-40],[17,-38],[16,-39],[16,-42]], [[17,-22],[20,-29],[23,-33],[27,-34],[30,-34],[33,-30],[36,-30],[38,-30]]]
const RELIC_29540_WALK: Array = [[[10,-57],[18,-64],[25,-76],[32,-78],[37,-76],[41,-71],[48,-67],[52,-62]], [[9,-57],[13,-65],[21,-73],[24,-75],[26,-71],[27,-66],[29,-60],[30,-52]], [[10,-58],[10,-63],[17,-70],[17,-71],[16,-66],[14,-57],[11,-50],[11,-42]], [[10,-57],[10,-65],[12,-72],[10,-76],[5,-72],[0,-65],[-4,-58],[-10,-51]], [[14,-55],[7,-65],[6,-75],[1,-79],[-7,-77],[-15,-70],[-23,-66],[-29,-59]], [[13,-55],[11,-66],[11,-78],[8,-82],[4,-82],[0,-77],[-4,-73],[-7,-68]], [[13,-53],[14,-68],[16,-81],[15,-86],[14,-88],[13,-85],[13,-81],[12,-78]], [[13,-54],[14,-65],[22,-78],[23,-81],[25,-81],[26,-78],[29,-75],[33,-69]]]
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		printerr("COMPANION_FOLLOW_SURGE_FAIL: " + label)
	return value

func _initialize() -> void: _run.call_deferred()

## Screen direction the character walks for facing8 (Land cells are 2:1).
static func screen_dir(k: int) -> Vector2:
	var f := Vector2.RIGHT.rotated(k * PI / 4.0)
	return Vector2(f.x, f.y * 0.5).normalized()

## Phone-like pacing: 60 fps with one 200 ms frame every 0.25 s.
static func frame_delta(t: float, previous_t: float) -> float:
	return 0.2 if floorf(t / 0.25) != floorf(previous_t / 0.25) else 1.0 / 60.0

static func points_of(rows: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for q: Array in rows: out.append(Vector2(q[0], q[1]))
	return out

## Per-frame step a follower cancels (as _fit_walk_root_motion with
## root_motion_endpoint_fit, no cell steps).
static func cancelled_step(points: Array[Vector2], _endpoint: bool) -> Vector2:
	return PREVIEW.endpoint_root_motion(points)

## Drawn body travel at the loop seam (last frame -> next loop's frame 0) along
## the loop's travel, the host moving one cancelled step per frame.
static func seam_progress(points: Array[Vector2], step: Vector2, cancel: bool) -> float:
	var n: int = points.size()
	var dir: Vector2 = (points[n - 1] - points[0]).normalized()
	# Host H moves `step` per frame. Old: drawn H + p_k. Cancelled: H + p_k - step * k.
	var seam: Vector2 = points[0] - points[n - 1] + (step * float(n) if cancel else step)
	return dir.dot(seam)

func root_motion_frames() -> void:
	var seams: Dictionary = {}
	for pair: Array in [["doll 9699", DOLL_9699_WALK], ["relic 29540", RELIC_29540_WALK]]:
		var rows: Array = []
		for k: int in 8:
			var pts: Array[Vector2] = points_of(pair[1][k])
			var step: Vector2 = cancelled_step(pts, true)
			check(step.length() * pts.size() > 10.0, "%s %s: the loop's step is cancelled (%s)" % [pair[0], NAMES[k], str(step * pts.size())])
			# With the step cancelled the drawn body continues forward across the
			# seam; drawn unchanged (old) it ran ahead and jumped back.
			var after: float = seam_progress(pts, step, true)
			var before: float = seam_progress(pts, step, false)
			check(after >= 0.0, "%s %s: no jump back at the loop seam (%.1f px)" % [pair[0], NAMES[k], after])
			rows.append([NAMES[k], snappedf(before, 0.1), snappedf(after, 0.1)])
		seams[pair[0]] = rows
	# The plain least-squares fit (character) rejects the hopping relic loops.
	var rejected: int = 0
	for k: int in 8:
		if PREVIEW.fit_root_motion(points_of(RELIC_29540_WALK[k])) == Vector2.ZERO: rejected += 1
	check(rejected >= 4, "hopping relic loops need the end-to-end step (%d/8 rejected by the line fit)" % rejected)
	var flags: Array = []
	for owner: RefCounted in [FOLLOWER.new(), RELIC.new()]: flags.append(owner.native_actor.root_motion_endpoint_fit)
	var plain = PREVIEW.new()
	check(flags == [true, true] and not plain.root_motion_endpoint_fit, "followers measure the step end to end, the character keeps its fit")
	plain.free()
	var bob: Array[Vector2] = [Vector2(0, 0), Vector2(0, -6), Vector2(0, -10), Vector2(0, -6), Vector2(0, 0), Vector2(0, -6), Vector2(0, -10), Vector2(0, -1)]
	check(cancelled_step(bob, true) == Vector2.ZERO, "an in-place float has no step to cancel")
	evidence["seam_before_after"] = seams

func _run() -> void:
	root_motion_frames()
	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	root.add_child(world)
	var player: TwilightPlayer = load("res://scenes/Player.tscn").instantiate()
	world.add_child(player)
	var anchor := Node2D.new()
	anchor.name = "Companion"
	world.add_child(anchor)
	await process_frame
	player.set_physics_process(false)
	player.set_process(false)
	# 1. Root motion: the followers' original actors cancel the frames' step
	# like the character's, on the same field cell steps, and the follow never
	# overwrites the actor's own (root-motion) position.
	var doll: TwilightFollowerMotion = FOLLOWER.new()
	var relic: TwilightRelicMotion = RELIC.new()
	anchor.add_child(doll.native_actor)
	relic._attach_native(world)
	check(player.original_source_preview.cancel_walk_root_motion, "character cancels walk root motion")
	check(doll.native_actor.cancel_walk_root_motion and relic.native_actor.cancel_walk_root_motion, "doll and relic actors cancel walk root motion")
	var steps: Array[Vector2] = [Vector2(24, -12), Vector2(24, 12), Vector2(-24, 12), Vector2(-24, -12), Vector2(48, 0), Vector2(0, 24), Vector2(-48, 0), Vector2(0, -24)]
	player.original_source_preview.root_motion_cell_steps = steps
	player.motion.face(screen_dir(2))
	player.global_position = Vector2(4000, 4000)
	doll._place_now(player)
	relic._place_now(player)
	anchor.global_position = player.global_position + doll.follow_offset
	relic._apply_native_position(player)
	doll.native_actor.position = Vector2(5, -2)
	relic.native_actor.position = Vector2(-3, 4)
	doll.follow_native(1.0 / 60.0, anchor, player)
	relic.follow_native(1.0 / 60.0, player)
	check(doll.native_actor.root_motion_cell_steps == steps and relic.native_actor.root_motion_cell_steps == steps, "followers walk on the character's cell steps")
	check(doll.native_actor.position == Vector2(5, -2) and relic.native_actor.position == Vector2(-3, 4), "follow keeps the actor's root-motion position")
	var sub = SUBSLOT.new()
	check(sub.has_method("_apply_position"), "second doll/relic placement present")
	var sub_text: String = FileAccess.get_file_as_string("res://scripts/cards/native_doll_subslot_visual.gd")
	check(sub_text.contains("cancel_walk_root_motion=true") and not sub_text.contains("actor.position=Vector2.ZERO") and not sub_text.contains("actor.global_position=visual_position"), "second doll/relic cancel root motion and keep the actor position")
	sub.free()
	# 2. Straight travel in all eight directions, walk and run, phone pacing.
	var report: Dictionary = {}
	for speed: float in [WALK_SPEED, WALK_SPEED * 1.5]:
		for k: int in 8:
			var dir := screen_dir(k)
			player.motion.face(dir)
			player.velocity = Vector2.ZERO
			# Straight travel from rest facing that way (turning is section 3).
			doll._place_now(player)
			relic._place_now(player)
			for i: int in 200:
				doll.follow_native(1.0 / 60.0, anchor, player)
				relic.follow_native(1.0 / 60.0, player)
			player.velocity = dir * speed
			var t: float = 0.0
			var prev_t: float = -1.0
			var back_doll: float = 0.0
			var back_relic: float = 0.0
			var jump_doll: float = 0.0
			var jump_relic: float = 0.0
			var prev_dp: float = dir.dot(anchor.global_position)
			var prev_rp: float = dir.dot(relic.visual_position)
			var prev_doff := Vector2.INF
			var prev_roff := Vector2.INF
			while t < 3.0:
				var dt: float = frame_delta(t, prev_t) if t > 0.0 else 1.0 / 60.0
				prev_t = t
				t += dt
				player.global_position += player.velocity * dt
				doll.follow_native(dt, anchor, player)
				relic.follow_native(dt, player)
				var dp: float = dir.dot(anchor.global_position)
				var rp: float = dir.dot(relic.visual_position)
				back_doll = maxf(back_doll, prev_dp - dp)
				back_relic = maxf(back_relic, prev_rp - rp)
				prev_dp = dp
				prev_rp = rp
				var doff: Vector2 = anchor.global_position - player.global_position
				var roff: Vector2 = relic.visual_position - player.global_position
				if t > 1.0 and prev_doff != Vector2.INF:
					jump_doll = maxf(jump_doll, doff.distance_to(prev_doff))
					jump_relic = maxf(jump_relic, roff.distance_to(prev_roff))
				prev_doff = doff
				prev_roff = roff
			var label: String = "%s %s" % [NAMES[k], "walk" if speed == WALK_SPEED else "run"]
			check(back_doll <= 0.01 and back_relic <= 0.01, "%s: progress never goes back (doll %.2f, relic %.2f px)" % [label, back_doll, back_relic])
			check(jump_doll < 1.0 and jump_relic < 1.0, "%s: offset to the character steady across 200 ms frames (doll %.2f, relic %.2f px)" % [label, jump_doll, jump_relic])
			var lag: float = (anchor.global_position - player.global_position).distance_to(PLACEMENT.doll_offset(k))
			check(lag > 2.0 and lag < 30.0, "%s: doll trails its place by a short lag (%.1f)" % [label, lag])
			report[label] = {"back": [snappedf(back_doll, 0.01), snappedf(back_relic, 0.01)], "jump": [snappedf(jump_doll, 0.01), snappedf(jump_relic, 0.01)], "lag": snappedf(lag, 0.1)}
	evidence["straight"] = report
	# 3. Zig-zag auto-hunt legs: E and SE alternating every 0.25 s.
	player.motion.face(screen_dir(0))
	player.velocity = Vector2.ZERO
	doll._place_now(player)
	relic._place_now(player)
	for i: int in 200:
		doll.follow_native(1.0 / 60.0, anchor, player)
		relic.follow_native(1.0 / 60.0, player)
	var mean_dir: Vector2 = (screen_dir(0) + screen_dir(1)).normalized()
	var t2: float = 0.0
	var prev_t2: float = -1.0
	var back: float = 0.0
	var prev_p: float = mean_dir.dot(anchor.global_position)
	var prev_rp2: float = mean_dir.dot(relic.visual_position)
	var lateral: Array[float] = []
	var side := mean_dir.orthogonal()
	while t2 < 4.0:
		var dt: float = frame_delta(t2, prev_t2) if t2 > 0.0 else 1.0 / 60.0
		prev_t2 = t2
		t2 += dt
		var leg: int = int(floorf(t2 / 0.25)) % 2
		player.motion.face(screen_dir(leg))
		player.velocity = screen_dir(leg) * WALK_SPEED
		player.global_position += player.velocity * dt
		doll.follow_native(dt, anchor, player)
		relic.follow_native(dt, player)
		var p: float = mean_dir.dot(anchor.global_position)
		var rp: float = mean_dir.dot(relic.visual_position)
		back = maxf(back, maxf(prev_p - p, prev_rp2 - rp))
		prev_p = p
		prev_rp2 = rp
		if t2 > 1.5: lateral.append(side.dot(anchor.global_position - player.global_position))
	var lo: float = INF
	var hi: float = -INF
	for v: float in lateral:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	check(back <= 0.01, "zig-zag: progress never goes back (%.2f px)" % back)
	check(hi - lo < 12.0, "zig-zag: doll does not swing side to side (%.1f px)" % (hi - lo))
	evidence["zigzag"] = {"back": snappedf(back, 0.01), "swing": snappedf(hi - lo, 0.1)}
	world.queue_free()
	await process_frame
	print("COMPANION_FOLLOW_SURGE523_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence}))
	quit(0 if failures.is_empty() else 1)
