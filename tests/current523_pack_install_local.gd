extends SceneTree
## Real private input only. Run with isolated XDG_DATA_HOME and --pack=... .
const PACK = preload("res://scripts/resources/current523_pack.gd")
const LEGACY = preload("res://scripts/lineagem_pack_install.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label_text: String) -> void:
	checks += 1
	if not ok: failures.append(label_text)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var archive: String = ""
	var read_only: bool = "--read-installed" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="): archive = argument.trim_prefix("--pack=")
	if archive.is_empty() and not read_only:
		printerr("Specify an authorized --pack=... and an isolated user-data profile.")
		quit(2); return
	var legacy: String = LEGACY.active_manifest()
	if not read_only:
		check(PACK.root_path().is_empty(), "fresh isolated 523 profile")
		var before: String = FileAccess.get_sha256(archive)
		var installer := PACK.new()
		root.add_child(installer)
		var cancel := func(done: int,_total: int) -> void:
			if done == 0: installer.cancelled = true
		installer.progress.connect(cancel)
		var cancelled: Dictionary = await installer.install_zip(archive)
		check(not cancelled.ok and PACK.latest_root().is_empty(), "cancel never activates a version")
		installer.progress.disconnect(cancel)
		var missing: Dictionary = await installer.install_zip("user://source523-missing-test.zip")
		check(not missing.ok and PACK.latest_root().is_empty(), "missing input keeps previous selection")
		var result: Dictionary = await installer.install_zip(archive)
		check(bool(result.get("ok",false)), "actual private source archive installs")
		check(PACK.root_path().is_empty(), "running session keeps its frozen root")
		check(FileAccess.get_sha256(archive) == before, "original ZIP is byte preserved")
		check(not PACK.latest_root().is_empty(), "committed version available for restart")
		var installed: String = PACK.latest_root()
		var wrong_path: String = "user://wrong-current523-input.zip"
		var wrong := FileAccess.open(wrong_path, FileAccess.WRITE)
		wrong.seek(PACK.ARCHIVE_BYTES - 1)
		wrong.store_8(0)
		wrong.close()
		var rejected: Dictionary = await installer.install_zip(wrong_path)
		check(not rejected.ok and str(rejected.error).contains("SHA-256"), "same-size wrong source hash rejected")
		check(PACK.latest_root() == installed, "failed replacement preserves completed version")
		installer.free()
	var selected: String = PACK.root_path() if read_only else PACK.latest_root()
	var receipt: Dictionary = PACK.info(selected)
	check(not receipt.is_empty() and int(receipt.get("files",0)) == 992, "real installed file receipt")
	check(int(receipt.get("raw_sp2_files",0)) == 989 and receipt.get("sprite_playback",true) == false, "raw identities never become decoded animation claims")
	for key: String in PACK.IMAGES:
		var texture: Texture2D = PACK.texture(key,selected)
		check(texture != null, "standard PNG texture loads: " + key)
		if texture != null:
			var image: Image = Image.load_from_file(selected.path_join(PACK.IMAGES[key].member))
			check(texture.get_image().get_data() == image.get_data(), "decoded standard PNG bytes retained: " + key)
	var rows: Variant = JSON.parse_string(FileAccess.get_file_as_string(selected.path_join(PACK.REGISTRY)))
	check(rows is Array and rows.size() == 989, "original registry is physically installed")
	if rows is Array:
		for row: Dictionary in rows:
			check(FileAccess.get_sha256(selected.path_join(row.canonical_package_member)) == row.sha256, "installed SP2 hash: " + str(row.member))
	check(LEGACY.active_manifest() == legacy, "523 component never replaces 508 actor selection")
	print("CURRENT523_INSTALL_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"read_only":read_only,"standard_pngs":2,"raw_sp2":989,"sprite_playback":false}))
	quit(0 if failures.is_empty() else 1)
