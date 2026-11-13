extends SceneTree
## Authorized source bytes, actual Main/UI; run only with isolated XDG data.
const PACK = preload("res://scripts/resources/current523_pack.gd")
const PLAYBACK = preload("res://scripts/resources/current523_playback.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func check(value: bool,message: String) -> void:
	checks += 1
	if not value: failures.append(message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var archive: String = ""
	var capture: String = ""
	var field_capture: String = ""
	var restart: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="): archive = argument.trim_prefix("--pack=")
		if argument.begins_with("--capture-output="): capture = argument.trim_prefix("--capture-output=")
		if argument.begins_with("--field-capture="): field_capture = argument.trim_prefix("--field-capture=")
		if argument == "--read-installed": restart = true
	if archive.is_empty() and not restart: printerr("Authorized --pack and isolated profile required."); quit(2); return
	var source_sha: String = FileAccess.get_sha256(archive) if not archive.is_empty() else ""
	if not restart:
		check(not PLAYBACK.options().enabled,"estimated mode starts opt-in disabled")
		var invalid: Dictionary = PLAYBACK.options()
		invalid.group_bit = INF
		check(not PLAYBACK.save_options(invalid).ok,"nonfinite setting rejected before integer conversion")
		invalid = PLAYBACK.options()
		invalid.fps = 0.0
		check(not PLAYBACK.save_options(invalid).ok,"out-of-range timing rejected without persistence")
		var installer := PACK.new()
		root.add_child(installer)
		var installed: Dictionary = await installer.install_zip(archive)
		check(installed.ok,"actual source installed for real playback")
		installer.queue_free()
	else:
		check(PLAYBACK.options().enabled and PLAYBACK.options().world_enabled,"restart restores explicit estimated settings")
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	check(scene != null,"actual Main scene loads")
	if scene == null: finish(); return
	var world = scene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual class selection opens gameplay")
	world.player.set_physics_process(false)
	world.player.set_process(false)
	check(world._save_game(true) == OK,"baseline real atomic game save")
	var saved: String = world.save_path()
	var save_sha: String = FileAccess.get_sha256(saved)
	var physics_state: Array = [world.player.collision_layer,world.player.collision_mask,world.player.move_speed,world.player.attack_speed_multiplier]
	var original_class_visible: bool = world.player.class_sprite.visible
	var source_file: String = PLAYBACK.source_root().path_join("selected_originals/Sprite/10557-0.sp2")
	var raw_sha: String = FileAccess.get_sha256(source_file)
	world.hud.open_settings_info(true)
	await process_frame
	var viewer = world.hud.workspace.find_child("Current523SP2Viewer",true,false)
	check(viewer != null,"estimated viewer reachable through real settings")
	if viewer != null:
		check(viewer.find_child("Current523EstimatedTitle",true,false).text.contains("미검증"),"estimated output clearly labelled")
		viewer.enabled_toggle.button_pressed = true
		var selected: Dictionary = viewer.select_member("Sprite/10557-0.sp2")
		check(selected.ok and viewer.frame_count() > 1,"actual multi-group source member loads")
		check(viewer.select_group_bit(0),"raw stored bit selected without compass mapping")
		viewer.fps_input.value = 12.0
		viewer.zoom_input.value = 0.5
		viewer.world_toggle.button_pressed = true
		var applied: Dictionary = viewer._apply()
		check(applied.ok,"actual settings persist explicit estimate options")
		viewer.reset_playback()
		viewer.play()
		await create_timer(0.35).timeout
		check(viewer.current_frame_index > 0,"real elapsed time advances actual source records")
		check(viewer.canvas.sprite.texture != null and viewer.canvas.sprite.visible,"actual estimated pixels shown in UI")
		viewer.pause()
		var paused: int = viewer.current_frame_index
		await create_timer(0.12).timeout
		check(viewer.current_frame_index == paused,"pause keeps source record stable")
		viewer.step_frame(1)
		check(viewer.current_frame_index != paused,"manual source record step works")
		var sample = world.player.get_node_or_null("Current523EstimatedWorldPreview")
		check(sample != null and sample.visible and sample.frame_index > 0 and sample.sprite.texture != null,"opt-in field sample actually animates")
		if sample != null and sample.frame_index >= 0:
			var native_bounds: Rect2i = sample._parsed.groups[sample._group].frames[sample.frame_index].bounds
			check(sample.sprite.position == Vector2(native_bounds.position) * float(PLAYBACK.options().zoom),"world zoom preserves the same native coordinate origin as UI")
		check(sample != null and sample.label.text.contains("추정") and sample.label.text.contains("게임 판정 없음"),"field sample labels estimated and noncombat display")
		var before_options: Dictionary = PLAYBACK.options()
		var before_revision: int = PLAYBACK.revision
		var config_sha: String = FileAccess.get_sha256(PLAYBACK.SETTINGS)
		var preserved: String = PLAYBACK.SETTINGS + ".test-preserved"
		check(DirAccess.rename_absolute(PLAYBACK.SETTINGS,preserved) == OK,"test preserves config before obstruction")
		check(DirAccess.make_dir_absolute(PLAYBACK.SETTINGS) == OK,"isolated settings save obstruction")
		viewer.fps_input.value = 20.0
		var rejected: Dictionary = viewer._apply()
		check(not rejected.ok and not viewer.save_status.text.is_empty(),"settings save failure visible in actual UI")
		check(PLAYBACK.options() == before_options and PLAYBACK.revision == before_revision,"failed settings write keeps active estimate")
		check(FileAccess.get_sha256(preserved) == config_sha,"failed write preserves prior settings bytes")
		DirAccess.remove_absolute(PLAYBACK.SETTINGS) # Only the empty test obstruction.
		check(DirAccess.rename_absolute(preserved,PLAYBACK.SETTINGS) == OK,"test restores original settings file")
		world.hud.open_settings_info(true)
		await process_frame
		viewer = world.hud.workspace.find_child("Current523SP2Viewer",true,false)
		check(viewer != null and is_equal_approx(viewer.fps_input.value,12.0),"reentry restores saved options after failed edits")
		check(viewer != null and viewer.frame_count() > 1,"reentry loads actual source records")
		viewer.target_picker.select(1)
		viewer.target_picker.item_selected.emit(1)
		check(viewer._apply().ok,"actual UI selects estimated player appearance")
		await process_frame
		check(not world.player.class_sprite.visible and sample.sprite.texture != null and sample.position == Vector2.ZERO,"selected SP2 replaces only player display at explicit host origin")
		check(sample.label.text.contains("플레이어 외형 추정"),"estimated player appearance remains labelled")
		var previous_ratio: float = world.player.motion.move_ratio
		world.player.motion.move_ratio = 0.4
		await process_frame
		check(not world.player.get_node("PlayerActionFX").visible,"later movement FX cannot reappear over selected estimate")
		world.player.motion.move_ratio = previous_ratio
		# Presentation-state fixture only: no synthetic pixels or native-playback claim.
		var previous_record: Dictionary = world.player.original_source_preview._record
		var previous_transform: bool = world.player.transform_active
		world.player.original_source_preview._record = {"visibility_fixture_only":true}
		world.player.transform_active = true
		world.player.original_source_preview.visible = true
		await process_frame
		check(not world.player.original_source_preview.visible,"form changed while estimate enabled remains suppressed")
		viewer.world_toggle.button_pressed = false
		check(viewer._apply().ok,"field sample can be disabled independently")
		await process_frame
		check(sample != null and not sample.visible,"field display disabled without changing original actor")
		check(world.player.original_source_preview.visible and not world.player.class_sprite.visible,"disable restores current native-form presentation instead of stale class snapshot")
		world.player.original_source_preview._record = previous_record
		world.player.transform_active = previous_transform
		world.player._refresh_visual_visibility()
		check(world.player.class_sprite.visible == original_class_visible,"disabling estimate restores original player display")
		viewer.world_toggle.button_pressed = true
		check(viewer._apply().ok,"explicit field sample reenabled")
		if not capture.is_empty() and DisplayServer.get_name() != "headless":
			var scroll: ScrollContainer = world.hud.workspace.find_child("SettingsScroll",true,false)
			if scroll != null: scroll.ensure_control_visible(viewer.canvas)
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(capture) == OK,"real renderer estimated UI capture")
		if not field_capture.is_empty() and DisplayServer.get_name() != "headless":
			world.hud._close_workspace()
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(field_capture) == OK,"real renderer field sample capture")
			check(sample.label.is_visible_in_tree() and sample.label.z_index == 4000,"estimated field annotation stays above foreground")
			print("CURRENT523_FIELD_LABEL ",JSON.stringify({"screen_origin":str(sample.label.get_global_transform_with_canvas().origin),"size":str(sample.label.size),"text":sample.label.text}))
	check(FileAccess.get_sha256(saved) == save_sha,"playback and failed config save preserve game save bytes")
	check([world.player.collision_layer,world.player.collision_mask,world.player.move_speed,world.player.attack_speed_multiplier] == physics_state,"sample leaves collisions and gameplay speeds unchanged")
	check(FileAccess.get_sha256(source_file) == raw_sha,"estimated decoding preserves actual SP2 bytes")
	if not archive.is_empty(): check(FileAccess.get_sha256(archive) == source_sha,"original source ZIP preserved")
	world.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("CURRENT523_ESTIMATE_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_UI_AND_FIELD_ESTIMATED_PLAYBACK; NOT_NATIVE_M_VISUAL_EQUIVALENCE"}))
	quit(0 if failures.is_empty() else 1)
