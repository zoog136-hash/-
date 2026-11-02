extends SceneTree
func _initialize() -> void:
	var isolated: String = OS.get_environment("TWILIGHT_PRIVATE_TEST_ROOT")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").simplify_path().begins_with(isolated.simplify_path() + "/"):
		push_error("Run this via tools/test_private_catalog_motion.py; real user data must not be used")
		quit(1)
		return
	call_deferred("run")
func run() -> void:
	var scene: Control = load("res://CatalogPackSetup.tscn").instantiate()
	root.add_child(scene)
	var panel: VBoxContainer = scene.get_child(0).get_child(0)
	var status: Label = panel.get_child(1)
	var cancel: Button = panel.get_child(3)
	var checking := false
	for frame: int in range(10):
		await process_frame
		if status.text.contains(" / 723"):
			checking = true
			break
	if not checking:
		push_error("Verifier never entered checked progress")
		quit(1)
		return
	cancel.pressed.emit()
	await process_frame
	await process_frame
	if not status.text.contains("중단") or bool(scene._busy):
		push_error("Cancel must stop setup before Main handoff")
		quit(1)
		return
	if FileAccess.get_file_as_string("user://save-sentinel") != "preserved":
		quit(1)
		return
	print("CATALOG_GATE_CANCEL_OK no_Main_handoff save_preserved")
	quit(0)
