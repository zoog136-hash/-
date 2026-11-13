extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var screenshots: Array[String] = []
var install_trace: Array[Dictionary] = []
var installed_result: Dictionary = {}
const PREFERENCES = preload("res://scripts/maps/current523_aden_preferences.gd")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func capture(tag: String) -> void:
	var directory: String = OS.get_environment("ADEN523_CAPTURE_DIR")
	if directory.is_empty(): return
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(), "actual UI viewport is rendered")
	if image == null or image.is_empty(): return
	var path: String = directory.path_join(tag + ".png")
	check(image.save_png(path) == OK, "actual UI screenshot saved")
	screenshots.append(path)

func run() -> void:
	check(not "--aden523-review" in OS.get_cmdline_user_args(), "entry is ordinary Main, without the command-line review mode")
	var raw_root: String = ""
	var tile_root: String = ""
	var resource_zip: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--aden523-pack="): raw_root = arg.trim_prefix("--aden523-pack=")
		if arg.begins_with("--aden523-tiles="): tile_root = arg.trim_prefix("--aden523-tiles=")
		if arg.begins_with("--aden523-install-zip="): resource_zip = arg.trim_prefix("--aden523-install-zip=")
	var world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	check(QA.enter_game(world), "ordinary game class confirmation completes")
	world.player.set_physics_process(false)
	world.gold = 938274
	check(world._save_game(true) == OK, "baseline uses the real game save writer")
	var save_path: String = world.save_path()
	var save_sha: String = FileAccess.get_sha256(save_path)
	var prior_field = world.field_map
	var prior_renderer = world.field_renderer
	var prior_position: Vector2 = world.player.global_position
	var prior_mode: int = world.process_mode
	var prior_map: String = world.active_map_id
	world.hud.call("open_settings_info",true)
	await frame()
	var panel = world.hud.workspace.find_child("Current523AdenReviewSettings", true, false)
	check(panel != null and panel.is_visible_in_tree(), "existing settings window contains the Aden review panel")
	if panel == null: world.queue_free(); quit(1); return
	panel.raw_path_edit.text = "/nonexistent/aden523-ui-test"
	panel.raw_path_edit.text_changed.emit(panel.raw_path_edit.text)
	panel.tile_path_edit.text = tile_root
	panel.tile_path_edit.text_changed.emit(tile_root)
	panel.open_button.pressed.emit()
	check(not world.current523_aden_review_active and world.field_map == prior_field, "bad folder is rejected through the UI without suspending the game")
	check(not panel.status_label.text.is_empty() and not world.current523_aden_problem.is_empty(), "folder failure is shown in the settings result label")
	check(FileAccess.get_sha256(save_path) == save_sha, "failed UI open preserves save bytes")
	if not resource_zip.is_empty():
		var scroller: ScrollContainer = panel.get_parent().get_parent() as ScrollContainer
		if scroller != null:
			scroller.ensure_control_visible(panel)
		await frame()
		panel.installer.progress.connect(func(stage: String, done: int, total: int) -> void:
			if install_trace.is_empty() or install_trace[-1].stage != stage:
				var event: Dictionary = {"stage":stage, "done":done, "total":total, "elapsed_ms":Time.get_ticks_msec()}
				install_trace.append(event)
				print("CURRENT523_INSTALL_STAGE " + JSON.stringify(event)))
		check(PREFERENCES.activate(raw_root, tile_root).ok, "initial external source paths are separate preferences")
		panel.install_button.pressed.emit()
		check(panel.zip_dialog.visible and panel.zip_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE, "actual resource ZIP chooser opens from Settings")
		panel.zip_dialog.file_selected.emit("/nonexistent/current523-resource.zip")
		panel.zip_dialog.hide()
		while panel.installer.busy: await process_frame
		check(not panel.installer.busy and panel.status_label.text.contains("못했"), "unavailable ZIP is reported without changing the game")
		panel.zip_dialog.file_selected.emit(resource_zip)
		check(panel.installer.busy and panel.open_button.disabled and panel.rollback_button.disabled and not panel.cancel_button.disabled, "install UI prevents switching resources while verification is running")
		panel.cancel_button.pressed.emit()
		while panel.installer.busy: await process_frame
		check(panel.status_label.text.contains("취소") and PREFERENCES.selection().raw == raw_root, "cancel through the actual UI preserves the active selection")
		panel.zip_dialog.file_selected.emit(resource_zip)
		world.hud.workspace.hide()
		while panel.installer.busy: await process_frame
		check(panel.installer.last_result.get("cancelled", false) and PREFERENCES.selection().raw == raw_root, "hiding Settings cancels its pending install and preserves the selected pack")
		world.hud.workspace.show()
		check(panel.is_visible_in_tree() and panel.cancel_button.disabled and not panel.install_button.disabled, "Settings can be reopened after cancellation")
		panel.zip_dialog.file_selected.emit(resource_zip)
		while panel.installer.busy: await process_frame
		check(panel.installer.last_result.get("ok", false) and panel.status_label.text.contains("완료"), "full reviewed 6412-file resource ZIP installs through Settings")
		installed_result = panel.installer.last_result.duplicate(true)
		var installed_raw: String = panel.raw_path_edit.text
		var installed_tiles: String = panel.tile_path_edit.text
		var store: String = ProjectSettings.globalize_path("user://current523_aden_resources/")
		check(installed_raw.begins_with(store) and installed_tiles.begins_with(store), "installed resources live in the component's own persistent store")
		check(PREFERENCES.selection().raw == installed_raw and PREFERENCES.selection().tiles == installed_tiles, "both installed resource paths activate together")
		check(world.field_map == prior_field and world.player.global_position == prior_position and FileAccess.get_sha256(save_path) == save_sha, "installation leaves live field, actor and real save bytes unchanged")
		if scroller != null:
			scroller.ensure_control_visible(panel.status_label)
		await frame()
		capture("settings-aden523-installed")
		panel.rollback_button.pressed.emit()
		check(panel.raw_path_edit.text == raw_root and panel.tile_path_edit.text == tile_root and panel.status_label.text.contains("이전"), "previous-pack action restores both original external paths")
		panel.rollback_button.pressed.emit()
		check(panel.raw_path_edit.text == installed_raw and panel.tile_path_edit.text == installed_tiles, "selection history can return to the retained installed version")
		raw_root = installed_raw
		tile_root = installed_tiles
		check(world.gold == 938274 and FileAccess.get_sha256(save_path) == save_sha, "installation, cancellation and rollback preserve progression and real save bytes")
	panel.raw_browse_button.pressed.emit()
	check(panel.folder_dialog.visible and panel.folder_dialog.file_mode == FileDialog.FILE_MODE_OPEN_DIR, "raw-folder picker opens from its actual settings button")
	panel.folder_dialog.dir_selected.emit(raw_root)
	panel.folder_dialog.hide()
	panel.tile_browse_button.pressed.emit()
	check(panel.folder_dialog.visible, "tile-folder picker opens from its settings button")
	panel.folder_dialog.dir_selected.emit(tile_root)
	panel.folder_dialog.hide()
	check(panel.raw_path_edit.text == raw_root and panel.tile_path_edit.text == tile_root and not panel.open_button.disabled, "folder choices update visible controls and enable the entry action")
	check(panel.status_label.text.contains("눌러 확인"), "choosing new folders clears the previous validation error")
	await frame()
	capture("settings-aden523-entry")
	var prior_visibility: bool = world.hud.visible
	panel.open_button.pressed.emit()
	await frame()
	check(world.current523_aden_review_active and world.current523_aden_review != null, "settings action opens the actual current523 rendered view")
	if world.current523_aden_review == null: world.queue_free(); quit(1); return
	check(world.field_map == prior_field and world.field_renderer == prior_renderer and world.active_map_id == prior_map, "review entry keeps the existing live map objects")
	check(world.process_mode == Node.PROCESS_MODE_DISABLED and not world.hud.visible, "game is suspended under the review overlay")
	check(world._save_game(true) == ERR_UNAVAILABLE, "UI review blocks saves as well as command-line review")
	world._load_game(true)
	check(FileAccess.get_sha256(save_path) == save_sha and world.gold == 938274, "review UI preserves actual save and progression")
	var metrics: Dictionary = world.current523_aden_review.frame_metrics()
	check(metrics.get("draw_commands", 0) > 0 and metrics.get("budget_skips", -1) == 0, "settings entry renders original tiles within its budget")
	capture("settings-aden523-open")
	world.current523_aden_review.close_button.pressed.emit()
	await frame()
	check(not world.current523_aden_review_active and world.current523_aden_review == null, "review close button returns to the existing game")
	check(world.process_mode == prior_mode and world.hud.visible == prior_visibility and world.hud.workspace.visible, "original simulation mode and settings visibility are restored")
	check(world.field_map == prior_field and world.field_renderer == prior_renderer and world.active_map_id == prior_map and world.player.global_position == prior_position, "map and actor position survive the full UI round trip")
	check(world.gold == 938274 and FileAccess.get_sha256(save_path) == save_sha, "closing review preserves progression and save bytes")
	check(panel.status_label.text.contains("돌아왔"), "settings panel displays the return result")
	var config := ConfigFile.new()
	check(config.load("user://current523_aden_review_paths.cfg") == OK and config.get_value("paths", "raw", "") == raw_root and config.get_value("paths", "tiles", "") == tile_root, "only separate folder preferences are remembered")
	capture("settings-aden523-return")
	print("CURRENT523_ADEN_REVIEW_UI_RESULT " + JSON.stringify({"checks":checks, "failures":failures, "screenshots":screenshots, "rendered_view":metrics, "installation":installed_result, "install_trace":install_trace, "scope":"ACTUAL_MAIN_SETTINGS_FOLDER_PICKERS_INSTALL_CANCEL_ROLLBACK_REVIEW_AND_RETURN; M_SPATIAL_AND_COLLISION_SEMANTICS_UNVERIFIED"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
