extends SceneTree
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
var world: Node
var folder: String = ""
var captures: Array = []
var failed: bool = false
func _initialize() -> void: call_deferred("_run")
func _capture(label: String) -> void:
	for frame: int in 6: await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	var path := folder+"/"+label+".png"
	var result := pixels.save_png(path)
	if result != OK: failed = true; push_error("Capture write failed: "+path)
	captures.append({"name":label,"width":pixels.get_width(),"height":pixels.get_height(),"path":path,"error":result,"map":world.active_map_id,"menu":world.hud.active_section,"auto":world.player.auto_enabled,"hp":world.hp,"mp":world.mp,"position":[world.player.position.x,world.player.position.y],"target":str(world.selected_monster.monster_name) if is_instance_valid(world.selected_monster) else ""})
	print("CAPTURE "+label)
func _run() -> void:
	folder = OS.get_environment("TWILIGHT_UI_CAPTURE_DIR")
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://integrated-ui-captures")
	DirAccess.make_dir_recursive_absolute(folder)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	for frame: int in 6: await process_frame
	await _capture("entry-class-selection")
	if not CLASS_QA.enter_game(world): push_error("CLASS_SELECTION_FAILED"); quit(1); return
	world.save_timer = -100000
	var hud: Node = world.hud
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2400,1080)]:
		root.size = extent
		DisplayServer.window_set_size(extent)
		for frame: int in 4: await process_frame
		hud.workspace.title_dragged = false
		hud._fit_hud()
		hud._close_workspace()
		var suffix := "-%dx%d" % [extent.x,extent.y]
		await _capture("hud"+suffix)
		for section: String in ["menu","inventory","character","skills","quickslots","map","quest","chat","party","crafting","settings","teleport","shop","exchange","변신","마법인형","성물"]:
			hud._navigate(section)
			# Re-entry restores the previous detail view. Explicitly return to
			# the list so each capture label describes what is actually visible.
			for frame: int in 3: await process_frame
			if section == "inventory": hud.lineage_inventory_ui.back_to_list()
			elif section == "skills": hud.skills_view.cards.get_parent().get_parent().back_to_list()
			await _capture(section+suffix)
			if section == "menu":
				for group: int in range(1,4):
					(hud.workspace.find_child("MenuGroup_%d" % group,true,false) as Button).pressed.emit()
					await _capture("menu-category-%d" % group+suffix)
				(hud.workspace.find_child("MenuGroup_0",true,false) as Button).pressed.emit()
			elif section == "inventory":
				hud.lineage_inventory_ui._select_item("HP 물약")
				await _capture("inventory-detail"+suffix)
			elif section == "skills":
				var browser: Node = hud.skills_view.cards.get_parent().get_parent()
				(browser.tabs.get_child(1) as Button).pressed.emit()
				await _capture("skills-detail"+suffix)
			hud._close_workspace()
		world._set_click_destination(world.player.global_position+Vector2(200,0))
		await create_timer(.2).timeout
		await _capture("movement"+suffix)
		world.player.clear_click_path()
		world._select_nearest_target()
		world._attack()
		await _capture("manual-combat"+suffix)
		world.player.set_auto_enabled(true)
		await create_timer(2).timeout
		# Existing level-up behavior can open character stats. Close that
		# window so this capture actually shows the requested HUD state.
		hud._close_workspace()
		await _capture("auto-hunt"+suffix)
		world.player.set_auto_enabled(false)
		hud.confirm_action("저장 후 종료","현재 상태를 저장하고 게임을 종료합니다.",Callable())
		await _capture("confirmation"+suffix)
		hud.go_back()
	var file := FileAccess.open(folder+"/captures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(captures,"\t"))
	world.queue_free()
	await process_frame
	print("INTEGRATED_CAPTURE_FAILED" if failed else "INTEGRATED_CAPTURE_OK")
	quit(1 if failed else 0)
