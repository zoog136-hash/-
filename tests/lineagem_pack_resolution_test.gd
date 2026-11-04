extends SceneTree
## Synthetic routing/version fixtures only; no original art or delivery claim.
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
const SOURCE = preload("res://scripts/lineagem_base508.gd")
const PREVIEW = preload("res://scripts/animation/original_source_preview.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label_text: String) -> void:
	checks += 1
	if not ok: failures.append(label_text)

func write_json(path: String, value: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if "--resolution-child" in arguments:
		run_child(arguments)
	else:
		var selection: Dictionary = INSTALL.preview_selection(PackedStringArray(["--unrelated", "--lineagem-original-preview=/first/manifest.json", "--lineagem-original-preview=/last/custom.json"]))
		check(selection.specified and selection.path == "/last/custom.json", "last explicit path preserved")
		check(not INSTALL.preview_selection(PackedStringArray()).specified, "default selection remains optional")
		check(INSTALL.preview_selection(PackedStringArray(["--lineagem-original-preview="])).specified, "empty explicit path never becomes default")
		check(INSTALL.resolve_file("", "ui/test.png").is_empty(), "empty root cannot resolve into project files")
		var folder: String = "user://resource-resolution-fixtures/" + str(Time.get_ticks_usec())
		var directions: Array = []
		for direction: int in range(8):
			directions.append([{"duration":1.0/24.0, "source_ticks":1, "source_group":0, "source_frame":0, "layers":[{"path":"ui/test.png", "offset":[0,0], "layer_id":1}]}])
		var record: Dictionary = {"body_id":1, "tracks":{"idle":{"fps":24, "loop":true, "directions":directions}}}
		var manifest: Dictionary = {"schema":1, "source_snapshot":"base508", "mode":"literal_body_shadow_inspection_only", "records":{"transform:267":record, "overlay:777":record}, "source_spell_bindings":{"1":{"EffectSpriteID":777}}}
		var valid: String = folder.path_join("selected/custom-name.json")
		write_json(valid, manifest)
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color.GREEN)
		DirAccess.make_dir_recursive_absolute(folder.path_join("selected/ui"))
		check(image.save_png(folder.path_join("selected/ui/test.png")) == OK, "synthetic selected UI fixture")
		manifest.source_snapshot = "patch523"
		var unsupported: String = folder.path_join("unsupported/custom-name.json")
		write_json(unsupported, manifest)
		DirAccess.make_dir_recursive_absolute(folder.path_join("unsupported/ui"))
		check(image.save_png(folder.path_join("unsupported/ui/test.png")) == OK, "unsupported fixture retains otherwise playable pixels")
		for scenario: Array in [[valid,"ready"], [unsupported,"unsupported"], [folder.path_join("missing.json"),"missing"], ["","missing"]]:
			var output: Array = []
			var code: int = OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/lineagem_pack_resolution_test.gd", "--", "--resolution-child", "--expected=" + scenario[1], "--lineagem-original-preview=" + scenario[0]]), output, true)
			var lines: String = "\n".join(output)
			check(code == 0 and lines.contains("LINEAGEM_PACK_RESOLUTION_OK") and not lines.contains("SCRIPT ERROR:") and not lines.contains("ERROR:"), "isolated selection " + scenario[1] + ": " + lines)
			for line: String in lines.split("\n"):
				if line.begins_with("LINEAGEM_PACK_RESOLUTION_OK"): print("SELECTION_CHILD ", scenario[1], " ", line)
	finish()

func run_child(arguments: PackedStringArray) -> void:
	var expected: String = ""
	for argument: String in arguments:
		if argument.begins_with("--expected="): expected = argument.trim_prefix("--expected=")
	var selected: String = INSTALL.preview_selection(arguments).path
	check(INSTALL.active_manifest() == selected, "explicit manifest wins without filename rewriting or fallback")
	check(INSTALL.active_root() == selected.get_base_dir(), "body and UI share selected root")
	var problem: String = INSTALL.active_manifest_problem()
	if expected == "ready":
		check(problem.is_empty(), "supported manifest accepted")
		check(SOURCE.asset_path("test.png") == selected.get_base_dir().path_join("ui/test.png"), "UI uses selected pack")
		var icon: Texture2D = SOURCE.icon({"source":"lineagem_base508", "source_ui_assets":{"DisplayBaseAssetID":{"path":"test.png"}}})
		check(icon != null and icon.get_image().get_pixel(0,0) == Color.GREEN, "actual UI texture comes from selected bytes")
		var actor := PREVIEW.new()
		root.add_child(actor)
		check(actor.configure("transform:267", selected), "supported actor actually loads selected synthetic pixels")
		actor.advance_source(0.01, "idle", 0, 0, false)
		check(actor.last_source_frame >= 0, "supported actor samples selected frame")
		actor.free()
	else:
		check(not problem.is_empty(), "missing/unsupported pack reported")
		check(SOURCE.asset_path("test.png").is_empty(), "no default UI from another pack")
		if expected == "unsupported": check(problem.contains("base508"), "snapshot mismatch explained")
		var actor := PREVIEW.new()
		root.add_child(actor)
		check(not actor.configure("transform:267", selected), "unsupported/missing body refused")
		check(not actor.notify_source_spell_event(1, "effect", Vector2.ZERO, 0, selected), "unsupported/missing spell refused")
		actor.free()
	var panel := preload("res://scripts/ui/lineagem_pack_settings.gd").new()
	root.add_child(panel)
	check(panel.status.text.contains(problem) if not problem.is_empty() else panel.status.text.contains("연결됨"), "settings reports actual selection")
	panel.free()

func finish() -> void:
	print("LINEAGEM_PACK_RESOLUTION_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty(): print("LINEAGEM_PACK_RESOLUTION_OK checks=", checks)
	else: printerr("LINEAGEM_PACK_RESOLUTION_FAILED ", failures)
	quit(0 if failures.is_empty() else 1)
