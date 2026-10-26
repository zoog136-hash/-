extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("MINIMAP_BATCH_FAIL ",label)
func run() -> void:
	if DisplayServer.get_name()=="headless":print("MINIMAP_BATCH_SKIP: real renderer required for GPU instance readback");quit();return
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000
	world._set_map("escaros_01",false)
	await process_frame;await RenderingServer.frame_post_draw
	var expected_markers: Array[Vector2]=[]
	for spawn: Dictionary in world.field_map.data.monster_spawn:
		if str(spawn.get("mode",""))!="boss" or (not spawn.has("polygon") and not spawn.has("polygons")):continue
		var cells: Array=world.field_map.spawn_cells.get(str(spawn.id),[])
		var stride: int=maxi(1,ceili(float(cells.size())/480.0))
		for i: int in range(0,cells.size(),stride):expected_markers.append(world.field_minimap._point(world.field_map.cell_to_world(cells[i])))
	check(world.field_minimap.boss_region_mesh.instance_count==expected_markers.size(),"batched minimap keeps every boss floor marker")
	for i: int in range(expected_markers.size()):check(world.field_minimap.boss_region_mesh.get_instance_transform_2d(i).origin.distance_to(expected_markers[i])<.001,"minimap marker position "+str(i))
	print("MINIMAP_BATCH_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
