extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const ART="res://assets/maps/aden_rebuild_preview/"
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("ADEN_NEW_ART_FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var out: String=OS.get_environment("ADEN_NEW_ART_OUTPUT")
	if out.is_empty() or DisplayServer.get_name()=="headless":printerr("ADEN_NEW_ART requires rendered output directory");quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	var spec: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+"preview.json"))
	var world: TwilightWorld=load("res://Main.tscn").instantiate();root.add_child(world);QA.enter_game(world)
	world.set_process(false);world.save_timer=-100000;world.portal_cooldown=100000
	world._set_map("aden_world",false);world.field_population.configure(world,null);world._clear_monsters()
	world.player.set_auto_enabled(false);world.player.camera.position_smoothing_enabled=false;world.player.camera.zoom=Vector2.ONE
	var original: NativePngRenderer=world.field_renderer
	for size: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=size;world.player.camera.force_update_scroll();await original.settle_visible();await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/before-"+str(size.x)+".png")
	var anchor: Vector2=world.player.global_position-Vector2(800,610)
	world.field_minimap.hide() # The old world overview is not a map of this new sample.
	world.field_renderer.hide();world.field_physics.get_parent().remove_child(world.field_physics);world.field_physics.queue_free()
	var field:=PlayableField.new()
	var definition: Dictionary=world.field_map.data.duplicate(true)
	var polygon: Array=[]
	for p: Array in spec.walk_polygon:polygon.append([anchor.x+p[0],anchor.y+p[1]])
	definition.bounds=[anchor.x,anchor.y,1536,1024];definition.navigation={"cell_size":8,"clearance":4,"use_baked_cache":false}
	definition.spawn_position=[anchor.x+800,anchor.y+610];definition.navigable_polygons=[polygon]
	for key: String in ["collision","monster_spawn","npc_spawn","portal","teleport","regions","safe_zone","combat_zone","boss_zone"]:definition[key]=[]
	definition.portal_connected_regions=false;field.configure(definition);world.field_map=field;world.field_physics=field.build_physics(world)
	var rendered:=Node2D.new();rendered.name="GeneratedAdenRegionPreview";rendered.position=anchor;rendered.z_index=-20;rendered.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;world.add_child(rendered)
	var source:=Image.load_from_file(ART+spec.image);check(source.get_size()==Vector2i(1536,1024),"native generated resolution");check(FileAccess.get_sha256(ART+spec.image)==spec.sha256,"original generated PNG hash")
	var chunks: int=0
	for y: int in range(0,1024,512):
		for x: int in range(0,1536,512):
			var part: Image=source.get_region(Rect2i(x,y,512,512));var sprite:=Sprite2D.new();sprite.centered=false;sprite.position=Vector2(x,y);sprite.texture=ImageTexture.create_from_image(part);rendered.add_child(sprite);chunks+=1
	check(chunks==6,"six 512px chunks, 6MiB RGBA total")
	# Exact chunk reconstruction proves no crop gaps, overlap or resampling.
	var assembled:=Image.create(1536,1024,false,source.get_format())
	for child: Sprite2D in rendered.get_children():assembled.blit_rect(child.texture.get_image(),Rect2i(0,0,512,512),Vector2i(child.position))
	check(assembled.get_data()==source.get_data(),"all chunk seams preserve exact original pixels")
	for row: Array in spec.routes:
		var a:=anchor+Vector2(row[0][0],row[0][1]);var b:=anchor+Vector2(row[1][0],row[1][1]);check(not field.path(a,b).is_empty(),"visible street exit path "+str(row))
	for p: Array in spec.blocked_probes:check(not field.walkable(anchor+Vector2(p[0],p[1])),"building/tree/rock area excluded "+str(p))
	world.player.global_position=anchor+Vector2(800,610);await physics_frame;await physics_frame
	var target:=anchor+Vector2(800,850);world._set_click_destination(target)
	for i: int in range(100):await physics_frame
	check(world.player.global_position.distance_to(target)<24,"actual player walks 240px along new visible street")
	world.player.clear_click_path();world.player.global_position=anchor+Vector2(800,610)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=size;world.player.camera.force_update_scroll();await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"/after-"+str(size.x)+".png")
	var report: Dictionary={"checks":checks,"failures":failures,"image_size":[1536,1024],"world_pixels_per_image_pixel":1,"chunks":chunks,"chunk_rgba_bytes":512*512*4,"total_rgba_bytes":1536*1024*4,"actual_android":false,"production_map_replaced":false}
	var file:=FileAccess.open(out+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print("ADEN_NEW_ART_RESULT ",JSON.stringify(report))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
