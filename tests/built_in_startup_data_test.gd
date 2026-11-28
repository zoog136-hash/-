extends SceneTree

const DATA = preload("res://scripts/resources/built_in_startup_data.gd")
const ROOT := "user://built_in_startup_data_test"
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _write(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	return file.store_buffer(bytes) and file.get_error() == OK

func _mount(name: String, entries: Dictionary) -> bool:
	var pack := PCKPacker.new()
	var target := ROOT.path_join(name + ".pck")
	if pack.pck_start(target) != OK: return false
	for path: String in entries:
		if pack.add_file(path, entries[path]) != OK: return false
	return pack.flush() == OK and ProjectSettings.load_resource_pack(target)

func _fingerprint(value: Variant) -> String:
	return JSON.stringify(value, "", false, true).sha256_text()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var original: Dictionary = {}
	var entries: Dictionary = {}
	for path: String in DATA.PATHS:
		var text: String = FileAccess.get_file_as_string(path)
		original[path] = _fingerprint(JSON.parse_string(text))
		_check(DATA._read_companion(path) == null and _fingerprint(DATA.read_json(path)) == original[path], "JSON fallback " + path)
		var binary: String = ROOT.path_join(path.get_file() + ".bin")
		var data := DATA.compile_json(path)
		_check(not data.is_empty() and _write(binary, data), "compilation " + path)
		entries[DATA.companion_path(path)] = binary
	_check(_mount("built_in", entries), "mount compiled data")
	for path: String in DATA.PATHS:
		var prepared: Variant = DATA._read_companion(path)
		_check(prepared != null and _fingerprint(prepared) == original[path], "exact compiled data " + path)

	var path: String = DATA.PATHS[0]
	var damaged := DATA.compile_json(path)
	damaged[damaged.size() - 1] ^= 1
	var bad := ROOT.path_join("damaged.bin")
	_check(_write(bad, damaged) and _mount("damaged", {DATA.companion_path(path): bad}), "mount damaged companion")
	_check(DATA._read_companion(path) == null and _fingerprint(DATA.read_json(path)) == original[path], "reject damaged bytes and use JSON")

	path = DATA.PATHS[1]
	var replacement := ROOT.path_join("updated.json")
	_check(_write(replacement, '{"updated":true}'.to_utf8_buffer()) and _mount("updated", {path: replacement}), "mount updated JSON without replacing companion")
	_check(DATA._read_companion(path) == null and DATA.read_json(path) == {"updated": true}, "reject stale companion after overlay")
	print("BUILT_IN_STARTUP_DATA_RESULT ", JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
