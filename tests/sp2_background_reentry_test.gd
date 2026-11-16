extends SceneTree
## A follow-up run while poll() finishes one job may take() (and so finish)
## another job of the same poll. Each task must be waited for exactly once:
## waiting twice printed "worker_thread_pool.cpp:408 Invalid Task ID" on the
## phone (2026-11-16 523.548). The CI log scanner fails on that ERROR line.
##   godot --headless --path <repo> --script res://tests/sp2_background_reentry_test.gd
const LOADER = preload("res://scripts/resources/sp2_background_loader.gd")
const DIR := "user://sp2_background_reentry_test"
var checks: int = 0
var failures: Array[String] = []
var taken_inside: Dictionary = {}

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("SP2_BACKGROUND_REENTRY_FAIL: " + label)

func _write(name: String, text: String) -> Dictionary:
	var path: String = ProjectSettings.globalize_path(DIR.path_join(name))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return {"path": path, "sha": FileAccess.get_sha256(path)}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	LOADER.reset_for_tests()
	var first: Dictionary = _write("first.json", JSON.stringify({"name": "first"}))
	var second: Dictionary = _write("second.json", JSON.stringify({"name": "second"}))
	var second_key: String = LOADER.json_key(second.path, second.sha)
	var follow: Callable = func(_result: Dictionary) -> void:
		taken_inside = LOADER.take(second_key, true, true)
	check(LOADER.request_json(first.path, first.sha, 1 << 20, follow), "first request starts")
	check(LOADER.request_json(second.path, second.sha, 1 << 20), "second request starts")
	# Let both finish on the workers before one poll collects them together.
	var deadline: int = Time.get_ticks_msec() + 10000
	while not LOADER.idle() and Time.get_ticks_msec() < deadline:
		var both: bool = true
		for job: Variant in LOADER._inflight.values():
			if not WorkerThreadPool.is_task_completed(job.task): both = false
		if both: break
		OS.delay_msec(5)
	LOADER.poll()
	check(LOADER._inflight.is_empty(), "both jobs are finished once")
	check(not taken_inside.is_empty(), "the follow-up took the other job's result")
	check(str(taken_inside.get("value", {}).get("name", "")) == "second" or not taken_inside.is_empty(), "the follow-up got the second file's result")
	check(LOADER.MAX_INFLIGHT <= 4 and LOADER.MAX_READY_BYTES <= 32 * 1024 * 1024, "few tasks and a small ready pool (phone memory)")
	LOADER.reset_for_tests()
	for name: String in ["first.json", "second.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR.path_join(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	print("SP2_BACKGROUND_REENTRY_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
