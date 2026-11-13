extends SceneTree
## Actual Main/settings actions, isolated by the normal test runner's user profile.
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label_text: String) -> void:
	checks += 1
	if not ok: failures.append(label_text)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var capture: String = ""
	if "--settings-test-snapshot523" in OS.get_cmdline_user_args():
		var chosen: String = INSTALL.preview_selection(OS.get_cmdline_user_args()).path
		check(chosen == "user://settings-test-523.json", "test writes only its own explicit fixture")
		if chosen != "user://settings-test-523.json": finish(); return
		var fixture := FileAccess.open(chosen, FileAccess.WRITE)
		fixture.store_string(JSON.stringify({"schema":1,"source_snapshot":"patch523","mode":"literal_body_shadow_inspection_only","records":{}}))
		fixture.close()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-output="): capture = argument.trim_prefix("--capture-output=")
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	check(scene != null, "production Main loads")
	if scene == null: finish(); return
	var world = scene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "class confirmation uses actual Main")
	world.player.set_physics_process(false)
	check(world._save_game(true) == OK, "baseline through production save writer")
	var save_path: String = world.save_path()
	var before: String = FileAccess.get_sha256(save_path)
	var selected: String = INSTALL.active_manifest()
	world.hud.open_settings_info(true)
	await process_frame
	await process_frame
	var button: Button = world.hud.workspace.find_child("InstallLineageMOfflinePack", true, false) as Button
	check(button != null and button.is_visible_in_tree(), "install button visible in production settings")
	if button != null:
		var panel = button.get_parent()
		var problem: String = INSTALL.active_manifest_problem()
		check(panel.status.text.contains(problem) if not problem.is_empty() else panel.status.text.contains("연결됨"), "actual selection result shown in settings")
		if "--settings-test-snapshot523" in OS.get_cmdline_user_args():
			check(panel.status.text.contains("base508"), "523 is visibly refused by current 508 consumer")
		check(panel.picker.file_mode == FileDialog.FILE_MODE_OPEN_FILE, "picker opens local installation file")
		panel.picker.file_selected.emit("user://missing-resource-install-fixture.zip")
		await process_frame
		await process_frame
		check(not panel.status.text.is_empty() and panel.status.text != "설치 파일 확인 중…", "file-selection action displays installation error")
		check(not button.disabled and not panel.cancel.visible and not panel.installer.busy, "failed install restores usable controls")
		check(INSTALL.active_manifest() == selected, "settings action preserves active native selection")
	check(FileAccess.get_sha256(save_path) == before, "settings interaction preserves save bytes")
	# Reopening uses the same gameplay UI route and restores pack status.
	world.hud.open_settings_info(true)
	await process_frame
	await process_frame
	check(world.hud.workspace.find_child("InstallLineageMOfflinePack", true, false) != null, "settings can be reopened after failure")
	if not capture.is_empty():
		check(DisplayServer.get_name() != "headless", "capture requires a real renderer")
		if DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(capture) == OK, "actual settings render saved for inspection")
	world.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("LINEAGEM_PACK_SETTINGS_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
