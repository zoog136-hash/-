extends RefCounted
## Resource selection has its own atomic preferences; never writes game saves.
const PATH = "user://current523_aden_review_paths.cfg"
const RAW = preload("res://scripts/maps/current523_aden_pack.gd")
const TILES = preload("res://scripts/maps/current523_tile_review_pack.gd")

static func selection(previous: bool = false) -> Dictionary:
	var config := ConfigFile.new()
	config.load(PATH)
	var section: String = "previous_paths" if previous else "paths"
	var raw: Variant = config.get_value(section, "raw", "")
	var tiles: Variant = config.get_value(section, "tiles", "")
	return {"raw": raw if raw is String else "", "tiles": tiles if tiles is String else ""}

static func activate(raw: String, tiles: String) -> Dictionary:
	var config := ConfigFile.new()
	var error: Error = config.load(PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return {"ok": false, "problem": "기존 팩 설정을 읽을 수 없습니다."}
	var old: Dictionary = selection()
	if (old.raw != raw or old.tiles != tiles) and not old.raw.is_empty() and not old.tiles.is_empty():
		config.set_value("previous_paths", "raw", old.raw)
		config.set_value("previous_paths", "tiles", old.tiles)
	config.set_value("paths", "raw", raw)
	config.set_value("paths", "tiles", tiles)
	# One rename publishes both paths together. A failed write retains the old file.
	var temporary: String = PATH + ".pending-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	if config.save(temporary) != OK:
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "problem": "팩 경로 설정을 저장할 수 없습니다."}
	if DirAccess.rename_absolute(temporary, PATH) != OK:
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "problem": "팩 경로 설정을 활성화할 수 없습니다."}
	return {"ok": true, "raw": raw, "tiles": tiles}

static func rollback() -> Dictionary:
	var old: Dictionary = selection(true)
	if old.raw.is_empty() or old.tiles.is_empty():
		return {"ok": false, "problem": "이전에 사용한 팩 경로가 없습니다."}
	var raw = RAW.new()
	if not raw.load_pack(old.raw):
		return {"ok": false, "problem": "이전 원문 팩을 열 수 없습니다: " + raw.problem}
	var tiles = TILES.new()
	if not tiles.load_pack(old.tiles):
		return {"ok": false, "problem": "이전 타일 팩을 열 수 없습니다: " + tiles.problem}
	return activate(old.raw, old.tiles)
