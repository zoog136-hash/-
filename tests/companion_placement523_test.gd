extends SceneTree
## Summoned magic doll / relic placement against the character (user report
## 2026-11-22: "마법인형·성물 위치는 소환한 뒤 캐릭터와의 위치 관계",
## "성물이 캐릭 앞에 있어"). Before: fixed screen offsets (-54,24) / (48,18)
## whatever the facing, so both stood south of the character and the y-sort
## drew them in front of it in all eight facings.
##
## The 523 data has no follow offset (NpcCategory 14 MagicDoll / 138 HolyStuff,
## server AI ids, no spr/list anchor), so the placement is TWILIGHT 근사 (see
## companion_placement.gd). This keeps for all eight facings, standing and
## moving: the doll trails behind and beside the facing, the relic floats
## behind the head and always sorts behind the character, the follow is smooth
## (no per-frame jumps), stops without jitter and turns around the character.
##   godot --headless --path <repo> --script res://tests/companion_placement523_test.gd
const PLACEMENT = preload("res://scripts/animation/companion_placement.gd")
const FOLLOWER = preload("res://scripts/animation/follower_motion.gd")
const RELIC = preload("res://scripts/animation/relic_motion.gd")
const NAMES: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const DT: float = 1.0 / 60.0
const WALK_SPEED: float = 108.0
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures.append(label)
		printerr("COMPANION_PLACEMENT_FAIL: " + label)
	return value

func _initialize() -> void: _run.call_deferred()

## Ground-plane (2:1 Land) unit vector of facing8, clockwise from E.
static func forward(k: int) -> Vector2:
	return Vector2.RIGHT.rotated(k * PI / 4.0)

static func ground(screen: Vector2, lift: float = 0.0) -> Vector2:
	return Vector2(screen.x, (screen.y + lift) * 2.0)

## Screen direction the character walks for facing8 (Land cells are 2:1).
static func screen_dir(k: int) -> Vector2:
	var f := forward(k)
	return Vector2(f.x, f.y * 0.5).normalized()

func pure() -> void:
	for k: int in 8:
		var f := forward(k)
		var d: Vector2 = ground(PLACEMENT.doll_offset(k))
		check(d.dot(f) < -30.0, "doll behind facing %s %s" % [NAMES[k], str(d)])
		var side: float = d.dot(f.rotated(PI / 2.0))
		check(absf(side) > 25.0, "doll beside facing %s" % NAMES[k])
		var m: Vector2 = ground(PLACEMENT.doll_offset(k, true))
		check(is_equal_approx(m.dot(f), d.dot(f)) and is_equal_approx(m.dot(f.rotated(PI / 2.0)), -side), "second doll mirrors the side %s" % NAMES[k])
		var r_screen: Vector2 = PLACEMENT.relic_offset(k)
		var r: Vector2 = ground(r_screen, PLACEMENT.RELIC_LIFT)
		check(r.dot(f) < -15.0, "relic behind facing %s %s" % [NAMES[k], str(r)])
		check(r_screen.y < -PLACEMENT.RELIC_LIFT * 0.5, "relic floats above the foot %s" % NAMES[k])
	# A reversal swings around the character: constant radius, never through it.
	var p = PLACEMENT.new()
	p.reset(0)
	var radius: float = ground(PLACEMENT.doll_offset(0)).length()
	var min_r: float = INF
	var frames: int = 0
	for i: int in 120:
		var o: Vector2 = ground(p.doll(DT, 4))
		min_r = minf(min_r, o.length())
		frames += 1
		if is_equal_approx(p.heading, PLACEMENT.facing_angle(4)) or is_equal_approx(absf(p.heading), PI): break
	check(min_r > radius - 0.5, "turn keeps the doll around the character (%.1f/%.1f)" % [min_r, radius])
	check(frames >= 20 and frames <= 40, "180-degree turn takes about half a second (%d frames)" % frames)

