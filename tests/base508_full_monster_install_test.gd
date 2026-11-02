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
	if bool(result.get("ok", false)):
		var pack_root: String = str(result.root)
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(pack_root.path_join("manifest.json")))
		var header: Dictionary = {"npc_ids": manifest.records.keys().map(func(value): return int(value))}
		var changed: Dictionary = manifest.duplicate(true)
		var first: String = "248"
		changed.records[first]["territory_link_id"] = 99999999
		if INSTALL.validate_monster_payload(pack_root, changed, header).is_empty():
			result["ok"] = false
			push_error("Invalid source territory accepted")
		changed = manifest.duplicate(true)
		changed.records[first]["sprite_id"] = 99999999
		if INSTALL.validate_monster_payload(pack_root, changed, header).is_empty():
			result["ok"] = false
			push_error("Invalid source sprite accepted")
		print("BASE508_MONSTER_INSTALL_CONTEXT_REJECTIONS ", bool(result.get("ok", false)))
	installer.free()
	quit(0 if bool(result.get("ok", false)) else 1)
