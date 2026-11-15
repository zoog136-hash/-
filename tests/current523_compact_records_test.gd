extends SceneTree
## A compact record index answers exactly like current523_bake_cache.open_records()
## (same file, later duplicate ID wins, missing IDs absent) with less memory.
##   godot --headless --path <repo> --script res://tests/current523_compact_records_test.gd
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const RECORDS = preload("res://scripts/resources/current523_compact_records.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("CURRENT523_COMPACT_RECORDS_FAIL: " + label)

func _initialize() -> void:
	var name: String = "compact_records_test_%d" % OS.get_process_id()
	var key: String = BAKE.key(["compact_records_test", str(Time.get_ticks_usec())])
	var writer: RefCounted = BAKE.record_writer(name, key)
	check(writer != null, "record writer opens")
	if writer == null:
		_finish()
		return
	var ids: Array[String] = []
	for index: int in 20000:
		var id: String = ["a:%d", "c:ItemClass:%d", "m:Image/UI/아이콘_%d.png"][index % 3] % index
		ids.append(id)
		writer.add(id, {"index": index, "id": id})
	writer.add("a:3", {"index": -3, "id": "a:3", "later": true}) # duplicate: the later wins
	writer.add("", "empty id")
	writer.add("meta", {"kind": "meta"})
	check(BAKE.finish_records(writer), "record file commits")
	var plain: RefCounted = BAKE.open_records(name, key)
	var m0: int = OS.get_static_memory_usage()
	var compact: RefCounted = RECORDS.open(name, key)
	var compact_bytes: int = OS.get_static_memory_usage() - m0
	check(plain != null and compact != null, "both readers open the same verified file")
	if plain != null and compact != null:
		var same: bool = compact.size() == plain.offsets.size()
		for id: String in ids:
			same = same and compact.has(id) and compact.read(id) == plain.read(id)
		check(same, "every ID answers the same record")
		check(compact.read("a:3") == {"index": -3, "id": "a:3", "later": true} and plain.read("a:3") == compact.read("a:3"), "a later duplicate ID wins")
		check(compact.read("") == "empty id" and compact.read("meta") == {"kind": "meta"}, "empty and short IDs")
		var absent: bool = true
		for id: String in ["a:20000", "a:", "c:ItemClass:0", "m:Image/UI/아이콘_1.pn", "A:3", "zz"]:
			absent = absent and not compact.has(id) and compact.read(id) == null and plain.read(id) == null
		check(absent, "missing IDs (prefixes, other tables, case) are absent")
		var m1: int = OS.get_static_memory_usage()
		var again: RefCounted = BAKE.open_records(name, key)
		var plain_bytes: int = OS.get_static_memory_usage() - m1
		check(again != null and compact_bytes * 2 < plain_bytes, "packed index uses less than half the memory: %d vs %d" % [compact_bytes, plain_bytes])
	check(RECORDS.open(name, "0".repeat(64)) == null, "a different value key is not opened")
	BAKE.clear(name)
	check(RECORDS.open(name, key) == null, "a removed file is not opened")
	_finish()

func _finish() -> void:
	print("CURRENT523_COMPACT_RECORDS_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
