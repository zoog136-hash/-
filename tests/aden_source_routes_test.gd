extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var checks: int = 0
var failures: Array[String] = []
var rows: Array = []
var output: String = "user://aden-source-routes"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("ADEN_ROUTE_FAIL ",label)
func route(field: RemakePlayableField, id: String, from: Vector2, to: Vector2) -> void:
	var began: int = Time.get_ticks_usec();var path: PackedVector2Array = field.path(from,to)
	var duration: float = float(Time.get_ticks_usec()-began)/1000.0
	check(not path.is_empty(),id+" source route exists")
	var previous: Vector2 = from;var valid: bool = true
	for point: Vector2 in path:
		valid = valid and field.walkable(point) and field.line_clear(previous,point);previous=point
	check(valid,id+" every returned segment obeys exact source edges and corner policy")
	check(not path.is_empty() and path[-1].distance_to(to)<30,id+" source destination reached")
	rows.append({"id":id,"points":path.size(),"milliseconds":duration,"all_segments_source_clear":valid,
		"hierarchy":field.aden_routes.last_metrics if field.aden_routes!=null else {}})
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	world=load("res://Main.tscn").instantiate();root.add_child(world);check(QA.enter_game(world),"real Main")
	world.save_timer=-100000;world.set_process(false);world.field_population.set_process(false)
	var field: RemakePlayableField = world.field_map
	var start: Vector2 = field.cell_to_world(Vector2i(180,743))
	for item: Array in [["giran",981,740],["heine",1156,1173],["aden",1514,1190],["oren",1605,220],["elf",603,279],["woodbec",164,1124]]:
		var target: Vector2 = field.cell_to_world(field.nearest_cell(field.cell_to_world(Vector2i(item[1],item[2]))))
		route(field,str(item[0]),start,target)
	for region: Dictionary in field.data.monster_spawn:
		if str(region.get("mode",""))!="dense":continue
		var a: Array = region.rect
		var center := Vector2(float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5)
		var target: Vector2 = field.cell_to_world(field.nearest_cell(center))
		route(field,"auto_"+str(region.id),world.player.global_position,target)
	# Blocked and out-of-bounds destinations must not fabricate paths.
	check(field.path(start,Vector2.INF).is_empty(),"non-finite destination rejected")
	var report: Dictionary = {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"routes":rows,
		"continuous_end_to_end_walk":"NOT_RUN","scope":"actual production field long routes; every returned movement segment checked against exact source edges"}
	var file := FileAccess.open(output+"/runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ADEN_ROUTE_RESULT ",JSON.stringify(report));world.queue_free();quit(0 if failures.is_empty() else 1)
