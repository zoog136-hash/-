extends SceneTree
const PROFILE = preload("res://scripts/characters/save_profile.gd")
const MIGRATION = preload("res://scripts/maps/source_map_save_migration.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("CHARACTER_PROFILE_FAIL ",label)

func run() -> void:
	var rows: Array = [
		[[],"Windows",false,false,false,PROFILE.DEFAULT_PATH],
		[[],"Android",false,false,false,PROFILE.DEFAULT_PATH],
		[[],"Android",true,false,false,"user://twilight_full_cards_test_v1.json"],
		[[],"Android",true,true,false,PROFILE.DEFAULT_PATH],
		[["--playtest-full-cards"],"Linux",true,false,false,"user://twilight_full_cards_test_v1.json"],
		[["--playtest-full-cards"],"Linux",false,false,false,PROFILE.DEFAULT_PATH],
		[["--native-png-maps"],"Windows",false,false,false,"user://twilight_native_png_save.json"],
		[["--native-png-maps","--playtest-full-cards"],"Linux",true,false,false,"user://twilight_native_png_full_cards_test_v1.json"],
		[["--native-png-maps","--legacy-map-layouts"],"Linux",true,false,true,PROFILE.DEFAULT_PATH],
		[["--native-png-maps","--legacy-map-layouts"],"Linux",true,false,false,"user://twilight_native_png_save.json"],
		[["--growth-lab"],"Linux",true,false,false,"user://twilight_growth_lab_v1.json"],
		[["--growth-lab"],"Linux",false,false,false,PROFILE.DEFAULT_PATH],
		[["--base508-source-test","--growth-lab"],"Android",true,false,false,"user://base508_source_test_never_written.json"]
	]
	for i: int in rows.size():
		var row: Array=rows[i]
		check(PROFILE.base_for(PackedStringArray(row[0]),row[1],row[2],row[3],row[4])==row[5],"namespace matrix %d"%i)
	check(PROFILE.allows_for(PackedStringArray(),true),"normal account uses roster")
	check(PROFILE.allows_for(PackedStringArray(["--playtest-full-cards"]),true),"isolated full-card account uses roster")
	for flag: String in ["--base508-source-test","--aden523-review","--png-review","--growth-lab"]:
		check(not PROFILE.allows_for(PackedStringArray([flag]),true),"review bypass: "+flag)
	check(PROFILE.allows_for(PackedStringArray(["--growth-lab"]),false),"release ignores debug-only lab")
	var base: String="user://profile-test-"+str(Time.get_ticks_usec())+".json"
	check(PROFILE.resolve(base).get("path")==base,"absent pointer retains namespace")
	check(WRITER.write(base,{"progress":11})==OK,"seed isolated base")
	var original: String=FileAccess.get_sha256(base)
	var first: Dictionary=MIGRATION.stage(base,{"progress":22},original)
	check(first.get("ok",false),"first migration staged")
	if first.get("ok",false):
		check(MIGRATION.activate(base,first)==OK,"first pointer active")
		check(PROFILE.resolve(base).get("path")==first.target_path,"resolver follows first pointer")
		var older_sha: String=FileAccess.get_sha256(first.target_path)
		var latest: Dictionary=MIGRATION.stage(base,{"progress":33},original)
		check(latest.get("ok",false),"later migration staged")
		if latest.get("ok",false):
			check(MIGRATION.activate(base,latest)==OK,"latest pointer active")
			check(PROFILE.resolve(base).get("path")==latest.target_path,"resolver follows latest target")
			check(FileAccess.get_sha256(base)==original and FileAccess.get_sha256(first.target_path)==older_sha,"read routing preserves original and older target bytes")
		var pointer: String=base+".source-map-current.json"
		for raw: String in ["{broken","[]",JSON.stringify({"target_path":base+".source-map-missing.json"}),JSON.stringify({"target_path":base+".source-map-../escape.json"})]:
			check(WRITER.write_text(pointer,raw)==OK,"seed invalid pointer")
			var pointer_sha: String=FileAccess.get_sha256(pointer)
			var result: Dictionary=PROFILE.resolve(base)
			check(not result.get("ok",true) and result.get("path","").is_empty() and not str(result.get("problem","")).is_empty(),"invalid pointer blocks without base fallback")
			check(FileAccess.get_sha256(base)==original and FileAccess.get_sha256(pointer)==pointer_sha,"refusal preserves base and pointer bytes")
	print("CHARACTER_SAVE_PROFILE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
