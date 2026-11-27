extends SceneTree

const MONSTER := preload("res://scenes/Monster.tscn")
const SOURCE := preload("res://scripts/skills/player_skills523.gd")

class FieldProbe extends Node2D:
	var player := Node2D.new()
	var monsters_root := Node2D.new()
	var sight_checks: int = 0
	var walls: Dictionary = {Vector2(4, 0):true, Vector2(30, 1):true}

	func _has_line_of_sight_world(_from: Vector2, to: Vector2) -> bool:
		sight_checks += 1
		return not walls.has(to)

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

func run() -> void:
	var field := FieldProbe.new()
	field.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(field)
	field.add_child(field.player)
	field.add_child(field.monsters_root)
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
	field.queue_free()
	await process_frame
	print("SKILL_AREA_TARGET_SCAN_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"wall_queries_before_after":counts}))
	quit(0 if failures.is_empty() else 1)
