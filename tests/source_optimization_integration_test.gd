extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("SOURCE_OPTIMIZATION_UI_FAIL: ",label)
func click(button: Control, scroll: ScrollContainer) -> void:
	# Source loading/selection changes wrapped text and content height. Let the
	# container lay out before asking it to bring the button into view.
	for i: int in range(3): await process_frame
	scroll.ensure_control_visible(button)
	await process_frame
	await process_frame
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size*0.5)
	check(scroll.get_global_rect().has_point(point),"input target is inside scroll clip: " + str(button.name))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func run() -> void:
	check(DisplayServer.get_name()!="headless","actual renderer required")
	var path: String = OS.get_environment("TWILIGHT_PATCH523_CONTENT")
	check(not path.is_empty(),"actual private source required")
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual Main enters game")
	world.player.set_physics_process(false)
	check(world._save_game(true)==OK,"baseline real save")
	var save_path: String = world.save_path()
	var save_hash: String = FileAccess.get_sha256(save_path)
	var equipment: Dictionary = world.equipped_catalog.duplicate(true)
	var attack: int = world._effective_attack()
	var global_before: Dictionary = world.presentation_global_settings.duplicate(true)
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = extent
		world.hud.open_settings_info()
		await process_frame
		await process_frame
		var host: Node = world.hud.find_child("RenewalSettings",true,false)
		var source: Node = host.find_child("SourceOptimizationSettings",true,false)
		var scroll: ScrollContainer = host.find_child("SettingsScroll",true,false)
		check(source!=null,"real source settings controls " + str(extent))
		await click(source.choose_button if extent.x==1280 else source.zip_button,scroll)
		check(is_instance_valid(source.directory_dialog) and source.directory_dialog.visible,"actual folder picker opens " + str(extent))
		source.directory_dialog.current_dir = path
		if extent.x==1280: source.directory_dialog.dir_selected.emit(path)
		else: source.directory_dialog.file_selected.emit(OS.get_environment("TWILIGHT_PATCH523_ZIP"))
		source.directory_dialog.hide()
		check(source.regions.item_count==195,"all 195 regions reach actual dropdown " + str(extent))
		for i: int in range(source.regions.item_count):
			check(world.source_optimization.by_id.has(int(source.regions.get_item_metadata(i))),"original row identity in UI %d" % i)
		var index: int = -1
		for i: int in range(source.regions.item_count):
			var row: Dictionary = world.source_optimization.by_id[int(source.regions.get_item_metadata(i))]
			if row.DefaultLowEffectCount and row.DefaultHideMagicDoll and int(row.ConditionTypeId)==0: index=i;break
		check(index>=0,"real unconditional recommendation available")
		source.regions.select(index)
		source.regions.item_selected.emit(index)
		await click(source.apply_button,scroll)
		check(world.presentation_settings.hide_doll and world.presentation_settings.limit_effect_count,"actual apply button reaches game " + str(extent))
		check(not world.get_node("Companion").visible and world.combat_vfx.impact_visual_limit==24,"real presentation changes immediately")
		check(world.presentation_settings.effect_detail==global_before.effect_detail,"source low count never invents a detail setting")
		check(world.presentation_global_settings==global_before,"source application preserves global preferences")
		check(source.automatic.disabled and not source.automatic.button_pressed,"unverified current PC/M coordinate mapping cannot auto-activate")
		check(source.status.text.contains("적용했습니다"),"application result is visible")
		check(world.equipped_catalog==equipment and world._effective_attack()==attack,"equipment and combat stats preserved")
		check(FileAccess.get_sha256(save_path)==save_hash,"source UI preserves game save bytes")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://source-settings-%dx%d.png" % [extent.x,extent.y])
		if extent.x==1280:
			await click(host.region_override,scroll)
			check(not world.presentation_settings.hide_doll and not world.presentation_settings.limit_effect_count,"real scope-off restores global preferences")
	var old_rows: String = JSON.stringify(world.source_optimization.territories)
	check(not bool(world.load_source_optimization("user://missing-source").ok) and JSON.stringify(world.source_optimization.territories)==old_rows,"failed source selection preserves active pack")
	world.queue_free()
	await process_frame
	var reopened: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(reopened)
	reopened.set_process(false)
	reopened.save_timer = -100000.0
	check(QA.enter_game(reopened),"actual Main restarts")
	check(reopened.source_optimization.territories.size()==195 and reopened.presentation_settings.hide_doll,"source folder and selected preferences survive restart")
	check(FileAccess.get_sha256(save_path)==save_hash,"restart preserves game save")
	reopened.queue_free()
	await process_frame
	print("SOURCE_OPTIMIZATION_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"viewports":["1280x720","960x540"],"native_M_coordinate_or_pixel_approval":false}))
	quit(0 if failures.is_empty() else 1)
