extends RefCounted
## One namespace and migration-pointer authority for boot, lobby and World.
## Debug grants stay in their existing isolated account; review modes bypass it.
const DEFAULT_PATH := "user://twilight_v20_save.json"
const LEGACY = preload("res://scripts/maps/legacy_layout_policy.gd")

static func namespace_for(source_test: bool, growth_lab: bool, full_cards: bool, native_png: bool) -> String:
	if source_test: return "user://base508_source_test_never_written.json"
	if growth_lab: return "user://twilight_growth_lab_v1.json"
	if full_cards: return "user://twilight_native_png_full_cards_test_v1.json" if native_png else "user://twilight_full_cards_test_v1.json"
	return "user://twilight_native_png_save.json" if native_png else DEFAULT_PATH

static func full_cards_for(args: PackedStringArray, platform: String, debug: bool, editor_hint: bool = false) -> bool:
	return debug and not editor_hint and (platform == "Android" or "--playtest-full-cards" in args)

static func base_for(args: PackedStringArray, platform: String, debug: bool, editor_hint: bool = false, validation_script: bool = false) -> String:
	var native: bool = "--native-png-maps" in args and not (validation_script and "--legacy-map-layouts" in args)
	return namespace_for("--base508-source-test" in args, debug and "--growth-lab" in args, full_cards_for(args, platform, debug, editor_hint), native)

static func full_cards_active() -> bool:
	return full_cards_for(OS.get_cmdline_user_args(), OS.get_name(), preload("res://scripts/boot/build_flags.gd").playtest(), Engine.is_editor_hint())

static func current_base_path() -> String:
	return base_for(OS.get_cmdline_user_args(), OS.get_name(), preload("res://scripts/boot/build_flags.gd").playtest(), Engine.is_editor_hint(), LEGACY.validation_script())

static func allows_for(args: PackedStringArray, debug: bool) -> bool:
	return "--base508-source-test" not in args and "--aden523-review" not in args and "--png-review" not in args and not (debug and "--growth-lab" in args)

static func allows_roster() -> bool:
	return allows_for(OS.get_cmdline_user_args(), preload("res://scripts/boot/build_flags.gd").playtest())

static func resolve(base: String) -> Dictionary:
	# No heavy map classes are needed on ordinary launches without a pointer.
	if not FileAccess.file_exists(base + ".source-map-current.json"):
		return {"ok":true, "path":base, "problem":""}
	var resolver: Script = load("res://scripts/maps/source_map_save_migration.gd")
	var result: Dictionary = resolver.call("resolve", base)
	if not result.get("ok",false):
		return {"ok":false, "path":"", "problem":str(result.get("error","저장 이전 경로를 확인하지 못했습니다."))}
	return {"ok":true, "path":str(result.path), "problem":""}

static func resolve_current() -> Dictionary:
	return resolve(current_base_path())
