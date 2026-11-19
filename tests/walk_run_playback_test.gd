extends SceneTree
## User report 2026-11-19 19:04 (phone recording, elf in 거울의 숲):
## "이젠 왜 뛰지 않고 걷는거지? 이동속도에 비해서 다리는 또 왜저래?? 원본에 재생속도 없어?"
##
## Original 523: the elf walk (15282) and its SpriteRun run actor (15284) are
## both 8 frames x 2 ticks = PlayerDelay 16 at PlayerFrameRate 36 (0.444 s per
## loop) and each loop travels exactly one cell (48.8 / 46.8 px sideways, 24.9 /
## 23.9 px up). The run actor is switched on by RunSpritePoint (BonusType 168,
## RunSpriteLevel 394), which only the 1단/2단/3단 acceleration buffs grant.
## Since #642 the old 210 px/s "run" threshold could never be reached, so the
## run actor was never shown. User decision: walk normally, run from stage 1.
##
## Always (CI): RunSpritePoint combination, the run/walk decision and its
## TWILIGHT approximation, playback speed proportional to the move speed, the
## field's one-cell steps, and the root-motion snap on the measured 523 frames.
## With --source523-pack=<root> (actual Main, elf on the 523 Land): walk at the
## base speed, run actor 15284 when accelerated (multiplier or an applied
## 초록 물약 BuffClass), walk again under the -1 "강제 걷기" debuff, and one loop
## per cell at both speeds.
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
const PLAYER = preload("res://scripts/player.gd")
const RUN_POINTS = preload("res://scripts/animation/source_run_points.gd")
const SOURCE_WALK = preload("res://scripts/maps/source_walk_speed.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const HOST = preload("res://scripts/maps/current523_host.gd")
const PACK = preload("res://scripts/boot/source523_pack.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

class FakeCoordinates extends RefCounted:
	var valid: bool = true
	var basis_x: Vector2 = Vector2(24, 12)
	var basis_y: Vector2 = Vector2(-24, 12)

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("WALK_RUN_PLAYBACK_FAIL: ", label)
	return condition

func _initialize() -> void: _run.call_deferred()

func _pack_root() -> String:
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source523-pack="): return value.trim_prefix("--source523-pack=")
	return ""

func _residual(points: Array[Vector2], slope: Vector2) -> float:
	# Sweep of the cancelled anchor over frames 1..n-1 (frame 0 is the odd one).
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k: int in range(1, points.size()):
		var p: Vector2 = points[k] - slope * float(k)
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return (hi - lo).length()

func _run() -> void:
	# 1) The field's eight one-cell steps.
	var steps: Array[Vector2] = SOURCE_WALK.cell_steps(FakeCoordinates.new())
	evidence["cell_steps"] = str(steps)
	check(steps.size() == 8 and Vector2(48, 0) in steps and Vector2(0, 24) in steps and Vector2(-24, -12) in steps, "cell steps: sideways 48, up/down 24, grid axes 24x12 %s" % str(steps))
	check(SOURCE_WALK.cell_steps(null).is_empty(), "no field, no steps")

	# 2) Root-motion snap on the measured cooked anchors of 523 elf 15282 walk,
	# source direction 0 (frame 0's box sits ~20 px off the line).
	var dir0: Array[Vector2] = [Vector2(20.5, -10), Vector2(0, -11), Vector2(-4.5, -14), Vector2(-7, -14.5), Vector2(-8.5, -15.5), Vector2(-12.5, -16.5), Vector2(-16.5, -20), Vector2(-19.5, -20.5)]
	var fitted: Vector2 = PREVIEW.fit_root_motion(dir0)
	var snapped: Vector2 = PREVIEW.snap_root_motion(fitted, dir0.size(), steps)
	evidence["dir0_fit_travel"] = str(fitted * 8.0)
	evidence["dir0_snapped_travel"] = str(snapped * 8.0)
	check((fitted * 8.0).distance_to(Vector2(-24, -12)) > 8.0, "the least-squares travel alone is off by the odd frame (%s)" % str(fitted * 8.0))
	check((snapped * 8.0).is_equal_approx(Vector2(-24, -12)), "the travel snaps to exactly one grid-axis cell (%s)" % str(snapped * 8.0))
	evidence["dir0_residual_px"] = [snappedf(_residual(dir0, fitted), 0.01), snappedf(_residual(dir0, snapped), 0.01)]
	check(_residual(dir0, snapped) < _residual(dir0, fitted) and _residual(dir0, snapped) <= 6.0, "the cancelled walk sways less (%s)" % str(evidence["dir0_residual_px"]))
	# Sideways (direction 3, measured): already one cell, stays one cell.
	var dir3: Array[Vector2] = [Vector2(52.5, -10.5), Vector2(58.5, -10.5), Vector2(65, -10.5), Vector2(71, -10), Vector2(76.5, -10.5), Vector2(83, -10), Vector2(89.5, -10.5), Vector2(95, -10.5)]
	var side: Vector2 = PREVIEW.snap_root_motion(PREVIEW.fit_root_motion(dir3), 8, steps)
	check((side * 8.0).is_equal_approx(Vector2(48, 0)), "sideways walk: one 48 px cell per loop (%s)" % str(side * 8.0))
	# Far from any cell step, or no steps known: the fit is kept.
	check(PREVIEW.snap_root_motion(Vector2(1.5, 0), 8, steps) == Vector2(1.5, 0), "a 12 px travel is not forced to a cell")
	check(PREVIEW.snap_root_motion(fitted, 8, [] as Array[Vector2]) == fitted, "no field steps: least-squares fit unchanged")
	check(PREVIEW.snap_root_motion(Vector2.ZERO, 8, steps) == Vector2.ZERO, "an in-place cycle stays in place")

	# 3) RunSpritePoint combination (rows as in the original tables).
	RUN_POINTS._memo_generation = DEF.cache_generation()
	RUN_POINTS._memo = {
		40: {"levels": {1: 1}, "flat": 0},      # [가속] 1단 (초록 물약)
		10: {"levels": {1: 1}, "flat": 0},      # [가속] 1단 (헤이스트)
		41: {"levels": {2: 1}, "flat": 0},      # 2단 (용기의 물약)
		237: {"levels": {3: 1}, "flat": 0},     # 3단 (드래곤의 진주)
		84031: {"levels": {}, "flat": -1},      # [Test] 강제 걷기 만들기 디버프
		999: {}}                                # no RunSpritePoint
	check(RUN_POINTS.points([]) == {"known": false, "points": 0}, "no buffs: unknown")
	check(RUN_POINTS.points([999]) == {"known": false, "points": 0}, "a buff without RunSpritePoint: unknown")
	check(RUN_POINTS.points([40]) == {"known": true, "points": 1}, "초록 물약: stage 1")
	check(RUN_POINTS.points([40, 10]) == {"known": true, "points": 1}, "two stage-1 buffs do not stack")
	check(RUN_POINTS.points([40, 41, 237]) == {"known": true, "points": 3}, "1단+2단+3단: 3 points")
	check(RUN_POINTS.points([40, 84031]) == {"known": true, "points": 0}, "강제 걷기 debuff cancels one point")
	check(RUN_POINTS.record_buff_class_id({"source_buff_class": {"ID": 41}}) == 41 and RUN_POINTS.record_buff_class_id({"buff_class_id": 237}) == 237 and RUN_POINTS.record_buff_class_id({"speed": 1.2}) == 0, "buff records name their original BuffClass")
	var fake := FakeWorld.new()
	fake.active_item_buffs = {"초록 물약": {"source_buff_class": {"ID": 40}, "move_speed": 25}}
	check(RUN_POINTS.from_world(fake) == {"known": true, "points": 1}, "applied item buff: stage 1")
	fake.active_item_buffs = {}
	fake.active_skill_buffs = {"헤이스트": {"buff_class_id": 10}}
	check(RUN_POINTS.from_world(fake) == {"known": true, "points": 1}, "applied skill buff: stage 1")
	RUN_POINTS._memo = {}
	RUN_POINTS._memo_generation = -1

	# 4) Decision and playback speed.
	check(not bool(PLAYER.source_run_decision({"known": false}, 1.0).run), "base speed, no acceleration: walk")
	check(bool(PLAYER.source_run_decision({"known": false}, 1.25).run), "TWILIGHT 근사: faster than the base walk counts as accelerated")
	check(not bool(PLAYER.source_run_decision({"known": false}, 0.8).run), "slowed (weight): walk")
	check(bool(PLAYER.source_run_decision({"known": true, "points": 1}, 1.0).run), "RunSpritePoint 1 runs even before its speed applies")
	check(not bool(PLAYER.source_run_decision({"known": true, "points": 0}, 1.33).run), "강제 걷기: the applied points win over the multiplier")
	SOURCE_WALK.reset()
	var cycle: float = 16.0 / 36.0
	for multiplier: float in [0.5, 1.0, 1.25, 1.33, 2.0]:
		# One loop (one cell of stride) per cell step at the actual speed.
		var scale: float = PLAYER.walk_clock_scale(cycle, multiplier)
		check(is_equal_approx(scale, multiplier), "playback x%.2f at move speed x%.2f" % [scale, multiplier])
		check(is_equal_approx(cycle / scale, SOURCE_WALK.step_seconds(multiplier)), "x%.2f: one loop takes one cell step (%.3f s)" % [multiplier, cycle / scale])

	if not _pack_root().is_empty(): await _main_checks()
	var result := {"checks": checks, "failures": failures, "evidence": evidence}
	print("WALK_RUN_PLAYBACK_RESULT ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

class FakeWorld extends RefCounted:
	var active_item_buffs: Dictionary = {}
	var active_skill_buffs: Dictionary = {}

func _main_checks() -> void:
	preload("res://scripts/animation/source_sp2_compositor.gd").screen_copy_available = false
	var base: String = _pack_root()
	var read: Dictionary = PACK.read_descriptor(base.path_join("source523_pack.json"))
	PACK.apply(PACK.selections(base, read.descriptor, PACK.read_addons(base)))
	HOST.refresh()
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for i: int in 1500:
		if bool(world.get("current523_aden_play_active")): break
		await process_frame
	QA.enter_game(world, "요정")
	world.set_source_character_gender(2)
	var p: Node2D = world.player
	for i: int in 900:
		if p.original_source_preview.installed(): break
		await process_frame
	if not check(p.original_source_preview.installed(), "the elf's original actor is drawn"): return
	for i: int in 30: await process_frame
	p.set_auto_enabled(false)
	var pv = p.original_source_preview
	var saved_items: Dictionary = world.active_item_buffs.duplicate(true)
	var cases: Array = [
		{"name": "base", "mult": 1.0, "buffs": {}, "role": "walk", "actor": 15282},
		{"name": "x1.25", "mult": 1.25, "buffs": {}, "role": "run", "actor": 15284},
		{"name": "초록 물약", "mult": 1.0, "buffs": {"zz_test_green": {"source_buff_class": {"ID": 40}, "remaining": 600.0, "duration": 600.0}}, "role": "run", "actor": 15284},
		{"name": "강제 걷기", "mult": 1.25, "buffs": {"zz_test_walk": {"source_buff_class": {"ID": 84031}, "remaining": 600.0, "duration": 600.0}}, "role": "walk", "actor": 15282}]
	var rows: Dictionary = {}
	for c: Dictionary in cases:
		p.set_skill_speed_multiplier(float(c.mult))
		world.active_item_buffs = saved_items.duplicate(true)
		world.active_item_buffs.merge(c.buffs, true)
		p.set_touch_vector(Vector2.RIGHT)
		var roles: Dictionary = {}
		var actors: Dictionary = {}
		var advanced: int = 0
		var distance: float = 0.0
		var last_frame: int = -1
		var last_pos: Vector2 = p.global_position
		for i: int in 45:
			await physics_frame
			if i < 6 or pv.source_role() not in ["walk", "run"]:
				last_frame = pv.last_source_frame
				last_pos = p.global_position
				continue
			roles[pv.source_role()] = true
			actors[int(pv._playback_tracks.get(pv.source_role(), {}).get("source_sprite_id", -1))] = true
			advanced += posmod(pv.last_source_frame - last_frame, 8)
			distance += p.global_position.distance_to(last_pos)
			last_frame = pv.last_source_frame
			last_pos = p.global_position
		p.set_touch_vector(Vector2.ZERO)
		for i: int in 8: await physics_frame
		var per_loop: float = distance / (float(advanced) / 8.0) if advanced > 0 else -1.0
		rows[c.name] = {"roles": roles.keys(), "actors": actors.keys(), "status": p.source_run_status.duplicate(), "px_per_loop": snappedf(per_loop, 0.1), "clock": snappedf(p._walk_clock_scale, 0.001)}
		check(roles.keys() == [c.role], "%s: %s shown (%s)" % [c.name, c.role, str(roles.keys())])
		check(actors.keys() == [c.actor], "%s: original actor %d (%s)" % [c.name, c.actor, str(actors.keys())])
		check(per_loop >= 40.0 and per_loop <= 56.0, "%s: one loop per 48 px sideways cell (%.1f px)" % [c.name, per_loop])
	world.active_item_buffs = saved_items
	p.set_skill_speed_multiplier(1.0)
	evidence["main_cases"] = rows
	check(rows.get("x1.25", {}).get("clock", 0.0) > 1.2 and rows.get("base", {}).get("clock", 0.0) < 1.05, "playback follows the move speed (%s / %s)" % [str(rows.get("base", {}).get("clock")), str(rows.get("x1.25", {}).get("clock"))])
