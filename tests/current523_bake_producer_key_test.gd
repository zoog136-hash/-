extends SceneTree
## Standalone, synthetic (no original): narrow producer bake keys
## (current523_bake_cache.gd producer_key()) keep a bake across unrelated code
## changes and invalidate it on any change of the producer script, a file it
## preloads (transitively), data it names, a class it uses, its schema, the
## original identity or the key's other parts; a stale or unverifiable input
## list falls back to the global key. Also checks the shipped manifest
## (current523_bake_producers.gd) equals a fresh scan of every producer.

const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const DEPENDENCIES = preload("res://scripts/resources/current523_bake_dependencies.gd")
const PRODUCERS = preload("res://scripts/resources/current523_bake_producers.gd")
const DIR := "user://bake_producer_key_test/"
const NAMES := {"SyntheticBakeKlass": DIR + "klass.gd"}
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)

func put(name: String, text: String) -> void:
	var file := FileAccess.open(DIR + name, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func entry(files: Variant = null) -> Dictionary:
	var scanned: PackedStringArray = DEPENDENCIES.closure([DIR + "producer.gd"], [], DIR, NAMES).files
	return {"roots": [DIR + "producer.gd"], "ignore": [], "files": Array(scanned) if files == null else files}

func code(value: Dictionary) -> String:
	return BAKE.producer_code(value, DIR, NAMES).code

func key_of(value: Dictionary, schema: String = "schema.v1", source: String = "original:1") -> String:
	var hashed: String = code(value)
	return BAKE.producer_key_from("synthetic_bake", "synthetic", schema, source, hashed) if not hashed.is_empty() else ""

func write_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	put("producer.gd", "extends RefCounted\nconst DEP = preload(\"" + DIR + "dep.gd\")\nfunc build(): return SyntheticBakeKlass.new()\n")
	put("dep.gd", "extends RefCounted\nconst DEEP = preload(\"" + DIR + "deep.gd\")\nconst DATA := \"" + DIR + "data.json\"\n")
	put("deep.gd", "extends RefCounted\nconst VALUE := 1\n")
	put("data.json", "{\"rows\":[1]}")
	put("klass.gd", "class_name SyntheticBakeKlass\nextends RefCounted\n")
	put("unrelated.gd", "extends RefCounted\nconst VALUE := 1\n")

func clean() -> void:
	for name: String in ["producer.gd","dep.gd","deep.gd","data.json","klass.gd","unrelated.gd","extra.gd"]:
		DirAccess.remove_absolute(DIR + name)
	DirAccess.remove_absolute(DIR.trim_suffix("/"))

func synthetic() -> void:
	write_fixture()
	var declared: Dictionary = entry()
	var expected := PackedStringArray([DIR+"data.json",DIR+"deep.gd",DIR+"dep.gd",DIR+"klass.gd",DIR+"producer.gd"])
	check(PackedStringArray(declared.files) == expected, "closure = producer + transitive preload + named data + used class " + str(declared.files))
	var base: String = key_of(declared)
	check(base.length() == 64, "narrow key formed")
	check(BAKE.producer_code(declared, DIR, NAMES).reason == "narrow:verified", "sources readable -> list verified")
	put("unrelated.gd", "extends RefCounted\nconst VALUE := 2 # unrelated change\n")
	check(key_of(declared) == base, "(1) unrelated script change keeps the narrow key")
	put("producer.gd", "extends RefCounted\nconst DEP = preload(\"" + DIR + "dep.gd\")\nfunc build(): return SyntheticBakeKlass.new() # changed\n")
	check(key_of(declared) != base, "(2) producer script change invalidates")
	write_fixture()
	check(key_of(declared) == base, "restored inputs give the same key")
	put("deep.gd", "extends RefCounted\nconst VALUE := 2\n")
	check(key_of(declared) != base, "(2) transitively preloaded dependency change invalidates")
	write_fixture()
	put("dep.gd", "extends RefCounted\nconst DEEP = preload(\"" + DIR + "deep.gd\")\nconst DATA := \"" + DIR + "data.json\"\n# edit\n")
	check(key_of(declared) != base, "(2) directly preloaded dependency change invalidates")
	write_fixture()
	put("data.json", "{\"rows\":[2]}")
	check(key_of(declared) != base, "named data file change invalidates")
	write_fixture()
	put("klass.gd", "class_name SyntheticBakeKlass\nextends RefCounted\nconst X := 1\n")
	check(key_of(declared) != base, "used class_name script change invalidates")
	write_fixture()
	check(key_of(declared, "schema.v2") != base, "(2) schema version change invalidates")
	check(key_of(declared, "schema.v1", "original:2") != base, "(2) original identity change invalidates")
	check(key_of(declared, "schema.v1", "").is_empty(), "no original -> no key")
	var hashed: String = code(declared)
	check(BAKE.producer_key_from("other_bake", "synthetic", "schema.v1", "original:1", hashed) != base, "bake name is a key part")
	check(BAKE.producer_key_from("synthetic_bake", "synthetic", "schema.v1", "original:1", hashed) == base, "key composition is deterministic")
	check(BAKE.engine_key().begins_with(str(Engine.get_version_info().string)), "engine version is a key part")
	check(BAKE.producer_key_from("synthetic_bake", "synthetic", "schema.v1", "original:1", "") == "", "never a key without code")
	# A new dependency makes the declared list stale: refused (global key).
	put("extra.gd", "extends RefCounted\n")
	put("producer.gd", "extends RefCounted\nconst DEP = preload(\"" + DIR + "dep.gd\")\nconst EXTRA = preload(\"" + DIR + "extra.gd\")\nfunc build(): return SyntheticBakeKlass.new()\n")
	var stale: Dictionary = BAKE.producer_code(declared, DIR, NAMES)
	check(stale.code == "" and stale.reason == "global:manifest_stale", "new preload with an old list -> global key")
	var refreshed: Dictionary = entry()
	check((refreshed.files as Array).has(DIR + "extra.gd") and key_of(refreshed) != base, "regenerated list includes the new dependency")
	write_fixture()
	DirAccess.remove_absolute(DIR + "extra.gd")
	# Dependency removed from disk while still declared: stale.
	DirAccess.remove_absolute(DIR + "deep.gd")
	check(BAKE.producer_code(declared, DIR, NAMES).code == "", "missing declared input -> global key")
	write_fixture()
	# Sources not readable (exported binary tokens): declared list used, still hashed.
	put("producer.gd", "")
	var exported: Dictionary = BAKE.producer_code(declared, DIR, NAMES)
	check(exported.reason == "narrow:manifest" and exported.code.length() == 64, "unreadable root -> CI-verified list, hashed")
	var before: String = exported.code
	put("deep.gd", "extends RefCounted\nconst VALUE := 3\n")
	check(BAKE.producer_code(declared, DIR, NAMES).code != before, "export mode still invalidates on a declared input change")
	write_fixture()
	put("dep.gd", "")
	check(BAKE.producer_code(declared, DIR, NAMES).reason == "global:partly_unreadable", "readable root with unreadable dependency -> global key")
	write_fixture()
	check(BAKE.producer_code({}, DIR, NAMES).reason == "global:unknown_producer", "unknown producer -> global key")
	clean()

func shipped() -> void:
	check(not PRODUCERS.PRODUCERS.is_empty(), "manifest declares producers")
	for producer: String in PRODUCERS.PRODUCERS:
		var value: Dictionary = PRODUCERS.PRODUCERS[producer]
		var scan: Dictionary = DEPENDENCIES.closure(value.roots, value.ignore)
		check((scan.unreadable as PackedStringArray).is_empty(), producer + ": sources readable in tests")
		check(scan.files == PackedStringArray(value.files), producer + ": manifest current (run tools/current523_bake_producers_update.gd) " + str(scan.files))
		check(not PackedStringArray(value.files).has("res://scripts/world.gd") and not PackedStringArray(value.files).has("res://Main.tscn"), producer + ": unrelated game code is not an input")
		check(not PackedStringArray(value.files).has(DEPENDENCIES.MANIFEST) and not PackedStringArray(value.files).has(DEPENDENCIES.SELF), producer + ": key machinery is not an input")
		check(PackedStringArray(value.files).has("res://scripts/resources/current523_bake_cache.gd"), producer + ": bake format code is an input")
		var hashed: String = BAKE.producer_code_key(producer)
		check(hashed.length() == 64 and BAKE.producer_key_reasons.get(producer) == "narrow:verified", producer + ": narrow key " + str(BAKE.producer_key_reasons.get(producer)))
		check(BAKE.producer_key("probe", producer, "s", "original:1") == BAKE.producer_key_from("probe", producer, "s", "original:1", hashed), producer + ": producer_key uses the narrow code")
	check(BAKE.producer_key("probe", "no_such_producer", "s", "original:1") == BAKE.projection_key("probe", "original:1"), "undeclared producer keeps the global key")
	check(BAKE.global_code_key().length() == 64, "global key still hashes every script/data file")

func _initialize() -> void:
	synthetic()
	shipped()
	var result := {"checks": checks, "failures": failures}
	print("CURRENT523_BAKE_PRODUCER_KEY_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
