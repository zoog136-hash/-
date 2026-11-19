extends SceneTree
## A source Land move with an empty / short / bad landing box is refused with a
## reason before anything is indexed, and the controller is not left "busy":
## the next valid move is still judged (current523_aden_play_controller
## _enter_source_land used to read bounds[0] before validation; the script
## error left _source_travel_busy set and blocked every later map move).
const CONTROLLER = preload("res://scripts/maps/current523_aden_play_controller.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("SOURCE_LAND_BOUNDS_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for bad: Array in [[],[1],[1,2,3],[1,2,3,4,5],["1",2,3,4],[1.5,2,3,4],[-1,2,3,4],[5,2,3,4],[1,5,3,4],[INF,2,3,4]]:
		check(not CONTROLLER.valid_landing_bounds(bad), "bad landing box %s is refused" % str(bad))
	for good: Array in [[10,20,10,20],[10,20,30,40],[0,0,0,0],[10.0,20.0,30.0,40.0]]:
		check(CONTROLLER.valid_landing_bounds(good), "landing box %s is accepted" % str(good))
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main entry")
	for frame: int in range(20): await process_frame
	var controller: RefCounted = world._aden_play_controller()
	evidence["source_active"] = controller != null and bool(controller.get("active")) and bool(controller.get("source_owned"))
	if evidence.source_active:
		var map_before: String = str(world.active_map_id)
		var first: Dictionary = world.content523_enter_land(25,[],[])
		check(not first.ok and str(first.reason).begins_with("도착 범위 오류"), "an empty box is refused with its reason (%s)" % str(first))
		check(not bool(controller.get("_source_travel_busy")) and str(world.active_map_id) == map_before, "the refusal leaves no busy move and the map unchanged")
		var second: Dictionary = world.content523_enter_land(25,[1,2],[])
		check(not second.ok and not str(second.reason).contains("사용할 수 없습니다"), "the next move is still judged, not blocked (%s)" % str(second))
	world.queue_free()
	await process_frame
	print("SOURCE_LAND_BOUNDS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
