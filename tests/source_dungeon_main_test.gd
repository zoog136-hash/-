extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("DUNGEON523_MAIN_FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func click(control: Control) -> void:
	await process_frame
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func capture(name: String) -> void:
	var directory := OS.get_environment("TWILIGHT_DUNGEON_SCREENSHOTS")
	if directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty() and image.save_png(directory.path_join(name+".png")) == OK,"render " + name)

func run() -> void:
	var packed := load("res://Main.tscn") as PackedScene
	check(packed != null,"actual Main loads")
	if packed == null:
		quit(1)
		return
	var world = packed.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual initial class confirmation")
	world.player.set_physics_process(false)
	check(world._save_game(true) == OK,"isolated initial save")
	var save_path: String = world.save_path()
	var save_hash := FileAccess.get_sha256(save_path)
	var original_gold: int = world.gold
	var original_inventory: Dictionary = world.inventory.duplicate(true)
	var original_map: String = world.active_map_id
	var original_position: Vector2 = world.player.global_position
	var hud: Node = world.hud
	hud.toggle_menu()
	await process_frame
	var tile := hud.workspace.find_child("MenuTile_source_dungeons",true,false) as Button
	check(tile != null,"dungeon tile in existing game menu")
	if tile == null:
		world.queue_free()
		quit(1)
		return
	hud.menu_scroll_view.ensure_control_visible(tile)
	await process_frame
	await click(tile)
	check(hud.active_section == "source_dungeons","mouse input opens dungeon screen from game menu")
	var view: Control = hud.workspace.find_child("SourceDungeonView",true,false)
	check(view != null,"actual dungeon UI mounted")
	if view == null:
		world.queue_free()
		quit(1)
		return
	var path := OS.get_environment("TWILIGHT_DUNGEON523_PACK")
	if path.is_empty():
		check(view.rows.is_empty() and view.condition_button.disabled,"missing pack shows empty guarded screen")
	else:
		check(view.rows.size() == 100,"actual Main loaded normal tower")
		check(view.details.text.contains("70000") and view.details.text.contains("아인하사드"),"normal rewards and entry currency visible")
		await click(view.condition_button)
		check(view.notice.text.contains("70레벨") and view.notice.text.contains("준비 중"),"entry check shows level and unresolved execution result")
		await capture("tower-normal")
		view.reward_mode.select(1)
		view.reward_mode.item_selected.emit(1)
		check(view.details.text.contains("90055") and view.details.text.contains("12052320") and view.details.text.contains("드래곤의 다이아몬드"),"immediate reward and correct payment displayed")
		await capture("tower-immediate")
		view.family.select(1)
		view.family.item_selected.emit(1)
		check(view.rows.size() == 100 and bool(view.rows[0].stage.IsHard),"hard mode UI selects Stage identity")
		check(view.details.text.contains("160055"),"hard immediate rewards separate")
		view.family.select(2)
		view.family.item_selected.emit(2)
		check(view.rows.size() == 10 and view.details.text.contains("닫힘"),"Orim closed state visible")
		check(view.details.text.contains("축복") and view.details.text.contains("등장 계획"),"Orim reward variants and wave plan visible")
		await capture("orim-normal")
		view.details.scroll_to_line(maxi(0,view.details.text.get_slice_count("\n")-15))
		await capture("orim-waves")
		view.family.select(3)
		view.family.item_selected.emit(3)
		check(bool(view.rows[0].stage.IsHard) and int(view.rows[0].place.land.ID) == 48752,"same Orim Land supports explicit hard UI")
		view.family.select(4)
		view.family.item_selected.emit(4)
		check(view.rows.size() == 22 and view.details.text.contains("이동 비용"),"special dungeon destinations and costs visible")
		await capture("special")
		view.family.select(5)
		view.family.item_selected.emit(5)
		check(view.rows.size() == 450 and view.details.text.contains("1시간 충전"),"time recharge item UI and explicit seconds")
		await capture("rechargers")
		# The actual screen's installation action persists verified bytes, not game progress.
		await click(view.find_child("DungeonLoadPack",true,false))
		check(is_instance_valid(view.import_dialog) and view.import_dialog.visible,"UI opens file picker from load button")
		view.import_dialog.hide()
		view.import_dialog.file_selected.emit(path)
		check(view.notice.text.contains("불러왔습니다"),"UI import action reports verified installation")
		view.import_dialog.file_selected.emit("user://absent-dungeon523/manifest.json")
		check(view.rows.size() == 450 and view.notice.text.contains("읽을 수 없습니다"),"UI bad replacement retains prior rows and shows error")
	check(world.gold == original_gold and world.inventory == original_inventory,"preview and install do not spend/grant inventory or currency")
	check(world.active_map_id == original_map and world.player.global_position == original_position,"inspection does not teleport player")
	check(FileAccess.get_sha256(save_path) == save_hash,"all dungeon UI actions preserve exact save bytes")
	hud._go_back()
	check(hud.active_section == "menu","existing back navigation works")
	print("DUNGEON523_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"real_pack":not path.is_empty(),"scope":"ACTUAL_MAIN_DUNGEON_UI_INSPECTION_ONLY; NO_DUNGEON_COMBAT_OR_PAYOUT"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
