extends SceneTree
## Godot 4 treats a null get_meta() default as "no default": a missing key
## logs an object.cpp error. Every get_meta(key, null) read in scripts/ must be
## guarded by has_meta(key) on the same line.
##   godot --headless --path <repo> --script res://tests/meta_default_guard_test.gd
const SKIP: Array[String] = []
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("META_DEFAULT_GUARD_FAIL: " + label)

func _scripts(dir: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"): out.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir): _scripts(dir.path_join(sub), out)

func _initialize() -> void:
	var files: Array[String] = []
	_scripts("res://scripts", files)
	var pattern := RegEx.new()
	pattern.compile("get_meta\\(\"([^\"]+)\",\\s*null\\)")
	var reads: int = 0
	for path: String in files:
		if path in SKIP: continue
		var number: int = 0
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			for found: RegExMatch in pattern.search_all(line):
				reads += 1
				check(line.contains("has_meta(\"%s\")" % found.get_string(1)), "%s:%d unguarded get_meta(\"%s\", null)" % [path, number, found.get_string(1)])
	check(files.size() > 100, "scanned %d scripts / %d null-default reads" % [files.size(), reads])
	# The guarded form returns null for a missing key and the value otherwise.
	var node := Node.new()
	check((node.get_meta("source_button") if node.has_meta("source_button") else null) == null, "missing key reads null")
	node.set_meta("source_button", 7)
	check((node.get_meta("source_button") if node.has_meta("source_button") else null) == 7, "present key reads its value")
	node.free()
	print("META_DEFAULT_GUARD_RESULT " + JSON.stringify({"checks":checks, "reads":reads, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
