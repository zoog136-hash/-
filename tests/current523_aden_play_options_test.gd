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
	var older: Dictionary = {"enabled":true,"navigation_profile":OPTIONS.LEGACY,"offset_x":0,"offset_y":12,"raw_root":"/private/raw","tile_root":"/private/tiles"}
	# Preferences written before the landing/time/open/fee/return policies existed
	# receive the explicit own defaults instead of being rejected.
	var policy_defaults: Dictionary = {}
	for key: String in ["portal_landing_policy","map_time_policy","map_open_policy","portal_fee_adena","aden_return_radius"]:
		policy_defaults[key] = OPTIONS.defaults()[key]
	check(policy_defaults.map_open_policy == OPTIONS.OWN_ALWAYS_OPEN_V1 and policy_defaults.portal_fee_adena == OPTIONS.OWN_MANUAL_PORTAL_FEE_ADENA, "own map policies are the explicit defaults")
	var valid: Dictionary = older.merged(policy_defaults)
	check(OPTIONS.validate(older) == valid, "older preferences gain the explicit own policy defaults")
	check(OPTIONS.validate(valid) == valid, "explicit local profile and visual correction accept")
	for changes: Dictionary in [{"map_open_policy":"OPEN"},{"map_open_policy":1},{"portal_fee_adena":-1},{"portal_fee_adena":100000001},{"portal_fee_adena":1.5},{"aden_return_radius":33},{"aden_return_radius":true}]:
		var bad: Dictionary = valid.merged(changes, true)
		check(OPTIONS.validate(bad).is_empty(), "invalid map open policy, fee or return radius rejects: " + str(changes))
	var conditions: Dictionary = valid.merged({"map_open_policy":OPTIONS.SOURCE_CONDITIONS_V1,"portal_fee_adena":0,"aden_return_radius":32}, true)
	check(OPTIONS.validate(conditions) == conditions, "source-condition policy and bounded fee/radius accept")
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
	check(OPTIONS.validate(source).path_search_limit==8192,"old source preferences retain the original default search budget")
	check(OPTIONS.validate(source).aden_inferred_placement_enabled,"old source preferences receive explicitly user-authorized default host placement")
	source.aden_inferred_placement_enabled=true
	source.path_search_limit=8192
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
	for limit: Variant in [0,65537,-1,1.5,true,"65536",INF,NAN]:
		var bad: Dictionary=generic.duplicate(true);bad.path_search_limit=limit
		check(OPTIONS.validate(bad).is_empty(),"unsafe or unbounded search budget rejects")
	generic.path_search_limit=65536
	check(OPTIONS.write(generic)==OK and OPTIONS.read()==generic,"explicit bounded own search budget survives preference restart")
	for bad_value: Variant in [0,1,"true",null]:
		var bad: Dictionary=generic.duplicate(true);bad.aden_inferred_placement_enabled=bad_value
		check(OPTIONS.validate(bad).is_empty(),"placement must be an explicit bool, never implicit permission")
	generic.aden_inferred_placement_enabled=false
	check(OPTIONS.write(generic)==OK and OPTIONS.read()==generic,"disabled inferred placement survives own preference restart")
	check(FileAccess.get_sha256("user://play-options-save-sentinel.bin")==sha,"generic preferences preserve actual game save sentinel")
	# Core checks share an isolated profile; remove only this guard's own fixture.
	DirAccess.remove_absolute(OPTIONS.PATH)
	DirAccess.remove_absolute("user://play-options-save-sentinel.bin")
	print("CURRENT523_ADEN_PLAY_OPTIONS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true,"M_collision_verified":false}))
	quit(0 if failures.is_empty() else 1)
