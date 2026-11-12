extends SceneTree
## Real loading controller integration with a synthetic, delayed destination.
## No original resource packs, character accounts, saves or rendering proof.
## Recovery note: roster-plan and timeout assertions were newly replayed from
## the parent's recorded requirements; this is not an exact old-file SHA claim.
const LOADER = preload("res://scripts/boot/loading_screen.gd")
const DESTINATION := "res://tests/fixtures/loading/delayed_ready.tscn"
var checks: int = 0
var failures: Array[String] = []
var events: Array[Dictionary] = []
var outcomes: Array[bool] = []
var premature_complete: bool = false
var observed_overlay: bool = false
var stable_waits: int = 0
var previous_wait_percent: int = -1

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _watch(loader: Control) -> void:
	loader.progress_changed.connect(func(value: Dictionary) -> void:
		events.append(value.duplicate(true))
		if int(value.percent) == 100:
			var target: Node = current_scene
			if target == null or not target.has_method("loading_readiness") or not target.call("loading_readiness").get("ready", false): premature_complete = true)
	loader.finished.connect(func(ok: bool) -> void: outcomes.append(ok))

func _wait_outcome(loader: Control, expected: int) -> void:
	for index: int in 180:
		if outcomes.size() >= expected: return
		if is_instance_valid(loader):
			var target: Node = current_scene
			if target != null and target.has_method("loading_readiness") and not target.call("loading_readiness").get("ready", false):
				var value: Dictionary = loader.snapshot()
				observed_overlay = observed_overlay or (loader.is_inside_tree() and loader.get_parent() is CanvasLayer and loader.get_parent().get_parent() == root)
				if str(value.current) == "scene_ready":
					if previous_wait_percent >= 0:
						check(int(value.percent) == previous_wait_percent and int(value.percent) < 100, "readiness wait advances no invented progress")
						stable_waits += 1
					previous_wait_percent = int(value.percent)
		await process_frame
	check(false, "loader completes within bounded fixture frames")

func _reset_observations() -> void:
	events.clear()
	outcomes.clear()
	premature_complete = false
	observed_overlay = false
	stable_waits = 0
	previous_wait_percent = -1

