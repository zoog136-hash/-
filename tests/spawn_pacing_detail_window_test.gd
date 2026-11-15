extends SceneTree
## Respawn pacing after a map's first fill, and the per-second detail summary
## shown on the next loading screen.
##   godot --headless --path <repo> --script res://tests/spawn_pacing_detail_window_test.gd
const POPULATION = preload("res://scripts/maps/field_population.gd")
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const BOOT_LOG = preload("res://scripts/boot/boot_progress_log.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("SPAWN_PACING_DETAIL_FAIL: " + label)

func _initialize() -> void:
	var population: Node = POPULATION.new()
	population._fill_remaining = POPULATION.FILL_SECONDS
	population._spawn_tokens = 0.0
	var during_fill: int = 0
	for i: int in 50:
		if population._take_spawn_token(): during_fill += 1
	check(during_fill == 50, "the first fill of a map is not paced")
	population._fill_remaining = 0.0
	population._spawn_tokens = POPULATION.STEADY_SPAWN_BURST
	var burst: int = 0
	for i: int in 50:
		if population._take_spawn_token(): burst += 1
	check(burst == int(POPULATION.STEADY_SPAWN_BURST), "after the fill only the burst is available at once")
	# One simulated second of refills allows about STEADY_SPAWNS_PER_SECOND.
	population._spawn_tokens = minf(POPULATION.STEADY_SPAWN_BURST, population._spawn_tokens + 1.0 * POPULATION.STEADY_SPAWNS_PER_SECOND)
	var next_second: int = 0
	for i: int in 50:
		if population._take_spawn_token(): next_second += 1
	check(next_second == int(POPULATION.STEADY_SPAWNS_PER_SECOND), "steady respawns are paced per second")
	population.free()

	HITCH.reset_for_test("user://spawn_pacing_detail_test")
	var base: int = Time.get_ticks_usec()
	HITCH.frame_at_for_test(base)
	for frame: int in 4:
		var started: int = Time.get_ticks_usec() - 30000
		HITCH.detail("spawn.total", started)
		HITCH.detail("player.visual", Time.get_ticks_usec() - 2000)
		HITCH.frame_at_for_test(base + (frame + 1) * 250000)
	var window: Dictionary = HITCH.take_window()
	var top: String = str(window.get("detail_top", ""))
	check(top.begins_with("spawn.total:"), "the busiest detail operation comes first: " + top)
	check(top.contains("*4"), "calls per second are recorded: " + top)
	check(HITCH.take_window().get("detail_top", "x") == "", "the detail window clears after it is taken")
	var line: String = "ev=alive t=5000 map=aden_world fps=4 frame_ms=250 max_fps=30 cpu_top=field_population:120 detail_top=" + top
	check(BOOT_LOG.parse_line(line).get("detail_top") == top, "the detail summary survives the log line format")

	print("SPAWN_PACING_DETAIL_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
