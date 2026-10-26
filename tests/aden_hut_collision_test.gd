extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const PNG=preload("res://scripts/maps/native_png_registry.gd")
class Outline extends Node2D:
	var points:=PackedVector2Array()
	func _draw() -> void:
		if not points.is_empty():
			var closed:=points.duplicate();closed.append(points[0]);draw_polyline(closed,Color.RED,3.0)
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("ADEN_HUT_FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var baseline: bool=OS.get_environment("ADEN_HUT_BASELINE")=="1"
	var output: String=OS.get_environment("ADEN_HUT_OUTPUT")
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000
	world._set_map("aden_world",false);world.portal_cooldown=100000
	world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false);actor.hide()
	var field: NativePngField=world.field_map
	var yard:=Vector2(8820,4990)*6.0;var wall:=Vector2(8853,5053)*6.0
	var approach:=Vector2(8880,5053)*6.0
	var measurements: Dictionary={"baseline":baseline,"yard_walkable":field.walkable(yard),"wall_walkable":field.walkable(wall),"slots":world.field_population.slots.size(),"bounds":str(field.bounds)}
	world.player.global_position=approach
	await physics_frame;await physics_frame
	measurements["body_stopped_at_wall"]=world.player.test_move(world.player.global_transform,wall-approach)
	if not baseline:
		check(field.walkable(yard),"visually empty north yard is open")
		check(not field.walkable(wall),"visible southeast wall is solid")
		check(field.walkable(field.cell_to_world(field.nearest_cell(wall))),"old position inside corrected wall relocates to open cell")
		check(measurements.body_stopped_at_wall,"actual player body stops at southeast wall")
		check(not field.path(yard,approach).is_empty(),"yard route goes around hut")
		check(field.bounds==Rect2(11802,2214,72240,45708),"world bounds unchanged")
		for portal: Dictionary in field.data.portal:
			check(field.walkable(Vector2(portal.position[0],portal.position[1])),"portal stays walkable "+str(portal.id))
		for id: String in field.spawn_cells:
			for cell: Vector2i in field.spawn_cells[id]:
				check(field.walkable(field.cell_to_world(cell)),"spawn candidate remains walkable "+id)
		# Both regional portal endpoints remain usable through the real Main flow.
		check(world.use_field_portal("bandits_return"),"camp return portal travel")
		check(world.use_field_portal("aden_hunting_entry"),"plaza outgoing portal travel")
		world._set_map("aden_world",false);field=world.field_map
		world.field_population.set_process(false)
		for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false);actor.hide()
	if not output.is_empty() and DisplayServer.get_name()!="headless":
		DirAccess.make_dir_recursive_absolute(output)
		var outline:=Outline.new()
		for shape: Dictionary in field.data.collision:
			if shape.id=="bandit_hut":
				for p: Array in shape.points:outline.points.append(Vector2(p[0],p[1]))
		world.add_child(outline);outline.z_index=100
		world.player.global_position=Vector2(8820,4990)*6.0
		world.player.camera.position_smoothing_enabled=false;world.player.camera.offset=Vector2(0,240)
		var renderer: NativePngRenderer=world.field_renderer;renderer.texture_pixel_budget=renderer.MAX_MOBILE_PIXELS
		for size: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
			root.size=size;world.player.camera.force_update_scroll();await renderer.settle_visible();await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/hut-"+str(size.x)+".png")
		var file:=FileAccess.open(output+"/results.json",FileAccess.WRITE);file.store_string(JSON.stringify(measurements,"  "));file.close()
	print("ADEN_HUT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
