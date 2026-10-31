extends SceneTree

# A source map's full pack verification (hashing every chunk) runs once and is
# reused while nothing it checked changed; any change re-verifies.
const RUNTIME = preload("res://scripts/maps/source_map_runtime.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("SOURCE_MAP_VERIFY_CACHE_FAIL: ", label)

func _initialize() -> void:
	var mid: String = "aden_world"
	check(RUNTIME.supports(mid), "aden_world is a supported source map")
	RUNTIME.verified_rules.clear()
	var runs: int = RUNTIME.verification_runs
	var started: int = Time.get_ticks_usec()
	var first: Dictionary = RUNTIME.verified_context(mid)
	var full_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	check(not first.is_empty(), "first verification succeeds")
	if first.is_empty():
		_finish()
		return
	check(RUNTIME.verification_runs == runs + 1, "first call verifies the pack")
	started = Time.get_ticks_usec()
	var second: Dictionary = RUNTIME.verified_context(mid)
	var cached_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	check(RUNTIME.verification_runs == runs + 1, "unchanged pack is not re-hashed")
	check(second.record == first.record and not is_same(second.record, RUNTIME.verified_rules[mid].record), "callers get an equal private record copy")
	check(second.rule == first.rule and second.art == first.art, "rule and pack reader match the verified result")
	second.record.chunks.clear()
	check(not RUNTIME.verified_context(mid).record.chunks.is_empty(), "a caller's edit never reaches the cache")
	var entry: Dictionary = RUNTIME.verified_rules[mid]
	check(entry.files.size() > 3 and entry.files.has(RUNTIME.root_path() + "/index.json"), "cache tracks the pack index and chunks")
	entry.stamps[entry.stamps.size() - 1] = 1
	RUNTIME.verified_context(mid)
	check(RUNTIME.verification_runs == runs + 2, "a changed file stamp forces full verification")
	RUNTIME.verified_rules[mid].rule["layout_revision"] = -99
	RUNTIME.verified_context(mid)
	check(RUNTIME.verification_runs == runs + 3, "a changed pinned rule forces full verification")
	RUNTIME.verified_rules[mid].root = "user://elsewhere"
	RUNTIME.verified_context(mid)
	check(RUNTIME.verification_runs == runs + 4, "a different pack root forces full verification")
	print("SOURCE_MAP_VERIFY_CACHE_TIMING full_ms=%.1f cached_ms=%.2f files=%d" % [full_ms, cached_ms, entry.files.size()])
	_finish()

func _finish() -> void:
	print("SOURCE_MAP_VERIFY_CACHE_RESULT ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
