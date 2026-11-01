extends SceneTree
## Optional real private-pack install/load. Does not assert visual equivalence.
const INSTALLER = preload("res://scripts/lineagem_pack_install.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path: String = ""
	var load_installed: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pack="): path = argument.trim_prefix("--pack=")
		if argument == "--load-installed": load_installed = true
	if path.is_empty() and not load_installed:
		push_error("Specify --pack=authorized-offline-install.zip; use an isolated XDG_DATA_HOME.")
		quit(2)
		return
	var installer := INSTALLER.new()
	root.add_child(installer)
	var bucket: Array = [-1]
	installer.progress.connect(func(done: int, total: int) -> void:
		if int(done / 25000) > bucket[0]:
			bucket[0] = int(done / 25000)
			print("INSTALL_PROGRESS ", done, "/", total))
	var result: Dictionary = {"ok":true,"mode":"load_existing_only"} if load_installed else await installer.install_zip(path)
	if not result.ok:
		push_error(JSON.stringify(result))
		quit(1)
		return
	INSTALLER._session_root = ""
	var selected: String = INSTALLER.active_root()
	var actor := preload("res://scripts/animation/original_source_preview.gd").new()
	root.add_child(actor)
	var loaded: bool = actor.configure("transform:267", selected.path_join("manifest.json"))
	actor.advance_source(0.1, "walk", 0, 0, false)
	var icon_loaded: bool = false
	var source := preload("res://scripts/lineagem_base508.gd")
	for card: Dictionary in source.cards().catalog["변신"]:
		if source.icon(card) != null:
			icon_loaded = true
			break
	var effect_loaded: bool = actor.spawn_source_overlay(4221, 0)
	print("NATIVE_INSTALL_LOAD ", JSON.stringify({"installed":result,"selected_root":selected,"girtas_loaded":loaded,"frame":actor.last_source_frame,"icon_loaded":icon_loaded,"event_effect_loaded":effect_loaded,"android":false,"visual_equivalence":"not_tested"}))
	quit(0 if loaded and actor.last_source_frame >= 0 and icon_loaded and effect_loaded else 1)
