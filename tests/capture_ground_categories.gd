extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var world: Node
var failures: Array[String] = []
var folder: String
func _initialize() -> void: call_deferred("_run")
func settle() -> void:
	for i: int in range(12):await process_frame
func _run() -> void:
	folder=OS.get_environment("GROUND_CAPTURES")
	DirAccess.make_dir_recursive_absolute(folder)
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	await settle()
	if not QA.enter_game(world):quit(1);return
	world.set_process(false)
	world.save_timer=-10000
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world._clear_monsters()
	world._clear_drops()
	world.player.global_position=world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550,4300)))
	world.player.camera.zoom=Vector2.ONE
	world.player.camera.position=Vector2(0,-110)
	world.player.camera.position_smoothing_enabled=false
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	var pages: Dictionary = {"equipment":["강철 한손검","청동 양손검","훈련용 활","훈련용 지팡이","미스릴의 갑옷","가죽의 각반","가죽의 투구","강철의 장갑","강철의 신발","용기의 목걸이","용기의 반지","강철의 방패"],"consumables":["HP 물약","마나 회복 물약","무기 마법 주문서 (각인)","드래곤의 루비","엘릭서","힘센 한우 스테이크","철 광석","가죽 조각","천 조각","희귀 제작 비법서","화살","총알"]}
	for page: String in pages:
		world.loot_pickup.cancel()
		world._clear_drops()
		var captions:=CanvasLayer.new()
		captions.layer=19
		root.add_child(captions)
		var views: Array[Button]=[]
		var names: Array=pages[page]
		for i: int in range(names.size()):
			var item: Dictionary={}
			for candidate: Dictionary in world.catalog_db.get("아이템",[]):
				if candidate.get("name","")==names[i]:item=candidate;break
			if item.is_empty(): failures.append("sample missing: "+str(names[i]));continue
			var point: Vector2=world.player.global_position+Vector2(float(i%4-1.5)*150,-155+float(i/4)*120)
			var view: Button=world.ground_loot.spawn(str(names[i]),point,1,"",{"item_record":item})
			if view==null:failures.append("drop failed: "+str(names[i]));continue
			view.visual.set_process(false)
			view.visual.clock=0.75
			view.visual.queue_redraw()
			views.append(view)
		await settle()
		for view: Button in views:
			# QA-only captions identify the test samples; production name UI is
			# additionally exercised below and is not changed by this feature.
			var label:=Label.new()
			label.text=str(view.get_meta("item_name"))
			label.add_theme_font_size_override("font_size",14)
			label.add_theme_color_override("font_color",TwilightDropVisual.grade_color(str(view.get_meta("grade"))))
			label.add_theme_color_override("font_shadow_color",Color.BLACK)
			label.add_theme_constant_override("shadow_offset_x",1)
			label.add_theme_constant_override("shadow_offset_y",1)
			label.position=WorldCoordinates.world_to_screen(root,view.get_meta("world_position"))+Vector2(-55,12)
			captions.add_child(label)
		if not views.is_empty():world.loot_pickup.select(views[mini(5,views.size()-1)])
		await settle()
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(folder+"/"+page+".png")!=OK:failures.append("capture failed: "+page)
		captions.queue_free()
		await process_frame
	print("GROUND_CAPTURE_RESULT ",JSON.stringify({"failures":failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
