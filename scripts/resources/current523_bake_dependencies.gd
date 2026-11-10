extends RefCounted
## Transitive code/data inputs of a bake producer, by static scan.
##
## A producer's bake is reusable only while every file its result can depend
## on is unchanged. From the producer's root scripts this follows, to a fixed
## point: every quoted "res://..." literal that names an existing file
## (preload/load/extends/const paths, data files), and every global class_name
## or autoload name used as a word. Scripts and text resources (.gd, .tscn,
## .tres) are scanned again; other files (JSON, binary data) are inputs whose
## bytes are hashed. The scan over-includes on purpose (comments, unused
## branches): an extra file only costs a rebake, a missing one would reuse a
## stale bake. Paths built at run time are not visible to it; such producers
## stay on the global key (see current523_bake_producers.gd).
##
## The key machinery itself (this file and the producer manifest) is never an
## input: the manifest's relevant content (a producer's file list) is hashed
## explicitly by current523_bake_cache.gd.

const SELF := "res://scripts/resources/current523_bake_dependencies.gd"
const MANIFEST := "res://scripts/resources/current523_bake_producers.gd"
const SCANNED_EXTENSIONS := ["gd","tscn","tres"]

static var _globals: Dictionary = {}

## Global class_name and autoload names -> script path, for this project.
static func globals() -> Dictionary:
	if not _globals.is_empty(): return _globals
	var names: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class","")) != "" and str(entry.get("path","")) != "": names[str(entry["class"])] = str(entry["path"])
	if names.is_empty():
		# No editor class cache (fresh checkout run headless without import):
		# read the class_name declarations themselves, so the scan does not
		# depend on whether the project was imported.
		var declaration := RegEx.new()
		declaration.compile("(?m)^class_name\\s+([A-Za-z_][A-Za-z0-9_]*)")
		var scripts: PackedStringArray = []
		for directory: String in ["res://scripts","res://addons"]: _scripts(directory, scripts)
		for path: String in scripts:
			var found: RegExMatch = declaration.search(FileAccess.get_file_as_string(path))
			if found != null: names[found.get_string(1)] = path
	for property: Dictionary in ProjectSettings.get_property_list():
		var key: String = str(property.get("name",""))
		if not key.begins_with("autoload/"): continue
		var path: String = str(ProjectSettings.get_setting(key,"")).trim_prefix("*")
		if not path.is_empty(): names[key.trim_prefix("autoload/")] = path
	_globals = names
	return _globals

## {"files": sorted PackedStringArray of every input (roots included),
##  "unreadable": scripts whose text could not be read (e.g. exported as
##  binary tokens), so their own references are unknown}.
## `scheme` is the path prefix literals must start with (synthetic tests use
## a user:// folder); `names` maps class/autoload words to paths.
static func closure(roots: Array, ignore: Array = [], scheme: String = "res://", names: Variant = null) -> Dictionary:
	var skip: Dictionary = {SELF: true, MANIFEST: true}
	for path: Variant in ignore: skip[str(path)] = true
	var literal := RegEx.new()
	literal.compile("[\"'](" + _escape(scheme) + "[^\"'\\n]*)[\"']")
	var words: Dictionary = {}
	var word := RegEx.new()
	var word_list: PackedStringArray = []
	var words_ready: bool = false
	var found: Dictionary = {}
	var unreadable: Dictionary = {}
	var queue: Array = roots.duplicate()
	while not queue.is_empty():
		var path: String = str(queue.pop_back())
		if found.has(path) or skip.has(path): continue
		found[path] = true
		if not path.get_extension() in SCANNED_EXTENSIONS: continue
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			unreadable[path] = true
			continue
		if not words_ready:
			# Built on the first readable script only: an exported project
			# (binary tokens) never needs the class/autoload names.
			words_ready = true
			words = globals() if names == null else names
			for name: Variant in words: if str(name).is_valid_identifier(): word_list.append(str(name))
			word_list.sort()
			if not word_list.is_empty(): word.compile("\\b(" + "|".join(word_list) + ")\\b")
		for match: RegExMatch in literal.search_all(text):
			var target: String = match.get_string(1)
			if not found.has(target) and not skip.has(target) and FileAccess.file_exists(target): queue.append(target)
		if word_list.is_empty(): continue
		for match: RegExMatch in word.search_all(text):
			var target: String = str(words[match.get_string(1)])
			if target != path and not found.has(target) and not skip.has(target) and FileAccess.file_exists(target): queue.append(target)
	var files := PackedStringArray(found.keys())
	files.sort()
	var missing := PackedStringArray(unreadable.keys())
	missing.sort()
	return {"files": files, "unreadable": missing}

static func _scripts(directory: String, files: PackedStringArray) -> void:
	var dir := DirAccess.open(directory)
	if dir == null: return
	for name: String in dir.get_files(): if name.get_extension() == "gd": files.append(directory.path_join(name))
	for name: String in dir.get_directories(): if not name.begins_with("."): _scripts(directory.path_join(name), files)

static func _escape(text: String) -> String:
	var result: String = ""
	for character: String in text:
		result += ("\\" + character) if character in [".","/","\\","(",")","[","]","{","}","*","+","?","^","$","|"] else character
	return result
