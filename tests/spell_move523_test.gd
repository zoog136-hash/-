extends SceneTree
## SpellMove executor: synthetic rows (always) and the held original archive
## (only when installed; CI has none and checks the absent-archive path).
const MOVE = preload("res://scripts/skills/spell_move523.gd")
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []
var real: Dictionary = {}

class StubPlayer extends Node2D:
	var move_speed: float = 210.0
	var equipment_move_speed_multiplier: float = 1.0
	var skill_speed_multiplier: float = 1.0
	var held: bool = false
	func is_held() -> bool: return held
	func is_stunned() -> bool: return false
	func clear_click_path() -> void: pass
class StubTarget extends Node2D:
	var dead: bool = false
	var velocity: Vector2 = Vector2.ZERO
class StubWorld extends Node:
	var player: StubPlayer = StubPlayer.new()
	var wall_x: float = 100000.0
	func _init() -> void: add_child(player)
	func _is_walkable_world(point: Vector2) -> bool: return point.x < wall_x
	func _has_line_of_sight_world(_from: Vector2, _to: Vector2) -> bool: return true

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

static func b(name: String, value: int, application: int = 0, target: int = 0, level: int = 0) -> Dictionary:
	return {"name":name, "value":value, "application":application, "target":target, "min_level":level}

static func spell(id: int, cast_range: int, target_kind: int = 11, targeting: int = 2) -> Dictionary:
	return {"ID":id, "Name":"synthetic", "CastRange":cast_range, "MinCastRange":0, "TargettingTypeID":targeting, "TargetKindID":target_kind, "TestSpell":false}

static func phases() -> Dictionary:
	var row: Dictionary = {"ID":7, "EffectSpriteID":0, "ScreenEffectID":0, "SpeedMultiplier":100, "EffectSpriteWatchTargetKind":2}
	return {"begin":row, "middle":row, "end":row}

func run_dash(world: StubWorld, runtime, move: Dictionary, target: StubTarget) -> Dictionary:
	var started: Dictionary = runtime.begin(move, target)
	var guard: int = 0
	while runtime.busy() and guard < 400:
		runtime.tick(1.0 / 60.0); guard += 1
	return started

