extends SceneTree
## Exercise PCK export where original .png files are absent and resources use raw bytes.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("L1J_PACKED_ASSETS_FAIL: ", message)

func _run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/l1j/live_visual_bindings.json"))
	var any_installed: bool = false
	var raw_files: Dictionary = {}
	for section: String in ["items","monsters"]:
		for record: Dictionary in source.get(section, []):
			for digest_key: String in (["inventory_sha256","ground_sha256"] if section == "items" else ["sha256"]):
				var raw: String = "res://data/l1j/verified_bytes/%s.l1jpng" % str(record.get(digest_key,""))
				if FileAccess.file_exists(raw):
					any_installed = true
					raw_files[raw] = true
	if not any_installed:
		print("L1J_PACKED_ASSETS_OK bundle_absent=1 actual_export_test=SKIPPED")
		quit(0)
		return
	var script := FileAccess.open("user://packed_probe.gd",FileAccess.WRITE)
	script.store_string("""extends SceneTree
const ASSETS=preload("res://addons/twilight_l1j/twilight_runtime_assets.gd")
func _initialize():
	var bindings=JSON.parse_string(FileAccess.get_file_as_string(ASSETS.PATH))
	var loaded=0
	for binding in bindings.items:
		var record={"sourceId":binding.game_source_id,"name":binding.game_name}
		if ASSETS.item_icon(record,binding.game_name)==null or ASSETS.ground_icon(record,binding.game_name)==null:
			print("PACKED_PROBE_FAIL item ",binding.game_name)
			quit(1)
			return
		loaded+=2
	for binding in bindings.monsters:
		if ASSETS.monster_texture({"name":binding.game_name})==null:
			print("PACKED_PROBE_FAIL monster ",binding.game_name)
			quit(1)
			return
		loaded+=1
	print("PACKED_PROBE_OK original_png_absent=1 loaded=",loaded)
	quit(0 if loaded==14 else 1)
""")
	script.close()
	var project := FileAccess.open("user://packed_project.godot",FileAccess.WRITE)
	project.store_string("config_version=5\n[application]\nconfig/name=\"Private packed asset probe\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
	project.close()
	var packer := PCKPacker.new()
	var output: String = ProjectSettings.globalize_path("user://l1j_probe.pck")
	check(packer.pck_start(output) == OK, "pack start")
	check(packer.add_file("res://project.godot", "user://packed_project.godot") == OK,"packed project")
	check(packer.add_file("res://probe.gd", "user://packed_probe.gd") == OK,"packed probe")
	for file: String in ["res://addons/twilight_l1j/twilight_runtime_assets.gd","res://data/l1j/live_visual_bindings.json"]:
		check(packer.add_file(file,file) == OK,"packed code/manifest")
	for file: String in raw_files:
		check(packer.add_file(file,file) == OK,"packed verified byte source")
	check(packer.flush() == OK,"pack finalization")
	var logs: Array = []
	var status: int = OS.execute(OS.get_executable_path(),["--headless","--main-pack",output,"--script","res://probe.gd"],logs,true)
	var text: String = str(logs)
	check(status == 0 and text.contains("PACKED_PROBE_OK") and not text.contains("ERROR:"),"packed PNG-byte fallback: " + text)
	print("L1J_PACKED_ASSETS_OK actual_export_test=PASS" if failures.is_empty() else "L1J_PACKED_ASSETS_FAIL")
	quit(0 if failures.is_empty() else 1)
