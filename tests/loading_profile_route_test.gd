extends SceneTree
## Headless dispatch/ABI tests. Optional installed profile is exercised through
## its real static API; this is not GPU, map or original-art validation.
const LOADER = preload("res://scripts/boot/loading_screen.gd")
class Allow extends RefCounted:
	static func allows_roster() -> bool: return true
class Deny extends RefCounted:
	static func allows_roster() -> bool: return false
class Missing extends RefCounted:
	static func another_api() -> bool: return true
class InstanceOnly extends RefCounted:
	func allows_roster() -> bool: return true
class RequiredArgument extends RefCounted:
	static func allows_roster(_required: bool) -> bool: return true
class WrongType extends RefCounted:
	static func allows_roster() -> String: return "false"
var failures: Array[String] = []
var checks: int = 0
var observations: Dictionary = {}
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("LOADING_PROFILE_ROUTE_FAIL ", label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	for headless: bool in [false,true]:
		for exists: bool in [false,true]:
			for allowed: bool in [false,true]:
				var expected: String = LOADER.CHARACTERS if not headless and exists and allowed else LOADER.MAIN
				check(LOADER.destination_for(headless,exists,allowed) == expected, "three-input destination truth table %s/%s/%s" % [headless,exists,allowed])
	check(LOADER._profile_allows(Allow), "proper static Boolean API admits roster")
	check(not LOADER._profile_allows(Deny), "proper static API can reject roster")
	check(not LOADER._profile_allows(null), "unloadable existing profile fails closed")
	check(not LOADER._profile_allows(Missing), "missing API fails closed")
	check(not LOADER._profile_allows(InstanceOnly), "instance method is not a static profile API")
	check(not LOADER._profile_allows(RequiredArgument), "incompatible static arguments fail closed")
	check(not LOADER._profile_allows(WrongType), "non-Boolean static result fails closed")
	check(LOADER.initial_destination() == LOADER.MAIN, "actual headless startup remains Main")
	var exists: bool = ResourceLoader.exists(LOADER.CHARACTER_PROFILE_PATH)
	observations["profile_present"] = exists
	observations["user_args"] = Array(OS.get_cmdline_user_args())
	observations["debug"] = OS.is_debug_build()
	if not exists:
		check(LOADER._roster_allowed(), "main without optional profile keeps previous admission")
	else:
		var profile: Script = load(LOADER.CHARACTER_PROFILE_PATH) as Script
		check(profile != null, "actual optional profile script loads")
		if profile != null:
			var expected: bool = bool(profile.call("allows_for",OS.get_cmdline_user_args(),OS.is_debug_build()))
			observations["actual_profile_allows"] = expected
			var namespace_before: String = str(profile.call("current_base_path"))
			check(LOADER._profile_allows(profile) == expected, "actual module static call matches current CLI/debug policy")
			check(LOADER._roster_allowed() == expected, "dynamic optional-module admission matches actual profile")
			for flag: String in ["--base508-source-test","--aden523-review","--png-review"]:
				for debug: bool in [false,true]:
					var allowed: bool = bool(profile.call("allows_for",PackedStringArray([flag]),debug))
					check(not allowed and LOADER.destination_for(false,true,allowed) == LOADER.MAIN, "graphical review bypass remains authoritative "+flag+str(debug))
			for debug: bool in [false,true]:
				var allowed: bool = bool(profile.call("allows_for",PackedStringArray(["--growth-lab"]),debug))
				check(allowed == not debug and LOADER.destination_for(false,true,allowed) == (LOADER.MAIN if debug else LOADER.CHARACTERS), "growth-lab obeys debug policy "+str(debug))
			for flags: PackedStringArray in [PackedStringArray(),PackedStringArray(["--playtest-full-cards"]),PackedStringArray(["--native-png-maps","--playtest-full-cards"])]:
				var allowed: bool = bool(profile.call("allows_for",flags,true))
				check(allowed and LOADER.destination_for(false,true,allowed) == LOADER.CHARACTERS, "normal and isolated full-card namespaces retain roster "+str(flags))
			check(str(profile.call("base_for",PackedStringArray(["--playtest-full-cards"]),"Linux",true,false,false)) == "user://twilight_full_cards_test_v1.json", "full-card namespace remains separate")
			check(str(profile.call("base_for",PackedStringArray(["--native-png-maps","--playtest-full-cards"]),"Linux",true,false,false)) == "user://twilight_native_png_full_cards_test_v1.json", "native-PNG full-card namespace remains separate")
			check(str(profile.call("current_base_path")) == namespace_before, "admission changes no current save namespace")
	print("LOADING_PROFILE_ROUTE_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"scope":"headless_script_dispatch_static_API_real_optional_profile_flags_no_GPU_or_original_media"}))
	quit(0 if failures.is_empty() else 1)