func run() -> void:
	var world := StubWorld.new()
	root.add_child(world)
	var runtime = MOVE.new()
	runtime.configure(world)
	var cell: float = MOVE.cell_length()
	check(cell > 0, "cell length from the existing distance policy")
	# Caster dash: complete rows.
	var dash: Dictionary = MOVE.plan_from(spell(900001, 5), {"ID":1, "SpellID":900001}, phases(),
		[b("SpellMoveMultiple",5), b("CasterMoveLimitMaxRange",1), b("SpellMoveLimitPathCount",8), b("CastSpeedAlterMoveSpeedMultiplier",400), b("NextSpellClassID",900002,5,1), b("SpellMoveMultiple",9,0,0,3)])
	check(dash.ok and dash.kind == "caster_dash" and int(dash.move_cells) == 5 and int(dash.stop_cells) == 1 and int(dash.speed_percent) == 400, "complete dash plan is ready (higher-level rows ignored)")
	check((dash.unhandled as Array).has("NextSpellClassID"), "follow-up spell is reported, not executed")
	var target := StubTarget.new(); world.add_child(target)
	world.player.global_position = Vector2.ZERO; target.global_position = Vector2(5 * cell, 0)
	var started: Dictionary = run_dash(world, runtime, dash, target)
	check(started.ok and not runtime.busy() and world.player.global_position.distance_to(Vector2(4 * cell, 0)) < 1.0, "dash stops 1 cell before the target: %s" % str(world.player.global_position))
	check(is_equal_approx(float(started.event.speed), 840.0), "dash speed is 400 percent of move speed")
	check(str(runtime.last_event.get("state","")) == "arrived", "dash arrived")
	# Out of CastRange and blocked straight line reject without moving.
	world.player.global_position = Vector2.ZERO; target.global_position = Vector2(6 * cell, 0)
	check(not runtime.begin(dash, target).ok and world.player.global_position == Vector2.ZERO, "target beyond CastRange is rejected")
	target.global_position = Vector2(5 * cell, 0); world.wall_x = 2 * cell
	check(not runtime.begin(dash, target).ok and world.player.global_position == Vector2.ZERO, "blocked dash is rejected without a path engine")
	world.wall_x = 100000.0
	# Missing stop distance / speed: plan not ready, never run with a substitute.
	var partial: Dictionary = MOVE.plan_from(spell(900003, 6), {"ID":2}, phases(), [b("SpellMoveMultiple",6)])
	check(not partial.ok and (partial.missing as Array).size() == 2, "dash without stop/speed rows is not ready")
	check(not runtime.begin(partial, target).ok and world.player.global_position == Vector2.ZERO, "unready plan never moves")
	# Path count limit shorter than the move distance.
	var short: Dictionary = MOVE.plan_from(spell(900004, 8), {"ID":3}, phases(), [b("SpellMoveMultiple",8), b("CasterMoveLimitMaxRange",1), b("SpellMoveLimitPathCount",3), b("CastSpeedAlterMoveSpeedMultiplier",400)])
	target.global_position = Vector2(6 * cell, 0)
	check(not runtime.begin(short, target).ok, "SpellMoveLimitPathCount caps the dash")
	# Knockback with weapon caps.
	var knock: Dictionary = MOVE.plan_from(spell(900005, 10, 3), {"ID":4}, phases(),
		[b("TargetKnockback",1), b("SpellMoveMultiple",4), b("MaxKnockbackDistanceByWeaponType",10,22,34), b("MaxKnockbackDistanceByWeaponType",9,22,54)])
	check(knock.ok and knock.kind == "target_knockback" and int(knock.max_cells_by_weapon[54]) == 9, "knockback plan")
	world.player.global_position = Vector2.ZERO; target.global_position = Vector2(2 * cell, 0)
	check(runtime.begin(knock, target, 54).ok and target.global_position.distance_to(Vector2(6 * cell, 0)) < 1.0, "knockback pushes 4 cells")
	target.global_position = Vector2(7 * cell, 0)
	runtime.begin(knock, target, 54)
	check(target.global_position.distance_to(Vector2(9 * cell, 0)) < 1.0, "knockback capped at 9 cells for weapon 54: %s" % str(target.global_position))
	world.wall_x = 8 * cell; target.global_position = Vector2(5 * cell, 0)
	runtime.begin(knock, target, 34)
	check(target.global_position.x < 8 * cell and target.global_position.x >= 7 * cell, "knockback stops before an obstacle")
	world.wall_x = 100000.0
	# Pull to 1 cell from the caster.
	var pull: Dictionary = MOVE.plan_from(spell(900006, 8), {"ID":5}, phases(), [b("TargetMove",1), b("TargetMoveLimitCellCount",1)])
	target.global_position = Vector2(0, 7 * cell)
	check(pull.ok and runtime.begin(pull, target).ok and target.global_position.distance_to(Vector2(0, cell)) < 1.0, "pull lands 1 cell from caster")
	# PC-only target kinds and undeclared kinds stay unready.
	check(not MOVE.plan_from(spell(900007, 8, 52), {"ID":6}, phases(), [b("TargetMove",1), b("TargetMoveLimitCellCount",1)]).ok, "PC-only target is not admitted")
	check(not MOVE.plan_from(spell(900008, 8), {"ID":7}, phases(), [b("SpellMoveNode",1)]).ok, "undeclared move kind is not admitted")
	# Held caster interrupts an active dash.
	world.player.global_position = Vector2.ZERO; target.global_position = Vector2(5 * cell, 0)
	runtime.begin(dash, target); runtime.tick(1.0 / 60.0); world.player.held = true; runtime.tick(1.0 / 60.0)
	check(not runtime.busy() and str(runtime.last_event.state) == "interrupted", "hold interrupts the dash")
	world.player.held = false
	# Held original archive, when present.
	if not DEF.identity().is_empty():
		var ready: Array = []
		var by_kind: Dictionary = {}
		for row: Dictionary in DEF.rows("SpellMoveEffectSet"):
			var p: Dictionary = MOVE.plan(int(row.SpellID))
			if p.is_empty(): continue
			by_kind[str(p.kind)] = int(by_kind.get(str(p.kind), 0)) + 1
			if p.ok: ready.append(int(p.spell_id))
		real["sets"] = DEF.rows("SpellMoveEffectSet").size()
		real["effects"] = DEF.rows("SpellMoveEffect").size()
		real["ready_spells"] = ready
		real["kinds"] = by_kind
		var flash: Dictionary = MOVE.plan(69381)
		check(flash.ok and flash.kind == "caster_dash", "original flash dash plan is ready")
		world.player.global_position = Vector2(1000, 1000); target.global_position = Vector2(1000 + 5 * cell, 1000)
		var before: Vector2 = world.player.global_position
		var original: Dictionary = run_dash(world, runtime, flash, target)
		real["flash"] = {"move_cells":flash.get("move_cells"), "stop_cells":flash.get("stop_cells"), "path_limit_cells":flash.get("path_limit_cells"), "speed_percent":flash.get("speed_percent"),
			"before":str(before), "target":str(target.global_position), "after":str(world.player.global_position), "speed":original.get("event",{}).get("speed"), "unhandled":flash.get("unhandled")}
		check(original.ok and world.player.global_position.distance_to(target.global_position) <= float(flash.stop_cells) * cell + 1.0, "original flash moves next to the target")
		for id: int in [48601, 65478, 57004, 96242, 118114, 119742, 17514, 67011, 113882]:
			var p: Dictionary = MOVE.plan(id)
			real[str(id)] = {"ok":p.get("ok"), "kind":p.get("kind"), "missing":p.get("missing"), "unhandled":p.get("unhandled")}
		var charging: Dictionary = MOVE.plan(67011)
		check(charging.kind == "target_knockback" and not charging.ok, "charging shot is knockback but PC-only")
	else:
		check(MOVE.plan(69381).is_empty(), "absent archive yields no plan")
		real["archive"] = "absent"
	print("SPELL_MOVE523_RESULT ", JSON.stringify({"checks":checks, "failures":failures, "real":real}))
	quit(0 if failures.is_empty() else 1)
