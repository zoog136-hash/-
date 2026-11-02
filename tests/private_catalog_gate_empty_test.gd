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
	await process_frame
	await process_frame
	var label: Label = scene.get_child(0).get_child(0).get_child(1)
	if bool(scene._busy) or not label.text.contains("설치해"):
		push_error("Missing private pack must show setup, not Main/fallback")
		quit(1)
		return
	print("CATALOG_GATE_EMPTY_OK setup_shown no_missing_texture_boot")
	quit(0)
