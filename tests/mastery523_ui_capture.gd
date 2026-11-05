extends SceneTree
## Manual OpenGL review; isolated profile and separately supplied source pack.
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("MASTERY_UI_FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world),"actual Main class selection")
	world.player.set_physics_process(false)
	var path: String = OS.get_environment("TWILIGHT_MASTERY523_PACK")
	var runtime = world.weapon_mastery
	check(not path.is_empty() and runtime.core.load_pack(path,FileAccess.get_sha256(path)),"actual523 source bytes")
	if runtime.core.levels.is_empty(): quit(1); return
	runtime.enabled = true
	var weapon: int = int(runtime.core.levels.keys()[0])
	var group: int = 0
	for id: int in runtime.core.options:
		if int(runtime.core.options[id][weapon].level) == 2 and str(runtime.core.types[int(runtime.core.bonuses[int(runtime.core.options[id][weapon].BonusID)].BonusTypeID)].Name) == "PVPMeleeAdditionDamage": group = id; break
	check(group != 0,"source PvP option found")
	var grade: int = int(runtime.core.tables.MasteryGradeView[0].GradeID)
	runtime.state.weapons[str(weapon)] = {"points":str(int(runtime.core.levels[weapon][2].CumulativePoint)),"options":[{"group_id":group}],"colors":{"2":[grade,grade,grade,grade]},"locks":{}}
	world.job_class = "요정"
	world.hud._navigate("weapon_mastery")
	var view = runtime.view
	view.selected_weapon = weapon
	view.target_weapon = 3
	view.refresh()
	check(view.visible and view.find_child("MasteryTransferTarget",true,false) != null,"actual HUD transfer preview selection")
	var found: bool = false
	for child: Node in view.body.get_children():
		if child is Label and child.get_meta("mastery_bonus_type","") == "PVPRangeAdditionDamage": found = true
	check(found,"destination preview changes original BonusType")
	var output: String = OS.get_environment("TWILIGHT_MASTERY_CAPTURE_DIR")
	check(not output.is_empty(),"explicit capture destination")
	DirAccess.make_dir_recursive_absolute(output)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/mastery-top.png") == OK,"actual OpenGL top capture")
	var button = view.find_child("MasteryLock_2_0",true,false)
	button.toggled.emit(true)
	check(runtime.core.record(runtime.state,weapon).locks.get("2",[false])[0],"UI lock event writes actual save")
	view.get_child(0).scroll_vertical = 10000
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output+"/mastery-preview.png") == OK,"actual OpenGL preview capture")
	print("MASTERY_UI_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_OPENGL; NATIVE_UI_EQUIVALENCE_NOT_CLAIMED"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
