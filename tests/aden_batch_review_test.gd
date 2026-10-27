extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("ADEN_BATCH_FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var baseline: bool=OS.get_environment("ADEN_BATCH_BASELINE")=="1"
	var output: String=OS.get_environment("ADEN_BATCH_OUTPUT")
	var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/aden_batch_review_probes.json"))
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000
	world._set_map("aden_world",false);world.portal_cooldown=100000;world.field_population.set_process(false)
	for actor: Node in world.monsters_root.get_children():actor.set_physics_process(false);actor.hide()
	await physics_frame;await physics_frame
	var field: NativePngField=world.field_map
	var measurements: Array=[]
	for row: Dictionary in probes.replace+probes.add:
		for kind: String in ["open","blocked"]:
			if not row.has(kind):continue
			var point:=Vector2(row[kind][0],row[kind][1])*6.0
			var query:=PhysicsPointQueryParameters2D.new();query.position=point;query.collision_mask=4
			var solid: bool=not world.get_world_2d().direct_space_state.intersect_point(query).is_empty()
			var walkable: bool=field.walkable(point)
			measurements.append({"id":row.id,"kind":kind,"walkable":walkable,"physics_solid":solid})
			if not baseline:
				check(walkable==(kind=="open"),str(row.id)+" grid "+kind)
				check(solid==(kind=="blocked"),str(row.id)+" physics "+kind)
	if not baseline:
		check(field.bounds==Rect2(11802,2214,72240,45708),"same world bounds")
		check(world.field_population.slots.size()==77,"same 77 population slots")
		for portal: Dictionary in field.data.portal:check(field.walkable(Vector2(portal.position[0],portal.position[1])),"portal approach "+str(portal.id))
		var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/aden_faith_png_plan.json"))
		for route: Dictionary in plan.maps.aden_world.hunting_routes:
			var entry:=Vector2(route.entry[0],route.entry[1])*6.0
			var target:=Vector2(route.exit[0],route.exit[1])*6.0
			check(not field.path(entry,target).is_empty(),str(route.id)+" entry to onward portal route")
			for portal: Dictionary in field.data.portal:
				if portal.id==route.return_portal:
					check(not field.path(entry,Vector2(portal.position[0],portal.position[1])).is_empty(),str(route.id)+" return portal route")
		check(field.walkable(Vector2(8820,4990)*6.0) and not field.walkable(Vector2(8853,5053)*6.0),"previous hut correction retained")
		for row: Dictionary in probes.captures:
			var center:=Vector2(row.center[0],row.center[1])*6.0
			var landing: Vector2=field.cell_to_world(field.nearest_cell(center))
			check(field.walkable(landing),str(row.id)+" safe relocation")
		# Sample changed sectors, not another full spawn/world suite per object.
		for id: String in field.spawn_cells:
			if not ("desert" in id or "oren" in id or "sand_worm" in id or "death_knight" in id):continue
			var cells: Array=field.spawn_cells[id]
			check(not cells.is_empty(),id+" retains spawn candidates")
			if not cells.is_empty():check(field.walkable(field.cell_to_world(cells[cells.size()/2])),id+" sample on floor")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		if DisplayServer.get_name()!="headless":
			world.player.camera.position_smoothing_enabled=false
			var renderer: NativePngRenderer=world.field_renderer;renderer.texture_pixel_budget=renderer.MAX_MOBILE_PIXELS
			for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
				root.size=dimensions
				for row: Dictionary in probes.captures:
					world.player.global_position=Vector2(row.center[0],row.center[1])*6.0;world.player.camera.force_update_scroll()
					await renderer.settle_visible();await process_frame;await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output+"/"+str(row.id)+"-"+str(dimensions.x)+".png")
		var file:=FileAccess.open(output+"/results.json",FileAccess.WRITE);file.store_string(JSON.stringify(measurements,"  "));file.close()
	print("ADEN_BATCH_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
