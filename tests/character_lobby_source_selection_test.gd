extends SceneTree
const SELECT = preload("res://scripts/characters/lobby_source_selection.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("CHARACTER_LOBBY_SOURCE_SELECTION_FAIL ",label)
func _initialize() -> void:
	var pin: String = "a".repeat(64)
	check(SELECT.options([]) == {"ok":true,"selected":false},"no original lobby selection is explicit")
	check(not SELECT.options(["--source-ui=/main","--source-ui-sha256="+pin]).selected,"Main UI selection never becomes lobby selection")
	var cli: Dictionary = SELECT.options(["--source-lobby=/private/lobby","--source-lobby-sha256="+pin])
	check(cli.ok and cli.path == "/private/lobby" and cli.sha256 == pin,"explicit lobby CLI pair")
	var env: Dictionary = SELECT.options([],"/private/lobby",pin)
	check(env == cli,"environment and CLI agree")
	check(SELECT.options(["--source-lobby=/private/lobby","--source-lobby-sha256="+pin],"/private/lobby",pin) == cli,"matching selection routes accepted")
	for args: PackedStringArray in [["--source-lobby=/private/lobby"],["--source-lobby-sha256="+pin],["--source-lobby=","--source-lobby-sha256="+pin],["--source-lobby=/private/lobby","--source-lobby=/other","--source-lobby-sha256="+pin],["--source-lobby=/private/lobby","--source-lobby-sha256="+pin,"--source-lobby-sha256="+"b".repeat(64)]]:
		check(not SELECT.options(args).ok,"incomplete or conflicting CLI rejected")
	for pair: Array in [["/private/lobby",""],["",pin],["/private/lobby","A".repeat(64)],["/private/lobby","bad"],[" /private/lobby",pin]]:
		check(not SELECT.options([],pair[0],pair[1]).ok,"incomplete or malformed environment rejected")
	check(not SELECT.options(["--source-lobby=/private/lobby","--source-lobby-sha256="+pin],"/other",pin).ok,"conflicting environment does not silently override CLI")
	check(SELECT.options(["--source-lobby=/private/lobby","--source-lobby=/private/lobby","--source-lobby-sha256="+pin]).ok,"identical repeated selection is stable")
	check(not SELECT.open_options({"ok":true,"selected":true,"path":"relative","sha256":pin}).ok,"relative original source paths rejected")
	check(not SELECT.open_options({"ok":true,"selected":true,"path":"user://does-not-exist-original-lobby","sha256":pin}).ok,"missing source manifest never selects another pack")
	var folder: String = "user://lobby-selection-proof-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(folder)
	var path: String = folder.path_join("original_ui.json")
	var document: Dictionary = {"schema":"twilight-original-ui-v1","scenes":{},"files":{},"atlases":{},"blockers":[]}
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(document)); file.close()
	var options: Dictionary = {"ok":true,"selected":true,"path":folder,"sha256":FileAccess.get_sha256(path)}
	check(not SELECT.open_options(options).get("ok",true),"a pinned Main UI or foreign pack cannot impersonate lobby provenance")
	document["lobby_source"] = {"kind":"twilight.source523.lobby-input.v1","source_snapshot":"patch523","definition_sha256":SELECT.DEFINITIONS.SOURCE_SHA,"files_info_sha256":SELECT.FILES_INFO_SHA}
	file = FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(document)); file.close()
	options.sha256 = FileAccess.get_sha256(path)
	var opened: Dictionary = SELECT.open_options(options)
	check(opened.get("ok",false) and opened.get("selected",false) and not opened.get("rendered",true),"matching pinned lobby provenance selects a pack without rendering claim")
	if opened.get("pack") != null: opened.pack.release_cache_leases()
	document.lobby_source.definition_sha256 = "b".repeat(64)
	file = FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(document)); file.close()
	options.sha256 = FileAccess.get_sha256(path)
	check(not SELECT.open_options(options).get("ok",true),"a valid pin does not excuse another definition snapshot")
	options.sha256 = "c".repeat(64)
	check(not SELECT.open_options(options).get("ok",true),"manifest tampering blocks pack selection")
	DirAccess.remove_absolute(path); DirAccess.remove_absolute(folder)
	print("CHARACTER_LOBBY_SOURCE_SELECTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
