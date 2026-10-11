extends SceneTree
## Targeted shoreline geometry and rendered bends; full gameplay lives in
## aden_terrain_polish_test.gd and is not repeated here.
var failures: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("SHORELINE_FAIL: "+label)
func area(points: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i: int in range(points.size()): sum+=points[i].cross(points[(i+1)%points.size()])
	return absf(sum)*.5
func run() -> void:
	var directory: String = "user://aden-shoreline"
	DirAccess.make_dir_recursive_absolute(directory)
	check(DisplayServer.get_name()!="headless","real OpenGL viewport")
	seed(8401)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.hud.complete_class_selection(); world.hud._close_workspace()
	world._set_map("aden_world",false)
	world.save_timer=-10000
	world.set_process(false); world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	var river_layer: Node = world.field_renderer.terrain_root.get_node("Water")
	var rivers: Array[Polygon2D] = []
	for node: Node in river_layer.get_children():
		if node is Polygon2D: rivers.append(node)
	check(rivers.size()==world.field_map.data.water.size(),"all three original river sections present")
	for index: int in range(rivers.size()):
		var river: Polygon2D = rivers[index]
		var original := PackedVector2Array()
		for p: Array in world.field_map.data.water[index].polygon: original.append(Vector2(p[0],p[1]))
		check(river.polygon==original,"exact original bank vertices "+str(index))
		check((river.material as ShaderMaterial).shader.resource_path=="res://assets/maps/aden/river_depth.gdshader","depth shader loaded "+str(index))
		var triangles_area: float = 0.0
		for face: PackedInt32Array in river.polygons:
			triangles_area+=area(PackedVector2Array([original[face[0]],original[face[1]],original[face[2]]]))
		check(absf(triangles_area-area(original))<2.0,"triangle strip covers original area without overlap "+str(index))
		check(river.uv.size()==original.size(),"bank-aligned depth coordinates "+str(index))
	for bridge: Dictionary in world.field_map.data.bridges:
		var a: Array = bridge.rect
		var center := Vector2(float(a[0])+float(a[2])*.5,float(a[1])+float(a[3])*.5)
		check(world.field_map.walkable(center),str(bridge.id)+" center remains walkable")
		check(world.field_map.line_clear(center-Vector2(450,0),center+Vector2(450,0)),str(bridge.id)+" original crossing remains clear")
		check(not world.field_map.walkable(center+Vector2(0,200)),str(bridge.id)+" adjacent water remains blocked")
	var scenes: Dictionary = {"01-north-bridge":Vector2(6180,3000),"02-south-bridge":Vector2(5700,5700),"03-curved-bank":Vector2(5520,4370)}
	for title: String in scenes:
		world.player.global_position=world.field_map.cell_to_world(world.field_map.nearest_cell(scenes[title]))
		world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		world.field_renderer.refresh_visible()
		for i: int in range(6): await physics_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory+"/"+title+".png")==OK,"capture "+title)
		print("SHORELINE_CAPTURE ",title," at ",world.player.global_position)
	var report: Dictionary = {"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"scope":"three original river outlines/area, two bridge clearance and blocked adjacent water, three actual rendered views","original_restored":false}
	var file := FileAccess.open(directory+"/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("SHORELINE_RESULT ",JSON.stringify(report))
	world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
