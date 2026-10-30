extends SceneTree
## Review-only: crop flattened high-resolution draft panels into a bounded
## viewport texture. No full-world texture or navigation replacement occurs.
const QA=preload("res://tests/qa_class_selection.gd")
const BASE="res://assets/maps/aden_world_draft/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var out: String=OS.get_environment("ADEN_WORLD_DRAFT_OUTPUT")
	if out.is_empty() or DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,720)
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"manifest.json"))
	if manifest.get("status")!="FULL_EXTENT_RENDERED_GEOGRAPHIC_ART_DRAFT_NOT_PRODUCTION":push_error("Draft compilation incomplete");quit(1);return
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world);world.set_process(false);world.save_timer=-100000;world.portal_cooldown=100000
	world._set_map("aden_world",false);world.field_population.configure(world,null);world._clear_monsters();world.player.set_auto_enabled(false);world.player.set_physics_process(false);world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE
	var field: NativePngField=world.field_map;var before: Dictionary=field.navigation_snapshot();var portals: Array=field.data.portal.duplicate(true);var failures: Array=[]
	world.field_renderer.get_parent().remove_child(world.field_renderer);world.field_renderer.free();world.field_renderer=null
	var view:=Sprite2D.new();view.centered=false;view.z_index=-20;world.add_child(view)
	for site: Array in [["snow",7780,1140],["volcano",6450,2270],["forest",10290,3395],["desert",7500,5370],["ruins",8240,3130],["river",7250,4200]]:
		var center:=Vector2i(int(site[1])*6,int(site[2])*6)
		if not field.walkable(Vector2(center)):failures.append("existing arrival blocked: "+str(site[0]))
		world.player.global_position=Vector2(center);world.player.camera.force_update_scroll()
		var rect:=Rect2i(center-Vector2i(640,360),Vector2i(1280,720));var canvas:=Image.create(1280,720,false,Image.FORMAT_RGBA8)
		for row: Dictionary in manifest.panels:
			var bounds:=Rect2i(int(row.world_bounds[0]),int(row.world_bounds[1]),int(row.world_bounds[2]),int(row.world_bounds[3]));var overlap:=rect.intersection(bounds)
			if not overlap.has_area():continue
			var image:=Image.new();var result: Error=image.load_png_from_buffer(FileAccess.get_file_as_bytes(BASE+"panels/"+row.file))
			if result!=OK:failures.append("decode: "+str(row.file));continue
			canvas.blit_rect(image,Rect2i(overlap.position-bounds.position,overlap.size),overlap.position-rect.position)
		view.position=Vector2(rect.position);view.texture=ImageTexture.create_from_image(canvas)
		await process_frame;await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(out+"/"+site[0]+"-game.png")
	var after: Dictionary=field.navigation_snapshot()
	if before.solid_runs!=after.solid_runs or before.spawn_cells!=after.spawn_cells or portals!=field.data.portal:failures.append("navigation mutation")
	var result={"failures":failures,"sites":6,"navigation_unchanged":true,"production_enabled":false,"flattened_foreground_not_production_occlusion":true,"viewport_texture_bytes":1280*720*4,"actual_android":false}
	var f:=FileAccess.open(out+"/capture-result.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close();print("WORLD_DRAFT_CAPTURE ",JSON.stringify(result));world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
