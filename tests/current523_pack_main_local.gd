extends SceneTree
## Real Main/UI and authorized source ZIP; use an isolated user-data profile.
const PACK = preload("res://scripts/resources/current523_pack.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool,label_text: String) -> void:
	checks += 1
	if not ok: failures.append(label_text)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var archive: String = ""
	var capture: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="): archive = argument.trim_prefix("--pack=")
		if argument.begins_with("--capture-output="): capture = argument.trim_prefix("--capture-output=")
	if archive.is_empty(): printerr("Authorized --pack and isolated profile required."); quit(2); return
	var before_archive: String = FileAccess.get_sha256(archive)
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	check(scene != null,"actual Main loads")
	if scene == null: finish(); return
	var world = scene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual class selection path")
	world.player.set_physics_process(false)
	check(world._save_game(true) == OK,"baseline through real atomic save writer")
	var save_path: String = world.save_path()
	var before_save: String = FileAccess.get_sha256(save_path)
	world.hud.open_settings_info(true)
	await process_frame
	var panel = world.hud.workspace.find_child("Current523PackSettings",true,false)
	check(panel != null,"523 installer is reachable in production settings")
	if panel != null:
		panel.picker.file_selected.emit(archive)
		while panel.installer.busy: await process_frame
		check(not panel.choose.disabled and not panel.cancel.visible,"installer controls restored")
		check(panel.previews.get_child_count() == 2,"two actual standard PNGs displayed after selection")
		check(panel.status.text.contains("정체 표시 팩은 아래에서 별도 선택"),"raw SP2 storage remains explicitly separate")
		check(panel.status.text.contains("설치 완료"),"install result visible")
	check(not PACK.latest_root().is_empty(),"verified version is committed on disk")
	check(FileAccess.get_sha256(save_path) == before_save,"UI installation preserves original save bytes")
	check(FileAccess.get_sha256(archive) == before_archive,"UI installation preserves original source ZIP")
	world.hud.open_settings_info(true)
	await process_frame
	panel = world.hud.workspace.find_child("Current523PackSettings",true,false)
	check(panel != null and panel.previews.get_child_count() == 2,"reopening retains pending-restart image preview")
	if not capture.is_empty():
		check(DisplayServer.get_name() != "headless","real renderer required for capture")
		if DisplayServer.get_name() != "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(capture) == OK,"actual Main installation result rendered")
	world.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("CURRENT523_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"REAL_STANDARD_PNGS_AND_RAW_STORAGE; NOT_SP2_PLAYBACK"}))
	quit(0 if failures.is_empty() else 1)
