extends SceneTree

const MONSTER := preload("res://scenes/Monster.tscn")
const SOURCE := preload("res://scripts/skills/player_skills523.gd")
const SOURCE_FIELD_FIXTURE := preload("res://tests/current523_aden_source_field_test.gd")
const HITCH := preload("res://scripts/boot/frame_hitch_log.gd")

class FieldProbe extends Node2D:
	var player := Node2D.new()
	var monsters_root := Node2D.new()
	var sight_checks: int = 0
	var walls: Dictionary = {Vector2(4, 0):true, Vector2(30, 1):true}
	var navigation: OriginalPlayableField

	func _has_line_of_sight_world(from: Vector2, to: Vector2) -> bool:
		sight_checks += 1
		if navigation != null: return navigation.line_clear(from, to)
		return not walls.has(to)

class StaticFieldProbe extends FieldProbe:
	var field_map := RefCounted.new()
	var combat_generation: int = 0
	var epoch: int = 1

	func _static_auto_route_epoch() -> int: return epoch

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("SKILL_AREA_TARGET_SCAN_FAIL ", label)

func spawn(field: FieldProbe, position: Vector2, hidden: bool = false, dead: bool = false) -> TwilightMonster:
	var monster: TwilightMonster = MONSTER.instantiate()
	monster.position = position
	field.monsters_root.add_child(monster)
	monster.concealed523 = hidden
	monster.dead = dead
	return monster

