extends SceneTree
## The crash trail prints sections only while armed after loading.
##   godot --headless --path <repo> --script res://tests/crash_trail_test.gd
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("CRASH_TRAIL_FAIL: " + label)

func _initialize() -> void:
	check(HITCH._trail_until_msec == 0, "trail is off until loading finishes")
	var before: int = HITCH._trail_seq
	HITCH.trail("ignored")
	check(HITCH._trail_seq == before, "an unarmed trail prints nothing")
	HITCH.arm_trail(5)
	check(HITCH._trail_until_msec > Time.get_ticks_msec(), "arming opens a bounded window")
	var armed: int = HITCH._trail_seq
	HITCH.add("monsters", HITCH.now())
	HITCH.count("spawn.rate_capped")
	check(HITCH._trail_seq == armed + 2, "measured sections and counters are traced while armed")
	HITCH._trail_until_msec = Time.get_ticks_msec() - 1
	HITCH.trail("late")
	check(HITCH._trail_until_msec == 0, "the window closes by itself")
	var closed: int = HITCH._trail_seq
	HITCH.add("monsters", HITCH.now())
	check(HITCH._trail_seq == closed, "nothing is traced after the window")
	check(FileAccess.get_file_as_string("res://scripts/boot/loading_screen.gd").contains("FRAME_HITCH.arm_trail()"), "loading completion arms the trail")
	check(FileAccess.get_file_as_string("res://scripts/ui/renewal_hud.gd").contains("FRAME_HITCH.arm_trail(WINDOW_TRAIL_SECONDS)"), "opening a window arms the trail")
	print("CRASH_TRAIL_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
