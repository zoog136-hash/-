extends SceneTree
## Diagnostic views of production Main.tscn, clearly separate from play tests.
## --legacy-map-layouts --cameras=<new/captures.json> makes exact-camera pairs.
var world: TwilightWorld
var output: String = "user://map-captures"
var cameras: Dictionary = {}
var reports: Dictionary = {}
var failures: Array[String] = []
var selected_maps: PackedStringArray = []

func _initialize() -> void: call_deferred("run")
func frames(n: int) -> void:
	for i: int in range(n): await process_frame

func capture(map_id: String,kind: String) -> void:
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	await frames(3)
	await RenderingServer.frame_post_draw
	var name: String = map_id+"-"+kind+".png"
	var img: Image = root.get_texture().get_image()
	if img==null or img.save_png(output+"/"+name)!=OK: failures.append(name)
	reports[map_id].images.append({"file":name,"kind":"MAIN_PAUSED_2D_RENDER_ONLY",
		"camera_center":[world.player.camera.get_screen_center_position().x,world.player.camera.get_screen_center_position().y],
		"zoom":world.player.camera.zoom.x,"viewport":[root.size.x,root.size.y]})

func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("CAPTURE_REQUIRES_REAL_RENDERER");quit(1);return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
		if arg.begins_with("--cameras="): cameras=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--cameras="))).maps
		if arg.begins_with("--maps="): selected_maps=arg.trim_prefix("--maps=").split(",",false)
	DirAccess.make_dir_recursive_absolute(output)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	await frames(3)
	world.hud.complete_class_selection();world.hud._close_workspace()
	world.save_timer=-100000
	world.set_process(false)
	world.player.set_physics_process(false)
	world.player.camera.position_smoothing_enabled=false
	for record: Dictionary in world.maps:
		var id: String=record.id
		if not selected_maps.is_empty() and id not in selected_maps: continue
		world._set_map(id,false)
		world.field_population.set_process(false)
		for mob: Node in world.monsters_root.get_children(): mob.set_physics_process(false)
		var field: PlayableField=world.field_map
		if field==null: failures.append(id+" missing field");continue
		var entry: Vector2=world.player.global_position
		reports[id]={"remake_topology":field is RemakePlayableField,"images":[],
			"layout_revision":int(field.data.get("layout_revision",0)),
			"technical_complete":false,"faithful_complete":false,"diagnostic_only":true,
			"entry":[entry.x,entry.y],"comparison_alignment":"SAME_CANVAS_PIXELS_NOT_CURRENT_M_CALIBRATION"}
		world.player.hide();world.hud.hide();world.field_minimap.hide();world.monsters_root.hide()
		world.player.global_position=field.bounds.get_center()
		world.player.camera.position=Vector2.ZERO
		world.player.camera.zoom=Vector2.ONE*minf(1280.0/field.bounds.size.x,720.0/field.bounds.size.y)*0.96
		await capture(id,"full-map")
		var overlay:=Regions.new();overlay.field=field;overlay.z_index=10;world.add_child(overlay)
		await capture(id,"placements")
		overlay.boss_only=true;overlay.queue_redraw()
		await capture(id,"boss-area")
		overlay.queue_free();await frames(1)
		# Disable camera limits for before/after: both images use EXACT same
		# canvas point and zoom, even when the legacy world has a different size.
		var camera_point: Vector2=entry
		if cameras.has(id): camera_point=Vector2(cameras[id].entry[0],cameras[id].entry[1])
		world.player.camera.limit_left=-1000000;world.player.camera.limit_top=-1000000
		world.player.camera.limit_right=1000000;world.player.camera.limit_bottom=1000000
		world.player.global_position=camera_point;world.player.camera.zoom=Vector2.ONE
		world.player.show();world.monsters_root.show();world.hud.show();world.field_minimap.show()
		await capture(id,"same-camera-detail")
		print("MAP_CAPTURED ",id," ","A3_PRIVATE_PROVISIONAL" if field is RemakePlayableField else "EXISTING_UNREMADE")
	var file:=FileAccess.open(output+"/captures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"maps":reports,"failures":failures,"display":DisplayServer.get_name(),"android":"NOT_RUN"},"\t"));file.close()
	world.queue_free();await frames(3)
	print("MAP_CAPTURE_RESULT ",JSON.stringify({"maps":reports.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)

class Regions extends Node2D:
	var field: PlayableField
	var boss_only: bool=false
	func _draw() -> void:
		var colors: Array[Color]=[Color("62b6ff"),Color("eac76b"),Color("c37de3"),Color("61d8b1"),Color("f28f66")]
		var number: int=0
		for region: Dictionary in field.data.monster_spawn:
			var boss: bool=str(region.get("mode",""))=="boss"
			if boss_only and not boss: continue
			var color: Color=Color("f26599") if boss else colors[number%colors.size()]
			color.a=0.38;number+=1
			if field is RemakePlayableField:
				for flat: int in region.source_cells:
					var c:=Vector2i(flat%field.width,flat/field.width)
					draw_colored_polygon(field.coordinates.cell_polygon(c),color)
			elif region.has("polygon"):
				draw_colored_polygon(field.REGION_GEOMETRY.polygon(region),color)
			else:
				var r: Array=region.rect
				draw_rect(Rect2(r[0],r[1],r[2],r[3]),color)
			var r: Array=region.rect
			draw_string(ThemeDB.fallback_font,Vector2(r[0]+r[2]*0.5,r[1]+r[3]*0.5),str(region.id),HORIZONTAL_ALIGNMENT_CENTER,-1,68,Color.WHITE)
		for kind: String in ["npc_spawn","portal"]:
			for row: Dictionary in field.data[kind]:
				var p:=Vector2(row.position[0],row.position[1])
				draw_circle(p,36,Color("fff1a3") if kind=="npc_spawn" else Color("87ffff"))
				draw_string(ThemeDB.fallback_font,p+Vector2(40,0),str(row.id),HORIZONTAL_ALIGNMENT_LEFT,-1,58,Color.WHITE)
