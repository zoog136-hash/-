extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const COORD = preload("res://scripts/maps/world_coordinates.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func settle() -> void:
	for i: int in range(12):await process_frame
func _run() -> void:
	root.size=Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	var world: Node=load("res://Main.tscn").instantiate();root.add_child(world);await settle()
	if not QA.enter_game(world):quit(1);return
	world.set_process(false);world.save_timer=-10000
	world.field_population.set_process(false);world.player.set_physics_process(false);world._clear_monsters();world._clear_drops()
	world.player.global_position=world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550,4300)))
	world.player.camera.zoom=Vector2.ONE;world.player.camera.position=Vector2(0,-110)
	world.player.camera.position_smoothing_enabled=false;world.player.camera.force_update_scroll();world.field_renderer.refresh_visible()
	var names: Array[String]=["미스릴 단검","은장검","장궁","벡드코빈","훈련용 단검","훈련용 창","미스릴의 갑옷","가죽의 각반","HP 물약","무기 마법 주문서 (각인)","강철의 장갑","강철의 신발"]
	var labels:=CanvasLayer.new();labels.layer=19;root.add_child(labels)
	var views: Array[Button]=[]
	for i: int in range(names.size()):
		var record: Dictionary={}
		for candidate: Dictionary in world.catalog_db.get("아이템",[]):
			if candidate.get("name","")==names[i]:record=candidate;break
		if record.is_empty():failures.append("missing sample:"+names[i]);continue
		var point: Vector2=world.player.global_position+Vector2((float(i%4)-1.5)*150.0,-155.0+float(i/4)*120.0)
		var drop: Button=world.ground_loot.spawn(names[i],point,1,"",{"item_record":record})
		if drop==null:failures.append("drop failed:"+names[i]);continue
		drop.visual.set_process(false);drop.visual.clock=0.75;drop.visual.queue_redraw();views.append(drop)
	await settle()
	for drop: Button in views:
		var label:=Label.new();label.text=str(drop.get_meta("item_name"))
		label.add_theme_font_size_override("font_size",14)
		label.add_theme_color_override("font_color",TwilightDropVisual.grade_color(str(drop.get_meta("grade"))))
		label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",1)
		label.position=COORD.world_to_screen(root,drop.get_meta("world_position"))+Vector2(-55,12);labels.add_child(label)
	if not views.is_empty():world.loot_pickup.select(views[0])
	await settle();await RenderingServer.frame_post_draw
	var folder: String=OS.get_environment("GROUND_CAPTURES");DirAccess.make_dir_recursive_absolute(folder)
	if root.get_texture().get_image().save_png(folder+"/white-backgrounds.png")!=OK:failures.append("capture save failed")
	print("GROUND_ALPHA_CAPTURE ",JSON.stringify({"samples":views.size(),"failures":failures,"captions":"QA-only; production selected-name overlay also visible"}))
	labels.queue_free();world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