## Reference traversal: test the original wall-query-first implementation
## against the same visible, blocked, dead and out-of-range candidates.
func previous_targets(field: FieldProbe, skill: Dictionary, primary: TwilightMonster) -> Array[TwilightMonster]:
	var targets: Array[TwilightMonster] = []
	var origin: Vector2 = field.player.global_position
	var center: Vector2 = primary.global_position if is_instance_valid(primary) else origin
	for child: Node in field.monsters_root.get_children():
		if not child is TwilightMonster or child.dead or not SOURCE.target_allowed(skill, child): continue
		if not field._has_line_of_sight_world(origin, child.global_position): continue
		var distance: float = child.global_position.distance_to(center)
		if skill.shape == "line":
			var end: Vector2 = origin + origin.direction_to(center) * float(skill.range)
			distance = Geometry2D.get_closest_point_to_segment(child.global_position, origin, end).distance_to(child.global_position)
		if distance <= float(skill.radius): targets.append(child)
	targets.sort_custom(func(a: TwilightMonster, b: TwilightMonster) -> bool:
		return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	if targets.size() > int(skill.targets): targets.resize(int(skill.targets))
	return targets

func make_field() -> FieldProbe:
	var field := FieldProbe.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(field)
	field.add_child(field.player)
	field.add_child(field.monsters_root)
	return field

func check_stationary_auto_misses() -> void:
	var probe := StaticFieldProbe.new()
	probe.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(probe)
	probe.add_child(probe.player)
	probe.add_child(probe.monsters_root)
	probe.walls = {Vector2(4,0):true, Vector2(5,0):true}
	var blocked: TwilightMonster = spawn(probe, Vector2(4,0))
	spawn(probe, Vector2(5,0))
	var distant: TwilightMonster = spawn(probe, Vector2(200,0))
	var service := TwilightOriginalSkillService.new()
	service.world = probe
	var skill: Dictionary = {"mode":"attack","shape":"self_circle","radius":10.0,"range":40.0,
		"targets":2,"source523":{"target_kind":"Enemy"}}
	HITCH._clear_pending()
	var all_missed: bool = true
	for _pulse: int in range(20):
		all_missed = not service._has_area_target(skill) and all_missed
	check(all_missed and probe.sight_checks == 2 and HITCH._counters.get("skill.area_auto_scans",0) == 1,
		"a stationary blocked area scans the list once across 20 probes")
	distant.position = Vector2(220,0)
	check(not service._has_area_target(skill) and probe.sight_checks == 2, "out-of-range movement leaves the proof intact")
	distant.position = Vector2(10,0)
	check(service._has_area_target(skill) and distant.auto_area_miss_observer == null,
		"an actor on the exact radius invalidates the miss and resumes the live route")
	distant.free()
	check(not service._has_area_target(skill), "a new miss can be recorded after removal")
	var joined: TwilightMonster = spawn(probe, Vector2(6,0))
	check(service._has_area_target(skill), "a new child at a reachable position invalidates the miss")
	joined.free()
	check(not service._has_area_target(skill), "blocked original candidates remain")
	probe.monsters_root.position = Vector2(1,0)
	check(service._has_area_target(skill), "a parent transform invalidates the previous world endpoints")
	probe.monsters_root.position = Vector2.ZERO
	check(not service._has_area_target(skill), "the same blockage is tested after moving the parent back")
	var last_sight: int = probe.sight_checks
	probe.player.position = Vector2(0,1)
	check(not service._has_area_target(skill) and probe.sight_checks == last_sight+2, "caster world position is part of the proof")
	probe.walls.erase(blocked.position)
	probe.epoch += 1
	check(service._has_area_target(skill), "new terrain admission drops a cached wall refusal")
	blocked.concealed523 = true
	check(not service._has_area_target(skill), "concealment still refuses an immobile actor")
	blocked.concealed523 = false
	check(service._has_area_target(skill), "removing concealment does not need movement to enable AUTO")
	blocked.dead = true
	check(not service._has_area_target(skill), "a dead pooled actor stays ineligible")
	blocked.dead = false
	check(service._has_area_target(skill), "the next life at the same position is seen")
	probe.epoch = 0
	probe.walls[blocked.position] = true
	check(not service._has_area_target(skill), "unversioned terrain uses the live wall")
	probe.walls.erase(blocked.position)
	check(service._has_area_target(skill), "unversioned terrain sees an opened wall immediately")
	probe.epoch += 1
	probe.walls[blocked.position] = true
	check(not service._has_area_target(skill) and blocked.auto_area_miss_observer != null, "verified blocked geometry arms movement notifications")
	probe.monsters_root.free()
	check(service._auto_area_misses._root == null, "releasing the actor root also releases the miss cache")
	probe.queue_free()

func run() -> void:
	var field: FieldProbe = make_field()
	field.monsters_root.add_child(Node2D.new())
	var active: TwilightMonster = spawn(field, Vector2(30, 0))
	for position: Vector2 in [Vector2(4,0), Vector2(10,0), Vector2(-10,0), Vector2(4,3), Vector2(30,1), Vector2(28,2), Vector2(60,0), Vector2(40,2)]:
		spawn(field, position)
	spawn(field, Vector2(2, 0), true)
	spawn(field, Vector2(3, 0), false, true)
	for index: int in range(100): spawn(field, Vector2(200 + index, 100 + index))
	var service := TwilightOriginalSkillService.new()
	service.world = field
	var counts: Dictionary = {}
	for shape: String in ["self_circle", "area", "line"]:
		var primary: TwilightMonster = null if shape == "self_circle" else active
		var skill: Dictionary = {"shape":shape,"radius":2.0 if shape == "line" else 10.0,"range":40.0,"targets":2,"source523":{"target_kind":"Enemy"}}
		field.sight_checks = 0
		var previous: Array[TwilightMonster] = previous_targets(field, skill, primary)
		var baseline: int = field.sight_checks
		field.sight_checks = 0
		check(service.targets(skill, primary) == previous and previous.size() == 2, shape + " keeps the same ordered, capped targets")
		check(field.sight_checks > 2 and field.sight_checks < 10 and baseline > 100, shape + " wall checks only inside the original range")
		counts[shape] = [baseline, field.sight_checks]
	field.sight_checks = 0
	check(service.targets({"shape":"single","source523":{"target_kind":"Enemy"}}, active) == [active] and field.sight_checks == 0,
		"the existing targeted single branch stays direct")
	var auto_skill: Dictionary = {"shape":"self_circle","radius":10.0,"range":40.0,"targets":2,"source523":{"target_kind":"Enemy"}}
	field.sight_checks = 0
	check(service._has_area_target(auto_skill) and field.sight_checks == 2,
		"auto probe skips the first blocked candidate and stops at the first visible one")
	field.walls.merge({Vector2(10,0):true,Vector2(-10,0):true,Vector2(4,3):true}, true)
	check(not service._has_area_target(auto_skill) and service.targets(auto_skill, null).is_empty(),
		"auto probe rejects a blocked, hidden, dead or distant crowd")
	field.walls.clear()
	auto_skill.targets = 0
	field.sight_checks = 0
	check(not service._has_area_target(auto_skill) and field.sight_checks == 0,
		"an empty target limit never admits an automatic cast")
	var forward_skill: Dictionary = {"mode":"attack","shape":"line","radius":2.0,"range":32.0,"targets":6}
	check(active in service.targets(forward_skill, null, Vector2.RIGHT)
		and active not in service.targets(forward_skill, null, Vector2.LEFT),
		"target-free line uses facing without finding an anchor monster")
	forward_skill.shape = "cone"
	var cone_targets: Array[TwilightMonster] = service.targets(forward_skill, null, Vector2.RIGHT)
	check(active in cone_targets and cone_targets.all(func(actor: TwilightMonster) -> bool: return actor.global_position.x >= 0.0),
		"target-free cone keeps its declared forward range")
	check_stationary_auto_misses()
	var timing: Dictionary = s32_benchmark() if "--benchmark" in OS.get_cmdline_user_args() else {}
	field.queue_free()
	await process_frame
	print("SKILL_AREA_TARGET_SCAN_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"wall_queries_before_after":counts,"synthetic_s32":timing}))
	quit(0 if failures.is_empty() else 1)

## Warm CPU comparison through the production S32 line traversal, using the
## existing in-memory synthetic terrain fixture. No disk/GPU time is sampled.
func s32_benchmark() -> Dictionary:
	var probe: FieldProbe = make_field()
	var field := SOURCE_FIELD_FIXTURE.MemoryField.new()
	field.prepare({})
	probe.navigation = field
	probe.player.global_position = field.cell_to_world(Vector2i(24, 24))
	for y: int in range(20, 28): field.attribute(Vector2i(27, y), 1, 1)
	for i: int in range(96):
		spawn(probe, field.cell_to_world(Vector2i(43 + (i * 7) % 76, 5 + (i * 13) % 49)))
	for cell: Vector2i in [Vector2i(28,24),Vector2i(26,24),Vector2i(22,24),Vector2i(24,21),Vector2i(25,25),Vector2i(23,25),Vector2i(25,26)]:
		spawn(probe, field.cell_to_world(cell))
	var skill: Dictionary = {"shape":"self_circle","radius":160.0,"range":240.0,"targets":5,"source523":{"target_kind":"Enemy"}}
	var service := TwilightOriginalSkillService.new()
	service.world = probe
	var original: Callable = previous_targets.bind(probe, skill, null)
	var current: Callable = service.targets.bind(skill, null)
	var auto_probe: Callable = service._has_area_target.bind(skill)
	var wanted: Array = original.call()
	check(wanted.size() == 5 and wanted == current.call() and auto_probe.call(), "production S32 wall traversal keeps the ordered targets")
	var rounds: Array[Dictionary] = []
	for index: int in 3:
		var before: Dictionary
		var after: Dictionary
		if index % 2 == 0:
			before = time_queries(probe, original)
			after = time_queries(probe, current)
		else:
			after = time_queries(probe, current)
			before = time_queries(probe, original)
		rounds.append({"previous":before,"impact":after,"auto_probe":time_queries(probe, auto_probe)})
	check(int(rounds[0].previous.sight_per_query) > 96 and int(rounds[0].impact.sight_per_query) < 12 and int(rounds[0].auto_probe.sight_per_query) == 2,
		"production S32 collision runs only for actual candidates, and auto stops after the first valid target")
	probe.queue_free()
	field.close()
	return {"queries_per_round":60,"rounds":rounds}

func time_queries(probe: FieldProbe, query: Callable) -> Dictionary:
	var durations := PackedInt64Array()
	probe.sight_checks = 0
	for index: int in 60:
		var started: int = Time.get_ticks_usec()
		query.call()
		durations.append(Time.get_ticks_usec() - started)
	durations.sort()
	return {"median_us":durations[30],"p95_us":durations[56],"max_us":durations[59],"sight_per_query":float(probe.sight_checks)/60.0}
