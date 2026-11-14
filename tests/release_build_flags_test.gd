extends SceneTree
## The phone APK is a release export with the playtest feature: playtest tools
## and the full-card save namespace must not depend on the debug template.
##   godot --headless --path <repo> --script res://tests/release_build_flags_test.gd
const FLAGS = preload("res://scripts/boot/build_flags.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("RELEASE_BUILD_FLAGS_FAIL: " + label)

func _scripts(dir: String, out: Array) -> void:
	var access := DirAccess.open(dir)
	if access == null: return
	for name: String in access.get_files():
		if name.ends_with(".gd"): out.append(dir.path_join(name))
	for sub: String in access.get_directories(): _scripts(dir.path_join(sub), out)

func _initialize() -> void:
	check(FLAGS.playtest() == (OS.is_debug_build() or OS.has_feature(FLAGS.PLAYTEST_FEATURE)), "playtest is the debug template or the export feature")
	var presets := ConfigFile.new()
	check(presets.load("res://export_presets.cfg") == OK, "export presets load")
	for section: String in presets.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"): continue
		if str(presets.get_value(section, "platform", "")) != "Android": continue
		check(str(presets.get_value(section, "custom_features", "")).split(",").has(FLAGS.PLAYTEST_FEATURE), "%s exports the playtest feature" % presets.get_value(section, "name", section))
	var workflow: String = FileAccess.get_file_as_string("res://.github/workflows/twilight-android-playtest-apk.yml")
	check(workflow.contains('--export-release "Android"') and not workflow.contains('--export-debug "Android"'), "the playtest APK is a release export")
	check(workflow.contains("GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$GITHUB_WORKSPACE/tools/android/twilight-playtest.keystore"), "the release export keeps the fixed playtest signature")
	var files: Array = []
	_scripts("res://scripts", files)
	var left: Array = []
	for path: String in files:
		if path.ends_with("build_flags.gd"): continue
		var text: String = FileAccess.get_file_as_string(path)
		var at: int = text.find("OS.is_debug_build()")
		while at >= 0:
			var line_start: int = text.rfind("\n", at) + 1
			var func_at: int = text.rfind("\nfunc ", at)
			var owner: String = text.substr(func_at + 1, 40) if func_at >= 0 else ""
			if not owner.begins_with("func _perf_log"): left.append(path.get_file() + ":" + text.substr(line_start, at - line_start + 20).strip_edges())
			at = text.find("OS.is_debug_build()", at + 1)
	check(left.is_empty(), "only diagnostics use the debug template directly: " + str(left))
	var profile = load("res://scripts/characters/save_profile.gd")
	check(profile.full_cards_for(PackedStringArray(), "Android", true) and str(profile.base_for(PackedStringArray(), "Android", true)) == "user://twilight_full_cards_test_v1.json", "the Android playtest save namespace is unchanged")
	print("RELEASE_BUILD_FLAGS_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
