extends SceneTree
## Map usage observation stays a one-time cost per unit: the ground keeps
## per-block lists of refs not yet seen on screen, and the ledger returns at
## once for an observation it already recorded and normally writes every 10 s (pressure and lifecycle force a drain).
##   godot --headless --path <repo> --script res://tests/map_usage_cost_test.gd
const PLAY = preload("res://scripts/maps/current523_aden_play_renderer.gd")
const USAGE = preload("res://scripts/maps/current523_map_usage.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("MAP_USAGE_COST_FAIL: " + label)

func _initialize() -> void:
	var commands: Dictionary = {-2: PackedInt64Array([0, 0, 0x101, 24, 0, 0x101, 48, 0, 0x202]), 0: PackedInt64Array([5, 7, 0x202])}
	var pending: Dictionary = PLAY._usage_pending(commands)
	check(pending.size() == 2, "one entry per distinct ref")
	check(pending[0x101] == PackedInt64Array([0, 0, 24, 0]) and pending[0x202] == PackedInt64Array([48, 0, 5, 7]), "every tile corner of a ref, in draw order")
	check(USAGE.FLUSH_INTERVAL_MSEC >= 10000, "normal periodic writes retain the ten-second interval")
	var source: String = FileAccess.get_file_as_string("res://scripts/maps/current523_map_usage.gd")
	var early: int = source.find("if _recorded.has(seen_key):return Observation.ACCEPTED")
	var checks_at: int = source.find("if not actual_main(renderer)")
	check(early > 0 and early < checks_at, "a recorded observation returns before any other check")
	check(source.find("_recorded[seen_key]=true") > source.find("_pending.append(event)"), "only an accepted observation is remembered; persistence is reported separately")
	print("MAP_USAGE_COST_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
