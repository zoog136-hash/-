extends SceneTree
## Same stationary all-unreachable selection fixture before/after graph change.
const FIXTURE=preload("res://tests/qa_route_failure_field.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func stats(values: Array[float]) -> Dictionary:
	values=values.duplicate();values.sort()
	return {"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"p99":values[int(values.size()*.99)],"max":values[-1]}
func run() -> void:
	var script_path: String=OS.get_environment("TWILIGHT_ROUTE_SCRIPT")
	if script_path.is_empty():script_path="res://scripts/maps/native_png_route_graph.gd"
	var graph_script: Script=load(script_path)
	var field: NativePngField=FIXTURE.create()
	var graph: AStar2D=graph_script.new()
	var began: int=Time.get_ticks_usec()
	graph.configure(field)
	var configure_us: int=Time.get_ticks_usec()-began
	field.precise_routes=graph
	var world:=TwilightWorld.new()
	world.field_map=field
	world.player=TwilightPlayer.new()
	world.player.position=field.cell_to_world(Vector2i(12,12))
	world.monsters_root=Node2D.new()
	for i: int in range(24):
		var actor:=TwilightMonster.new()
		actor.position=field.cell_to_world(Vector2i(43+i%6,11+i/6))
		world.monsters_root.add_child(actor)
	var times: Array[float]=[]
	for frame: int in range(60):
		began=Time.get_ticks_usec()
		var selected: TwilightMonster=world._nearest_reachable_monster(99999)
		times.append(float(Time.get_ticks_usec()-began)/1000)
		if selected!=null:failures.append("disconnected target selected")
	var report: Dictionary={"scope":"stationary synthetic native-grid islands, same 24 disconnected targets and exact world selector, 60 calls; CPU microbenchmark, not whole-frame or Android","graph_script":script_path,"configure_us":configure_us,"selection_ms":stats(times),"first_selection_ms":times[0],"targets":24,"grid_cells":field.width*field.height,"graph_points":graph.get_point_count(),"failures":failures}
	var output: String=OS.get_environment("TWILIGHT_AUTO_OUTPUT")
	if not output.is_empty():
		var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print("UNREACHABLE_AUTO_RESULT ",JSON.stringify(report))
	world.player.free();world.monsters_root.free();world.free()
	quit(0 if failures.is_empty() else 1)
