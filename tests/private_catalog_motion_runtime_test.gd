extends SceneTree
const Store = preload("res://scripts/resources/private_catalog_motion.gd")
const NoSpace = preload("res://tests/private_catalog_no_space.gd")
var checks := 0
func check(value: bool, label: String) -> void:
	if not value: push_error(label); quit(1); assert(false, label)
	checks += 1
func _initialize() -> void:
	var isolated: String = OS.get_environment("TWILIGHT_PRIVATE_TEST_ROOT")
	if isolated.is_empty() or not ProjectSettings.globalize_path("user://").simplify_path().begins_with(isolated.simplify_path() + "/"):
		push_error("Run this via tools/test_private_catalog_motion.py; real user data must not be used")
		quit(1)
		return
	call_deferred("run")
func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	check(args.size() == 2, "ZIP and unchanged source root required")
	var zip_path: String = args[0]
	var source_root: String = args[1]
	var index: Dictionary = Store.index_data()
	check(index.size() > 0 and index.files.size() == 723, "pinned index")
	check(index.frame_count == 41442, "frame count unchanged")
	check(Store.validate_zip(zip_path, index), "bounded ZIP inventory")
	check(not Store.safe_path("assets/catalog_motion/../escape.webp"), "traversal")
	check(Store.texture("res://assets/catalog_motion/transform/393.webp") == null, "no fake installed art")
	var save := FileAccess.open("user://save-sentinel", FileAccess.WRITE)
	save.store_string("preserved"); save.close()
	var save_sha: String = FileAccess.get_sha256("user://save-sentinel")
	var installer := Store.new()
	root.add_child(installer)
	var result: Dictionary = await installer.install_zip(zip_path)
	check(result.ok and result.files == 723, "actual installation")
	var installed: String = Store.active_root()
	check(not installed.is_empty(), "activated receipt")
	var pixels := 0
	for relative: String in index.files:
		var texture: Texture2D = Store.texture("res://" + relative)
		var source: Image = Image.load_from_file(source_root.path_join(relative))
		check(texture != null and source != null and not source.is_empty(), "actual atlas loaded")
		var actual: Image = texture.get_image()
		check(actual.get_size() == source.get_size() and actual.get_format() == source.get_format() and actual.get_data() == source.get_data(), "source pixels preserved: " + relative)
		pixels += actual.get_width() * actual.get_height()
		await process_frame
	var damaged: String = str(index.files.keys()[0])
	var writer := FileAccess.open(installed.path_join(damaged), FileAccess.WRITE)
	writer.store_buffer(PackedByteArray([0, 1, 2])); writer.close()
	check(Store.texture("res://" + damaged) == null, "damaged file is rejected")
	writer = FileAccess.open(installed.path_join(damaged), FileAccess.WRITE)
	writer.store_buffer(FileAccess.get_file_as_bytes(source_root.path_join(damaged))); writer.close()
	check(Store.texture("res://" + damaged) != null, "verified unchanged file restored")
	var bad := FileAccess.open("user://bad.zip", FileAccess.WRITE)
	bad.store_string("not a pack"); bad.close()
	result = await installer.install_zip("user://bad.zip")
	check(not result.ok and Store.active_root() == installed, "bad ZIP keeps previous pack")
	var blocked := NoSpace.new()
	root.add_child(blocked)
	result = await blocked.install_zip(zip_path)
	check(not result.ok and Store.active_root() == installed, "insufficient space preserves active version")
	installer.progress.connect(func(done: int, _total: int):
		if done >= 16: installer.cancelled = true)
	result = await installer.install_zip(zip_path)
	check(not result.ok and Store.active_root() == installed, "cancel does not activate partial pack")
	check(FileAccess.get_sha256("user://save-sentinel") == save_sha, "save preserved")
	var stage_found := false
	for name: String in DirAccess.get_directories_at(Store.STORE):
		if name.begins_with("staging-"): stage_found = true
	check(not stage_found, "failed staging removed")
	print(JSON.stringify({"passed":checks, "atlases":723, "frames":41442, "pixels_compared":pixels, "engine":Engine.get_version_info().string, "scope":"isolated private-loader/installer, not full game or Android"}))
	quit(0)
