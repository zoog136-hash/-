extends SceneTree
## Regenerates the "files" lists of scripts/resources/current523_bake_producers.gd
## from each producer's roots (run headless from the project root):
##   godot --headless --path . --script res://tools/current523_bake_producers_update.gd
## Prints BAKE_PRODUCERS_UPDATED <n> or BAKE_PRODUCERS_CURRENT.
const PRODUCERS = preload("res://scripts/resources/current523_bake_producers.gd")
const DEPENDENCIES = preload("res://scripts/resources/current523_bake_dependencies.gd")

func _initialize() -> void:
	var path: String = DEPENDENCIES.MANIFEST
	var text: String = FileAccess.get_file_as_string(path)
	var changed: int = 0
	for producer: String in PRODUCERS.PRODUCERS:
		var entry: Dictionary = PRODUCERS.PRODUCERS[producer]
		var scan: Dictionary = DEPENDENCIES.closure(entry.roots, entry.ignore)
		if not (scan.unreadable as PackedStringArray).is_empty():
			push_error("unreadable sources: " + str(scan.unreadable)); quit(1); return
		var block_start: int = text.find("\t\"" + producer + "\": {")
		var files_start: int = text.find("\t\t\"files\": [", block_start)
		var files_end: int = text.find("],", files_start)
		if block_start < 0 or files_start < 0 or files_end < 0:
			push_error("manifest layout: " + producer); quit(1); return
		var lines: PackedStringArray = []
		for file: String in scan.files: lines.append("\t\t\t\"" + file + "\",")
		var body: String = "\t\t\"files\": [\n" + "\n".join(lines) + "\n\t\t"
		if text.substr(files_start, files_end - files_start) != body:
			text = text.substr(0, files_start) + body + text.substr(files_end)
			changed += 1
	if changed == 0:
		print("BAKE_PRODUCERS_CURRENT"); quit(0); return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: push_error("cannot write " + path); quit(1); return
	file.store_string(text)
	file.close()
	print("BAKE_PRODUCERS_UPDATED " + str(changed))
	quit(0)