func follow() -> void:
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
	player.global_position = Vector2(4000, 4000)
	var doll: TwilightFollowerMotion = FOLLOWER.new()
	var relic: TwilightRelicMotion = RELIC.new()
	anchor.add_child(doll.native_actor)
	relic._attach_native(world)
	check(relic.native_actor.get_parent() == relic.sort_anchor and relic.sort_anchor.get_parent() == world, "relic actor sorts through its own anchor")
	player.motion.face(screen_dir(2))
	doll._place_now(player)
	relic._place_now(player)
	anchor.global_position = player.global_position + doll.follow_offset
	relic._apply_native_position(player)
	var report: Dictionary = {}
	for k: int in 8:
		var dir := screen_dir(k)
		player.motion.face(dir)
		check(player.motion.facing8 == k, "player faces %s" % NAMES[k])
		player.velocity = dir * WALK_SPEED
		var max_step: float = 0.0
		var max_relic_step: float = 0.0
		var prev_d := Vector2.INF
		var prev_r := Vector2.INF
		var behind_every_frame: bool = true
		var walk_frames: int = 0
		for i: int in 90:
			player.global_position += player.velocity * DT
			if doll.follow_native(DT, anchor, player) == "walk": walk_frames += 1
			relic.follow_native(DT, player)
			behind_every_frame = behind_every_frame and relic.sort_anchor.global_position.y < player.global_position.y
			var d: Vector2 = anchor.global_position - player.global_position
			var r: Vector2 = relic.native_actor.global_position - player.global_position
			if i > 45 and prev_d != Vector2.INF:
				max_step = maxf(max_step, d.distance_to(prev_d))
				max_relic_step = maxf(max_relic_step, r.distance_to(prev_r))
			prev_d = d
			prev_r = r
		var f := forward(k)
		var dg: Vector2 = ground(anchor.global_position - player.global_position)
		var rg: Vector2 = ground(relic.native_actor.global_position - player.global_position, PLACEMENT.RELIC_LIFT)
		check(behind_every_frame, "moving %s: relic drawn behind the character every frame" % NAMES[k])
		check(dg.dot(f) < -30.0, "moving %s: doll trails behind (%s)" % [NAMES[k], str(dg)])
		check(rg.dot(f) < -10.0, "moving %s: relic trails behind (%s)" % [NAMES[k], str(rg)])
		check(max_step < 0.5 and max_relic_step < 0.5, "moving %s: steady follow without jumps (%.2f, %.2f)" % [NAMES[k], max_step, max_relic_step])
		check(walk_frames > 80, "moving %s: doll walks while following" % NAMES[k])
		var lag: float = anchor.global_position.distance_to(player.global_position + doll.follow_offset)
		check(lag > 1.0 and lag < 24.0, "moving %s: doll follows with a short lag (%.1f)" % [NAMES[k], lag])
		# Stop: settle on the target, then hold still (no idle jitter).
		player.velocity = Vector2.ZERO
		for i: int in 150:
			doll.follow_native(DT, anchor, player)
			relic.follow_native(DT, player)
		var held_d: Vector2 = anchor.global_position
		var held_r: Vector2 = relic.native_actor.global_position
		var idle_state: String = ""
		for i: int in 60:
			idle_state = doll.follow_native(DT, anchor, player)
			relic.follow_native(DT, player)
		check(anchor.global_position == held_d and relic.native_actor.global_position.distance_to(held_r) < 0.01 and idle_state == "idle", "stopped %s: no idle jitter" % NAMES[k])
		check(anchor.global_position.distance_to(player.global_position + PLACEMENT.doll_offset(k)) < 0.7, "stopped %s: doll on its place" % NAMES[k])
		check(relic.native_actor.global_position.distance_to(player.global_position + PLACEMENT.relic_offset(k)) < 0.7, "stopped %s: relic on its place" % NAMES[k])
		check(relic.sort_anchor.global_position.y < player.global_position.y, "stopped %s: relic drawn behind the character" % NAMES[k])
		var doll_offset: Vector2 = anchor.global_position - player.global_position
		var relic_offset: Vector2 = relic.native_actor.global_position - player.global_position
		report[NAMES[k]] = {"doll": [snappedf(doll_offset.x, 0.1), snappedf(doll_offset.y, 0.1)], "relic": [snappedf(relic_offset.x, 0.1), snappedf(relic_offset.y, 0.1)], "lag": snappedf(lag, 0.1)}
	# Facing S (toward the camera) the doll stands north of the character: drawn behind.
	check(report["S"].doll[1] < 0.0 and report["N"].doll[1] > 0.0, "doll y-sorts behind facing S, in front facing N (%s)" % str([report.S, report.N]))
	evidence["offsets"] = report
	world.queue_free()
	await process_frame

func sources() -> void:
	var world_src: String = FileAccess.get_file_as_string("res://scripts/world.gd")
	check(not world_src.contains("secondary_relic_visual.follow_offset=Vector2(-54,24)"), "second relic uses the shared placement")
	var sub: String = FileAccess.get_file_as_string("res://scripts/cards/native_doll_subslot_visual.gd")
	check(sub.contains("placement.relic(delta,facing8,true)") and sub.contains("PLACEMENT.RELIC_SORT_BEHIND"), "second relic sorts behind with the mirrored placement")
	for path: String in ["res://scripts/animation/follower_motion.gd", "res://scripts/animation/relic_motion.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		check(not text.contains("Vector2(-54, 24)") and not text.contains("Vector2(48, 18)"), "no fixed screen offset in " + path.get_file())

func _run() -> void:
	pure()
	await follow()
	sources()
	print("COMPANION_PLACEMENT523_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence}))
	quit(0 if failures.is_empty() else 1)
