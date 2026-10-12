extends SceneTree
## GPU regression: magnify actual sampler wrap boundaries in both projections.
var failures: Array[String] = []
var samples: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("GPU display required"); quit(1); return
	var directory: String = "user://aden-ground-continuity"
	DirAccess.make_dir_recursive_absolute(directory)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,128)
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera2D.new()
	camera.ignore_rotation = false
	camera.zoom = Vector2(128,1)
	viewport.add_child(camera)
	var polygon := Polygon2D.new()
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/maps/aden/ground.gdshader")
	material.set_shader_parameter("terrain",load("res://assets/maps/reference_expansion_v2/terrain.png"))
	material.set_shader_parameter("atlas_grid",4.0)
	material.set_shader_parameter("material_index",1.0)
	polygon.material = material
	viewport.add_child(polygon)
	var probes: Array[Dictionary] = [
		{"name":"primary_x","at":Vector2(2580,3900),"angle":0.0},
		{"name":"primary_y","at":Vector2(3200,4300),"angle":PI/2},
		{"name":"rotated_x","at":Vector2(2966.9625,4120),"angle":atan2(-.6,.8)},
		{"name":"rotated_y","at":Vector2(2416,4390.5375),"angle":atan2(.8,.6)}]
	for probe: Dictionary in probes:
		var at: Vector2 = probe.at
		camera.position = at
		camera.rotation = float(probe.angle)
		camera.force_update_scroll()
		polygon.polygon = PackedVector2Array([at+Vector2(-300,-300),at+Vector2(300,-300),at+Vector2(300,300),at+Vector2(-300,300)])
		var row: Dictionary = {"boundary":probe.name}
		for enabled: bool in [false,true]:
			material.set_shader_parameter("continuous_ground",enabled)
			for i: int in range(3): await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = viewport.get_texture().get_image()
			var delta: float = 0.0
			for y: int in range(128):
				var a: Color = img.get_pixel(127,y)
				var b: Color = img.get_pixel(128,y)
				delta += (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/384.0
			var key: String = "after" if enabled else "before"
			row[key] = delta
			if img.save_png(directory+"/"+str(probe.name)+"-"+key+".png")!=OK: failures.append("capture "+str(probe.name))
		if float(row.after)>.002: failures.append(str(probe.name)+" residual discontinuity")
		if float(row.after)>=float(row.before)*.5: failures.append(str(probe.name)+" must halve the old jump")
		samples.append(row)
		print("ADEN_BOUNDARY ",JSON.stringify(row))
	var report: Dictionary = {"boundaries":samples,"failures":failures,"metric":"mean absolute RGB difference at adjacent pixels straddling sampler wrap; 128x horizontal magnification","display":DisplayServer.get_name()}
	var file := FileAccess.open(directory+"/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("ADEN_CONTINUITY_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