func _run() -> void:
	for variable: String in ["TWILIGHT_SOURCE523_IMAGES", "TWILIGHT_SOURCE_UI"]:
		OS.set_environment(variable, "")
		OS.set_environment(variable + "_SHA256", "")
	OS.set_environment("TWILIGHT_LOADING_TEST_REJECT_READY", "")
	OS.set_environment("TWILIGHT_LOADING_TEST_NEVER_READY", "")
	var planned: Array[Dictionary] = [{"id":"images"}, {"id":"ui"}, {"id":"maps"}, {"id":"tiles"}]
	check(LOADER.plan_steps(planned, LOADER.CHARACTERS).map(func(step: Dictionary) -> String: return str(step.id)) == ["images", "ui"], "roster defers map and tile verification until selected character enters Main")
	check(LOADER.plan_steps(planned, LOADER.MAIN) == planned, "Main keeps every selected verification item")
	check(planned.size() == 4, "planning leaves the pending verification list intact")
	check(not FileAccess.file_exists(LOADER.PREBAKE.OPTIONS.PATH), "test has isolated user data without map selection")
	# Fresh recovery regression: the prior measured hitch stays visible.
	LOADER.FRAME_HITCH._previous = {"schema":1,"hitches":2,"worst":[{"ms":345,"sections":[["world",200]]}]}
	var expected_hitch: String = LOADER.FRAME_HITCH.previous_line() + " · 기록 " + LOADER.FRAME_HITCH.PREV_NAME
	var origin := Node.new()
	origin.name = "SyntheticLobbyOrigin"
	root.add_child(origin)
	current_scene = origin
	var loader: Control = LOADER.open(self, "res://tests/fixtures/loading/absent_destination.tscn")
	_watch(loader)
	var hitch_labels: Array[Node] = loader.find_children("*", "Label", true, false).filter(func(node: Node) -> bool: return (node as Label).text == expected_hitch)
	check(hitch_labels.size() == 1 and (hitch_labels[0] as Label).visible, "previous measured hitch diagnostic remains visible")
	check(hitch_labels.size() == 1 and (hitch_labels[0] as Label).autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "previous hitch diagnostic retains original word wrapping")
	check(LOADER.open(self, DESTINATION) == loader, "repeated open reuses the one active overlay")
	await _wait_outcome(loader, 1)
	check(outcomes == [false], "missing destination emits explicit failure")
	check(current_scene == origin and not paused, "load failure preserves the previous scene and its pause state")
	check(loader.snapshot().failed and loader.snapshot().percent == 0 and not loader.snapshot().ready, "missing destination never completes work")
	check(loader.get("_retry").visible, "load failure exposes retry")
	loader.destination = DESTINATION
	loader.call("_boot")
	await _wait_outcome(loader, 2)
	check(outcomes == [false, true], "retry uses the real controller and succeeds")
	check(not premature_complete and current_scene.call("loading_readiness").ready, "100 and successful finish require explicit destination readiness")
	check(observed_overlay, "root overlay survives scene replacement")
	check(stable_waits >= 3, "delayed fixture exercises multiple frames with the same measured percent")
	check(loader.snapshot().percent == 100 and loader.snapshot().completed == loader.snapshot().total, "only the finished target completes the plan")
	check(paused, "target remains paused while the completed overlay is drawn")
	await process_frame
	await process_frame
	check(not is_instance_valid(loader) and not paused, "automatic close frees overlay and restores pause")
	check(is_instance_valid(current_scene), "automatic close leaves ready destination alive")
	# A destination can reject initialization after change_scene, too. Its
	# failure must keep progress below 100 until retry or explicit dismissal.
	_reset_observations()
	OS.set_environment("TWILIGHT_LOADING_TEST_REJECT_READY", "1")
	loader = LOADER.open(self, DESTINATION)
	_watch(loader)
	await _wait_outcome(loader, 1)
	check(outcomes == [false] and loader.snapshot().failed, "explicit readiness rejection emits failure")
	check(loader.snapshot().percent < 100 and not premature_complete, "failed deferred initialization cannot display 100")
	check(paused and loader.get("_dismiss").visible, "failed initialized target stays behind dismissible overlay")
	loader.call("_close")
	await process_frame
	await process_frame
	check(not paused and not is_instance_valid(loader), "dismissal restores pause and releases overlay")
	OS.set_environment("TWILIGHT_LOADING_TEST_REJECT_READY", "")
	# A destination that never opens its readiness gate must fail honestly,
	# offer recovery controls and restore pause after explicit dismissal.
	_reset_observations()
	OS.set_environment("TWILIGHT_LOADING_TEST_NEVER_READY", "1")
	loader = LOADER.open(self, DESTINATION)
	loader.readiness_timeout_msec = 1
	_watch(loader)
	await _wait_outcome(loader, 1)
	check(outcomes == [false] and loader.snapshot().failed, "missing readiness response reaches an explicit timeout failure")
	check(loader.snapshot().percent < 100 and not premature_complete, "readiness timeout cannot invent completion")
	check(loader.get("_retry").visible and loader.get("_dismiss").visible, "readiness timeout exposes retry and error dismissal")
	loader.call("_close")
	await process_frame
	await process_frame
	check(not paused and not is_instance_valid(loader), "timeout dismissal restores pause and releases overlay")
	OS.set_environment("TWILIGHT_LOADING_TEST_NEVER_READY", "")
	# Exercise Loading.tscn's own startup path. Destination is injected before
	# _ready, so no real Main or account/save code is executed by this test.
	_reset_observations()
	var target: Node = current_scene
	current_scene = null
	target.queue_free()
	var initial: Control = (load("res://scenes/boot/Loading.tscn") as PackedScene).instantiate()
	initial.destination = DESTINATION
	root.add_child(initial)
	current_scene = initial
	_watch(initial)
	await _wait_outcome(initial, 1)
	check(outcomes == [true] and not premature_complete, "initial Loading.tscn completes the explicit readiness contract")
	check(observed_overlay and initial.get_parent() is CanvasLayer, "initial scene reparents itself before replacing current_scene")
	await process_frame
	await process_frame
	check(not paused and not is_instance_valid(initial), "initial scene releases its overlay after readiness")
	OS.set_environment("TWILIGHT_LOADING_TEST_NEVER_READY", "")
	print("LOADING_SCREEN_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"fixture":"synthetic_delayed_scene_only"}))
	quit(0 if failures.is_empty() else 1)
