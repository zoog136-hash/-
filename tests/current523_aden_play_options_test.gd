extends SceneTree
const OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _initialize() -> void:
	if FileAccess.file_exists(OPTIONS.PATH):
		push_error("Use an isolated empty profile for play options tests")
		quit(1)
		return
	var initial: Dictionary = OPTIONS.read()
	check(not initial.enabled and initial.navigation_profile == OPTIONS.NONE, "experimental navigation defaults off")
	check(OPTIONS.validate({"enabled":true,"navigation_profile":OPTIONS.NONE}).is_empty(), "active mode requires explicit local profile")
	var valid: Dictionary = {"enabled":true,"navigation_profile":OPTIONS.LEGACY,"offset_x":0,"offset_y":12,"raw_root":"/private/raw","tile_root":"/private/tiles"}
	check(OPTIONS.validate(valid) == valid, "explicit local profile and visual correction accept")
	for key: String in ["offset_x", "offset_y"]:
		for number: Variant in [-49, 49, 0.5, INF, NAN, true, "12"]:
			var bad: Dictionary = valid.duplicate()
			bad[key] = number
			check(OPTIONS.validate(bad).is_empty(), "invalid visual correction rejects: " + key)
	for changes: Dictionary in [{"enabled":1}, {"navigation_profile":"M_RAW_U16_IS_PC_MASK"}, {"raw_root":""}, {"tile_root":123}]:
		var bad: Dictionary = valid.duplicate()
		bad.merge(changes, true)
		check(OPTIONS.validate(bad).is_empty(), "invalid or unverified navigation selection rejects")
	check(not OPTIONS.qualify(null).is_empty(), "no world fails safely")
	var sentinel := FileAccess.open("user://play-options-save-sentinel.bin", FileAccess.WRITE)
	sentinel.store_string("unmodified game state")
	sentinel.close()
	var sha: String = FileAccess.get_sha256("user://play-options-save-sentinel.bin")
	check(OPTIONS.write(valid) == OK and OPTIONS.read() == valid, "separate preferences remember explicit profile and roots")
	var config := ConfigFile.new()
	config.load(OPTIONS.PATH)
	config.set_value("other", "keep", 523)
	config.save(OPTIONS.PATH)
	var before: String = FileAccess.get_sha256(OPTIONS.PATH)
	check(OPTIONS.write({"enabled":true}) == ERR_INVALID_PARAMETER and FileAccess.get_sha256(OPTIONS.PATH) == before, "invalid update preserves preference bytes")
	valid.enabled = false
	check(OPTIONS.write(valid) == OK and not OPTIONS.read().enabled, "turning off retains explicit profile for the next manual entry")
	config.load(OPTIONS.PATH)
	check(config.get_value("other", "keep", 0) == 523, "unrelated preference fields survive")
	check(FileAccess.get_sha256("user://play-options-save-sentinel.bin") == sha, "play preferences never write game saves")
	var source: Dictionary = valid.duplicate(true)
	source.merge({"enabled":true,"navigation_profile":OPTIONS.SOURCE,"allowed_raw_words":[0,4,8,12,32],"source_position":[33342.5,33168.5],"portal_contract":"/private/source-portals.json"},true)
	check(OPTIONS.validate(source)==source,"source profile preserves separate exact-word policy and fractional source cursor")
	for changes: Dictionary in [{"allowed_raw_words":[]},{"allowed_raw_words":[65535]},{"allowed_raw_words":[true]},{"allowed_raw_words":[4.5]},{"source_position":[INF,1]},{"source_position":[1]},{"source_position":[-1,1]},{"portal_contract":12}]:
		var bad: Dictionary = source.duplicate(true); bad.merge(changes,true)
		check(OPTIONS.validate(bad).is_empty(),"unsafe source policy or cursor rejects: "+str(changes))
	check(OPTIONS.write(source)==OK and OPTIONS.read()==source,"source policy and cursor survive own settings readback")
	var source_sha: String = FileAccess.get_sha256(OPTIONS.PATH)
	var bad_source: Dictionary = source.duplicate(true); bad_source.source_position=[NAN,1]
	check(OPTIONS.write(bad_source)==ERR_INVALID_PARAMETER and FileAccess.get_sha256(OPTIONS.PATH)==source_sha,"invalid source cursor preserves accepted settings bytes")
	check(FileAccess.get_sha256("user://play-options-save-sentinel.bin")==sha,"source preferences leave ordinary game-save bytes unchanged")
	var generic: Dictionary=source.duplicate(true)
	generic.merge({"navigation_profile":OPTIONS.GENERIC,"source_manifest_sha256":"a".repeat(64),"tile_manifest_sha256":"b".repeat(64),"native_land_id":1,"source_position":[32668.5,32803.5]},true)
	check(OPTIONS.validate(generic)==generic,"generic native Land profile keeps explicit resource pins and separate cursor")
	for changes: Dictionary in [{"source_manifest_sha256":""},{"source_manifest_sha256":"g".repeat(64)},{"tile_manifest_sha256":17},{"native_land_id":true},{"native_land_id":-1},{"native_land_id":1.5}]:
		var bad: Dictionary=generic.duplicate(true); bad.merge(changes,true)
		check(OPTIONS.validate(bad).is_empty(),"generic identity or resource pin rejects invalid input")
	check(OPTIONS.write(generic)==OK and OPTIONS.read()==generic,"generic logical identity pins and cursor survive preference restart")
	check(FileAccess.get_sha256("user://play-options-save-sentinel.bin")==sha,"generic preferences preserve actual game save sentinel")
	# Core checks share an isolated profile; remove only this guard's own fixture.
	DirAccess.remove_absolute(OPTIONS.PATH)
	DirAccess.remove_absolute("user://play-options-save-sentinel.bin")
	print("CURRENT523_ADEN_PLAY_OPTIONS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true,"M_collision_verified":false}))
	quit(0 if failures.is_empty() else 1)
