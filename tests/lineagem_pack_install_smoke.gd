extends SceneTree
## Safety/load check; fixture is not original art or visual equivalence evidence.
const INSTALLER = preload("res://scripts/lineagem_pack_install.gd")
var failures: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label_text: String) -> void:
	if not value:
		failures += 1
		push_error(label_text)
func run() -> void:
	var installer := INSTALLER.new()
	root.add_child(installer)
	var save := FileAccess.open("user://pack-test-save-sentinel", FileAccess.WRITE)
	save.store_string("preserved")
	save.close()
	var before: String = INSTALLER.active_root()
	var base: String = "user://lineagem_pack_test_inputs/"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fixtures="): base = argument.trim_prefix("--fixtures=").path_join("") + "/"
	for unsafe: String in ["../save.dat", "/tmp/x", "a/../../x", "a\\b", "C:/x", "a//b", "a/./b"]:
		check(not INSTALLER.safe_relative(unsafe), "path rejected: " + unsafe)
	for name: String in ["corrupt", "traversal", "missing", "duplicate"]:
		var rejected: Dictionary = await installer.install_zip(base + name + ".zip")
		check(not rejected.ok, "reject " + name)
		INSTALLER._session_root = ""
		check(INSTALLER.active_root() == before, "old root preserved after " + name)
	var stop := func(done: int, _total: int) -> void:
		if done == 0: installer.cancelled = true
	installer.progress.connect(stop)
	var cancelled: Dictionary = await installer.install_zip(base + "valid.zip")
	check(not cancelled.ok, "cancelled install")
	INSTALLER._session_root = ""
	check(INSTALLER.active_root() == before, "interrupted staging ignored on restart")
	installer.progress.disconnect(stop)
	var installed: Dictionary = await installer.install_zip(base + "valid.zip")
	check(installed.ok, "valid install")
	check(INSTALLER.active_root() == before, "running session keeps existing assets")
	INSTALLER._session_root = ""
	check(INSTALLER.active_root() == installed.get("root", ""), "next session selects committed version")
	check(FileAccess.file_exists(INSTALLER.active_root().path_join("manifest.json")), "runtime manifest accessible")
	var full_root: String = INSTALLER.active_root()
	var wrong_base: Dictionary = await installer.install_zip(base + "addon_wrong_base.zip")
	check(not wrong_base.ok, "addon rejects wrong base before activation")
	var addon: Dictionary = await installer.install_zip(base + "addon.zip")
	check(addon.ok, "valid addon installs")
	check(INSTALLER.active_root() == full_root, "addon keeps current-session root")
	INSTALLER._session_root = ""
	var addon_root: String = INSTALLER.active_root()
	check(addon_root == addon.get("root", ""), "addon activated next session")
	check(INSTALLER.resolve_file(addon_root, "actors/test.json") == full_root.path_join("actors/test.json"), "unchanged actor resolves through base")
	check(INSTALLER.resolve_file(addon_root, "overlays/new.json") == addon_root.path_join("overlays/new.json"), "new effect resolves through addon")
	check(INSTALLER.resolve_file(addon_root, "../pack-test-save-sentinel").is_empty(), "resolver rejects traversal")
	var preference := FileAccess.open(full_root.path_join("playback_settings.json"), FileAccess.WRITE)
	preference.store_string('{"mode":"strict"}')
	preference.close()
	check(preload("res://scripts/animation/source_playback_policy.gd").mode(addon_root) == "strict", "addon preserves base strict preference")
	check(FileAccess.get_file_as_string("user://pack-test-save-sentinel") == "preserved", "save preserved")
	var panel := preload("res://scripts/ui/lineagem_pack_settings.gd").new()
	root.add_child(panel)
	await process_frame
	check(panel.get_node_or_null("InstallLineageMOfflinePack") != null, "settings install action exists")
	print("LINEAGEM_PACK_INSTALL_SMOKE failures=", failures, " root=", INSTALLER.active_root())
	quit(1 if failures else 0)
