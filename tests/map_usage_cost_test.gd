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
	var observed: Dictionary = {}
	var pending: Dictionary = PLAY._first_draw_usage(commands, Rect2(400, 400, 24, 24), observed)
	check(pending.size() == 2, "one entry per distinct ref")
	check(pending[0x101] == PackedInt64Array([0, 0, 24, 0]) and pending[0x202] == PackedInt64Array([48, 0, 5, 7]), "every tile corner of a ref, in draw order")
	check(observed.is_empty(), "no evidence for a block entirely outside the view")
	var view := Rect2(0, 0, 24, 24)
	commands = {
		-2: PackedInt64Array([48, 0, 1, 0, 0, 2, -24, -24, 3, -23, -23, 4]),
		0: PackedInt64Array([0, 0, 1, 24, 0, 5, 48, 0, 5, 0, 24, 6])
	}
	pending = PLAY._first_draw_usage(commands, view, observed)
	check(observed.keys() == [1, 2, 4], "later visible duplicate retains its first command order across layers")
	check(pending.keys() == [3, 5, 6] and pending[5] == PackedInt64Array([24, 0, 48, 0]), "edge-touching tiles stay pending, a one-pixel intersection counts")
	var other_block: Dictionary = PLAY._first_draw_usage({0: PackedInt64Array([24, 0, 1, 0, 0, 2])}, view, observed)
	check(observed.keys() == [1, 2, 4] and other_block.keys() == [1], "overlapping blocks deduplicate only refs genuinely visible in each")
	observed.clear()
	view.position = Vector2(24, 0)
	PLAY._reveal_usage(pending, view, observed)
	PLAY._reveal_usage(other_block, view, observed)
	check(observed.keys() == [5, 1] and pending.keys() == [3, 6] and other_block.is_empty(), "movement reveals the remaining corners in block order")
	observed.clear()
	PLAY._reveal_usage(pending, view, observed)
	check(observed.is_empty(), "warm repeats do not resubmit consumed refs")
	check(USAGE.FLUSH_INTERVAL_MSEC >= 10000, "normal periodic writes retain the ten-second interval")
	var source: String = FileAccess.get_file_as_string("res://scripts/maps/current523_map_usage.gd")
	var early: int = source.find("if _recorded.has(seen_key):return Observation.ACCEPTED")
	var checks_at: int = source.find("if not actual_main(renderer)")
	check(early > 0 and early < checks_at, "a recorded observation returns before any other check")
	check(source.find("_recorded[seen_key]=true") > source.find("_pending.append(event)"), "only an accepted observation is remembered; persistence is reported separately")
	print("MAP_USAGE_COST_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
