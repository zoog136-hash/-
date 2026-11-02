extends SceneTree
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--install-monster-zip="): path = argument.trim_prefix("--install-monster-zip=")
	if path.is_empty(): push_error("Missing private install ZIP argument");quit(1);return
	var installer := INSTALL.new()
	root.add_child(installer)
	var result: Dictionary = await installer.install_zip(path)
	print("BASE508_MONSTER_INSTALL ", JSON.stringify(result))
	installer.free()
	quit(0 if bool(result.get("ok", false)) else 1)
