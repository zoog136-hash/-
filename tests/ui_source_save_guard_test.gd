extends "res://tests/integrated_ui_test.gd"

# A missing original-map pack must not let the UI overwrite a saved character
# or report "saved" and quit. All files live in this test's isolated user dir.
func _run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	hud = world.hud
	check(CLASS_QA.enter_game(world),"starter character enters world")
	world.set_process(false)
	world.field_population.set_process(false)
	world.save_timer = -100000
	check(world._save_game(true),"real local save succeeds")
	var original: String = FileAccess.get_file_as_string(world.SAVE_PATH)
	var fixture: Dictionary = JSON.parse_string(original)
	fixture["map_id"] = "l1_missing_test_pack"
	var file := FileAccess.open(world.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	var checksum: String = FileAccess.get_sha256(world.SAVE_PATH)
	world._load_game(true)
	check(world.source_save_blocked,"missing map load activates existing pack protection")
	check(not world._save_game(true) and FileAccess.get_sha256(world.SAVE_PATH) == checksum,"save command reports failure and preserves protected bytes")
	hud._confirm_exit()
	await frames()
	await click(hud.modal.find_child("ConfirmAction",true,false))
	check(not is_instance_valid(hud.modal) and FileAccess.get_sha256(world.SAVE_PATH) == checksum,"confirmed save-and-exit stays in game when save is blocked")
	file = FileAccess.open(world.SAVE_PATH,FileAccess.WRITE)
	file.store_string(original)
	file.close()
	world._load_game(true)
	check(not world.source_save_blocked and world._save_game(true),"valid save recovery restores normal save result")
	world.queue_free()
	await frames()
	print("UI_SOURCE_SAVE_GUARD_OK: %d checks" % checks.size() if failures.is_empty() else "UI_SOURCE_SAVE_GUARD_FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
