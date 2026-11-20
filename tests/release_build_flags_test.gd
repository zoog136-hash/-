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

## Repository files outside the staged CI project are read from the checkout.
func _repo_file(relative: String) -> String:
	for root: String in ["res://", OS.get_environment("GITHUB_WORKSPACE"), ProjectSettings.globalize_path("res://")]:
		if root.is_empty(): continue
		var path: String = root.path_join(relative)
		if FileAccess.file_exists(path): return path
	return ""

func _initialize() -> void:
	check(FLAGS.playtest() == (OS.is_debug_build() or OS.has_feature(FLAGS.PLAYTEST_FEATURE)), "playtest is the debug template or the export feature")
	var presets := ConfigFile.new()
	var presets_path: String = _repo_file("export_presets.cfg")
	check(not presets_path.is_empty() and presets.load(presets_path) == OK, "export presets load")
	for section: String in presets.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"): continue
		if str(presets.get_value(section, "platform", "")) != "Android": continue
		check(str(presets.get_value(section, "custom_features", "")).split(",").has(FLAGS.PLAYTEST_FEATURE), "%s exports the playtest feature" % presets.get_value(section, "name", section))
	var workflow_path: String = _repo_file(".github/workflows/twilight-android-playtest-apk.yml")
	check(not workflow_path.is_empty(), "the APK workflow is found")
	var workflow: String = FileAccess.get_file_as_string(workflow_path) if not workflow_path.is_empty() else ""
	check(workflow.contains('--export-release "Android" build/TWILIGHT_ANDROID_PLAYTEST.apk'), "the playtest APK is a release export")
	## The only debug-template export is the separate diagnostic twin TWILIGHT_DEBUG.apk.
	var debug_exports: int = workflow.count('--export-debug "Android"')
	check(debug_exports == 0 or (debug_exports == 1 and workflow.contains('--export-debug "Android" build/TWILIGHT_DEBUG.apk')), "only the diagnostic TWILIGHT_DEBUG.apk uses the debug template")
	check(workflow.contains("cp build/TWILIGHT_ANDROID_PLAYTEST.apk build/TWILIGHT.apk"), "the published TWILIGHT.apk is the release export")
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
	## 2026-11-20: review buttons are hidden on the phone (developer_ui), while the
	## playtest card collection, the guardian diamond wallet and TestItem coupons
	## stay as they are; the guardian wallet reads as plain "수호성 다이아".
	var hud: String = FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd")
	check(hud.contains("card_draw_button.visible=card_controls.visible and developer_tools_visible()") and hud.contains("if developer_tools_visible() and CARD_RULES.CATEGORIES.has(catalog_category):"), "free test card draws are developer-only")
	var tj: String = FileAccess.get_file_as_string("res://scripts/tj/view.gd")
	check(tj.contains("playtest() and preload(\"res://scripts/boot/build_flags.gd\").developer_ui():\n\t\tvar grant := Button.new()"), "the test coupon grant button is developer-only")
	var guardian: String = FileAccess.get_file_as_string("res://scripts/growth/growth_view.gd") + FileAccess.get_file_as_string("res://scripts/growth/growth_runtime.gd")
	check(guardian.contains("else \"수호성 다이아 %d\")") and guardian.contains("else \"수호성 다이아 +%d\")") and guardian.contains("else \"\\n수호성 다이아 %d 사용\")"), "the guardian diamond wallet keeps working with player wording")
	var coupons: String = FileAccess.get_file_as_string("res://scripts/tj/coupon_service.gd")
	check(coupons.contains("not preload(\"res://scripts/boot/build_flags.gd\").playtest()"), "TestItem coupons keep the playtest rule")
	var profile = load("res://scripts/characters/save_profile.gd")
	check(profile.full_cards_for(PackedStringArray(), "Android", true) and str(profile.base_for(PackedStringArray(), "Android", true)) == "user://twilight_full_cards_test_v1.json", "the Android playtest save namespace is unchanged")
	print("RELEASE_BUILD_FLAGS_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
