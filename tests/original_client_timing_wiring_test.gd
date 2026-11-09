extends SceneTree
## Measures exactly what changed when the 523 explicit-FPS frame duration moved from
## float(ticks)/fps to the original whole-millisecond stored delay.
const TIMING = preload("res://scripts/original_client/sprite_timing.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "res://scripts/resources/reference_sp2_bank.gd"
	var text: String = FileAccess.get_file_as_string(path)
	if not text.contains("ORIGINAL_TIMING.frame_seconds"): failures.append("reference_sp2_bank does not call the timing adapter")
	if text.contains('float(token[2])/float(source_fps) if explicit_timing'): failures.append("old inline division remains")
	var script: Variant = load(path)
	if not (script is GDScript) or not (script as GDScript).can_instantiate(): failures.append("reference_sp2_bank does not compile")
	var compared: int = 0
	var identical: int = 0
	var max_diff: float = 0.0
	var max_diff_case: Array = []
	var fell_back: int = 0
	for fps: int in range(1, 121):
		for raw: int in range(0, 3001):
			var old_value: float = float(raw) / float(fps)
			var timed: Dictionary = TIMING.frame_seconds(raw, fps)
			compared += 1
			if timed.status != "OK":
				fell_back += 1
				continue
			var new_value: float = timed.seconds
			var expected_ms: int = int(floor(float(raw) * 1000.0 / float(fps) + 1e-9))
			if int(timed.delay_ms) != expected_ms: failures.append("not whole-ms truncation raw=%d fps=%d" % [raw, fps])
			var diff: float = absf(old_value - new_value)
			if diff < 1e-12: identical += 1
			if diff > max_diff:
				max_diff = diff
				max_diff_case = [raw, fps]
			if diff >= 0.001: failures.append("difference of 1 ms or more raw=%d fps=%d" % [raw, fps])
	# Domain edges keep the previous division instead of wrapping.
	for edge: Array in [[-1, 24], [5, 0], [70000, 1], [4294968, 24]]:
		if TIMING.frame_seconds(int(edge[0]), int(edge[1])).status == "OK": failures.append("edge accepted " + str(edge))
	if TIMING.frame_seconds(4, 36).delay_ms != 111: failures.append("V03 raw 4 at FPS 36 must be 111 ms")
	print("ORIGINAL_CLIENT_TIMING_WIRING_RESULT ", JSON.stringify({"compared": compared, "identical_to_old": identical, "kept_old_division": fell_back, "max_difference_seconds": max_diff, "max_difference_case_raw_fps": max_diff_case, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
